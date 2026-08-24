using System.Runtime.InteropServices;
using System.Windows.Interop;
using Keys = System.Windows.Forms.Keys;
using Snipster.Native;

namespace Snipster.Services;

/// <summary>
/// Wraps Win32 RegisterHotKey via a hidden message-only window. Equivalent
/// role to HotkeyManager on macOS (which used Carbon's RegisterEventHotkey),
/// but this is entirely user-level: no admin rights required.
/// </summary>
public class HotkeyManager : IDisposable
{
    // Win32 error code for "some other process already owns this hotkey" —
    // the one conflict RegisterHotKey can actually tell us about; there is
    // no API to enumerate what already holds a combo, only to try and fail.
    private const int ERROR_HOTKEY_ALREADY_REGISTERED = 1409;

    private const int HotkeyId = 0x5A1B;

    private readonly HwndSource _source;
    private bool _isRegistered;

    public event Action? HotkeyPressed;

    public uint CurrentModifiers { get; private set; }
    public uint CurrentVirtualKey { get; private set; }

    public HotkeyManager()
    {
        // A message-only window just to receive WM_HOTKEY; never shown.
        var parameters = new HwndSourceParameters("SnipsterHotkeyWindow")
        {
            Width = 0,
            Height = 0,
            WindowStyle = 0,
            ParentWindow = new IntPtr(-3), // HWND_MESSAGE
        };

        _source = new HwndSource(parameters);
        _source.AddHook(WndProc);
    }

    public bool RegisterDefault()
    {
        // Ctrl+Shift+S, matching the macOS app's default Cmd+Shift+S.
        return TryAssign(NativeMethods.MOD_CONTROL | NativeMethods.MOD_SHIFT, (uint)Keys.S, out _);
    }

    /// <summary>
    /// Attempts to move the hotkey to a new combo. The OLD binding stays
    /// active untouched unless the new one succeeds — a rejected change
    /// must never leave the user with no working hotkey at all.
    /// </summary>
    public bool TryAssign(uint modifiers, uint virtualKey, out string? conflictMessage)
    {
        conflictMessage = null;

        // Probe with a throwaway id first: RegisterHotKey is also the only
        // way to DETECT a conflict (there's no "is this combo free?" query),
        // so we test on a scratch id before touching the real one, and
        // immediately release the probe regardless of outcome.
        const int probeId = HotkeyId + 1;
        var probeOk = NativeMethods.RegisterHotKey(_source.Handle, probeId, modifiers, virtualKey);
        var probeError = Marshal.GetLastWin32Error();
        if (probeOk) NativeMethods.UnregisterHotKey(_source.Handle, probeId);

        if (!probeOk)
        {
            conflictMessage = probeError == ERROR_HOTKEY_ALREADY_REGISTERED
                ? "That key combination is already registered by another running application."
                : $"That key combination could not be registered (Win32 error {probeError}).";
            DebugLog.Write($"HotkeyManager: rejected {Describe(modifiers, virtualKey)} — {conflictMessage}");
            return false;
        }

        if (_isRegistered)
            NativeMethods.UnregisterHotKey(_source.Handle, HotkeyId);

        var applied = NativeMethods.RegisterHotKey(_source.Handle, HotkeyId, modifiers, virtualKey);
        if (!applied)
        {
            // Vanishingly unlikely given the probe just succeeded (another
            // process would have to grab it in this exact instant), but
            // don't leave _isRegistered lying about state if it happens.
            _isRegistered = false;
            conflictMessage = "That key combination could not be registered.";
            return false;
        }

        _isRegistered = true;
        CurrentModifiers = modifiers;
        CurrentVirtualKey = virtualKey;
        DebugLog.Write($"HotkeyManager: assigned {Describe(modifiers, virtualKey)}");
        return true;
    }

    public static string Describe(uint modifiers, uint virtualKey)
    {
        var parts = new List<string>();
        if ((modifiers & NativeMethods.MOD_CONTROL) != 0) parts.Add("Ctrl");
        if ((modifiers & NativeMethods.MOD_SHIFT) != 0) parts.Add("Shift");
        if ((modifiers & NativeMethods.MOD_ALT) != 0) parts.Add("Alt");
        if ((modifiers & NativeMethods.MOD_WIN) != 0) parts.Add("Win");
        parts.Add(((Keys)virtualKey).ToString());
        return string.Join("+", parts);
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == NativeMethods.WM_HOTKEY && wParam.ToInt32() == HotkeyId)
        {
            HotkeyPressed?.Invoke();
            handled = true;
        }

        return IntPtr.Zero;
    }

    public void Dispose()
    {
        if (_isRegistered)
            NativeMethods.UnregisterHotKey(_source.Handle, HotkeyId);
        _source.RemoveHook(WndProc);
        _source.Dispose();
    }
}
