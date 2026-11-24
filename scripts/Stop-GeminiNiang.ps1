param([string]$StateDir=(Join-Path $env:LOCALAPPDATA 'GeminiNiang\state'),[switch]$UnregisterPlugin)
$ErrorActionPreference='Stop'
$StateDir=[IO.Path]::GetFullPath($StateDir)
if(Test-Path -LiteralPath $StateDir){
  [IO.File]::WriteAllText((Join-Path $StateDir 'stop.flag'),'stop')
  if($UnregisterPlugin){
    $file=Join-Path $StateDir 'config.json'
    if(!(Test-Path -LiteralPath $file)){throw 'No local configuration found; plugin was not changed.'}
    $config=Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json
    if(!(Test-Path -LiteralPath $config.agyPath -PathType Leaf)){throw 'Configured CLI is unavailable; remove gemini-niang manually in Antigravity.'}
    & $config.agyPath plugin uninstall gemini-niang
    if($LASTEXITCODE-ne 0){throw 'Plugin removal failed; local preferences are retained.'}
  }
}
Write-Output 'Stop requested. Preferences retained. Codex and GPT Niang were not changed.'
