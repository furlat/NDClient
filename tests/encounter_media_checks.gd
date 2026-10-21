extends SceneTree
## Independent typed-authoring closure plus actual original PNG publication.
## Native texture assertions require the manifest's GPU lane.
const Media=preload("res://presentation/media_warmup.gd")
const Encounter=preload("res://presentation/encounter_media.gd")
const EnvironmentMedia=preload("res://presentation/environment_media.gd")
const Characters=preload("res://presentation/characters.gd")
const Catalog=preload("res://source_catalog.gd")
const Journal=preload("res://sdk/journal.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
var checks:int=0
var failures:Array=[]
var source_root:Resource
var appearance:Resource
var entries:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("ENCOUNTER_MEDIA_FAIL ",label)
func entry(section:String,id:String)->Resource:
    var path:String=source_root.sections[section][id]
    if not entries.has(path):entries[path]=load(path)
    return entries[path]
func raw_layers(actor:Dictionary,state:Dictionary,set_name:String)->Dictionary:
    var selected:Dictionary={"body":actor.appearance.body_category}
    if actor.appearance.head_category!=null:selected.head=actor.appearance.head_category
    if actor.appearance.has_beard:selected.beard=appearance.flag_parts.has_beard
    for layer in actor.visual_loadout.layers:
        if not appearance.equipment_slots.has(layer.slot):continue
        if appearance.weapon_sets.has(layer.slot) and appearance.weapon_sets[layer.slot]!=set_name:continue
        var item:Dictionary=layer.duplicate();item.merge(state.items.get(layer.item_uuid,{}).get("look",{}),true)
        if item.get("equipped_visual_policy")=="hidden":continue
        var gear:Resource=entry("gear",str(item.item_id))
        if not gear.family.is_empty():gear=entry("gear",gear.family)
        var slot:String=appearance.equipment_slots[layer.slot]
        var variant:Variant=item.get("visual_variant_id")
        var hand_key:String="" if variant==null else str(variant)
        var rows:Array=[]
        if gear.hands.get(slot,{}).has(hand_key):rows=gear.hands[slot][hand_key]
        else:
            var look:Dictionary=gear.slots.get(slot,{})
            check(not look.is_empty(),"Actual gear has raw authored slot "+str(item.item_id)+"/"+slot)
            if look.is_empty():continue
            rows=look.layers if variant==null else look.get("variants",{}).get(variant,[])
            check(not rows.is_empty(),"Actual visual variant has raw authored layers "+str(item.item_id))
        for row in rows:
            if row.slot not in appearance.effect_slots:selected[row.slot]=row.part
    return selected
func add_art(paths:Dictionary,path:String,surface:Resource,geometry:bool,profile:String,modular:bool)->void:
    if not path.is_empty():paths["res://assets/"+path]=true
    if not geometry or surface==null or surface.encoding=="none":return
    # These are the exact authored receiving inputs: no source selector,
    # built descriptor, or runtime companion planner is its own oracle.
    for value in [surface.depth,surface.normals.original,surface.masks.get("support",""),surface.masks.get("normal_valid","")]:
        if not value.is_empty():paths["res://assets/"+value]=true
    for name in surface.normals:
        if modular and not profile.is_empty() and name!=profile:
            paths.erase("res://assets/"+surface.normals[name]);continue
        paths["res://assets/"+surface.normals[name]]=true
func expected(state:Dictionary,environment:Dictionary,profile:String)->Dictionary:
    var result:Dictionary=environment.duplicate()
    for actor in state.actors.values():
        if actor.get("last_visual_position")==null:continue
        check(actor.life_state=="alive" and actor.conditions.is_empty(),"Actual initial actor has ordinary idle source semantics")
        var rig:Resource=entry("rigs",appearance.rig) if actor.creature_content_ref==null else entry("rigs",entry("characters",actor.creature_content_ref.content_id).rig)
        if rig.kind!="layered":
            for clip in rig.clips:
                add_art(result,clip.art.body,clip.surface,true,profile,false)
            continue
        for set_name in ["melee","ranged"]:
            var layers:Dictionary=raw_layers(actor,state,set_name)
            for slot in layers:
                var part:Resource=entry("parts",layers[slot])
                for clip in rig.clips:
                    if set_name!=actor.visual_loadout.active_weapon_set and clip.name!="Idle":continue
                    if not part.actions.has(clip.source_clip):continue
                    var art:Resource=part.actions[clip.source_clip]
                    add_art(result,art.path,art.surface,slot in part.slots,profile,true)
    return result
func settle(data:Dictionary)->void:
    var owner:Dictionary=Media.physical(data)
    var deadline:int=Time.get_ticks_msec()+10000
    while Time.get_ticks_msec()<deadline:
        Media.prepare_optional(data)
        if not Media._families_pending(owner) and owner.changed_paths.is_empty() and owner.selection_task<0 \
            and (owner.selection_publication.is_empty() or owner.selection_publication.cursor==owner.selection_publication.paths.size()) \
            and owner.selection_applied_revision==owner.selection_revision:return
        await process_frame
    check(false,"Current bounded physical source owner finishes optional metadata admission")
func loaded(data:Dictionary)->Dictionary:
    var deadline:int=Time.get_ticks_msec()+20000
    while Time.get_ticks_msec()<deadline:
        var value:Dictionary=Media.poll(data)
        if not value.is_empty():return value
        await process_frame
    check(false,"Actual original source worker completes");return {}
func accounting(data:Dictionary,label:String)->void:
    var owner:Dictionary=Media.physical(data)
    for category in [false,true]:
        var cpu:int=0;var gpu:int=0;var pins:int=0;var sheets:int=0;var pending:int=0
        for path in owner.resident:
            var row:Dictionary=owner.resident[path]
            if row.environment!=category:continue
            cpu+=int(row.cpu_bytes);gpu+=int(row.gpu_bytes);sheets+=1
            if owner.wanted.has(path) or owner.preload_selected.has(path):
                pins+=int(row.gpu_bytes)
                if owner.interests.get(path,[0,0,0])[2]>0:pins+=int(row.cpu_bytes)
        for request in owner.pending:
            if (owner.interests.get(request.path,[0,0,0,0,0])[4]>0)==category:pending+=1
        for job in owner.decode_jobs:
            for path in job.get("paths",[job.path]):
                if (owner.interests.get(path,[0,0,0,0,0])[4]>0)==category:pending+=1
        var actual:Dictionary=Media.diagnostics(data,category)
        check(actual.cpu_bytes==cpu and actual.gpu_estimated_bytes==gpu and actual.resident_sheets==sheets \
            and actual.pinned_bytes==pins and actual.pending==pending,label+" independent physical byte/pin/queue accounting "+str(category))
func run()->void:
    source_root=load("res://authoring/characters.tres");appearance=entry("appearance","modular")
    # Original immutable fixtures use their exact stored native16 contract;
    # live decode_server intentionally admits only the current producer.
    var journal:RefCounted=Journal.new()
    var directory:String=Fixtures.journal("door","amber")
    var opened:Dictionary=journal.open(directory,true,false)
    check(opened.ok,"Original Door journal admits its exact stored producer contract: "+str(opened.get("error","")))
    if not opened.ok:finish({});return
    var packet:Dictionary=journal.decode_record(0,FileAccess.get_file_as_bytes(directory.path_join("0000000000000000.json")))
    check(packet.ok,"Original schema16 Door initialization decodes without rewriting packets")
    if not packet.ok:finish({});return
    var reduced:Dictionary=Reducer.reduce_initialization(packet.value.initialization,packet.value.content_additions)
    check(reduced.ok,"Actual initialization reduces through canonical SDK")
    if not reduced.ok:finish({});return
    var state:Dictionary=reduced.value;var original:PackedByteArray=var_to_bytes(state);var cache:Dictionary={}
    var surrounding:Dictionary=EnvironmentMedia.plan(state,[],cache)
    var default_plan:Dictionary={}
    for profile in ["reference","gentle","original"]:
        var plan:Dictionary=Encounter.plan(state,surrounding.disclosed,surrounding.fixtures,cache,[],profile)
        var want:Dictionary=expected(state,surrounding.disclosed,profile)
        var absent:Array=want.keys().filter(func(path):return not plan.paths.has(path))
        var extra:Array=plan.paths.keys().filter(func(path):return not want.has(path))
        if not absent.is_empty() or not extra.is_empty():printerr("ENCOUNTER_CLOSURE_DIFF ",profile," missing=",absent," extra=",extra)
        check(plan.errors.is_empty() and plan.paths.keys().all(func(path):return want.has(path)) and want.keys().all(func(path):return plan.paths.has(path)),"Full exact source closure agrees with independent typed categories/gear/rig clips and selected "+profile+" normals")
        if profile=="reference":default_plan=plan
    check(var_to_bytes(state)==original,"Optional source planning never mutates canonical actors/items")
    var actors:Array=state.actors.values().filter(func(actor):return actor.get("last_visual_position")!=null)
    check(actors.size()>=2,"Actual recording has two independently disclosed outfits")
    if actors.size()>=2:
        var one:Dictionary=state.duplicate();one.actors={actors[0].uuid:actors[0]}
        var before:Dictionary=Encounter.plan(one,{},{},{},[],"reference")
        var future:Dictionary={"id":"received-existing-outfit","actor_tracks":[],"commits":[],"staged_actors":{actors[1].uuid:actors[1]}}
        var after:Dictionary=Encounter.plan(one,{},{},{},[future],"reference")
        var received:Dictionary=one.duplicate();received.actors=one.actors.duplicate();received.actors[actors[1].uuid]=actors[1]
        var want:Dictionary=expected(received,{},"reference")
        check(want.keys().all(func(path):return after.paths.has(path)) and after.paths.keys().all(func(path):return want.has(path)),"Already-received outfit prepares its exact raw-authored family")
        check(one.actors.size()==1 and not one.actors.has(actors[1].uuid) and after.paths.size()>=before.paths.size(),"Preparation publishes neither a future actor nor a fabricated source")
    if "--closure-only" not in OS.get_cmdline_user_args():await png_publication(state)
    finish({"known_unique_sources":default_plan.get("paths",{}).size(),"native":DisplayServer.get_name()!="headless",
        "scope":"Independent current typed source closure and original PNG/texture/publication/role/budget boundaries. Native pixel ownership requires GPU default invocation; --closure-only checks no artwork or texture allocation."})
func png_publication(state:Dictionary)->void:
    check(DisplayServer.get_name()!="headless","The actual texture/alpha gate runs on its native GPU lane")
    if DisplayServer.get_name()=="headless":return
    var actor:Dictionary=state.actors.values().filter(func(row):return row.creature_content_ref==null and row.get("last_visual_position")!=null)[0]
    var part:Resource=entry("parts",actor.appearance.body_category)
    var art:Resource=part.actions.Idle
    var colour:String="res://assets/"+art.path
    var companion:String="res://assets/"+art.surface.depth
    var later:String="res://assets/"+part.actions.TakeDamage.path
    var paths:Dictionary={colour:Catalog.media_path(colour),companion:Catalog.media_path(companion)}
    var gpu:Dictionary={companion:true};var cpu:Dictionary={colour:true}
    var cache:Dictionary={};var sizes:Dictionary=Encounter.estimates(paths,cpu,gpu,cache)
    var family:Dictionary={"paths":paths,"cpu_required":cpu,"gpu_only":gpu,"estimates":sizes}
    var data:Dictionary=Media.create();data.budget_bytes=int(sizes[colour].bytes)+int(sizes[companion].bytes)
    Media.adopt_required(data,1);Media.adopt_encounter(data,family,1)
    Media.demand_records(data,[Media.source_record({colour:paths[colour]},{},{},{},{colour:true})]);await settle(data)
    check(Media.physical(data).pending[0].path==colour and not Media.boot_ready(data),"Required original precedes its optional geometry; unpublished bytes cannot start play")
    var decoded:Dictionary=await loaded(data)
    check(decoded.has("image") and decoded.path==colour,"Worker decodes the exact raw-authored original colour first")
    if not decoded.has("image"):Media.close(data);return
    var independent:Image=Image.load_from_file(paths[colour])
    var bytes:PackedByteArray=independent.get_data()
    check(decoded.image.get_data()==bytes,"Worker image preserves independently loaded original colour and alpha bytes")
    var texture:Texture2D=ImageTexture.create_from_image(decoded.image)
    check(texture.get_image().get_data()==bytes,"Actual native texture upload preserves original source pixels and alpha")
    Media.published(data,decoded);accounting(data,"Original publication")
    check(Media.ready(data,{colour:true}) and Media.boot_ready(data) and not Media.ready(data,{companion:true}),"Original required receipt starts play while its optional companion remains unavailable")
    var geometry:Dictionary=await loaded(data)
    check(geometry.has("image") and geometry.path==companion,"Optional geometry worker uses its exact original physical source")
    if not geometry.has("image"):Media.close(data);return
    check(not Media.ready(data,{companion:true}),"Decoded but unpublished geometry does not grant render readiness")
    var geometry_texture:Texture2D=ImageTexture.create_from_image(geometry.image)
    check(geometry_texture.get_image().get_data()==geometry.image.get_data(),"Native geometry texture retains exact original bytes")
    Media.published(data,geometry)
    check(Media.release_cold_images(data,-1)==[companion] and Media.ready(data,{companion:true}),"Never-CPU-used GPU companion releases its decode copy without losing actual residency")
    accounting(data,"Companion CPU release")
    var count:int=Media.physical(data).decoded
    Media.demand(data,{companion:paths[companion]},{},{},{companion:true});await settle(data)
    Media.demand(data,{colour:paths[colour]},{},{},{},{colour:true});await settle(data)
    check(Media.physical(data).pending.is_empty() and Media.physical(data).decoded==count,"Revisiting prepared originals queues no redundant decode")
    check(decoded.image.get_data()==bytes and data.resident[colour].cpu_bytes==bytes.size(),"Original picking pixels stay unchanged and owned")
    var expanded:Dictionary=family.duplicate(true);expanded.paths[later]=Catalog.media_path(later)
    expanded.estimates=Encounter.estimates(expanded.paths,cpu,gpu,cache);data.budget_bytes+=int(expanded.estimates[later].bytes)
    var boot:Dictionary=data.boot_paths.duplicate()
    Media.adopt_encounter(data,expanded,1);Media.demand(data,{colour:paths[colour]},{},{},{},{colour:true});await settle(data)
    check(Media.boot_ready(data) and data.boot_paths==boot and not Media.ready(data,{later:true}),"Accepted family growth stays background work without enlarging completed startup")
    check(Media.physical(data).pending.size()==1 and Media.physical(data).pending[0].path==later,"New exact source joins optional work once")
    Media.demand(data,{colour:paths[colour]},{colour:true},{colour:true},{},{colour:true});await settle(data)
    check(not Media.ready(data,{colour:true}),"A new fixture role cannot borrow old colour-only readiness")
    Media.demand(data,{colour:paths[colour]},{},{},{},{colour:true});await settle(data)
    check(Media.ready(data,{colour:true}) and texture.get_image().get_data()==bytes,"Removing fixture role restores the same uploaded original without changing its alpha")
    accounting(data,"Role withdrawal")
    data.budget_bytes=int(sizes[colour].bytes)
    Media.demand(data,{colour:paths[colour]},{},{},{},{colour:true});await settle(data)
    var owner:Dictionary=Media.physical(data)
    check(not owner.preload_selected.has(companion) and not owner.preload_selected.has(later),"Finite budget withdraws both optional selections")
    check(owner.wanted.keys()==[colour] and Media.ready(data,{colour:true}) and data.resident[colour].cpu_bytes==bytes.size(),"Required original stays pinned, ready and owns its unchanged picking bytes")
    check(not Media._requested(owner,companion) and not Media._requested(owner,later),"Unselected optional sources have no current physical admission")
    # The earlier fixture promotion can retain a required colour request even
    # after colour-only readiness returns. Budget withdrawal owns optional
    # work; it is not an eager global pending-queue-empty contract.
    print("ENCOUNTER_BUDGET_BOUNDARY ",JSON.stringify({"selected":owner.preload_selected.keys(),"required":owner.wanted.keys(),
        "pending":owner.pending.map(func(job):return {"path":job.path,"required":job.required,"fixture":job.fixture})}))
    var received:Dictionary=Media.poll(data)
    check(received.is_empty() or received.path==colour,"Ordinary polling cannot admit a withdrawn optional source")
    check(owner.pending.all(func(job):return job.path==colour and job.required) \
        and owner.decode_jobs.all(func(job):return job.get("paths",[job.path]).all(func(path):return path==colour)),"Actual pending/worker ownership contains only the still-required original")
    check(not data.resident.has(later),"Withdrawn background source never gains residency")
    check(Media.prune(data)==[companion] and data.resident.has(colour),"Pressure evicts only the unpinned optional source and retains original picking pixels")
    accounting(data,"Optional pressure retirement")
    Media.close(data)
    var missing:String="res://tests/no-such-optional-source.png"
    var failed:Dictionary=Media.create()
    Media.adopt_required(failed,1);Media.adopt_encounter(failed,{"paths":{missing:missing},"source_sizes":{missing:4},"gpu_only":{missing:true}},1)
    Media.demand(failed,{});await settle(failed)
    check(Media.boot_ready(failed) and not Media.ready(failed,{missing:true}),"Missing optional bytes cannot hold startup or become ready")
    var error:Dictionary=await loaded(failed)
    check(error.has("error") and failed.failed.has(missing) and Media.boot_ready(failed) and not Media.ready(failed,{missing:true}),"Actual optional PNG failure remains explicit without blocking required startup")
    accounting(failed,"Original optional source failure");Media.close(failed)
func finish(extra:Dictionary)->void:
    var report:Dictionary={"checks":checks,"failures":failures};report.merge(extra)
    FileAccess.open("res://generated/encounter_media_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("ENCOUNTER_MEDIA ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
