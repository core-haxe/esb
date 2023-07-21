package esb.core.exchange.eip;

import esb.core.bodies.RawBody;
import esb.queues.QueueFactory;
import esb.common.Uuid;
import promises.Promise;
import queues.IQueue;
import promises.PromiseUtils.*;
import esb.logging.Logger;

@:keep
class InOut implements IExchangePattern {
    private static var log:Logger = new Logger("esb.core.exchange.eip.InOut");

    private var outputQ:IQueue<String> = null;
    private var responseQ:IQueue<String> = null;

    private var _correlationMap:Map<String, {resolve:Message<RawBody>->Void, reject:Any->Void}> = [];

    private var endpoint:String;
    private var producer:Bool = false;

    public function new(endpoint:String, producer:Bool = false) {
        this.endpoint = endpoint;
        this.producer = producer;
    }

    public function init():Promise<Bool> {
        return new Promise((resolve, reject) -> {
            initQueues().then(_ -> {
                resolve(true);
            }, error -> {
                reject(error);
            });
        });
    }

    public function sendMessage(message:Message<RawBody>):Promise<Message<RawBody>> {
        return new Promise((resolve, reject) -> {
            if (producer) {
                message.correlationId = Uuid.generate();
            }

            if (_correlationMap.exists(message.correlationId)) {
                trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> WARNING CORRELAION ALREADY EXISTS");
            }
            if (producer) {
                _correlationMap.set(message.correlationId, {resolve: resolve, reject: reject});
            }
            initQueues().then(success -> {
                var s = message.serialize();
                if (producer) {
                    log.info('sending message to output endpoint ${this.endpoint} (correlationId: ${message.correlationId})');
                    outputQ.enqueue(s);
                } else {
                    log.info('sending message to response endpoint ${this.endpoint} (correlationId: ${message.correlationId})');
                    responseQ.enqueue(s);
                    resolve(message);
                }
                return null;
            }, error -> {
                reject(error);
            });
        });
    }

    private function initQueues():Promise<Bool> {
        return new Promise((resolve, reject) -> {
            var promises = [];
            if (outputQ == null) {
                if (producer) {
                    var queueType = "rabbitmq-queue";
                    var queueConfig:Dynamic = {
                        brokerUrl: "amqp://localhost",
                        queueName: '${this.endpoint}',
                        producerOnly: producer
                    }
                    outputQ = QueueFactory.create(queueType, queueConfig);
                    promises.push(outputQ.start.bind());
                }
            }

            if (responseQ == null) {
                var queueType = "rabbitmq-queue";
                var queueConfig:Dynamic = {
                    brokerUrl: "amqp://localhost",
                    queueName: '${this.endpoint}-response',
                    producerOnly: !producer
                }
                responseQ = QueueFactory.create(queueType, queueConfig);
                promises.push(responseQ.start.bind());
            }

            runSequentially(promises).then(success -> {
                if (producer) {
                    responseQ.onMessage = onResponseMessage;
                }
                resolve(true);
            }, error -> {
                reject(error);
            });
        });
    }

    private function onResponseMessage(data:String):Promise<Bool> {
        return new Promise((resolve, reject) -> {
            var message = Bus.createMessage(RawBody);
            message.unserialize(data);
            var finalMessage = message;
            if (message.bodyType != Type.getClassName(Type.getClass(message.body))) {
                finalMessage = Bus.convertMessageUsingStringType(message, message.bodyType);
            }
            log.info('message received on response queue for ${this.endpoint} (correlationId: ${finalMessage.correlationId})');
            var info = _correlationMap.get(finalMessage.correlationId);
            if (info == null) {
                log.info("no correlation info");
                responseQ.requeue(data);
                resolve(true);
            } else {
                _correlationMap.remove(finalMessage.correlationId);
                info.resolve(finalMessage);
                resolve(true);
            }
        });
    }
}