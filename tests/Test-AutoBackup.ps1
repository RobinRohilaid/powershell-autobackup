#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$program = Join-Path (Split-Path -Parent $PSScriptRoot) 'src/AutoBackup.ps1'
$engine = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path -LiteralPath $engine)) { $engine = Join-Path $PSHOME 'pwsh.exe' }
if (-not (Test-Path -LiteralPath $engine)) { throw 'Run these tests with PowerShell on Windows.' }
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('autobackup-tests-' + [Guid]::NewGuid().ToString('N'))
$source = Join-Path $temporary 'source'
$destination = Join-Path $temporary 'backups'
$passed = 0
function Assert-Test {
    param([bool]$Condition,[string]$Message)
    if (-not $Condition) { throw $Message }
}
function Invoke-Backup {
    param([string]$From,[string]$To,[int]$Count=2,[switch]$Dry)
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$program,
        '-SourceFolder',$From,'-BackupDestination',$To,'-KeepCount',[string]$Count)
    if ($Dry) { $arguments += '-DryRun' }
    $saved = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $engine @arguments 2>&1
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $saved }
    return [pscustomobject]@{exitCode=$code;output=($output | Out-String)}
}
try {
    [void][IO.Directory]::CreateDirectory($source)
    [IO.File]::WriteAllText((Join-Path $source 'hello.txt'),'backup test payload')
    $result = Invoke-Backup $source $destination -Dry
    Assert-Test ($result.exitCode -eq 0 -and -not (Test-Path -LiteralPath $destination)) 'DryRun created a destination or failed.'
    $passed++
    $result = Invoke-Backup $source $destination -Count 0
    Assert-Test ($result.exitCode -ne 0 -and -not (Test-Path -LiteralPath $destination)) 'KeepCount 0 must fail before writing.'
    $passed++
    $inside = Join-Path $source 'backups'
    $result = Invoke-Backup $source $inside
    Assert-Test ($result.exitCode -ne 0 -and -not (Test-Path -LiteralPath $inside)) 'A destination inside the source was accepted.'
    $passed++
    $result = Invoke-Backup (Join-Path $temporary 'missing') $destination
    Assert-Test ($result.exitCode -ne 0) 'A missing source returned success.'
    $passed++
    [void][IO.Directory]::CreateDirectory($destination)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $oldNames = @('source_20200101_120000000_aaaaaaaa.zip','source_20210101_120000000_bbbbbbbb.zip')
    foreach ($name in $oldNames) {
        $path = Join-Path $destination $name
        [IO.Compression.ZipFile]::CreateFromDirectory($source,$path)
        [IO.File]::SetLastWriteTimeUtc($path,[DateTime]::ParseExact($name.Substring(7,8),'yyyyMMdd',[Globalization.CultureInfo]::InvariantCulture))
    }
    $unrelated = Join-Path $destination 'other-project.zip'
    [IO.File]::WriteAllText($unrelated,'unrelated archive fixture')
    $before = [string[]]@(Get-ChildItem -LiteralPath $destination -File | Sort-Object Name | ForEach-Object { $_.Name })
    $result = Invoke-Backup $source $destination -Dry
    $after = [string[]]@(Get-ChildItem -LiteralPath $destination -File | Sort-Object Name | ForEach-Object { $_.Name })
    Assert-Test ($result.exitCode -eq 0 -and ($before -join '|') -ceq ($after -join '|')) 'DryRun changed existing backups.'
    $passed++
    $result = Invoke-Backup $source $destination
    Assert-Test ($result.exitCode -eq 0) ('Backup failed: ' + $result.output)
    $managed = @(Get-ChildItem -LiteralPath $destination -File | Where-Object { $_.Name -like 'source_*.zip' })
    Assert-Test ($managed.Count -eq 2 -and -not (Test-Path -LiteralPath (Join-Path $destination $oldNames[0]))) 'Rotation did not remove only the oldest managed backup.'
    Assert-Test ([IO.File]::ReadAllText($unrelated) -ceq 'unrelated archive fixture') 'Rotation modified an unrelated file.'
    $newest = @($managed | Where-Object { $_.Name -notin $oldNames })
    Assert-Test ($newest.Count -eq 1) 'Expected exactly one new backup.'
    $zip = [IO.Compression.ZipFile]::OpenRead($newest[0].FullName)
    try {
        $entry = $zip.GetEntry('hello.txt')
        Assert-Test ($null -ne $entry) 'The archive did not preserve its payload.'
        $reader = New-Object IO.StreamReader -ArgumentList ($entry.Open())
        try { Assert-Test ($reader.ReadToEnd() -ceq 'backup test payload') 'Archive payload differs from source.' }
        finally { $reader.Dispose() }
    }
    finally { $zip.Dispose() }
    $passed++
    Write-Host ('PASS: ' + $passed + ' AutoBackup checks; only disposable test directories were used.')
}
finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
