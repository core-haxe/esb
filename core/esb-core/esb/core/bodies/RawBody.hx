package esb.core.bodies;

import haxe.io.Encoding;
import haxe.io.Bytes;

@:keep
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

    private var _bytes:Bytes = null;

    public function fromBytes(bytes:Bytes) {
        _bytes = bytes;
    }

    public function toBytes():Bytes {
        return _bytes;
    }
}