namespace Ledgerly.Api.Infrastructure;

public sealed class SupabaseOptions
{
    public const string SectionName = "Supabase";

    public string Url { get; set; } = "";
    public string AnonKey { get; set; } = "";
    public string JwtSecret { get; set; } = "";
}

public sealed class GeminiOptions
{
    public const string SectionName = "Gemini";

    public string ApiKey { get; set; } = "";
    public string[] Models { get; set; } =
    [
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite",
        "gemini-flash-latest"
    ];
}

public sealed class LedgerlyCorsOptions
{
    public const string SectionName = "Cors";

    public string[] Origins { get; set; } = ["http://localhost:3000"];
}
