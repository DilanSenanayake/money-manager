using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
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
        NumberHandling = JsonNumberHandling.AllowReadingFromString,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
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
            throw new InvalidOperationException(DescribeGeminiHttpError((int)response.StatusCode, body));

        using var doc = JsonDocument.Parse(body);
        if (!doc.RootElement.TryGetProperty("candidates", out var candidates)
            || candidates.GetArrayLength() == 0)
        {
            var block = TryGetBlockReason(doc.RootElement);
            throw new InvalidOperationException(
                string.IsNullOrEmpty(block)
                    ? "Gemini returned no candidates."
                    : $"Gemini blocked the response ({block}).");
        }

        var text = candidates[0]
            .GetProperty("content")
            .GetProperty("parts")[0]
            .GetProperty("text")
            .GetString();

        if (string.IsNullOrWhiteSpace(text))
            throw new InvalidOperationException("Gemini returned empty content.");

        var cleaned = StripCodeFence(text.Trim());

        try
        {
            return JsonSerializer.Deserialize<T>(cleaned, JsonOptions)
                   ?? throw new InvalidOperationException("Failed to deserialize Gemini JSON.");
        }
        catch (JsonException ex)
        {
            logger.LogWarning(ex, "Gemini JSON parse failed. Payload: {Payload}", cleaned);
            throw new InvalidOperationException(
                $"Could not parse AI JSON: {ex.Message}");
        }
    }

    private static string StripCodeFence(string cleaned)
    {
        if (!cleaned.StartsWith("```")) return cleaned;
        var firstNl = cleaned.IndexOf('\n');
        if (firstNl > 0) cleaned = cleaned[(firstNl + 1)..];
        if (cleaned.EndsWith("```")) cleaned = cleaned[..^3];
        return cleaned.Trim();
    }

    private static string? TryGetBlockReason(JsonElement root)
    {
        if (root.TryGetProperty("promptFeedback", out var feedback)
            && feedback.TryGetProperty("blockReason", out var reason))
        {
            return reason.GetString();
        }

        return null;
    }

    private static string DescribeGeminiHttpError(int status, string body)
    {
        var detail = body;
        try
        {
            using var doc = JsonDocument.Parse(body);
            if (doc.RootElement.TryGetProperty("error", out var err))
            {
                if (err.TryGetProperty("message", out var msg))
                    detail = msg.GetString() ?? body;
                else
                    detail = err.ToString();
            }
        }
        catch
        {
            // keep raw body
        }

        if (detail.Length > 280) detail = detail[..280] + "...";

        return status switch
        {
            401 or 403 => $"Gemini API key was rejected ({status}): {detail}",
            404 => $"Gemini model not found ({status}): {detail}",
            429 => $"Gemini rate limit ({status}): {detail}",
            _ => $"Gemini HTTP {status}: {detail}",
        };
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
            return "We're a bit busy right now. Please wait a minute and try again.";

        var msg = ex.Message ?? "";

        if (msg.Contains("API key", StringComparison.OrdinalIgnoreCase)
            || msg.Contains("rejected", StringComparison.OrdinalIgnoreCase)
            || msg.Contains("API_KEY", StringComparison.OrdinalIgnoreCase))
        {
            return "Smart add isn't configured correctly (Gemini API key). Check the API env and try again.";
        }

        if (msg.Contains("model not found", StringComparison.OrdinalIgnoreCase)
            || msg.Contains("NOT_FOUND", StringComparison.OrdinalIgnoreCase))
        {
            return "The AI model isn't available right now. Try again in a bit, or add the entry manually.";
        }

        if (msg.Contains("Could not parse AI JSON", StringComparison.OrdinalIgnoreCase)
            || msg.Contains("empty content", StringComparison.OrdinalIgnoreCase)
            || msg.Contains("no candidates", StringComparison.OrdinalIgnoreCase)
            || msg.Contains("blocked", StringComparison.OrdinalIgnoreCase))
        {
            return "We couldn't understand that message. Try a clearer bank SMS, or add it manually.";
        }

        // Prefer a short, readable Gemini detail over a total black box
        if (msg.StartsWith("Gemini HTTP", StringComparison.OrdinalIgnoreCase)
            || msg.StartsWith("Gemini API", StringComparison.OrdinalIgnoreCase))
        {
            return msg.Length > 180 ? msg[..180] + "..." : msg;
        }

        return string.IsNullOrWhiteSpace(msg) ? fallback : msg;
    }
}
