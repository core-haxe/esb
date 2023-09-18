package esb.common;

using StringTools;

#if !esb_common_impl

@:jsRequire("./esb-common.js", "esb.common.UriObject")
extern class UriObject {
    public var prefix:String;
    public var domain:String;
    public var port(get, null):Null<Int>;
    public var path:String;
    public var fullPath(get, null):String;
    public var params:Map<String, Any>;
    public var fragment:String;

    public function new(uri:String = null);
    public function parse(uri:String):Void;
    public function param(name:String, defaultValue:String = null):String;
    public function paramInt(name:String, defaultValue:Null<Int>):Null<Int>;
    public function paramBool(name:String, defaultValue:Null<Bool>):Null<Bool>;
    public function asEndpoint():String;
    public function toString():String;
    public function clone():Uri;
    public function replacePlaceholdersWith(uri:Uri):Void;
    public static function fromString(uri:String):Uri;
}

#else

/*

    http://somewhere.there:999999/someplace_else?someparam1=value1&someparam2=value2#someotherinfo
    | pre | domain        | port | path         | params                            | fragment   |
*/


@:expose
@:native("esb.common.UriObject")
class UriObject {
    public var prefix:String;
    public var domain:String;
    public var path:String;
    public var params:Map<String, Any> = [];
    public var fragment:String;

    public var portString:String;

    public function new(uri:String = null) {
        if (uri != null) {
            parse(uri);
        }
    }

    public var port(get, null):Null<Int>;
    private function get_port():Null<Int> {
        if (portString == null) {
            return null;
        }
        return Std.parseInt(portString);
    }

    public var fullPath(get, null):String;
    private function get_fullPath():String {
        var s = domain;
        if (portString != null && portString.length == 0) {
            s += ":";
        }
        if (path != null) {
            s += "/" + path;
        }
        return s;
    }

    public function parse(uri:String) {
        var n = uri.indexOf(":");
        prefix = uri.substring(0, n);
        uri = uri.substring(n + 1);
        while (uri.startsWith("/")) {
            uri = uri.substr(1);
        }

        var n = uri.indexOf("#");
        if (n != -1) {
            fragment = uri.substring(n + 1);
            uri = uri.substring(0, n);
        }

        params = [];
        var n = uri.indexOf("?");
        if (n != -1) {
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
            
            uri = uri.substring(0, n);
        }

        var n = uri.indexOf("/");
        if (n != -1) {
            path = uri.substring(n + 1);
            uri = uri.substring(0, n);
        }

        var n = uri.indexOf(":");
        if (n != -1) {
            portString = uri.substring(n + 1);
            uri = uri.substring(0, n);
        }

        domain = uri;
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
        if (domain != null) {
            s += domain;
        }
        if (port != null) {
            s += ":" + port;
        }
        if (path != null) {
            s += "/" + path;
        }
        return s;
    }

    public function toString():String {
        var s = prefix;
        if (s == null) {
            s = "";
        }
        s += "://";
        /*
        if (!domain.startsWith("{{") && !domain.endsWith("}}")) {
        }
        */
        if (domain != null) {
            s += domain;
        }
        if (portString != null) {
            s += ":" + portString;
        }
        if (path != null) {
            s += "/" + path;
        }

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

        if (fragment != null) {
            s += "#" + fragment;
        }

        return s;
    }

    public function replacePlaceholdersWith(uri:Uri) {
        domain = replaceParts(domain, uri);
        portString = replaceParts(portString, uri);
        path = replaceParts(path, uri);
        if (params != null) {
            for (key in params.keys()) {
                var value = params.get(key);
                var newValue = replaceParts(value, uri);
                if (value != newValue) {
                    params.set(key, newValue);
                }
            }
        }
    }

    private function replaceParts(s:String, uri:Uri):String {
        if (s == null) {
            return null;
        }
        if (s.contains("{port}") && uri.portString != null) {
            s = s.replace("{port}", uri.portString);
        }
        if (s.contains("{domain}") && uri.domain != null) {
            s = s.replace("{domain}", uri.domain);
        }
        if (s.contains("{path}") && uri.path != null) {
            s = s.replace("{path}", uri.path);
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