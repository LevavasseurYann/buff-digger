# Dev only (dev/ is never packaged): keeps every BuffDiggerJournal.lua the game writes (/reload, logout),
# zipped and dated, in %USERPROFILE%\BuffDigger-journaux (outside OneDrive: real names and private chat).
# Run every 5 minutes by a scheduled task, see README § Développer.
$wtf = 'C:\Program Files (x86)\World of Warcraft\_forever_\WTF\Account'
$out = Join-Path $env:USERPROFILE 'BuffDigger-journaux'
New-Item -ItemType Directory -Force -Path $out | Out-Null
Get-ChildItem -Path $wtf -Recurse -Filter 'BuffDiggerJournal.lua' | ForEach-Object {
  # Named after the game's write time: a file already archived has its zip already.
  $zip = Join-Path $out ($_.LastWriteTime.ToString('yyyy-MM-dd_HHmmss') + '-BuffDiggerJournal.zip')
  if (-not (Test-Path $zip)) { Compress-Archive -Path $_.FullName -DestinationPath $zip }
}
