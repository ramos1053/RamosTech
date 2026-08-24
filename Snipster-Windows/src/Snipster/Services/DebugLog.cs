using System.IO;

namespace Snipster.Services;

/// <summary>
/// Minimal file logger for the keyboard hook / expansion pipeline. Global
/// hooks fail silently in ways a user can't screenshot (blocked by AV,
/// UIPI, a stale layout handle, ...), so a plain text log the user can
/// paste back is worth more here than nothing.
///
/// SECURITY: this log is deliberately restricted to structural events only
/// (hook install/failure, trigger NAMES matched, SendInput error codes,
/// exceptions) — callers must never pass raw typed text, clipboard content,
/// or expanded snippet content. The hook sees keystrokes system-wide, so
/// logging their content would make this file a de facto plaintext
/// keylogger capable of capturing passwords and other secrets.
/// </summary>
internal static class DebugLog
{
    // Defense in depth against the log growing unbounded even though its
    // content is now restricted to short structural lines.
    private const long MaxSizeBytes = 1_000_000;

    private static readonly string LogPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Snipster", "debug.log");

    private static readonly object Lock = new();

    public static void Write(string message)
    {
        lock (Lock)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LogPath)!);

                if (File.Exists(LogPath) && new FileInfo(LogPath).Length > MaxSizeBytes)
                    File.Delete(LogPath); // start over rather than growing forever

                File.AppendAllText(LogPath, $"{DateTime.Now:HH:mm:ss.fff} {message}{Environment.NewLine}");
            }
            catch
            {
                // Logging must never be the reason the app crashes.
            }
        }
    }
}
