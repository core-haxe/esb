package esb.core.bodies;

import haxe.io.Bytes;
#if !esb_core_impl

@:jsRequire("./esb-core.js", "esb.core.bodies.MultiBody")
extern class MultiBody extends RawBody {
    public var bodies:Map<String, RawBody>;
    public function getAs<T:RawBody>(name:String, convertTo:Class<T>):T;
    public function set<T:RawBody>(name:String, body:T):Void;
}

#else

@:keep
@:keepInit
@:keepSub
@:expose
@:native("esb.core.bodies.MultiBody")
class MultiBody extends RawBody {
    public var bodies:Map<String, RawBody> = [];

    public function getAs<T:RawBody>(name:String, convertTo:Class<T>):T {
        var body = bodies.get(name);
        if (convertTo != null) {
            body = Bus.convertBody(body, convertTo);
        }
        return cast body;
    }

    public function set<T:RawBody>(name:String, body:T) {
        bodies.set(name, body);
    }

    public override function fromBytes(bytes:Bytes) {
        var unserializer = new haxe.Unserializer(bytes.toString());
        var bodyCount = unserializer.unserialize();
        for (_ in 0...bodyCount) {
            var name = unserializer.unserialize();
            var type = unserializer.unserialize();
            var data = unserializer.unserialize();
            var body:RawBody = Type.createInstance(Type.resolveClass(type), []);
            //var body = new RawBody();
            body.fromBytes(data);
            set(name, body);
        }
    }

    public override function toBytes():Bytes {
        var serializer = new haxe.Serializer();
        var n = 0;
        for (_ in bodies.keys()) {
            n++;
        }
        serializer.serialize(n);
        for (name in bodies.keys()) {
            var body = bodies.get(name);
            serializer.serialize(name);
            serializer.serialize(Type.getClassName(Type.getClass(body)));
            serializer.serialize(body.toBytes());
        }

        return Bytes.ofString(serializer.toString());
    }

    public static function toXml(multi:MultiBody):XmlBody {
        var xml = new XmlBody();
        xml.root = Xml.parse("<root></root>");

        for (bodyName in multi.bodies.keys()) {
            var body = multi.getAs(bodyName, XmlBody);
            var xmlBody = Bus.convertBody(body, XmlBody);
            xmlBody.root.firstElement().nodeName = bodyName;
            xml.root.firstElement().addChild(xmlBody.root);
        }

        return xml;
    }
}

#end