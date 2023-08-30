package esb.core.bodies;

import haxe.io.Encoding;
import haxe.io.Bytes;

@:keep
@:keepInit
@:keepSub
@:expose
@:native("esb.core.RawBody")
class RawBody {
    public function new() {
    }

    public function toString() {
        var bytes = toBytes();
        if (bytes == null) {
            return null;
        }

        return bytes.toString();
    }

    public function append(data:Any) {
        if ((data is String)) {
            var s:String = cast data;
            if (_bytes == null) {
                _bytes = Bytes.ofString(s);
            } else {
                _bytes = Bytes.ofString(_bytes.toString() + s);
            }
        }
    }

    private var _bytes:Bytes = null;

    public function fromBytes(bytes:Bytes) {
        _bytes = bytes;
    }

    public function toBytes():Bytes {
        return _bytes;
    }
}