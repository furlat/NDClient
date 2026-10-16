extends SceneTree
# Effective native authoring only; no images, scene actors, GPU or live session.
const Catalog=preload("res://source_catalog.gd")
const NativeSpell=preload("res://presentation/native_spell_authoring.gd")
const Characters=preload("res://presentation/characters.gd")
const Journal=preload("res://sdk/journal.gd")
func stamp(path:String)->Dictionary:
    var file=FileAccess.open(path,FileAccess.READ)
    return {"mtime":FileAccess.get_modified_time(path),"size":file.get_length()} if file!=null else {}
func socket_banks(value:Variant,result:Array)->void:
    if value is Dictionary:
        for key in value:
            if key=="sourceSockets":result.append({"rig":"","sockets":value[key]})
            elif key=="sourceSocketsByRig":
                for rig in value[key]:result.append({"rig":rig,"sockets":value[key][rig]})
            else:socket_banks(value[key],result)
    elif value is Array:
        for item in value:socket_banks(item,result)
func _initialize()->void:
    var output="res://.derived/surface-socket-inputs.json"
    var journal_path=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
        elif argument.begins_with("--journal="):journal_path=argument.trim_prefix("--journal=")
    var cache={}
    var rigs:Dictionary=Catalog.read_file("catalog/rigs.json",cache)
    var resources:Dictionary=Catalog.read_file("catalog/resources.json",cache)
    var index:Dictionary=Catalog.read_file("catalog-index.json",cache)
    var components:Dictionary=Catalog.read_file(index.sheet_components,cache)
    var spells=[]
    for behavior in index.drafts:
        var recipe:Dictionary=NativeSpell.recipe({"behavior_id":behavior},cache)
        if recipe.is_empty():continue
        var banks=[];socket_banks(recipe,banks)
        if not banks.is_empty():spells.append({"behavior":behavior,"cast":recipe.get("cast",{}),"banks":banks})
    var gallery_sources={}
    if not journal_path.is_empty():
        var journal=Journal.new();var opened:Dictionary=journal.open(journal_path,true,false)
        if not opened.ok:printerr(opened);quit(1);return
        var replay:Dictionary=journal.replay(0)
        if not replay.ok:printerr(replay);quit(1);return
        for actor in journal.state.actors.values():
            var rig=Characters.rig_id(actor,cache)
            for weapon_set in ["melee","ranged"]:
                var variant:Dictionary=actor.duplicate(true)
                variant.visual_loadout.active_weapon_set=weapon_set
                var paths:Dictionary=Characters.sheet_paths(variant,rigs[rig].clips.keys(),cache)
                if not paths.ok:printerr(paths);quit(1);return
                gallery_sources.merge(paths.cpu_required)
    var inputs={}
    for key in cache:
        if not key is String:continue
        var path:String=key.trim_prefix("native_resource:") if key.begins_with("native_resource:") else ("res://authoring/"+key if key.ends_with(".json") and not key.begins_with("res://") else key)
        if FileAccess.file_exists(path):inputs[path]=stamp(path)
    # The baker reads optical records directly. Runtime material binding in
    # character_geometry.gd does not produce its pixel coordinates or bytes.
    for path in ["res://source_catalog.gd","res://presentation/native_authoring.gd","res://presentation/native_spell_authoring.gd","res://presentation/spell_feedback.gd","res://presentation/authoring.gd","res://generated/character_geometry.json","res://generated/creature_geometry.json","res://tools/export_surface_socket_inputs.gd","res://tools/bake_surface_socket_samples.py"]:
        if FileAccess.file_exists(path):inputs[path]=stamp(path)
    var errors:Array=cache.get("native_authoring_errors",[])
    if not errors.is_empty():printerr(errors);quit(1);return
    var roots={}
    for name in ["character_geometry_root","creature_geometry_root","media_root"]:roots[name]=ProjectSettings.get_setting("source_data/"+name)
    DirAccess.make_dir_recursive_absolute(output.get_base_dir())
    FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"schema":1,"rigs":rigs,"resources":resources,"sheet_components":components,"spells":spells,"authoring_inputs":inputs,"roots":roots,"gallery_sources":gallery_sources.keys()}))
    print("SURFACE_SOCKET_EXPORT rigs=",rigs.size()," spells=",spells.size()," gallery_sources=",gallery_sources.size()," inputs=",inputs.size())
    quit()
