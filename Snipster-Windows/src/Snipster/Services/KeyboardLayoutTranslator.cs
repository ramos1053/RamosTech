using System.Text;
using Snipster.Native;

namespace Snipster.Services;

/// <summary>
/// Translates a virtual-key code to the character it actually produces,
/// using the ACTIVE FOREGROUND WINDOW's keyboard layout and live modifier
/// state — correct for non-US layouts, AltGr, and CapsLock, unlike a
/// hardcoded VK-to-char table that only holds for US QWERTY.
/// </summary>
internal static class KeyboardLayoutTranslator
{
    // Reused across calls (this only ever runs on the hook's thread) to
    // avoid allocating on every keystroke.
    [ThreadStatic] private static byte[]? _keyState;
    [ThreadStatic] private static StringBuilder? _output;

    public static bool TryTranslate(uint vkCode, uint scanCode, out char result)
    {
        result = '\0';

        // GetKeyboardState() only reflects the CALLING thread's input state,
        // not the foreground app's, so we look up that app's layout and
        // sample modifier keys directly instead.
        var foregroundWindow = NativeMethods.GetForegroundWindow();
        var threadId = NativeMethods.GetWindowThreadProcessId(foregroundWindow, out _);
        var layout = NativeMethods.GetKeyboardLayout(threadId);

        var keyState = _keyState ??= new byte[256];
        Array.Clear(keyState);
        SetModifier(keyState, NativeMethods.VK_SHIFT);
        SetModifier(keyState, NativeMethods.VK_CONTROL);
        SetModifier(keyState, NativeMethods.VK_MENU);
        if ((NativeMethods.GetKeyState(NativeMethods.VK_CAPITAL) & 0x1) != 0)
            keyState[NativeMethods.VK_CAPITAL] = 1; // toggle state lives in the low-order bit

        var output = _output ??= new StringBuilder(8);
        output.Clear();

        var translated = NativeMethods.ToUnicodeEx(vkCode, scanCode, keyState, output, output.Capacity, 0, layout);

        switch (translated)
        {
            case 1:
                result = output[0];
                return true;

            case < 0:
                // Dead key (e.g. '^' on an intl. layout, awaiting the next
                // letter to combine with). Flush it with a dummy VK_SPACE
                // translation so it doesn't corrupt the NEXT keystroke.
                var emptyState = new byte[256];
                var scratch = new StringBuilder(8);
                NativeMethods.ToUnicodeEx(NativeMethods.VK_SPACE, scanCode, emptyState, scratch, scratch.Capacity, 0, layout);
                return false;

            default:
                return false;
        }
    }

    private static void SetModifier(byte[] keyState, int vk)
    {
        if ((NativeMethods.GetAsyncKeyState(vk) & 0x8000) != 0)
            keyState[vk] = 0x80;
    }
}
