using System.Collections.Generic;
using Godot;
using Microsoft.Extensions.Logging;

namespace BusyOffice.Bundles.Core;

public sealed class BundleSceneHost
{
    private readonly Node _root;
    private readonly ILogger _logger;
    private readonly Dictionary<string, Node> _activeScenes = new();

    public BundleSceneHost(Node root, ILogger logger)
    {
        _root = root;
        _logger = logger;
    }

    public Node? InstantiateScene(string scenePath)
    {
        var packed = ResourceLoader.Load<PackedScene>(scenePath);
        if (packed is null)
        {
            _logger.LogWarning("Scene not found: {Path}", scenePath);
            return null;
        }

        var instance = packed.Instantiate();
        _root.CallDeferred("add_child", instance);
        return instance;
    }

    public void RegisterScene(string bundleId, Node scene)
    {
        _activeScenes[bundleId] = scene;
        _logger.LogInformation("Scene registered for bundle {BundleId}", bundleId);
    }

    public void RemoveScene(string bundleId)
    {
        if (_activeScenes.TryGetValue(bundleId, out var scene))
        {
            scene.QueueFree();
            _activeScenes.Remove(bundleId);
            _logger.LogInformation("Scene removed for bundle {BundleId}", bundleId);
        }
    }

    public void RemoveAll()
    {
        foreach (var kvp in _activeScenes)
            kvp.Value.QueueFree();
        _activeScenes.Clear();
    }
}
