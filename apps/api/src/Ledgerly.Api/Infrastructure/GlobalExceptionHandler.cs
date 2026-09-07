using Ledgerly.Api.Models;
using Microsoft.AspNetCore.Diagnostics;

namespace Ledgerly.Api.Infrastructure;

/// <summary>
/// Catches unhandled exceptions and returns a safe client message (no stack traces).
/// </summary>
public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is UnauthorizedAccessException)
            return false;

        logger.LogError(exception, "Unhandled exception on {Method} {Path}",
            httpContext.Request.Method,
            httpContext.Request.Path);

        if (httpContext.Response.HasStarted)
            return false;

        httpContext.Response.StatusCode = StatusCodes.Status500InternalServerError;
        await httpContext.Response.WriteAsJsonAsync(
            new ErrorResponse("Something went wrong. Please try again."),
            cancellationToken);
        return true;
    }
}
