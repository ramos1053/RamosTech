using System.Windows;
using System.Windows.Input;
using Snipster.Native;
using Snipster.Services;
using KeyEventArgs = System.Windows.Input.KeyEventArgs;

namespace Snipster.Views;

/// <summary>
/// Captures a new global-hotkey combo and validates it against every other
/// running app before committing — RegisterHotKey itself is the only way to
/// detect that conflict, so "Apply" is the actual conflict check.
/// </summary>
public partial class HotkeyCaptureWindow : Window
{
    private readonly HotkeyManager _hotkeyManager;
    private uint _pendingModifiers;
    private uint _pendingVirtualKey;

    public HotkeyCaptureWindow(HotkeyManager hotkeyManager)
    {
        InitializeComponent();
        _hotkeyManager = hotkeyManager;
        Loaded += (_, _) => Focus();
    }

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        e.Handled = true;
        ErrorLabel.Visibility = Visibility.Collapsed;

        var key = e.Key == Key.System ? e.SystemKey : e.Key;

        if (key is Key.LeftCtrl or Key.RightCtrl or Key.LeftShift or Key.RightShift
            or Key.LeftAlt or Key.RightAlt or Key.LWin or Key.RWin)
        {
            // A modifier on its own isn't a valid hotkey yet — show what's
            // held so far and wait for a non-modifier key.
            CaptureLabel.Text = DescribeModifiersOnly();
            ApplyButton.IsEnabled = false;
            return;
        }

        if (key == Key.Escape)
        {
            DialogResult = false;
            return;
        }

        var modifiers = ToNativeModifiers(Keyboard.Modifiers);
        if (modifiers == 0)
        {
            CaptureLabel.Text = "Hold at least one modifier (Ctrl/Shift/Alt/Win)";
            ApplyButton.IsEnabled = false;
            return;
        }

        _pendingModifiers = modifiers;
        _pendingVirtualKey = (uint)KeyInterop.VirtualKeyFromKey(key);
        CaptureLabel.Text = HotkeyManager.Describe(_pendingModifiers, _pendingVirtualKey);
        ApplyButton.IsEnabled = true;
    }

    private void Apply_Click(object sender, RoutedEventArgs e)
    {
        if (_hotkeyManager.TryAssign(_pendingModifiers, _pendingVirtualKey, out var conflict))
        {
            DialogResult = true;
            return;
        }

        ErrorLabel.Text = conflict;
        ErrorLabel.Visibility = Visibility.Visible;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => DialogResult = false;

    private static uint ToNativeModifiers(ModifierKeys modifiers)
    {
        uint result = 0;
        if (modifiers.HasFlag(ModifierKeys.Control)) result |= NativeMethods.MOD_CONTROL;
        if (modifiers.HasFlag(ModifierKeys.Shift)) result |= NativeMethods.MOD_SHIFT;
        if (modifiers.HasFlag(ModifierKeys.Alt)) result |= NativeMethods.MOD_ALT;
        if (modifiers.HasFlag(ModifierKeys.Windows)) result |= NativeMethods.MOD_WIN;
        return result;
    }

    private static string DescribeModifiersOnly()
    {
        var parts = new List<string>();
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Control)) parts.Add("Ctrl");
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Shift)) parts.Add("Shift");
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Alt)) parts.Add("Alt");
        if (Keyboard.Modifiers.HasFlag(ModifierKeys.Windows)) parts.Add("Win");
        return parts.Count == 0 ? "(waiting for keys...)" : string.Join("+", parts) + "+...";
    }
}
