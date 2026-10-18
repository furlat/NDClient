extends SceneTree
## Real condition application owns Shield's gesture; the SDK events stay intact.
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Coverage=preload("res://presentation/condition_coverage.gd")
var checks:=0
var failures:Array=[]
var observations:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("SHIELD_REACTION_FAIL ",label)

func inspect_case(path:String)->void:
    var journal=Journal.new()
    var opened=journal.open(path,true,false)
    check(opened.ok,path+": original server journal admitted")
    if not opened.ok:return
    var replayed=journal.replay(1)
    check(replayed.ok,path+": actual pre-action state reduced")
    if not replayed.ok:return
    var decoded=journal.protocol.decode("PlayerOperation",FileAccess.get_file_as_bytes(path.path_join("0000000000000002.json")))
    check(decoded.ok,path+": actual reaction operation admitted")
    if not decoded.ok:return
    var packet:Dictionary=journal.protocol.normalize("PlayerOperation",decoded.value)
    var original=packet.duplicate(true)
    var cache={}
    var compiled=Compiler.compile(journal.state,packet,cache)
    check(compiled.ok,path+": actual operation compiles")
    if not compiled.ok:return
    var local=cache.duplicate()
    var recipes=cache["catalog/condition_recipes.json"].duplicate()
    recipes["condition.spell.shield"]=recipes["condition.spell.shield"].duplicate()
    recipes["condition.spell.shield"].erase("reactionCastBinding")
    local["catalog/condition_recipes.json"]=recipes
    var baseline=Compiler.compile(journal.state,packet,local)
    check(baseline.ok,path+": same recording admits with only the reaction authoring disabled")
    if not baseline.ok:return
    var events={}
    for lineage in packet.lineages:
        for event in lineage.events:events[event.uuid]=event
    var reactions:Array=[]
    var state=journal.state.duplicate(true)
    check(compiled.value.groups.size()==baseline.value.groups.size(),path+": gesture adds no presentation event group")
    for i in compiled.value.groups.size():
        var group:Dictionary=compiled.value.groups[i]
        var before:Dictionary=baseline.value.groups[i]
        var times={};var base_times={}
        for commit in before.commits:
            if commit.has("event_uuid"):base_times[commit.event_uuid]=commit.at_ms
        for commit in group.commits:
            if commit.has("event_uuid"):times[commit.event_uuid]=commit.at_ms
            Compiler.apply_delta(state,commit.delta)
        check(times==base_times,path+": reaction does not move any authoritative commit")
        check(group.events.map(func(event):return event.event_uuid)==before.events.map(func(event):return event.event_uuid),path+": original event hierarchy/identities remain unchanged")
        var sources:Array=group.components.filter(func(component):return component.get("native_spell",false))
        var old_sources:Array=before.components.filter(func(component):return component.get("native_spell",false))
        check(sources.map(func(component):return [component.source,component.start_ms,component.duration_ms,component.get("intercepted_by_condition_uuid")])==old_sources.map(func(component):return [component.source,component.start_ms,component.duration_ms,component.get("intercepted_by_condition_uuid")]),path+": cast gesture duplicates neither native Shield nor hostile deliveries")
        for track in group.actor_tracks:
            if not track.has("reaction_cast_binding"):continue
            reactions.append(track)
            var node:Dictionary=events[track.source_event_uuid]
            var fact:Dictionary=node.fact
            var body:Dictionary=Compiler.Components.NativeSpells.recipe({"behavior_id":track.reaction_cast_binding},cache).cast
            var clip:Dictionary=Compiler.Authoring.clip(track.presentation_actor,track.clip,cache)
            check(fact.kind=="condition" and fact.event_type=="condition_application" and fact.condition.behavior_id=="condition.spell.shield",path+": actual Shield application owns its gesture without a fabricated SpellFact")
            check(track.actor_uuid==fact.target_entity_uuid and track.condition_uuid==fact.condition.condition_uuid,path+": recipient Blue owns its exact reaction and condition instance")
            check(track.clip==body.actionClip and track.activity=="cast" and track.hidden_slots==["weapon","offhand"],path+": existing authored cast pose/equipment policy is reused")
            check(track.effect_layers.size()==1 and track.effect_layers[0].category=="Magic2",path+": same approved hand-magic policy applies without caster aura")
            check(is_equal_approx(track.contact_ms,times[node.uuid]) and track.start_ms>=0,path+": release equals the unchanged actual condition commit, with bounded pre-roll")
            var sampled:Dictionary=Compiler.Tracks.samples([track],track.contact_ms)[track.actor_uuid]
            check(is_equal_approx(sampled.source_seconds,float(body.releaseFrame)/clip.fps),path+": actual release samples the exact authored source frame")
            var hostile:Array=group.actor_tracks.filter(func(other):return other.actor_uuid!=track.actor_uuid and events[other.source_event_uuid].fact.get("behavior_id")=="spell.magic_missile")
            check(hostile.size()==1 and track.target_position==hostile[0].from_position and track.from_position==hostile[0].target_position,path+": Blue faces the disclosed Amber threat; Amber retains its own cast")
            var hands:Array=group.components.filter(func(component):return component.kind=="sprite_layer" and component.source_event_uuid==node.uuid)
            check(hands.size()==1 and hands[0].actor_uuid==track.actor_uuid and hands[0].source=="spells/spell.shield.json:/cast" and hands[0].body_track_id==track.trace_track_id,path+": real condition event owns its correctly sourced hand-magic track")
            var trace:Array=group.events.filter(func(event):return event.event_uuid==node.uuid)
            check(trace.size()==1 and trace[0].components.any(func(component):return component.kind=="body" and component.get("reaction_cast_binding")=="spell.shield" and component.trace_track_id==track.trace_track_id),path+": reaction body registers its own exact event witness")
            check(trace[0].components.all(func(component):return component.status!="missing"),path+": Shield event has no unprocessed authored body/hand requirement")
            check(group.duration_ms>=track.start_ms+track.duration_ms,path+": authored recovery stays inside presentation duration")
            crop_boundary(node,track,body,cache)
            observations.append({"journal":path,"condition_uuid":track.condition_uuid,"actor":track.actor_uuid,"clip":track.clip,"start_ms":track.start_ms,"release_ms":track.contact_ms,"end_ms":track.start_ms+track.duration_ms,"target_position":track.target_position,"hand_layers":track.effect_layers.map(func(layer):return layer.category)})
    check(reactions.size()==1,path+": exactly one reaction gesture, no removal recast")
    check(state==compiled.value.final_state and compiled.value.final_state==baseline.value.final_state,path+": presentation still reaches the exact SDK final state")
    check(packet==original,path+": compiler does not mutate the admitted packet")
    var report=Coverage.build(cache,[],{"condition.spell.shield":true})
    var binding:Array=report.entries[0].requirements.filter(func(requirement):return requirement.mechanism=="cast_binding")
    check(binding.size()==1 and binding[0].status=="unexercised" and binding[0].evidence.is_empty() and not binding[0].rendered,path+": catalog alone does not claim the reaction played")

func crop_boundary(node:Dictionary,source:Dictionary,cast:Dictionary,cache:Dictionary)->void:
    # Reuse the actual actor/event and exact authored clip to test a group
    # boundary. This is a timing-unit case, not another fabricated recording.
    var graph={"positions":{source.actor_uuid:source.from_position},"contacts":{source.actor_uuid:{"from_elevation_feet":0,"to_elevation_feet":0}}}
    for release in [0.0,125.0]:
        var group={"operation_sequence":2,"actor_tracks":[],"skipped":[]}
        var track=Compiler._cast_track(group,node,source.presentation_actor,{"cast":cast},"spell.shield",0.0,source.target_position,graph,cache,release)
        var sample=Compiler.Tracks.samples([track],release)[source.actor_uuid]
        var clip=Compiler.Authoring.clip(source.presentation_actor,cast.actionClip,cache)
        check(track.start_ms==0 and track.source_start_seconds>0 and track.contact_ms==release,"Bounded reaction windup crops source without delaying a group-start application")
        check(is_equal_approx(sample.source_seconds,float(cast.releaseFrame)/clip.fps),"Cropped reaction still reaches the authored release frame at the real contact")
    var contact={"from_elevation_feet":source.get("from_elevation_feet",0),"to_elevation_feet":source.get("to_elevation_feet",0)}
    graph.positions[source.actor_uuid]=[source.from_position[0]+8,source.from_position[1]+8]
    graph.contacts[source.actor_uuid]={"from_elevation_feet":50,"to_elevation_feet":50}
    graph.reaction_contacts={node.uuid:{"position":source.from_position,"contact":contact}}
    graph.nodes={};graph.ends={};graph.spell_sources={};graph.actor_inputs={node.uuid:{source.actor_uuid:source.presentation_actor}}
    graph.recipes={node.uuid:Compiler.Authoring.load_data("catalog/condition_recipes.json",cache)["condition.spell.shield"]}
    var group={"operation_sequence":2,"actor_tracks":[],"skipped":[],"duration_ms":source.contact_ms,
        "commits":[{"event_uuid":node.uuid,"at_ms":source.contact_ms}]}
    Compiler._reaction_casts({"events":[node]},{},group,graph,cache)
    check(group.actor_tracks.size()==1 and group.actor_tracks[0].from_position==source.from_position and group.actor_tracks[0].to_position==source.from_position and group.actor_tracks[0].from_elevation_feet==contact.from_elevation_feet,"Reaction contact remains at its actual sampled position/elevation when later group movement changes the graph")

func run()->void:
    for faction in ["amber","blue"]:inspect_case("res://.runtime/studio-spells-20261015/shield-seed3/"+faction+"/journal")
    var report={"checks":checks,"failures":failures,"observations":observations,"scope":"Actual two-perspective Shield recording; shared cast-track timing, real recipient/condition ownership, unchanged commits and SDK state. Headless semantic coverage, not native pixel qualification."}
    FileAccess.open("res://.runtime/shield-reaction-cast-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("SHIELD_REACTION_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
