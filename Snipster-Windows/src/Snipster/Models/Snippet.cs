namespace Snipster.Models;

public class Snippet
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Trigger { get; set; } = "";
    public string Content { get; set; } = "";
    public string? TagId { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset ModifiedAt { get; set; } = DateTimeOffset.UtcNow;
}
