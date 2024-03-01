package esb.core;

import esb.core.bodies.XmlBody;
import esb.core.bodies.CsvBody;
import esb.core.bodies.StringBody;
import esb.core.bodies.JsonBody;
import esb.core.bodies.MultiBody;
import esb.common.Uri;
import promises.Promise;
import esb.core.bodies.RawBody;

using StringTools;

#if !esb_core_impl

@:jsRequire("./esb-core.js", "esb.core.Bus")
extern class Bus {
    public static function from(uri:Uri, callback:Uri->Message<RawBody>->Promise<Message<RawBody>>):Void;
    public static function registerDirectConsumer(uri:Uri, callback:Uri->Message<RawBody>->Promise<Message<RawBody>>):Void;
    public static function to(uri:Uri, message:Message<RawBody>):Promise<Message<RawBody>>;

    public static function registerMessageType<T:RawBody>(bodyType:Class<T>, ctor:Void->Message<T>):Void;
    public static function createMessage<T:RawBody>(bodyType:Class<T>):Message<T>;
    public static function copyMessage<T:RawBody>(message:Message<RawBody>, bodyType:Class<T>):Message<T>;
    public static function convertMessage<T:RawBody>(message:Message<RawBody>, bodyType:Class<T>, applyBody:Bool = true):Message<T>;
    public static function canConvertMessage<T:RawBody>(message:Message<RawBody>, bodyType:Class<T>):Bool;
    public static function convertMessageUsingStringType<T:RawBody>(message:Message<RawBody>, bodyType:String, applyBody:Bool = true):Message<T>;
    public static function convertBody<T:RawBody>(body:RawBody, bodyType:Class<T>, applyBody:Bool = true):T;
    public static function registerBodyConverter<T1:RawBody, T2:RawBody>(from:Class<T1>, to:Class<T2>, fn:T1->T2):Void;
    public static function isMessageBody(object:Dynamic):Bool;
}

#else

@:expose
@:native("esb.core.Bus")
@:access(esb.core.Message)
class Bus {
    private static var log:esb.logging.Logger = new esb.logging.Logger("esb.core.Bus");

    public static function from(uri:Uri, callback:Uri->Message<RawBody>->Promise<Message<RawBody>>) {
        registerInternalMessageTypes();
        BundleLoader.autoLoadBundles();

        var effectiveUri = uri.clone();
        var bundlePrefixConfig = esb.core.config.sections.EsbConfig.get().findPrefix(uri.prefix, true);
        if (bundlePrefixConfig != null && bundlePrefixConfig.uri != null) {
            effectiveUri = Uri.fromString(bundlePrefixConfig.uri);
            effectiveUri.params = uri.params;
            effectiveUri.replacePlaceholdersWith(uri);
        }
        if (effectiveUri.prefix != "consumer" && effectiveUri.prefix != "producer") {
            effectiveUri.prefix = "producer";
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
                    log.debug('message received on "${endpoint}", passing to consumer');
                    return new Promise((resolve, reject) -> {
                        try {
                            var message = createMessage(RawBody);
                            message.unserialize(data);
                            message.properties.set(BusProperties.SourceUri, uri.toString());
                            var finalMessage = message;
                            if (message.bodyType != Type.getClassName(Type.getClass(message.body))) {
                                finalMessage = convertMessageUsingStringType(message, message.bodyType);
                            }
                            var destUri = uri;
                            if (message.properties.exists(BusProperties.DestinationUri)) {
                                destUri = Uri.fromString(message.properties.get(BusProperties.DestinationUri));
                            }
                            auditMessage(finalMessage, ["audit.from.direction" => "request"]);
                            var eip = finalMessage.properties.get("bus.eip");
                            callback(destUri, finalMessage).then(result -> {
                                auditMessage(result, ["audit.from.direction" => "response"]);
                                esb.core.exchange.ExchangePatternFactory.create(endpoint, false, eip).then(exchangePattern -> {
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

    private static var directUriConsumers:Map<String, Uri->Message<RawBody>->Promise<Message<RawBody>>> = [];
    public static function registerDirectConsumer(uri:Uri, callback:Uri->Message<RawBody>->Promise<Message<RawBody>>) {
        var key = uri.asEndpoint();
        log.info('registering direct consumer ${key}');
        directUriConsumers.set(key, callback);
    }

    public static function to(uri:Uri, message:Message<RawBody>):Promise<Message<RawBody>> {
        registerInternalMessageTypes();
        BundleLoader.autoLoadBundles();

        if (!message.properties.exists(Message.PropertyMessageId)) {
            message.properties.set(Message.PropertyMessageId, esb.common.Uuid.generate());
        }
        if (message.breacrumbs().length == 0) {
            message.addBreadcrumb();
        }

        return new Promise((resolve, reject) -> {
            var effectiveUri = uri.clone();
            message.properties.set(BusProperties.DestinationUri, uri.toString());
            var bundlePrefixConfig = esb.core.config.sections.EsbConfig.get().findPrefix(uri.prefix, false);
            if (bundlePrefixConfig != null && bundlePrefixConfig.uri != null) {
                effectiveUri = Uri.fromString(bundlePrefixConfig.uri);
                effectiveUri.params = uri.params;
                effectiveUri.replacePlaceholdersWith(uri);
            }
            if (effectiveUri.prefix != "consumer" && effectiveUri.prefix != "producer") {
                effectiveUri.prefix = "consumer";
            }

            message = copyMessage(message, Type.getClass(message.body));
            var eip = message.properties.get("bus.eip");
            auditMessage(message, ["audit.to.direction" => "request"]);

            var directConsumerKey = uri.asEndpoint();
            var directConsumer = directUriConsumers.get(directConsumerKey);
            if (directConsumer != null) {
                log.debug('sending direct message to ${directConsumerKey}');
                var correlationId = message.correlationId;
                directConsumer(uri, message).then(response -> {
                    log.debug('response message received from direct endpoint ${directConsumerKey}');
                    if (correlationId != null) {
                        response.correlationId = correlationId;
                    }
                    resolve(response);
                }, error -> {
                    reject(error);
                });
            } else {
                BundleManager.startEndpoint(effectiveUri, false, uri).then(_ -> {
                    var endpoint = effectiveUri.asEndpoint();
                    esb.core.exchange.ExchangePatternFactory.create(endpoint, true, eip).then(exchangePattern -> {
                        var correlationId = message.correlationId;
                        exchangePattern.sendMessage(message).then(response -> {
                            auditMessage(response, ["audit.to.direction" => "response"]);
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
            }
        });
    }

    private static function auditMessage(message:Message<RawBody>, properties:Map<String, Any> = null) {
        if (message.properties.exists("audit.skip") && message.properties.get("audit.skip") == true) {
            return;
        }

        var copy = copyMessage(message, Type.getClass(message.body));
        copy.timestamp();
        if (properties != null) {
            for (key in properties.keys()) {
                copy.properties.set(key, properties.get(key));
            }
        }
        var bundleFile:String = js.node.Path.basename(js.Syntax.code("require.main.filename"));
        bundleFile = haxe.io.Path.normalize(bundleFile).split("/").pop().split(".").shift();
        copy.properties.set("audit.bundle", bundleFile);

        esb.audit.MessageAuditor.audit(copy);
    }

    private static var messageTypes:Map<String, Void->Message<RawBody>> = [];
    public static function registerMessageType<T:RawBody>(bodyType:Class<T>, ctor:Void->Message<T>) {
        var name = Type.getClassName(bodyType);
        log.debug('registering message type: ${name}');
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

    public static function copyMessage<T:RawBody>(message:Message<RawBody>, bodyType:Class<T>):Message<T> {
        registerInternalMessageTypes();
        var newMessage = new Message<RawBody>();
        newMessage.body = new RawBody();
        var toType = Type.getClassName(bodyType);
        if (messageTypes.exists(toType)) {
            var fn = messageTypes.get(toType);
            newMessage = fn();
            newMessage.bodyType = toType;
        } else {
            log.warn('could not create message of type "${toType}", no type registered, using raw');
        }

        newMessage.correlationId = message.correlationId;
        newMessage.headers = message.headers.copy();
        newMessage.properties = message.properties.copy();
        if (message.body != null) {
            newMessage.body.fromBytes(message.body.toBytes());
        }

        return cast newMessage;
    }

    public static function convertMessage<T:RawBody>(message:Message<RawBody>, bodyType:Class<T>, applyBody:Bool = true):Message<T> {
        registerInternalMessageTypes();
        var newMessage = new Message<RawBody>();
        newMessage.body = new RawBody();
        var fromType = Type.getClassName(Type.getClass(message.body));
        var toType = Type.getClassName(bodyType);
        if (fromType == toType) {
            return cast message;
        }

        if (messageTypes.exists(toType)) {
            var fn = messageTypes.get(toType);
            newMessage = fn();
            newMessage.bodyType = toType;
        } else {
            log.warn('could not convert message of type "${toType}", no type registered, using raw');
        }
    
        newMessage.correlationId = message.correlationId;
        newMessage.headers = message.headers.copy();
        newMessage.properties = message.properties.copy();

        if (applyBody) {
            var key = fromType + "_to_" + toType;
            if (bodyConverters.exists(key)) {
                var fn = bodyConverters.get(key);
                newMessage.body = fn(message.body);
            } else {
                newMessage.body.fromBytes(message.body.toBytes());
            }
        }

        if (esb.core.config.sections.EsbConfig.get().logging.verbose) {
            log.debug('converted message type from "${fromType}" to "${toType}"');
        }
        return cast newMessage;
    }

    public static function canConvertMessage<T:RawBody>(message:Message<RawBody>, bodyType:Class<T>):Bool {
        registerInternalMessageTypes();
        var className = Type.getClassName(bodyType);
        if (messageTypes.exists(className)) {
            if (esb.core.config.sections.EsbConfig.get().logging.verbose) {
                log.debug('conversion to "${className}" is possibe');
            }
            return true;
        }
        if (esb.core.config.sections.EsbConfig.get().logging.verbose) {
            log.debug('conversion to "${className}" is NOT possibe');
        }
        return false;
    }

    public static function convertMessageUsingStringType<T:RawBody>(message:Message<RawBody>, bodyType:String, applyBody:Bool = true):Message<T> {
        registerInternalMessageTypes();
        var fromType = Type.getClassName(Type.getClass(message.body));
        var toType = bodyType;
        if (fromType == toType) {
            return cast message;
        }

        var newMessage = new Message<RawBody>();
        newMessage.body = new RawBody();
        if (messageTypes.exists(toType)) {
            var fn = messageTypes.get(toType);
            newMessage = fn();
            newMessage.bodyType = toType;
        } else {
            log.warn('could not convert message of type "${toType}", no type registered, using raw');
        }
    
        newMessage.correlationId = message.correlationId;
        newMessage.headers = message.headers.copy();
        newMessage.properties = message.properties.copy();

        if (applyBody) {
            var key = fromType + "_to_" + toType;
            if (bodyConverters.exists(key)) {
                var fn = bodyConverters.get(key);
                newMessage.body = fn(message.body);
            } else {
                newMessage.body.fromBytes(message.body.toBytes());
            }
        }

        if (esb.core.config.sections.EsbConfig.get().logging.verbose) {
            log.debug('converted message type from "${fromType}" to "${toType}"');
        }
        return cast newMessage;

    }

    public static function convertBody<T:RawBody>(body:RawBody, bodyType:Class<T>, applyBody:Bool = true):T {
        registerInternalMessageTypes();
        var fromType = Type.getClassName(Type.getClass(body));
        var toType = Type.getClassName(bodyType);
        if (fromType == toType) {
            return cast body;
        }

        var newMessage = new Message<RawBody>();
        newMessage.body = new RawBody();
        if (messageTypes.exists(toType)) {
            var fn = messageTypes.get(toType);
            newMessage = fn();
            newMessage.bodyType = toType;
        } else {
            log.warn('could not convert message of type "${toType}", no type registered, using raw');
        }

        var newBody:T = cast newMessage.body;
        if (applyBody) {
            var key = fromType + "_to_" + toType;
            if (bodyConverters.exists(key)) {
                var fn = bodyConverters.get(key);
                newBody = cast fn(body);
            } else {
                newBody.fromBytes(body.toBytes());
            }
        }

        return newBody;
    }

    public static function isMessageBody(object:Any):Bool {
        var className = Type.getClassName(Type.getClass(object));
        return messageTypes.exists(className);
    }

    private static var bodyConverters:Map<String, RawBody->RawBody> = [];
    public static function registerBodyConverter<T1:RawBody, T2:RawBody>(from:Class<T1>, to:Class<T2>, fn:T1->T2) {
        var fromName = Type.getClassName(from);
        var toName = Type.getClassName(to);
        log.debug('registering body converter: ${fromName} => ${toName}');
        var key = fromName + "_to_" + toName;
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

        registerMessageType(CsvBody, () -> {
            var m = new Message<CsvBody>();
            m.body = new CsvBody();
            return m;
        });

        registerMessageType(XmlBody, () -> {
            var m = new Message<XmlBody>();
            m.body = new XmlBody();
            return m;
        });

        registerMessageType(MultiBody, () -> {
            var m = new Message<MultiBody>();
            m.body = new MultiBody();
            return m;
        });

        registerBodyConverter(CsvBody, JsonBody, CsvBody.toJson);
        registerBodyConverter(CsvBody, XmlBody, CsvBody.toXml);

        registerBodyConverter(JsonBody, CsvBody, JsonBody.toCsv);
        registerBodyConverter(JsonBody, XmlBody, JsonBody.toXml);

        registerBodyConverter(MultiBody, XmlBody, MultiBody.toXml);
    }    
}

#end