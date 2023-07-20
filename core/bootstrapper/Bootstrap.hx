package;

#if !esb_bundle_manager_impl

class Bootstrap {
}

#else

import esb.core.BundleManager;

class Bootstrap {
    public static function main() {
        bootstrap();
    }

    public static function bootstrap() {
        BundleManager.start().then(_ -> {
            return BundleManager.autostartBundles();
        }).then(result -> {
            return BundleManager.autostopBundles();
        }).then(result -> {
        }, error -> {
            trace("error", error);
        });
    }
}

#end