# UI adapted from GPT-Niang widget.xaml and runtime/ui-settings.ps1 (MIT).
# Copyright (c) 2026 T7moris and GPT-Niang contributors. See ../LICENSE.
. (Join-Path $PSScriptRoot 'quotes.ps1')
. (Join-Path $PSScriptRoot 'scenes.ps1')
. (Join-Path $PSScriptRoot 'quote-editor.ps1')
. (Join-Path $PSScriptRoot 'placement.ps1')
. (Join-Path $PSScriptRoot 'media.ps1')
function Save-Preferences {Write-Json (Join-Path $script:stateDir 'preferences.json') $script:prefs}
function Set-GeminiBubble([bool]$visible,[switch]$Transient) {
  foreach($name in @('Bubble','Tail','TailNear')){$script:ui[$name].Visibility=if($visible){'Visible'}else{'Hidden'}}
  if(!$Transient){$script:prefs.collapsed=!$visible;$script:noticeUntil=[DateTime]::MinValue;$script:noticeRestorePending=$false;$script:autoQuoteUntil=0}
}
function Set-GeminiSize {
  # Upstream 378-unit design canvas; retain existing user's character-size preference.
  $script:window.Width=[Math]::Round(378*$script:prefs.size/208)
  $script:window.Height=$script:window.Width
  $script:desktopRestored=$false
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
function Show-GeminiQuote([switch]$Automatic) {
  $script:currentQuote=Get-WidgetQuote $script:stateDir
  $script:bubbleMode='quote'
  if($Automatic){Set-GeminiBubble $true -Transient}else{Set-GeminiBubble $true;Save-Preferences}
  Update-Status
}
function Initialize-GeminiUi {
  $script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'widget.xaml')))
  $script:window.ShowInTaskbar=([bool]$TestMode -or [bool]$ShowInTaskbar)
  $script:window.Left=100;$script:window.Top=100
  $script:ui=@{}
  foreach($name in @('Bubble','Tail','TailNear','Girl','MenuButton','Header','Refresh','QuotaText','QuoteText','ShortRow','WeekRow','ShortLabel','WeekLabel','ShortLeft','WeekLeft','ShortBar','WeekBar','ShortReset','WeekReset')){$script:ui[$name]=$script:window.FindName($name)}
  $script:bubble=$script:ui.Bubble;$script:avatar=$script:ui.Girl;$script:text=$script:ui.QuoteText
  $script:bubbleMode='quota';$script:currentQuote='我在这儿，慢慢来就好。'
  $script:autoQuoteUntil=0;$script:noticeRestorePending=$false
  Initialize-WidgetAutoQuoteSettings $script:prefs
  if(!$script:prefs.ContainsKey('musicVolume')){$script:prefs.musicVolume=.35}
  Initialize-GeminiMedia
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
  $script:pauseItem=Add-GeminiItem $appearance '暂停动画' {$script:prefs.paused=$this.IsChecked;Save-Preferences};$script:pauseItem.IsCheckable=$true
  $script:soundMenu=Add-GeminiItem $script:menu '声音与点击' $null
  $script:soundItem=Add-GeminiItem $script:soundMenu '点击音效（默认关闭）' {Set-GeminiSound $this.IsChecked};$script:soundItem.IsCheckable=$true
  $script:soundStatus=Add-GeminiItem $script:soundMenu '点击音效已关闭' $null;$script:soundStatus.IsEnabled=$false
  $script:soundVolumeMenu=Add-GeminiItem $script:soundMenu '音效音量' $null
  foreach($v in @(0,25,35,50,75,100)){$item=Add-GeminiItem $script:soundVolumeMenu ($v.ToString()+'%') {Set-GeminiSoundVolume ([double]$this.Uid/100)};$item.Uid=[string]$v;$item.IsCheckable=$true}
  $script:soundPreview=Add-GeminiItem $script:soundMenu '试听内置 / 当前按下音效' {Invoke-GeminiMediaAction 'preview'};$script:soundPreview.ToolTip='先启用点击音效；测试模式始终静音。'
  foreach($slot in @('press','release')){$label=if($slot-eq 'press'){'选择按下音效（WAV ≤5秒）'}else{'选择松开音效（WAV ≤5秒）'};$item=Add-GeminiItem $script:soundMenu $label {Invoke-WidgetAudioAction 'import' $this.Uid};$item.Uid=$slot}
  $null=Add-GeminiItem $script:soundMenu '恢复内置音效' {Invoke-WidgetAudioAction 'builtin' ''}
  $script:musicMenu=Add-GeminiItem $script:menu '音乐律动（本地 WAV）' $null
  $script:musicMenu.ToolTip='只分析所选文件的音量能量，不录制麦克风或系统声音。'
  $script:musicStatus=Add-GeminiItem $script:musicMenu '未播放' $null;$script:musicStatus.IsEnabled=$false
  $null=Add-GeminiItem $script:musicMenu '选择并播放本地 WAV…' {Invoke-GeminiMediaAction 'music'}
  $script:musicPause=Add-GeminiItem $script:musicMenu '暂停 / 继续' {Toggle-GeminiMusic}
  $null=Add-GeminiItem $script:musicMenu '停止播放与律动' {Stop-GeminiMusic}
  $script:musicVolumeMenu=Add-GeminiItem $script:musicMenu '音乐音量' $null
  foreach($v in @(0,25,35,50,75,100)){$item=Add-GeminiItem $script:musicVolumeMenu ($v.ToString()+'%') {Set-GeminiMusicVolume ([double]$this.Uid/100)};$item.Uid=[string]$v;$item.IsCheckable=$true}
  $script:groupMenu=Add-GeminiItem $script:menu '额度模型组' $null
  $script:quoteEditorItem=Add-GeminiItem $script:menu '编辑我的语录' {Open-GeminiQuoteEditor}
  $script:autoQuoteMenu=Add-GeminiItem $script:menu '自动语录' $null
  $script:autoQuoteItem=Add-GeminiItem $script:autoQuoteMenu '启用自动语录' {Set-GeminiAutoQuotes $this.IsChecked $script:autoQuoteIntervalSeconds};$script:autoQuoteItem.IsCheckable=$true
  foreach($pair in @(@(60,'每 1 分钟'),@(300,'每 5 分钟'),@(900,'每 15 分钟'))){$item=Add-GeminiItem $script:autoQuoteMenu $pair[1] {Set-GeminiAutoQuotes $script:autoQuoteEnabled ([int]$this.Uid)};$item.Uid=[string]$pair[0];$item.IsCheckable=$true}
  $script:completionItem=Add-GeminiItem $script:menu '回答结束提醒' {$script:prefs.completion=$this.IsChecked;Save-Preferences};$script:completionItem.IsCheckable=$true
  Add-GeminiDivider
  $display=Add-GeminiItem $script:menu '显示与位置' $null
  $script:followItem=Add-GeminiItem $display '跟随 Antigravity 窗口' {Set-GeminiFollowHost $this.IsChecked};$script:followItem.IsCheckable=$true
  $null=Add-GeminiItem $display '重置位置' {Reset-GeminiPosition}
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
  $script:soundItem.IsChecked=$script:soundOn
  $script:soundStatus.Header=if(!$script:geminiNiangAudio){'音效未就绪，请检查安装文件'}elseif($script:geminiNiangAudio.Queue.Error){'音频设备播放失败，请重试'}elseif($script:geminiNiangAudio.Errors.Count-gt 0){'有音效文件不可用，请重新选择'}elseif(!$script:soundOn){'点击音效已关闭'}else{'音效已就绪'}
  $script:soundPreview.IsEnabled=$script:soundOn-and [bool]$script:geminiNiangAudio
  foreach($item in $script:soundVolumeMenu.Items){$item.IsChecked=[Math]::Abs([double]$item.Uid/100-$script:soundVolume)-lt .001}
  foreach($item in $script:musicVolumeMenu.Items){$item.IsChecked=[Math]::Abs([double]$item.Uid/100-$script:prefs.musicVolume)-lt .001}
  $script:musicStatus.Header=switch($script:music.mode){'loading'{'正在分析本地 WAV…'}'opening'{'正在打开播放器…'}'playing'{'播放中 · 文件能量律动'}'paused'{'已暂停'}'paused-hidden'{'宿主隐藏，已暂停；请手动继续'}'ended'{'播放结束'}'error'{$script:music.lastError}default{'未播放 · 不监听系统音频'}}
  $script:musicPause.IsEnabled=$script:music.mode-in @('playing','paused','paused-hidden','ended')
  $script:autoQuoteItem.IsChecked=$script:autoQuoteEnabled
  foreach($item in $script:autoQuoteMenu.Items){if($item.Uid){$item.IsChecked=[int]$item.Uid-eq $script:autoQuoteIntervalSeconds}}
  $script:groupMenu.Items.Clear();$usage=Read-Json (Join-Path $script:stateDir 'usage.json')
  $groups=@($usage.groups|Where-Object {$null-ne $_})
  for($i=0;$i-lt $groups.Count;$i++){$item=Add-GeminiItem $script:groupMenu ([string]$groups[$i].name) {$script:prefs.group=[int]$this.Uid;$script:bubbleMode='quota';Set-GeminiBubble $true;Update-Status;Save-Preferences};$item.Uid=[string]$i;$item.IsCheckable=$true;$item.IsChecked=$i-eq $script:prefs.group}
  if(!$groups.Count){$item=Add-GeminiItem $script:groupMenu '读取额度后可选择' $null;$item.IsEnabled=$false}
}
function Update-Status {
  $message=$null
  if([DateTime]::UtcNow-lt $script:noticeUntil){$message=if($TestMode){'任务已完成 ✦（测试）'}else{'任务已完成 ✦'}}
  elseif($script:bubbleMode-eq 'quote'){$message=$script:currentQuote}
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
  if($message){Set-GeminiMessage $message;$script:bubble.ToolTip=$message}
}
