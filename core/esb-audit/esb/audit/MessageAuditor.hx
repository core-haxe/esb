package esb.audit;

import esb.core.bodies.RawBody;
import esb.core.Message;

#if !esb_core_audit_impl

@:jsRequire("./esb-audit.js", "esb.audit.MessageAuditor")
extern class MessageAuditor {
    public static function audit(message:Message<RawBody>):Void;
}

#else

@:expose
@:native("esb.audit.MessageAuditor")
class MessageAuditor {
    public static function audit(message:Message<RawBody>) {
        trace("-----------------------------------------------------------------------------------");
        trace(message);
        if (message.body == null) {
            trace("body is null");
        } else {
            trace(message.body.toString());
        }
        trace(message.headers);
        trace(message.properties);
        trace("HASH: ", message.hash());
        trace("BODY HASH: ", message.bodyHash());
        trace("-----------------------------------------------------------------------------------");
    }
}

#end