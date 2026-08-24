using System.Runtime.InteropServices;

namespace Snipster.Native;

internal static class NativeMethods
{
    // --- Global hotkeys (RegisterHotKey) ---
    // User-level API: no admin rights needed to register or receive WM_HOTKEY.

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    public const int WM_HOTKEY = 0x0312;
    public const uint MOD_ALT = 0x0001;
    public const uint MOD_CONTROL = 0x0002;
    public const uint MOD_SHIFT = 0x0004;
    public const uint MOD_WIN = 0x0008;

    // --- Low-level keyboard hook (SetWindowsHookEx WH_KEYBOARD_LL) ---
    // User-level API. NOTE: cannot observe/inject keystrokes in a window
    // that belongs to a HIGHER-integrity process (e.g. an app running
    // "as Administrator") — that is Windows UIPI, the rough equivalent of
    // macOS refusing Accessibility control across a permission boundary.

    public const int WH_KEYBOARD_LL = 13;
    public const int WM_KEYDOWN = 0x0100;
    public const int WM_SYSKEYDOWN = 0x0104;

    public delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct KBDLLHOOKSTRUCT
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetModuleHandle(string lpModuleName);

    // --- Synthesizing input (SendInput) ---
    // Same UIPI boundary applies here as the keyboard hook above.

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT
    {
        public uint type;
        public InputUnion U;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct InputUnion
    {
        // MOUSEINPUT must be present even though we never use it: it's the
        // LARGEST member of the real Win32 union (32 bytes vs KEYBDINPUT's
        // 24 on x64), so it's what actually determines the union's — and
        // therefore INPUT's — true size. Without it, Marshal.SizeOf<INPUT>()
        // comes out 8 bytes short of the real 40-byte native struct, and
        // SendInput silently rejects every call with ERROR_INVALID_PARAMETER
        // because the reported cbSize doesn't match what it expects.
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    public const uint INPUT_KEYBOARD = 1;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const ushort VK_BACK = 0x08;
    public const ushort VK_V = 0x56;

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    // --- Layout-aware key translation (ToUnicodeEx) ---
    // Used instead of a hardcoded VK->char table so trigger matching works
    // under non-US keyboard layouts and respects live Shift/AltGr/CapsLock
    // state, not just a US QWERTY assumption.

    public const int VK_SHIFT = 0x10;
    public const int VK_CONTROL = 0x11;
    public const int VK_MENU = 0x12;
    public const int VK_CAPITAL = 0x14;
    public const uint VK_SPACE = 0x20;

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern IntPtr GetKeyboardLayout(uint idThread);

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern short GetKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern int ToUnicodeEx(
        uint wVirtKey, uint wScanCode, byte[] lpKeyState,
        System.Text.StringBuilder pwszBuff, int cchBuff, uint wFlags, IntPtr dwhkl);

    // --- Tray icon generation ---

    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr hIcon);

    // --- Clipboard history (AddClipboardFormatListener) ---
    // Event-driven, user-level API — no admin rights and no polling needed.

    public const int WM_CLIPBOARDUPDATE = 0x031D;

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool AddClipboardFormatListener(IntPtr hwnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RemoveClipboardFormatListener(IntPtr hwnd);

    // Lets the post-paste clipboard restore detect "did something ELSE
    // copy in the meantime?" and skip restoring if so, instead of blindly
    // clobbering a newer copy.
    [DllImport("user32.dll")]
    public static extern int GetClipboardSequenceNumber();
}
