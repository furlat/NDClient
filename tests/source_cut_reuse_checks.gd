extends SceneTree
## Passive source-cut identity and required-vs-optional readiness. No GPU,
## texture decoding, scene construction, or native-output/performance claim.
const Media=preload("res://presentation/media_warmup.gd")
const Player=preload("res://play.gd")
const Renderer=preload("res://presentation/component_renderer.gd")
const RecordingMedia=preload("res://studio/recording_media.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Profile=preload("res://frame_profile.gd")

class NativeSpy extends RefCounted:
    var preparation_revision:int=0
    var calls:int=0
    var optional_ids:Array=[]
    var optical_tracks:Array=[]
    var optical_components:Array=[]
    func prepare(_groups:Array,_cache:Dictionary,_world:Node=null,prefetch:Array=[],_budget:Dictionary={},_optional:bool=true,_optical:Array=[])->Dictionary:
        calls+=1;optional_ids=[];optical_tracks=[];optical_components=[]
        for group in prefetch:
            for component in group.components:optional_ids.append(component.id)
        for group in _optical:
            optical_tracks.append_array(group.get("actor_tracks",[]));optical_components.append_array(group.get("components",[]))
        return {"ready":true,"errors":[]}
class HitSpy extends RefCounted:
    func prepare(_world:Node,_components:Array,_cache:Dictionary,_prefetch:Array=[],_budget:Dictionary={},_optional:bool=true)->Dictionary:
        return {"ready":true,"issues":[]}
class BloodSpy extends RefCounted:
    var deposit_create_usec:int=0
    func prepare(_world:Node,_groups:Array,_budget:Dictionary={})->bool:return true
class Lighting extends RefCounted:
    var native_preparation_ready:bool=true
class Host extends Node:
    var timeline:RefCounted
    var profile:Dictionary=Profile.create()
    var quarter:int=0
    var native_spell_hit_material:bool=true
    var source_lighting:RefCounted=Lighting.new()
    var displayed_components:Array=[]

var checks:int=0
var failures:Array=[]
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SOURCE_CUT_REUSE_FAIL ",label)

func profile_contract()->void:
    check(Player._same_source_refs([[]],[[]]),"Empty contribution arrays have no physical source identity to replace")
    check(not Player._same_source_refs([[{"roles":{"body":true}}]],[[{"roles":{"body":true}}]]),"Equal-valued nonempty contributions retain strict original-owner identity")
    var paths:Dictionary={"body":"/unit/body","original":"/unit/original","gentle":"/unit/gentle","reference":"/unit/reference"}
    var normals:Dictionary={"body":{"original":"original","gentle":"gentle","reference":"reference"}}
    var records:Dictionary={};var families:Dictionary={}
    for profile in ["original","gentle","reference"]:
        records[profile]=[Media.source_record({"body":"/unit/body",profile:"/unit/"+profile})]
        families[profile]=Media._source_family(records[profile],{})
    var packet:Dictionary={"source_records":records,"source_families":families}
    var environment:Dictionary={"required_records":[],"required_family":{}}
    var cache:Dictionary={};var first:Dictionary={}
    for id in ["first","next_turn"]:
        var character:Dictionary={"actor_records":{id:[packet]}}
        var plan:Dictionary={"required":paths,"normal_sets":normals,"source_sizes":{},
            "source_records":Media.source_records(character,environment,[{"id":id}],cache)}
        Media._source_publications(plan,cache)
        for profile in records:
            var actual:Dictionary=plan.character_profiles[id][profile]
            check(actual=={"body":"/unit/body",profile:"/unit/"+profile},"Prepared "+profile+" paths contain exactly the independent physical body and selected normal")
            check(actual.is_read_only(),"Prepared "+profile+" projection is immutable")
            if first.is_empty():continue
            check(is_same(actual,first[profile]),"A distinct turn with the same source operands borrows the original "+profile+" path map")
        if first.is_empty():first=plan.character_profiles[id]
    check(paths.size()==4 and normals.body.size()==3,"Projection preserves the neutral source/profile metadata")
    var changed_records:Dictionary={};var changed_families:Dictionary={}
    for profile in records:
        changed_records[profile]=records[profile]+[Media.source_record({"new":"/unit/new"})]
        changed_families[profile]=Media._source_family(changed_records[profile],{})
    var changed_packet:Dictionary={"source_records":changed_records,"source_families":changed_families}
    var changed_paths:Dictionary=paths.duplicate();changed_paths.new="/unit/new"
    var changed:Dictionary={"required":changed_paths,"normal_sets":normals,"source_sizes":{},
        "source_records":Media.source_records({"actor_records":{"changed":[changed_packet]}},environment,[{"id":"changed"}],cache)}
    Media._source_publications(changed,cache)
    for profile in records:
        check(changed.character_profiles.changed[profile].has("new") and not first[profile].has("new") \
            and not is_same(first[profile],changed.character_profiles.changed[profile]),
            "Changed actual source operands replace the "+profile+" projection without mutating its old holder")

func empty_resource_groups(index:Dictionary)->void:
    var host=Host.new();root.add_child(host)
    host.timeline=Fixtures.Recording.Timeline.new()
    host.timeline.state={"actors":{},"objects":{},"items":{},"senses":{"spatial_effects":{}}}
    var renderer=Renderer.new();var native=NativeSpy.new()
    renderer.native_spells=native;renderer.native_hits=HitSpy.new();renderer.blood=BloodSpy.new()
    renderer.epoch=host.timeline.initialization_revision
    var source_groups:Array=[]
    for entry in index.groups:
        var group:Dictionary=entry.group
        if group.get("components",[]).is_empty() and group.get("native_requirements",[]).is_empty() and group.get("actor_tracks",[]).is_empty():source_groups.append(group)
    check(source_groups.size()>=12,"Original Gallery supplies at least twelve distinct groups without presentation resources")
    if source_groups.size()<12:host.free();renderer.audio.close();return
    for ordinal in 12:
        var group:Dictionary=source_groups[ordinal]
        host.timeline.current=group;host.timeline.group_start_ms=float(ordinal)
        host.timeline.queue=source_groups.slice(ordinal+1,mini(ordinal+4,source_groups.size()))
        host.timeline.revision+=1
        var result:Dictionary=renderer.prepare([group],index.cache,host,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000},false,float(ordinal))
        check(result.ready,"Actual resource-empty group "+str(group.id)+" remains ready")
    check(native.calls==1,"Twelve distinct source-empty groups perform one native admission, despite changing canonical revision/clock/lookahead")
    var frozen:int=host.timeline.resource_revision
    host.timeline.resource_revision+=1
    renderer.prepare([host.timeline.current],index.cache,host,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000},false,20.0)
    check(native.calls==2 and host.timeline.resource_revision==frozen+1,"A true resource revision still refreshes admission under the same group")
    renderer.invalidate_preparation()
    renderer.prepare([host.timeline.current],index.cache,host,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000},false,20.0)
    check(native.calls==3,"Published world/actor membership still refreshes admission")
    var pending:Dictionary={"id":"real-required-cut","kind":"native_effect","native_spell":true,"start_ms":100.0,"status":"available"}
    var future:Dictionary={"id":"future","components":[pending],"duration_ms":1000.0}
    host.timeline.queue=[future]
    renderer.prepare([host.timeline.current],index.cache,host,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000},false,20.0)
    check(native.calls==3,"A newly received optional source does not invalidate current required readiness")
    renderer.prepare_optional(host,index.cache,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000})
    check(native.optional_ids==[pending.id],"The existing optional lane still receives the changed lookahead source")
    var requested:Dictionary={"id":"required","components":[pending],"duration_ms":1000.0}
    renderer._prepared_resource_groups=[requested]
    check(not renderer._same_resource_groups([host.timeline.current]),"Withdrawing a genuinely required component cannot borrow empty-group readiness")
    renderer._prepared_resource_groups=[host.timeline.current]
    check(not renderer._same_resource_groups([requested]),"A newly required component cannot borrow source-empty readiness")
    var constructor:Dictionary={"id":"constructor","components":[],"native_requirements":[pending]}
    check(not renderer._same_resource_groups([constructor]),"A genuine compiled native constructor requirement invalidates empty-group readiness")
    evidence.empty_groups_tested=12;renderer.audio.close();host.free()

func optical_track_and_horizon(index:Dictionary)->void:
    var track:Dictionary={};var incoming:Dictionary={};var persistent:RefCounted
    for entry in index.groups:
        if track.is_empty():
            for candidate in entry.group.actor_tracks:
                if candidate.clip=="Run":track=candidate;break
        if incoming.is_empty() and entry.start_ms>5000:
            for component in entry.group.components:
                if component.get("native_spell",false):
                    incoming={"id":entry.group.id,"components":[component],"duration_ms":entry.group.duration_ms,"preview_start_ms":entry.start_ms};break
        if persistent!=null:continue
        for commit in entry.group.commits:
            if commit.get("condition_rows",[]).is_empty():continue
            var candidate:RefCounted=Fixtures.Recording.restore(index,entry.start_ms+float(commit.at_ms))
            if not candidate.condition_owners.is_empty():persistent=candidate;break
    check(not track.is_empty() and not incoming.is_empty() and persistent!=null,"Actual recording supplies movement, a later native spell and a persistent condition owner")
    if track.is_empty() or incoming.is_empty() or persistent==null:return
    var host=Host.new();root.add_child(host);host.timeline=persistent
    var renderer=Renderer.new();var native=NativeSpy.new()
    renderer.native_spells=native;renderer.native_hits=HitSpy.new();renderer.blood=BloodSpy.new()
    renderer.epoch=host.timeline.initialization_revision
    var resting:Dictionary={"id":"passive-rest","components":[],"actor_tracks":[],"duration_ms":0.0}
    host.timeline.current=resting;host.timeline.queue=[]
    renderer.prepare([resting],index.cache,host,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000},false,INF)
    var original_native:Array=native.optical_components
    check(not original_native.is_empty(),"Actual persistent condition contributes its optical receiving requirement")
    var moving:Dictionary={"id":"passive-track","components":[],"actor_tracks":[track],"duration_ms":0.0}
    host.timeline.current=moving
    var before:int=native.calls
    renderer.prepare([moving],index.cache,host,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000},false,INF)
    check(native.calls==before+1 and native.optical_tracks.size()==1 and is_same(native.optical_tracks[0],track),
        "A new actual track-only input reaches optical preparation with the persistent receiver still present")
    check(native.optical_components.any(func(component):return component.get("condition_uuid")!=null),"Track admission preserves the real condition's source identity")
    # Exact authored preview time from this original recording. Only the
    # preparation clock is varied; the queue, current group and owners stay put.
    host.timeline.current=resting;host.timeline.group_start_ms=0.0;host.timeline.display_ms=0.0
    host.timeline.queue=[incoming]
    renderer.prepare([resting],index.cache,host,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000},false,0.0)
    var cutoff:float=float(incoming.preview_start_ms)-Renderer.NATIVE_PREFETCH_MS
    check(is_equal_approx(renderer._next_optional_cue_ms,cutoff) and cutoff>0,"Optional deadline is the actual next source's start minus the existing four-second horizon")
    var signature:Array=renderer._optional_owner.duplicate()
    host.timeline.display_ms=cutoff-0.001
    renderer.prepare_optional(host,index.cache,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000})
    check(not renderer._optional_components.any(func(component):return component.id==incoming.components[0].id),"Before the temporal cut the future source remains outside the preparation horizon")
    host.timeline.display_ms=cutoff
    before=native.calls
    renderer.prepare_optional(host,index.cache,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000})
    check(renderer._optional_owner==signature and native.calls>before and incoming.components[0].id in native.optional_ids,
        "Crossing the exact temporal cut prepares the original source even when group/queue/resource identity is unchanged")
    before=native.calls
    renderer.prepare([resting],index.cache,host,{"frame":Engine.get_process_frames(),"used_usec":0,"limit_usec":1000000},false,cutoff)
    check(native.calls==before,"Optional temporal admission does not invalidate already-qualified required readiness")
    evidence.optical_track=track.clip;evidence.optional_cutoff_ms=cutoff
    renderer.audio.close();host.free()

func actual_condition_cuts(index:Dictionary)->void:
    var host=Host.new();root.add_child(host);host.timeline=Fixtures.Recording.Timeline.new()
    var initialization:Dictionary=index.initialization.duplicate(true)
    host.timeline.accept(initialization)
    var renderer=Renderer.new();var native=NativeSpy.new();renderer.native_spells=native
    var applications:int=0;var removals:int=0
    for entry in index.groups:
        for commit in entry.group.commits:
            var scope:Array=renderer._resource_scope(host)
            Fixtures.Recording.Compiler.apply_delta(host.timeline.state,commit.delta)
            host.timeline._observe_resource_owners(commit.delta,entry.start_ms+commit.at_ms,commit.get("condition_rows",[]),str(commit.get("event_uuid","")),{},commit.get("item_rows",[]))
            var membership:bool=false
            for row in commit.get("condition_rows",[]):
                if row.before==null and row.after!=null:applications+=1;membership=true
                elif row.before!=null and row.after==null:removals+=1;membership=true
            if membership:check(renderer._resource_scope(host)!=scope,"Original condition UUID admission/removal invalidates the required resource proof at its actual commit")
    check(applications>0 and removals>0,"Original Gallery supplies positive condition applications and removals")
    evidence.condition_applications=applications;evidence.condition_removals=removals
    renderer.audio.close();host.free()

func recorded_projection(index:Dictionary)->void:
    var metadata:Dictionary=RecordingMedia.plan(index)
    check(metadata.errors.is_empty(),"Original Gallery source publication resolves")
    var player=Player.new()
    player.timeline.accept(index.initialization)
    player._reset_media_epoch();player.external_playback=true
    player.media_warmup.encounter_override=metadata
    var previous:Dictionary={};var reused:int=0;var compared:int=0
    var frozen:PackedByteArray=var_to_bytes(player.timeline.state)
    for entry in index.groups:
        var group:Dictionary=entry.group
        var exact:Dictionary=metadata.group_plans[group.id]
        # Independent expected selection: retain ordinary physical paths and
        # only the actual profile's normal alternatives from the supplied map.
        for profile in ["original","gentle","reference"]:
            var alternatives:Dictionary={};var chosen:Dictionary={}
            for variants in exact.get("normal_sets",{}).values():
                for path in variants.values():alternatives[path]=true
                if variants.has(profile):chosen[variants[profile]]=true
            var expected:Dictionary={}
            for path in exact.character:
                if not alternatives.has(path) or chosen.has(path):expected[path]=exact.character[path]
            check(exact.character_profiles[profile]==expected,"Original group "+str(group.id)+" has independently selected "+profile+" paths")
        player.timeline.current=group;player.timeline.queue=[]
        player._prepare_media()
        check(player.media_plan.required==exact.character_profiles[player.character_light_profile],"Ordinary Play borrows this group's exact prepared paths")
        if not previous.is_empty() and is_same(previous.paths,exact.character_profiles[player.character_light_profile]):
            check(is_same(previous.required,player.media_plan.required),"Unchanged physical source cut preserves required-map identity across original groups")
            reused+=1
        previous={"paths":exact.character_profiles[player.character_light_profile],"required":player.media_plan.required}
        compared+=1
    check(reused>=12,"Actual repeated Gallery cuts reuse prepared source/path identity")
    var current:Dictionary=index.groups[0].group
    player.timeline.current=current;player.timeline.queue=[];player._prepare_media()
    var required:Dictionary=player.media_plan.required
    player.timeline.queue=[index.groups.back().group];player._prepare_media()
    check(is_same(required,player.media_plan.required),"A different optional upcoming group preserves the current immutable required map")
    player.character_light_profile="original";player.media_plan_key=[];player._prepare_media()
    check(player.media_plan.required==metadata.group_plans[current.id].character_profiles.original \
        and not is_same(required,player.media_plan.required),"Changing the actual selected normal profile replaces required readiness operands")
    check(var_to_bytes(player.timeline.state)==frozen,"Resource-window selection never changes canonical state or event order")
    evidence.recorded_groups=compared;evidence.reused_adjacent_cuts=reused
    Media.close(player.media_warmup);player._exit_tree();player.context_menu.free();player.free()

func run()->void:
    profile_contract()
    var index:Dictionary=Fixtures.read("gallery","amber")
    check(index.ok,"Stable original schema16 Gallery recording admits")
    if index.ok:
        var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups])
        empty_resource_groups(index)
        optical_track_and_horizon(index)
        actual_condition_cuts(index)
        recorded_projection(index)
        check(var_to_bytes([index.initialization,index.groups])==immutable,"All source/clock controls preserve the unchanged original recording")
    var result:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"CPU-only original recording/source-contract reuse; no native-output or live-frame claim"}
    FileAccess.open("res://.runtime/source-cut-reuse-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("SOURCE_CUT_REUSE ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
