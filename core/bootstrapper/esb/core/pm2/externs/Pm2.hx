package esb.core.pm2.externs;

@:jsRequire("pm2")
extern class Pm2 {
    public static function connect(cb:Dynamic->Void):Void;
    public static function disconnect():Void;
    public static function start(details:Dynamic, cb:Dynamic->Dynamic->Void):Void;
    public static function list(cb:Dynamic->Array<Dynamic>->Void):Void;
    public static function restart(name:String, cb:Dynamic->Dynamic->Void):Void;
    public static function stop(name:String, cb:Dynamic->Dynamic->Void):Void;
    public static function delete(name:String, cb:Dynamic->Dynamic->Void):Void;
}