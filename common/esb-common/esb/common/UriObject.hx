package esb.common;

using StringTools;

#if !esb_common_impl

@:jsRequire("./esb-common.js", "esb.common.UriObject")
extern class UriObject {
    public var prefix:String;
    public var path:String;
    public var params:Map<String, Any>;

    public function new(uri:String = null);
    public function parse(uri:String):Void;
    public function param(name:String, defaultValue:String = null):String;
    public function paramInt(name:String, defaultValue:Null<Int>):Null<Int>;
    public function paramBool(name:String, defaultValue:Null<Bool>):Null<Bool>;
    public function asEndpoint():String;
    public function toString():String;
    public function clone():Uri;
    public static function fromString(uri:String):Uri;
}

#else

@:expose
@:native("esb.common.UriObject")
class UriObject {
    public var prefix:String;
    public var path:String;
    public var params:Map<String, Any> = [];

    public function new(uri:String = null) {
        if (uri != null) {
            parse(uri);
        }
    }

    public function parse(uri:String) {
        var parts = uri.split(":");
        prefix = parts.shift();
        uri = parts.join(":");
        while (uri.startsWith("/")) {
            uri = uri.substr(1);
        }

        var n = uri.indexOf("?");
        if (n == -1) {
            path = uri;
        } else {
            params = [];
            path = uri.substring(0, n);
            var paramsString = uri.substring(n + 1);
            var paramParts = paramsString.split("&");
            for (p in paramParts) {
                var pp = p.split("=");
                if (pp.length == 1) {
                    params.set(pp[0], pp[0]);
                } else {
                    var v = pp[1]; // TODO: auto convert type?
                    params.set(pp[0], v);
                }
            }
        }
    }

    public function param(name:String, defaultValue:String = null):String {
        if (!params.exists(name)) {
            return defaultValue;
        }
        return params.get(name);
    }

    public function paramInt(name:String, defaultValue:Null<Int>):Null<Int> {
        if (!params.exists(name)) {
            return defaultValue;
        }
        return Std.parseInt(params.get(name));
    }

    public function paramBool(name:String, defaultValue:Null<Bool>):Null<Bool> {
        if (!params.exists(name)) {
            return defaultValue;
        }
        return params.get(name) == "true";
    }

    public function asEndpoint():String {
        var s = prefix + "://";
        s += path;
        if (params != null) {
            s += "";
        }
        return s;
    }

    public function toString():String {
        var s = prefix;
        if (!prefix.startsWith("{{") && !prefix.endsWith("}}")) {
            s += "://";
        }
        s += path;
        if (params != null) {
            var paramArray = null;
            for (key in params.keys()) {
                if (paramArray == null) {
                    paramArray = [];
                    s += "?";
                }
                var value = params.get(key);
                if (value == null) {
                    paramArray.push('${key}');
                } else {
                    paramArray.push('${key}=${value}');
                }
            }
            if (paramArray != null) {
                s += paramArray.join("&");
            }
        }
        return s;
    }

    public function clone():Uri {
        return Uri.fromString(this.toString());
    }

    public static function fromString(uri:String):UriObject {
        var instance = new UriObject(uri);
        return instance;
    }
}

#end