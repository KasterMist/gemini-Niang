param(
  [string]$AgyPath,
  [string]$StateDir=(Join-Path $env:LOCALAPPDATA 'GeminiNiang\state'),
  [switch]$CheckOnly,[switch]$DownloadCli,[switch]$RegisterPlugin,[switch]$StartWidget
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$node=Get-Command node.exe -ErrorAction SilentlyContinue
if(!$node){throw 'Node.js 20+ is required.'}
if([int]((& $node.Source --version).TrimStart('v').Split('.')[0])-lt 20){throw 'Node.js 20+ is required.'}
if(!$AgyPath){
  $command=Get-Command agy.exe -ErrorAction SilentlyContinue
  if($command){$AgyPath=$command.Source}
  else{foreach($candidate in @((Join-Path $env:LOCALAPPDATA 'agy\bin\agy.exe'),(Join-Path $env:LOCALAPPDATA 'GeminiNiang\bin\agy.exe'))){if(Test-Path -LiteralPath $candidate){$AgyPath=$candidate;break}}}
}
if(!$AgyPath-and $DownloadCli-and !$CheckOnly){
  $arch=if($env:PROCESSOR_ARCHITEW6432){$env:PROCESSOR_ARCHITEW6432}else{$env:PROCESSOR_ARCHITECTURE}
  $platform=switch($arch){'AMD64'{'windows_amd64'}'ARM64'{'windows_arm64'}default{throw 'Unsupported CPU architecture'}}
  $manifest=Invoke-RestMethod ('https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/'+$platform+'.json')
  if($manifest.url-notlike 'https://storage.googleapis.com/antigravity-public/antigravity-cli/*'-or $manifest.sha512-notmatch '^[a-fA-F0-9]{128}$'){throw 'Unexpected CLI manifest source or hash'}
  $bin=Join-Path $env:LOCALAPPDATA 'GeminiNiang\bin';$null=New-Item -ItemType Directory -Path $bin -Force
  $temp=Join-Path $bin ('download-'+[Guid]::NewGuid().ToString('N')+'.tmp')
  try{
    Invoke-WebRequest -Uri $manifest.url -OutFile $temp -UseBasicParsing
    if((Get-FileHash -LiteralPath $temp -Algorithm SHA512).Hash-ine $manifest.sha512){throw 'CLI SHA512 verification failed'}
    $AgyPath=Join-Path $bin 'agy.exe'
    # Do not replace an installation that appeared concurrently.
    if(Test-Path -LiteralPath $AgyPath){throw 'CLI path appeared concurrently; retry installer'}
    [IO.File]::Move($temp,$AgyPath)
  }finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp}}
}
if(!$AgyPath-or !(Test-Path -LiteralPath $AgyPath -PathType Leaf)){throw 'Antigravity CLI not found. Supply -AgyPath or explicitly use -DownloadCli.'}
$AgyPath=[IO.Path]::GetFullPath($AgyPath)
$version=(& $AgyPath --version|Out-String).Trim();if($LASTEXITCODE-ne 0){throw 'CLI version check failed'}
$parsed=$null;if(![Version]::TryParse(($version -replace '^v',''),[ref]$parsed)-or $parsed-lt [Version]'1.1.11'){throw 'CLI 1.1.11+ required for read-only /usage'}
& $AgyPath plugin validate --strict (Join-Path $root 'antigravity')
if($LASTEXITCODE-ne 0){throw 'Official Antigravity plugin validation failed'}
if($CheckOnly){@{ok=$true;cli=$AgyPath;version=$version;registerPlugin=[bool]$RegisterPlugin}|ConvertTo-Json;return}
$StateDir=[IO.Path]::GetFullPath($StateDir);$null=New-Item -ItemType Directory -Path $StateDir -Force
$file=Join-Path $StateDir 'config.json';$backup=$null;$config=@{}
if(Test-Path -LiteralPath $file){
  $original=Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json
  foreach($property in $original.PSObject.Properties){$config[$property.Name]=$property.Value}
  $backup=$file+'.'+[DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')+'.bak';Copy-Item -LiteralPath $file -Destination $backup
}
$config.agyPath=$AgyPath;$config.nodePath=$node.Source;$config.version='0.2.0'
try{
  $temp=$file+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
  [IO.File]::WriteAllText($temp,($config|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
  if(Test-Path -LiteralPath $file){[IO.File]::Replace($temp,$file,($file+'.previous.bak'))}else{[IO.File]::Move($temp,$file)}
  if($RegisterPlugin){
    & $AgyPath plugin install (Join-Path $root 'antigravity')
    if($LASTEXITCODE-ne 0){throw 'Plugin install failed; local configuration will be restored'}
  }
}catch{
  if($backup){Copy-Item -LiteralPath $backup -Destination $file -Force}else{Remove-Item -LiteralPath $file -ErrorAction SilentlyContinue}
  throw
}
Write-Output ('Gemini Niang configured. CLI='+$version+'; state='+$StateDir+'; pluginRegistered='+[bool]$RegisterPlugin)
if($backup){Write-Output ('Previous config backup='+$backup)}
Write-Output 'No autostart, scheduled task, PATH or Codex configuration was changed.'
if($StartWidget){
  $args='-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $root 'desktop\GeminiNiang.ps1')+'" -StateDir "'+$StateDir+'"'
  Start-Process powershell.exe -ArgumentList $args -WindowStyle Hidden
}
