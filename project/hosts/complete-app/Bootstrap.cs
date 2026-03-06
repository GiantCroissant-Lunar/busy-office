using System;
using Crosscut.Config;
using Crosscut.Hosting;
using Crosscut.Logging;
using Microsoft.Extensions.DependencyInjection;
using PluginArchi.Extensibility.Abstractions;
using PluginArchi.Extensibility.Hosting;
using ServiceArchi.Core;
using ServiceArchi.Contracts;

namespace CompleteApp;

public sealed class Bootstrap : IDisposable
{
    public IRegistry Registry { get; }
    public Crosscut.Config.ServiceProxy Config { get; }
    public Crosscut.Logging.ServiceProxy Logging { get; }
    public Crosscut.Hosting.ServiceProxy Hosting { get; }
    public IPluginHost PluginHost { get; }

    public Bootstrap()
    {
        Registry = new ServiceRegistry();

        // Tier 1: Providers
        Registry.RegisterJsonConfig();
        Registry.RegisterConsoleLogging();

        // Tier 2: Core services
        Registry.RegisterConfigService();
        Registry.RegisterLoggingService();
        Registry.RegisterHostingService();

        // Tier 3: Proxies
        Config = new Crosscut.Config.ServiceProxy(Registry);
        Logging = new Crosscut.Logging.ServiceProxy(Registry);
        Hosting = new Crosscut.Hosting.ServiceProxy(Registry);

        // Tier 4: Plugin host (for bundle system)
        var sharedPolicy = new SharedAssemblyPolicy(
            prefixes: new[]
            {
                "GiantCroissant.Plate.ServiceArchi.",
                "GiantCroissant.Plate.PluginArchi.",
                "GiantCroissant.Crosscut.",
                "BusyOffice.Bundles.",
                "GodotSharp",
                "Godot",
                "System.",
                "Microsoft.",
                "netstandard"
            });

        PluginHost = new PluginHostBuilder()
            .ConfigureServices(services =>
            {
                services.AddSingleton(Registry);
            })
            .WithParentContext(System.Runtime.Loader.AssemblyLoadContext.Default)
            .WithSharedPolicy(sharedPolicy)
            .Build();
    }

    public void Dispose()
    {
        PluginHost.DisposeAsync().AsTask().GetAwaiter().GetResult();

        if (Registry.TryGet<Crosscut.Logging.IService>() is IDisposable d)
            d.Dispose();
    }
}
