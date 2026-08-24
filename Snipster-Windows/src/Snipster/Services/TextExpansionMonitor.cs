using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using Snipster.Models;
using Snipster.Native;
using Snipster.Views;

namespace Snipster.Services;

/// <summary>
/// Watches keystrokes globally for "!trigger" patterns and expands them.
/// This is the counterpart to the macOS app's Accessibility-gated
/// TextExpansionMonitor/CGEventTap — here it's a WH_KEYBOARD_LL hook, which
/// needs no explicit user permission grant, but is blocked by Windows UIPI
/// from seeing or injecting into higher-integrity (elevated) windows.
/// </summary>
public class TextExpansionMonitor : IDisposable
{
    private const int MaxBufferLength = 40;
    private static readonly Regex InputTokenRegex = new(@"\{\{INPUT:([^}]+)\}\}", RegexOptions.Compiled);

    private readonly StringBuilder _buffer = new();
    private readonly NativeMethods.LowLevelKeyboardProc _proc;
    private readonly Func<SnippetLibrary> _libraryProvider;
    private IntPtr _hookHandle = IntPtr.Zero;

    // Gates both "typing a template popup's fields" and "SendInput is
    // currently replaying our own synthetic keystrokes" — in both cases the
    // hook must let keys through (CallNextHookEx) without feeding them back
    // into the trigger-matching buffer.
    private bool _suspended;

    /// <summary>User-facing on/off switch, wired to the tray menu's checkbox.</summary>
    public bool IsEnabled { get; set; } = true;

    public TextExpansionMonitor(Func<SnippetLibrary> libraryProvider)
    {
        _libraryProvider = libraryProvider;
        _proc = HookCallback; // keep a live reference so the delegate isn't GC'd
    }

    public void Start()
    {
        if (_hookHandle != IntPtr.Zero) return;

        using var curModule = System.Diagnostics.Process.GetCurrentProcess().MainModule!;
        var moduleHandle = NativeMethods.GetModuleHandle(curModule.ModuleName!);

        _hookHandle = NativeMethods.SetWindowsHookEx(
            NativeMethods.WH_KEYBOARD_LL, _proc, moduleHandle, 0);

        if (_hookHandle == IntPtr.Zero)
        {
            DebugLog.Write("Start: SetWindowsHookEx FAILED");
            throw new InvalidOperationException(
                "Failed to install keyboard hook (SetWindowsHookEx). " +
                "This does not require admin rights, but can fail if blocked by policy/AV.");
        }

        DebugLog.Write("Start: keyboard hook installed");
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0 && !_suspended && IsEnabled &&
            (wParam.ToInt32() == NativeMethods.WM_KEYDOWN || wParam.ToInt32() == NativeMethods.WM_SYSKEYDOWN))
        {
            var data = Marshal.PtrToStructure<NativeMethods.KBDLLHOOKSTRUCT>(lParam);
            ProcessKey(data);
        }

        return NativeMethods.CallNextHookEx(_hookHandle, nCode, wParam, lParam);
    }

    private void ProcessKey(NativeMethods.KBDLLHOOKSTRUCT data)
    {
        var key = (Keys)data.vkCode;

        if (key == Keys.Back)
        {
            if (_buffer.Length > 0) _buffer.Length--;
            return;
        }

        if (key == Keys.Space || key == Keys.Enter || key == Keys.Tab)
        {
            TryExpand();
            _buffer.Clear();
            return;
        }

        if (KeyboardLayoutTranslator.TryTranslate(data.vkCode, data.scanCode, out var ch))
        {
            _buffer.Append(ch);
            if (_buffer.Length > MaxBufferLength)
                _buffer.Remove(0, 1); // drop oldest so a long run of text doesn't block matching
        }
        else if (BreaksBuffer(key))
        {
            // A key that actually moves the caret or edits text invalidates
            // a trigger typed so far, same as the macOS behavior.
            DebugLog.Write($"Buffer-breaking key {key}, clearing (was '{_buffer}')");
            _buffer.Clear();
        }
        // Anything else that fails translation — Shift/Ctrl/Alt/Win presses,
        // CapsLock/NumLock/ScrollLock toggles, function keys, media keys —
        // is just ignored. These don't touch the document, so they must not
        // wipe a trigger in progress; an anti-idle/keep-awake tool sending
        // background keystrokes (e.g. NumLock or F15) was doing exactly
        // that and silently eating triggers before this fix.
    }

    private static bool BreaksBuffer(Keys key) => key is
        Keys.Left or Keys.Right or Keys.Up or Keys.Down or
        Keys.Home or Keys.End or Keys.PageUp or Keys.PageDown or
        Keys.Delete or Keys.Insert or Keys.Escape;

    private void TryExpand()
    {
        // Deliberately never logged: the candidate buffer is raw text typed
        // anywhere on the system (up to 40 chars), and could be a password
        // or other sensitive content the user is about to submit elsewhere.
        // Only the fact that a KNOWN, user-authored trigger name matched is
        // safe to log — never the surrounding text or expanded content.
        var candidate = _buffer.ToString();
        var library = _libraryProvider();
        var snippet = library.Snippets
            .Where(s => !string.IsNullOrEmpty(s.Trigger))
            .FirstOrDefault(s => candidate.EndsWith(s.Trigger, StringComparison.Ordinal));

        if (snippet is null) return;

        DebugLog.Write($"Matched trigger '{snippet.Trigger}'");
        _suspended = true;

        try
        {
            DeleteCharacters(snippet.Trigger.Length);
            _buffer.Clear();

            var labels = ExtractInputLabels(snippet.Content);
            if (labels.Count == 0)
            {
                TypeText(ExpandVariables(snippet.Content));
                _suspended = false;
                return;
            }

            // A modal dialog must never be pumped from INSIDE a WH_KEYBOARD_LL
            // callback — Windows expects that callback to return almost
            // immediately, and blocking it on however long a human takes to
            // fill in a popup can stall system-wide keyboard input and risks
            // Windows silently unhooking Snipster. Deferring via BeginInvoke
            // lets the hook return first; this runs moments later, off the
            // hook's call stack, once the dispatcher is free to process it.
            var trigger = snippet.Trigger;
            var content = snippet.Content;
            var contacts = library.Contacts;

            System.Windows.Application.Current.Dispatcher.BeginInvoke(new Action(() =>
            {
                try
                {
                    var inputWindow = new TemplateInputWindow(labels, contacts);
                    if (inputWindow.ShowDialog() == true)
                        TypeText(ExpandVariables(SubstituteInputs(content, inputWindow.Values)));
                    else
                        TypeText(trigger); // restore what the user had typed
                }
                catch (Exception ex)
                {
                    DebugLog.Write($"Deferred template expansion failed: {ex.GetType().Name}: {ex.Message}");
                }
                finally
                {
                    _suspended = false;
                }
            }));
        }
        catch (Exception ex)
        {
            // An unhandled exception here happens INSIDE Windows' hook
            // dispatch — letting it propagate risks the OS silently
            // unregistering a hook whose callback is too slow/faulted.
            DebugLog.Write($"TryExpand threw: {ex.GetType().Name}: {ex.Message}");
            _suspended = false;
        }
    }

    private static List<string> ExtractInputLabels(string content)
    {
        var labels = new List<string>();
        foreach (Match m in InputTokenRegex.Matches(content))
        {
            var label = m.Groups[1].Value;
            if (!labels.Contains(label)) labels.Add(label);
        }
        return labels;
    }

    private static string SubstituteInputs(string content, IReadOnlyDictionary<string, string> values) =>
        InputTokenRegex.Replace(content, m => values.GetValueOrDefault(m.Groups[1].Value, ""));

    private static string ExpandVariables(string content)
    {
        return content
            .Replace("{{DATE}}", DateTime.Now.ToShortDateString())
            .Replace("{{TIME}}", DateTime.Now.ToShortTimeString())
            .Replace("{{USERNAME}}", Environment.UserName)
            .Replace("{{CLIPBOARD}}", TryGetClipboardText());
    }

    private static string TryGetClipboardText()
    {
        try
        {
            // Runs on the hook's own thread (the app's main STA thread), so
            // this is a same-thread clipboard read, not cross-thread.
            return System.Windows.Clipboard.ContainsText() ? System.Windows.Clipboard.GetText() : "";
        }
        catch (System.Runtime.InteropServices.COMException)
        {
            // Another process can hold the clipboard open transiently.
            return "";
        }
    }

    private static void DeleteCharacters(int count)
    {
        var inputs = new NativeMethods.INPUT[count * 2];
        for (int i = 0; i < count; i++)
        {
            inputs[i * 2] = KeyInput(NativeMethods.VK_BACK, keyUp: false);
            inputs[i * 2 + 1] = KeyInput(NativeMethods.VK_BACK, keyUp: true);
        }
        if (inputs.Length == 0) return;

        var sent = NativeMethods.SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<NativeMethods.INPUT>());
        if (sent != inputs.Length)
            DebugLog.Write($"SendInput(backspace) only queued {sent}/{inputs.Length} events, Win32 error {Marshal.GetLastWin32Error()}");
    }

    /// <summary>
    /// Inserts text via clipboard + Ctrl+V rather than synthesizing
    /// KEYEVENTF_UNICODE characters directly. Plain SendInput unicode chars
    /// don't reliably reach the many apps (browsers, Electron/Chromium
    /// apps, anything with JS-driven text state) that update their content
    /// from a real "paste" event rather than raw key events — paste is a
    /// standard OS operation practically everything supports correctly.
    /// </summary>
    private static void TypeText(string text)
    {
        if (text.Length == 0) return;

        System.Windows.IDataObject? previousClipboard = null;
        try
        {
            previousClipboard = System.Windows.Clipboard.GetDataObject();
        }
        catch (System.Runtime.InteropServices.COMException)
        {
            // Another app can hold the clipboard open transiently; proceed
            // without a restore rather than failing the expansion.
        }

        var payload = new System.Windows.DataObject();
        payload.SetText(text);
        // Keep this transient write out of Snipster's own clipboard history
        // — it's an implementation detail of expansion, not something the
        // user copied. Same real Windows convention the history monitor
        // already honors for password managers.
        payload.SetData("ExcludeClipboardContentFromMonitorProcessing", Array.Empty<byte>());

        try
        {
            System.Windows.Clipboard.SetDataObject(payload, true);
        }
        catch (System.Runtime.InteropServices.COMException ex)
        {
            DebugLog.Write($"TypeText: SetDataObject failed, aborting paste: {ex.Message}");
            return;
        }

        var inputs = new[]
        {
            KeyInput(NativeMethods.VK_CONTROL, keyUp: false),
            KeyInput(NativeMethods.VK_V, keyUp: false),
            KeyInput(NativeMethods.VK_V, keyUp: true),
            KeyInput(NativeMethods.VK_CONTROL, keyUp: true),
        };

        var sent = NativeMethods.SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<NativeMethods.INPUT>());
        if (sent != inputs.Length)
            DebugLog.Write($"SendInput(Ctrl+V) only queued {sent}/{inputs.Length} events, Win32 error {Marshal.GetLastWin32Error()}");

        // Our own write above bumped the clipboard sequence number; capture
        // it so the delayed restore can tell whether something ELSE copied
        // in the meantime and skip restoring if so, instead of clobbering it.
        RestoreClipboardAfterPaste(previousClipboard, NativeMethods.GetClipboardSequenceNumber());
    }

    private static void RestoreClipboardAfterPaste(System.Windows.IDataObject? previousClipboard, int sequenceAfterOurWrite)
    {
        // Runs asynchronously so the hook callback returns quickly — blocking
        // it to wait out the paste risks Windows treating the hook as
        // unresponsive and silently removing it.
        var timer = new System.Windows.Threading.DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(400),
        };
        timer.Tick += (_, _) =>
        {
            timer.Stop();

            // If the sequence number moved since our own write, the user (or
            // another app) copied something new in the meantime — leave it
            // alone rather than clobbering it with the pre-expansion content.
            if (NativeMethods.GetClipboardSequenceNumber() != sequenceAfterOurWrite) return;

            try
            {
                if (previousClipboard is not null)
                    System.Windows.Clipboard.SetDataObject(previousClipboard, true);
                else
                    System.Windows.Clipboard.Clear();
            }
            catch (System.Runtime.InteropServices.COMException)
            {
                // Another app grabbed the clipboard meanwhile; not fatal.
            }
        };
        timer.Start();
    }

    private static NativeMethods.INPUT KeyInput(ushort vk, bool keyUp) => new()
    {
        type = NativeMethods.INPUT_KEYBOARD,
        U = new NativeMethods.InputUnion
        {
            ki = new NativeMethods.KEYBDINPUT
            {
                wVk = vk,
                dwFlags = keyUp ? NativeMethods.KEYEVENTF_KEYUP : 0,
            },
        },
    };

    public void Dispose()
    {
        if (_hookHandle != IntPtr.Zero)
        {
            NativeMethods.UnhookWindowsHookEx(_hookHandle);
            _hookHandle = IntPtr.Zero;
        }
    }
}
