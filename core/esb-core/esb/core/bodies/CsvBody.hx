package esb.core.bodies;

import haxe.io.Bytes;

using StringTools;

#if !esb_core_impl

@:jsRequire("./esb-core.js", "esb.core.bodies.CsvBody")
extern class CsvBody extends RawBody {
    public var columns:Array<String>;
    public var data:Array<Array<Any>>;
    public function addColumn(name:String):Void;
    public function addColumns(names:Array<Any>):Void;
    public function addRow(data:Array<Any>):Void;
    public function records():Array<Message<CsvBody>>;
}

#else

@:keep
@:keepInit
@:keepSub
@:expose
@:native("esb.core.bodies.CsvBody")
class CsvBody extends RawBody {
    public var columns:Array<String> = [];
    public var data:Array<Array<Any>> = [];

    public function addColumns(names:Array<Any>) {
        columns = [];
        for (name in names) {
            columns.push(Std.string(name));
        }
    }

    public function addRow(rowData:Array<Any>) {
        data.push(rowData);
    }

    public function addColumn(name:String, value:Any = null) {
        columns.push(name);
        if (value != null) {
            for (d in data) {
                d.push(value);
            }
        }
    }

    public function records():Array<CsvBody> {
        var array = [];
        for (d in data) {
            var body = new CsvBody();
            body.columns = columns.copy();
            body.data = [d.copy()];
            array.push(body);
        }
        return array;
    }

    public override function fromBytes(bytes:Bytes) {
        var lines = bytes.toString().split("\n");
        var firstLine = null;
        for (line in lines) {
            line = line.trim();
            if (line.length == 0) {
                continue;
            }

            if (firstLine == null) {
                firstLine = line;
                addColumns(firstLine.split(","));
            } else {
                addRow(line.split(","));
            }
        }
    }

    public override function toBytes():Bytes {
        var sb = new StringBuf();
        sb.add(columns.join(","));
        sb.add("\n");
        for (row in data) {
            sb.add(row.join(","));
            sb.add("\n");
        }
        return Bytes.ofString(sb.toString());
    }
}

#end