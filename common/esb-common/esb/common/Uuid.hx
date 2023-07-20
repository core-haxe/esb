package esb.common;

#if !esb_common_impl

@:jsRequire("./esb-common.js", "esb.common.Uuid")
extern class Uuid {
    public static function generate():String;
}

#else

@:expose
@:native("esb.common.Uuid")
class Uuid {
    public static function generate():String {
        return uuid.Uuid.v4();
    }
}

#end