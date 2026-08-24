using System.Windows;
using Snipster.Models;

namespace Snipster.Views;

public partial class ContactPickerWindow : Window
{
    public Contact? SelectedContact { get; private set; }

    public ContactPickerWindow(IReadOnlyList<Contact> contacts)
    {
        InitializeComponent();
        ContactsList.ItemsSource = contacts;
        if (contacts.Count > 0) ContactsList.SelectedIndex = 0;
    }

    private void Select_Click(object sender, RoutedEventArgs e) => Accept();

    private void ContactsList_MouseDoubleClick(object sender, System.Windows.Input.MouseButtonEventArgs e) => Accept();

    private void Cancel_Click(object sender, RoutedEventArgs e) => DialogResult = false;

    private void Accept()
    {
        SelectedContact = ContactsList.SelectedItem as Contact;
        DialogResult = SelectedContact is not null;
    }
}
