package esb.logging;

#if !esb_logging_impl

@:jsRequire("./esb-logging.js", "esb.logging.Logger")
extern class Logger {
    public function new(ref:String);
    public function info(message:String, data:Any = null):Void;
    public function warn(message:String, data:Any = null):Void;
    public function error(message:String, data:Any = null):Void;
    public function performance(message:String, data:Any = null):Void;
    public function debug(message:String, data:Any = null):Void;
}

#else

@:expose
@:native("esb.logging.Logger")
class Logger {
    private var _logger:logging.Logger;

    private static var _configured:Bool = false;
    public function new(ref:String) {
        if (!_configured) {
            _configured = true;
            var defaultConfig = esb.core.config.sections.EsbConfig.get().logging.adaptors.get("default");
            if (defaultConfig != null) {
                var adaptor = adaptorFromConfig(defaultConfig);
                if (adaptor != null) {
                    logging.LogManager.instance.addAdaptor(adaptor);
                } else {
                    logging.LogManager.instance.addAdaptor(new logging.adaptors.ConsoleLogAdaptor({
                        levels: [logging.LogLevel.Info, logging.LogLevel.Warning, logging.LogLevel.Error, logging.LogLevel.Performance, logging.LogLevel.Debug]
                    }));
                }
            } else {
                logging.LogManager.instance.addAdaptor(new logging.adaptors.ConsoleLogAdaptor({
                    levels: [logging.LogLevel.Info, logging.LogLevel.Warning, logging.LogLevel.Error, logging.LogLevel.Performance, logging.LogLevel.Debug]
                }));
            }
        }
        _logger = new logging.Logger(null, StringTools.rpad(ref, " ", 40));
    }

    public function info(message:String, data:Any = null) {
        _logger.info(message, data);
    }

    public function warn(message:String, data:Any = null) {
        _logger.warn(message, data);
    }

    public function error(message:String, data:Any = null) {
        _logger.error(message, data);
    }

    public function performance(message:String, data:Any = null) {
        _logger.performance(message, data);
    }

    public function debug(message:String, data:Any = null) {
        _logger.debug(message, data);
    }

    private function adaptorFromConfig(config:esb.core.config.sections.LoggingAdaptorConfig):logging.ILogAdaptor {
        var adaptor:logging.ILogAdaptor = null;

        var levels = convertConfigLogLevels(config.levels);
        switch (config.className) {
            case "logging.adaptors.ConsoleLogAdaptor" | "console":
                adaptor = new logging.adaptors.ConsoleLogAdaptor({
                    levels: levels
                });
        }

        return adaptor;
    }

    private function convertConfigLogLevels(configLevels:Array<String>):Array<logging.LogLevel> {
        if (configLevels == null) {
            return [];
        }

        var levels = [];
        for (item in configLevels) {
            item = StringTools.trim(item.toLowerCase());
            switch (item) {
                case "info": levels.push(logging.LogLevel.Info);
                case "warning": levels.push(logging.LogLevel.Warning);
                case "error": levels.push(logging.LogLevel.Error);
                case "performance": levels.push(logging.LogLevel.Performance);
                case "debug": levels.push(logging.LogLevel.Debug);
            }
        }

        return levels;
    }
}

#end