# Isolated, silent visual demo. It never constructs a system-audio capture worker.
$ErrorActionPreference='Stop'
$dir=Join-Path $env:LOCALAPPDATA 'GeminiNiang\preview-rhythm';$null=[IO.Directory]::CreateDirectory($dir)
$file=Join-Path $dir 'preferences.json';$prefs=@{view='bust';size=240;followHost=$false;paused=$false;autoQuoteEnabled=$false;soundOn=$false;collapsed=$true}
if([IO.File]::Exists($file)){
  try{$saved=[IO.File]::ReadAllText($file)|ConvertFrom-Json;foreach($key in @('view','size')){if($null-ne $saved.$key){$prefs[$key]=$saved.$key}}}catch{}
  [IO.File]::Copy($file,$file+'.bak',$true)
}
[IO.File]::WriteAllText($file,($prefs|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
& (Join-Path $PSScriptRoot 'Start-GeminiNiang.ps1') -StateDir $dir -TestMode -NoRefresh -SyntheticRhythmTest -AutoCloseSeconds 120
