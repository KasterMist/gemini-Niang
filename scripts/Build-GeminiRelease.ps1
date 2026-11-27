param(
  [ValidatePattern('^[A-Za-z0-9._/-]+$')][string]$SourceRef='HEAD',
  [string]$OutputDirectory=(Join-Path (Split-Path $PSScriptRoot -Parent) 'dist\gemini')
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Git-Text([string]$Arguments){
  $p=[Diagnostics.Process]::new();$p.StartInfo=[Diagnostics.ProcessStartInfo]::new('git',$Arguments)
  $p.StartInfo.WorkingDirectory=$root;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
  $p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
  $p.StartInfo.StandardOutputEncoding=[Text.UTF8Encoding]::new($false)
  try{$null=$p.Start();$s=$p.StandardOutput.ReadToEnd();$errorText=$p.StandardError.ReadToEnd();$p.WaitForExit();if($p.ExitCode-ne 0){throw "git failed: $errorText"};return $s.TrimEnd("`r","`n")}finally{$p.Dispose()}
}
function Hash-Hex($Algorithm,[byte[]]$Bytes){try{return ([BitConverter]::ToString($Algorithm.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$Algorithm.Dispose()}}
function File-Hash([string]$Path){
  $s=[IO.File]::OpenRead($Path);$h=[Security.Cryptography.SHA256]::Create()
  try{return ([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','')}finally{$h.Dispose();$s.Dispose()}
}
# Always package immutable Git blobs, never untracked files or working-tree edits.
$commit=Git-Text ('rev-parse --verify "'+$SourceRef+'^{commit}"')
if($commit-notmatch '^[a-f0-9]{40}$'){throw 'Expected SHA1 Git commit'}
$package=(Git-Text ('show '+$commit+':package.json'))|ConvertFrom-Json
$plugin=(Git-Text ('show '+$commit+':antigravity/plugin.json'))|ConvertFrom-Json
if($package.name-ne 'gemini-niang'-or $plugin.name-ne 'gemini-niang'-or $package.version-ne $plugin.version-or $package.version-notmatch '^\d+\.\d+\.\d+$'){throw 'Gemini package/plugin identity or version mismatch'}
$excluded=@('.codex','.agents','docs/ui-v040/local-runtime.json')
$tree=@{}
foreach($line in (Git-Text ('-c core.quotepath=false ls-tree -r '+$commit)).Split("`n")){
  if($line-notmatch '^(100644|100755) blob ([a-f0-9]{40})\t(.+)$'){throw "Unsupported Git entry: $line"}
  $blob=$Matches[2];$name=$Matches[3].TrimEnd("`r")
  if(@($excluded|Where-Object {$name-eq $_-or $name.StartsWith($_+'/')}).Count){continue}
  if($name-match '(^|/)(node_modules|\.test-state|dist|\.git)(/|$)|(^|/)(preferences|audio-preferences|widget-runtime|config|usage|installation|settings|presence|runtime|status)\.json$|(^|/)\.env($|\.)|\.(bak|tmp|flag|zip|exe|log)$'){throw "Local/generated state cannot be shipped: $name"}
  if($name.Contains('..')-or $name.Contains('\')-or $name.Contains("`t")-or $name.StartsWith('/')){throw "Unsafe archive path: $name"}
  $tree[$name]=$blob
}
$required=@('LICENSE','README.md','package.json','antigravity/plugin.json','desktop/Host.cs','desktop/Host.manifest','desktop/GeminiNiang.ps1','desktop/system-rhythm.ps1','desktop/music-audio.cs','desktop/music-visual.cs','desktop/music-anchor.cs','desktop/assets/press.wav','desktop/assets/release.wav','scripts/Build-DesktopHost.ps1','scripts/Start-GeminiNiang.ps1','scripts/Install-GeminiNiang.ps1','scripts/Stop-GeminiNiang.ps1','scripts/Preview-Rhythm.ps1','安装Gemini娘.cmd','打开Gemini娘.cmd','停用Gemini娘.cmd','预览摆锤（不监听）.cmd')
foreach($view in @('bust','full','side','back')){foreach($action in @('idle','blink','wave','happy','think','sleep')){$required+='assets/characters/gemini/png/'+$view+'-'+$action+'.png'}}
foreach($name in $required){if(!$tree.ContainsKey($name)){throw "Required Gemini file missing: $name"}}
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory);$null=[IO.Directory]::CreateDirectory($OutputDirectory)
$base='gemini-niang-v'+$package.version+'-windows-source'
$target=Join-Path $OutputDirectory ($base+'.zip');$temp=Join-Path $OutputDirectory ([Guid]::NewGuid().ToString('N')+'.tmp')
try{
  $arguments='archive --format=zip --prefix=Gemini-Niang/ --output="'+$temp+'" '+$commit+' -- .'
  foreach($name in $excluded){$arguments+=' ":(exclude)'+$name+'"'}
  $null=Git-Text $arguments
  $zip=[IO.Compression.ZipFile]::OpenRead($temp);$files=@{};$seen=@{}
  try{
    foreach($entry in $zip.Entries){
      if($entry.FullName.EndsWith('/')){continue}
      if(!$entry.FullName.StartsWith('Gemini-Niang/')){throw 'Unexpected archive prefix'}
      $name=$entry.FullName.Substring(13)
      if(!$tree.ContainsKey($name)-or $seen.ContainsKey($name)){throw "Unexpected/duplicate entry: $name"};$seen[$name]=$true
      $stream=$entry.Open();$buffer=[IO.MemoryStream]::new()
      try{$stream.CopyTo($buffer);$bytes=$buffer.ToArray()}finally{$stream.Dispose();$buffer.Dispose()}
      $header=[Text.Encoding]::ASCII.GetBytes('blob '+$bytes.Length+[char]0)
      $h=[Security.Cryptography.SHA1]::Create()
      try{$null=$h.TransformBlock($header,0,$header.Length,$header,0);$null=$h.TransformFinalBlock($bytes,0,$bytes.Length);$blobHash=([BitConverter]::ToString($h.Hash)).Replace('-','').ToLowerInvariant()}finally{$h.Dispose()}
      if($blobHash-ne $tree[$name]){throw "Blob mismatch: $name"}
      $files[$name]=Hash-Hex ([Security.Cryptography.SHA256]::Create()) $bytes
    }
    if($files.Count-ne $tree.Count){throw 'Archive file count mismatch'}
  }finally{$zip.Dispose()}
  $digest=File-Hash $temp
  if([IO.File]::Exists($target)){
    if((File-Hash $target)-ne $digest){throw 'Different package already exists. Use another output directory; existing package was preserved.'}
  }else{[IO.File]::Move($temp,$target)}
  $utf8=[Text.UTF8Encoding]::new($false)
  [IO.File]::WriteAllText((Join-Path $OutputDirectory ($base+'.sha256.txt')),($digest+'  '+$base+".zip`n"),$utf8)
  $manifest=@{version=$package.version;commit=$commit;archive=($base+'.zip');sha256=$digest;files=$files;systemAudioTested=$false}
  [IO.File]::WriteAllText((Join-Path $OutputDirectory ($base+'.manifest.json')),($manifest|ConvertTo-Json -Depth 5),$utf8)
  @{archive=$target;commit=$commit;sha256=$digest;files=$files.Count;version=$package.version}|ConvertTo-Json
}finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
