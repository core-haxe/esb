package;

import esb.core.config.ConfigParser;

class Test {
    static function main() {
        #if esb_config_impl

        /*
        var c = ConfigParser.fromFile("example.json");

        for (bundleName in c.bundles.keys()) {
            trace(bundleName);
            var bundle = c.bundles.get(bundleName);
            for (prefixName in bundle.prefixes.keys()) {
                trace("    " + prefixName, bundle.name);
                trace("    " + bundle.prefixes.get(prefixName).consumer.className);
                trace("    " + bundle.prefixes.get(prefixName).producer.className);
            }
        }

        trace(c.findPrefix("http", true).bundle.bundleFile);

        for (propName in c.findPrefix("file", false).bundle.properties.keys()) {
            trace(propName + " = " + c.findPrefix("file", false).bundle.properties.get(propName));
        }
        for (propName in c.properties.keys()) {
            trace(propName + " = " + c.properties.get(propName));
        }

        for (queueType in c.queues.keys()) {
            var queueConfig = c.queues.get(queueType);
            trace(queueType, queueConfig.isDefault);
            trace(queueConfig.consumer.className);
            trace(queueConfig.consumer.properties.get("queueName"));
            trace(queueConfig.producer.className);
            trace(queueConfig.producer.properties.get("queueName", ["endpoint" => "bob"]));
            trace(queueConfig.producer.properties.get("brokerUrl"));
        }
        */

        #end
    }
}