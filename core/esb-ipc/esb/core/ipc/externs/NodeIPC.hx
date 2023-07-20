package esb.core.ipc.externs;

@:jsRequire("node-ipc", "default")
extern class NodeIPC {
    public static var config:Dynamic;
    public static var server:Dynamic;
    public static var of:Dynamic;
    public static function serve(cb:Void->Void):Void;
    public static function connectTo(id:String, cb:Void->Void):Void;
}