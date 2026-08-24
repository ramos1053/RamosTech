using System.Windows.Interop;
using Snipster.Models;
using Snipster.Native;
using Clipboard = System.Windows.Clipboard;
using DataFormats = System.Windows.DataFormats;
using IDataObject = System.Windows.IDataObject;

namespace Snipster.Services;

/// <summary>
/// In-memory ring buffer of recent clipboard text — mirrors the macOS app's
/// ClipboardHistoryBuffer. Uses AddClipboardFormatListener (event-driven,
/// user-level, no admin rights) instead of polling.
/// </summary>
public class ClipboardHistoryMonitor : IDisposable
{
    // The real, Microsoft-documented clipboard format that password
    // managers set to opt content out of history/sync tools — the direct
    // Windows counterpart to the macOS org.nspasteboard.* convention the
    // README calls out.
    private const string ExcludeClipboardFormat = "ExcludeClipboardContentFromMonitorProcessing";

    private readonly HwndSource _source;
    private readonly LinkedList<ClipboardHistoryEntry> _entries = new();

    public event Action? HistoryChanged;

    public IReadOnlyList<ClipboardHistoryEntry> Entries => _entries.ToList();

    /// <summary>User-configurable via Preferences; trims immediately when lowered.</summary>
    public int MaxEntries { get; set; } = 50;

    public ClipboardHistoryMonitor()
    {
        var parameters = new HwndSourceParameters("SnipsterClipboardWindow")
        {
            Width = 0,
            Height = 0,
            WindowStyle = 0,
            ParentWindow = new IntPtr(-3), // HWND_MESSAGE
        };

        _source = new HwndSource(parameters);
        _source.AddHook(WndProc);
        NativeMethods.AddClipboardFormatListener(_source.Handle);
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == NativeMethods.WM_CLIPBOARDUPDATE)
            CaptureCurrentClipboard();

        return IntPtr.Zero;
    }

    private void CaptureCurrentClipboard()
    {
        try
        {
            IDataObject? data = Clipboard.GetDataObject();
            if (data is null) return;

            if (data.GetDataPresent(ExcludeClipboardFormat)) return;
            if (!data.GetDataPresent(DataFormats.Text)) return;

            if (data.GetData(DataFormats.Text) is not string text || string.IsNullOrEmpty(text))
                return;

            // Skip re-recording the same thing copied twice in a row.
            if (_entries.First?.Value.Text == text) return;

            _entries.AddFirst(new ClipboardHistoryEntry { Text = text });
            while (_entries.Count > MaxEntries) _entries.RemoveLast();

            // Never log clipboard CONTENT — it's arbitrary data copied from
            // any app system-wide and could be a password, token, or other
            // secret. Length only.
            DebugLog.Write($"Clipboard history captured ({_entries.Count} entries, {text.Length} chars)");
            HistoryChanged?.Invoke();
        }
        catch (System.Runtime.InteropServices.COMException)
        {
            // Another process can hold the clipboard open transiently.
        }
    }

    public void Clear()
    {
        _entries.Clear();
        HistoryChanged?.Invoke();
    }

    public void Dispose()
    {
        NativeMethods.RemoveClipboardFormatListener(_source.Handle);
        _source.RemoveHook(WndProc);
        _source.Dispose();
    }
}
