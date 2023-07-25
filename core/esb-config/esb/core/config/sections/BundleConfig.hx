package esb.core.config.sections;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.BundleConfig")
extern class BundleConfig {
    public function new();
    public var name:String;
    public var bundleFile:String;
    public var bundleEntryPoint:String;
    public var autoStart:Bool;
    public var autoLoad:Bool;
    public var disabled:Bool;
    public var prefixes:Map<String, BundlePrefixConfig>;
    public var routes:Map<String, BundleRouteConfig>;
    public var dependencies:Array<String>;
    public var properties:PropertiesConfig;
    
    public function hasPrefix(prefix:String, producer:Bool):Bool;
    public function getPrefix(prefix:String, producer:Bool):BundlePrefixCommonConfig;
}

#else

@:expose
@:native("esb.core.config.sections.BundleConfig")
class BundleConfig {
    public var name:String;
    @:alias("bundle-file") public var bundleFile:String;
    @:alias("bundle-entry-point") public var bundleEntryPoint:String;
    @:alias("auto-start") public var autoStart:Bool;
    @:alias("auto-load") public var autoLoad:Bool;
    public var disabled:Bool;

    @:default(new Map<String, esb.core.config.sections.BundlePrefixConfig>())
    @:optional public var prefixes:Map<String, BundlePrefixConfig>;

    @:default(new Map<String, esb.core.config.sections.BundleRouteConfig>())
    @:optional public var routes:Map<String, BundleRouteConfig>;

    @:default(new Array<String>())
    @:optional public var dependencies:Array<String>;
    
    @:alias("properties") private var _properties:Map<String, String> = [];
    @:jignored public var properties:PropertiesConfig;

    public function new() {
    }

    public function hasPrefix(prefix:String, producer:Bool):Bool {
        if (prefixes == null) {
            return false;
        }

        if (!prefixes.exists(prefix)) {
            return false;
        }

        var prefixConfig = prefixes.get(prefix);
        if (producer && prefixConfig.producer == null) {
            return false;
        }
        if (!producer && prefixConfig.consumer == null) {
            return false;
        }

        return true;
    }

    public function getPrefix(prefix:String, producer:Bool):BundlePrefixCommonConfig {
        if (prefixes == null) {
            return null;
        }

        if (!prefixes.exists(prefix)) {
            return null;
        }

        var prefixConfig = prefixes.get(prefix);
        if (producer && prefixConfig.producer != null) {
            return prefixConfig.producer;
        }
        if (!producer && prefixConfig.consumer != null) {
            return prefixConfig.consumer;
        }

        return null;
    }

    @:jignored private var _parent:EsbConfig = null;
    private var parent(get, set):EsbConfig;
    private function get_parent():EsbConfig {
        return _parent;
    }
    private function set_parent(value:EsbConfig):EsbConfig {
        _parent = value;
        for (prefixName in prefixes.keys()) {
            var prefix = prefixes.get(prefixName);
            @:privateAccess prefix.parent = this;
        }
        return value;
    }

    private function postProcess() {
        properties = new PropertiesConfig(_properties);
        @:privateAccess properties.parentProperties = _parent.properties;
        @:privateAccess properties.postProcess();

        if (name != null) {
            name = @:privateAccess EsbConfig.applyPropertiesTo(name, this.properties);
        }
        if (bundleFile != null) {
            bundleFile = @:privateAccess EsbConfig.applyPropertiesTo(bundleFile, this.properties);
        }


        for (prefixName in prefixes.keys()) {
            var prefix = prefixes.get(prefixName);
            @:privateAccess prefix.postProcess();
        }
    }
}

#end