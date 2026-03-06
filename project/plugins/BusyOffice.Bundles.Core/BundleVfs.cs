using Godot;

namespace BusyOffice.Bundles.Core;

public sealed class BundleVfs
{
    public bool LoadPck(string pckPath)
    {
        return ProjectSettings.LoadResourcePack(pckPath);
    }

    public void UnloadPck(string pckPath)
    {
        // Godot does not support unloading individual PCKs at runtime.
        // Tracked as a known limitation — scenes instantiated from the PCK
        // can still be freed, but the VFS entries persist until restart.
    }

    public string? ReadManifestJson(string bundleResPath)
    {
        var manifestPath = bundleResPath.PathJoin("manifest.json");
        if (!FileAccess.FileExists(manifestPath))
            return null;

        using var file = FileAccess.Open(manifestPath, FileAccess.ModeFlags.Read);
        return file?.GetAsText();
    }

    public BundleManifest? ReadManifest(string bundleResPath)
    {
        var json = ReadManifestJson(bundleResPath);
        if (json is null) return null;
        return BundleManifest.FromJson(json);
    }

    public bool ResourceExists(string resPath)
    {
        return ResourceLoader.Exists(resPath);
    }
}
