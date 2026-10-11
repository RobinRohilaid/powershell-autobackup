# Origin and authorship

- Author: Robin Rohilaid (`RobinRohilaid`).
- Original coursework: TalTech ICA0021 scripting languages, PowerShell project.
- Reviewed source: private `RobinRohilaid/TalTech-IT-Projects`, repository ID `1335822116`.
- Source path: `SKRIPTIMISKEELED/ICA0021-rrohil-PS1/src/AutoBackup.ps1`.
- Source commit: `a5ee5690b1e5d0393a3af0fb6914dc50fbae2c3c`.
- Original source blob: `c280283cf89545ab616502975fc8acef6160a686`.

The original metadata records Gemini 3.1 Pro assistance with error handling and file rotation.

This public edition adds positive retention validation, rejects a destination inside the source, uses literal paths and unique archive names, reserves a retention slot for the new backup, and limits cleanup to the tool's current naming format. Archives are staged before rotation, and failures stop the script. It also adds English documentation and six isolated Windows tests.

The original course repositories and their source code remain unchanged. This public repository contains only the selected utility, documentation, ignore rules, and tests; it does not import private repository history or personal files.
