namespace Snipster.Models;

public class ClipboardHistoryEntry
{
    public string Text { get; init; } = "";
    public DateTimeOffset CopiedAt { get; init; } = DateTimeOffset.Now;
}
