package esb.core.exchange;

import esb.core.bodies.RawBody;
import promises.Promise;

interface IExchangePattern {
    public function sendMessage(message:Message<RawBody>):Promise<Message<RawBody>>;
    public function init():Promise<Bool>;
}