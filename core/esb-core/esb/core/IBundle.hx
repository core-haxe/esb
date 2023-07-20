package esb.core;

import esb.core.config.sections.BundleConfig;

interface IBundle {
    public var config:BundleConfig;
    public var classResolver:String->Class<Dynamic>;
    public function start():Void;
}