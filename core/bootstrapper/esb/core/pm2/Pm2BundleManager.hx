package esb.core.pm2;

import esb.core.config.sections.BundleConfig;
import esb.core.config.sections.EsbConfig;
import esb.common.Uri;
import esb.core.pm2.externs.Pm2;
import promises.Promise;
import esb.logging.Logger;

using StringTools;

class Pm2BundleManager {
    private static var log:Logger = new Logger("esb.core.Pm2BundleManager");

    private static var _connected:Bool = false;
    public static function start():Promise<Bool> {
        return new Promise((resolve, reject) -> {
            if (_connected) {
                resolve(true);
                return;
            }
            log.info("connecting to PM2");
            _connected = true;
            Pm2.connect((err) -> {
                if (err != null) {
                    stop();
                    reject(err);
                    return;
                }
                resolve(true);
            });
        });
    }

    public static function stop():Promise<Bool> {
        return new Promise((resolve, reject) -> {
            _connected = false;
            Pm2.disconnect();
            resolve(true);
        });
    }

    public static function startBundle(bundleConfig:BundleConfig):Promise<Bool> {
        return new Promise((resolve, reject) -> {
            Pm2.list((err, list) -> {
                var bundleFile = bundleConfig.bundleFile;
                if (!bundleFile.endsWith(".js")) {
                    bundleFile += ".js";
                }
                    
                var itemName = bundleFile.replace(".js", "");
                if (bundleConfig.name != null) {
                    itemName = bundleConfig.name;
                }

                var alreadyExists = false;
                var alreadyRunning = false;
                for (item in list) {
                    if (item.name == itemName) {
                        alreadyExists = true;
                        if (item.pid != 0) {
                            alreadyRunning = true;
                        }
                        break;
                    }
                }

                if (!alreadyExists) {
                    log.info('bundle ${itemName} doesnt exist, starting (${bundleFile})');
                    var details:Dynamic = {
                        name: itemName,
                        script: bundleFile,
                        args: [],
                        watch: true
                    }
                    Pm2.start(details, (err, app) -> {
                        if (err != null) {
                            trace(err);
                            return;
                        } else {
                            resolve(true);
                        }
                    });
                } else if (!alreadyRunning) {
                    log.info('bundle ${itemName} exists but isnt running, restarting');
                    Pm2.restart(itemName, (err, proc) -> {
                        if (err != null) {
                            trace(err);
                            return;
                        } else {
                            resolve(true);
                        }
                    });
                } else {
                    resolve(true);
                }
            });
        });
    }

    public static function stopBundle(bundleConfig:BundleConfig):Promise<Bool> {
        return new Promise((resolve, reject) -> {
            Pm2.list((err, list) -> {
                var bundleFile = bundleConfig.bundleFile;
                if (!bundleFile.endsWith(".js")) {
                    bundleFile += ".js";
                }
                    
                var itemName = bundleFile.replace(".js", "");
                if (bundleConfig.name != null) {
                    itemName = bundleConfig.name;
                }

                var alreadyExists = false;
                var alreadyRunning = false;
                for (item in list) {
                    if (item.name == itemName) {
                        alreadyExists = true;
                        if (item.pid != 0) {
                            alreadyRunning = true;
                        }
                        break;
                    }
                }

                if (alreadyExists) {
                    Pm2.delete(itemName, (err, app) -> {
                        resolve(true);
                    });
                } else {
                    resolve(true);
                }
            });
        });
    }

    public static function startEndpoint(uri:Uri, producer:Bool):Promise<Bool> {
        return new Promise((resolve, reject) -> {
            var bundleConfig = EsbConfig.get().findBundleFromPrefix(uri.prefix, producer);
            if (bundleConfig == null) {
                reject("no bundle config found");
                return;
            }

            var bundleFile:String = bundleConfig.bundleFile;
            if (bundleFile == "internal") {
                resolve(true);
                return;
            }
            if (!bundleFile.endsWith(".js")) {
                bundleFile += ".js";
            }

            Pm2.list((err, list) -> {
                var itemName = uri.asEndpoint();
                var alreadyExists = false;
                var alreadyRunning = false;
                for (item in list) {
                    if (item.name == itemName) {
                        alreadyExists = true;
                        if (item.pid != 0) {
                            alreadyRunning = true;
                        }
                        break;
                    }
                }

                if (!alreadyExists) {
                    log.info('endpoint ${uri.asEndpoint()} doesnt exist, starting');
                    var type:String = "consumer";
                    if (producer) {
                        type = "producer";
                    }
                    var details:Dynamic = {
                        name: itemName,
                        script: bundleFile,
                        args: [
                            "--json-config",
                            '{"type":"${type}","uri":"${uri.toString()}"}'
                        ],
                        watch: true,
                        //namespace: type
                    }
                    Pm2.start(details, (err, app) -> {
                        if (err != null) {
                            trace(err);
                            return;
                        } else {
                            resolve(true);
                        }
                    });
                } else if (!alreadyRunning) {
                    log.info('endpoint ${uri.asEndpoint()} exists but isnt running, restarting');
                    Pm2.restart(itemName, (err, proc) -> {
                        if (err != null) {
                            trace(err);
                            return;
                        } else {
                            resolve(true);
                        }
                    });
                } else {
                    resolve(true);
                }
            });
        });
    }


}