// Native GUI entry point for the WPF companion (not a terminal launcher).
using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Windows.Forms;
public static class GeminiDesktopHost {
    [STAThread] public static int Main(string[] args) {
        try {
            string root=null,state=null;bool test=false,noRefresh=false,taskbar=false,synthetic=false;int close=0;
            for(int i=0;i<args.Length;i++) {
                switch(args[i]) {
                    case "--root":root=Path.GetFullPath(args[++i]);break;
                    case "--state-dir":state=Path.GetFullPath(args[++i]);break;
                    case "--test":test=true;break;
                    case "--synthetic-rhythm":synthetic=true;break;
                    case "--no-refresh":noRefresh=true;break;
                    case "--show-taskbar":taskbar=true;break;
                    case "--auto-close":close=int.Parse(args[++i]);if(close<0||close>3600)throw new ArgumentException("Invalid timeout");break;
                    default:throw new ArgumentException("Unknown option");
                }
            }
            if(root==null||!File.Exists(Path.Combine(root,"desktop","GeminiNiang.ps1")))throw new ArgumentException("Companion source directory not found");
            using(var runspace=RunspaceFactory.CreateRunspace(InitialSessionState.CreateDefault())) {
                runspace.ApartmentState=ApartmentState.STA;runspace.ThreadOptions=PSThreadOptions.UseCurrentThread;runspace.Open();
                using(var policy=PowerShell.Create()) {
                    policy.Runspace=runspace;
                    policy.AddCommand("Set-ExecutionPolicy").AddParameter("Scope","Process").AddParameter("ExecutionPolicy","Bypass").AddParameter("Force");policy.Invoke();
                }
                using(var ps=PowerShell.Create()) {
                    ps.Runspace=runspace;
                    ps.AddCommand(Path.Combine(root,"desktop","GeminiNiang.ps1"));
                    if(state!=null)ps.AddParameter("StateDir",state);
                    if(test)ps.AddParameter("TestMode");if(noRefresh)ps.AddParameter("NoRefresh");if(taskbar)ps.AddParameter("ShowInTaskbar");
                    if(close>0)ps.AddParameter("AutoCloseSeconds",close);
                    if(synthetic)ps.AddParameter("SyntheticRhythmTest");
                    ps.Invoke();
                    if(ps.InvocationStateInfo.State==PSInvocationState.Failed)throw new InvalidOperationException("Companion pipeline failed",ps.InvocationStateInfo.Reason);
                }
            }
            return 0;
        } catch(Exception e) {
            string dir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"GeminiNiang");Directory.CreateDirectory(dir);
            File.WriteAllText(Path.Combine(dir,"host-error.txt"),e.ToString());
            MessageBox.Show("Gemini 娘无法启动。详细原因保存在本机 GeminiNiang/host-error.txt。\n"+e.Message,"Gemini 娘",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;
        }
    }
}
