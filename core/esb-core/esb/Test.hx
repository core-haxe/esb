package esb;

#if !esb_core_impl

@:jsRequire("./esb-core.js", "esb.Test")
extern class Test {
    public function new();
    public function someOtherTestFunction():Void;
    public static function someTestFunction():Void;
}

#else

@:expose
@:native("esb.Test")
class Test {
    public function new() {

    }

    public function someOtherTestFunction() {
        trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> THIS IS ANOTER TEST FUNCTION IN ESB CORE11111");
    }

    public static function someTestFunction() {
        trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> THIS IS A TEST FUNCTION IN ESB CORE1111111111");
    }
}

#end
