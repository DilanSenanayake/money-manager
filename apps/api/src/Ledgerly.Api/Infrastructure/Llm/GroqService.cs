using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;

namespace Ledgerly.Api.Infrastructure.Llm;

public sealed class GroqService(
    IHttpClientFactory httpClientFactory,
    IOptions<GroqOptions> options,
    ILogger<GroqService> logger) : ILlmService
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
            throw new InvalidOperationException("Groq API key is not configured.");

        Exception? lastError = null;
        foreach (var model in opts.Models)
        {
            try
            {
                return await CallModelAsync<T>(model, prompt, jsonSchemaHint, ct);
            }
            catch (Exception ex) when (IsRetryable(ex))
            {
                lastError = ex;
                logger.LogWarning(ex, "Groq retryable error for model {Model}", model);
            }
            catch (Exception ex)
            {
                lastError = ex;
                logger.LogWarning(ex, "Groq failed for model {Model}", model);
            }
        }

        throw lastError ?? new InvalidOperationException("All Groq models failed.");
    }

    private async Task<T> CallModelAsync<T>(
        string model,
        string prompt,
        string jsonSchemaHint,
        CancellationToken ct)
    {
        var client = httpClientFactory.CreateClient("groq");
        var url = string.IsNullOrWhiteSpace(options.Value.BaseUrl)
            ? "https://api.groq.com/openai/v1/chat/completions"
            : options.Value.BaseUrl.TrimEnd('/');

        if (!url.EndsWith("/chat/completions", StringComparison.OrdinalIgnoreCase))
            url = $"{url.TrimEnd('/')}/chat/completions";

        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.Authorization =
            new AuthenticationHeaderValue("Bearer", options.Value.ApiKey);

        var payload = new
        {
            model,
            temperature = 0.2,
            max_tokens = 1024,
            response_format = new { type = "json_object" },
            messages = new[]
            {
                new
                {
                    role = "system",
                    content =
                        "You extract structured personal-finance data. Respond with ONLY valid JSON matching the requested shape. No markdown."
                },
                new
                {
                    role = "user",
                    content =
                        $"{prompt}\n\nRespond with ONLY valid JSON matching this shape:\n{jsonSchemaHint}"
                }
            }
        };

        request.Content = new StringContent(
            JsonSerializer.Serialize(payload),
            Encoding.UTF8,
            "application/json");

        using var response = await client.SendAsync(request, ct);
        var body = await response.Content.ReadAsStringAsync(ct);

        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(DescribeHttpError((int)response.StatusCode, body));

        using var doc = JsonDocument.Parse(body);
        if (!doc.RootElement.TryGetProperty("choices", out var choices)
            || choices.GetArrayLength() == 0)
        {
            throw new InvalidOperationException("Groq returned no choices.");
        }

        var text = choices[0]
            .GetProperty("message")
            .GetProperty("content")
            .GetString();

        if (string.IsNullOrWhiteSpace(text))
            throw new InvalidOperationException("Groq returned empty content.");

        var cleaned = StripCodeFence(text.Trim());

        try
        {
            return JsonSerializer.Deserialize<T>(cleaned, JsonOptions)
                   ?? throw new InvalidOperationException("Failed to deserialize Groq JSON.");
        }
        catch (JsonException ex)
        {
            logger.LogWarning(ex, "Groq JSON parse failed. Payload: {Payload}", cleaned);
            throw new InvalidOperationException($"Could not parse AI JSON: {ex.Message}");
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

    private static string DescribeHttpError(int status, string body)
    {
        var detail = body;
        try
        {
            using var doc = JsonDocument.Parse(body);
            if (doc.RootElement.TryGetProperty("error", out var err))
            {
                if (err.ValueKind == JsonValueKind.Object
                    && err.TryGetProperty("message", out var msg))
                {
                    detail = msg.GetString() ?? body;
                }
                else if (err.ValueKind == JsonValueKind.String)
                {
                    detail = err.GetString() ?? body;
                }
                else
                {
                    detail = err.ToString();
                }
            }
        }
        catch
        {
            // keep raw body
        }

        if (detail.Length > 280) detail = detail[..280] + "...";

        return status switch
        {
            401 or 403 => $"Groq API key was rejected ({status}): {detail}",
            404 => $"Groq model not found ({status}): {detail}",
            429 => $"Groq rate limit ({status}): {detail}",
            503 => $"Groq unavailable ({status}): {detail}",
            _ => $"Groq HTTP {status}: {detail}",
        };
    }

    public static bool IsRetryable(Exception ex)
    {
        var msg = ex.Message;
        return msg.Contains("quota", StringComparison.OrdinalIgnoreCase)
               || msg.Contains("rate limit", StringComparison.OrdinalIgnoreCase)
               || msg.Contains("429", StringComparison.OrdinalIgnoreCase)
               || msg.Contains("503", StringComparison.OrdinalIgnoreCase)
               || msg.Contains("high demand", StringComparison.OrdinalIgnoreCase)
               || msg.Contains("unavailable", StringComparison.OrdinalIgnoreCase);
    }

    public static string FormatAiError(Exception ex, string fallback)
    {
        if (IsRetryable(ex))
            return "We're a bit busy right now. Please wait a minute and try again.";

        var msg = ex.Message ?? "";

        if (msg.Contains("API key", StringComparison.OrdinalIgnoreCase)
            || msg.Contains("rejected", StringComparison.OrdinalIgnoreCase))
        {
            return "Smart add isn't configured correctly (Groq API key). Check the API env and try again.";
        }

        if (msg.Contains("model not found", StringComparison.OrdinalIgnoreCase)
            || msg.Contains("Groq model not found", StringComparison.OrdinalIgnoreCase))
        {
            return "The AI model isn't available right now. Try again in a bit, or add the entry manually.";
        }

        if (msg.Contains("Could not parse AI JSON", StringComparison.OrdinalIgnoreCase)
            || msg.Contains("empty content", StringComparison.OrdinalIgnoreCase)
            || msg.Contains("no choices", StringComparison.OrdinalIgnoreCase))
        {
            return "We couldn't understand that message. Try a clearer bank SMS, or add it manually.";
        }

        if (msg.StartsWith("Groq HTTP", StringComparison.OrdinalIgnoreCase)
            || msg.StartsWith("Groq API", StringComparison.OrdinalIgnoreCase)
            || msg.StartsWith("Groq ", StringComparison.OrdinalIgnoreCase))
        {
            return msg.Length > 180 ? msg[..180] + "..." : msg;
        }

        return string.IsNullOrWhiteSpace(msg) ? fallback : msg;
    }
}
