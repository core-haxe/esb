package esb.core.bodies;

import haxe.io.Bytes;
import haxe.Json;

using StringTools;

#if !esb_core_impl

@:jsRequire("./esb-core.js", "esb.core.bodies.JsonBody")
extern class JsonBody extends RawBody {
    public var data:Dynamic;
    public function fields():Array<String>;
    public function value(path:String, defaultValue:Any = null):Any;
    public function set(path:String, value:Any = null):Void;
}

#else

@:keep
@:keepInit
@:keepSub
@:expose
@:native("esb.core.bodies.JsonBody")
class JsonBody extends RawBody {
    public var data:Dynamic;

    public override function toBytes():Bytes {
        return Bytes.ofString(Json.stringify(this.data, null, "  "));
    }

    public override function fromBytes(bytes:Bytes) {
        data = Json.parse(bytes.toString());
    }

    public function fields():Array<String> {
        return Reflect.fields(data);
    }

    public function value(path:String, defaultValue:Any = null):Any {
        if (path.startsWith("$.")) {
            path = path.substring(2);
        }
        var parts = path.split(".");
        var ref = data;
        for (p in parts) {
            if (!Reflect.hasField(ref, p)) {
                return defaultValue;
            }
            ref = Reflect.field(ref, p);
        }
        
        return ref;
    }

    public function set(path:String, value:Any = null) {
        if (path.startsWith("$.")) {
            path = path.substring(2);
        }

        var parts = path.split(".");
        var lastPart = parts.pop();
        var ref = data;
        for (p in parts) {
            if (!Reflect.hasField(ref, p)) {
                Reflect.setField(ref, p, {});
            }
            ref = Reflect.field(ref, p);
        }

        if (ref != null) {
            Reflect.setField(ref, lastPart, value);
            _bytes = Bytes.ofString(Json.stringify(data, null, "  "));
        }
    }
}

#end