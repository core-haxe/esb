package esb.core;

import esb.core.config.sections.BundleConfig;
import haxe.io.Path;

using StringTools;

@:keep
class BundleLoader {
    private static var log:esb.logging.Logger = new esb.logging.Logger("esb.core.BundleLoader");

    public static function main() {
        load();
    }

    public static function load() {
        //var bundleFile:String = js.node.Path.basename(js.Syntax.code("require.main.filename"));
        var bundleFile:String = js.node.Path.basename(js.Syntax.code("module.filename"));
        bundleFile = Path.normalize(bundleFile).split("/").pop();

        var bundleConfig = esb.core.config.sections.EsbConfig.get().bundles.get(bundleFile);
        if (bundleConfig == null) {
            bundleConfig = esb.core.config.sections.EsbConfig.get().findBundleFromName(bundleFile);
        }
        if (bundleConfig == null) {
            bundleConfig = esb.core.config.sections.EsbConfig.get().findBundleFromBundleFile(bundleFile);
        }
        if (bundleConfig == null) {
            return;
        }

        autoLoadBundles();
        loadDependencies(bundleConfig);

        var bundle:IBundle = null;
        if (bundleConfig.bundleEntryPoint != null) {
            var bundleClass = Type.resolveClass(bundleConfig.bundleEntryPoint);
            if (bundleClass != null) {
                bundle = Type.createInstance(bundleClass, []);
                if (bundle != null) {
                } else {
                    trace("ERROR: Could not create bundle instance");
                }
            } else {
                trace("ERROR: Could not resolve bundle class: " + bundleConfig.bundleEntryPoint);
            }
        }

        if (bundle == null) {
            bundle = new Bundle();
        }
        if (bundle != null) {
            bundle.classResolver = Type.resolveClass;
            bundle.config = bundleConfig;
            bundle.start();
        }
    }

    private static var _bundlesAutoLoaded:Bool = false;
    public static function autoLoadBundles() {
        if (_bundlesAutoLoaded) {
            return;
        }
        _bundlesAutoLoaded = true;
        var bundles = esb.core.config.sections.EsbConfig.get().bundles;
        for (bundleName in bundles.keys()) {
            var bundleConfig = bundles.get(bundleName);
            if (bundleConfig.autoLoad) {
                loadBundle(bundleConfig);
            }
        }
    }

    private static function loadDependencies(bundleConfig:BundleConfig) {
        var deps = bundleConfig.dependencies;
        if (deps == null) {
            return;
        }

        for (depName in deps) {
            var depConfig = esb.core.config.sections.EsbConfig.get().bundles.get(depName);
            loadBundle(depConfig);
        }
    }

    private static function loadBundle(bundleConfig:BundleConfig) {
        if (bundleConfig == null) {
            return;
        }
        if (bundleConfig.bundleEntryPoint == null) {
            return;
        }
        var bundleFile = bundleConfig.bundleFile;
        if (!bundleFile.endsWith(".js")) {
            bundleFile += ".js";
        }

        if (bundleFile == js.node.Path.basename(js.Syntax.code("module.filename"))) {
            return;
        }

        js.Node.require("./" + bundleFile);
        log.info('auto loading bundle "${bundleConfig.name}" (file: "${bundleFile}")');
    }
}