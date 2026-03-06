using System.IO;
using GodotFileAccess = Godot.FileAccess;

namespace BusyOffice.Bundles.Core;

public sealed class DllExtractor
{
    public string? ExtractToTemp(string bundleResPath, string dllName)
    {
        var resPath = bundleResPath + "/" + dllName;
        if (!GodotFileAccess.FileExists(resPath))
            return null;

        using var file = GodotFileAccess.Open(resPath, GodotFileAccess.ModeFlags.Read);
        if (file is null) return null;

        var bytes = file.GetBuffer((long)file.GetLength());

        var tempDir = Path.Combine(Path.GetTempPath(), "busyoffice_bundles");
        Directory.CreateDirectory(tempDir);

        var tempPath = Path.Combine(tempDir, dllName);
        File.WriteAllBytes(tempPath, bytes);

        return tempPath;
    }
}
