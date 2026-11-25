# UI adapted from GPT-Niang widget.xaml and runtime/ui-settings.ps1 (MIT).
# Copyright (c) 2026 T7moris and GPT-Niang contributors. See ../LICENSE.
function Save-Preferences {Write-Json (Join-Path $script:stateDir 'preferences.json') $script:prefs}
function Set-GeminiBubble([bool]$visible,[switch]$Transient) {
  foreach($name in @('Bubble','Tail','TailNear')){$script:ui[$name].Visibility=if($visible){'Visible'}else{'Hidden'}}
  if(!$Transient){$script:prefs.collapsed=!$visible}
}
function Set-GeminiSize {
  # Upstream 378-unit design canvas; retain existing user's character-size preference.
  $script:window.Width=[Math]::Round(378*$script:prefs.size/208)
  $script:window.Height=$script:window.Width
}
function Add-GeminiItem($parent,$label,[scriptblock]$handler) {
  $item=[Windows.Controls.MenuItem]::new();$item.Header=$label;$item.Style=$script:menuResources['SettingsItem']
  if($handler){$item.Add_Click($handler)}
  $parent.Items.Add($item)|Out-Null;return $item
}
function Add-GeminiDivider {
  $item=[Windows.Controls.Separator]::new();$item.Margin='20,8';$item.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#EEE5F6')
  $script:menu.Items.Add($item)|Out-Null
}
function Show-GeminiQuote {
  $script:quoteIndex=($script:quoteIndex+1)%$script:quotes.Count
  $script:bubbleMode='quote';Set-GeminiBubble $true;Update-Status;Save-Preferences
}
function Initialize-GeminiUi {
  $script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'widget.xaml')))
  $script:window.ShowInTaskbar=([bool]$TestMode -or [bool]$ShowInTaskbar)
  $script:window.Left=100;$script:window.Top=100
  $script:ui=@{}
  foreach($name in @('Bubble','Tail','TailNear','Girl','MenuButton','Header','Refresh','QuotaText','QuoteText','ShortRow','WeekRow','ShortLabel','WeekLabel','ShortLeft','WeekLeft','ShortBar','WeekBar','ShortReset','WeekReset')){$script:ui[$name]=$script:window.FindName($name)}
  $script:bubble=$script:ui.Bubble;$script:avatar=$script:ui.Girl;$script:text=$script:ui.QuoteText
  $script:bubbleMode='quota';$script:quotes=@('我在这儿，慢慢来就好。','灵感到啦，一起试试看？','休息一下，也是在积蓄星光。');$script:quoteIndex=0
  $script:avatar.ToolTip='单击查看额度；拖动移动；右键打开设置'
  $script:avatar.RenderTransformOrigin=[Windows.Point]::new(.5,.9)
  $script:transforms=[Windows.Media.TransformGroup]::new();$script:scale=[Windows.Media.ScaleTransform]::new();$script:rotate=[Windows.Media.RotateTransform]::new();$script:translate=[Windows.Media.TranslateTransform]::new()
  $script:transforms.Children.Add($script:scale);$script:transforms.Children.Add($script:rotate);$script:transforms.Children.Add($script:translate);$script:avatar.RenderTransform=$script:transforms
  Set-GeminiSize;Set-GeminiBubble (!$script:prefs.collapsed)
  $script:menuResources=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'menu-resources.xaml')))
  $script:menu=[Windows.Controls.ContextMenu]::new();$script:menu.Width=328;$script:menu.FontFamily='Microsoft YaHei UI'
  $script:menu.MaxHeight=[Math]::Max(250,[Windows.SystemParameters]::WorkArea.Height-28)
  $script:menu.Resources.MergedDictionaries.Add($script:menuResources)
  $script:menu.Resources['SettingsSubmenuWidth']=[double]280;$script:menu.Resources['SettingsSubmenuMaxHeight']=[double]500
  $script:menu.Template=[Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="ContextMenu"><Border Background="#FFFCFF" BorderBrush="#DFD1EC" BorderThickness="1" CornerRadius="12" Padding="9,8"><ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" CanContentScroll="False"><ItemsPresenter/></ScrollViewer></Border></ControlTemplate>
'@)
  $script:window.ContextMenu=$script:menu
  $script:menuBubble=Add-GeminiItem $script:menu '收起额度气泡' {Set-GeminiBubble (-not ($script:bubble.Visibility-eq 'Visible'));$script:bubbleMode='quota';Update-Status;Save-Preferences}
  $null=Add-GeminiItem $script:menu '刷新额度' {$script:bubbleMode='quota';Set-GeminiBubble $true;Start-Refresh;Update-Status}
  $null=Add-GeminiItem $script:menu '换一句台词' {Show-GeminiQuote}
  Add-GeminiDivider
  $shape=Add-GeminiItem $script:menu '更换形象' $null
  foreach($pair in @(@('bust','半身近景'),@('full','正面全身'),@('side','侧面全身'),@('back','背面全身'))){$item=Add-GeminiItem $shape $pair[1] {$script:prefs.view=$this.Uid;Save-Preferences};$item.Uid=$pair[0];$item.IsCheckable=$true}
  $script:shapeMenu=$shape
  $script:actionMenu=Add-GeminiItem $script:menu '动作选择' $null
  $labels=@('待机','眨眼','招手','开心','思考','困倦')
  for($i=0;$i-lt 6;$i++){$item=Add-GeminiItem $script:actionMenu $labels[$i] {$script:prefs.action=$this.Uid;$script:clock=0;Save-Preferences};$item.Uid=$script:actions[$i];$item.IsCheckable=$true}
  $appearance=Add-GeminiItem $script:menu '外观设置' $null
  foreach($size in @(180,240,300)){$label=switch($size){180{'小 · 75%'}240{'标准 · 100%'}300{'大 · 125%'}};$item=Add-GeminiItem $appearance $label {$script:prefs.size=[int]$this.Uid;Set-GeminiSize;Save-Preferences};$item.Uid=[string]$size;$item.IsCheckable=$true}
  $script:sizeMenu=$appearance
  $script:pauseItem=Add-GeminiItem $appearance '暂停动画' {$script:prefs.paused=$this.IsChecked};$script:pauseItem.IsCheckable=$true
  $script:groupMenu=Add-GeminiItem $script:menu '额度模型组' $null
  $script:completionItem=Add-GeminiItem $script:menu '回答结束提醒' {$script:prefs.completion=$this.IsChecked;Save-Preferences};$script:completionItem.IsCheckable=$true
  Add-GeminiDivider
  $display=Add-GeminiItem $script:menu '显示与位置' $null
  $script:followItem=Add-GeminiItem $display '跟随 Antigravity 窗口' {$script:prefs.followHost=$this.IsChecked;Save-Preferences};$script:followItem.IsCheckable=$true
  $null=Add-GeminiItem $display '重置位置' {$script:prefs.right=16;$script:prefs.bottom=16;$script:window.Left=100;$script:window.Top=100;Save-Preferences}
  Add-GeminiDivider
  $exit=Add-GeminiItem $script:menu '退出 Gemini 娘' {$script:window.Close()};$exit.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#AE7A94')
  $script:menu.Add_Opened({Sync-GeminiMenu})
  $script:ui.MenuButton.Add_Click({$script:menu.PlacementTarget=$script:ui.MenuButton;$script:menu.Placement='Left';$script:menu.IsOpen=$true})
  $script:bubble.Add_MouseLeftButtonUp({if($script:bubbleMode-eq 'quota'){Show-GeminiQuote}else{Set-GeminiBubble $false;Save-Preferences}})
}
function Sync-GeminiMenu {
  $script:menuBubble.Header=if($script:bubble.Visibility-eq 'Visible'){'收起额度气泡'}else{'查看额度'}
  foreach($item in $script:shapeMenu.Items){$item.IsChecked=$item.Uid-eq $script:prefs.view}
  foreach($item in $script:actionMenu.Items){$item.IsChecked=$item.Uid-eq $script:prefs.action}
  $script:actionMenu.Items[1].Header=if($script:prefs.view-eq 'back'){'耳朵轻动'}else{'眨眼'}
  foreach($item in $script:sizeMenu.Items){if($item.Uid){$item.IsChecked=[int]$item.Uid-eq $script:prefs.size}}
  $script:pauseItem.IsChecked=$script:prefs.paused;$script:followItem.IsChecked=$script:prefs.followHost;$script:completionItem.IsChecked=$script:prefs.completion
  $script:groupMenu.Items.Clear();$usage=Read-Json (Join-Path $script:stateDir 'usage.json')
  $groups=@($usage.groups|Where-Object {$null-ne $_})
  for($i=0;$i-lt $groups.Count;$i++){$item=Add-GeminiItem $script:groupMenu ([string]$groups[$i].name) {$script:prefs.group=[int]$this.Uid;$script:bubbleMode='quota';Set-GeminiBubble $true;Update-Status;Save-Preferences};$item.Uid=[string]$i;$item.IsCheckable=$true;$item.IsChecked=$i-eq $script:prefs.group}
  if(!$groups.Count){$item=Add-GeminiItem $script:groupMenu '读取额度后可选择' $null;$item.IsEnabled=$false}
}
function Update-Status {
  $message=$null
  if([DateTime]::UtcNow-lt $script:noticeUntil){$message=if($TestMode){'任务已完成 ✦（测试）'}else{'任务已完成 ✦'}}
  elseif($script:bubbleMode-eq 'quote'){$message=$script:quotes[$script:quoteIndex]}
  else {
    $usage=Read-Json (Join-Path $script:stateDir 'usage.json')
    if(!$usage){$message='正在读取额度…'}
    elseif(!$usage.ok){$message=[string]$usage.message;if(!$message){$message='额度暂不可用，请刷新'}}
    else {
      try{$fresh=([DateTime]::UtcNow-([DateTime]$usage.observedAt).ToUniversalTime()).TotalSeconds-le 300}catch{$fresh=$false}
      if(!$fresh){$message='额度已过期，请刷新'}
      else {
        $groups=@($usage.groups|Where-Object {$null-ne $_})
        if(!$groups.Count){$message='暂无额度数据'}
        else {
          $index=[Math]::Min($script:prefs.group,$groups.Count-1);$group=$groups[$index]
          $script:ui.Header.Text=if($group.name-like '*Gemini*'){'Gemini 剩余额度'}elseif($group.name-like '*Claude*' -or $group.name-like '*GPT*'){'Claude / GPT 额度'}else{'剩余额度'}
          $script:ui.Header.ToolTip=[string]$group.name+' · 在菜单中切换模型组'
          $script:bubble.ToolTip=[string]$group.name+' · '+$(if($usage.source-eq 'antigravity-cli'){'官方 CLI 只读查询'}else{'测试数据，非真实额度'})
          foreach($pair in @(@('Short','5h','5 小时'),@('Week','weekly','每周'))){
            $prefix=$pair[0];$bucket=@($group.buckets|Where-Object {$_.window-eq $pair[1]})|Select-Object -First 1
            $script:ui[($prefix+'Label')].Text=$pair[2]
            if($bucket -and $null-ne $bucket.remaining){
              $value=[Math]::Max(0,[Math]::Min(100,[double]$bucket.remaining));$script:ui[($prefix+'Left')].Text=$value.ToString('0.#')+'%';$script:ui[($prefix+'Bar')].Width=184*$value/100
              $reset='重置时间未知';if($bucket.resetsAt){try{$reset=([DateTime]$bucket.resetsAt).ToLocalTime().ToString('MM-dd HH:mm')+' 重置'}catch{}}
              $script:ui[($prefix+'Reset')].Text=$reset
            }else{$script:ui[($prefix+'Left')].Text='—';$script:ui[($prefix+'Bar')].Width=0;$script:ui[($prefix+'Reset')].Text='此模型组未提供'}
          }
        }
      }
    }
  }
  $script:ui.QuotaText.Visibility=if($message){'Collapsed'}else{'Visible'}
  $script:ui.QuoteText.Visibility=if($message){'Visible'}else{'Collapsed'}
  if($message){$script:text.FontSize=if($message.Length-gt 25){13}else{19};$script:text.Text=$message;$script:bubble.ToolTip=$message}
}
