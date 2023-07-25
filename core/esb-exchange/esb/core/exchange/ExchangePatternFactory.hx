package esb.core.exchange;

import promises.Promise;

#if !esb_exchange_impl

@:jsRequire("./esb-exchange.js", "esb.core.exchange.ExchangePatternFactory")
extern class ExchangePatternFactory {
    public static function create(endpoint:String, producer:Bool):Promise<IExchangePattern>;
}

#else

@:expose
@:native("esb.core.exchange.ExchangePatternFactory")
class ExchangePatternFactory {
    private static var useCache:Bool = true;
    private static var _cache:Map<String, IExchangePattern> = [];
    private static var _initializingMap:Map<String, Array<{resolve: Dynamic, reject: Dynamic}>> = [];

    public static function create(endpoint:String, producer:Bool):Promise<IExchangePattern> {
        return new Promise((resolve, reject) -> {
            var eip = "InOut";

            if (!useCache) {
                var exchange:IExchangePattern = new esb.core.exchange.eip.InOut(endpoint, producer);
                exchange.init().then(_ -> {
                    resolve(exchange);
                    return null;
                }, error -> {

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
                    exchange = new esb.core.exchange.eip.InOut(endpoint, producer);
                    exchange.init().then(_ -> {
                        for (details in _initializingMap.get(cacheKey)) {
                            details.resolve(exchange);
                        }
                        _initializingMap.remove(cacheKey);
                        _cache.set(cacheKey, exchange);
                        resolve(exchange);
                        return null;
                    }, error -> {

                    });
                } else {
                    resolve(exchange);
                }
            }
        });
    }
}

#end