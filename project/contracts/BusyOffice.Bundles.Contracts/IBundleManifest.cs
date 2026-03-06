using System.Collections.Generic;

namespace BusyOffice.Bundles.Contracts;

public interface IBundleManifest
{
    string BundleId { get; }
    string DisplayName { get; }
    string Version { get; }
    string EntryScene { get; }
    IReadOnlyList<string> Scenes { get; }
    IReadOnlyDictionary<string, string> Metadata { get; }
}
