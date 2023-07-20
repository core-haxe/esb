package esb.core.config.sections;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.BundlePrefixProducerConfig")
extern class BundlePrefixProducerConfig extends BundlePrefixCommonConfig {
    public function new();
}

#else

@:expose
@:native("esb.core.config.sections.BundlePrefixProducerConfig")
class BundlePrefixProducerConfig extends BundlePrefixCommonConfig {
}

#end