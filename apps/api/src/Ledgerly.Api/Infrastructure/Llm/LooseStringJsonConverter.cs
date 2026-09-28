using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Ledgerly.Api.Infrastructure.Llm;

/// <summary>
/// Keeps extra model fields from failing extraction JSON.
/// Feedback ids are written by the API after the model call.
/// </summary>
public sealed class LooseStringJsonConverter : JsonConverter<string?>
{
    public override string? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        switch (reader.TokenType)
        {
            case JsonTokenType.Null:
                return null;
            case JsonTokenType.String:
                return reader.GetString();
            case JsonTokenType.Number:
                return reader.TryGetInt64(out var whole)
                    ? whole.ToString(CultureInfo.InvariantCulture)
                    : reader.GetDouble().ToString(CultureInfo.InvariantCulture);
            case JsonTokenType.True:
                return "true";
            case JsonTokenType.False:
                return "false";
            default:
                using (JsonDocument.ParseValue(ref reader))
                    return null;
        }
    }

    public override void Write(Utf8JsonWriter writer, string? value, JsonSerializerOptions options)
    {
        if (value is null) writer.WriteNullValue();
        else writer.WriteStringValue(value);
    }
}
