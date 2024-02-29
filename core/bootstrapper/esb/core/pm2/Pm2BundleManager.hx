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

    public static function startEndpoint(uri:Uri, producer:Bool, originalUri:Uri):Promise<Bool> {
        return new Promise((resolve, reject) -> {
            var bundleConfig = EsbConfig.get().findBundleFromPrefix(originalUri.prefix, producer);
            if (bundleConfig == null) {
                reject("no bundle config found for '" + originalUri.prefix + "'");
                return;
            }

            var prefixConfig = bundleConfig.getPrefix(originalUri.prefix, producer);
            if (prefixConfig.internal) {
                resolve(true);
                return;
            }

            var maxInstances = prefixConfig.maxInstances;
            if (maxInstances <= 0) {
                maxInstances = 1;
            }

            var bundleFile:String = bundleConfig.bundleFile;
            if (!bundleFile.endsWith(".js")) {
                bundleFile += ".js";
            }

            /*
            Pm2.list((err, list) -> {
                var itemName = uri.asEndpoint();
                if (producer) {
                    itemName = "[P] " + itemName;
                } else {
                    itemName = "[C] " + itemName;
                }
                var candidates:Array<Info> = [];
                for (item in list) {
                    if (Std.string(item.name).startsWith(itemName)) {
                        candidates.push({
                            name: item.name,
                            running: item.pid != 0
                        });
                    }
                }

                trace("candidates: for", uri.toString(), candidates, maxInstances);

                if (candidates.length == maxInstances) { // already enough, lets ensure running
                    trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> ALREADY ENOUGH LETS ENSURE RUNNING");
                    var listToRestart = [];
                    for (item in candidates) {
                        if (!item.running) {
                            listToRestart.push(item.name);
                        }
                    }
                    restartList(listToRestart, () -> {
                        resolve(true);
                    });
                } else if (candidates.length > maxInstances) { // too many lets remove some
                    trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> TOO MANY!!!!", candidates.length, maxInstances, prefixConfig.maxInstances, prefixConfig.bundle.name);
                    candidates.reverse();
                    var listToDelete = [];
                    while (candidates.length > maxInstances) {
                        listToDelete.push(candidates.pop().name);
                    }
                    //deleteList(listToDelete, () -> {
                    //    resolve(true);
                    //});
                    resolve(true);
                } else { // need to add more
                    trace("WE CAN ADD MORE!");
                    var listToRestart = [];
                    for (item in candidates) {
                        if (!item.running) {
                            listToRestart.push(item.name);
                        }
                    }

                    var listToStart = [];
                    for (i in 0...(maxInstances - candidates.length)) {
                        var type:String = "consumer";
                        if (producer) {
                            type = "producer";
                        }
                        var details:Dynamic = {
                            name: itemName + " [" + (candidates.length + i) + "]",
                            script: bundleFile,
                            args: [
                                "--json-config",
                                '{"type":"${type}","uri":"${uri.toString()}", "originalUri": "${originalUri.toString()}"}'
                            ],
                            watch: true
                        }
                        listToStart.push(details);
                    }
                    restartList(listToRestart, () -> {
                        startList(listToStart, () -> {
                            resolve(true);
                        });
                    });

                }
            });
            */

            Pm2.list((err, list) -> {
                var finalUri = uri.clone();
                // we'll flip round consumer / producer since its clearer when listing the bundles
                if (finalUri.prefix == "producer") {
                    finalUri.prefix = "consumer";
                } else if (finalUri.prefix == "consumer") {
                    finalUri.prefix = "producer";
                }
                var itemName = finalUri.asEndpoint();
                if (originalUri != null && uri.prefix != originalUri.prefix) {
                    itemName = originalUri.prefix + "-" + itemName;
                }
                /*
                if (producer) {
                    itemName = "[P] " + itemName;
                } else {
                    itemName = "[C] " + itemName;
                }
                */
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
                            '{"type":"${type}","uri":"${uri.toString()}", "originalUri": "${originalUri.toString()}"}'
                        ],
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

    private static function startList(list:Array<Dynamic>, cb:Void->Void) {
        if (list.length == 0) {
            cb();
            return;
        }

        var details = list.shift();
        log.info('endpoint ${details.name} doesnt exist, starting');
        Pm2.start(details, (err, app) -> {
            if (err != null) {
                trace(err);
                startList(list, cb);
            } else {
                startList(list, cb);
            }
        });
    }

    private static function restartList(list:Array<String>, cb:Void->Void) {
        if (list.length == 0) {
            cb();
            return;
        }

        var itemName = list.shift();
        log.info('endpoint ${itemName} exists but isnt running, restarting');
        Pm2.restart(itemName, (err, proc) -> {
            if (err != null) {
                trace(err);
                restartList(list, cb);
            } else {
                restartList(list, cb);
            }
        });
    }

    private static function deleteList(list:Array<String>, cb:Void->Void) {
        if (list.length == 0) {
            cb();
            return;
        }

        var itemName = list.shift();
        log.info('endpoint ${itemName} exists but isnt allowed, deleting');
        Pm2.delete(itemName, (err, proc) -> {
            if (err != null) {
                trace(err);
                deleteList(list, cb);
            } else {
                deleteList(list, cb);
            }
        });
    }
}

private typedef Info = {
    public var name:String;
    public var running:Bool;
}