namespace Ledgerly.Api.Infrastructure;

public sealed class SupabaseOptions
{
    public const string SectionName = "Supabase";

    public string Url { get; set; } = "";
    public string AnonKey { get; set; } = "";
    public string JwtSecret { get; set; } = "";
}

public sealed class GroqOptions
{
    public const string SectionName = "Groq";

    public string ApiKey { get; set; } = "";
    public string BaseUrl { get; set; } = "https://api.groq.com/openai/v1";
    public string[] Models { get; set; } =
    [
        "openai/gpt-oss-20b",
        "openai/gpt-oss-120b"
    ];
}

public sealed class LedgerlyCorsOptions
{
    public const string SectionName = "Cors";

    public string[] Origins { get; set; } = ["http://localhost:3000"];
}
