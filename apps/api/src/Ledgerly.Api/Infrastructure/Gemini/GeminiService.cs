using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Ledgerly.Api.Infrastructure.Gemini;

public interface IGeminiService
{
    bool IsConfigured { get; }
    Task<T> GenerateObjectAsync<T>(string prompt, string jsonSchemaHint, CancellationToken ct = default);
}

public sealed class GeminiService(
    IHttpClientFactory httpClientFactory,
    IOptions<GeminiOptions> options,
    ILogger<GeminiService> logger) : IGeminiService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    public bool IsConfigured => !string.IsNullOrWhiteSpace(options.Value.ApiKey);

    public async Task<T> GenerateObjectAsync<T>(
        string prompt,
        string jsonSchemaHint,
        CancellationToken ct = default)
    {
        var opts = options.Value;
        if (!IsConfigured)
            throw new InvalidOperationException("Gemini API key is not configured.");

        Exception? lastError = null;
        foreach (var model in opts.Models)
        {
            try
            {
                return await CallModelAsync<T>(model, prompt, jsonSchemaHint, ct);
            }
            catch (Exception ex) when (IsQuotaError(ex))
            {
                lastError = ex;
                logger.LogWarning(ex, "Gemini quota error for model {Model}", model);
                if (model == "gemini-2.5-flash-lite") break;
            }
            catch (Exception ex)
            {
                lastError = ex;
                logger.LogWarning(ex, "Gemini failed for model {Model}", model);
            }
        }

        throw lastError ?? new InvalidOperationException("All Gemini Flash models failed.");
    }

    private async Task<T> CallModelAsync<T>(
        string model,
        string prompt,
        string jsonSchemaHint,
        CancellationToken ct)
    {
        var client = httpClientFactory.CreateClient("gemini");
        var url =
            $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={options.Value.ApiKey}";

        var payload = new
        {
            contents = new[]
            {
                new
                {
                    parts = new[]
                    {
                        new
                        {
                            text =
                                $"{prompt}\n\nRespond with ONLY valid JSON matching this shape (no markdown):\n{jsonSchemaHint}"
                        }
                    }
                }
            },
            generationConfig = new
            {
                responseMimeType = "application/json",
                temperature = 0.2
            }
        };

        using var content = new StringContent(
            JsonSerializer.Serialize(payload),
            Encoding.UTF8,
            "application/json");
        using var response = await client.PostAsync(url, content, ct);
        var body = await response.Content.ReadAsStringAsync(ct);

        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException($"Gemini HTTP {(int)response.StatusCode}: {body}");

        using var doc = JsonDocument.Parse(body);
        var text = doc.RootElement
            .GetProperty("candidates")[0]
            .GetProperty("content")
            .GetProperty("parts")[0]
            .GetProperty("text")
            .GetString();

        if (string.IsNullOrWhiteSpace(text))
            throw new InvalidOperationException("Gemini returned empty content.");

        var cleaned = text.Trim();
        if (cleaned.StartsWith("```"))
        {
            var firstNl = cleaned.IndexOf('\n');
            if (firstNl > 0) cleaned = cleaned[(firstNl + 1)..];
            if (cleaned.EndsWith("```")) cleaned = cleaned[..^3];
            cleaned = cleaned.Trim();
        }

        return JsonSerializer.Deserialize<T>(cleaned, JsonOptions)
               ?? throw new InvalidOperationException("Failed to deserialize Gemini JSON.");
    }

    public static bool IsQuotaError(Exception ex)
    {
        var msg = ex.Message;
        return msg.Contains("quota", StringComparison.OrdinalIgnoreCase)
               || msg.Contains("rate limit", StringComparison.OrdinalIgnoreCase)
               || msg.Contains("resource exhausted", StringComparison.OrdinalIgnoreCase)
               || msg.Contains("429");
    }

    public static string FormatAiError(Exception ex, string fallback)
    {
        if (IsQuotaError(ex))
            return "We’re a bit busy right now. Please wait a minute and try again.";

        var msg = ex.Message;
        if (System.Text.RegularExpressions.Regex.IsMatch(
                msg,
                "api|quota|model|gemini|generate|unauthorized|429|403",
                System.Text.RegularExpressions.RegexOptions.IgnoreCase))
        {
            return fallback;
        }

        return string.IsNullOrWhiteSpace(msg) ? fallback : msg;
    }
}
