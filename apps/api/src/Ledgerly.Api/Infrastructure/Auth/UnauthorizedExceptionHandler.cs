using Ledgerly.Api.Models;
using Microsoft.AspNetCore.Diagnostics;

namespace Ledgerly.Api.Infrastructure.Auth;

/// <summary>
/// Maps identity/session failures to HTTP 401 instead of an unhandled 500.
/// </summary>
public sealed class UnauthorizedExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not UnauthorizedAccessException)
            return false;

        httpContext.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await httpContext.Response.WriteAsJsonAsync(
            new ErrorResponse("Unauthorized"),
            cancellationToken);
        return true;
    }
}
