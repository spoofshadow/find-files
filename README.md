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
Set-Alias ff C:\Path\to\script\Find-Files.ps1
```

Then use it like this:

```powershell
ff report -Path C:\
```
------------------------------------------------------------------------------------------------

# find-files.sh (Linux)

The bash version of the same tool, for Debian and other Linux systems. It needs only `find`, `grep` and `awk`, which Debian includes by default.
If you'd rather use one script on both systems, you could install PowerShell 7 on Debian and try running Find-Files.ps1 there. I haven't tested that.

## Setup

Copy `find-files.sh` to the Linux machine, then make it executable:

```bash
chmod +x find-files.sh
```

To run it from anywhere as `ff`, install it into your PATH:

```bash
sudo cp find-files.sh /usr/local/bin/ff
```

If you edited the file on Windows and see `bad interpreter` or `$'\r': command not found`, it has Windows line endings. Fix them with:

```bash
sed -i 's/\r$//' find-files.sh
```

## Examples

```bash
./find-files.sh report                        # files and folders containing "report"
./find-files.sh project -t folder             # folders only
./find-files.sh '*.pdf' -p ~/Documents        # wildcard match (quote wildcards!)
./find-files.sh -c invoice -e txt,csv         # text inside .txt and .csv files
./find-files.sh -c 'error [0-9]+' -r -p /var/log   # regex search inside files
./find-files.sh budget -p / -m 20 -o          # stop at 20 results, then pick one to open
```

## Options

| Short | Long | PowerShell equivalent |
|---|---|---|
| (first argument) | | `-Name` |
| `-p DIR` | `--path` | `-Path` |
| `-t TYPE` | `--type` | `-Type` (`all`, `file`, `folder`) |
| `-c TEXT` | `--content` | `-Content` |
| `-r` | `--regex` | `-Regex` |
| `-e LIST` | `--ext` | `-Ext` |
| `-m N` | `--max` | `-Max` |
| `-H` | `--hidden` | `-IncludeHidden` |
| `-o` | `--open` | `-Open` |
| `-h` | `--help` | |

## Linux-specific notes

- **Quote wildcards** (`'*.pdf'`), or bash expands them against the current folder before the script sees them.
- **Hidden folders** are folders whose names start with `.`, such as `.cache` and `.git`. They are skipped unless you pass `-H`.
- `/proc`, `/sys`, `/dev` and `/run` are always skipped, so searching from `/` is safe.
- Folders you can't read are skipped silently. Use `sudo` to search everything.
- **`-o` opens results with `xdg-open` on a desktop.** On a server with no desktop, files open in `$EDITOR` (or `nano`), and for folders it prints a `cd` command.
- Binary files are skipped during content searches.

