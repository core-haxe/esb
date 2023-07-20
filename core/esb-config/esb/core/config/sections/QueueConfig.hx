package esb.core.config.sections;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.QueueConfig")
extern class QueueConfig {
    public function new();
    public var isDefault:Bool;
    public var consumer:QueueConsumerConfig;
    public var producer:QueueProducerConfig;
    public var properties:PropertiesConfig;
}

#else

@:expose
@:native("esb.core.config.sections.QueueConfig")
class QueueConfig {
    @:alias("default") public var isDefault:Bool;

    public var consumer:QueueConsumerConfig;
    public var producer:QueueProducerConfig;

    @:alias("properties") private var _properties:Map<String, String> = [];
    @:jignored public var properties:PropertiesConfig;

    @:jignored private var _parent:EsbConfig = null;
    private var parent(get, set):EsbConfig;
    private function get_parent():EsbConfig {
        return _parent;
    }
    private function set_parent(value:EsbConfig):EsbConfig {
        _parent = value;
        if (consumer != null) {
            @:privateAccess consumer.parent = this;
        }
        if (producer != null) {
            @:privateAccess producer.parent = this;
        }
        return value;
    }

    private function postProcess() {
        properties = new PropertiesConfig(_properties);
        @:privateAccess properties.parentProperties = _parent.properties;
        @:privateAccess properties.postProcess();

        if (consumer != null) {
            @:privateAccess consumer.postProcess();
        }
        if (producer != null) {
            @:privateAccess producer.postProcess();
        }

    }
}

#end