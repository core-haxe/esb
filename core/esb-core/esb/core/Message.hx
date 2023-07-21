package esb.core;

import haxe.io.Bytes;
import haxe.Unserializer;
import haxe.Serializer;
import esb.core.bodies.RawBody;

@:keep
@:keepSub
@:keepInit
class Message<T:RawBody> {
    public var correlationId:String;
    public var properties:Map<String, Any> = [];
    public var headers:Map<String, Any> = [];
    public var bodyType:String = Type.getClassName(RawBody);

    public var body:T;

    private function new() {
    }

    public function serialize():String {
        var serializer = new Serializer();
        //serializer.useCache = true;
        serializer.serialize(correlationId);
        serializer.serialize(properties);
        serializer.serialize(headers);
        serializer.serialize(bodyType);

        var newBytes = null;
        var bytes = body.toBytes();
        if (bytes != null) {
            newBytes = haxe.io.Bytes.alloc(bytes.length);
            newBytes.blit(0, bytes, 0, bytes.length);
        }

        serializer.serialize(newBytes);
        return serializer.toString();
    }

    public function unserialize(data:String) {
        var unserializer = new Unserializer(data);
        correlationId = unserializer.unserialize();
        properties = unserializer.unserialize();
        headers = unserializer.unserialize();
        bodyType = unserializer.unserialize();
        var bytes:Bytes = unserializer.unserialize();
        body.fromBytes(bytes);
    }
}