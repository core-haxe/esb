package esb.core.config.sections;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.BundlePrefixCommonConfig")
extern class BundlePrefixCommonConfig {
    public function new();
    public var className:String;
    public var internal:Bool;
    public var bundle(get, null):BundleConfig;
}

#else

@:expose
@:native("esb.core.config.sections.BundlePrefixCommonConfig")
class BundlePrefixCommonConfig {
    @:alias("class") public var className:String;
    public var internal:Bool;

    @:jignored private var _parent:BundlePrefixConfig = null;
    private var parent(get, set):BundlePrefixConfig;
    private function get_parent():BundlePrefixConfig {
        return _parent;
    }
    private function set_parent(value:BundlePrefixConfig):BundlePrefixConfig {
        _parent = value;
        return value;
    }

    public var bundle(get, null):BundleConfig;
    public function get_bundle():BundleConfig {
        return @:privateAccess _parent._parent;
    }

    private function postProcess() {
        if (className != null) {
            className = @:privateAccess EsbConfig.applyPropertiesTo(className, bundle.properties);
        }
    }
}

#end