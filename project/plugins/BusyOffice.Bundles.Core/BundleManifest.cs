using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;
using BusyOffice.Bundles.Contracts;

namespace BusyOffice.Bundles.Core;

public sealed class BundleManifest : IBundleManifest
{
    [JsonPropertyName("bundleId")]
    public string BundleId { get; set; } = "";

    [JsonPropertyName("displayName")]
    public string DisplayName { get; set; } = "";

    [JsonPropertyName("version")]
    public string Version { get; set; } = "0.0.0";

    [JsonPropertyName("entryScene")]
    public string EntryScene { get; set; } = "";

    [JsonPropertyName("scenes")]
    public List<string> Scenes { get; set; } = new();

    IReadOnlyList<string> IBundleManifest.Scenes => Scenes;

    [JsonPropertyName("metadata")]
    public Dictionary<string, string> Metadata { get; set; } = new();

    IReadOnlyDictionary<string, string> IBundleManifest.Metadata => Metadata;

    public static BundleManifest? FromJson(string json)
    {
        return JsonSerializer.Deserialize<BundleManifest>(json);
    }
}
