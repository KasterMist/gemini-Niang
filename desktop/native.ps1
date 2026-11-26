if (!('GeminiNiangNative' -as [type])) {
Add-Type -TypeDefinition @'
using System;using System.IO;using System.Diagnostics;using System.Collections.Generic;using System.Runtime.InteropServices;using System.Text;
public sealed class GeminiHost { public long handle;public int pid;public int left;public int top;public int right;public int bottom; }
public static class GeminiNiangNative {
 public delegate bool EnumProc(IntPtr h,IntPtr p);
 [StructLayout(LayoutKind.Sequential)]public struct Rect{public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)]public struct Point{public int X,Y;}
 [DllImport("user32.dll")]static extern bool GetCursorPos(out Point point);
 [DllImport("user32.dll")]static extern uint GetDpiForWindow(IntPtr window);
 [StructLayout(LayoutKind.Sequential)]public class MonitorInfo {public int size=Marshal.SizeOf(typeof(MonitorInfo));public Rect monitor;public Rect work;public uint flags;}
 [DllImport("user32.dll")]static extern IntPtr MonitorFromRect(ref Rect rect,uint flags);
 [DllImport("user32.dll")]static extern bool GetMonitorInfo(IntPtr monitor,[In,Out] MonitorInfo info);
 [DllImport("user32.dll")]static extern bool EnumWindows(EnumProc cb,IntPtr p);
 [DllImport("user32.dll")]public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")]static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll")]static extern int GetWindowText(IntPtr h,StringBuilder text,int n);
 [DllImport("user32.dll")]static extern IntPtr GetWindow(IntPtr h,uint cmd);
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr z,int x,int y,int cx,int cy,uint flags);
 [DllImport("dwmapi.dll")]static extern int DwmGetWindowAttribute(IntPtr h,int a,out uint value,int n);
 public static GeminiHost FindHost(string expected,long preferred){
  var hosts=new List<GeminiHost>();int session;using(var self=Process.GetCurrentProcess())session=self.SessionId;
  EnumWindows((h,p)=>{try{
   if(!IsWindowVisible(h)||IsIconic(h)||GetWindow(h,4)!=IntPtr.Zero)return true;
   uint cloaked;if(DwmGetWindowAttribute(h,14,out cloaked,4)==0&&cloaked!=0)return true;
   var title=new StringBuilder(256);if(GetWindowText(h,title,256)==0)return true;
   uint pid;GetWindowThreadProcessId(h,out pid);
   using(var proc=Process.GetProcessById((int)pid)){
    if(proc.SessionId!=session||!proc.ProcessName.Equals("Antigravity",StringComparison.OrdinalIgnoreCase))return true;
    if(!Path.GetFullPath(proc.MainModule.FileName).Equals(Path.GetFullPath(expected),StringComparison.OrdinalIgnoreCase))return true;
    Rect r;if(!GetWindowRect(h,out r)||r.Right-r.Left<200||r.Bottom-r.Top<100)return true;
    hosts.Add(new GeminiHost{handle=h.ToInt64(),pid=(int)pid,left=r.Left,top=r.Top,right=r.Right,bottom=r.Bottom});
   }
  }catch{}return true;},IntPtr.Zero);
  long foreground=GetForegroundWindow().ToInt64();
  foreach(var host in hosts)if(host.handle==foreground)return host;
  foreach(var host in hosts)if(host.handle==preferred)return host;
  return hosts.Count>0?hosts[0]:null;
 }
 public static Rect Frame(long handle){Rect r;GetWindowRect(new IntPtr(handle),out r);return r;}
 public static Point Cursor(){Point p;GetCursorPos(out p);return p;}
 public static uint Dpi(long handle){return GetDpiForWindow(new IntPtr(handle));}
 public static Rect WorkArea(int x,int y){var r=new Rect{Left=x,Top=y,Right=x+1,Bottom=y+1};var info=new MonitorInfo();if(!GetMonitorInfo(MonitorFromRect(ref r,2),info))throw new InvalidOperationException("Monitor work area unavailable");return info.work;}
 public static void Move(long handle,int x,int y){SetWindowPos(new IntPtr(handle),IntPtr.Zero,x,y,0,0,0x0015);}
}
'@
}
