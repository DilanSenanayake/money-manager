using Ledgerly.Api.Infrastructure.Logging;
using Ledgerly.Api.Models;
using Microsoft.AspNetCore.Diagnostics;

namespace Ledgerly.Api.Infrastructure.Auth;

/// <summary>
/// Maps identity/session failures to HTTP 401 instead of an unhandled 500.
/// </summary>
public sealed class UnauthorizedExceptionHandler(ILogger<UnauthorizedExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not UnauthorizedAccessException)
            return false;

        logger.LogWarning(
            exception,
            "Unauthorized {Method} {Path} {RequestId} {UserId}",
            httpContext.Request.Method,
            httpContext.Request.Path.Value,
            httpContext.TraceIdentifier,
            RequestLoggingMiddleware.UserId(httpContext));

        httpContext.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await httpContext.Response.WriteAsJsonAsync(
            new ErrorResponse("Unauthorized"),
            cancellationToken);
        return true;
    }
}
