using System.Text;
using Ledgerly.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Ledgerly.Api.Controllers;

[ApiController]
[Authorize]
[Route("v1/export")]
public sealed class ExportController(IExportService export) : ControllerBase
{
    [HttpGet("transactions.csv")]
    public async Task<IActionResult> Csv(CancellationToken ct)
    {
        var csv = await export.TransactionsCsvAsync(ct);
        var body = Encoding.UTF8.GetPreamble().Concat(Encoding.UTF8.GetBytes(csv)).ToArray();
        return File(body, "text/csv; charset=utf-8", "smart-money-manager-transactions.csv");
    }

    [HttpGet("transactions.json")]
    public async Task<IActionResult> Json(CancellationToken ct)
    {
        var json = await export.TransactionsJsonAsync(ct);
        return File(
            Encoding.UTF8.GetBytes(json),
            "application/json; charset=utf-8",
            "smart-money-manager-transactions.json");
    }
}
