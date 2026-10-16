extends SceneTree
const Import=preload("res://tools/native_spell_import.gd")
func _initialize()->void:
    var started:int=Time.get_ticks_usec()
    var result:Dictionary=Import.import_all()
    result.elapsed_ms=(Time.get_ticks_usec()-started)/1000.0
    DirAccess.make_dir_recursive_absolute("res://.runtime")
    FileAccess.open("res://.runtime/native-spell-import.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("NATIVE_PRESENTATION_IMPORT spells=",result.spells.size()," assets=",result.assets.size()," failures=",JSON.stringify(result.failures)," elapsed_ms=",result.elapsed_ms)
    quit(0 if result.failures.is_empty() else 1)
