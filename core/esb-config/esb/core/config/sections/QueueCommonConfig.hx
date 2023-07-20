package esb.core.config.sections;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.QueueCommonConfig")
extern class QueueCommonConfig {
    public function new();
    public var className:String;
    public var properties:PropertiesConfig;
}

#else

@:expose
@:native("esb.core.config.sections.QueueCommonConfig")
class QueueCommonConfig {
    @:alias("class") public var className:String;

    @:alias("properties") private var _properties:Map<String, String> = [];
    @:jignored public var properties:PropertiesConfig;

    @:jignored private var _parent:QueueConfig = null;
    private var parent(get, set):QueueConfig;
    private function get_parent():QueueConfig {
        return _parent;
    }
    private function set_parent(value:QueueConfig):QueueConfig {
        _parent = value;
        return value;
    }

    private function postProcess() {
        properties = new PropertiesConfig(_properties);
        @:privateAccess properties.parentProperties = _parent.properties;
        @:privateAccess properties.postProcess();

        if (className != null) {
            className = @:privateAccess EsbConfig.applyPropertiesTo(className, this.properties);
        }
    }
}

#end