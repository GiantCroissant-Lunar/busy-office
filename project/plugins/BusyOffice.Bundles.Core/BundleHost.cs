using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Godot;
using Microsoft.Extensions.Logging;
using PluginArchi.Extensibility.Abstractions;

namespace BusyOffice.Bundles.Core;

public sealed class BundleHost
{
    private readonly BundleVfs _vfs;
    private readonly DllExtractor _extractor;
    private readonly BundleSceneHost _sceneHost;
    private readonly IPluginHost _pluginHost;
    private readonly ILogger _logger;
    private readonly Dictionary<string, LoadedBundle> _loaded = new();

    public BundleHost(
        BundleVfs vfs,
        DllExtractor extractor,
        BundleSceneHost sceneHost,
        IPluginHost pluginHost,
        ILogger logger)
    {
        _vfs = vfs;
        _extractor = extractor;
        _sceneHost = sceneHost;
        _pluginHost = pluginHost;
        _logger = logger;
    }

    public IReadOnlyDictionary<string, LoadedBundle> Loaded => _loaded;

    public Task LoadAsync(string pckPath)
    {
        var pckName = Path.GetFileNameWithoutExtension(pckPath);
        var bundleResPath = $"res://bundles/{pckName}";

        if (!_vfs.LoadPck(pckPath))
        {
            _logger.LogError("Failed to load PCK: {Path}", pckPath);
            return Task.CompletedTask;
        }

        _logger.LogInformation("PCK loaded: {Path}", pckPath);

        var manifest = _vfs.ReadManifest(bundleResPath);
        var bundleId = manifest?.BundleId ?? pckName;

        Godot.Node? scene = null;
        var entryScene = manifest?.EntryScene;
        if (!string.IsNullOrEmpty(entryScene))
        {
            var scenePath = bundleResPath.PathJoin(entryScene);
            scene = _sceneHost.InstantiateScene(scenePath);
            if (scene is not null)
                _sceneHost.RegisterScene(bundleId, scene);
        }

        _loaded[bundleId] = new LoadedBundle(bundleId, pckPath, bundleResPath, manifest);
        _logger.LogInformation("Bundle loaded: {BundleId} from {Path}", bundleId, pckPath);

        return Task.CompletedTask;
    }

    public async Task LoadRemoteAsync(string url)
    {
        using var http = new System.Net.Http.HttpClient();
        var bytes = await http.GetByteArrayAsync(url);

        var tempDir = Path.Combine(Path.GetTempPath(), "busyoffice_bundles");
        Directory.CreateDirectory(tempDir);

        var fileName = Path.GetFileName(new Uri(url).LocalPath);
        var tempPath = Path.Combine(tempDir, fileName);
        await File.WriteAllBytesAsync(tempPath, bytes);

        await LoadAsync(tempPath);
    }

    public Task UnloadAsync(string bundleId)
    {
        if (!_loaded.TryGetValue(bundleId, out var bundle))
        {
            _logger.LogWarning("Bundle not loaded: {BundleId}", bundleId);
            return Task.CompletedTask;
        }

        _sceneHost.RemoveScene(bundleId);
        _loaded.Remove(bundleId);
        _logger.LogInformation("Bundle unloaded: {BundleId}", bundleId);

        return Task.CompletedTask;
    }

    public async Task ReloadAsync(string bundleId)
    {
        if (!_loaded.TryGetValue(bundleId, out var bundle))
        {
            _logger.LogWarning("Bundle not loaded for reload: {BundleId}", bundleId);
            return;
        }

        var pckPath = bundle.PckPath;
        await UnloadAsync(bundleId);
        await LoadAsync(pckPath);
    }

    public Task UnloadAllAsync()
    {
        _sceneHost.RemoveAll();
        _loaded.Clear();
        _logger.LogInformation("All bundles unloaded");
        return Task.CompletedTask;
    }
}

public sealed record LoadedBundle(
    string BundleId,
    string PckPath,
    string BundleResPath,
    BundleManifest? Manifest);
