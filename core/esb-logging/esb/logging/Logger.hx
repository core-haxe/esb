package esb.logging;

#if !esb_logging_impl

@:jsRequire("./esb-logging.js", "esb.logging.Logger")
extern class Logger {
    public function new(ref:String);
    public function info(message:String, data:Any = null):Void;
    public function warn(message:String, data:Any = null):Void;
    public function error(message:String, data:Any = null):Void;
    public function performance(message:String, data:Any = null):Void;
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
            logging.LogManager.instance.addAdaptor(new logging.adaptors.ConsoleLogAdaptor({
                levels: [logging.LogLevel.Info, logging.LogLevel.Warning, logging.LogLevel.Error, logging.LogLevel.Performance]
            }));
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
}

#end