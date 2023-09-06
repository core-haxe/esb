package esb.core.config.sections;

using StringTools;

#if !esb_config_impl

@:jsRequire("./esb-config.js", "esb.core.config.sections.PropertiesConfig")
extern class PropertiesConfig {
    public function new();
    public function get(name:String, defaultValue:String = null, params:Map<String, Any> = null):String;
    public function int(name:String, defaultValue:Null<Int> = null, params:Map<String, Any> = null):Null<Int>;
    public function keys():Iterator<String>;
}

#else

@:expose
@:native("esb.core.config.sections.PropertiesConfig")
class PropertiesConfig {
    private var items:Map<String, String> = [];

    private var parentProperties:PropertiesConfig = null;

    public function new(items:Map<String, String>) {
        this.items = items;
    }

    private static var reg = new EReg("\\{(.*?)\\}", "gm");
    public function get(name:String, defaultValue:String = null, params:Map<String, Any> = null):String {
        if (items == null) {
            if (parentProperties != null) {
                return parentProperties.get(name, defaultValue, params);
            }
            return defaultValue;
        }
        if (!items.exists(name)) {
            if (parentProperties != null) {
                return parentProperties.get(name, defaultValue, params);
            }
            return defaultValue;
        }

        var v = items.get(name);
        if (params != null && v.contains("{") && v.contains("}")) {
            v = reg.map(v, f -> {
                var v = params.get(f.matched(1));
                if (v == null) {
                    trace("WARNING: could not resolve interpolated value {" + f.matched(1) + "}");
                    return "";
                }
                return v;
            });
        }
        return v;
    }

    public function int(name:String, defaultValue:Null<Int> = null, params:Map<String, Any> = null):Null<Int> {
        var v = get(name, null, params);
        if (v == null) {
            return defaultValue;
        }
        return Std.parseInt(v);
    }

    public function keys():Iterator<String> {
        if (items == null) {
            return null;
        }
        return items.keys();
    }

    private function postProcess() {
        if (items == null) {
            return;
        }
        for (item in items.keys()) {
            var value = items.get(item);
            value = @:privateAccess EsbConfig.applyPropertiesTo(value, this);
            items.set(item, value);
        }
        // lets do a second pass to make sure we have them all
        for (item in items.keys()) {
            var value = items.get(item);
            value = @:privateAccess EsbConfig.applyPropertiesTo(value, this);
            items.set(item, value);
        }
    }
}

#end