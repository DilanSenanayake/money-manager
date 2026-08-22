using Ledgerly.Api.Models;
using Ledgerly.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Ledgerly.Api.Controllers;

[ApiController]
[Authorize]
[Route("v1/accounts")]
public sealed class AccountsController(IAccountsService accounts) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<Account>>> GetAll(CancellationToken ct) =>
        Ok(await accounts.GetAllAsync(ct));

    [HttpPost]
    public async Task<ActionResult> Create([FromBody] CreateAccountRequest request, CancellationToken ct)
    {
        var result = await accounts.CreateAsync(request, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }

    [HttpPatch("{id:guid}")]
    public async Task<ActionResult> Update(
        Guid id,
        [FromBody] UpdateAccountRequest request,
        CancellationToken ct)
    {
        var result = await accounts.UpdateAsync(id, request, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult> Delete(Guid id, CancellationToken ct)
    {
        var result = await accounts.DeleteAsync(id, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }
}

[ApiController]
[Authorize]
[Route("v1/categories")]
public sealed class CategoriesController(ICategoriesService categories) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<Category>>> GetAll(CancellationToken ct) =>
        Ok(await categories.GetAllAsync(ct));

    [HttpPost]
    public async Task<ActionResult> Create([FromBody] CreateCategoryRequest request, CancellationToken ct)
    {
        var result = await categories.CreateAsync(request, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }

    [HttpPatch("{id:guid}")]
    public async Task<ActionResult> Update(
        Guid id,
        [FromBody] CreateCategoryRequest request,
        CancellationToken ct)
    {
        var result = await categories.UpdateAsync(id, request, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult> Delete(Guid id, CancellationToken ct)
    {
        var result = await categories.DeleteAsync(id, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }
}

[ApiController]
[Authorize]
[Route("v1/transactions")]
public sealed class TransactionsController(ITransactionsService transactions) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<Transaction>>> Get(
        [FromQuery] TransactionFilter filter,
        CancellationToken ct) =>
        Ok(await transactions.GetAsync(filter, ct));

    [HttpGet("recurring")]
    public async Task<ActionResult<List<Transaction>>> GetRecurring(CancellationToken ct) =>
        Ok(await transactions.GetRecurringAsync(ct));

    [HttpPost]
    public async Task<ActionResult> Create(
        [FromBody] CreateTransactionRequest request,
        CancellationToken ct)
    {
        var result = await transactions.CreateAsync(request, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }

    [HttpPatch("{id:guid}")]
    public async Task<ActionResult> Update(
        Guid id,
        [FromBody] CreateTransactionRequest request,
        CancellationToken ct)
    {
        var result = await transactions.UpdateAsync(id, request, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult> Delete(Guid id, CancellationToken ct)
    {
        var result = await transactions.DeleteAsync(id, ct);
        return result.Success ? Ok(new SuccessResponse()) : BadRequest(new ErrorResponse(result.Error!));
    }
}
