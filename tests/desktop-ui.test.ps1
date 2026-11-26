param([Parameter(Mandatory=$true)][string]$StateDir,[string]$CaptureDir)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$script:root=Split-Path $PSScriptRoot -Parent
$script:stateDir=$StateDir;$null=New-Item -ItemType Directory -Path $StateDir -Force
$TestMode=$true;$ShowInTaskbar=$true
$script:actions=@('idle','blink','wave','happy','think','sleep')
$script:prefs=@{view='bust';action='idle';size=240;followHost=$false;paused=$false;right=16;bottom=16;group=0;completion=$true;collapsed=$false}
$script:noticeUntil=[DateTime]::MinValue
function Read-Json($file){try{Get-Content -LiteralPath $file -Raw -Encoding UTF8|ConvertFrom-Json}catch{$null}}
function Write-Json($file,$value){[IO.File]::WriteAllText($file,($value|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))}
function Start-Refresh {$script:refreshRequested=$true}
function Assert-Ui($value,$name){if(!$value){throw "UI assertion failed: $name"};$script:checks.Add($name)}
function Click-Item($item){$item.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent,$item))}
function Render-Ui($visual,$file){
  $visual.UpdateLayout();$width=[int][Math]::Ceiling($visual.ActualWidth);$height=[int][Math]::Ceiling($visual.ActualHeight)
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new($width,$height,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($visual)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$stream=[IO.File]::Create($file)
  try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
$script:checks=[Collections.Generic.List[string]]::new()
. (Join-Path $script:root 'desktop/ui.ps1')
Initialize-GeminiUi
$image=[Windows.Media.Imaging.BitmapImage]::new([Uri](Join-Path $script:root 'assets/characters/gemini/png/bust-idle.png'));$script:avatar.Source=$image
$usage=@{ok=$true;observedAt=[DateTime]::UtcNow.ToString('o');source='ui-test';groups=@(@{name='Gemini Models · 测试';buckets=@(@{window='5h';remaining=100;resetsAt=$null},@{window='weekly';remaining=69;resetsAt='2026-11-30T02:20:00Z'})},@{name='Claude and GPT · 测试';buckets=@(@{window='weekly';remaining=0;resetsAt=$null})})}
$script:window.Show()
try {
  Write-Json (Join-Path $StateDir 'usage.json') $usage;Update-Status;Sync-GeminiMenu
  Assert-Ui ($script:ui.ShortLeft.Text-eq '100%') '5h percentage'
  Assert-Ui ($script:ui.Header.Text-eq 'Gemini 剩余额度') 'selected model group visible in header'
  Assert-Ui ($script:ui.WeekLeft.Text-eq '69%') 'weekly percentage'
  Assert-Ui ($script:ui.ShortBar.Width-eq 184) 'progress width 100 percent'
  Assert-Ui ($script:ui.ShortReset.Text-eq '重置时间未知') 'unknown reset is explicit'
  Assert-Ui ($script:bubble.ToolTip-like '*测试数据*') 'fixture not represented as real quota'
  Assert-Ui ($script:menu.Items[0].Style-eq $script:menuResources['SettingsItem']) 'upstream styled menu applied'
  if($CaptureDir){$null=New-Item -ItemType Directory -Path $CaptureDir -Force;Render-Ui $script:window.Content (Join-Path $CaptureDir 'quota.png')}
  Click-Item $script:groupMenu.Items[1]
  Assert-Ui ($script:ui.Header.Text-eq 'Claude / GPT 额度') 'switched group visible in header'
  Assert-Ui ($script:ui.WeekLeft.Text-eq '0%') 'model group switch preserves zero'
  Assert-Ui ($script:ui.ShortLeft.Text-eq '—') 'missing window not fabricated'
  Assert-Ui ($script:ui.ShortBar.Width-eq 0) 'missing window clears progress'
  Click-Item $script:shapeMenu.Items[3];Sync-GeminiMenu
  Assert-Ui ($script:actionMenu.Items[1].Header-eq '耳朵轻动') 'back action accurately labeled'
  Assert-Ui $script:shapeMenu.Items[3].IsChecked 'selected shape checkmark'
  Click-Item $script:sizeMenu.Items[2]
  Assert-Ui ($script:window.Width-gt 540) 'appearance scale changes whole composition'
  $script:completionItem.IsChecked=$false;Click-Item $script:completionItem
  Assert-Ui (!$script:prefs.completion) 'completion toggle saved'
  Assert-Ui (!(Read-Json (Join-Path $StateDir 'preferences.json')).completion) 'preference disk roundtrip'
  $script:refreshRequested=$false;Click-Item $script:menu.Items[1]
  Assert-Ui $script:refreshRequested 'refresh menu calls provider bridge'
  Show-GeminiQuote
  Assert-Ui ($script:ui.QuoteText.Visibility-eq 'Visible') 'quote scene'
  $script:bubbleMode='quota';$usage.observedAt=[DateTime]::UtcNow.AddMinutes(-6).ToString('o');Write-Json (Join-Path $StateDir 'usage.json') $usage;Update-Status
  Assert-Ui ($script:ui.QuotaText.Visibility-eq 'Collapsed' -and $script:text.Text-like '*过期*') 'expired quota hidden'
  Write-Json (Join-Path $StateDir 'usage.json') @{ok=$false;message='读取失败，请重试'};Update-Status
  Assert-Ui ($script:ui.QuotaText.Visibility-eq 'Collapsed' -and $script:text.Text-like '*失败*') 'failed quota hidden'
  $script:noticeUntil=[DateTime]::UtcNow.AddSeconds(10);Update-Status
  Assert-Ui ($script:text.Text-like '*测试*') 'completion scene labeled simulation'
  $script:noticeUntil=[DateTime]::MinValue;Set-GeminiBubble $false
  Assert-Ui ($script:ui.Tail.Visibility-eq 'Hidden' -and $script:ui.Bubble.Visibility-eq 'Hidden') 'collapse hides whole bubble and tails'
  Set-GeminiBubble $true;$script:prefs.view='bust';$script:prefs.group=0;$script:prefs.size=240;Set-GeminiSize
  $usage.observedAt=[DateTime]::UtcNow.ToString('o');Write-Json (Join-Path $StateDir 'usage.json') $usage;Update-Status;Sync-GeminiMenu
  $script:menu.PlacementTarget=$script:ui.MenuButton;$script:menu.Placement='Left';$script:menu.IsOpen=$true;$script:menu.UpdateLayout()
  if($CaptureDir){Render-Ui $script:menu (Join-Path $CaptureDir 'menu.png')}
  $script:shapeMenu.IsSubmenuOpen=$true;$script:shapeMenu.UpdateLayout()
  $popup=$script:shapeMenu.Template.FindName('PART_Popup',$script:shapeMenu)
  Assert-Ui ($popup.IsOpen -and $popup.Child.ActualWidth-ge 280) 'styled submenu opens with real content'
  if($CaptureDir){Render-Ui $popup.Child (Join-Path $CaptureDir 'shapes.png')}
  $script:shapeMenu.IsSubmenuOpen=$false
  $script:menu.IsOpen=$false
  . (Join-Path $script:root 'desktop/native.ps1')
  $script:owner=[Windows.Interop.WindowInteropHelper]::new($script:window);$script:hostHandle=0;$script:prefs.paused=$false
  $originalTransform=$script:avatar.RenderTransform
  $TestMode=$false;$rejected=$false
  try{Set-GeminiSystemRhythm $true -Synthetic}catch{$rejected=$true}finally{$TestMode=$true}
  Assert-Ui $rejected 'synthetic audio forbidden outside test mode'
  Set-GeminiSystemRhythm $true -Synthetic
  Assert-Ui (Test-GeminiSystemRhythm) 'ported physics visual starts with synthetic input'
  $capture=$script:systemRhythm.GetType().GetField('capture',[Reflection.BindingFlags]'NonPublic,Instance').GetValue($script:systemRhythm)
  Assert-Ui ($null-eq $capture) 'synthetic visual creates no system audio capture worker'
  Assert-Ui ($script:systemRhythm.SyntheticAudio.Source-eq 'synthetic-test') 'synthetic source explicitly labeled'
  Set-GeminiAutoQuotes $true 60;Reset-WidgetAutoQuoteSchedule 1000
  for($now=1000;$now-le 62000;$now+=500){Update-GeminiScenes $now}
  Assert-Ui ($script:bubble.Visibility-eq 'Hidden') 'automatic quotes do not interrupt system rhythm'
  Set-GeminiAutoQuotes $false 300
  Stop-GeminiSystemRhythm
  Assert-Ui ([object]::ReferenceEquals($originalTransform,$script:avatar.RenderTransform)) 'stop restores original character transform'
  Assert-Ui (!(Test-GeminiSystemRhythm)) 'system mode is not persisted or auto restarted'
  Set-GeminiSystemRhythm $true -Synthetic;$script:window.Hide();Update-GeminiSystemRhythm
  Assert-Ui (!(Test-GeminiSystemRhythm)) 'hiding widget disposes the system rhythm controller'
  $script:window.Show()
  Click-Item $script:quoteEditorItem
  Assert-Ui $script:quoteEditor.IsVisible 'quote editor opens from real menu event'
  $script:quoteEditor.FindName('Lines').Text='0 | 无效权重'
  $script:quoteEditor.FindName('Save').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  Assert-Ui ($script:quoteEditor.FindName('Feedback').Text-like '*无效*') 'editor invalid input shows feedback'
  $script:quoteEditor.FindName('Lines').Text="3 | 今天也一起加油吧。`n2 | 今天也一起加油吧。"
  $script:quoteEditor.FindName('Save').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  Assert-Ui ($script:quoteEditor.FindName('Feedback').Text-like '*已保存 1*') 'editor save uses validated weighted pool'
  Assert-Ui ((Get-WidgetQuoteSettings $StateDir).quotes[0].weight-eq 5) 'editor merged weight persisted'
  if($CaptureDir){Render-Ui $script:quoteEditor.Content (Join-Path $CaptureDir 'quote-editor.png')}
  $script:quoteEditor.FindName('Done').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  Assert-Ui (!$script:quoteEditor.IsVisible) 'editor close button works'
  Show-GeminiQuote
  Assert-Ui ($script:text.Text-eq '今天也一起加油吧。') 'new custom quote immediately available'
  if($CaptureDir){Render-Ui $script:window.Content (Join-Path $CaptureDir 'custom-quote.png')}
  $long='星'*200;Set-GeminiMessage $long;$script:window.UpdateLayout()
  Assert-Ui ($script:text.Text.Length-eq 200 -and $script:text.FontSize-ge 8 -and $script:text.ActualHeight-le 115) '200 character quote fits text area'
  $script:bubble.ToolTip='200 字排版测试，不是个人语录'
  if($CaptureDir){Render-Ui $script:window.Content (Join-Path $CaptureDir 'long-quote.png')}
  $script:autoQuoteItem.IsChecked=$true;Click-Item $script:autoQuoteItem
  Assert-Ui $script:autoQuoteEnabled 'automatic quote toggle connected'
  Click-Item $script:autoQuoteMenu.Items[3]
  Assert-Ui ($script:autoQuoteIntervalSeconds-eq 900) 'automatic quote interval connected'
  $script:autoQuoteItem.IsChecked=$false;Click-Item $script:autoQuoteItem
  $script:pauseItem.IsChecked=$true;Click-Item $script:pauseItem
  Assert-Ui ((Read-Json (Join-Path $StateDir 'preferences.json')).paused) 'pause survives preference disk roundtrip'
  Set-GeminiBubble $false;$script:noticeRestorePending=$true;Set-GeminiBubble $true -Transient
  Update-GeminiScenes
  Assert-Ui ($script:bubble.Visibility-eq 'Hidden') 'completion expiry restores prior collapse in WPF'
  Sync-GeminiMenu
  Assert-Ui (!$script:soundOn-and !$script:soundPreview.IsEnabled) 'click sounds default off with disabled preview'
  Assert-Ui (!$script:musicPause.IsEnabled) 'music pause disabled without a loaded track'
  $script:soundItem.IsChecked=$true;Click-Item $script:soundItem
  Assert-Ui ($script:prefs.soundOn-and !(Get-WidgetAudioEnabled)) 'sound toggle saved but UI tests remain silent'
  Click-Item $script:soundVolumeMenu.Items[3]
  Assert-Ui ($script:prefs.soundVolume-eq .5) 'sound volume menu connected'
  Click-Item $script:musicVolumeMenu.Items[1]
  Assert-Ui ($script:prefs.musicVolume-eq .25-and $script:prefs.soundVolume-eq .5) 'music and click volume independent'
  Set-GeminiSound $false;Sync-GeminiMenu
  $script:menu.PlacementTarget=$script:ui.MenuButton;$script:menu.IsOpen=$true;$script:menu.UpdateLayout()
  foreach($pair in @(@($script:soundMenu,'sound-menu.png'),@($script:musicMenu,'music-menu.png'))){
    $pair[0].IsSubmenuOpen=$true;$pair[0].UpdateLayout();$popup=$pair[0].Template.FindName('PART_Popup',$pair[0])
    Assert-Ui ($popup.IsOpen-and $popup.Child.ActualWidth-ge 280) 'local media submenu opens with themed controls'
    if($CaptureDir){Render-Ui $popup.Child (Join-Path $CaptureDir $pair[1])}
    $pair[0].IsSubmenuOpen=$false
  }
  $script:menu.IsOpen=$false
  Write-Json (Join-Path $StateDir 'ui-validation.json') @{ok=$true;checks=$script:checks.ToArray();quotaSource='synthetic UI fixture, not account quota'}
  "UI checks passed: $($script:checks.Count)"
} finally {Close-GeminiMedia;$script:menu.IsOpen=$false;$script:window.Close()}
