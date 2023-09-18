package esb.core.config.sections;

using StringTools;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.EsbConfig")
extern class EsbConfig {
    public function new();
    public var baseDir(get, null):String;
    public var bundles:Map<String, BundleConfig>;
    public var queues:Map<String, QueueConfig>;
    public var properties:PropertiesConfig;
    public var logging:LoggingConfig;
    public function findBundleFromPrefix(prefix:String, producer:Bool):BundleConfig;
    public function findBundleFromName(name:String):BundleConfig;
    public function findBundleFromBundleFile(bundleFile:String):BundleConfig;
    public function findPrefix(prefix:String, producer:Bool):BundlePrefixCommonConfig;
    public function getAutoStartBundles():Array<BundleConfig>;
    public function getDisabledBundles():Array<BundleConfig>;
    public function path(name:String, create:Bool = true):String;

    public static function get(filename:String = "config/esb.json", cache:Bool = true):EsbConfig;
}

#else

@:expose
@:native("esb.core.config.sections.EsbConfig")
class EsbConfig {
    public var bundles:Map<String, BundleConfig> = [];
    public var queues:Map<String, QueueConfig> = [];

    @:alias("properties") private var _properties:Map<String, String> = [];
    @:jignored public var properties:PropertiesConfig;

    public var baseDir(get, null):String;
    private function get_baseDir():String {
        var path = properties.get("baseDir");
        if (path == null) {
            path = Sys.getCwd();
        }
        return haxe.io.Path.normalize(path);
    }

    public function path(name:String, create:Bool = true):String {
        var p = haxe.io.Path.normalize(baseDir + "/" + name);
        if (create && !sys.FileSystem.exists(p)) {
            sys.FileSystem.createDirectory(p);
        }
        return p;
    }

    public var logging:LoggingConfig;

    public function new() {
    }

    public function findBundleFromPrefix(prefix:String, producer:Bool):BundleConfig {
        if (bundles == null) {
            return null;
        }
        var foundBundle:BundleConfig = null;
        for (bundleName in bundles.keys()) {
            var bundle = bundles.get(bundleName);
            if (bundle.hasPrefix(prefix, producer)) {
                foundBundle = bundle;
                break;
            }
        }
        return foundBundle;
    }

    public function findBundleFromName(name:String):BundleConfig {
        if (bundles == null) {
            return null;
        }

        if (name.endsWith(".js")) {
            name = name.replace(".js", "");
        }

        var foundBundle:BundleConfig = null;
        for (bundleName in bundles.keys()) {
            var bundle = bundles.get(bundleName);
            if (bundle.name == null) {
                continue;
            }
            var testName = bundle.name;
            if (testName.endsWith(".js")) {
                testName = testName.replace(".js", "");
            }
            if (testName == name) {
                foundBundle = bundle;
                break;
            }
        }
        return foundBundle;
    }

    public function findBundleFromBundleFile(bundleFile:String):BundleConfig {
        if (bundles == null) {
            return null;
        }

        if (bundleFile.endsWith(".js")) {
            bundleFile = bundleFile.replace(".js", "");
        }

        var foundBundle:BundleConfig = null;
        for (bundleName in bundles.keys()) {
            var bundle = bundles.get(bundleName);
            if (bundle.bundleFile == null) {
                continue;
            }
            var testName = bundle.bundleFile;
            if (testName.endsWith(".js")) {
                testName = testName.replace(".js", "");
            }
            if (testName == bundleFile) {
                foundBundle = bundle;
                break;
            }
        }
        return foundBundle;
    }

    public function findPrefix(prefix:String, producer:Bool):BundlePrefixCommonConfig {
        var bundle = findBundleFromPrefix(prefix, producer);
        if (bundle == null) {
            return null;
        }
        if (producer) {
            return bundle.prefixes.get(prefix).producer;
        }
        if (!producer) {
            return bundle.prefixes.get(prefix).consumer;
        }
        return null;
    }

    public function getAutoStartBundles():Array<BundleConfig> {
        var list = [];
        for (bundleName in bundles.keys()) {
            var bundle = bundles.get(bundleName);
            if (bundle.autoStart && !bundle.disabled) {
                list.push(bundle);
            }
        }
        return list;
    }

    public function getDisabledBundles():Array<BundleConfig> {
        var list = [];
        for (bundleName in bundles.keys()) {
            var bundle = bundles.get(bundleName);
            if (bundle.disabled) {
                list.push(bundle);
            }
        }
        return list;
    }

    private function postProcess() {
        // bundles
        var bundlesToRemove = [];
        for (bundleName in bundles.keys()) {
            var bundle = bundles.get(bundleName);
            if (bundle == null) {
                bundlesToRemove.push(bundleName);
            }
        }
        for (bundleName in bundlesToRemove) {
            bundles.remove(bundleName);
        }

        for (bundleName in bundles.keys()) {
            var bundle = bundles.get(bundleName);
            if (bundle == null) {
                continue;
            }
            @:privateAccess bundle.parent = this;
        }

        // queues
        var queuesToRemove = [];
        for (queueName in queues.keys()) {
            var queue = queues.get(queueName);
            if (queue == null) {
                queuesToRemove.push(queueName);
            }
        }
        for (queueName in queuesToRemove) {
            queues.remove(queueName);
        }

        for (queueName in queues.keys()) {
            var queue = queues.get(queueName);
            if (queue == null) {
                continue;
            }
            @:privateAccess queue.parent = this;
        }

        properties = new PropertiesConfig(_properties);
        @:privateAccess properties.postProcess();

        // bundles
        for (bundleName in bundles.keys()) {
            var bundle = bundles.get(bundleName);
            if (bundle == null) {
                continue;
            }
            @:privateAccess bundle.postProcess();
        }

        // queues
        for (queueName in queues.keys()) {
            var queue = queues.get(queueName);
            if (queue == null) {
                continue;
            }
            @:privateAccess queue.postProcess();
        }
    }

    private static var reg = new EReg("\\{\\{(.*?)\\}\\}", "gm");
    private static inline function applyPropertiesTo(s:String, properties:PropertiesConfig):String {
        if (s.contains("{{") && s.contains("}}")) {
            s = reg.map(s, f -> {
                var v = properties.get(f.matched(1));
                if (v == s && @:privateAccess properties.parentProperties != null) {
                    v = @:privateAccess properties.parentProperties.get(f.matched(1));
                }
                if (v == null) {
                    trace("WARNING: could not resolve property placholder {{" + f.matched(1) + "}}");
                    return "";
                }
                return v;
            });
        }
        return s;
    }

    private static var _config:EsbConfig = null;
    public static function get(filename:String = "config/esb.json", cache:Bool = true):EsbConfig {
        if (_config != null) {
            return _config;
        }
        var config = ConfigParser.fromFile(filename);
        if (cache) {
            _config = config;
        }
        //trace(haxe.Json.stringify(config));
        return config;
    }
}

#end