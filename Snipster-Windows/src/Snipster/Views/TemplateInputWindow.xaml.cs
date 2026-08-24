using System.Windows;
using System.Windows.Controls;
using Snipster.Models;
// WPF and WinForms are both referenced in this project (the tray icon and
// cursor position need WinForms); alias the WPF versions of every type name
// that also exists in System.Windows.Forms/System.Drawing to avoid CS0104
// ambiguity.
using TextBox = System.Windows.Controls.TextBox;
using Button = System.Windows.Controls.Button;
using Orientation = System.Windows.Controls.Orientation;
using Point = System.Windows.Point;

namespace Snipster.Views;

/// <summary>
/// Borderless popup shown when a snippet's content contains one or more
/// {{INPUT:label}} tokens — mirrors the macOS app's TemplateInputWindow.
/// Positioned near the mouse cursor: unlike Accessibility on macOS, there is
/// no reliable cross-process way to read the caret position on Windows.
/// </summary>
public partial class TemplateInputWindow : Window
{
    private readonly Dictionary<string, TextBox> _fieldsByLabel = new();
    private readonly IReadOnlyList<Contact> _contacts;
    private readonly System.Drawing.Point _cursorPosition;

    public Dictionary<string, string> Values { get; } = new();

    public TemplateInputWindow(IReadOnlyList<string> labels, IReadOnlyList<Contact> contacts)
    {
        InitializeComponent();
        _contacts = contacts;
        _cursorPosition = System.Windows.Forms.Cursor.Position;

        foreach (var label in labels)
        {
            RootPanel.Children.Insert(RootPanel.Children.Count - 1, BuildFieldRow(label));
        }

        // SourceInitialized (not Loaded) fires before the window is painted,
        // so positioning here avoids a visible flash at the default location.
        SourceInitialized += (_, _) => PositionNearCursor();
    }

    private UIElement BuildFieldRow(string label)
    {
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Margin = new Thickness(0, 4, 0, 0),
        };

        row.Children.Add(new TextBlock
        {
            Text = label,
            Width = 90,
            VerticalAlignment = VerticalAlignment.Center,
        });

        var textBox = new TextBox { Width = 150, VerticalAlignment = VerticalAlignment.Center };
        _fieldsByLabel[label] = textBox;
        row.Children.Add(textBox);

        if (LooksLikeContactField(label))
        {
            var pickButton = new Button
            {
                Content = "👤", // bust-in-silhouette glyph
                Width = 28,
                Margin = new Thickness(4, 0, 0, 0),
                ToolTip = "Fill from a contact",
            };
            pickButton.Click += (_, _) => PickContact(label, textBox);
            row.Children.Add(pickButton);
        }

        if (_fieldsByLabel.Count == 1)
        {
            Loaded += (_, _) => textBox.Focus();
        }

        return row;
    }

    private void PickContact(string label, TextBox targetBox)
    {
        var picker = new ContactPickerWindow(_contacts) { Owner = this };
        if (picker.ShowDialog() == true && picker.SelectedContact is { } contact)
        {
            targetBox.Text = ExtractContactValue(contact, label);
        }
    }

    private static bool LooksLikeContactField(string label)
    {
        var l = label.ToLowerInvariant();
        return l.Contains("name") || l.Contains("email") || l.Contains("phone") || l.Contains("address");
    }

    private static string ExtractContactValue(Contact contact, string label)
    {
        var l = label.ToLowerInvariant();
        if (l.Contains("email")) return contact.Email;
        if (l.Contains("phone")) return contact.Phone;
        if (l.Contains("address")) return contact.Address;
        return contact.Name;
    }

    private void PositionNearCursor()
    {
        var source = PresentationSource.FromVisual(this);
        if (source?.CompositionTarget is null) return;

        // TransformFromDevice converts the cursor's physical pixel position
        // into this window's device-independent units, accounting for the
        // DPI of whichever monitor it's on.
        var point = source.CompositionTarget.TransformFromDevice.Transform(
            new Point(_cursorPosition.X, _cursorPosition.Y));

        Left = point.X;
        Top = point.Y + 20;
    }

    private void Insert_Click(object sender, RoutedEventArgs e)
    {
        foreach (var (label, box) in _fieldsByLabel)
            Values[label] = box.Text;

        DialogResult = true;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e) => DialogResult = false;

    private void Window_KeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key == System.Windows.Input.Key.Escape)
            DialogResult = false;
    }
}
