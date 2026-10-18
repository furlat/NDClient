extends SceneTree
## A condition lifecycle that fails to warm must not hold the game's loading:
## it is reported in background_errors and readiness continues. A required
## spell source that fails still blocks (its cue would otherwise draw nothing).
const NativeStartup=preload("res://presentation/native_source_startup.gd")
var checks:=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("NATIVE_STARTUP_FAIL ",label)

func run()->void:
    var lifecycle={"key":"","clip":{"id":"conditions/retained/shield/sustain"},"lifecycle":true}
    var spell={"key":"","clip":{"id":"spells/fire_bolt/default/travel"},"lifecycle":false}
    var plan=[lifecycle,spell]
    NativeStartup._state={"plan":plan,"done":{NativeStartup._key(spell.clip):true},
        "failures":{NativeStartup._key(lifecycle.clip):"lifecycle build failed"},"ready":false,"started":Time.get_ticks_usec()}
    var status=NativeStartup.status({"plan":plan,"required":plan})
    check(status.ready,"a failed lifecycle warm-up does not hold readiness")
    check(status.errors.is_empty(),"a failed lifecycle is not a blocking error")
    check(status.background_errors.has("lifecycle build failed"),"a failed lifecycle is still reported")
    NativeStartup._state={"plan":plan,"done":{NativeStartup._key(lifecycle.clip):true},
        "failures":{NativeStartup._key(spell.clip):"spell build failed"},"ready":false,"started":Time.get_ticks_usec()}
    status=NativeStartup.status({"plan":plan,"required":plan})
    check(not status.ready and status.errors.has("spell build failed"),"a failed required spell source still blocks and is reported")
    NativeStartup._state={}
    var report={"checks":checks,"failures":failures}
    print("NATIVE_STARTUP_LIFECYCLE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
