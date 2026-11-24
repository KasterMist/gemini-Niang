param(
  [switch]$CheckOnly,[switch]$NoRefresh,[switch]$TestMode,
  [string]$StateDir=(Join-Path $env:LOCALAPPDATA 'GeminiNiang\state'),
  [string]$HostExecutablePath=(Join-Path $env:LOCALAPPDATA 'Programs\antigravity\Antigravity.exe'),
  [ValidateRange(0,3600)][int]$AutoCloseSeconds=0
)
$ErrorActionPreference='Stop'
$script:root=Split-Path $PSScriptRoot -Parent
$script:stateDir=[IO.Path]::GetFullPath($StateDir)
$script:assetDir=Join-Path $script:root 'assets\characters\gemini\png'
$script:actions=@('idle','blink','wave','happy','think','sleep')
. (Join-Path $PSScriptRoot 'native.ps1')
foreach($view in @('bust','full')){foreach($action in $script:actions){if(!(Test-Path (Join-Path $script:assetDir "$view-$action.png"))){throw "Missing asset: $view-$action"}}}
if($CheckOnly){
  [pscustomobject]@{ok=$true;assets=12;stateDir=$script:stateDir;hostExecutableExists=(Test-Path -LiteralPath $HostExecutablePath);host=[GeminiNiangNative]::FindHost($HostExecutablePath,0)}|ConvertTo-Json -Depth 4
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
$script:prefs=@{view='bust';action='idle';size=240;followHost=$true;paused=$false;right=16;bottom=16}
$saved=Read-Json (Join-Path $script:stateDir 'preferences.json')
if($saved){
  if($saved.view-in @('bust','full')){$script:prefs.view=$saved.view}
  if($saved.action-in $script:actions){$script:prefs.action=$saved.action}
  if($saved.size-in @(180,240,300)){$script:prefs.size=[int]$saved.size}
  if($saved.followHost-is [bool]){$script:prefs.followHost=$saved.followHost}
  foreach($key in @('right','bottom')){if($null-ne $saved.$key){$script:prefs[$key]=[Math]::Max(0,[Math]::Min(2000,[int]$saved.$key))}}
}
$mutexId='Local\GeminiNiang-'+([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($script:stateDir)).Replace('/','_'))
$script:mutex=[Threading.Mutex]::new($false,$mutexId)
try{$owned=$script:mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true}
if(!$owned){$script:mutex.Dispose();return}
Remove-Item -LiteralPath (Join-Path $script:stateDir 'stop.flag') -ErrorAction SilentlyContinue
$script:images=@{}
foreach($view in @('bust','full')){foreach($action in $script:actions){
  $bitmap=[Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption='OnLoad';$bitmap.UriSource=[Uri](Join-Path $script:assetDir "$view-$action.png");$bitmap.EndInit();$bitmap.Freeze();$script:images["$view-$action"]=$bitmap
}}
$script:window=[Windows.Window]::new()
$script:window.Title='Gemini 娘';$script:window.WindowStyle='None';$script:window.AllowsTransparency=$true;$script:window.Background=[Windows.Media.Brushes]::Transparent
$script:window.SizeToContent='WidthAndHeight';$script:window.ResizeMode='NoResize';$script:window.ShowInTaskbar=[bool]$TestMode;$script:window.ShowActivated=$false
$script:window.Left=100;$script:window.Top=180
$panel=[Windows.Controls.StackPanel]::new();$script:window.Content=$panel
$script:bubble=[Windows.Controls.Border]::new();$script:bubble.Width=300;$script:bubble.Padding='14';$script:bubble.CornerRadius='14';$script:bubble.BorderThickness='1';$script:bubble.BorderBrush=[Windows.Media.BrushConverter]::new().ConvertFromString('#BBA9D8');$script:bubble.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#FFF9F6FF');$script:bubble.Visibility='Collapsed'
$bubblePanel=[Windows.Controls.StackPanel]::new();$script:bubble.Child=$bubblePanel
$script:text=[Windows.Controls.TextBlock]::new();$script:text.TextWrapping='Wrap';$script:text.FontSize=12;$script:text.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#40305D');$bubblePanel.Children.Add($script:text)|Out-Null
$refreshButton=[Windows.Controls.Button]::new();$refreshButton.Content='刷新额度';$refreshButton.Margin='0,8,0,0';$bubblePanel.Children.Add($refreshButton)|Out-Null
$panel.Children.Add($script:bubble)|Out-Null
$script:avatar=[Windows.Controls.Image]::new();$script:avatar.Width=$script:prefs.size;$script:avatar.Height=$script:prefs.size;$script:avatar.Stretch='Uniform';$script:avatar.ToolTip='单击查看额度，拖动移动，右键切换形态和动作'
$script:avatar.RenderTransformOrigin=[Windows.Point]::new(.5,.9)
$script:transforms=[Windows.Media.TransformGroup]::new();$script:scale=[Windows.Media.ScaleTransform]::new();$script:rotate=[Windows.Media.RotateTransform]::new();$script:translate=[Windows.Media.TranslateTransform]::new()
$script:transforms.Children.Add($script:scale);$script:transforms.Children.Add($script:rotate);$script:transforms.Children.Add($script:translate);$script:avatar.RenderTransform=$script:transforms
$panel.Children.Add($script:avatar)|Out-Null
$script:menu=[Windows.Controls.ContextMenu]::new();$script:window.ContextMenu=$script:menu
function Save-Preferences {Write-Json (Join-Path $script:stateDir 'preferences.json') $script:prefs}
function Add-MenuItem($parent,$label,[scriptblock]$handler){$item=[Windows.Controls.MenuItem]::new();$item.Header=$label;$item.Add_Click($handler);$parent.Items.Add($item)|Out-Null;return $item}
$shapeMenu=[Windows.Controls.MenuItem]::new();$shapeMenu.Header='出场形态';$script:menu.Items.Add($shapeMenu)|Out-Null
foreach($pair in @(@('bust','半身挂件'),@('full','全身伙伴'))){$item=Add-MenuItem $shapeMenu $pair[1] { $script:prefs.view=$this.Tag;Save-Preferences };$item.Tag=$pair[0]}
$actionMenu=[Windows.Controls.MenuItem]::new();$actionMenu.Header='动作';$script:menu.Items.Add($actionMenu)|Out-Null
$labels=@('待机','眨眼','招手','开心','思考','困倦')
for($i=0;$i-lt 6;$i++){$item=Add-MenuItem $actionMenu $labels[$i] {$script:prefs.action=$this.Tag;$script:clock=0;Save-Preferences};$item.Tag=$script:actions[$i]}
$sizeMenu=[Windows.Controls.MenuItem]::new();$sizeMenu.Header='大小';$script:menu.Items.Add($sizeMenu)|Out-Null
foreach($size in @(180,240,300)){$item=Add-MenuItem $sizeMenu ([string]$size+' px') {$script:prefs.size=[int]$this.Tag;$script:avatar.Width=$script:prefs.size;$script:avatar.Height=$script:prefs.size;Save-Preferences};$item.Tag=$size}
$script:followItem=Add-MenuItem $script:menu '跟随 Antigravity 窗口' {$script:prefs.followHost=!$script:prefs.followHost;$script:followItem.IsChecked=$script:prefs.followHost;Save-Preferences}
$script:followItem.IsCheckable=$true;$script:followItem.IsChecked=$script:prefs.followHost
$script:pauseItem=Add-MenuItem $script:menu '暂停动画' {$script:prefs.paused=!$script:prefs.paused;$script:pauseItem.IsChecked=$script:prefs.paused}
$script:pauseItem.IsCheckable=$true
$null=Add-MenuItem $script:menu '刷新额度' {Start-Refresh;$script:bubble.Visibility='Visible'}
$null=Add-MenuItem $script:menu '退出 Gemini 娘' {$script:window.Close()}
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
$refreshButton.Add_Click({Start-Refresh})
$script:avatar.Add_MouseLeftButtonDown({
  $before=[GeminiNiangNative]::Frame($script:owner.Handle.ToInt64())
  $script:window.DragMove()
  $after=[GeminiNiangNative]::Frame($script:owner.Handle.ToInt64())
  if([Math]::Abs($before.Left-$after.Left)+[Math]::Abs($before.Top-$after.Top)-lt 4){
    if($script:bubble.Visibility-eq 'Visible'){$script:bubble.Visibility='Collapsed'}else{$script:bubble.Visibility='Visible';Start-Refresh}
  }elseif($script:prefs.followHost-and $script:hostHandle){
    $hostFrame=[GeminiNiangNative]::Frame($script:hostHandle)
    $script:prefs.right=[Math]::Max(0,$hostFrame.Right-$after.Right);$script:prefs.bottom=[Math]::Max(0,$hostFrame.Bottom-$after.Bottom);Save-Preferences
  }
})
function Update-Status {
  $lines=[Collections.Generic.List[string]]::new();$lines.Add('Gemini 娘 · Antigravity')
  if([DateTime]::UtcNow-lt $script:noticeUntil){$lines.Add($(if($TestMode){'任务已完成（模拟事件验证）'}else{'任务已完成 ✦'}))}
  $usage=Read-Json (Join-Path $script:stateDir 'usage.json')
  if(!$usage){$lines.Add('尚未读取额度，单击刷新。')}
  elseif(!$usage.ok){$lines.Add([string]$usage.message)}
  elseif(([DateTime]::UtcNow-([DateTime]$usage.observedAt).ToUniversalTime()).TotalSeconds-gt 300){$lines.Add('额度已过期，请刷新；不显示旧余额。')}
  else{
    foreach($group in @($usage.groups)){
      $lines.Add([string]$group.name)
      foreach($bucket in @($group.buckets)){
        $name=switch($bucket.window){'5h'{'5小时'}'weekly'{'每周'}default{$bucket.window}}
        $reset=if($bucket.resetsAt){([DateTime]$bucket.resetsAt).ToLocalTime().ToString('MM-dd HH:mm')}else{'未知'}
        $lines.Add(('  {0} 剩余 {1}% · 重置 {2}' -f $name,$bucket.remaining,$reset))
      }
    }
    if($usage.source-eq 'antigravity-cli'){$lines.Add('来源：官方 CLI 只读查询')}else{$lines.Add('测试数据，非真实额度')}
  }
  $script:text.Text=$lines -join "`n"
}
function Update-Host {
  $hostWindow=if($script:prefs.followHost){[GeminiNiangNative]::FindHost($HostExecutablePath,$script:hostHandle)}else{$null}
  if($script:prefs.followHost-and !$hostWindow){if($script:window.IsVisible){$script:window.Hide()};$script:hostHandle=0L;return}
  if($hostWindow){
    if($script:owner.Owner.ToInt64()-ne $hostWindow.handle){$script:owner.Owner=[IntPtr]$hostWindow.handle}
    $script:hostHandle=$hostWindow.handle
    if(!$script:window.IsVisible){$script:window.Show()}
    $rect=[GeminiNiangNative]::Frame($script:owner.Handle.ToInt64())
    $x=[Math]::Max($hostWindow.left,$hostWindow.right-($rect.Right-$rect.Left)-$script:prefs.right)
    $y=[Math]::Max($hostWindow.top,$hostWindow.bottom-($rect.Bottom-$rect.Top)-$script:prefs.bottom)
    [GeminiNiangNative]::Move($script:owner.Handle.ToInt64(),$x,$y)
  }else{
    $script:owner.Owner=[IntPtr]::Zero;$script:hostHandle=0L
    if(!$script:window.IsVisible){$script:window.Show()}
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
    $script:noticeUntil=[DateTime]::UtcNow.AddSeconds(6);$script:bubble.Visibility='Visible'
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
    $script:avatar.Source=$script:images[($script:prefs.view+'-'+$pose)]
    $script:scale.ScaleX=.88;$script:scale.ScaleY=.88*$sy;$script:rotate.Angle=$angle;$script:translate.Y=$y*$script:prefs.size/512
    if(($script:ticks%5)-eq 0){Update-Host;Update-Events;Update-Status}
    if(($script:ticks%20)-eq 0){Write-Json (Join-Path $script:stateDir 'widget-runtime.json') @{pid=$PID;handle=$script:owner.Handle.ToInt64();host=$script:hostHandle;view=$script:prefs.view;action=$action;testMode=[bool]$TestMode;nativeVisible=[GeminiNiangNative]::IsWindowVisible($script:owner.Handle);noticeActive=([DateTime]::UtcNow-lt $script:noticeUntil);bubbleVisible=($script:bubble.Visibility-eq 'Visible');at=[DateTime]::UtcNow.ToString('o')}}
    if(([DateTime]::UtcNow-$script:lastRefresh).TotalSeconds-ge 120){Start-Refresh}
    if($AutoCloseSeconds-gt 0-and ([DateTime]::UtcNow-$script:started).TotalSeconds-ge $AutoCloseSeconds){$script:window.Close()}
    $script:ticks++
  }catch{[IO.File]::WriteAllText((Join-Path $script:stateDir 'widget-error.txt'),$_.Exception.ToString())}
})
$script:window.Add_Closed({$script:timer.Stop()})
try{
  $script:timer.Start();$script:window.Show();Update-Host;Start-Refresh
  $app=[Windows.Application]::new();$app.ShutdownMode='OnExplicitShutdown'
  $script:window.Add_Closed({$app.Shutdown()})
  $null=$app.Run()
}finally{
  $script:timer.Stop()
  if($script:refreshProcess){$script:refreshProcess.Dispose()}
  try{$runtime=Read-Json (Join-Path $script:stateDir 'widget-runtime.json');if($runtime.pid-eq $PID){Remove-Item -LiteralPath (Join-Path $script:stateDir 'widget-runtime.json') -ErrorAction SilentlyContinue}}catch{}
  $script:mutex.ReleaseMutex();$script:mutex.Dispose()
}
