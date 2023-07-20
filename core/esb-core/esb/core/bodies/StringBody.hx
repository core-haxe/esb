package esb.core.bodies;

#if !esb_core_impl

@:jsRequire("./esb-core.js", "esb.core.bodies.StringBody")
extern class StringBody extends RawBody {
}

#else

@:keep
@:keepInit
@:keepSub
@:expose
@:native("esb.core.bodies.StringBody")
class StringBody extends RawBody {
}

#end