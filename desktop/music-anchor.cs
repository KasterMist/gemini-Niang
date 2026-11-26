using System;
using System.Runtime.InteropServices;
// Native GUI-thread callbacks: no PowerShell delegate is invoked by render delivery.
public sealed class GeminiMusicAnchor {
    public IntPtr Widget,Host;public bool Follow;public int X,Y,RelativeX,BottomDistance;
    [StructLayout(LayoutKind.Sequential)]struct Rect {public int Left,Top,Right,Bottom;}
    [DllImport("user32.dll")]static extern bool GetWindowRect(IntPtr h,out Rect r);
    [DllImport("user32.dll")]static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int height,uint flags);
    public int[] HostFrame(){Rect r;if(Host==IntPtr.Zero||!GetWindowRect(Host,out r))return null;return new[]{r.Left,r.Top,r.Right,r.Bottom};}
    public void Move(int dx,int dy){ using(var dpiScope=new GeminiMusicDpiScope()) {
        int x=X,y=Y;Rect r;if(Follow&&GetWindowRect(Host,out r)){x=r.Left+RelativeX;y=r.Bottom-BottomDistance;}
        if(Widget!=IntPtr.Zero)SetWindowPos(Widget,IntPtr.Zero,x+dx,y+dy,0,0,0x615);
    }}
}
// WPF rendering may be dispatched under a secondary HwndSource's DPI context.
// Keep native coordinates physical and restore the caller's context afterwards.
public sealed class GeminiMusicDpiScope : IDisposable {
    readonly IntPtr previous;
    [DllImport("user32.dll")]static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")]static extern IntPtr GetThreadDpiAwarenessContext();
    [DllImport("user32.dll")]static extern bool AreDpiAwarenessContextsEqual(IntPtr a,IntPtr b);
    public GeminiMusicDpiScope(){previous=SetThreadDpiAwarenessContext(new IntPtr(-4));}
    public static bool IsPerMonitorV2 {get{return AreDpiAwarenessContextsEqual(GetThreadDpiAwarenessContext(),new IntPtr(-4));}}
    public void Dispose(){if(previous!=IntPtr.Zero)SetThreadDpiAwarenessContext(previous);}
}
