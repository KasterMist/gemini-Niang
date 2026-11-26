# Explicit opt-in system-render loopback + upstream physics/visuals, never microphone.
function Initialize-GeminiRhythmTypes {
  if('GeminiMusicVisual'-as [type]){return}
  Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml,System.Windows.Forms,System.Drawing
  $references=@('System.dll','System.Core.dll','System.Xaml.dll','System.Windows.Forms.dll','System.Drawing.dll',[Windows.Window].Assembly.Location,[Windows.Media.Brush].Assembly.Location,[Windows.Point].Assembly.Location)
  Add-Type -Path @((Join-Path $PSScriptRoot 'music-audio.cs'),(Join-Path $PSScriptRoot 'music-visual.cs'),(Join-Path $PSScriptRoot 'music-anchor.cs')) -ReferencedAssemblies $references
}
function Test-GeminiSystemRhythm {return [bool]($script:systemRhythm-and $script:systemRhythm.Enabled)}
function Stop-GeminiSystemRhythm {
  if(!$script:systemRhythm){return}
  $rhythm=$script:systemRhythm;$script:systemRhythm=$null
  $rhythm.Stop($false);$script:rhythmAnchor=$null;$script:rhythmBase=$null;$script:avatar.ReleaseMouseCapture()
  Set-GeminiBubble (!$script:prefs.collapsed) -Transient
}
function Set-GeminiSystemRhythm([bool]$Enabled,[switch]$Synthetic) {
  if(!$Enabled){Stop-GeminiSystemRhythm;return}
  if(Test-GeminiSystemRhythm){return}
  if($Synthetic-and !$TestMode){throw '合成节拍仅限验收模式。'}
  if(!$script:window.IsVisible-or $script:prefs.paused){throw '请先显示挂件并取消暂停动画。'}
  Initialize-GeminiRhythmTypes
  Stop-GeminiMusic
  $script:rhythmError=$null;$script:rhythmSynthetic=[bool]$Synthetic
  $script:rhythmBase=$null
  Set-GeminiBubble $false -Transient
  $script:window.UpdateLayout()
  if(!$script:avatar.Source){$script:avatar.Source=$script:images[($script:prefs.view+'-idle')]}
  $script:rhythmAnchor=[GeminiMusicAnchor]::new();$script:rhythmAnchor.Widget=$script:owner.Handle
  $move=[Delegate]::CreateDelegate([System.Action[int,int]],$script:rhythmAnchor,'Move')
  $colors=[Windows.Media.Color[]]@('#B79BE1','#8ED9E8','#F0A6CF'|ForEach-Object{[Windows.Media.ColorConverter]::ConvertFromString($_)})
  try{
    $script:systemRhythm=[GeminiMusicVisual]::new($script:window,$script:avatar,$script:bubble,$move,$colors,$false,(!$Synthetic))
    $script:systemRhythm.HostFrame=[Delegate]::CreateDelegate([System.Func[int[]]],$script:rhythmAnchor,'HostFrame')
    Update-GeminiSystemRhythm
  }catch{Stop-GeminiSystemRhythm;Set-GeminiBubble (!$script:prefs.collapsed) -Transient;throw}
}
function Invoke-GeminiSystemRhythm {
  if(Test-GeminiSystemRhythm){Stop-GeminiSystemRhythm;return}
  $answer=[Windows.MessageBox]::Show($script:window,'将监听默认输出设备上的系统播放音频（不含麦克风），用于实时节奏检测。原始音频不保存、不上传。隐藏挂件或退出会停止监听，恢复窗口不会自动开启。是否现在开启？','Gemini 娘 · 系统音频监听',[Windows.MessageBoxButton]::YesNo,[Windows.MessageBoxImage]::Question)
  if($answer-eq [Windows.MessageBoxResult]::Yes){try{Set-GeminiSystemRhythm $true}catch{$script:rhythmError='系统律动无法启动，请检查输出设备。';Stop-GeminiSystemRhythm}}
}
function Update-GeminiSystemRhythm {
  if(!$script:systemRhythm){return}
  if(!$script:systemRhythm.Enabled){$script:rhythmError='系统律动已停止，请重试。';Stop-GeminiSystemRhythm;return}
  if(!$script:window.IsVisible-or $script:prefs.paused){$script:rhythmError='挂件隐藏或动画暂停，监听已停止；需手动重新开启。';Stop-GeminiSystemRhythm;return}
  $rect=[GeminiNiangNative]::Frame($script:owner.Handle.ToInt64())
  $hostFrame=if($script:prefs.followHost-and $script:hostHandle){[GeminiNiangNative]::Frame($script:hostHandle)}else{[GeminiNiangNative]::WorkArea($rect.left,$rect.top)}
  $x=$rect.left;$y=$rect.top
  if($script:prefs.followHost-and $script:hostHandle){$x=$hostFrame.right-($rect.right-$rect.left)-$script:prefs.right;$y=$hostFrame.bottom-($rect.bottom-$rect.top)-$script:prefs.bottom}
  elseif($script:rhythmBase){$x=$script:rhythmBase.x;$y=$script:rhythmBase.y}
  else{$script:rhythmBase=@{x=$x;y=$y}}
  $script:rhythmAnchor.Host=[IntPtr]$script:hostHandle;$script:rhythmAnchor.Follow=$script:prefs.followHost-and $script:hostHandle-gt 0
  $script:rhythmAnchor.X=$x;$script:rhythmAnchor.Y=$y;$script:rhythmAnchor.RelativeX=$x-$hostFrame.left;$script:rhythmAnchor.BottomDistance=$hostFrame.bottom-$y
  $dpi=[GeminiNiangNative]::Dpi($script:owner.Handle.ToInt64())/96.0
  $blocked=($script:quoteEditor-and $script:quoteEditor.IsVisible)-or $script:audioDialogOpen-or [DateTime]::UtcNow-lt $script:noticeUntil
  if($script:rhythmSynthetic){
    $now=[GeminiMusicCapture]::NowMs;$s=$script:systemRhythm.SyntheticAudio;$s.RhythmLocked=$true;$s.PeriodMs=500;$s.NextBeatAtMs=[Math]::Floor($now/500)*500+500;$s.Strength=1;$s.Running=$true
  }
  $script:systemRhythm.Configure($script:owner.Handle,[IntPtr]$script:hostHandle,($script:prefs.followHost-and $script:hostHandle-gt 0),$true,[bool]$blocked,$false,$x,$y,$hostFrame.left,$hostFrame.bottom,$dpi)
  $script:systemRhythm.SetVisibility($true,[bool]$blocked)
}
