package esb.core;

@:keep
class BundleLoader {
    public static function main() {
        load();
    }

    public static function load() {
        var bundleFile:String = js.node.Path.basename(js.Syntax.code("require.main.filename"));
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
                trace("ERROR: Could not resolve bundle class: ", bundleConfig.bundleEntryPoint);
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
}