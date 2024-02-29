package esb.audit;

import esb.core.bodies.RawBody;
import esb.core.Message;
import esb.core.Bus.*;

@:expose
@:native("esb.audit.MessageAuditor")
class MessageAuditor {
    public static function audit(message:Message<RawBody>) {
        /*
        if (message.properties.exists("audit.skip") && message.properties.get("audit.skip") == true) {
            return;
        }
        var copy = copyMessage(message, RawBody);
        var newProperties:Map<String, Any> = [];
        for (key in copy.properties.keys()) {
            newProperties.set("$$" + key + "$$", copy.properties.get(key));
        }
        copy.properties = newProperties;
        copy.properties.set("audit.skip", true);
        copy.properties.set("bus.eip", "InOnly");
        to("audit-db://impact-esb", copy);
        */
    }
}
