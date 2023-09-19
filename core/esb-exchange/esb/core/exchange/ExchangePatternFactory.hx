package esb.core.exchange;

import promises.Promise;

#if !esb_exchange_impl

@:jsRequire("./esb-exchange.js", "esb.core.exchange.ExchangePatternFactory")
extern class ExchangePatternFactory {
    public static function create(endpoint:String, producer:Bool, eip:String = null):Promise<IExchangePattern>;
}

#else

@:expose
@:native("esb.core.exchange.ExchangePatternFactory")
class ExchangePatternFactory {
    private static var useCache:Bool = true;
    private static var _cache:Map<String, IExchangePattern> = [];
    private static var _initializingMap:Map<String, Array<{resolve: Dynamic, reject: Dynamic}>> = [];

    public static function create(endpoint:String, producer:Bool, eip:String = null):Promise<IExchangePattern> {
        return new Promise((resolve, reject) -> {
            if (eip == null) {
                eip = "inout";
            }
            eip = eip.toLowerCase();
    
            if (!useCache) {
                var exchange:IExchangePattern = createExchangePattern(eip, endpoint, producer);
                exchange.init().then(_ -> {
                    resolve(exchange);
                    return null;
                }, error -> {
                    trace("error", error);
                });
            } else {
                var cacheKey = endpoint + "_" + eip + "_" + (producer == true ? "producer" : "consumer");
                if (_initializingMap.exists(cacheKey)) {
                    _initializingMap.get(cacheKey).push({resolve: resolve, reject: reject});
                    return;
                }
                var exchange:IExchangePattern = _cache.get(cacheKey);
                if (exchange == null) {
                    _initializingMap.set(cacheKey, []);
                    exchange = createExchangePattern(eip, endpoint, producer);
                    exchange.init().then(_ -> {
                        for (details in _initializingMap.get(cacheKey)) {
                            details.resolve(exchange);
                        }
                        _initializingMap.remove(cacheKey);
                        _cache.set(cacheKey, exchange);
                        resolve(exchange);
                        return null;
                    }, error -> {
                        trace("error", error);
                    });
                } else {
                    resolve(exchange);
                }
            }
        });
    }

    private static function createExchangePattern(eip:String, endpoint:String, producer:Bool):IExchangePattern {
        return switch (eip) {
            case "inout":   new esb.core.exchange.eip.InOut(endpoint, producer);
            case "inonly":  new esb.core.exchange.eip.InOnly(endpoint, producer);
            case _:         new esb.core.exchange.eip.InOut(endpoint, producer);
        }
    }
}

#end