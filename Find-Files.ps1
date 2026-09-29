<#
.SYNOPSIS
    Fast file and folder search by name, or file search by content.

.EXAMPLE
    .\Find-Files.ps1 report                     # files and folders containing "report"
    .\Find-Files.ps1 project -Type Folder       # folders only
    .\Find-Files.ps1 *.docx -Path C:\Users       # wildcard name match
    .\Find-Files.ps1 -Content "invoice" -Ext txt,md,csv
    .\Find-Files.ps1 budget -Path D:\ -Max 50 -Open
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Name = '*',                 # Name or wildcard. Plain text = "contains".
    [string]$Path = '.',                 # Where to start searching
    [string]$Content,                    # Optional: text to search for inside files
    [string[]]$Ext,                      # Optional: extensions, e.g. txt,docx
    [ValidateSet('All', 'File', 'Folder')]
    [string]$Type = 'All',               # Match files, folders, or both
    [int]$Max = 0,                       # Stop after N results (0 = unlimited)
    [switch]$Regex,                      # Treat -Content as a regex
    [switch]$IncludeHidden,              # Also search hidden/system folders
    [switch]$Open                        # Pick a result and open it
)

$root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
if ($Name -notmatch '[\*\?]') { $Name = "*$Name*" }
$pattern = [System.Management.Automation.WildcardPattern]::new($Name, 'IgnoreCase')
$extSet = $null
if ($Ext) {
    $extSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($e in $Ext) { [void]$extSet.Add('.' + $e.TrimStart('.', '*')) }
}
# Content and extension filters only make sense for files
$matchFolders = $Type -ne 'File' -and -not $Content -and -not $Ext
$matchFiles = $Type -ne 'Folder'
$skipAttrs =[IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System -bor [IO.FileAttributes]::ReparsePoint

$sw = [Diagnostics.Stopwatch]::StartNew()
$results = [System.Collections.Generic.List[string]]::new()
$stack = [System.Collections.Generic.Stack[string]]::new()
$stack.Push($root)

:outer while ($stack.Count -gt 0) {
    $dir = $stack.Pop()

    try {
        foreach ($sub in [IO.Directory]::EnumerateDirectories($dir)) {
            if (-not $IncludeHidden) {
                try { if (([IO.File]::GetAttributes($sub) -band $skipAttrs) -ne 0) { continue } } catch { continue }
            }
            $stack.Push($sub)
            if ($matchFolders -and $pattern.IsMatch([IO.Path]::GetFileName($sub))) {
                Write-Host "$sub\" -ForegroundColor Yellow
                $results.Add($sub)
                if ($Max -gt 0 -and $results.Count -ge $Max) { break outer }
            }
        }
    } catch { continue }   # access denied, path too long, etc.

    if (-not $matchFiles) { continue }
    try { $files = [IO.Directory]::EnumerateFiles($dir) } catch { continue }
    try {
        foreach ($file in $files) {
            $fileName = [IO.Path]::GetFileName($file)
            if (-not $pattern.IsMatch($fileName)) { continue }
            if ($extSet -and -not $extSet.Contains([IO.Path]::GetExtension($file))) { continue }

            if ($Content) {
                $hit = Select-String -LiteralPath $file -Pattern $Content -SimpleMatch:(-not $Regex) -List -ErrorAction SilentlyContinue
                if (-not $hit) { continue }
                Write-Host ("{0}:{1}: " -f $file, $hit.LineNumber) -ForegroundColor Cyan -NoNewline
                Write-Host $hit.Line.Trim()
            } else {
                Write-Host $file
            }

            $results.Add($file)
            if ($Max -gt 0 -and $results.Count -ge $Max) { break outer }
        }
    } catch { continue }
}

$sw.Stop()
Write-Host ("`n{0} match(es) in {1:N2}s" -f $results.Count, $sw.Elapsed.TotalSeconds) -ForegroundColor Green

if ($Open -and $results.Count -gt 0) {
    for ($i = 0; $i -lt [Math]::Min($results.Count, 30); $i++) { Write-Host ("[{0}] {1}" -f $i, $results[$i]) }
    $choice = Read-Host 'Number to open (Enter to cancel)'
    if ($choice -match '^\d+$' -and [int]$choice -lt $results.Count) { Invoke-Item -LiteralPath $results[[int]$choice] }
}
