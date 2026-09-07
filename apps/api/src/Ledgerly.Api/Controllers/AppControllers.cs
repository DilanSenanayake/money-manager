using Ledgerly.Api.Models;
using Ledgerly.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using Ledgerly.Api.Infrastructure;

namespace Ledgerly.Api.Controllers;

[ApiController]
[Authorize]
[Route("v1/dashboard")]
public sealed class DashboardController(IDashboardService dashboard) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<DashboardResponse>> Get(CancellationToken ct) =>
        Ok(await dashboard.GetDashboardAsync(ct));

    [HttpGet("analytics")]
    public async Task<ActionResult<AnalyticsResponse>> GetAnalytics(CancellationToken ct) =>
        Ok(await dashboard.GetAnalyticsAsync(ct));

    [HttpGet("budgets")]
    public async Task<ActionResult<List<BudgetProgress>>> GetBudgets(CancellationToken ct) =>
        Ok(await dashboard.GetBudgetsAsync(ct));
}

[ApiController]
[Authorize]
[Route("v1/settings")]
public sealed class SettingsController(ISettingsService settings) : ControllerBase
{
    [HttpGet("profile")]
    public async Task<ActionResult<Profile>> GetProfile(CancellationToken ct)
    {
        var profile = await settings.GetProfileAsync(ct);
        return profile is null ? NotFound(new ErrorResponse("Profile not found")) : Ok(profile);
    }

    [HttpPatch("profile")]
    public async Task<ActionResult> UpdateProfile(
        [FromBody] UpdateProfileRequest request,
        CancellationToken ct)
    {
        var result = await settings.UpdateProfileAsync(request, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }

    [HttpGet("exchange-rates")]
    public async Task<ActionResult<List<ExchangeRate>>> GetRates(CancellationToken ct) =>
        Ok(await settings.GetExchangeRatesAsync(ct));

    [HttpPut("exchange-rates")]
    public async Task<ActionResult> UpsertRate(
        [FromBody] UpsertExchangeRateRequest request,
        CancellationToken ct)
    {
        var result = await settings.UpsertExchangeRateAsync(request, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }

    [HttpDelete("exchange-rates/{id:guid}")]
    public async Task<ActionResult> DeleteRate(Guid id, CancellationToken ct)
    {
        var result = await settings.DeleteExchangeRateAsync(id, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }
}

[ApiController]
[Authorize]
[EnableRateLimiting("ai")]
[Route("v1/ai")]
public sealed class AiController(IAiService ai) : ControllerBase
{
    [HttpPost("parse-receipt")]
    public async Task<ActionResult> ParseReceipt(
        [FromBody] ParseReceiptRequest request,
        CancellationToken ct)
    {
        var result = await ai.ParseReceiptAsync(request.OcrText, ct);
        return result.Success
            ? Ok(new DataEnvelope<ReceiptExtraction>(result.Value!))
            : BadRequest(new ErrorResponse(result.Error!));
    }

    [HttpPost("parse-sms")]
    public async Task<ActionResult> ParseSms([FromBody] ParseTextRequest request, CancellationToken ct)
    {
        var result = await ai.ParseSmsAsync(request.Text, ct);
        return result.Success
            ? Ok(new DataEnvelope<SmsExtraction>(result.Value!))
            : BadRequest(new ErrorResponse(result.Error!));
    }

    [HttpPost("parse-text")]
    public async Task<ActionResult> ParseText([FromBody] ParseTextRequest request, CancellationToken ct)
    {
        var result = await ai.ParseQuickTextAsync(request.Text, ct);
        return result.Success
            ? Ok(new DataEnvelope<QuickTextExtraction>(result.Value!))
            : BadRequest(new ErrorResponse(result.Error!));
    }

    [HttpPost("save-reviewed")]
    public async Task<ActionResult> SaveReviewed(
        [FromBody] AiReviewSaveRequest request,
        CancellationToken ct)
    {
        var result = await ai.SaveReviewedAsync(request, ct);
        return result.Success
            ? Ok(new SuccessResponse { CategoryId = result.Value })
            : BadRequest(new ErrorResponse(result.Error!));
    }
}

[ApiController]
[Route("health")]
public sealed class HealthController(
    IHttpClientFactory httpClientFactory,
    IOptions<SupabaseOptions> supabaseOptions) : ControllerBase
{
    [HttpGet]
    [AllowAnonymous]
    public IActionResult Get() => Ok(new { status = "ok" });

    /// <summary>Readiness: process is up and Supabase is reachable.</summary>
    [HttpGet("ready")]
    [AllowAnonymous]
    public async Task<IActionResult> Ready(CancellationToken ct)
    {
        var url = (supabaseOptions.Value.Url ?? "").TrimEnd('/');
        if (string.IsNullOrWhiteSpace(url))
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                status = "not_ready",
                supabase = "unconfigured",
            });
        }

        try
        {
            var client = httpClientFactory.CreateClient("supabase");
            using var request = new HttpRequestMessage(HttpMethod.Head, $"{url}/rest/v1/");
            using var response = await client.SendAsync(request, ct);
            // 401/404 still means the host is reachable
            var reachable = (int)response.StatusCode is >= 200 and < 500;
            if (!reachable)
            {
                return StatusCode(StatusCodes.Status503ServiceUnavailable, new
                {
                    status = "not_ready",
                    supabase = "unreachable",
                });
            }

            return Ok(new { status = "ready", supabase = "ok" });
        }
        catch
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                status = "not_ready",
                supabase = "error",
            });
        }
    }
}
