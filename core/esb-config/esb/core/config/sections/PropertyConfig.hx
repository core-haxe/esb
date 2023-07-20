package esb.core.config.sections;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.PropertyConfig")
extern class PropertyConfig {
    public function new();
    public var name:String;
    public var value:String;
}

#else

@:expose
@:native("esb.core.config.sections.PropertyConfig")
class PropertyConfig {
    public var name:String;
    public var value:String;

    public function new() {
    }
}

#end