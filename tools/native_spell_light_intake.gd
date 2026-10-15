extends SceneTree
const Factory=preload("res://presentation/native_factory_source.gd")
const Bounds=preload("res://presentation/native_source_bounds.gd")

func _initialize()->void:run.call_deferred()

func plain(value:Variant)->Variant:
    if value is Color:return [value.r,value.g,value.b,value.a]
    if value is Vector3:return [value.x,value.y,value.z]
    if value is Quaternion:return [value.x,value.y,value.z,value.w]
    if value is Vector2:return [value.x,value.y]
    return value if value is float or value is int or value is bool or value is String else var_to_str(value)

func source_visible(light:Node3D,source:Node3D)->bool:
    var node:Node=light
    while node!=source:
        if node is Node3D and not node.visible:return false
        node=node.get_parent()
    return true

func run()->void:
    var owner=Node3D.new();root.add_child(owner)
    var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/projectiles.json"))
    var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/native_effects/index.json"))
    var selected:Array=index.spells.values().map(func(value):return value.id)
    var report={"scope":"Exact selected Factory source bounds, Light3D nodes, native Animation tracks and source-clock samples; no optical/gameplay inference","clips":[],"errors":[]}
    for spell in manifest.spells:
        if spell.id not in selected:continue
        for clip in spell.clips:
            var handle=Factory.make(owner,clip.duplicate(true))
            if not handle.error.is_empty():report.errors.append(handle.error)
            var emitters:Array=Bounds.emitters(handle)
            # This headless intake samples lights/animation metadata, not trail
            # geometry. Trail callbacks enqueue renderer work and are qualified
            # separately in native playback; no geometry is needed here.
            handle.scripts.clear();handle.motion_trails.clear()
            var row={"id":clip.id,"spell_id":spell.id,"recipe":clip.get("source_recipe",""),"bindings":clip.bindings,"lights":[],"tracks":[],"samples":[],
                "animation_end":handle.native_animation_end,"particle_tail":0.0,"animations":[],"emitters":[]}
            row.emitters=emitters
            for emitter in emitters:
                if emitter.layer_enabled:row.particle_tail=maxf(row.particle_tail,emitter.tail_seconds)
            var lights:Array=handle.root.find_children("*","Light3D",true,false)
            for light in lights:
                row.lights.append({"path":str(handle.root.get_path_to(light)),"node_type":light.get_class(),"position":plain(light.position),"source_position":plain(handle.root.to_local(light.global_position)),"visible":source_visible(light,handle.root),"energy":light.light_energy,"color":plain(light.light_color),"range":light.omni_range if light is OmniLight3D else null,"attenuation":light.omni_attenuation if light is OmniLight3D else null})
            for player in handle.players:
                var base:Node=player.get_node(player.root_node)
                for animation_name in player.get_animation_list():
                    var animation:Animation=player.get_animation(animation_name)
                    row.animations.append({"player":str(handle.root.get_path_to(player)),"animation":animation_name,"active":animation_name==player.current_animation,"length":animation.length,"loop_mode":animation.loop_mode})
                    for track in animation.get_track_count():
                        var path:NodePath=animation.track_get_path(track)
                        var node:Node=base.get_node_or_null(NodePath(path.get_concatenated_names()))
                        if node==null:continue
                        var affected:Array=[]
                        for light in lights:
                            if node==light or node.is_ancestor_of(light):affected.append(str(handle.root.get_path_to(light)))
                        if affected.is_empty():continue
                        var keys:Array=[]
                        for key in animation.track_get_key_count(track):keys.append({"time":animation.track_get_key_time(track,key),"value":plain(animation.track_get_key_value(track,key)),"transition":animation.track_get_key_transition(track,key)})
                        row.tracks.append({"player":str(handle.root.get_path_to(player)),"animation":animation_name,"active_animation":animation_name==player.current_animation,"path":str(path),"type":animation.track_get_type(track),"interpolation":animation.track_get_interpolation_type(track),"update_mode":animation.value_track_get_update_mode(track) if animation.track_get_type(track)==Animation.TYPE_VALUE else null,"enabled":animation.track_is_enabled(track),"affected_lights":affected,"keys":keys})
            for at in [0.0,.1,.2,.4,.6,.8,1.0]:
                Factory.sample(handle,at,0.0)
                var values:Array=[]
                for light in lights:values.append({"path":str(handle.root.get_path_to(light)),"source_position":plain(handle.root.to_local(light.global_position)),"visible":source_visible(light,handle.root),"energy":light.light_energy,"color":plain(light.light_color),"range":light.omni_range if light is OmniLight3D else null})
                row.samples.append({"source_seconds":at,"lights":values})
            report.clips.append(row)
            var bounds={"animation_end":row.animation_end,"particle_tail":row.particle_tail,"emitters":row.emitters,"lights":[]}
            for light in row.lights:
                var annotated:Dictionary=light.duplicate(true)
                annotated.tracks=row.tracks.filter(func(track):return light.path in track.affected_lights)
                annotated.bindings=clip.bindings
                bounds.lights.append(annotated)
            for entry in index.spells.values():
                if entry.id!=spell.id:continue
                if not entry.has("source_bounds"):entry.source_bounds={}
                entry.source_bounds[clip.id]=bounds
            Factory.close(handle)
            # Source construction can queue particle/renderer retirement work.
            # Drain it between independent clips instead of stacking all72
            # owners' teardown into the final process-exit frame.
            await process_frame
    if "--write-index" in OS.get_cmdline_user_args() and report.errors.is_empty():
        FileAccess.open("res://authoring/native_effects/index.json",FileAccess.WRITE).store_string(JSON.stringify(index,"  "))
    FileAccess.open("res://.runtime/native-spell-light-inventory.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    FileAccess.open("res://.runtime/native-spell-light-intake.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_LIGHT_INVENTORY ",JSON.stringify({"clips":report.clips.size(),"errors":report.errors}))
    owner.free()
    quit(0 if report.errors.is_empty() and not report.clips.is_empty() else 1)
