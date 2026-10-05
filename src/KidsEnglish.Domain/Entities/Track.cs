namespace KidsEnglish.Domain.Entities;

public class Track
{
    public int Id { get; set; }
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public int MinAge { get; set; }
    public int MaxAge { get; set; }
    public string CefrFrom { get; set; } = "";
    public string CefrTo { get; set; } = "";

    public List<Lesson> Lessons { get; set; } = [];
}
