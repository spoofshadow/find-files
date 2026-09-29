# Find-Files.ps1

A fast PowerShell script for finding files and folders by name, or files by the text inside them.

It walks folders with .NET directory enumeration instead of `Get-ChildItem -Recurse`, so it is much faster on large folder trees. It quietly skips folders you don't have access to.

Works in Windows PowerShell 5.1 and PowerShell 7+.

## Quick start

```powershell
.\Find-Files.ps1 report
```

This lists every file and folder under the current folder whose name contains "report".

## Examples

```powershell
.\Find-Files.ps1 report                            # files and folders containing "report"
.\Find-Files.ps1 project -Type Folder              # folders only
.\Find-Files.ps1 *.docx -Path C:\Users\spoof       # wildcard match, starting from a folder
.\Find-Files.ps1 -Content "invoice" -Ext txt,csv   # text inside .txt and .csv files
.\Find-Files.ps1 -Content "\d{3}-\d{4}" -Regex     # regex search inside files
.\Find-Files.ps1 budget -Path D:\ -Max 20 -Open    # stop at 20 results, then pick one to open
```

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `-Name` (first argument) | `*` | Name to match. Without `*` or `?`, it matches any name that **contains** the text. Not case-sensitive. |
| `-Path` | current folder | Folder to start searching from. |
| `-Type` | `All` | `All`, `File` or `Folder`. |
| `-Content` | none | Text to search for inside files. Shows the file, line number and first matching line. |
| `-Regex` | off | Treat `-Content` as a regular expression instead of plain text. |
| `-Ext` | none | Only include these extensions, e.g. `-Ext txt,md,csv`. |
| `-Max` | `0` (unlimited) | Stop after this many results. |
| `-IncludeHidden` | off | Also search hidden and system folders (skipped by default for speed). |
| `-Open` | off | After searching, show a numbered list and open the one you pick. |

## Output

- **Files** are printed as plain paths.
- **Folders** are printed in yellow with a trailing `\`.
- **Content matches** are printed as `path:line:` in cyan, followed by the matching line.
- A summary line shows the number of matches and how long the search took.

## Notes

- `-Content` and `-Ext` only return files, since folders have no contents or extensions.
- `-Content` searches plain-text files only. It won't find text inside `.docx`, `.xlsx` or `.pdf` files, because those are stored compressed.
- Symbolic links and junctions are not followed, which avoids loops and duplicate results.
- For a tighter name match, use wildcards: `word*` matches names starting with "word", while plain `word` also matches `password.txt`.

## Setup

If PowerShell blocks the script because of its execution policy, allow local scripts once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

To run it from anywhere by typing `ff`, add this line to your PowerShell profile (open it with `notepad $PROFILE`):

```powershell
Set-Alias ff C:\Users\spoof\word\Find-Files.ps1
```

Then use it like this:

```powershell
ff report -Path C:\
```

