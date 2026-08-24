namespace Snipster.Models;

/// <summary>
/// Local-only address book entry. macOS Snipster autofills from the system
/// Contacts database (CNContactStore); Windows has no equivalent store that
/// ordinary desktop apps share, so contacts here live inside Snipster's own
/// JSON library instead of integrating with an OS-level contacts source.
/// </summary>
public class Contact
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = "";
    public string Email { get; set; } = "";
    public string Phone { get; set; } = "";
    public string Address { get; set; } = "";
}
