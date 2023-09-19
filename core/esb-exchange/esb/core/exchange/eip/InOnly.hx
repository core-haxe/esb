package esb.core.exchange.eip;

import esb.core.bodies.RawBody;
import esb.queues.QueueFactory;
import esb.common.Uuid;
import promises.Promise;
import queues.IQueue;
import promises.PromiseUtils.*;
import esb.logging.Logger;

@:keep
class InOnly implements IExchangePattern {
    private static var log:Logger = new Logger("esb.core.exchange.eip.InOnly");

    private var outputQ:IQueue<String> = null;

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
                initQueues().then(success -> {
                    var s = message.serialize();
                    if (esb.core.config.sections.EsbConfig.get().logging.verbose) {
                        log.debug('sending message to output endpoint ${this.endpoint} (correlationId: ${message.correlationId})');
                    }
                    outputQ.enqueue(s);
                    resolve(message);
                }, error -> {
                    reject(error);
                });
            } else {
                resolve(message);
            }
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

            runSequentially(promises).then(success -> {
                resolve(true);
            }, error -> {
                reject(error);
            });
        });
    }
}