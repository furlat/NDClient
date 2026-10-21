extends SceneTree
## Source-owner contract: retained scopes, role promotion/cancellation and real
## authored opening versus later cues. CPU-only; no native pixel/FPS claim.
const Media=preload("res://presentation/media_warmup.gd")
const Geometry=preload("res://presentation/character_geometry.gd")
const Protocol=preload("res://sdk/protocol.gd")
const Reducer=preload("res://sdk/reducer.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Characters=preload("res://presentation/characters.gd")
const Player=preload("res://play.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
var recorded_sequences:int=0
var selected_sequences:Array=[1,2,3,4,5,6]
var fireball_sequence:int=5
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("SOURCE_REQUIREMENTS_FAIL ",label)

func immutable_metadata()->void:
    var first:Dictionary=Media.source_record({"shared":"/unused/shared.png","first":"/unused/first.png"},{"shared":true})
    var second:Dictionary=Media.source_record({"shared":"/unused/shared.png","second":"/unused/second.png"},{},{"shared":true})
    var sizes:Dictionary={"shared":64,"first":128,"second":256};sizes.make_read_only()
    var parts:Array=[Media._source_family([first],sizes),Media._source_family([second],sizes)]
    var combined:Dictionary=Media._combine_source_families(parts)
    var expected:Dictionary=Media._source_family([first,second],sizes)
    for field in ["paths","environment","fixtures","cpu_required","gpu_only","ordered_paths","source_sizes"]:
        check(combined[field]==expected[field],"Retained source-family composition preserves exact "+field)
    var cache:Dictionary={"__source_record_sets":{},"__required_headers":{"unrelated":{"width":999,"height":999}}}
    var environment:Dictionary={"source_sizes":{"shared":64},"source_headers":{"shared":{"width":4,"height":4}}}
    var packet:Dictionary={"source_sizes":{"first":128},"source_headers":{"first":{"width":4,"height":8}}}
    var character:Dictionary={"actor_records":{"a":[packet],"b":[packet]}}
    var opening:Dictionary=Media._source_size_union(character,environment,cache,true)
    var complete:Dictionary=Media._source_size_union(character,environment,cache,false)
    check(is_same(opening,complete) and opening=={"shared":64,"first":128},
        "Opening and completion borrow one immutable size projection of the same physical source operands")
    var headers:Dictionary=Media._source_size_headers(opening,cache)
    check(headers.keys()==["shared","first"] and not headers.has("unrelated") \
        and is_same(headers,Media._source_size_headers(complete,cache)),
        "Header publication borrows only the selected source facts even when optional catalog headers are present")
    character.actor_records.b=[{"source_sizes":{"second":256}}]
    var changed:Dictionary=Media._source_size_union(character,environment,cache,false)
    check(changed==sizes and not is_same(changed,opening) and opening=={"shared":64,"first":128},
        "A newly selected source changes only the new size owner without editing the displayed one")

func actor_source_inputs(actor:Dictionary)->void:
    var after:Dictionary=actor.duplicate()
    after.normal_hp=int(actor.get("normal_hp",0))+1;after.last_visual_position=[123,456]
    check(Media._same_actor_source_inputs(actor,after),"HP/position after-values reuse their actual immutable source selectors")
    after.appearance=actor.appearance.duplicate();after.appearance.skin_tint=123
    check(Media._same_actor_source_inputs(actor,after),"Tint changes do not select another physical sprite family")
    after.appearance.body_category="DifferentAuthoredBody"
    check(not Media._same_actor_source_inputs(actor,after),"A changed authored body cannot borrow the previous source selector")
    after=actor.duplicate();after.presentation_layers=[{"slot":"effect","category":"DifferentAuthoredEffect"}]
    check(not Media._same_actor_source_inputs(actor,after),"Per-track effect operands invalidate the physical layer selector")
    after=actor.duplicate();after.life_state="dead" if actor.life_state!="dead" else "alive"
    check(not Media._same_actor_source_inputs(actor,after),"Lifecycle changes reselect the authored resting source")
    after=actor.duplicate();after.conditions=actor.get("conditions",[]).duplicate()
    check(not Media._same_actor_source_inputs(actor,after),"A new condition operand is resolved before borrowing its pose and media sources")

func first_use_owner(actor:Dictionary,cache:Dictionary)->void:
    var paths:Dictionary={};var gpu:Dictionary={};var cpu:Dictionary={};var optics:Dictionary={};var normals:Dictionary={}
    var errors:Array=[];var requested:Array=[];var reuse:Dictionary=Media._actor_reuse(cache)
    Media._add_actor_once(paths,actor,[],cache,errors,gpu,cpu,false,optics,normals,requested,reuse)
    check(errors.is_empty() and not requested.is_empty(),"Actual actor source packet is admitted before its first-use occurrence")
    if not errors.is_empty() or requested.is_empty():return
    var packet:Dictionary=requested[0].packet
    # The source owner already supplied these role projections. A later use
    # may borrow them but cannot edit or reconstruct their global membership.
    for roles in [gpu,cpu,optics,normals]:roles.make_read_only()
    var times:Dictionary={};var count:int=requested.size()
    Media._actor_first_use(times,actor,[],25.0,cache,errors,gpu,cpu,false,optics,normals,requested,reuse)
    check(requested.size()==count+1 and is_same(requested[-1].packet,packet) and errors.is_empty(),
        "First-use retains the exact actor/clip/native-optics packet as a separate group occurrence")
    check(times.size()==packet.paths.size() and times.keys().all(func(path):return packet.paths.has(path) and times[path]==25.0),
        "Borrowed source occurrence records the exact authored first-use clock without replaying role projection")

func finite_role_views(cache:Dictionary)->void:
    var base:Dictionary={"source":"selected physical clip"}
    var obsolete:Dictionary={"source":"unselected old clip"}
    var ordinary:Dictionary={"base":base,"native_optics":false}
    var native:Dictionary={"base":base,"native_optics":true}
    var old:Dictionary={"base":obsolete,"native_optics":true}
    var reuse:Dictionary={"current":[ordinary],"previous":[ordinary,native,old],"selected_actors":{},"hits":0,"misses":0}
    Media._retain_actor_closures(cache,reuse)
    var retained:Array=cache.__required_actor_closures.entries
    check(retained.size()==2 and is_same(retained[0],ordinary) and is_same(retained[1],native),
        "A selected physical base retains exactly its ordinary/native optical views without an unselected clip history")
    reuse.current=[native];reuse.previous=retained
    Media._retain_actor_closures(cache,reuse)
    retained=cache.__required_actor_closures.entries
    check(retained.size()==2 and is_same(retained[0],native) and is_same(retained[1],ordinary),
        "Changing current optical roles borrows its retained opposite view without recreating source metadata")
    reuse.current=[];reuse.previous=retained
    Media._retain_actor_closures(cache,reuse)
    check(cache.__required_actor_closures.entries.is_empty(),
        "The final physical base leaving scope retires both metadata views")

func roles()->void:
    var a:Dictionary=Media.create();var b:Dictionary=Media.create();Media.share(b,a)
    for data in [a,b]:Media.adopt_required(data,1)
    var background:Dictionary={}
    for i in 4000:background["background/%d"%i]="/unused/background/%d.png"%i
    var shared:Dictionary=Media.source_record(background,{},{},background)
    var first:Dictionary=Media.source_record({"first":"/unused/first.png"},{},{},{"first":true})
    var second:Dictionary=Media.source_record({"second":"/unused/second.png"},{},{},{"second":true})
    Media.demand_records(a,[shared,first])
    check(not Media.physical(a).has("environment") and not Media.physical(a).has("fixtures") \
        and not Media.physical(a).has("cpu_required") and not Media.physical(a).has("gpu_only"),
        "Physical source interests are the single aggregate optical-role owner")
    check(a.wanted.size()==4001 and not a.cpu_required.has("first"),"One immutable background scope and GPU action pin their actual sources")
    Media.demand_records(a,[shared,second])
    check(a.wanted.size()==4001 and not a.wanted.has("first") and a.wanted.has("second"),"Replacing an action preserves the retained background membership")
    check(a.demand_counts.records_retained==1 and a.demand_counts.source_roles_visited==2 and a.demand_counts.affected==2,"Changed-source work is two sources despite 4,000 retained sources")
    Media.demand_records(a,[shared,second])
    check(a.demand_counts.source_roles_visited==0 and a.demand_counts.affected==0,"Publishing identical owner references performs no retained-source role work")
    var fixture:Dictionary=Media.source_record({"second":"/unused/second.png"},{},{"second":true})
    Media.published(a,{"path":"second","cpu_bytes":0,"gpu_bytes":64})
    Media.demand_records(b,[fixture])
    check(Media.ready(a,{"second":true}) and not Media.ready(b,{"second":true}),"Fixture promotion waits only for its own consumer's missing CPU data")
    Media.published(b,{"path":"second","cpu_bytes":64,"gpu_bytes":64,"energy":1.0,"emission_centroid":Vector2.ZERO})
    check(Media.ready(a,{"second":true}) and Media.ready(b,{"second":true}),"One source publication satisfies independent GPU and fixture requirements")
    Media.demand_records(a,[])
    check(Media.physical(b).wanted.has("second") and Media.ready(b,{"second":true}),"Cancelling one scope does not release the other consumer's required pin")
    Media.demand_records(b,[])
    check(not Media.physical(b).wanted.has("second"),"Last required owner releases its source pin")
    Media.close(a);Media.close(b)

func later_publication()->void:
    var a:Dictionary=Media.create();var b:Dictionary=Media.create();Media.share(b,a)
    for data in [a,b]:Media.adopt_required(data,1)
    var first:Dictionary=Media.source_record({"first":"/unused/first.png"},{},{},{"first":true})
    var future:Dictionary=Media.source_record({"future":"/unused/future.png"},{},{},{"future":true})
    var later_paths:Dictionary={"future":"/unused/future.png"}
    for i in 80:later_paths["later/%d"%i]="/unused/later/%d.png"%i
    var family:Dictionary={"paths":later_paths,"gpu_only":later_paths,"source_sizes":{}}
    for path in later_paths:family.source_sizes[path]=64
    Media.demand_records(a,[first],{},[family])
    var owner:Dictionary=Media.physical(a)
    var revision:int=owner.selection_revision
    Media.demand_records(b,[],{},[family])
    check(owner.selection_revision==revision,"Another consumer retaining the same later family does not restart its unchanged physical budget decision")
    check(owner.interests.size()==1 and owner.wanted.size()==1 and owner.families.size()==1 and owner.families[0].users==2,
        "Publishing a complete received family retains one shared reference without walking its later roles")
    Media.prepare_optional(a)
    check(owner.interests.size()>1 and owner.interests.size()<=1+Media.OPTIONAL_UPDATES_PER_FRAME \
        and owner.optional_updates<=Media.OPTIONAL_UPDATES_PER_FRAME,
        "Later received roles use the existing bounded optional allowance")
    Media.demand_records(a,[first,future],{},[family])
    check(owner.wanted.has("future") and a.wanted.has("future") and not b.wanted.has("future"),
        "An exact preparing cue promotes its pin synchronously without waiting for optional family accounting")
    Media.published(a,{"path":"future","cpu_bytes":0,"gpu_bytes":64})
    check(Media.prune(a,0).is_empty() and Media.ready(a,{"future":true}),
        "A privately preparing cue's explicit required pin survives memory pressure")
    Media.demand_records(a,[first,future],{},[])
    check(owner.families[0].users==1 and owner.wanted.has("future"),
        "Withdrawing one later family retains another consumer and the independently preparing cue")
    Media.demand_records(b,[],{},[])
    check(owner.families[0].users==0 and not Media._requested(owner,"later/79") and owner.wanted.has("future"),
        "Last speculative withdrawal stops new later decode work immediately without releasing an exact cue")
    Media.demand_records(a,[])
    check(not owner.wanted.has("future"),"Only the final exact owner releases the preparing source pin")
    Media.close(a);Media.close(b)

func partition_ownership()->void:
    var source:Dictionary=Media.source_record({"colour":"/unused/colour.png","normal":"/unused/normal.png"},{},{},{"normal":true})
    var reuse:Dictionary={"previous":[],"current":[]}
    var first:Dictionary=Media._source_cut_schedule([source],{"colour":0.0,"normal":50.0},{},reuse)
    check(record_paths(Media.records_at(first,0.0))=={"colour":true} and record_paths(Media.records_at(first,50.0))=={"colour":true,"normal":true},
        "A mixed descriptor retains exactly the role operands needed by each authored cut")
    var next_reuse:Dictionary={"previous":reuse.current,"current":[]}
    var next:Dictionary=Media._source_cut_schedule([source],{"colour":0.0,"normal":50.0},{},next_reuse)
    check(is_same(first.initial[0],next.initial[0]) and is_same(first.changes[0].records[1],next.changes[0].records[1]),
        "Opening/full preparation borrows the same immutable role partitions instead of replacing unchanged contribution owners")
    var cache:Dictionary={"__source_cut_partitions":reuse.current}
    var retained:Array=cache.__source_cut_partitions
    var opening:Dictionary={"source_sizes":{},"source_records":{"group":{"Off":[source]}}}
    Media._source_publications(opening,cache,true)
    check(is_same(cache.__source_cut_partitions,retained),
        "Initial-only opening does not destroy the previous complete partition owner on its critical path")
    var full:Dictionary={"source_sizes":{},"source_records":{"group":{"Off":[source]}},
        "character_timeline":{"group":{"initial":{"colour":true},"changes":[{"at_ms":50.0,"paths":{"colour":true,"normal":true}}]}}}
    Media._source_publications(full,cache)
    check(is_same(first.initial[0],full.source_cuts.group.Off.initial[0]),
        "Complete continuation reuses its exact previously admitted mixed-role partition after opening")

func hint_roles()->void:
    var a:Dictionary=Media.create();var b:Dictionary=Media.create();Media.share(b,a)
    for data in [a,b]:Media.adopt_required(data,1)
    var required:Dictionary=Media.source_record({"required":"/unused/required.png"},{},{},{"required":true})
    var records:Array=[required];records.make_read_only()
    var paths:Dictionary={"hint":"/unused/hint.png"}
    var gpu:Dictionary={"paths":paths,"gpu_only":{"hint":true}}
    Media.demand_records(a,records,gpu)
    Media.published(a,{"path":"hint","cpu_bytes":0,"gpu_bytes":64})
    check(Media.ready(a,{"hint":true}),"An exact GPU hint is ready without retained CPU pixels")
    var same:Dictionary={"paths":paths.duplicate(),"gpu_only":{"hint":true}}
    Media.demand_records(a,records,same)
    check(a.demand_counts.affected==0 and a.demand_counts.source_roles_visited==0 \
        and is_same(Media.physical(a).consumers[a.consumer_id].records,records),
        "Replacing identical hint roles retains required record ownership and performs no source readiness refresh")
    var cpu:Dictionary={"paths":paths,"cpu_required":{"hint":true}}
    Media.demand_records(b,[],cpu)
    check(Media.ready(a,{"hint":true}) and not Media.ready(b,{"hint":true}),
        "A different consumer's CPU hint promotion changes only its own readiness")
    # Reuse the very same paths map: role ownership changes independently of
    # source membership, so path-map identity cannot mask a fixture upgrade.
    var fixture:Dictionary={"paths":paths,"fixtures":{"hint":true}}
    Media.demand_records(a,records,fixture)
    check(a.demand_counts.affected==0 and not Media.ready(a,{"hint":true}),
        "Common-path optional fixture promotion is exact on query without publishing required roles")
    Media.published(a,{"path":"hint","cpu_bytes":64,"gpu_bytes":64})
    check(not Media.ready(a,{"hint":true}) and Media.ready(b,{"hint":true}),
        "CPU pixels alone satisfy the CPU hint but not the independent fixture metrics gate")
    Media.demand_records(a,records,gpu)
    check(a.demand_counts.affected==0 and Media.ready(a,{"hint":true}) and Media.ready(b,{"hint":true}),
        "Fixture-to-GPU optional hint demotion releases only that consumer's queried gate")
    Media.demand_records(a,records,fixture)
    Media.published(a,{"path":"hint","cpu_bytes":64,"gpu_bytes":64,"energy":1.0,"emission_centroid":Vector2.ZERO})
    check(Media.ready(a,{"hint":true}) and Media.ready(b,{"hint":true}),"One actual metric publication satisfies both exact hint contracts")
    Media.demand_records(a,records,{})
    check(Media.ready(b,{"hint":true}) and a.wanted.has("required") and not a.wanted.has("hint"),
        "Cancelling a hint preserves another consumer and never promotes optional artwork to required")
    Media.close(a);Media.close(b)

func record_paths(records:Array)->Dictionary:
    var paths:Dictionary={}
    for record in records:
        for path in record.roles:paths[path]=true
    return paths

func cuts(complete:Dictionary,group:Dictionary,profile:String,sequence:int)->void:
    var value:Dictionary=complete.value
    var schedule:Dictionary=value.source_cuts[group.id][profile]
    var character:Dictionary=value.character_timeline[group.id]
    var environment:Dictionary=value.environment_timeline[group.id]
    var times:Array=[0.0]
    for change in schedule.changes:times.append(float(change.at_ms))
    for at in times:
        var expected:Dictionary=Geometry.for_profile(Media.required_at(character,at),value.normal_sets,profile).duplicate()
        expected.merge(Media.required_at(environment,at))
        var actual:Dictionary=record_paths(Media.records_at(schedule,at))
        check(actual.size()==expected.size() and expected.keys().all(func(path):return actual.has(path)),
            "Operation %d %s at %s: prepared contribution cut equals actual authored due paths"%[sequence,profile,at])
    var family:Dictionary=value.source_families[group.id][profile]
    var full:Dictionary=record_paths(value.source_records[group.id][profile])
    check(family.paths.size()==full.size() and full.keys().all(func(path):return family.paths.has(path)),
        "Operation %d %s: bounded later family retains the complete received source closure"%[sequence,profile])
    check(full.keys().all(func(path):return family.source_sizes.get(path,-1)==value.source_sizes.get(path,-2)),
        "Operation %d %s: retained family sizes belong to its actual immutable source operands"%[sequence,profile])

func recorded(directory:String)->void:
    var protocol=Protocol.new();var cache:Dictionary={}
    var first:Dictionary=protocol.decode("InitializationResponse",FileAccess.get_file_as_bytes(directory.path_join("0000000000000000.json")))
    check(first.ok,"Actual initialization admits")
    if not first.ok:return
    var initial:Dictionary=protocol.normalize("InitializationResponse",first.value)
    var state:Dictionary=Reducer.reduce_initialization(initial.initialization,initial.content_additions).value
    var source_actor:Dictionary=state.actors.values()[0]
    actor_source_inputs(state.actors.values()[0])
    for sequence in range(1,int(selected_sequences.max())+1):
        var path:String=directory.path_join("%016d.json"%sequence)
        if not FileAccess.file_exists(path):break
        var decoded:Dictionary=protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(path))
        check(decoded.ok,"Actual operation %d admits"%sequence)
        if not decoded.ok:return
        var packet:Dictionary=protocol.normalize("PlayerOperation",decoded.value)
        var reduced:Dictionary=Reducer._reduce_operation_retained(state,packet,true)
        check(reduced.ok,"Actual operation %d reduces"%sequence)
        if not reduced.ok:return
        if sequence not in selected_sequences:state=reduced.value;continue
        if sequence==fireball_sequence:
            check(packet.lineages.any(func(lineage):return lineage.events.any(func(event):return event.get("fact")!=null and event.fact.get("kind")=="spell" and event.fact.get("behavior_id")=="spell.fireball")),"Selected late-source control is an actual native Fireball operation")
        var compiled:Dictionary=Compiler.compile_recorded(state,packet,cache,reduced.value,reduced.transitions)
        check(compiled.ok,"Actual operation %d compiles"%sequence)
        if not compiled.ok:return
        recorded_sequences+=1
        var groups:Array=compiled.value.groups
        if groups.is_empty():state=reduced.value;continue
        var started:int=Time.get_ticks_usec()
        var opening:Dictionary=Media.prepare_opening_handoff(state,groups[0],cache)
        var opening_ms:float=(Time.get_ticks_usec()-started)/1000.0
        var opening_packets:Dictionary=cache.get("__required_actor_closures",{})
        started=Time.get_ticks_usec()
        var complete:Dictionary=Media.prepare_handoff(state,groups,cache,reduced.value)
        var complete_ms:float=(Time.get_ticks_usec()-started)/1000.0
        var size_paths:Dictionary=complete.value.required.duplicate()
        for paths in [complete.value.upcoming,complete.value.environment_required,complete.value.environment_upcoming,complete.value.optical_candidates]:size_paths.merge(paths)
        check(complete.value.source_sizes==Media.EncounterMedia.source_sizes(size_paths,cache),
            "Operation %d: retained actor/environment size contributions equal the complete prior header projection"%sequence)
        for profile in Geometry.PROFILES:
            cuts(complete,groups[0],profile,sequence)
            var paths:Dictionary={};var cpu:Dictionary={};var environment:Dictionary={};var fixtures:Dictionary={}
            for record in complete.value.source_records[groups[0].id][profile]:
                for source in record.roles:
                    var role:Array=record.roles[source];paths[source]=true
                    if role[1]>0:cpu[source]=true
                    if role[2]>0:fixtures[source]=true
                    if role[3]>0:environment[source]=true
            var expected:Dictionary=Geometry.for_profile(complete.value.required,complete.value.normal_sets,profile).duplicate()
            expected.merge(complete.value.environment_required)
            check(paths.size()==expected.size() and expected.keys().all(func(source):return paths.has(source)),"Operation %d %s: contribution scopes equal exact authored first-group source set"%[sequence,profile])
        if not opening.is_empty():
            check(is_same(opening.groups[0],groups[0]) and opening.coverage_until_ms>0,"Opening metadata retains the accepted group owner and its next source deadline")
            var player=Player.new();player.timeline.state=state
            player.media_received_owners[groups[0].id]=groups[0]
            player.media_group_plans[groups[0].id]={"coverage_until_ms":opening.coverage_until_ms}
            player.timeline.current=groups[0];player.timeline.group_start_ms=0.0
            player.timeline.display_ms=0.0;player.timeline.media_target_ms=0.0
            check(player._source_group_ready(groups[0]),"Opening metadata admits its initial display cut")
            player.timeline.media_target_ms=opening.coverage_until_ms
            check(not player._source_group_ready(groups[0]),"Late cue waits for its complete metadata instead of being declared source-ready")
            player.media_group_plans[groups[0].id]={}
            check(not player._source_group_ready(groups[0]),"Missing replacement metadata cannot unblock a late cue")
            player.media_group_plans[groups[0].id]={"character":complete.value.required}
            check(player._source_group_ready(groups[0]),"Completed metadata replaces the partial source deadline")
            Media.close(player.media_warmup);player._exit_tree();player.context_menu.free();player.free()
            var later_sources:Dictionary={}
            for track in groups[0].get("actor_tracks",[]):
                if float(track.start_ms)<=0:continue
                var actor:Dictionary=track.get("presentation_actor",{})
                if actor.is_empty():continue
                var source:Dictionary=Characters.sheet_paths(actor,[track.clip],cache)
                if source.ok:later_sources.merge(source.value)
            var exclusive:int=0
            for source in later_sources:
                if complete.value.required.has(source) and not opening.value.required.has(source):exclusive+=1
            if sequence==fireball_sequence:
                var failure_player=Player.new()
                failure_player.timeline.accept({"kind":"initialization","sequence":0,"state":state})
                failure_player.timeline.current=groups[0];failure_player.timeline.group_start_ms=0.0
                failure_player._reset_media_epoch()
                var full:Dictionary=complete.duplicate()
                full.key=[failure_player.timeline.initialization_revision,complete.groups.map(func(group):return group.id),0]
                failure_player._adopt_media_plan(full,false)
                failure_player._prepare_media()
                var selected:Dictionary=Geometry.for_profile(complete.value.required,complete.value.normal_sets,failure_player.character_light_profile)
                var late_path:String="";var late_at:float=0.0
                for track in groups[0].get("actor_tracks",[]):
                    if float(track.start_ms)<=0:continue
                    var actor:Dictionary=track.get("presentation_actor",{})
                    if actor.is_empty():continue
                    var source:Dictionary=Characters.sheet_paths(actor,[track.clip],cache)
                    if not source.ok:continue
                    for candidate in source.value:
                        if selected.has(candidate) and not opening.value.required.has(candidate):
                            late_path=candidate;late_at=float(track.start_ms);break
                    if not late_path.is_empty():break
                check(not late_path.is_empty(),"Actual Fireball has an independently selected late actor source")
                if not late_path.is_empty():
                    check(not failure_player.media_warmup.wanted.has(late_path),
                        "Complete Fireball metadata keeps its later actor source in bounded family intent rather than synchronous opening demand")
                    failure_player.media_warmup.failed[late_path]="Late Fireball target source unavailable"
                    failure_player._prepare_media()
                    check(failure_player.media_issue.is_empty(),"Full metadata with a failed later Hit/Death source leaves the opening ungated")
                    failure_player.timeline.media_target_ms=late_at;failure_player._prepare_media()
                    check(failure_player.media_warmup.wanted.has(late_path),"The exact Fireball actor cue promotes its source pin before readiness/publication")
                    check(failure_player.media_issue=="Late Fireball target source unavailable","The same source failure is exposed at its authored actor cue")
                    failure_player.media_empty_plan=failure_player.media_group_plans[groups[0].id]
                    failure_player.timeline.current={};failure_player.timeline.queue=[]
                    failure_player._publish_media_interest(late_at)
                    check(failure_player.media_warmup.wanted.has(late_path),"Idle terminal ownership retains final source operands rather than selecting the previous group's initial cut")
                Media.close(failure_player.media_warmup);failure_player._exit_tree();failure_player.context_menu.free();failure_player.free()
                var broken:Dictionary=groups[0].duplicate()
                broken.actor_tracks=groups[0].actor_tracks.map(func(track):return track.duplicate())
                var at:float=0.0
                for track in broken.actor_tracks:
                    if float(track.start_ms)>0:at=float(track.start_ms);track.clip="MissingLateAuthoredSource";break
                # This deliberate failure must not rewind the real six-action
                # selector owner or contaminate the next opening's timings.
                var bad:Dictionary=Media.prepare_handoff(state,[broken],Characters.Catalog.source_snapshot(cache))
                var plan:Dictionary={"errors":bad.value.errors,"error_timeline":bad.value.character_error_timeline[broken.id]}
                check(not bad.value.errors.is_empty() and Media.errors_at(plan,0.0).is_empty(),"Late authoring resolution failure retains its first-use clock")
                check(not Media.errors_at(plan,at).is_empty(),"Late authoring failure becomes actionable when that cue is due")
            evidence.append({"sequence":sequence,"opening_ms":opening_ms,"complete_ms":complete_ms,"deadline_ms":opening.coverage_until_ms,
                "opening_sources":opening.value.required.size(),"complete_sources":complete.value.required.size(),"deferred_late_actor_sources":exclusive,
                "opening_packet_hits":opening_packets.get("hits",0),"opening_packet_misses":opening_packets.get("misses",0),"opening_packet_promotions":opening_packets.get("promotions",0),
                "opening_phases":opening.phases,"complete_phases":complete.phases})
        state=reduced.value
    first_use_owner(source_actor,Characters.Catalog.source_snapshot(cache))
    finite_role_views(Characters.Catalog.source_snapshot(cache))

func run()->void:
    immutable_metadata()
    roles()
    later_publication()
    partition_ownership()
    hint_roles()
    var directory:String=""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--recording="):directory=argument.trim_prefix("--recording=")
        if argument.begins_with("--sequences="):
            selected_sequences=[]
            for part in argument.trim_prefix("--sequences=").split(",",false):selected_sequences.append(int(part))
        if argument.begins_with("--fireball-sequence="):fireball_sequence=int(argument.trim_prefix("--fireball-sequence="))
    check(not directory.is_empty() and selected_sequences.size()==6 and fireball_sequence in selected_sequences,"Supply actual journal, six source operations and its actual Fireball sequence")
    if not failures.is_empty():quit(1);return
    await recorded(directory)
    check(recorded_sequences==6,"All six actual recorded operations reached source qualification without an interrupted reducer/compiler path")
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,"scope":"Independent source-consumer pins and actual Gallery recorded source closures/opening deadlines. CPU only; timings are isolated metadata work, not live onset or frame acceptance."}
    FileAccess.open("res://generated/source_requirement_publication_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
