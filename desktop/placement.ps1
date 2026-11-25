# Coordinates are native physical pixels throughout; negative monitor origins are valid.
function Get-GeminiPlacement($Bounds,[double]$Width,[double]$Height,[double]$X,[double]$Y) {
  $left=[double]$Bounds.left;$top=[double]$Bounds.top
  $maxX=[Math]::Max($left,[double]$Bounds.right-$Width);$maxY=[Math]::Max($top,[double]$Bounds.bottom-$Height)
  [pscustomobject]@{x=[int][Math]::Round([Math]::Max($left,[Math]::Min($maxX,$X)));y=[int][Math]::Round([Math]::Max($top,[Math]::Min($maxY,$Y)))}
}
function Save-GeminiPosition($Before,$After,$HostFrame) {
  if([Math]::Abs($Before.left-$After.left)+[Math]::Abs($Before.top-$After.top)-lt 4){return $false}
  if($script:prefs.followHost-and $HostFrame){
    $script:prefs.right=[Math]::Max(0,$HostFrame.right-$After.right);$script:prefs.bottom=[Math]::Max(0,$HostFrame.bottom-$After.bottom)
  }else{$script:prefs.desktopLeft=$After.left;$script:prefs.desktopTop=$After.top}
  Save-Preferences;return $true
}
function Set-GeminiFollowHost([bool]$Follow) {
  if($script:owner-and $script:owner.Handle-ne [IntPtr]::Zero){$frame=[GeminiNiangNative]::Frame($script:owner.Handle.ToInt64());$script:prefs.desktopLeft=$frame.left;$script:prefs.desktopTop=$frame.top}
  $script:prefs.followHost=$Follow;$script:desktopRestored=$true;Save-Preferences
}
function Reset-GeminiPosition {
  $script:prefs.right=16;$script:prefs.bottom=16;$script:prefs.desktopLeft=100;$script:prefs.desktopTop=100;$script:desktopRestored=$false;Save-Preferences
}
