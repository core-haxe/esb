package esb.core;

import esb.common.Uri;

@:keep
interface IConsumer {
    public var bundle:IBundle;
    public function start(uri:Uri):Void;
}