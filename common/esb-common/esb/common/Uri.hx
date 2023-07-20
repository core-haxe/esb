package esb.common;

@:forward
@:forward.new
abstract Uri(UriObject) {
    @:from public static function fromString(s:String):Uri {
        return new Uri(s);
    }
}