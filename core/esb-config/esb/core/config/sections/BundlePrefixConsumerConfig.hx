package esb.core.config.sections;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.BundlePrefixConsumerConfig")
extern class BundlePrefixConsumerConfig extends BundlePrefixCommonConfig {
    public function new();
}

#else

@:expose
@:native("esb.core.config.sections.BundlePrefixConsumerConfig")
class BundlePrefixConsumerConfig extends BundlePrefixCommonConfig {
}

#end