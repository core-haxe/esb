package esb.core.ipc;

import esb.common.Uuid;
import promises.Promise;
#if !esb_ipc_impl

@:jsRequire("./esb-ipc.js", "esb.core.ipc.Channel")
extern class Channel {
    public function new(id:String, server:Bool = false);
    public function start(onMessage:String->Dynamic->Promise<Dynamic> = null):Promise<Bool>;
    public function send(message:String, payload:Dynamic):Promise<Dynamic>;
}

#else

@:expose
@:native("esb.core.ipc.Channel")
class Channel {
    private var id:String = null;
    private var server:Bool = false;
    private var client:Dynamic = null;
    private var responseMap:Map<String, {resolve: Dynamic, reject:Dynamic}> = [];

    public function new(id:String, server:Bool = false) {
        this.id = id;
        this.server = server;
    }

    public function start(onMessage:String->Dynamic->Promise<Dynamic> = null):Promise<Bool> {
        if (server) {
            return startServer(onMessage);
        }
        return startClient(onMessage);
    }

    public function send(message:String, payload:Dynamic):Promise<Dynamic> {
        return new Promise((resolve, reject) -> {
            var messageId:String = esb.common.Uuid.generate();
            responseMap.set(messageId, {resolve: resolve, reject: reject});
            client.emit("message", haxe.Json.stringify({
                messageId: messageId,
                message: message,
                payload: payload
            }));
        });
    }

    private function startServer(onMessage:String->Dynamic->Promise<Dynamic> = null):Promise<Bool> {
        return new Promise((resolve, reject) -> {
            esb.core.ipc.externs.NodeIPC.config.id = id;
            esb.core.ipc.externs.NodeIPC.config.retry = 100;
            esb.core.ipc.externs.NodeIPC.config.silent = true;
        
            esb.core.ipc.externs.NodeIPC.serve(() -> {
                esb.core.ipc.externs.NodeIPC.server.on("message", (data, socket) -> {
                    var json = haxe.Json.parse(data);
                    var messageId = json.messageId;
                    var message = json.message;
                    var payload = json.payload;
                    if (onMessage != null) {
                        onMessage(message, payload).then(responsePayload -> {
                            esb.core.ipc.externs.NodeIPC.server.emit(socket, "message", haxe.Json.stringify({
                                messageId: messageId,
                                responsePayload: responsePayload
                            }));
                        }, error -> {
                            trace(">>>>>>>>>>>>>>>>>>>>>> ERROR, ", error);
                        });
                    }
                });
                esb.core.ipc.externs.NodeIPC.server.on("socket.disconnected", (socket, destroyedSocketID) -> {
                    trace("SOCKET DESTROYED");
                });
                resolve(true);
            });
            esb.core.ipc.externs.NodeIPC.server.start();
        });
    }

    private function startClient(onMessage:String->Dynamic->Promise<Dynamic> = null) {
        return new Promise((resolve, reject) -> {
            esb.core.ipc.externs.NodeIPC.config.id = id + "-client" + "-" + Uuid.generate();
            esb.core.ipc.externs.NodeIPC.config.retry = 100;
            esb.core.ipc.externs.NodeIPC.config.silent = true;
        
            esb.core.ipc.externs.NodeIPC.connectTo(id, () -> {
                client = Reflect.field(esb.core.ipc.externs.NodeIPC.of, id);
                client.on("connect", () -> {
                    resolve(true);
                });
                client.on("disconnect", () -> {
                    //trace("CLIENT DISCONNECTED");
                });
                client.on("message", (data) -> {
                    var json = haxe.Json.parse(data);
                    var messageId = json.messageId;
                    if (responseMap.exists(messageId)) {
                        var details = responseMap.get(messageId);
                        details.resolve(json.responsePayload);
                        responseMap.remove(messageId);
                    } else {
                        trace("NO RESPONSE IN MAP FOR", messageId);
                    }
                });
            });
        });
    }
}

#end