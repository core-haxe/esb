package esb.queues;

import queues.IQueue;
import promises.Promise;

#if !esb_queues_impl

@:jsRequire("./esb-queues.js", "esb.queues.QueueFactory")
extern class QueueFactory {
    public static function create<T>(type:String, config:Dynamic):IQueue<T>;
}

#else

@:expose
@:native("esb.queues.QueueFactory")
class QueueFactory {
    public static function create<T>(type:String, config:Dynamic):IQueue<T> {
        return queues.QueueFactory.instance.createQueue(type, config);
    }
}

#end