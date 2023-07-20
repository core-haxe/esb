package esb.core.config.sections;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.QueueProducerConfig")
extern class QueueProducerConfig extends QueueCommonConfig {
    public function new();
}

#else

@:expose
@:native("esb.core.config.sections.QueueProducerConfig")
class QueueProducerConfig extends QueueCommonConfig {
    
}

#end