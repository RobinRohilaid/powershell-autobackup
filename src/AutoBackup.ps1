#Requires -Version 5.1
<#
.SYNOPSIS
Creates a ZIP backup and retains a limited number of this tool's earlier backups.
.DESCRIPTION
Use DryRun to inspect the planned archive and rotation without writing files.
The destination must be outside the source. Hidden files are excluded by Compress-Archive.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SourceFolder,
    [Parameter(Mandatory=$true)][string]$BackupDestination,
    [ValidateRange(1,10000)][int]$KeepCount = 5,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

if (-not (Test-Path -LiteralPath $SourceFolder -PathType Container)) {
    throw "Source folder does not exist or is not a directory: $SourceFolder"
}
$source = Get-Item -LiteralPath $SourceFolder
if ($source.PSProvider.Name -cne 'FileSystem') { throw 'The source must be a filesystem directory.' }
$sourcePath = $source.FullName
if ($sourcePath.TrimEnd([char[]]'\/') -ieq ([IO.Path]::GetPathRoot($sourcePath)).TrimEnd([char[]]'\/')) {
    throw 'Select a named source directory rather than a drive root.'
}
$destinationPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BackupDestination)
$destinationPath = [IO.Path]::GetFullPath($destinationPath)
$sourcePrefix = $sourcePath.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
if ($destinationPath.TrimEnd([char[]]'\/') -ieq $sourcePath.TrimEnd([char[]]'\/') -or
    $destinationPath.StartsWith($sourcePrefix,[StringComparison]::OrdinalIgnoreCase)) {
    throw 'The backup destination must be outside the source directory.'
}
if (Test-Path -LiteralPath $destinationPath) {
    if (-not (Test-Path -LiteralPath $destinationPath -PathType Container)) {
        throw 'The backup destination is an existing file.'
    }
}
$sourceFiles = @(Get-ChildItem -LiteralPath $sourcePath -Recurse -File)
if ($sourceFiles.Count -eq 0) {
    Write-Host 'No visible source files found. Nothing to back up.'
    return
}
$sourceName = $source.Name
if ([string]::IsNullOrWhiteSpace($sourceName)) { throw 'Select a named source directory rather than a drive root.' }
$pattern = '^' + [regex]::Escape($sourceName) + '_[0-9]{8}_[0-9]{9}_[a-f0-9]{8}\.zip$'
$existing = @()
if (Test-Path -LiteralPath $destinationPath -PathType Container) {
    $existing = @(Get-ChildItem -LiteralPath $destinationPath -File |
        Where-Object { $_.Name -cmatch $pattern } | Sort-Object LastWriteTime,Name -Descending)
}
# Reserve one retention slot for the archive that will be created in this run.
$toDelete = @($existing | Select-Object -Skip ($KeepCount - 1))
$stamp = Get-Date -Format 'yyyyMMdd_HHmmssfff'
$suffix = [Guid]::NewGuid().ToString('N').Substring(0,8)
$zipPath = Join-Path $destinationPath ($sourceName + '_' + $stamp + '_' + $suffix + '.zip')
if ($DryRun) {
    if (-not (Test-Path -LiteralPath $destinationPath)) {
        Write-Host "[DRY-RUN] Would create destination: $destinationPath"
    }
    Write-Host "[DRY-RUN] Would create archive: $zipPath"
    foreach ($file in $toDelete) { Write-Host ('[DRY-RUN] Would remove earlier backup: ' + $file.FullName) }
    return
}
if (-not (Test-Path -LiteralPath $destinationPath)) {
    [void][IO.Directory]::CreateDirectory($destinationPath)
}
$temporary = Join-Path $destinationPath ('.in-progress-' + [Guid]::NewGuid().ToString('N') + '.zip')
try {
    $items = [string[]]@(Get-ChildItem -LiteralPath $sourcePath | ForEach-Object { $_.FullName })
    Compress-Archive -LiteralPath $items -DestinationPath $temporary -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($temporary)
    try { if ($archive.Entries.Count -eq 0) { throw 'The generated archive is empty.' } }
    finally { $archive.Dispose() }
    # No Force: an existing archive is never overwritten.
    Move-Item -LiteralPath $temporary -Destination $zipPath -ErrorAction Stop
}
catch {
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
    throw
}
# Rotation starts only after the new archive has been created and opened successfully.
foreach ($file in $toDelete) {
    Remove-Item -LiteralPath $file.FullName -ErrorAction Stop
    Write-Host ('Removed earlier backup: ' + $file.Name)
}
Write-Host ('Backup created: ' + $zipPath)
