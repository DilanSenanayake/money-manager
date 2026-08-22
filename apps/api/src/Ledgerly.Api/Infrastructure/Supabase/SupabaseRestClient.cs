using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;

namespace Ledgerly.Api.Infrastructure.Supabase;

public interface ICurrentUser
{
    Guid UserId { get; }
    string AccessToken { get; }
}

public sealed class CurrentUser(IHttpContextAccessor httpContextAccessor) : ICurrentUser
{
    public Guid UserId
    {
        get
        {
            var user = httpContextAccessor.HttpContext?.User
                       ?? throw new UnauthorizedAccessException("No authenticated user.");
            var sub = user.FindFirstValue("sub")
                      ?? user.FindFirstValue(ClaimTypes.NameIdentifier)
                      ?? throw new UnauthorizedAccessException("Missing subject claim.");
            return Guid.Parse(sub);
        }
    }

    public string AccessToken
    {
        get
        {
            var auth = httpContextAccessor.HttpContext?.Request.Headers.Authorization.ToString();
            if (string.IsNullOrWhiteSpace(auth) || !auth.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                throw new UnauthorizedAccessException("Missing bearer token.");
            return auth["Bearer ".Length..].Trim();
        }
    }
}

public interface ISupabaseRestClient
{
    Task<List<T>> GetListAsync<T>(string table, string? query = null, CancellationToken ct = default);
    Task<T?> GetSingleAsync<T>(string table, string? query = null, CancellationToken ct = default);
    Task<T?> InsertAsync<T>(string table, object payload, CancellationToken ct = default);
    Task InsertManyAsync(string table, object payload, CancellationToken ct = default);
    Task UpdateAsync(string table, string filterQuery, object payload, CancellationToken ct = default);
    Task UpsertAsync(string table, object payload, string onConflict, CancellationToken ct = default);
    Task DeleteAsync(string table, string filterQuery, CancellationToken ct = default);
}

public sealed class SupabaseRestClient(
    IHttpClientFactory httpClientFactory,
    ICurrentUser currentUser,
    IOptions<SupabaseOptions> options) : ISupabaseRestClient
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    private HttpClient Client => httpClientFactory.CreateClient("supabase");

    private Uri BuildUri(string relative)
    {
        var opts = options.Value;
        if (string.IsNullOrWhiteSpace(opts.Url) || string.IsNullOrWhiteSpace(opts.AnonKey))
            throw new InvalidOperationException("Supabase Url and AnonKey must be configured.");

        return new Uri($"{opts.Url.TrimEnd('/')}/rest/v1/{relative}");
    }

    private HttpRequestMessage CreateRequest(HttpMethod method, string relative, string? prefer = null)
    {
        var request = new HttpRequestMessage(method, BuildUri(relative));
        request.Headers.Add("apikey", options.Value.AnonKey);
        request.Headers.Authorization =
            new AuthenticationHeaderValue("Bearer", currentUser.AccessToken);
        request.Headers.Add("Prefer", prefer ?? "return=representation");
        return request;
    }

    public async Task<List<T>> GetListAsync<T>(string table, string? query = null, CancellationToken ct = default)
    {
        var path = string.IsNullOrWhiteSpace(query) ? table : $"{table}?{query}";
        using var request = CreateRequest(HttpMethod.Get, path);
        using var response = await Client.SendAsync(request, ct);
        var body = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(ParseError(body, response.StatusCode));

        return JsonSerializer.Deserialize<List<T>>(body, JsonOptions) ?? [];
    }

    public async Task<T?> GetSingleAsync<T>(string table, string? query = null, CancellationToken ct = default)
    {
        var list = await GetListAsync<T>(table, query, ct);
        return list.FirstOrDefault();
    }

    public async Task<T?> InsertAsync<T>(string table, object payload, CancellationToken ct = default)
    {
        using var request = CreateRequest(HttpMethod.Post, table);
        request.Content = JsonContent(payload);
        using var response = await Client.SendAsync(request, ct);
        var body = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(ParseError(body, response.StatusCode));

        var list = JsonSerializer.Deserialize<List<T>>(body, JsonOptions);
        return list is { Count: > 0 } ? list[0] : default;
    }

    public async Task InsertManyAsync(string table, object payload, CancellationToken ct = default)
    {
        using var request = CreateRequest(HttpMethod.Post, table);
        request.Content = JsonContent(payload);
        using var response = await Client.SendAsync(request, ct);
        var body = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(ParseError(body, response.StatusCode));
    }

    public async Task UpdateAsync(string table, string filterQuery, object payload, CancellationToken ct = default)
    {
        using var request = CreateRequest(HttpMethod.Patch, $"{table}?{filterQuery}");
        request.Content = JsonContent(payload);
        using var response = await Client.SendAsync(request, ct);
        var body = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(ParseError(body, response.StatusCode));
    }

    public async Task UpsertAsync(string table, object payload, string onConflict, CancellationToken ct = default)
    {
        using var request = CreateRequest(
            HttpMethod.Post,
            $"{table}?on_conflict={onConflict}",
            "resolution=merge-duplicates,return=representation");
        request.Content = JsonContent(payload);
        using var response = await Client.SendAsync(request, ct);
        var body = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(ParseError(body, response.StatusCode));
    }

    public async Task DeleteAsync(string table, string filterQuery, CancellationToken ct = default)
    {
        using var request = CreateRequest(HttpMethod.Delete, $"{table}?{filterQuery}");
        using var response = await Client.SendAsync(request, ct);
        var body = await response.Content.ReadAsStringAsync(ct);
        if (!response.IsSuccessStatusCode)
            throw new InvalidOperationException(ParseError(body, response.StatusCode));
    }

    private static StringContent JsonContent(object payload) =>
        new(JsonSerializer.Serialize(payload, JsonOptions), Encoding.UTF8, "application/json");

    private static string ParseError(string body, System.Net.HttpStatusCode status)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            if (doc.RootElement.TryGetProperty("message", out var message))
                return message.GetString() ?? status.ToString();
            if (doc.RootElement.TryGetProperty("error", out var error))
                return error.GetString() ?? status.ToString();
        }
        catch
        {
            // ignore parse failures
        }

        return string.IsNullOrWhiteSpace(body) ? status.ToString() : body;
    }
}
