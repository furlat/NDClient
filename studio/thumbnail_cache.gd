extends RefCounted
## Bounded source previews use shared GPU materials and native simulations.
const Catalog=preload("res://source_catalog.gd")
const Recording=preload("res://studio/recording.gd")
const ReplayPanes=preload("res://studio/replay_panes.gd")
const BackgroundRelease=preload("res://presentation/background_release.gd")
const Characters=preload("res://presentation/characters.gd")
const Tracks=preload("res://presentation/tracks.gd")
const Components=preload("res://presentation/components.gd")
const Palette=preload("res://presentation/palette.gd")
const ConditionPose=preload("res://presentation/condition_pose.gd")
const Conditions=preload("res://presentation/conditions.gd")
const SourceShader=preload("res://studio/source_preview.gdshader")
const BloodPreview=preload("res://presentation/blood_preview.gd")
const NativePreview=preload("res://presentation/native_effect_preview.gd")
const NativeSpellPreview=preload("res://studio/native_spell_preview.gd")
const NativePreviewStore=preload("res://studio/native_preview_store.gd")
const NativeSources=preload("res://presentation/native_effects.gd")
const NativeHits=preload("res://presentation/native_spell_hits.gd")
const Lighting=preload("res://presentation/lighting_2d.gd")
const ConditionOutline=preload("res://presentation/condition_outline.gd")
const OutlineShader=preload("res://studio/condition_outline_preview.gdshader")
const BoltShader=preload("res://studio/geometry_projectile_preview.gdshader")
var source_lights=Lighting.new()
var native_store=NativePreviewStore.new()
var baked_requests:Dictionary={}
var native_descriptors:Dictionary={}
var outline_source=ConditionOutline.new()
var host: Node
## One ordinary production pane serves demand-only composed samples. The
## immutable recording supplies all owners/poses/items; no study operands.
var recording:Dictionary={}
var reference_world:Node3D
## The published pane may differ from the staged source-preparation reference.
var displayed_world:Node3D
var composed_receiving:Dictionary={}
var composed_pane:Dictionary={}
var composed_worker:Thread
var composed_job:Dictionary={}
var composed_token:Dictionary={}
var composed_active:Dictionary={}
var cache: Dictionary={}
var textures: Dictionary={}
var errors: Dictionary={}
var inactive: Dictionary={}
var suspended=false
var prewarm_suspended=false
const NATIVE_READY_TIMEOUT_MS=15000
var pending: Array=[]
var warm_pending: Array=[]
var warm_requested: Dictionary={}
var requested: Dictionary={}
var worker: Thread
var generation=0
# Preserve the previous 256-sample working set for all four authored views.
# Published swatches also share a byte budget, including higher precision sources.
var limit=1024
var texture_limit=64*1024*1024
var texture_bytes=0
var texture_sizes:Dictionary={}
var active: Dictionary={}
const COMPOSITE_BATCH_LIMIT=8
var batch_size=COMPOSITE_BATCH_LIMIT
var composites:Array=[]
var hit_templates:Dictionary={}
const NATIVE_BATCH_LIMIT=8
var native_batch_size=NATIVE_BATCH_LIMIT
var native_composites:Array=[]
# Parked spell swatches (NATIVE_BATCH_LIMIT at most), built before playback
# and reused by every later batch instead of new viewport pairs per job.
var native_spares:Array=[]
var images: Dictionary={}
var image_bytes=0
var image_generation=-1
var image_limit=256*1024*1024
var source_reads=0
var source_hits=0
var source_evictions=0
var pinned:Dictionary={}

func set_demand(keys:Dictionary)->void:
    if keys==pinned and keys.keys()==pinned.keys():return
    pinned=keys
    # A scroll/expand request goes ahead of obsolete viewport work. The running
    # native sample remains atomic; no worker is synchronously interrupted.
    var visible:Array=[];var other:Array=[];var by_key={}
    for job in pending:
        if pinned.has(job.key):by_key[job.key]=job
        else:other.append(job)
    for key in pinned:
        if by_key.has(key):visible.append(by_key[key])
    pending=visible+other

func seed_source_images(sources:Dictionary)->bool:
    # The caller supplies this staged index's admitted renderer source images.
    # Copy immutable handles only for queued source demand, into our own bounded
    # cache. Never inspect or mutate this dictionary while its worker runs.
    if worker!=null and worker.is_alive():return false
    if image_generation!=generation:
        images.clear();image_bytes=0;image_generation=generation;source_reads=0;source_hits=0;source_evictions=0
    var needed={}
    for job in pending:
        for layer in job.get("layers",[]):
            var path:String=layer.paths.get(job.clip,"")
            if not path.is_empty():needed[path]=true
            var noise:String=job.resources.get(layer.get("effect",{}).get("palette",{}).get("noiseSheet"),"")
            if not noise.is_empty():needed[noise]=true
        var film:String=job.get("resources",{}).get(job.get("material",{}).get("ramp",{}).get("texture"),"")
        if not film.is_empty():needed[film]=true
    for path in needed:
        if images.has(path) or not sources.has(path):continue
        var source:Image=sources[path]
        var bytes=source.get_data_size()
        if bytes>image_limit:continue
        images[path]=source;image_bytes+=bytes
        while image_bytes>image_limit:
            var old=images.keys()[0];image_bytes-=images[old].get_data_size();images.erase(old);source_evictions+=1
    return true

func request(row: Dictionary,sample_ms: float,quarter: int,prepare_views: bool=true) -> String:
    var component: Dictionary=row.get("component",{})
    if row.get("visible_here",true)==false or row.kind in ["other_view","perspective"] or row.get("status")=="missing":return ""
    if _composed_row(row):return _request_composed(row,sample_ms,quarter)
    var state: Dictionary={}
    for candidate in row.get("preview_states",[]):
        if candidate.at_ms>sample_ms:break
        state=candidate
    var activities={}
    if row.get("selection_policy")=="sampled" and not suspended:
        var eligible: Array=row.get("preview_tracks",[]).filter(func(value):return sample_ms<value.group_end_ms)
        var actor_samples=Tracks.samples(eligible,sample_ms)
        for id in actor_samples:activities[id]=actor_samples[id].get("activity","idle")
        var candidates=Conditions.samples(state.get("condition_owners",row.get("condition_owners",{})).duplicate(),sample_ms,cache,activities,false)
        var chosen=Conditions.select_layers(candidates.filter(func(value):return value.has("layer")),sample_ms,activities)
        var matches=chosen.filter(func(value):return value.id==component.id)
        if matches.is_empty():
            var idle_key="%s:%s:inactive:%s:%s"%[generation,row.id,floori(sample_ms*32/1000),quarter]
            inactive[idle_key]="Inactive at this sample (shared condition selection)"
            while inactive.size()>limit:inactive.erase(inactive.keys()[0])
            return idle_key
        component=matches[0]
    var age=float(component.get("source_age_ms",sample_ms-row.get("source_start_ms",row.start_ms))) if row.get("selection_policy")=="sampled" else sample_ms-row.get("source_start_ms",row.start_ms)
    if row.kind=="native_effect":age=NativeSources.source_age_ms(component,age)
    elif component.get("loop",false) and component.has("source_duration_ms"):age=fposmod(age,component.source_duration_ms)
    var hz=float(row.get("source_fps",component.get("sample_hz",32)))
    if component.has("native_hit"):hz=maxf(32.0,hz)
    var tick:int=floori(age*maxf(1,hz)/1000.0)
    if component.get("native_spell",false):age=tick*1000.0/maxf(1,hz)
    if row.kind in ["audio","feedback_text","damage_number","geometry_projectile"]:quarter=0
    var key="%s:%s:%s:%s" % [generation,row.id,tick,quarter]
    if row.kind=="audio":key="%s:audio:%s" % [generation,component.get("clip","")]
    if textures.has(key):
        var texture=textures[key];textures.erase(key);textures[key]=texture
        return key
    if suspended or requested.has(key) or errors.has(key): return key
    if row.kind=="native_effect" and component.get("native_spell",false):
        var descriptor_key:String=str(row.id)+":"+str(hz)
        if not native_descriptors.has(descriptor_key):native_descriptors[descriptor_key]=native_store.descriptor(component,maxf(1,hz))
        var baked:Texture2D=native_store.lookup(native_descriptors[descriptor_key],tick,quarter)
        if baked!=null:
            _publish_texture(key,baked,native_store.last_texture_bytes)
            return key
        if native_store.pending(native_descriptors[descriptor_key],tick,quarter):
            baked_requests[key]={"descriptor":native_descriptors[descriptor_key],"tick":tick,"quarter":quarter,
                "row":row,"sample_ms":sample_ms}
            return key
    var job={"key":key,"row":row,"age_ms":age,"sample_ms":sample_ms,"quarter":quarter,"generation":generation,"component":component}
    # Capture this generation's immutable source tables before worker dispatch.
    # A thumbnail must not select on-disk authoring edited after this index.
    job.resources=Catalog.read_file("catalog/resources.json",cache)
    job.facing_cycle=Catalog.read_file("catalog/rig.json",cache).FACING_CYCLE
    if row.kind=="native_effect":
        job.native_age_ms=age
        job.native_context={}
        if NativeSources.source_record(component.source_id,cache).get("weapon_path",false):
            var native_actor:Dictionary=row.get("actor",{})
            var native_rig:Dictionary=Characters.rigs(cache).get(native_actor.get("rig",""),{})
            var weapon=NativeSources.weapon_context(component,native_actor,native_rig,job.facing_cycle,quarter)
            if not weapon.error.is_empty():errors[key]=weapon.error;return key
            job.native_context=weapon.context
    if row.kind in ["native_effect","audio","feedback_text","damage_number","geometry_projectile","residue_deposit"]:
        _queue(job,prepare_views);return key
    var actor: Dictionary=row.get("actor",{}) if row.kind in ["body","part","sprite_layer"] else state.get("actor",row.get("actor",{}))
    if actor.is_empty():errors[key]="No disclosed source actor";return key
    var track: Dictionary=row.get("track",row.get("source_track",component.get("source_track",{})))
    var sampled: Dictionary={}
    if row.kind in ["body","part","sprite_layer"] and not track.is_empty():
        sampled=Tracks.samples([track],sample_ms-row.get("group_start_ms",row.start_ms-track.start_ms)).get(track.actor_uuid,{})
        if sampled.is_empty():sampled={"clip":track.clip,"source_seconds":track.get("source_end_seconds",0)}
    else:
        var eligible: Array=row.get("preview_tracks",[]).filter(func(value):return sample_ms<value.group_end_ms)
        sampled=Tracks.samples(eligible,sample_ms).get(actor.id,{})
        if not sampled.is_empty():track=sampled
    if sampled.is_empty():
        sampled=state.get("sampled_pose",row.get("sampled_pose",{})).duplicate()
        if sampled.get("clock")=="display":sampled.source_seconds=sample_ms/1000.0
    if sampled.is_empty():errors[key]="No disclosed source pose";return key
    var rig: Dictionary=Characters.rigs(cache)[actor.rig]
    var clip_name: String=sampled.clip
    var clip: Dictionary=rig.clips[clip_name]
    var seconds=float(sampled.source_seconds)
    if sampled.get("clock")=="condition":seconds=ConditionPose.source_seconds(sampled.condition_pose,clip,sample_ms-sampled.owner_start_ms)
    if track.get("loop",false) or sampled.get("clock")=="display":seconds=fposmod(seconds,float(clip.frames)/clip.fps)
    var frame=clampi(int(seconds*clip.fps),0,int(clip.frames)-1)
    var config: Dictionary=Catalog.read_file("catalog/rig.json",cache)
    var cycle: Array=config.FACING_CYCLE
    var direction: String=actor.get("facing","SW")
    var origin: Variant=track.get("from_position")
    var target: Variant=track.get("target_position",track.get("to_position"))
    if origin!=null and target!=null:
        var delta=Vector2(target[0]-origin[0],target[1]-origin[1])
        if not delta.is_zero_approx():direction=cycle[posmod(roundi((atan2(delta.y,delta.x)+PI/4)/(TAU/8))+cycle.find("E"),8)]
    var facing: String=cycle[posmod(cycle.find(direction)+quarter*2,8)]
    var conditions=Conditions.samples(state.get("condition_owners",row.get("condition_owners",{})).duplicate(),sample_ms,cache)
    if row.kind in ["material_flash","native_material"] and component.has("native_hit"):
        # Each sampled thumbnail has a private clock/surface. Reuse the exact
        # production material extractor, envelope and recipient composition.
        var flash=component.duplicate();flash.id=key;flash.kind="material_flash";flash.age_ms=age
        conditions.append(flash);job.hit_sample=flash
    elif row.kind=="material_flash":
        var flash=component.duplicate();flash.age_ms=age;conditions.append(flash)
    var material=Conditions.material(actor.id,conditions)
    var layers=Characters.layers(actor,rig,cache)
    if row.kind in ["sprite_layer","condition_appearance"]:
        var layer: Dictionary=component.layer
        var sheet: String=layer.get("sourceSheet",rig.clips[clip_name].sheets.get(layer.category,""))
        var path: String=Characters.BodySources.index(cache).sheets.get(sheet,{}).get("default","")
        if path.is_empty():errors[key]="Unresolved layer source: "+layer.category+"/"+clip_name;return key
        layers=[{"slot":layer.slot,"category":layer.category,"tint":0xffffff,"alpha":1.0,"effect":layer,"paths":{clip_name:path}}]
    if row.kind=="part":layers=layers.filter(func(layer):return layer.slot==row.slot)
    job.merge({"rig":rig,"clip":clip_name,"frame":frame,"facing":facing,"layers":layers,
        "hidden":track.get("hidden_slots",[]),"scale_x":actor.get("scale_x",1.0),"material":material})
    _queue(job,prepare_views)
    return key

static func _composed_row(row:Dictionary)->bool:
    var component:Dictionary=row.get("component",{})
    if component.get("native_item",false):return true
    if row.get("kind")=="native_material" and not component.has("native_hit"):return true
    if row.get("kind")=="world_animation" or component.get("kind")=="world_activation":return true
    # All input-bearing sources require their real receiving scene, including
    # spatial UUIDs with no actor. Immutable constructor operands belong to that
    # same production occurrence, never an isolated review or empty fixture.
    return row.get("kind")=="native_effect" and component.get("native_spell",false) \
        and (not component.get("native_clip",{}).get("inputs",[]).is_empty() \
            or not component.get("native_constructor_inputs",[]).is_empty() or component.get("spatial_effect_uuid")!=null)

func _request_composed(row:Dictionary,sample_ms:float,quarter:int)->String:
    var hz:float=maxf(32.0,float(row.get("source_fps",32.0)))
    var key:String="%s:%s:composed:%s:%s"%[generation,row.id,floori(sample_ms*hz/1000.0),quarter]
    if textures.has(key):
        var texture:Texture2D=textures[key];textures.erase(key);textures[key]=texture;return key
    if suspended or requested.has(key) or errors.has(key) or inactive.has(key):return key
    if recording.is_empty() or not recording.has("initialization"):
        errors[key]="Composed source preview requires this actual recording";return key
    if not is_instance_valid(reference_world):inactive[key]="Awaiting the actual production preview host"
    requested[key]=true
    pending.append({"key":key,"row":row,"component":row.get("component",{}),"sample_ms":sample_ms,"quarter":quarter,
        "generation":generation,"composed":true,"recording":recording})
    return key

static func _restore_composed(job:Dictionary,token:Dictionary)->Dictionary:
    return {"job":job,"timeline":Recording.restore(job.recording,float(job.sample_ms),token)}

func _start_composed(job:Dictionary)->void:
    inactive.erase(job.key)
    composed_job=job
    composed_token=Recording.cancellation();composed_worker=Thread.new()
    var error:Error=composed_worker.start(_restore_composed.bind(job,composed_token))
    if error!=OK:
        composed_worker=null;composed_job={};errors[job.key]="Cannot restore composed recording sample: "+error_string(error);requested.erase(job.key)

func set_displayed_world(value:Node3D)->void:
    var changed:bool=not is_same(displayed_world,value)
    displayed_world=value
    if changed:_release_composed_receiving()

func _release_composed_receiving()->void:
    if composed_receiving.is_empty():return
    var saved:Dictionary=composed_receiving;composed_receiving={}
    if not composed_active.is_empty():
        composed_active.drawn=false;composed_active.erase("draw_signature")
    if not composed_pane.is_empty() and is_instance_valid(composed_pane.get("world")):
        composed_pane.world.publishes_receiving=false
    # A seek may have published another pane while the draw fence was pending.
    # Restore the currently displayed publisher, never a retired candidate.
    var current:Node3D=displayed_world
    if is_instance_valid(current) and current.is_inside_tree():
        current.claim_receiving();current._publish_receiving()
    if is_instance_valid(saved.world) and is_same(saved.world,current) and saved.world.is_inside_tree() and is_instance_valid(saved.pane.viewport):
        ReplayPanes.freeze(saved.pane,false)
        saved.world.process_mode=saved.process_mode

func _claim_composed_receiving(owner:Node3D)->bool:
    if not composed_receiving.is_empty():return true
    if not is_instance_valid(displayed_world) or not displayed_world.is_inside_tree() or not displayed_world.timeline.paused:return false
    if not displayed_world.publishes_receiving:return false
    # Reuse the ordinary pane freeze. Only the paused displayed texture is
    # frozen; the private restored source keeps its normal preparation process
    # and its exact external display clock. No authoritative clock is held.
    var pane:Dictionary={"world":displayed_world,"viewport":displayed_world.get_viewport(),"frozen":[]}
    composed_receiving={"world":displayed_world,"pane":pane,"process_mode":displayed_world.process_mode}
    ReplayPanes.freeze(pane,true)
    displayed_world.publishes_receiving=false
    owner.claim_receiving();owner._publish_receiving()
    return true

func _finish_composed()->void:
    _release_composed_receiving()
    if not composed_pane.is_empty() and is_instance_valid(composed_pane.get("world")):ReplayPanes.freeze(composed_pane,true)
    composed_active={}

func _poll_composed()->bool:
    if composed_worker!=null and not composed_worker.is_alive():
        # A paused request can finish after playback resumes. Retain the one
        # completed result until optional preparation is admitted again; never
        # construct a production pane during the displayed playback's budget.
        if suspended or prewarm_suspended:return false
        var restored:Variant=composed_worker.wait_to_finish();composed_worker=null
        var job:Dictionary=composed_job;composed_job={}
        if job.generation!=generation:return false
        if not restored is Dictionary:
            errors[job.key]="Actual recording sample restoration failed";requested.erase(job.key);_finish_composed();return true
        if restored.get("timeline")!=null and is_instance_valid(reference_world):
            var budget:int=int(reference_world.media_warmup.budget_bytes)
            composed_pane=ReplayPanes.prepare(host,restored.timeline,job.recording,reference_world,composed_pane,budget,true,true)
            var owner:Node3D=composed_pane.world
            owner.external_clock=true;owner.timeline.paused=true;owner.publishes_receiving=false
            owner.native_startup_background=false
            owner.component_renderer.audio.set_enabled(false);composed_pane.viewport.audio_listener_enable_3d=false
            owner.presentation_mutes={};owner.presentation_solo={}
            owner.request_view(int(job.quarter))
            composed_active={"job":job,"started_ms":Time.get_ticks_msec(),"drawn":false,"framing":false}
        elif job.generation==generation:
            errors[job.key]="Actual recording sample restoration unavailable";requested.erase(job.key)
    if composed_active.is_empty():return false
    if composed_pane.is_empty() or not is_instance_valid(composed_pane.get("world")) or not is_instance_valid(composed_pane.get("viewport")):
        var lost_job:Dictionary=composed_active.job
        errors[lost_job.key]="Actual production preview host was retired";requested.erase(lost_job.key);_finish_composed();return true
    if suspended or prewarm_suspended or not is_instance_valid(displayed_world) or not displayed_world.timeline.paused:
        _release_composed_receiving()
        composed_active.drawn=false;composed_active.erase("draw_signature")
        ReplayPanes.freeze(composed_pane,true);composed_active.started_ms=Time.get_ticks_msec();return false
    ReplayPanes.freeze(composed_pane,false)
    var job:Dictionary=composed_active.job;var owner:Node3D=composed_pane.world
    if not owner.media_issue.is_empty() or not owner.presentation_errors.is_empty():
        errors[job.key]="Composed source preparation: "+str(owner.presentation_errors)+owner.media_issue
        requested.erase(job.key);_finish_composed();return true
    if Time.get_ticks_msec()-int(composed_active.started_ms)>NATIVE_READY_TIMEOUT_MS:
        errors[job.key]="Actual composed source did not become ready within the thumbnail budget";requested.erase(job.key);_finish_composed();return true
    if not owner.playback_prepared() or owner.rotation_pending() or int(owner.quarter)!=int(job.quarter):return false
    var component:Dictionary=job.component
    var source_stamp:Array=[];var focus:Variant=null
    if job.row.kind=="world_animation":
        var identity:String=str(job.row.get("owner",{}).get("id",""))
        var spatial:Dictionary=owner.timeline.spatial_effect_owners.get(identity,{})
        if spatial.is_empty() or owner.timeline.display_ms>=float(spatial.get("end_ms",INF)):
            inactive[job.key]="Recorded world owner is inactive at this exact sample"
            while inactive.size()>limit:inactive.erase(inactive.keys()[0])
            requested.erase(job.key);_finish_composed();return true
        var entries:Array=owner.world_media_entries.filter(func(entry):return entry.placement.get("spatial_effect_uuid")==identity)
        if entries.is_empty():
            errors[job.key]="Actual world source has no admitted placement at this recorded cut: "+identity
            requested.erase(job.key);_finish_composed();return true
        focus=_composed_world_focus(entries,source_stamp)
    else:
        var current:Array=owner.displayed_components.filter(func(value):return value.id==component.id)
        if current.is_empty():
            inactive[job.key]="Recorded source is inactive or suppressed at this exact sample"
            while inactive.size()>limit:inactive.erase(inactive.keys()[0])
            requested.erase(job.key);_finish_composed();return true
        if current.size()!=1:
            errors[job.key]="Recorded source identity is ambiguous: "+str(component.id);requested.erase(job.key);_finish_composed();return true
        component=current[0]
        if component.kind=="world_activation":
            var entries:Array=owner.component_renderer.media_handles.values().filter(func(entry):return entry.component_id==component.id and entry.published)
            if entries.is_empty():return false
            focus=_composed_world_focus(entries,source_stamp)
        else:
            var diagnostics:Dictionary=owner.component_renderer.native_spells.diagnostics.get(str(component.id),{})
            var bindings:Dictionary=diagnostics.get("input_bindings",{})
            if diagnostics.get("status") in ["missing","partial"]:
                errors[job.key]="Actual composed source unavailable: "+str(diagnostics.get("reason",""))+" "+str(bindings.get("unavailable",{}))
                requested.erase(job.key);_finish_composed();return true
            if diagnostics.get("status")!="rendered" or not bindings.get("pending",{}).is_empty():return false
            if not bindings.get("unavailable",{}).is_empty():return false
            var handle:Dictionary=owner.component_renderer.native_spells.handles.get(str(component.id),{})
            if handle.is_empty():return false
            source_stamp.append([handle.root.get_instance_id(),handle.get("drawn_time",-1.0)])
            var actor_id:String="" if component.get("actor_uuid")==null else str(component.actor_uuid)
            if component.get("target_uuid")!=null and not str(component.get("native_cue",{}).get("attachment","")).begins_with("caster"):actor_id=str(component.target_uuid)
            if not actor_id.is_empty():
                var visual:Dictionary=owner.visual_actors.get(actor_id,{})
                if visual.is_empty() or not visual.get("valid",false):
                    errors[job.key]="Actual composed recipient is not disclosed at this sample: "+actor_id;requested.erase(job.key);_finish_composed();return true
                focus=Components.Placement.contact(visual.row)
            elif handle.get("endpoints",{}).get("ready",false):
                # The shared renderer resolved this optical ground point from
                # the actual owner/geometry/support. No actor or cell is made up.
                focus=handle.endpoints.ground
    if focus==null:
        errors[job.key]="Actual composed source has no disclosed framing anchor";requested.erase(job.key);_finish_composed();return true
    if not composed_active.framing:
        # Keep the full recorded scene: an actor or cell crop cannot bound all
        # held field/weapon artwork. Only its actual restored focus is changed.
        owner.camera_focus=focus;owner.position_camera()
        composed_active.framing=true;composed_active.drawn=false;return false
    if not _claim_composed_receiving(owner):return false
    var signature:Array=[owner.timeline.initialization_revision,owner.world_revision,owner.quarter,owner.timeline.display_ms,owner.camera.transform,owner.camera.size,source_stamp]
    if composed_active.get("draw_signature",[])!=signature:
        composed_active.draw_signature=signature;composed_active.drawn=false
        var sample_owner:Dictionary=composed_active
        RenderingServer.frame_post_draw.connect(func():
            if is_same(composed_active,sample_owner):sample_owner.drawn=true,CONNECT_ONE_SHOT)
        return false
    if not composed_active.drawn:return false
    # Re-fetch above after the draw fence; publication may replace source
    # handles/operands while that frame was in flight. This is a preview only.
    _publish(job,composed_pane.viewport.get_texture().get_image())
    _finish_composed();return true

## One framing bound over actual already-published source placements. Each
## draw keeps the real spatial/occurrence identity and its normal source clock.
static func _composed_world_focus(entries:Array,stamp:Array)->Variant:
    var bounds:AABB;var found:bool=false
    for entry in entries:
        if not is_instance_valid(entry.get("node")) or not entry.get("placement",{}).has("position"):continue
        var point:Vector3=Components.Placement.contact(entry.placement)
        bounds=bounds.expand(point) if found else AABB(point,Vector3.ZERO);found=true
        stamp.append([entry.node.get_instance_id(),entry.get("world_media_frame_key",[]),entry.node.global_transform])
    return bounds.get_center() if found else null

func _queue(job:Dictionary,prepare_views:bool)->void:
    requested[job.key]=true;pending.append(job)
    if not prepare_views or job.row.kind in ["audio","feedback_text","damage_number","geometry_projectile"]:return
    for quarter in 4:
        if quarter==job.quarter:continue
        var key="%s:%s:%s:%s"%[generation,job.row.id,job.sample_ms,quarter]
        if warm_requested.has(key):continue
        warm_requested[key]=true
        warm_pending.append({"key":key,"row":job.row,"sample_ms":job.sample_ms,"quarter":quarter,"generation":generation})
    while warm_pending.size()>limit:
        warm_requested.erase(warm_pending.pop_front().key)

func queue_prewarm(samples:Array)->Dictionary:
    # A changed fit/zoom replaces only unresolved background descriptors. The
    # active worker and exact visible demand retain their existing ownership.
    warm_pending=[];warm_requested={}
    var ordered:Array=[]
    for sample in samples:
        var row:Dictionary=sample.row
        if row.get("status")=="missing" or not row.get("visible_here",true) or _composed_row(row):continue
        ordered.append({"sample":sample,"group":_prewarm_group(row)})
    ordered.sort_custom(func(a,b):
        if a.group!=b.group:return a.group<b.group
        if a.sample.row.id!=b.sample.row.id:return a.sample.row.id<b.sample.row.id
        if a.sample.sample_ms!=b.sample.sample_ms:return a.sample.sample_ms<b.sample.sample_ms
        return a.sample.quarter<b.sample.quarter)
    var skipped=0
    for entry in ordered:
        var sample:Dictionary=entry.sample
        var key="%s:%s:%s:%s"%[generation,sample.row.id,sample.sample_ms,sample.quarter]
        if warm_requested.has(key):skipped+=1;continue
        if warm_pending.size()>=limit:skipped+=1;continue
        warm_requested[key]=true
        warm_pending.append({"key":key,"row":sample.row,"sample_ms":sample.sample_ms,"quarter":sample.quarter,"generation":generation})
    return {"queued":warm_pending.size(),"retained":textures.size(),"skipped":skipped}

func _prewarm_group(row:Dictionary)->String:
    # Main mechanisms retain priority over optional individual gear inspection.
    # Static source clip metadata is sufficient for locality; actual pose and
    # condition selection still occurs only in the shared request() sampler.
    var track:Dictionary=row.get("track",row.get("source_track",row.get("component",{}).get("source_track",{})))
    var clip:String=track.get("clip",row.get("selected_pose",{}).get("clip",row.get("sampled_pose",{}).get("clip","")))
    var rig:String=row.get("actor",{}).get("rig","")
    var source:String=row.get("component",{}).get("source_id",row.get("component",{}).get("asset_id",row.get("source","")))
    return ("1:" if row.kind=="part" else "0:")+rig+":"+(clip if not clip.is_empty() else source)

func _prepare_view()->void:
    # Resolve a bounded batch only after foreground work. Already resident
    # samples return immediately; they never enter decoding or native drawing.
    if prewarm_suspended or not pending.is_empty() or _foreground_pending():return
    var deadline=Time.get_ticks_usec()+1000
    while pending.size()<clampi(batch_size,1,COMPOSITE_BATCH_LIMIT) and not warm_pending.is_empty() and Time.get_ticks_usec()<deadline:
        var sample:Dictionary=warm_pending.pop_front();warm_requested.erase(sample.key)
        if sample.generation==generation:request(sample.row,sample.sample_ms,sample.quarter,false)

func _foreground_pending()->bool:
    for key in pinned:
        if not textures.has(key) and not errors.has(key) and not inactive.has(key):return true
    return false

func _image(path: String) -> Image:
    if images.has(path):
        var cached:Image=images[path];images.erase(path);images[path]=cached;source_hits+=1
        return cached
    var result=Image.load_from_file(Catalog.media_path(path))
    if result==null or result.is_empty(): return null
    source_reads+=1
    if result.get_data_size()>image_limit:return result
    images[path]=result;image_bytes+=result.get_data_size()
    while image_bytes>image_limit:
        var old=images.keys()[0];image_bytes-=images[old].get_data_size();images.erase(old);source_evictions+=1
    return result

func _decode(job: Dictionary) -> Dictionary:
    if image_generation!=job.generation:
        images.clear();image_bytes=0;image_generation=job.generation;source_reads=0;source_hits=0;source_evictions=0
    var parts: Array=[];var auxiliary={}
    var resources:Dictionary=job.resources
    for layer in job.layers:
        if layer.slot=="shadow" or layer.slot in job.hidden or not layer.paths.has(job.clip): continue
        var source=_image(layer.paths[job.clip])
        if source==null: return {"error":"Missing source: "+str(layer.paths[job.clip]),"job":job}
        var size=Vector2i(job.rig.cell_width,job.rig.cell_height)
        var cell=source.get_region(Rect2i(Vector2i(job.frame*size.x,int(job.rig.facing_rows[job.facing])*size.y),size))
        parts.append({"layer":layer,"image":cell})
        var noise: String=resources.get(layer.get("effect",{}).get("palette",{}).get("noiseSheet"),"")
        if not noise.is_empty(): auxiliary[noise]=_image(noise)
    var film: String=resources.get(job.material.ramp.get("texture"),"")
    if not film.is_empty():auxiliary[film]=_image(film)
    if parts.is_empty():return {"error":"No authored layers for this source pose","job":job}
    var mask: Image
    if not job.material.outline.is_empty():
        mask=Image.create_empty(job.rig.cell_width,job.rig.cell_height,false,Image.FORMAT_RGBA8)
        for part in parts:
            if part.layer.slot not in Characters.EFFECT_SLOTS:mask.blend_rect(part.image,Rect2i(Vector2i.ZERO,mask.get_size()),Vector2i.ZERO)
    return {"job":job,"parts":parts,"auxiliary":auxiliary,"resources":resources,"mask":mask}

func _decode_batch(jobs:Array)->Array:
    # One worker owns the decoded-image LRU. Multiple ordinary swatches share
    # its source reads, while their unchanged native viewports draw together.
    var decoded:Array=[]
    for job in jobs:decoded.append(_decode(job))
    return decoded

func _ordinary(job:Dictionary)->bool:
    return not job.get("composed",false) and job.row.kind not in ["audio","feedback_text","damage_number","geometry_projectile","residue_deposit","native_effect"]

func poll() -> bool:
    native_store.poll_retired()
    for key in baked_requests.keys():
        var job:Dictionary=baked_requests[key]
        var baked:Texture2D=native_store.lookup(job.descriptor,job.tick,job.quarter)
        if baked!=null:
            baked_requests.erase(key);_publish_texture(key,baked,native_store.last_texture_bytes);return true
        if not native_store.pending(job.descriptor,job.tick,job.quarter):
            baked_requests.erase(key);request(job.row,job.sample_ms,job.quarter,false)
        break
    if not is_instance_valid(host):
        _release_composed_receiving();return false
    var composed_changed:bool=_poll_composed()
    if suspended:
        if active.get("kind")=="native_effect":active.started_ms=Time.get_ticks_msec()
        for composite in native_composites:composite.started_ms=Time.get_ticks_msec()
        for composite in composites:
            if composite.get("preparing_hit",false):composite.started_ms=Time.get_ticks_msec()
        return false
    _prepare_spares()
    var changed:bool=composed_changed
    # Each spell swatch retains its own simulation and private viewport. They
    # advance one existing 60 Hz history step together per drawn frame, rather
    # than replaying every visible sample's entire history serially.
    for i in range(native_composites.size()-1,-1,-1):
        var composite:Dictionary=native_composites[i]
        if _sample_native(composite):
            _close_native(composite);native_composites.remove_at(i);changed=true
    for i in range(composites.size()-1,-1,-1):
        var composite:Dictionary=composites[i]
        if composite.get("preparing_hit",false):
            if Time.get_ticks_msec()-composite.started_ms>NATIVE_READY_TIMEOUT_MS:
                errors[composite.job.key]="Native body material source did not become ready within the thumbnail budget";requested.erase(composite.job.key)
                _close_hit(composite);composites.remove_at(i);changed=true;continue
            var loading:Dictionary=composite.hit_renderer.prepare(composite.hit_parent,[composite.job.hit_sample],cache,[],{},false)
            if not loading.issues.is_empty():
                errors[composite.job.key]=str(loading.issues);requested.erase(composite.job.key)
                _close_hit(composite);composites.remove_at(i);changed=true;continue
            if not loading.ready:continue
            var decorated:Dictionary=composite.hit_renderer.decorate(composite.hit_parent,[composite.job.hit_sample])
            if not decorated.ready:continue
            if not composite.get("hit_sampled",false):
                composite.hit_sampled=true
                RenderingServer.frame_post_draw.connect(func():composite.hit_drawn=true,CONNECT_ONE_SHOT)
            if not composite.get("hit_drawn",false):continue
            composite.job.material.flash=composite.job.hit_sample
            var body:Dictionary=_compose(composite.decoded,false)
            body.hit_renderer=composite.hit_renderer;body.hit_parent=composite.hit_parent;composites[i]=body
            if not RenderingServer.frame_post_draw.is_connected(_composites_drawn):RenderingServer.frame_post_draw.connect(_composites_drawn,CONNECT_ONE_SHOT)
            continue
        if not composite.drawn:continue
        _publish(composite.job,composite.viewport.get_texture().get_image())
        if composite.has("hit_renderer"):_close_hit(composite)
        composite.viewport.queue_free();composites.remove_at(i);changed=true
    if worker!=null and not worker.is_alive() and composites.is_empty():
        var batch:Array=worker.wait_to_finish();worker=null
        for decoded in batch:
            if decoded.job.generation!=generation:continue
            if decoded.has("error"):errors[decoded.job.key]=decoded.error;requested.erase(decoded.job.key)
            else:composites.append(_compose(decoded))
        if not composites.is_empty():RenderingServer.frame_post_draw.connect(_composites_drawn,CONNECT_ONE_SHOT)
    if not active.is_empty():
        if active.kind=="native_effect":
            if _sample_native(active):_clear_active();changed=true
        elif active.kind=="blood":
            if not active.get("configured",false):
                if active.node.renderer.prepare(active.node,active.node.timeline.queue):
                    active.node.configure(active.job.component,cache,active.job.age_ms,active.job.quarter,source_lights)
                    active.configured=true;active.draws=0;active.drawn=false
                    RenderingServer.frame_post_draw.connect(_drawn.bind(active.job.key,active.job.generation),CONNECT_ONE_SHOT)
                return changed
            active.node.sample()
            if active.drawn and active.draws>2 and active.node.renderer.ready:
                _publish(active.job,active.viewport.get_texture().get_image());_clear_active();changed=true
        elif active.drawn:
            _publish(active.job,active.viewport.get_texture().get_image());_clear_active();changed=true
        if not active.is_empty() and active.kind!="native_effect":active.draws+=1
    if worker==null and active.is_empty() and pending.is_empty():_prepare_view()
    if worker==null and active.is_empty() and not pending.is_empty():
        if pending[0].get("composed",false):
            if composed_worker==null and composed_active.is_empty() and not prewarm_suspended and is_instance_valid(reference_world):
                _start_composed(pending.pop_front());return changed
            # A deferred production-pane sample must not hold ordinary visible
            # waveforms/body sources behind it. Keep that exact request queued;
            # the first eligible job uses the same existing bounded work paths.
            var eligible:int=-1
            for position in pending.size():
                if not pending[position].get("composed",false):eligible=position;break
            if eligible<0:return changed
            pending.push_front(pending.pop_at(eligible))
        while native_composites.size()<clampi(native_batch_size,1,NATIVE_BATCH_LIMIT) and not pending.is_empty() and not pending[0].get("composed",false) and pending[0].row.kind=="native_effect" and pending[0].component.get("native_spell",false):
            var next:Dictionary=pending.pop_front()
            if next.generation!=generation:continue
            var composite:Dictionary=_start_native(next)
            if not composite.is_empty():native_composites.append(composite)
            else:changed=true
        if pending.is_empty() or pending[0].get("composed",false):return changed
        # A full native batch must leave the next spell job queued. Ordinary
        # image decoding can still use its existing independent worker.
        if pending[0].row.kind=="native_effect" and pending[0].component.get("native_spell",false):return changed
        if _ordinary(pending[0]):
            var jobs:Array=[]
            while not pending.is_empty() and jobs.size()<clampi(batch_size,1,COMPOSITE_BATCH_LIMIT) and _ordinary(pending[0]):
                var next:Dictionary=pending.pop_front()
                if next.generation==generation:jobs.append(next)
            if not jobs.is_empty():worker=Thread.new();worker.start(_decode_batch.bind(jobs))
            return changed
        if not composites.is_empty():return changed
        # Native class swatches share the same compiler boundary as spells.
        if pending[0].row.kind=="native_effect" and not NativePreview.Sources.Admission.can_mutate():return changed
        var job: Dictionary=pending.pop_front()
        if job.generation!=generation:return changed
        if job.row.kind=="audio": _waveform(job);changed=true
        elif job.row.kind in ["feedback_text","damage_number","geometry_projectile"]:_primitive(job)
        elif job.row.kind=="residue_deposit":
            var view=SubViewport.new();view.size=Vector2i(256,256);view.transparent_bg=true;view.own_world_3d=true
            view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
            host.add_child(view)
            var node=BloodPreview.new();view.add_child(node);node.catalog_cache=cache;node.source_lighting=source_lights
            node.timeline.queue=[{"id":job.key,"components":[job.component]}]
            active={"kind":"blood","job":job,"node":node,"viewport":view,"draws":0,"drawn":false,"configured":false}
        elif job.row.kind=="native_effect":
            active=_start_native(job)
    return changed

func _start_native(job:Dictionary)->Dictionary:
    var node:Node
    if job.component.get("native_spell",false) and not native_spares.is_empty():node=native_spares.pop_back()
    else:
        node=NativeSpellPreview.new() if job.component.get("native_spell",false) else NativePreview.new()
        host.add_child(node)
    var issue:String=node.configure_component(job.component) if job.component.get("native_spell",false) else node.configure(job.component.source_id,cache,Components.effect_seed(job.component),job.component.get("palette",[]))
    # Source swatches keep their neutral illumination: white ambient, no room
    # lights, independent of the scene and of every other preview.
    if issue.is_empty() and not job.component.get("native_spell",false):issue=node.bind_receiving(1.0,false)
    if not issue.is_empty():
        errors[job.key]=issue;requested.erase(job.key);node.close();node.queue_free();return {}
    var context={"screen_origin":Vector2.ZERO,"pixel_scale":1.0,"light_cap":0.0,"supports":[Transform3D(Basis.from_scale(Vector3(3,1,3)),Vector3.ZERO)]}
    context.merge(job.native_context)
    node.texture()
    return {"kind":"native_effect","job":job,"node":node,"draws":0,"context":context,"started_ms":Time.get_ticks_msec()}

func _sample_native(composite:Dictionary)->bool:
    # A live approach's constructor (tens to hundreds of ms for a condition
    # lifecycle) waits until the recording is paused, never during playback.
    if prewarm_suspended and composite.node.has_method("builds_live") and composite.node.builds_live():
        composite.started_ms=Time.get_ticks_msec();return false
    var basis=Basis.from_euler(Vector3(-atan(sqrt(.5)),PI/4+composite.job.quarter*PI/2,0))
    var sampled= composite.node.sample(composite.job.native_age_ms/1000.0,basis,Vector3.ZERO,1.0,[],composite.context)
    if sampled.ready and composite.draws>1:
        _publish(composite.job,composite.node.texture().get_image());return true
    if not sampled.get("error","").is_empty():
        errors[composite.job.key]=sampled.error;requested.erase(composite.job.key);return true
    if Time.get_ticks_msec()-composite.started_ms>=NATIVE_READY_TIMEOUT_MS:
        errors[composite.job.key]="Native source did not become ready within 15 seconds: "+str(composite.job.component.source_id)
        requested.erase(composite.job.key);return true
    composite.draws+=1
    return false

func _close_native(composite:Dictionary)->void:
    if composite.node is NativeSpellPreview and native_spares.size()<NATIVE_BATCH_LIMIT:
        composite.node.release();native_spares.append(composite.node);return
    composite.node.close();composite.node.queue_free()

## Spell swatch viewports exist before playback: one parked swatch per frame
## until the batch size, while nothing else is queued.
func _prepare_spares()->void:
    if native_spares.size()+native_composites.size()>=NATIVE_BATCH_LIMIT or native_composites.size()>0:return
    var node:=NativeSpellPreview.new();host.add_child(node)
    node.configure_component({"finish_profile":{}})
    node.release();native_spares.append(node)

## Spell swatch descriptors read their source files' stamps (tens of ms per
## spell). Resolve them when the recording is installed, not at first request.
func prepare_descriptors(rows:Array)->void:
    for row in rows:
        var component:Dictionary=row.get("component",{})
        if row.get("kind")!="native_effect" or not component.get("native_spell",false) or _composed_row(row) or row.get("status")=="missing":continue
        var hz=float(row.get("source_fps",component.get("sample_hz",32)))
        var descriptor_key:String=str(row.id)+":"+str(hz)
        if not native_descriptors.has(descriptor_key):native_descriptors[descriptor_key]=native_store.descriptor(component,maxf(1,hz))

func _primitive(job: Dictionary) -> void:
    var component: Dictionary=job.component
    var view=SubViewport.new();view.disable_3d=true;view.transparent_bg=true;view.size=Vector2i(128,64)
    view.render_target_update_mode=SubViewport.UPDATE_ONCE;host.add_child(view)
    if component.kind=="geometry_projectile":
        var rect=ColorRect.new();rect.position=Vector2(16,24);rect.size=Vector2(96,16)
        var shader=ShaderMaterial.new();shader.shader=BoltShader;rect.material=shader
        var length_px: float=component.style.maximumLengthPx
        shader.set_shader_parameter("length_px",length_px);shader.set_shader_parameter("extent",Vector2(length_px+component.style.headRadiusPx*2+2,maxf(component.style.headRadiusPx*2,component.style.strokeWidthPx)+2))
        for field in [["stroke_width","strokeWidthPx"],["stroke_alpha","strokeAlpha"],["head_radius","headRadiusPx"],["head_alpha","headAlpha"]]:shader.set_shader_parameter(field[0],component.style[field[1]])
        shader.set_shader_parameter("stroke_colour",Color.hex(int(component.colors.secondary)*256+255));shader.set_shader_parameter("head_colour",Color.hex(int(component.colors.primary)*256+255));view.add_child(rect)
    else:
        var label=Label.new();label.text=component.text;label.size=Vector2(view.size)
        label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
        var font=SystemFont.new();font.font_names=PackedStringArray([component.style.fontFamily]);font.font_weight=700
        label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",component.style.fontSizePx)
        label.add_theme_color_override("font_color",Color.hex(int(component.color)*256+255));label.add_theme_color_override("font_outline_color",Color.hex(int(component.style.strokeColor)*256+255));label.add_theme_constant_override("outline_size",component.style.strokeWidthPx);view.add_child(label)
    active={"kind":"primitive","job":job,"viewport":view,"draws":0,"drawn":false}
    RenderingServer.frame_post_draw.connect(_drawn.bind(job.key,job.generation),CONNECT_ONE_SHOT)

func _compose(decoded: Dictionary,prepare_hit:bool=true) -> Dictionary:
    var job: Dictionary=decoded.job
    if prepare_hit and job.has("hit_sample"):
        var renderer=NativeHits.new();renderer.material_templates=hit_templates
        var source_parent=Node3D.new();host.add_child(source_parent)
        return {"kind":"body","job":job,"decoded":decoded,"preparing_hit":true,"hit_renderer":renderer,"hit_parent":source_parent,"drawn":false,"started_ms":Time.get_ticks_msec()}
    var view=SubViewport.new();view.disable_3d=true;view.transparent_bg=true
    view.size=Vector2i(job.rig.cell_width,job.rig.cell_height);view.render_target_update_mode=SubViewport.UPDATE_ONCE;host.add_child(view)
    var resources: Dictionary=decoded.resources;var aux={}
    for path in decoded.auxiliary:
        if decoded.auxiliary[path]!=null:aux[path]=ImageTexture.create_from_image(decoded.auxiliary[path])
    var state: Dictionary=job.material
    for part in decoded.parts:
        var sprite=Sprite2D.new();sprite.centered=false;sprite.texture=ImageTexture.create_from_image(part.image)
        var shader=ShaderMaterial.new();shader.shader=SourceShader;sprite.material=shader
        shader.set_shader_parameter("sheet",sprite.texture);shader.set_shader_parameter("frame_uv",Vector4(0,0,1,1))
        shader.set_shader_parameter("tint",Palette.rgb(part.layer.tint));shader.set_shader_parameter("layer_alpha",part.layer.alpha)
        Palette.bind(shader,part.layer,job.facing,job.frame,aux,resources);Conditions.bind(shader,state,aux,resources)
        shader.set_shader_parameter("material_cell_size",Vector2(job.rig.cell_width,job.rig.cell_height))
        sprite.scale.x=absf(job.scale_x)
        if job.scale_x<0: sprite.flip_h=true
        sprite.position.x=(view.size.x-view.size.x*absf(job.scale_x))*.5
        view.add_child(sprite)
    if decoded.mask!=null:
        var overlay=Sprite2D.new();overlay.centered=false;overlay.texture=ImageTexture.create_from_image(decoded.mask)
        var shader=ShaderMaterial.new();shader.shader=OutlineShader
        shader.set_shader_parameter("assembled",overlay.texture);shader.set_shader_parameter("pulse_mask",outline_source.pulse_mask(view.size))
        ConditionOutline.bind(shader,state);overlay.material=shader
        overlay.scale.x=absf(job.scale_x);overlay.flip_h=job.scale_x<0;overlay.position.x=(view.size.x-view.size.x*absf(job.scale_x))*.5;view.add_child(overlay)
    return {"kind":"body","job":job,"viewport":view,"drawn":false}

func _composites_drawn()->void:
    for composite in composites:
        if not composite.get("preparing_hit",false):composite.drawn=true

func _drawn(key: String,epoch: int) -> void:
    if epoch==generation and not active.is_empty() and active.job.key==key: active.drawn=true

func _waveform(job: Dictionary) -> void:
    var record: Dictionary=Catalog.read_file("audio/waveforms.json",cache).get("clips",{}).get(job.row.component.get("clip"),{})
    if record.is_empty(): errors[job.key]="No decoded waveform";requested.erase(job.key);return
    var peaks: Array=record.peaks
    var output=Image.create_empty(peaks.size(),64,false,Image.FORMAT_RGBA8)
    for x in peaks.size():
        var amplitude=clampi(roundi(peaks[x]*30),0,30)
        for y in range(32-amplitude,33+amplitude): output.set_pixel(x,y,Color("a1cfba"))
    _publish(job,output)

func _publish(job: Dictionary,output: Image) -> void:
    requested.erase(job.key)
    if job.generation!=generation or output==null or output.is_empty(): return
    if job.row.kind!="audio" and not job.get("composed",false):
        var used=output.get_used_rect()
        if used.has_area():output=output.get_region(used.grow(3).intersection(Rect2i(Vector2i.ZERO,output.get_size())))
    var factor=minf(1.0,128.0/maxi(output.get_width(),output.get_height()))
    if factor<1:output.resize(maxi(1,roundi(output.get_width()*factor)),maxi(1,roundi(output.get_height()*factor)),Image.INTERPOLATE_NEAREST)
    _publish_texture(job.key,ImageTexture.create_from_image(output),output.get_data_size())

func _publish_texture(key:String,texture:Texture2D,bytes:int)->void:
    textures[key]=texture
    texture_bytes-=texture_sizes.get(key,0)
    texture_sizes[key]=bytes;texture_bytes+=bytes
    while textures.size()>limit or texture_bytes>texture_limit:
        var old=""
        for candidate in textures:
            if not pinned.has(candidate):old=candidate;break
        if old.is_empty():
            # Refuse an oversized visible demand explicitly instead of cycling
            # forever between missing pinned samples or growing without a cap.
            old=key;errors[key]="Visible source previews exceed the bounded thumbnail budget"
        texture_bytes-=texture_sizes[old];texture_sizes.erase(old);textures.erase(old)

func _clear_active() -> void:
    if active.has("node"):active.node.close();active.node.queue_free()
    if active.has("viewport"):active.viewport.queue_free()
    active={}

func _close_hit(composite:Dictionary)->void:
    composite.hit_renderer.close()
    composite.hit_parent.queue_free()

func reset() -> void:
    Recording.cancel(composed_token)
    _release_composed_receiving()
    ReplayPanes.discard(composed_pane);composed_pane={};composed_active={};recording={};reference_world=null;displayed_world=null
    generation+=1;pending.clear();warm_pending.clear();warm_requested.clear();requested.clear();pinned.clear();textures.clear();texture_sizes.clear();texture_bytes=0;errors.clear();inactive.clear();cache.clear();_clear_active()
    for composite in native_composites:_close_native(composite)
    native_composites.clear()
    native_descriptors.clear();baked_requests.clear();native_store.reset()
    if RenderingServer.frame_post_draw.is_connected(_composites_drawn):RenderingServer.frame_post_draw.disconnect(_composites_drawn)
    for composite in composites:
        if composite.has("hit_renderer"):_close_hit(composite)
        if composite.has("viewport"):composite.viewport.queue_free()
    composites.clear()
    hit_templates.clear()

func close() -> void:
    reset()
    if composed_worker!=null:composed_worker.wait_to_finish();composed_worker=null
    composed_job={}
    for node in native_spares:
        if is_instance_valid(node):node.close();node.queue_free()
    native_spares.clear()
    if worker!=null:worker.wait_to_finish();worker=null
    # Retired tracks drop their decoded source images on a worker, not in a frame.
    BackgroundRelease.release([images]);images={};image_bytes=0
