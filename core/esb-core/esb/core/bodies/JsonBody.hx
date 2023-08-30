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
    public var data:Dynamic = null;

    public override function toBytes():Bytes {
        if (data == null) {
            return null;
        }
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
        if (data == null) {
            data = {};
        }
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

    public static function toCsv(json:JsonBody):CsvBody {
        var csv = new CsvBody();
        if (json.data is Array) {
            var jsonArray:Array<Dynamic> = json.data;
            var csvColumns:Array<String> = [];
            for (jsonItem in jsonArray) {
                for (f in Reflect.fields(jsonItem)) {
                    if (!csvColumns.contains(f)) {
                        csvColumns.push(f);
                    }
                }
            }
            csv.addColumns(csvColumns);
            for (jsonItem in jsonArray) {
                var csvRow = [];
                for (field in csvColumns) {
                    var value = Reflect.field(jsonItem, field);
                    if (value == null) {
                        value = "";
                    }
                    csvRow.push(value);
                }
                csv.addRow(csvRow);
            }
        }
        return csv;
    }

    public static function toXml(json:JsonBody):XmlBody {
        var xml = new XmlBody();
        xml.root = Xml.parse("<root></root>");

        // TODO: incomplete
        var processItem = function(item:Dynamic, node:Xml) {
            for (field in Reflect.fields(item)) {
                var value = Reflect.field(item, field);
                trace(Type.typeof(value));
                switch (Type.typeof(value)) {
                    case TObject:
                    case _:
                        if (value is Array) {

                        } else {
                            node.addChild(Xml.parse('<${field}>${value}</${field}>'));
                        }
                }
            }
        }

        if (json.data is Array) {

        } else {
            processItem(json.data, xml.root.firstElement());
        }

        return xml;
    }
}

#end