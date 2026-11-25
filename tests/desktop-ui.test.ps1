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
  Write-Json (Join-Path $StateDir 'ui-validation.json') @{ok=$true;checks=$script:checks.ToArray();quotaSource='synthetic UI fixture, not account quota'}
  "UI checks passed: $($script:checks.Count)"
} finally {$script:menu.IsOpen=$false;$script:window.Close()}
