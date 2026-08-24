using Microsoft.Win32;

namespace Snipster.Services;

/// <summary>
/// "Launch at login" via the per-user Run key — HKCU, not HKLM, so this
/// needs no admin rights, matching the rest of the app's no-elevation design.
/// </summary>
public static class StartupManager
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "Snipster";

    public static bool IsEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath);
        return key?.GetValue(ValueName) is string existing &&
               string.Equals(existing.Trim('"'), GetExePath(), StringComparison.OrdinalIgnoreCase);
    }

    public static void SetEnabled(bool enabled)
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: true)
            ?? Registry.CurrentUser.CreateSubKey(RunKeyPath);

        if (enabled)
            key.SetValue(ValueName, $"\"{GetExePath()}\"");
        else
            key.DeleteValue(ValueName, throwOnMissingValue: false);
    }

    private static string GetExePath() =>
        Environment.ProcessPath ?? System.Diagnostics.Process.GetCurrentProcess().MainModule!.FileName!;
}
