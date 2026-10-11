# PowerShell AutoBackup

A Windows PowerShell command-line project based on my TalTech scripting coursework. It creates a ZIP archive of a folder and retains a configurable number of this tool's backups.

## What it demonstrates

- Parameter validation and filesystem checks.
- A preview that leaves the filesystem unchanged.
- ZIP creation with `Compress-Archive` and a temporary output file.
- Backup naming and retention based on `LastWriteTime`.
- Error handling and isolated tests with disposable directories.

## Preview and run

Requires Windows PowerShell 5.1 or PowerShell on Windows with `Compress-Archive` available. From the repository root, substitute your own existing source folder:

```powershell
powershell.exe -NoProfile -File .\src\AutoBackup.ps1 -SourceFolder 'C:\MyProject' -BackupDestination 'C:\Backups\MyProject' -KeepCount 5 -DryRun
```

Review the preview, then remove `-DryRun` to create the backup. The destination must be outside the source folder. `KeepCount` must be between `1` and `10000`; its default is `5`.

## Backup and retention behavior

Archives are named `<source>_yyyyMMdd_HHmmssfff_<8-character-id>.zip`. Existing archives are never overwritten. The script creates a temporary archive, opens it to check it is readable and nonempty, and moves it to its final name before removing any earlier backups.

Rotation affects only files that match this exact naming format for the same source directory name. Unrelated ZIP files and backups made with the older coursework naming format are retained. A retention count of `1` keeps the new archive and removes earlier matching archives.

## Tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-AutoBackup.ps1
```

The tests use temporary directories and remove their fixtures afterward. Six checks cover preview behavior, invalid retention, a destination inside the source, a missing source, unchanged files during preview, and actual archive contents plus rotation. No user folders or real backups are used.

## Scope and limitations

This is a coursework backup utility for ordinary test folders. `Compress-Archive` omits hidden files and folders and has a documented per-file size limit of 2 GB. The archive check reads the ZIP directory; it is not a complete restore or checksum verification. The script does not coordinate concurrent runs and does not resolve directory junctions or symbolic links. Distinct sources with the same directory name should use separate destinations.

Author: Robin Rohilaid. See [ORIGIN.md](ORIGIN.md) for provenance and changes from the coursework version.
