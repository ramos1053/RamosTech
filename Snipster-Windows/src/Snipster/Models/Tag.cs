namespace Snipster.Models;

public class Tag
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = "";
    public string ColorHex { get; set; } = "#4A90D9";
}
