package esb.core.config.sections;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.QueueConsumerConfig")
extern class QueueConsumerConfig extends QueueCommonConfig {
    public function new();
}

#else

@:expose
@:native("esb.core.config.sections.QueueConsumerConfig")
class QueueConsumerConfig extends QueueCommonConfig {
    
}

#end