package esb.core;

import promises.Promise;
import esb.common.Uri;
import promises.PromiseUtils.*;

#if !esb_bundle_manager_impl

class BundleManager {
    private static var clientChannel:esb.core.ipc.Channel = new esb.core.ipc.Channel("esb-bundle-manager");
    private static var started:Bool = false;

    public static function start():Promise<Bool> {
        return new Promise((resolve, reject) -> {
            if (started) {
                resolve(true);
                return;
            }
            started = true;
            clientChannel.start().then(_ -> {
                resolve(true);
            }, error -> {
                reject(error);
            });
        });
    }

    public static function stop():Promise<Bool> {
        return new Promise((resolve, reject) -> {
            resolve(true);
        });
    }

    public static function startEndpoint(uri:Uri, producer:Bool, originalUri:Uri):Promise<Bool> {
        return new Promise((resolve, reject) -> {
            var cacheKey = uri.toString() + "_" + (producer == true ? "producer" : "consumer");
            if (_cachedEnpointsStarted.exists(cacheKey)) {
                resolve(true);
                return;
            }
            _startEndpoint(uri, producer, originalUri, resolve, reject);
        });
    }

    private static var _cachedEnpointsStarted:Map<String, Bool> = [];
    private static var _deferredStartEndpoint:Array<{uri:Uri, producer:Bool, originalUri:Uri, resolve:Dynamic, reject:Dynamic}> = [];
    private static var _startingEndpoint:Bool = false;
    private static function _startEndpoint(uri:Uri, producer:Bool, originalUri:Uri, resolve:Dynamic, reject:Dynamic) {
        if (_startingEndpoint == true) {
            _deferredStartEndpoint.push({uri: uri, producer: producer, originalUri: originalUri, resolve: resolve, reject: reject});
            return;
        }
        _startingEndpoint = true;

        var cacheKey = uri.toString() + "_" + (producer == true ? "producer" : "consumer");
        if (_cachedEnpointsStarted.exists(cacheKey)) {
            _startingEndpoint = false;
            resolve(true);
            if (_deferredStartEndpoint.length > 0) {
                /*
                var details = _deferredStartEndpoint.shift();
                _startEndpoint(details.uri, details.producer, details.resolve, details.reject);
                */
                var newList = [];
                for (item in _deferredStartEndpoint) {
                    if (item.uri.toString() == uri.toString() && item.producer == producer) {
                        item.resolve(true);
                    } else {
                        newList.push(item);
                    }
                }
                _deferredStartEndpoint = newList;
            }

            if (_deferredStartEndpoint.length > 0) {
                var details = _deferredStartEndpoint.shift();
                _startEndpoint(details.uri, details.producer, details.originalUri, details.resolve, details.reject);
            }

            return;
        }

        start().then(_ -> {
            clientChannel.send("bundle.startEndpoint", {
                uri: uri.toString(),
                producer: producer,
                originalUri: originalUri.toString()
            }).then(result -> {
                //if (producer == true) {
                    _cachedEnpointsStarted.set(cacheKey, true);
                //}
                _startingEndpoint = false;
                resolve(true);
                if (_deferredStartEndpoint.length > 0) {
                    var details = _deferredStartEndpoint.shift();
                    _startEndpoint(details.uri, details.producer, details.originalUri, details.resolve, details.reject);
                }
            }, error -> {
                trace(">>>>>>>>>>>>>>>>>>>>>> ERROR", error);
                _startingEndpoint = false;
                reject(error);
                if (_deferredStartEndpoint.length > 0) {
                    var details = _deferredStartEndpoint.shift();
                    _startEndpoint(details.uri, details.producer, details.originalUri, details.resolve, details.reject);
                }
            });
        }, error -> {
            trace(">>>>>>>>>>>>>>>>>>>>>> ERROR", error);
            _startingEndpoint = false;
            reject(error);
            if (_deferredStartEndpoint.length > 0) {
                var details = _deferredStartEndpoint.shift();
                _startEndpoint(details.uri, details.producer, details.originalUri, details.resolve, details.reject);
            }
        });
    }
}

/*
@:jsRequire("./esb-bundle-manager.js", "esb.core.BundleManager")
extern class BundleManager {
    public static function start():Promise<Bool>;
    public static function stop():Promise<Bool>;
    public static function startEndpoint(uri:Uri, producer:Bool):Promise<Bool>;
}
*/

#else

/*
@:expose
@:native("esb.core.BundleManager")
*/
class BundleManager {
    private static var serverChannel:esb.core.ipc.Channel = new esb.core.ipc.Channel("esb-bundle-manager", true);
    private static var started:Bool = false;

    public static function start():Promise<Bool> {
        return new Promise((resolve, reject) -> {
            if (started) {
                resolve(true);
                return;
            }
            started = true;
            serverChannel.start(onMessage).then(_ -> {
                return esb.core.pm2.Pm2BundleManager.start();
            }).then(result -> {
                resolve(true);
            }, error -> {
                reject(error);
            });
        });
    }

    private static var _initializingMap:Map<String, Array<{resolve: Dynamic, reject: Dynamic}>> = [];
    private static function onMessage(message:String, payload:Dynamic):Promise<Dynamic> {
        return new Promise((resolve, reject) -> {
            switch (message) {
                case "bundle.startEndpoint":
                    var uri = Uri.fromString(payload.uri);
                    var producer = payload.producer;
                    var originalUri = Uri.fromString(payload.originalUri);
                    var cacheKey = uri.toString() + "_" + (producer == true ? "producer" : "consumer");
                    if (_initializingMap.exists(cacheKey)) {
                        _initializingMap.get(cacheKey).push({resolve: resolve, reject: reject});
                        return;
                    }
        
                    _initializingMap.set(cacheKey, []);
                    startEndpoint(uri, producer, originalUri).then(_ -> {
                        for (details in _initializingMap.get(cacheKey)) {
                            details.resolve(payload);
                        }
                        _initializingMap.remove(cacheKey);
                        resolve(payload);
                    }, error -> {
                        reject(error);
                    });
                case _: 
                    trace(">>>>>>>>>>>>>>>>>>>>>>>>>> UNKNOWN BUNDLE MESSAGE", message);
                    resolve(payload);
            }
        });
    }

    public static function stop():Promise<Bool> {
        return esb.core.pm2.Pm2BundleManager.stop();
    }

    public static function startBundle(bundleConfig:esb.core.config.sections.BundleConfig):Promise<Bool> {
        return esb.core.pm2.Pm2BundleManager.startBundle(bundleConfig);
    }

    public static function stopBundle(bundleConfig:esb.core.config.sections.BundleConfig):Promise<Bool> {
        return esb.core.pm2.Pm2BundleManager.stopBundle(bundleConfig);
    }

    public static function startEndpoint(uri:Uri, producer:Bool, originalUri:Uri):Promise<Bool> {
        return new Promise((resolve, reject) -> {
            _startEndpoint(uri, producer, originalUri, resolve, reject);
        });

        return esb.core.pm2.Pm2BundleManager.startEndpoint(uri, producer, originalUri);
    }

    private static var _deferredStartEndpoint:Array<{uri:Uri, producer:Bool, originalUri:Uri, resolve:Dynamic, reject:Dynamic}> = [];
    private static var _startingEndpoint:Bool = false;
    private static function _startEndpoint(uri:Uri, producer:Bool, originalUri:Uri, resolve:Dynamic, reject:Dynamic) {
        if (_startingEndpoint == true) {
            _deferredStartEndpoint.push({uri: uri, producer: producer, originalUri: originalUri, resolve: resolve, reject: reject});
            return;
        }
        _startingEndpoint = true;
        esb.core.pm2.Pm2BundleManager.startEndpoint(uri, producer, originalUri).then(success -> {
            _startingEndpoint = false;
            resolve(success);
            if (_deferredStartEndpoint.length > 0) {
                var details = _deferredStartEndpoint.shift();
                _startEndpoint(details.uri, details.producer, details.originalUri, details.resolve, details.reject);
            }
        }, error -> {
            _startingEndpoint = false;
            reject(error);
            if (_deferredStartEndpoint.length > 0) {
                var details = _deferredStartEndpoint.shift();
                _startEndpoint(details.uri, details.producer, details.originalUri, details.resolve, details.reject);
            }
        });
    }

    public static function autostartBundles():Promise<Bool> {
        return new Promise((resolve, reject) -> {
            var list = esb.core.config.sections.EsbConfig.get().getAutoStartBundles();
            var promises = [];
            for (bundle in list) {
                var bundleConfig = esb.core.config.sections.EsbConfig.get().bundles.get(bundle.name);
                promises.push(startBundle.bind(bundleConfig));
            }
            
            runSequentially(promises).then(_ -> {
                resolve(true);
            }, error -> {
                reject(error);
            });
        });
    }

    public static function autostopBundles():Promise<Bool> {
        return new Promise((resolve, reject) -> {
            var list = esb.core.config.sections.EsbConfig.get().getDisabledBundles();
            var promises = [];
            for (bundle in list) {
                var bundleConfig = esb.core.config.sections.EsbConfig.get().bundles.get(bundle.name);
                promises.push(stopBundle.bind(bundleConfig));
            }
            
            runSequentially(promises).then(_ -> {
                resolve(true);
            }, error -> {
                reject(error);
            });
        });
    }
}

#end