using System.Diagnostics;
using System.Security.Claims;

namespace Ledgerly.Api.Infrastructure.Logging;

/// <summary>
/// Correlation id, ambient log scope, and one access line per request.
/// Bodies, query strings, and credentials are never written.
/// </summary>
public static class RequestLoggingMiddleware
{
    public const string RequestIdItemKey = "Ledgerly.RequestId";

    public static IApplicationBuilder UseRequestLogging(this IApplicationBuilder app)
    {
        return app.Use(async (context, next) =>
        {
            var requestId = ResolveRequestId(context);
            context.TraceIdentifier = requestId;
            context.Items[RequestIdItemKey] = requestId;
            context.Response.Headers["X-Request-Id"] = requestId;
            context.Response.Headers["X-Correlation-Id"] = requestId;

            var logger = context.RequestServices
                .GetRequiredService<ILoggerFactory>()
                .CreateLogger("Ledgerly.Api.Http");
            var started = Stopwatch.GetTimestamp();

            using (logger.BeginScope(new Dictionary<string, object>
            {
                ["RequestId"] = requestId,
                ["Service"] = "ledgerly-api",
            }))
            {
                await next();

                var status = context.Response.StatusCode;
                var level = status >= 500
                    ? LogLevel.Error
                    : status >= 400
                        ? LogLevel.Warning
                        : IsHealthCheck(context.Request.Path)
                            ? LogLevel.Debug
                            : LogLevel.Information;

                logger.Log(
                    level,
                    "HTTP {Method} {Path} responded {StatusCode} in {ElapsedMs} ms UserId {UserId} ClientIp {ClientIp}",
                    context.Request.Method,
                    Sanitize(context.Request.Path.Value, 256),
                    status,
                    (long)Stopwatch.GetElapsedTime(started).TotalMilliseconds,
                    UserId(context),
                    context.Connection.RemoteIpAddress?.ToString() ?? "unknown");
            }
        });
    }

    /// <summary>
    /// Adds the authenticated user id to the log scope after authentication has run.
    /// </summary>
    public static IApplicationBuilder UseUserLogScope(this IApplicationBuilder app)
    {
        return app.Use(async (context, next) =>
        {
            var userId = context.User.FindFirstValue("sub");
            if (string.IsNullOrEmpty(userId))
            {
                await next();
                return;
            }

            var logger = context.RequestServices
                .GetRequiredService<ILoggerFactory>()
                .CreateLogger("Ledgerly.Api.Http");
            using (logger.BeginScope(new Dictionary<string, object> { ["UserId"] = userId }))
            {
                await next();
            }
        });
    }

    public static string UserId(HttpContext context) =>
        context.User.FindFirstValue("sub") ?? "anonymous";

    private static string ResolveRequestId(HttpContext context)
    {
        var incoming = FirstHeader(context, "X-Request-Id")
                       ?? FirstHeader(context, "X-Correlation-Id");
        if (IsSafeId(incoming))
            return incoming!;

        var generated = context.TraceIdentifier;
        return IsSafeId(generated) ? generated : Guid.NewGuid().ToString("N");
    }

    private static string? FirstHeader(HttpContext context, string name)
    {
        if (!context.Request.Headers.TryGetValue(name, out var values))
            return null;
        return values.Count == 1 ? values[0] : null;
    }

    private static bool IsSafeId(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > 64)
            return false;

        foreach (var c in value)
        {
            if (char.IsAsciiLetterOrDigit(c) || c is '.' or '_' or ':' or '-')
                continue;
            return false;
        }

        return true;
    }

    private static bool IsHealthCheck(PathString path) =>
        path.StartsWithSegments("/health", StringComparison.OrdinalIgnoreCase);

    private static string Sanitize(string? value, int max)
    {
        if (string.IsNullOrEmpty(value))
            return "";

        var slice = value.Length <= max ? value : value[..max];
        return slice.Replace('\r', ' ').Replace('\n', ' ');
    }
}
