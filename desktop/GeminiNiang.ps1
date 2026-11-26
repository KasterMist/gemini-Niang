param(
  [switch]$CheckOnly,[switch]$NoRefresh,[switch]$TestMode,[switch]$ShowInTaskbar,
  [string]$StateDir=(Join-Path $env:LOCALAPPDATA 'GeminiNiang\state'),
  [string]$HostExecutablePath=(Join-Path $env:LOCALAPPDATA 'Programs\antigravity\Antigravity.exe'),
  [ValidateRange(0,3600)][int]$AutoCloseSeconds=0
)
$ErrorActionPreference='Stop'
$script:root=Split-Path $PSScriptRoot -Parent
$script:appVersion=([IO.File]::ReadAllText((Join-Path $script:root 'package.json'))|ConvertFrom-Json).version
$script:stateDir=[IO.Path]::GetFullPath($StateDir)
$script:assetDir=Join-Path $script:root 'assets\characters\gemini\png'
$script:actions=@('idle','blink','wave','happy','think','sleep')
$script:views=@('bust','full','side','back')
. (Join-Path $PSScriptRoot 'native.ps1')
foreach($view in $script:views){foreach($action in $script:actions){if(!(Test-Path (Join-Path $script:assetDir "$view-$action.png"))){throw "Missing asset: $view-$action"}}}
foreach($file in @('ui.ps1','widget.xaml','menu-resources.xaml','media.ps1','audio.ps1','audio-import.mjs','music-import.mjs','assets/press.wav','assets/release.wav')){if(!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)){throw "Missing desktop file: $file"}}
if($CheckOnly){
  [pscustomobject]@{ok=$true;assets=24;stateDir=$script:stateDir;hostExecutableExists=(Test-Path -LiteralPath $HostExecutablePath);host=[GeminiNiangNative]::FindHost($HostExecutablePath,0)}|ConvertTo-Json -Depth 4
  return
}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$null=New-Item -ItemType Directory -Path $script:stateDir -Force
function Read-Json($file){try{Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json}catch{$null}}
function Write-Json($file,$value){
  $temp=$file+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
  [IO.File]::WriteAllText($temp,($value|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
  if(Test-Path -LiteralPath $file){[IO.File]::Replace($temp,$file,($file+'.bak'))}else{[IO.File]::Move($temp,$file)}
}
$script:prefs=@{view='bust';action='idle';size=240;followHost=$true;paused=$false;right=16;bottom=16;group=0;completion=$true;collapsed=$false;autoQuoteEnabled=$false;autoQuoteIntervalSeconds=300;soundOn=$false;soundVolume=.35;musicVolume=.35}
$saved=Read-Json (Join-Path $script:stateDir 'preferences.json')
if($saved){
  if($saved.view-in $script:views){$script:prefs.view=$saved.view}
  if($saved.action-in $script:actions){$script:prefs.action=$saved.action}
  if($saved.size-in @(180,240,300)){$script:prefs.size=[int]$saved.size}
  foreach($key in @('completion','collapsed','paused','autoQuoteEnabled','soundOn')){if($saved.$key-is [bool]){$script:prefs[$key]=$saved.$key}}
  foreach($key in @('soundVolume','musicVolume')){try{$v=[double]$saved.$key;if($null-ne $saved.$key-and ![double]::IsNaN($v)-and ![double]::IsInfinity($v)-and $v-ge 0-and $v-le 1){$script:prefs[$key]=$v}}catch{}}
  if($saved.autoQuoteIntervalSeconds-in @(60,300,900)){$script:prefs.autoQuoteIntervalSeconds=[int]$saved.autoQuoteIntervalSeconds}
  foreach($key in @('desktopLeft','desktopTop')){if(($saved.$key-is [int] -or $saved.$key-is [long])-and [Math]::Abs([double]$saved.$key)-le 100000){$script:prefs[$key]=[int]$saved.$key}}
  if($saved.group-is [int] -or $saved.group-is [long]){$script:prefs.group=[Math]::Max(0,[int]$saved.group)}
  if($saved.followHost-is [bool]){$script:prefs.followHost=$saved.followHost}
  foreach($key in @('right','bottom')){if($null-ne $saved.$key){$script:prefs[$key]=[Math]::Max(0,[Math]::Min(2000,[int]$saved.$key))}}
}
$mutexId='Local\GeminiNiang-'+([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script:stateDir)).Replace('/','_'))
$script:mutex=[Threading.Mutex]::new($false,$mutexId)
try{$owned=$script:mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true}
if(!$owned){$script:mutex.Dispose();return}
Remove-Item -LiteralPath (Join-Path $script:stateDir 'stop.flag') -ErrorAction SilentlyContinue
$script:images=@{}
foreach($view in $script:views){foreach($action in $script:actions){
  $bitmap=[Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption='OnLoad';$bitmap.UriSource=[Uri](Join-Path $script:assetDir "$view-$action.png");$bitmap.EndInit();$bitmap.Freeze();$script:images["$view-$action"]=$bitmap
}}
. (Join-Path $PSScriptRoot 'ui.ps1')
Initialize-GeminiUi
$script:owner=[Windows.Interop.WindowInteropHelper]::new($script:window)
$script:hostHandle=0L;$script:clock=0.0;$script:refreshProcess=$null;$script:lastRefresh=[DateTime]::MinValue;$script:noticeUntil=[DateTime]::MinValue;$script:started=[DateTime]::UtcNow
$script:seen=[Collections.Generic.HashSet[string]]::new();$script:seenQueue=[Collections.Generic.Queue[string]]::new()
function Start-Refresh {
  if($NoRefresh){return}
  if($script:refreshProcess){if(!$script:refreshProcess.HasExited){return};$script:refreshProcess.Dispose();$script:refreshProcess=$null}
  $node=(Get-Command node.exe -ErrorAction SilentlyContinue).Source
  if(!$node){$script:text.Text='需要 Node.js 20 或更新版本。';return}
  $env:GEMINI_NIANG_STATE_DIR=$script:stateDir
  $args='"'+(Join-Path $script:root 'antigravity\scripts\refresh.mjs')+'"'
  $script:refreshProcess=Start-Process -FilePath $node -ArgumentList $args -WindowStyle Hidden -PassThru
  $script:lastRefresh=[DateTime]::UtcNow
}
$script:ui.Refresh.Add_Click({Start-Refresh})
$script:avatar.Add_MouseLeftButtonDown({
  Play-WidgetPressSound
  $before=[GeminiNiangNative]::Frame($script:owner.Handle.ToInt64())
  $script:dragging=$true
  try{$script:window.DragMove()}finally{$script:dragging=$false;Play-WidgetReleaseSound}
  $after=[GeminiNiangNative]::Frame($script:owner.Handle.ToInt64())
  $hostFrame=if($script:prefs.followHost-and $script:hostHandle){[GeminiNiangNative]::Frame($script:hostHandle)}else{$null}
  if(!(Save-GeminiPosition $before $after $hostFrame)){
    Set-GeminiBubble (-not ($script:bubble.Visibility-eq 'Visible'));if($script:bubble.Visibility-eq 'Visible'){$script:bubbleMode='quota';Start-Refresh};Save-Preferences
  }
})
function Update-Host {
  if($script:dragging){return}
  $hostWindow=if($script:prefs.followHost){[GeminiNiangNative]::FindHost($HostExecutablePath,$script:hostHandle)}else{$null}
  if($script:prefs.followHost-and !$hostWindow){if($script:window.IsVisible){$script:window.Hide()};$script:hostHandle=0L;return}
  if($hostWindow){
    if($script:owner.Owner.ToInt64()-ne $hostWindow.handle){$script:owner.Owner=[IntPtr]$hostWindow.handle}
    $script:hostHandle=$hostWindow.handle
    if(!$script:window.IsVisible){$script:window.Show()}
    $rect=[GeminiNiangNative]::Frame($script:owner.Handle.ToInt64())
    $position=Get-GeminiPlacement $hostWindow ($rect.Right-$rect.Left) ($rect.Bottom-$rect.Top) ($hostWindow.right-($rect.Right-$rect.Left)-$script:prefs.right) ($hostWindow.bottom-($rect.Bottom-$rect.Top)-$script:prefs.bottom)
    [GeminiNiangNative]::Move($script:owner.Handle.ToInt64(),$position.x,$position.y)
  }else{
    $script:owner.Owner=[IntPtr]::Zero;$script:hostHandle=0L
    if(!$script:window.IsVisible){$script:window.Show()}
    if(!$script:desktopRestored){
      $rect=[GeminiNiangNative]::Frame($script:owner.Handle.ToInt64());$x=$rect.left;$y=$rect.top
      if($script:prefs.ContainsKey('desktopLeft')){$x=$script:prefs.desktopLeft};if($script:prefs.ContainsKey('desktopTop')){$y=$script:prefs.desktopTop}
      $bounds=[GeminiNiangNative]::WorkArea($x,$y);$position=Get-GeminiPlacement $bounds ($rect.right-$rect.left) ($rect.bottom-$rect.top) $x $y
      [GeminiNiangNative]::Move($script:owner.Handle.ToInt64(),$position.x,$position.y);$script:desktopRestored=$true
    }
  }
}
function Update-Events {
  $folder=Join-Path $script:stateDir 'events'
  foreach($file in @(Get-ChildItem -LiteralPath $folder -Filter '*.json' -File -ErrorAction SilentlyContinue)){
    if($script:seen.Contains($file.BaseName)){continue}
    $event=Read-Json $file.FullName
    if(!$event-or $event.type-ne 'completed'-or !$event.at){continue}
    $null=$script:seen.Add($file.BaseName);$script:seenQueue.Enqueue($file.BaseName)
    if($script:seenQueue.Count-gt 256){$null=$script:seen.Remove($script:seenQueue.Dequeue())}
    if(([DateTime]$event.at).ToUniversalTime()-lt $script:started){continue}
    if($script:prefs.completion){$script:noticeUntil=[DateTime]::UtcNow.AddSeconds(6);$script:noticeRestorePending=$true;$script:autoQuoteUntil=0;Set-GeminiBubble $true -Transient}
  }
}
$script:timer=[Windows.Threading.DispatcherTimer]::new();$script:timer.Interval=[TimeSpan]::FromMilliseconds(100);$script:ticks=0
$script:timer.Add_Tick({
  try{
    if(Test-Path -LiteralPath (Join-Path $script:stateDir 'stop.flag')){$script:window.Close();return}
    if(!$script:prefs.paused){$script:clock+=.1}
    $t=$script:clock%4;$phase=$t*[Math]::PI/2
    $action=if([DateTime]::UtcNow-lt $script:noticeUntil){'happy'}else{$script:prefs.action}
    $pose=$action;$angle=0.0;$y=0.0;$sy=1.0
    switch($action){
      'idle'{if($t-ge 2.7-and $t-lt 2.9){$pose='blink'};$y=-2*(1-[Math]::Cos($phase));$sy=1+.005*[Math]::Sin($phase)}
      'blink'{$pose=if(($t%2)-ge 1.6-and ($t%2)-lt 1.85){'blink'}else{'idle'}}
      'wave'{$angle=1.4*[Math]::Sin($phase*2);$y=-2*(1-[Math]::Cos($phase*2))}
      'happy'{$y=-10*(1-[Math]::Cos($phase*2));$angle=.7*[Math]::Sin($phase*2)}
      'think'{$angle=1.3*[Math]::Sin($phase)}
      'sleep'{$sy=1+.008*[Math]::Sin($phase);$angle=.45*[Math]::Sin($phase)}
    }
    Update-GeminiMusic
    if($script:music.mode-eq 'playing'-and !$script:prefs.paused-and !$script:dragging-and [DateTime]::UtcNow-ge $script:noticeUntil){
      $musicMotion=Get-GeminiMusicMotion (Get-GeminiMusicLevel $script:music.player.Position.TotalSeconds)
      $y+=$musicMotion.y;$sy*=$musicMotion.scale;$angle+=$musicMotion.angle
    }
    $script:avatar.Source=$script:images[($script:prefs.view+'-'+$pose)]
    $script:scale.ScaleX=1;$script:scale.ScaleY=$sy;$script:rotate.Angle=$angle;$script:translate.Y=$y*$script:prefs.size/512
    if(($script:ticks%5)-eq 0){Update-Host;Update-Events;Update-GeminiScenes;Update-Status}
    if(($script:ticks%20)-eq 0){Write-Json (Join-Path $script:stateDir 'widget-runtime.json') @{version=$script:appVersion;pid=$PID;handle=$script:owner.Handle.ToInt64();host=$script:hostHandle;view=$script:prefs.view;action=$action;paused=$script:prefs.paused;autoQuoteEnabled=$script:autoQuoteEnabled;soundOn=$script:soundOn;audioReady=[bool]$script:geminiNiangAudio;musicMode=$script:music.mode;testMode=[bool]$TestMode;nativeVisible=[GeminiNiangNative]::IsWindowVisible($script:owner.Handle);noticeActive=([DateTime]::UtcNow-lt $script:noticeUntil);bubbleVisible=($script:bubble.Visibility-eq 'Visible');at=[DateTime]::UtcNow.ToString('o')}}
    if(([DateTime]::UtcNow-$script:lastRefresh).TotalSeconds-ge 120){Start-Refresh}
    if($AutoCloseSeconds-gt 0-and ([DateTime]::UtcNow-$script:started).TotalSeconds-ge $AutoCloseSeconds){$script:window.Close()}
    $script:ticks++
  }catch{[IO.File]::WriteAllText((Join-Path $script:stateDir 'widget-error.txt'),$_.Exception.ToString())}
})
$script:window.Add_Closed({$script:timer.Stop();Close-GeminiMedia;if($script:quoteEditor){$script:quoteEditor.Close()}})
try{
  $script:timer.Start();$script:window.Show();Update-Host;Start-Refresh
  $app=[Windows.Application]::new();$app.ShutdownMode='OnExplicitShutdown'
  $script:window.Add_Closed({$app.Shutdown()})
  $null=$app.Run()
}finally{
  $script:timer.Stop()
  Close-GeminiMedia
  if($script:refreshProcess){$script:refreshProcess.Dispose()}
  try{$runtime=Read-Json (Join-Path $script:stateDir 'widget-runtime.json');if($runtime.pid-eq $PID){Remove-Item -LiteralPath (Join-Path $script:stateDir 'widget-runtime.json') -ErrorAction SilentlyContinue}}catch{}
  $script:mutex.ReleaseMutex();$script:mutex.Dispose()
}
