namespace Ledgerly.Api.Infrastructure.Llm;

public interface ILlmService
{
    bool IsConfigured { get; }
    Task<T> GenerateObjectAsync<T>(string prompt, string jsonSchemaHint, CancellationToken ct = default);
}
