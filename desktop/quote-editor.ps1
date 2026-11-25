# Adapted from GPT-Niang runtime/ui-settings.ps1 (MIT), T7moris and contributors.
function Open-GeminiQuoteEditor {
  if($script:quoteEditor -and $script:quoteEditor.IsVisible){$script:quoteEditor.Activate()|Out-Null;return}
  $editor=[Windows.Markup.XamlReader]::Parse(@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Gemini 娘 · 我的语录" Width="540" Height="480" MinWidth="440" MinHeight="340" ShowInTaskbar="False"
 FontFamily="Microsoft YaHei UI" FontSize="14" Background="#FAF8FD" WindowStartupLocation="CenterScreen">
 <Border Background="#FAF8FD" Padding="22"><Grid>
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <TextBlock Margin="0,0,0,14" TextWrapping="Wrap" Foreground="#745A98" Text="一行一句语录。想让某句更常出现，可写：3 | 这句语录。"/>
  <TextBox x:Name="Lines" Grid.Row="1" MaxLength="1048576" AcceptsReturn="True" AcceptsTab="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" FontSize="16" Padding="12" Background="White" BorderBrush="#DDD4EA"/>
  <TextBlock x:Name="Feedback" Grid.Row="2" Margin="0,12,0,10" Foreground="#745A98" TextWrapping="Wrap"/>
  <Grid Grid.Row="3">
   <Button x:Name="Defaults" Content="恢复内置语录" Padding="12,6" HorizontalAlignment="Left"/>
   <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
    <Button x:Name="Save" Content="保存" Padding="20,6" Margin="0,0,10,0"/>
    <Button x:Name="Done" Content="关闭" Padding="20,6"/>
   </StackPanel>
  </Grid>
 </Grid></Border>
</Window>
'@)
  $script:quoteEditor=$editor
  $editor.Owner=$script:window
  $editor.Resources.MergedDictionaries.Add($script:menuResources)
  foreach($name in @('Defaults','Save','Done')){$editor.FindName($name).Style=$script:menuResources['SettingsPreset']}
  $lines=$editor.FindName('Lines');$feedback=$editor.FindName('Feedback')
  $current=Get-WidgetQuoteSettings $script:stateDir
  $lines.Text=($current.quotes|ForEach-Object{if($_.weight-eq 1){$_.text}else{([string]$_.weight)+' | '+$_.text}})-join [Environment]::NewLine
  $feedback.Text=if($current.error){$current.error}else{'每条最多 200 字。语录在你的电脑上保存。'}
  $editor.FindName('Save').Add_Click({
    try{
      $rows=@(ConvertFrom-GeminiQuoteLines $script:quoteEditor.FindName('Lines').Text)
      $saved=Save-WidgetQuotes $script:stateDir $rows
      $script:quoteEditor.FindName('Feedback').Text="已保存 $($saved.quotes.Count) 句。下一次显示语录时就会使用。"
    }catch{$script:quoteEditor.FindName('Feedback').Text=$_.Exception.Message}
  })
  $editor.FindName('Defaults').Add_Click({
    try{
      $restored=Reset-WidgetQuotes $script:stateDir
      $script:quoteEditor.FindName('Lines').Text=($restored.quotes|ForEach-Object{$_.text})-join [Environment]::NewLine
      $script:quoteEditor.FindName('Feedback').Text='已恢复内置语录，你的旧列表已备份。'
    }catch{$script:quoteEditor.FindName('Feedback').Text=$_.Exception.Message}
  })
  $editor.FindName('Done').Add_Click({$script:quoteEditor.Close()})
  $editor.Add_KeyDown({param($sender,$event)if($event.Key-eq [Windows.Input.Key]::Escape){$sender.Close();$event.Handled=$true}})
  $editor.Show()
}

