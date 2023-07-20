package esb.core.config.sections;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.BundlePrefixConfig")
extern class BundlePrefixConfig {
    public function new();
    public var consumer:BundlePrefixConsumerConfig;
    public var producer:BundlePrefixProducerConfig;
}

#else

@:expose
@:native("esb.core.config.sections.BundlePrefixConfig")
class BundlePrefixConfig {
    public var consumer:BundlePrefixConsumerConfig;
    public var producer:BundlePrefixProducerConfig;

    @:jignored private var _parent:BundleConfig = null;
    private var parent(get, set):BundleConfig;
    private function get_parent():BundleConfig {
        return _parent;
    }
    private function set_parent(value:BundleConfig):BundleConfig {
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
        if (consumer != null) {
            @:privateAccess consumer.postProcess();
        }
        if (producer != null) {
            @:privateAccess producer.postProcess();
        }
    }
}

#end