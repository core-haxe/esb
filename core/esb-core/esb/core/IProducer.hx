package esb.core;

import esb.common.Uri;

@:keep
interface IProducer {
    public var bundle:IBundle;
    public function start(uri:Uri):Void;
}