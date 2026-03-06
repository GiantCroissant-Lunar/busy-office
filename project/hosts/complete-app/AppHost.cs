using System;
using System.IO;
using System.Threading.Tasks;
using BusyOffice.Bundles.Core;
using Godot;
using Microsoft.Extensions.Logging;

namespace CompleteApp;

public partial class AppHost : Node
{
    private Bootstrap? _bootstrap;
    private ILogger? _logger;
    private BundleHost? _bundleHost;

    public static Bootstrap? Instance { get; private set; }

    public override void _Ready()
    {
        _bootstrap = new Bootstrap();
        Instance = _bootstrap;

        _logger = _bootstrap.Logging.CreateLogger("AppHost");
        _logger.LogInformation("Bootstrap initialized");

        _bootstrap.PluginHost.InitializeAsync().AsTask().GetAwaiter().GetResult();
        _logger.LogInformation("Plugin host initialized");

        var vfs = new BundleVfs();
        var extractor = new DllExtractor();
        var sceneHost = new BundleSceneHost(GetTree().Root, _bootstrap.Logging.CreateLogger("BundleSceneHost"));
        _bundleHost = new BundleHost(vfs, extractor, sceneHost, _bootstrap.PluginHost, _bootstrap.Logging.CreateLogger("BundleHost"));

        _logger.LogInformation("Bundle system initialized");

        _ = _bootstrap.Hosting.StartAsync();
        _ = AutoLoadBundlesAsync();
    }

    private async Task AutoLoadBundlesAsync()
    {
        try
        {
            string bundlesDir;

            if (OS.HasFeature("editor"))
            {
                bundlesDir = ProjectSettings.GlobalizePath("res://system_bundles");
            }
            else
            {
                var exeDir = OS.GetExecutablePath().GetBaseDir();
                bundlesDir = Path.Combine(exeDir, "bundles");
            }

            if (!Directory.Exists(bundlesDir))
            {
                _logger?.LogInformation("No bundles directory found at {Path}", bundlesDir);
                return;
            }

            var pckFiles = Directory.GetFiles(bundlesDir, "*.pck");
            foreach (var pckFile in pckFiles)
            {
                try
                {
                    await _bundleHost!.LoadAsync(pckFile);
                }
                catch (Exception ex)
                {
                    _logger?.LogError(ex, "Failed to auto-load bundle: {PckFile}", pckFile);
                }
            }
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Error during bundle auto-load");
        }
    }

    public void LoadBundle(string pckPath)
    {
        _ = LoadBundleAsync(pckPath);
    }

    public void LoadRemoteBundle(string url)
    {
        _ = LoadRemoteBundleAsync(url);
    }

    public void UnloadBundle(string bundleId)
    {
        _ = UnloadBundleAsync(bundleId);
    }

    public void ReloadBundle(string bundleId)
    {
        _ = ReloadBundleAsync(bundleId);
    }

    private async Task LoadBundleAsync(string pckPath)
    {
        try
        {
            await _bundleHost!.LoadAsync(pckPath);
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Failed to load bundle: {PckPath}", pckPath);
        }
    }

    private async Task LoadRemoteBundleAsync(string url)
    {
        try
        {
            await _bundleHost!.LoadRemoteAsync(url);
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Failed to load remote bundle from: {Url}", url);
        }
    }

    private async Task UnloadBundleAsync(string bundleId)
    {
        try
        {
            await _bundleHost!.UnloadAsync(bundleId);
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Failed to unload bundle: {BundleId}", bundleId);
        }
    }

    private async Task ReloadBundleAsync(string bundleId)
    {
        try
        {
            await _bundleHost!.ReloadAsync(bundleId);
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Failed to reload bundle: {BundleId}", bundleId);
        }
    }

    public override void _ExitTree()
    {
        if (_bootstrap is null) return;
        _logger?.LogInformation("Shutting down");

        _bundleHost?.UnloadAllAsync().GetAwaiter().GetResult();
        _bootstrap.Hosting.StopAsync().GetAwaiter().GetResult();
        _bootstrap.Dispose();
        Instance = null;
        _bootstrap = null;
    }
}
