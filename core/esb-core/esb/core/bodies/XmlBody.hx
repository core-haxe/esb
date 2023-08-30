package esb.core.bodies;

import haxe.io.Bytes;

class XmlBody extends RawBody {
    public var root:Xml = null;

    public override function fromBytes(bytes:Bytes) {
        root = Xml.parse(bytes.toString());
    }

    public override function toBytes():Bytes {
        if (root == null) {
            return null;
        }
        return Bytes.ofString(root.toString());
    }
}