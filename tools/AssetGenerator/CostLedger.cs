using System.Text.Json;

namespace AssetGenerator;

public class LedgerEntry
{
    public DateTime AtUtc { get; set; }
    public string Service { get; set; } = "";
    public string What { get; set; } = "";
    public decimal Usd { get; set; }
    /// <summary>True when no usage figure came back and a rate-based estimate was used instead.</summary>
    public bool Estimated { get; set; }
}

public record ImageUsage(int InputTextTokens, int InputImageTokens, int OutputTokens)
{
    public decimal Cost(PricingSettings p) =>
        (InputTextTokens * p.ImageTextInputUsdPerMTokens + InputImageTokens * p.ImageInputUsdPerMTokens + OutputTokens * p.ImageOutputUsdPerMTokens) / 1_000_000m;
}

/// <summary>Running total of API spend (content/generated/cost-ledger.json). Refuses runs that would exceed the budget.</summary>
public class CostLedger
{
    private readonly string _path;
    public List<LedgerEntry> Entries { get; private set; } = [];
    public decimal Budget { get; }

    public CostLedger(string path, decimal budget)
    {
        _path = path;
        Budget = budget;
        if (File.Exists(path))
            Entries = JsonSerializer.Deserialize<List<LedgerEntry>>(File.ReadAllText(path), new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? [];
    }

    public decimal Total => Entries.Sum(e => e.Usd);

    public void EnsureWithinBudget(decimal planned)
    {
        if (Total + planned > Budget)
            throw new ApiException($"Budget guard: spent ${Total:0.00} + planned ${planned:0.00} would exceed the ${Budget:0.00} limit. Nothing was generated.");
    }

    public void Add(string service, string what, decimal usd, bool estimated = false)
    {
        Entries.Add(new LedgerEntry { AtUtc = DateTime.UtcNow, Service = service, What = what, Usd = Math.Round(usd, 6), Estimated = estimated });
        Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
        File.WriteAllText(_path, ConfigLoader.ToJson(Entries));
    }

    public string Summary() =>
        $"Spend so far: ${Total:0.00} of ${Budget:0.00} (" + string.Join(", ", Entries.GroupBy(e => e.Service).Select(g => $"{g.Key} ${g.Sum(e => e.Usd):0.00}")) + ")";
}
