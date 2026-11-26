param([string]$StateDir,[switch]$TestMode,[switch]$NoRefresh,[switch]$ShowInTaskbar,[switch]$SyntheticRhythmTest,[ValidateRange(0,3600)][int]$AutoCloseSeconds=0)
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
$build=(& (Join-Path $PSScriptRoot 'Build-DesktopHost.ps1')|Out-String)|ConvertFrom-Json
$args='--root "'+$root+'"'
if($StateDir){$args+=' --state-dir "'+[IO.Path]::GetFullPath($StateDir)+'"'}
if($TestMode){$args+=' --test'};if($NoRefresh){$args+=' --no-refresh'};if($ShowInTaskbar){$args+=' --show-taskbar'}
if($AutoCloseSeconds){$args+=' --auto-close '+$AutoCloseSeconds}
if($SyntheticRhythmTest){$args+=' --synthetic-rhythm'}
Start-Process -FilePath $build.executable -ArgumentList $args -WindowStyle Hidden
Write-Output ('Gemini GUI host started: '+$build.executable)
