package esb.core;

import esb.core.bodies.StringBody;
import esb.core.bodies.JsonBody;
import esb.common.Uri;
import promises.Promise;
import esb.core.bodies.RawBody;

using StringTools;

#if !esb_core_impl

@:jsRequire("./esb-core.js", "esb.core.Bus")
extern class Bus {
    public static function from(uri:Uri, callback:Message<RawBody>->Promise<Message<RawBody>>):Void;
    public static function to(uri:Uri, message:Message<RawBody>):Promise<Message<RawBody>>;

    public static function registerMessageType<T:RawBody>(bodyType:Class<T>, ctor:Void->Message<T>):Void;
    public static function createMessage<T:RawBody>(bodyType:Class<T>):Message<T>;
    public static function convertMessage<T:RawBody>(message:Message<RawBody>, bodyType:Class<T>):Message<T>;
    public static function registerBodyConverter<T1:RawBody, T2:RawBody>(from:Class<T1>, to:Class<T2>, fn:T1->T2):Void;
}

#else

@:expose
@:native("esb.core.Bus")
@:access(esb.core.Message)
class Bus {
    private static var log:esb.logging.Logger = new esb.logging.Logger("esb.core.Bus");

    public static function from(uri:Uri, callback:Message<RawBody>->Promise<Message<RawBody>>) {
        var effectiveUri = uri.clone();
        var bundlePrefixConfig = esb.core.config.sections.EsbConfig.get().findPrefix(uri.prefix, true);
        if (bundlePrefixConfig != null && bundlePrefixConfig.uri != null) {
            effectiveUri = Uri.fromString(bundlePrefixConfig.uri);
            effectiveUri.params = uri.params;
            // TODO: temp
            if (effectiveUri.path.contains("{port}")) {
                var port = uri.path.split(":").pop();
                effectiveUri.path = effectiveUri.path.replace("{port}", port);
            }
        }
    
        BundleManager.startEndpoint(effectiveUri, true, uri).then(_ -> {
            var endpoint = effectiveUri.asEndpoint();
            var queueType = "rabbitmq-queue";
            var queueConfig:Dynamic = {
                brokerUrl: "amqp://localhost",
                queueName: '${endpoint}'
            }
            var fromQ:queues.IQueue<String> = esb.queues.QueueFactory.create(queueType, queueConfig);
            fromQ.start().then(_ -> {
                log.info('waiting for messages on "${endpoint}"');
                fromQ.onMessage = (data:String) -> {
                    log.info('message received on "${endpoint}", passing to consumer');
                    return new Promise((resolve, reject) -> {
                        try {
                            var message = createMessage(RawBody);
                            message.properties.set(BusProperties.SourceUri, uri.toString());
                            message.unserialize(data);
                            callback(message).then(result -> {
                                esb.core.exchange.ExchangePatternFactory.create(endpoint, false).then(exchangePattern -> {
                                    exchangePattern.sendMessage(result).then(_ -> {
                                        resolve(true);
                                    }, error -> {
                                        reject(error);
                                    });
                                }, error -> {
                                    reject(error);
                                });
                            }, error -> {
                                trace("error", error);
                                reject(error);
                            });
                        } catch (e:Dynamic) {
                            trace("------------------>", e);
                            reject(e);
                        }
                    });
                }
                return null;
            }, error -> {
                trace("error");
                trace("error", error);
            });
        }, error -> {
            trace(error, error);
        });
    }

    public static function to(uri:Uri, message:Message<RawBody>):Promise<Message<RawBody>> {
        return new Promise((resolve, reject) -> {
            var effectiveUri = uri.clone();
            message.properties.set(BusProperties.DestinationUri, uri.toString());
            var bundlePrefixConfig = esb.core.config.sections.EsbConfig.get().findPrefix(uri.prefix, false);
            if (bundlePrefixConfig != null && bundlePrefixConfig.uri != null) {
                effectiveUri = Uri.fromString(bundlePrefixConfig.uri);
                effectiveUri.params = uri.params;
            }

            BundleManager.startEndpoint(effectiveUri, false, uri).then(_ -> {
                var endpoint = effectiveUri.asEndpoint();
                esb.core.exchange.ExchangePatternFactory.create(endpoint, true).then(exchangePattern -> {
                    var correlationId = message.correlationId;
                    exchangePattern.sendMessage(message).then(response -> {
                        if (correlationId != null) {
                            response.correlationId = correlationId;
                        }
                        resolve(response);
                    }, error -> {
                        reject(error);
                    });
                }, error -> {
                    reject(error);
                });
            }, error -> {
                trace("error", error);
                reject(error);
            });
        });
    }

    private static var messageTypes:Map<String, Void->Message<RawBody>> = [];
    public static function registerMessageType<T:RawBody>(bodyType:Class<T>, ctor:Void->Message<T>) {
        var name = Type.getClassName(bodyType);
        messageTypes.set(name, cast ctor);
    }

    public static function createMessage<T:RawBody>(bodyType:Class<T>):Message<T> {
        registerInternalMessageTypes();
        var className = Type.getClassName(bodyType);
        if (!messageTypes.exists(className)) {
            log.warn('could not create message of type "${className}", no type registered, using raw');
            var m = new Message<RawBody>();
            m.body = new RawBody();
            return cast m;
        }

        var fn = messageTypes.get(className);
        var m = fn();
        return cast m;
    }

    public static function convertMessage<T:RawBody>(message:Message<RawBody>, bodyType:Class<T>):Message<T> {
        var newMessage = new Message<RawBody>();
        newMessage.body = new RawBody();
        var className = Type.getClassName(bodyType);
        if (messageTypes.exists(className)) {
            var fn = messageTypes.get(className);
            newMessage = fn();
        } else {
            log.warn('could not convert message of type "${className}", no type registered, using raw');
        }
    
        newMessage.correlationId = message.correlationId;
        newMessage.headers = message.headers;
        newMessage.properties = message.properties;

        var key = Type.getClassName(Type.getClass(message.body)) + "_to_" + Type.getClassName(Type.getClass(newMessage.body));
        if (bodyConverters.exists(key)) {
            var fn = bodyConverters.get(key);
            newMessage.body = fn(message.body);
        } else {
            newMessage.body.fromBytes(message.body.toBytes());
        }

        return cast newMessage;
    }

    private static var bodyConverters:Map<String, RawBody->RawBody> = [];
    public static function registerBodyConverter<T1:RawBody, T2:RawBody>(from:Class<T1>, to:Class<T2>, fn:T1->T2) {
        var key = Type.getClassName(from) + "_to_" + Type.getClassName(to);
        trace(key);
        bodyConverters.set(key, cast fn);
    }

    private static var internalMessageTypesRegistered:Bool = false;
    private static function registerInternalMessageTypes() {
        if (internalMessageTypesRegistered) {
            return;
        }
        internalMessageTypesRegistered = true;

        registerMessageType(JsonBody, () -> {
            var m = new Message<JsonBody>();
            m.body = new JsonBody();
            return m;
        });

        registerMessageType(RawBody, () -> {
            var m = new Message<RawBody>();
            m.body = new RawBody();
            return m;
        });

        registerMessageType(StringBody, () -> {
            var m = new Message<StringBody>();
            m.body = new StringBody();
            return m;
        });
    }    
}

#end