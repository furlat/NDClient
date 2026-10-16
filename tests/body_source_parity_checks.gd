extends SceneTree
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Media=preload("res://presentation/media_warmup.gd")
const Characters=preload("res://presentation/characters.gd")
var Legacy:GDScript
var OldEncounter:GDScript
const Encounter=preload("res://presentation/encounter_media.gd")
const Catalog=preload("res://source_catalog.gd")
const Sources=preload("res://presentation/body_sources.gd")
var cache:Dictionary={};var legacy:Dictionary={};var checks:int=0;var failures:Array=[];var phases:Array=[]
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
func compare(actor:Dictionary)->void:
    var empty_loaded:Dictionary={};empty_loaded.make_read_only()
    var passive_owner:Dictionary={"index":Sources.index(cache),"loaded":empty_loaded};passive_owner.make_read_only()
    var passive_cache:Dictionary={Sources.KEY:passive_owner}
    var loaded_before:Dictionary=passive_cache[Sources.KEY].loaded
    var passive:Dictionary=Characters.structure(actor,passive_cache)
    check(passive.ok,"Passive constructor source selection succeeds: "+actor.name)
    check(is_same(loaded_before,passive_cache[Sources.KEY].loaded),"Constructor comparison admits no category metadata: "+actor.name)
    if passive.ok:
        for layer in passive.value.equipment_layers:
            check(layer.has("source_path") and not layer.has("source_ref"),"Constructor layer contains only passive source path: "+actor.name)
    var unknown_cache:Dictionary={}
    for source_path in Sources.index(cache).source_owners:
        check(Sources.descriptor(source_path,"body",passive_cache).is_empty(),"Unprepared sampling lookup returns no descriptor: "+actor.name)
        check(is_same(loaded_before,passive_cache[Sources.KEY].loaded),"Sampling lookup admits no category metadata: "+actor.name)
        check(Sources.descriptor(source_path,"body",unknown_cache).is_empty() and unknown_cache.is_empty(),"Sampling lookup cannot admit even an index: "+actor.name)
        break
    var id:String=Characters.rig_id(actor,cache)
    var rigs:Dictionary=Characters.rigs(cache)
    for weapon in ["melee","ranged"]:
        var sample:Dictionary=actor.duplicate();sample.visual_loadout=actor.visual_loadout.duplicate();sample.visual_loadout.active_weapon_set=weapon
        var old:Dictionary=Legacy.sheet_paths(sample,rigs[id].clips.keys(),legacy)
        var current:Dictionary=Characters.sheet_paths(sample,rigs[id].clips.keys(),cache)
        check(old.ok and current.ok,actor.name+" source success")
        for field in ["value","gpu_only","cpu_required","geometry_slots","normal_sets"]:check(old.get(field)==current.get(field),actor.name+"/"+weapon+"/"+field)
        var selected:Dictionary=Characters._select_layers(sample,rigs[id],id==Sources.index(cache).root_rig,cache)
        var oldselected:Dictionary=Legacy._select_layers(sample,Legacy._read("catalog/rigs.json",legacy)[id],id==Sources.index(cache).root_rig,legacy)
        var plain:Array=selected.value.duplicate(true)
        for layer in plain:layer.erase("source_ref");layer.erase("source_path")
        check(plain==oldselected.value,actor.name+" selected layer parity")
        for layer in selected.value:
            var resource=Sources.prepare_layer(layer.source_path,cache)
            check(resource!=null,actor.name+" explicitly admits selected category")
            if resource==null:continue
            for clip in resource.clips:
                var descriptor:Dictionary=resource.clips[clip].get(layer.slot,{})
                if descriptor.is_empty():continue
                var source:Dictionary=descriptor.geometry
                var oldgeometry:Dictionary=Legacy.CharacterGeometry.record(descriptor.path,layer.slot,legacy).duplicate()
                if not oldgeometry.is_empty() and not oldgeometry.has("optical_camera"):
                    oldgeometry.optical_camera=legacy[Legacy.CharacterGeometry.TABLE if descriptor.path.begins_with("/media/smallscale/modular/") else Legacy.CharacterGeometry.CREATURE_TABLE].get("optical_camera",{})
                if not oldgeometry.is_empty():oldgeometry._source_root=Legacy.CharacterGeometry._root(oldgeometry)
                check(source==oldgeometry,actor.name+"/"+clip+"/"+layer.slot+" geometry")
                var oldpaths:Dictionary=Legacy.CharacterGeometry.source_paths(descriptor.path,layer.slot,legacy)
                check(descriptor.companions==oldpaths.value,actor.name+"/"+clip+"/"+layer.slot+" optical paths")
                var oldnormals:Dictionary=Legacy.CharacterGeometry.normal_paths(descriptor.path,layer.slot,legacy).value
                for profile in ["original","gentle","reference"]:
                    var expected_roles:Dictionary={descriptor.path:[Legacy.Catalog.media_path(descriptor.path),1,0,0]}
                    for companion in oldpaths.value:
                        if companion not in oldnormals.values() or companion==oldnormals.get(profile):
                            expected_roles[companion]=[Legacy.Catalog.media_path(companion),0,0,0]
                    check(descriptor.source_records[profile].roles==expected_roles,actor.name+"/"+clip+"/"+layer.slot+"/"+profile+" exact source roles")
                if clip=="Idle":
                    check(Sources.header(descriptor.path,cache)==OldEncounter._png_size(Legacy.Catalog.media_path(descriptor.path)),actor.name+"/"+layer.slot+" imported original dimensions")
                if descriptor.sockets.get("valid",false):
                    var file:String="res://.derived/surface-sockets/"+str(source.get("media",descriptor.path)).trim_prefix("/media/").get_basename()+".json"
                    var baked:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
                    check(baked.size==descriptor.sockets.size and baked.samples==descriptor.sockets.samples,actor.name+"/"+clip+"/"+layer.slot+" exact socket bytes")
func run()->void:
    var root:String="";var legacy_path:String="";var encounter_path:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):root=argument.trim_prefix("--recording=").trim_suffix("/")+"/"
        if argument.begins_with("--characters-oracle="):legacy_path=argument.trim_prefix("--characters-oracle=")
        if argument.begins_with("--encounter-oracle="):encounter_path=argument.trim_prefix("--encounter-oracle=")
    if root.is_empty() or legacy_path.is_empty() or encounter_path.is_empty():
        printerr("Requires --recording, --characters-oracle and --encounter-oracle frozen pre-change source adapters");quit(2);return
    Legacy=load(legacy_path);OldEncounter=load(encounter_path)
    var protocol=Protocol.new()
    var initial:Dictionary=protocol.normalize("InitializationResponse",protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(root+"0000000000000000.json")).value)
    var state:Dictionary=Reducer.reduce_initialization(initial.initialization,initial.content_additions).value
    var seen:Dictionary={};var first:Dictionary={};Media._plan_sources({"key":[],"state":Media._snapshot(state),"groups":[]},first,cache)
    for sequence in range(0,7):
        for actor in state.actors.values():
            if not seen.has(actor.uuid):compare(actor);seen[actor.uuid]=true
        var oldfamily:Dictionary=OldEncounter.plan(state,{},{},legacy)
        var newfamily:Dictionary=Encounter.plan(state,{},{},cache)
        check(oldfamily.paths==newfamily.paths,"sequence%d optional physical paths"%sequence)
        check(oldfamily.cpu_required==newfamily.cpu_required,"sequence%d optional CPU roles"%sequence)
        check(oldfamily.gpu_only==newfamily.gpu_only,"sequence%d optional GPU roles"%sequence)
        check(oldfamily.priority==newfamily.priority,"sequence%d optional priority paths"%sequence)
        if sequence==6:break
        var packet:Dictionary=protocol.normalize("PlayerOperation",protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(root+"%016d.json"%(sequence+1))).value)
        var reduced:Dictionary=Reducer._reduce_operation_retained(state,packet,true)
        var started:int=Time.get_ticks_usec()
        var compile_loaded_before:Dictionary=cache[Sources.KEY].loaded
        var compiled:Dictionary=Compiler.compile_recorded(state,packet,cache,reduced.value,reduced.transitions)
        var compile_ms:float=(Time.get_ticks_usec()-started)/1000.0
        var compiler_admitted_layers:int=cache[Sources.KEY].loaded.size()-compile_loaded_before.size()
        check(is_same(compile_loaded_before,cache[Sources.KEY].loaded),"Actual operation compiler admits no category metadata: "+str(sequence+1))
        check(not cache.has("catalog/rigs.json"),"Actual operation compiler does not read legacy rig JSON: "+str(sequence+1))
        started=Time.get_ticks_usec()
        var opening:Dictionary=Media.prepare_opening_handoff(state,compiled.value.groups[0],cache) if not compiled.value.groups.is_empty() else {}
        var opening_ms:float=(Time.get_ticks_usec()-started)/1000.0
        var opening_records:Array=opening.get("value",{}).get("source_records",{}).get(compiled.value.groups[0].id,{}).get("reference",[]) if not compiled.value.groups.is_empty() else []
        var opening_entries:Array=cache.get("__required_actor_closures",{}).get("entries",[]).duplicate()
        started=Time.get_ticks_usec();var full:Dictionary=Media.prepare_handoff(state,compiled.value.groups,cache,reduced.value)
        var full_ms:float=(Time.get_ticks_usec()-started)/1000.0
        var full_records:Array=full.get("value",{}).get("source_records",{}).get(compiled.value.groups[0].id,{}).get("reference",[]) if not compiled.value.groups.is_empty() else []
        var kept_records:int=0;var added_roles:int=0;var removed_roles:int=0;var added_body_roles:int=0;var removed_body_roles:int=0;var added_environment_roles:int=0;var removed_environment_roles:int=0;var new_paths:Dictionary={};var old_paths:Dictionary={}
        for record in opening_records:
            old_paths.merge(record.roles)
            if full_records.any(func(current):return is_same(current,record)):kept_records+=1
            else:
                removed_roles+=record.roles.size()
                if str(record.get("source_id","")).begins_with("environment:"):removed_environment_roles+=record.roles.size()
                else:removed_body_roles+=record.roles.size()
        for record in full_records:
            new_paths.merge(record.roles)
            if not opening_records.any(func(current):return is_same(current,record)):
                added_roles+=record.roles.size()
                if str(record.get("source_id","")).begins_with("environment:"):added_environment_roles+=record.roles.size()
                else:added_body_roles+=record.roles.size()
        var changed_physical_roles:int=0
        for path in new_paths:
            if old_paths.get(path)!=new_paths[path]:changed_physical_roles+=1
        for path in old_paths:
            if not new_paths.has(path):changed_physical_roles+=1
        var entries:Array=cache.get("__required_actor_closures",{}).get("entries",[])
        var shared:int=0
        for prior in opening_entries:
            for current in entries:
                if is_same(prior.get("base"),current.get("base")):shared+=1;break
        phases.append({"sequence":sequence+1,"compiler_ms":compile_ms,"compiler_admitted_layers":compiler_admitted_layers,"opening_ms":opening_ms,"full_ms":full_ms,"opening_entries":opening_entries.size(),"full_entries":entries.size(),"retained_opening_bases":shared,"loaded_layers":cache[Sources.KEY].loaded.size(),"opening_contributions":opening_records.size(),"full_contributions":full_records.size(),"retained_contributions":kept_records,"added_contribution_roles":added_roles,"removed_contribution_roles":removed_roles,"actual_changed_physical_roles":changed_physical_roles,"added_body_roles":added_body_roles,"removed_body_roles":removed_body_roles,"added_environment_roles":added_environment_roles,"removed_environment_roles":removed_environment_roles})
        state=reduced.value
    var rigs:Dictionary=Characters.rigs(cache)
    var knights:Array=state.actors.values().filter(func(actor):return str(actor.name).begins_with("Gallery sentry"))
    var selectors:Array=[]
    for actor in knights:selectors.append(Media._actor_selector(actor,cache))
    for i in range(1,selectors.size()):
        check(selectors[0][1]==selectors[i][1],"Identical knight source identity ignores item/actor UUID%d"%i)
        var first_source:Dictionary=Characters.sheet_paths(knights[0],["Idle"],cache)
        var other:Dictionary=Characters.sheet_paths(knights[i],["Idle"],cache)
        var first_refs:Dictionary={}
        for record in first_source.source_records.reference:first_refs[record.source_id]=record
        for record in other.source_records.reference:
            check(is_same(first_refs.get(record.source_id),record),"Identical knights share actual role-record refs, not just matching paths")
    var shell:Dictionary=cache[Sources.KEY];var snapshot:Dictionary=Catalog.source_snapshot(cache)
    check(is_same(snapshot.get(Sources.KEY),shell),"Source snapshot shares immutable admission shell")
    check(shell.is_read_only() and shell.loaded.is_read_only(),"Admission shell and refs read-only")
    var report:Dictionary={"checks":checks,"failures":failures,"phases":phases,"unique_actors":seen.size(),"loaded_layers":cache[Sources.KEY].loaded.size(),"loaded_resources":cache[Sources.KEY].loaded.keys(),"scope":"Six actual admitted Gallery records; exact approved legacy path/roles/geometry/socket parity via saved pre-change resolver. Isolated CPU metadata timings only."}
    FileAccess.open("res://generated/body_source_parity_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
