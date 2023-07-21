package esb.core;

import esb.core.config.sections.BundleConfig;
import esb.core.config.sections.EsbConfig;
import esb.common.Uri;
#if !esb_core_impl

@:keep
@:keepSub
@:keepInit
@:jsRequire("./esb-core.js", "esb.core.Bundle")
extern class Bundle implements IBundle {
    public var config:BundleConfig;
    public var classResolver:String->Class<Dynamic>;
    public function new();
    public function start():Void;
}

#else

@:keep
@:keepSub
@:keepInit
@:expose
@:native("esb.core.Bundle")
class Bundle implements IBundle {
    public var config:BundleConfig;

    public var classResolver:String->Class<Dynamic> = null;
    private var jsonConfig:Dynamic = null;

    public function new() {
    }

    public function start() {
        processArgs();
        processConfig();
    }

    private function processArgs() {
        var args = Sys.args();
        var configString = null;
        var n = 0;
        for (_ in 0...args.length) {
            if (args[n] == "--json-config") {
                n++;
                configString = args[n];
            }
            n++;
        }

        if (configString != null) {
            jsonConfig = haxe.Json.parse(configString);
        }
    }

    private function processConfig() {
        if (classResolver == null) {
            classResolver = Type.resolveClass;
        }

        // consumers / producers
        if (jsonConfig != null) {
            var uri = Uri.fromString(jsonConfig.uri);
            var producer = (jsonConfig.type == "producer");
            var originalUri = uri;
            if (jsonConfig.originalUri != null) {
                originalUri = Uri.fromString(jsonConfig.originalUri);
            }
            var bundleConfig = EsbConfig.get().findBundleFromPrefix(originalUri.prefix, producer);
            if (bundleConfig != null && bundleConfig.hasPrefix(originalUri.prefix, producer)) {
                var prefixConfig = bundleConfig.getPrefix(originalUri.prefix, producer);
                if (prefixConfig != null && !prefixConfig.internal) {
                    var className = prefixConfig.className;
                    if (className != null) {
                        var cls = classResolver(className);
                        if (cls != null) {
                            if (producer) {
                                var producerInstance:IProducer = Type.createInstance(cls, []);
                                if (producerInstance != null) {
                                    producerInstance.bundle = this;
                                    producerInstance.start(uri);
                                }
                            } else {
                                var consumerInstance:IConsumer = Type.createInstance(cls, []);
                                if (consumerInstance != null) {
                                    consumerInstance.bundle = this;
                                    consumerInstance.start(uri);   
                                }
                            }
                        }
                    }
                }
            }
        }

        // routes
        if (config.routes != null) {
            for (routeName in config.routes.keys()) {
                var routeConfig = config.routes.get(routeName);
                var className = routeConfig.className;
                if (className != null) {
                    var cls = classResolver(className);
                    if (cls != null) {
                        var routeInstance:IConsumer = Type.createInstance(cls, []);
                        if (routeInstance != null) {
                            routeInstance.bundle = this;
                            routeInstance.start(null);   
                        }
                    }
                }
            }
        }
    }
}

#end