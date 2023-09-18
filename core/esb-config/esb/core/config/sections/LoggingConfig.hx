package esb.core.config.sections;

class LoggingConfig {
    public var verbose:Bool;
    @:default(new Map<String, esb.core.config.sections.LoggingAdaptorConfig>())
    public var adaptors:Map<String, LoggingAdaptorConfig>;

    public function new() {
    }
}