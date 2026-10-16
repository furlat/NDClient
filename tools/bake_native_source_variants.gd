extends SceneTree
## Offline preparation of the selected native donor resources. Does not sample
## source time, change art, or store particle simulations.
const Verification=preload("res://tools/native_variant_verification.gd")
const Variants=preload("res://presentation/native_source_variants.gd")
const Factory=preload("res://presentation/native_factory_source.gd")
const Resources=preload("res://assets/native_effects/sandbox/projectiles/factory/core/resource_graph.gd")
var failures:Array=[]
var rows:Array=[]
func _initialize()->void:run.call_deferred()
func run()->void:
    create_timer(180).timeout.connect(func():printerr("Variant bake deadline");quit(2))
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(320,240)
    var only:PackedStringArray=[];var verify_only:bool=false
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--only="):only=argument.trim_prefix("--only=").split(",")
        if argument=="--verify-only":verify_only=true
    var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/projectiles.json"))
    var index:Dictionary={}
    if FileAccess.file_exists(Variants.DIRECTORY.path_join("index.json")):index=JSON.parse_string(FileAccess.get_file_as_string(Variants.DIRECTORY.path_join("index.json")))
    DirAccess.make_dir_recursive_absolute(Variants.DIRECTORY)
    var owner=Node3D.new();owner.hide();root.add_child(owner)
    var started:int=Time.get_ticks_usec();var seen:Dictionary={}
    for spell in manifest.spells:
        if not only.is_empty() and spell.id not in only:continue
        for clip in spell.clips:
            for raw_spec in clip.components:
                var spec:Dictionary=Variants.component_spec(raw_spec,clip)
                var identity:String=Variants.key(spec)
                if seen.has(identity):continue
                seen[identity]=true
                if not Variants.supported(spec):
                    rows.append({"source":clip.id,"script":spec.script,"status":"unsupported_original_adapter"});continue
                if verify_only:
                    var admitted:Dictionary=Verification.verify(spec)
                    while admitted.pending:
                        await process_frame
                        admitted=Verification.verify(spec)
                    rows.append({"source":clip.id,"status":"valid" if admitted.error.is_empty() else "invalid"})
                    if not admitted.error.is_empty():failures.append(admitted.error)
                    continue
                var begin:int=Time.get_ticks_usec()
                var script:Script=load(spec.script)
                var component:Node3D=script.make_component(Factory._constructor_input(spec))
                if component==null:failures.append("Constructor failed: "+clip.id);continue
                component.name=spec.id
                for binding in spec.get("material_bindings",[]):
                    component.get_node(binding.node).set_surface_override_material(int(binding.surface),load(binding.resource).duplicate(true))
                for binding in spec.get("animation_bindings",[]):
                    var player:AnimationPlayer=component.get_node(binding.node)
                    var library:AnimationLibrary=player.get_animation_library(binding.library).duplicate(true)
                    library.remove_animation(binding.animation)
                    var animation:Animation=load(binding.resource).duplicate(true)
                    if binding.has("length_seconds"):animation.length=float(binding.length_seconds)
                    for track in animation.get_track_count():
                        if str(animation.track_get_path(track)) in binding.get("disabled_tracks",[]):animation.track_set_enabled(track,false)
                    library.add_animation(binding.animation,animation)
                    player.remove_animation_library(binding.library);player.add_animation_library(binding.library,library)
                if spec.script.ends_with("/native_scene_effect.gd"):Resources.isolate_node(component,{"share_shader_programs":true})
                owner.add_child(component)
                # No frame occurs between original _ready and resource capture.
                var prepared:Dictionary=Variants.bake(component,spec)
                var error:Error=OK
                if prepared.error.is_empty():
                    error=ResourceSaver.save(prepared.packet,Variants.path_for(spec),ResourceSaver.FLAG_COMPRESS)
                    if error==OK:index[identity]={"source":clip.id,"dependencies":prepared.packet.dependencies,"path":Variants.path_for(spec)}
                if not prepared.error.is_empty() or error!=OK:failures.append(prepared.error if not prepared.error.is_empty() else "Save failed: "+str(error))
                rows.append({"source":clip.id,"script":spec.script,"status":"saved" if error==OK and prepared.error.is_empty() else "failed","prepare_save_ms":(Time.get_ticks_usec()-begin)/1000.0,"nodes":component.find_children("*","",true,false).size()+1,"bytes":FileAccess.open(Variants.path_for(spec),FileAccess.READ).get_length() if FileAccess.file_exists(Variants.path_for(spec)) else 0})
                print("NATIVE_VARIANT ",JSON.stringify(rows.back()))
                component.free()
                await process_frame
    if not verify_only:FileAccess.open(Variants.DIRECTORY.path_join("index.json"),FileAccess.WRITE).store_string(JSON.stringify(index,"  "))
    owner.queue_free();await process_frame
    var report={"scope":"Offline exact prepared donor resources. Original source samplers remain runtime owners. Not a native framebuffer qualification.","verify_only":verify_only,"rows":rows,"failures":failures,"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0}
    FileAccess.open("res://.runtime/native-source-variant-bake"+("-verify" if verify_only else "")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_VARIANT_COMPLETE ",rows.size()," failures=",failures)
    quit(0 if failures.is_empty() else 1)
