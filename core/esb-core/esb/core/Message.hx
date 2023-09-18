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

    public static inline var PropertyBreadcrumbs = "audit.breadcrumbs";
    public static inline var PropertyTimestamp = "audit.timestamp";
    public static inline var PropertyMessageId = "messageId";

    private function new() {
    }

    public function meta(value:Dynamic = null):Dynamic {
        if (value != null) {
            var properties:Map<String, Any> = value.properties;
            if (properties != null) {
                for (propKey in properties.keys()) {
                    var propValue = properties.get(propKey);
                    if (!this.properties.exists(propKey)) {
                        this.properties.set(propKey, propValue);
                    }
                }
            }
            return value;
        }

        var value:Dynamic = {
            properties: properties
        }
        return value;
    }

    public function hash():String {
        var s = serialize();
        return haxe.crypto.Md5.make(Bytes.ofString(s)).toHex();
    }

    public function timestamp() {
        properties.set(PropertyTimestamp, js.lib.Date.now());
    }

    public function bodyHash():String {
        if (body == null) {
            return null;
        }
        var b = body.toBytes();
        if (b == null) {
            return null;
        }

        return haxe.crypto.Md5.make(b).toHex();
    }

    public function addBreadcrumb() {
        var array:Array<String> = properties.get(PropertyBreadcrumbs);
        if (array == null) {
            array = [];
            properties.set(PropertyBreadcrumbs, array);
        }
        array.push(esb.common.Uuid.generate());
    }

    public function breacrumbs():Array<String> {
        var array:Array<String> = properties.get(PropertyBreadcrumbs);
        if (array == null) {
            return [];
        }
        return array;
    }

    public function serialize():String {
        if (!properties.exists(PropertyMessageId)) {
            properties.set(PropertyMessageId, esb.common.Uuid.generate());
        }
        if (breacrumbs().length == 0) {
            addBreadcrumb();
        }
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

        if (!properties.exists(PropertyMessageId)) {
            properties.set(PropertyMessageId, esb.common.Uuid.generate());
        }
        if (breacrumbs().length == 0) {
            addBreadcrumb();
        }
    }
}