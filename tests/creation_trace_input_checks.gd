extends SceneTree
## Actual original spatial creation and actor birth own finite optical traces.
## No armed/payload/body/trail semantics or native pixels are inferred here.
const Build=preload("res://tools/presentation_build/abilities.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Journal=preload("res://sdk/journal.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Creation=preload("res://presentation/creation_inputs.gd")
const Birth=preload("res://presentation/actor_birth_inputs.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Compare=preload("res://tests/schema16_fold_vectors_checks.gd")
const Report=preload("res://studio/capability_report.gd")
const Studio=preload("res://studio/studio.gd")
const CASES={
    "glyph_of_warding":{"folder":"scenarios/glyph-warding-trigger","case":"spell.glyph_of_warding/arm_move_enter_trigger","clip":"bg3-36/glyph-of-warding/hand_to_observed_origin","kind":"spatial_creation","identity":"90b31c3c-9fd2-4fe1-b637-ee0e7fcb5f3a","source":"43","admission":"38","publication":"39"},
    "flaming_sphere":{"folder":"effect-owned-actors/flaming-sphere","case":"spell.flaming_sphere/baseline","clip":"bg3-36/flaming-sphere/hand_to_ground_preparation","kind":"actor_birth","identity":"f0dcbb26-c72b-4d7b-b8bd-2a87bc4ceff3","source":"72","admission":"69","publication":"69"}}
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("CREATION_TRACE_FAIL ",label)
static func source_cache()->Dictionary:
    var entries:Dictionary={};var paths:Dictionary={}
    for name in CASES:
        var id:String="spell."+name;var path:String="res://authoring/abilities/spells/"+id+".tres"
        entries[id]=load(path);paths[id]=path
    var built:Dictionary=Build.documents({"spells":entries,"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},{"spells":paths})
    var cache:Dictionary={};var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate();index.spells=admitted.index.spells.duplicate();index.spells.merge(paths,true)
    var loaded:Dictionary=admitted.loaded.duplicate();loaded.merge(built.native.records,true)
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache
static func observed(owner:Dictionary,descriptor:Dictionary,graph:Dictionary,commits:Array)->Array:
    return Birth.observed(owner,descriptor,graph,commits) if descriptor.kind=="actor_birth" else Creation.spatial_destinations(owner,descriptor,graph,commits)
func run()->void:
    var count:int=0
    for name in CASES:
        var entry:Resource=load("res://authoring/abilities/spells/spell."+name+".tres")
        var cue:Resource=entry.effects[0]
        check(cue.extra.observed_destination.kind==CASES[name].kind,name+" actual finite phase has its exact public admission selector")
        check(cue.extra.live_endpoints==[{"actor":"caster","socket":"cast_hand"},{"cue_point":"target"},{"cue_point":"source"}],name+" source tuple retains actual caster hand, admitted target and release source")
        check(cue.extra.source_launch_local==.3 and cue.extra.source_contact_local==.75,name+" complete source-local preparation and travel remain authored")
        for seat in ["amber","blue"]:count+=read_seat(name,seat,cue.extra.observed_destination)
    check(count==4,"Both finite phases qualify from both independent original seats")
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Actual native16 creation/birth ancestry, separate public identities, later-of-public/mechanical admission, finite source clock, immutable structured/human Studio inspection and ordinary compiler/timeline replay. Glyph armed/payload and Flaming body/trail/contact, native pixels and art acceptance remain separate."}
    FileAccess.open("res://.runtime/creation-trace-input-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("CREATION_TRACE_INPUTS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func read_seat(name:String,seat:String,descriptor:Dictionary)->int:
    var spec:Dictionary=CASES[name];var label:String=name+"/"+seat
    var directory:String="res://tests/fixtures/schema16/"+spec.folder+"/"+seat
    var journal:RefCounted=Journal.new();check(journal.open(directory,true,false).ok,label+" unchanged original prefix opens")
    var cache:Dictionary=source_cache();var initial:Dictionary={};var groups:Array=[];var duration:float=0.0;var count:int=0
    var sequence:int=0
    while FileAccess.file_exists(directory.path_join("%016d.json"%sequence)):
        var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join("%016d.json"%sequence))
        var decoded:Dictionary=journal.decode_record(sequence,raw);check(decoded.ok,label+" actual record admits "+str(sequence))
        if not decoded.ok:return count
        var before:Dictionary=journal.state
        var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true);check(folded.ok,label+" original record folds "+str(sequence))
        if not folded.ok:return count
        sequence+=1
        if sequence==1:initial=journal.state;continue
        var held:PackedByteArray=var_to_bytes([before,folded.normalized])
        var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
        check(compiled.ok,label+" ordinary source cohort compiles "+str(sequence-1))
        if not compiled.ok:return count
        groups.append_array(compiled.value.groups)
        var group_starts:Array=[]
        for group in compiled.value.groups:
            group_starts.append(duration);duration+=float(group.duration_ms)
        for index in folded.normalized.lineages.size():
            var group:Dictionary=compiled.value.groups[index]
            var lineage:Dictionary=Occurrences.group(folded.normalized.lineages[index])
            var graph:Dictionary={"nodes":{},"body_records":lineage.get("bodies",[]),"contacts":{}}
            var owner:Dictionary={}
            for node in lineage.events:
                graph.nodes[node.lineage_id]=node
                if node.get("fact")!=null and node.fact.get("kind")=="spell" and node.fact.get("behavior_id")=="spell."+name:owner=node
            for actor in journal.state.actors.values():
                if actor.last_visual_position!=null:
                    var tile:Dictionary=journal.state.tiles.get("%d,%d"%actor.last_visual_position,{})
                    if tile.has("elevation_steps"):graph.contacts[actor.uuid]={"from_elevation_feet":float(tile.elevation_steps)*5.0}
            var rows:Array=group.components.filter(func(row):return row.get("native_clip",{}).get("id")==spec.clip)
            if not owner.is_empty():
                var actual:Array=observed(owner,descriptor,graph,group.commits)
                check(actual.size()==1 and rows.size()==1,label+" exactly one actual admission owns one finite source")
                if actual.size()==1 and rows.size()==1:
                    count+=1;var destination:Dictionary=actual[0];var component:Dictionary=rows[0]
                    var binding:Dictionary=component.get("native_destination",{})
                    check(not binding.is_empty(),label+" actual projection retains its public admission evidence")
                    if binding.is_empty():continue
                    var commit:Dictionary=group.commits.filter(func(row):return str(row.get("event_uuid",""))==spec.publication)[0]
                    check(component.status=="available" and component.start_ms==commit.at_ms and binding.publication_ms==commit.at_ms,label+" exact actual admission commit owns source age zero")
                    check(component.source_event_uuid==spec.publication and component.source_lineage==destination.node.lineage_id,label+" public source occurrence and lineage remain exact")
                    check(binding.source_occurrence==spec.source and binding.admission_occurrence==spec.admission,label+" rule declaration and public admission identities stay separate")
                    check(component.native_cast_id==owner.id and owner.fact.target_entity_uuid==null,label+" trace does not manufacture a spell target or extra cast")
                    check(component.to_position==[6,7] and component.to_elevation_feet==0.0 and component.ground_target,label+" exact independently recorded world destination has no review offset")
                    check(component.native_cue.launch==.3 and component.native_cue.contact==.75 and is_equal_approx(Playback.source_time(component.native_cue,.6),.6),label+" publication-local phase and source chronology agree")
                    check(is_equal_approx(component.duration_ms,900.0 if name=="glyph_of_warding" else 870.0),label+" full existing finite source and tail remain intact")
                    check(not component.has("native_constructor_inputs") and not binding.has("armed") and not binding.has("payload"),label+" endpoint admission supplies no unrelated private constructor or gameplay state")
                    if name=="glyph_of_warding":
                        check(binding.spatial_effect_uuid==spec.identity and binding.creation_occurrence=="39" and binding.admission_occurrence=="38",label+" public anchor receipt and later created receipt remain distinct")
                    else:
                        check(binding.actor_uuid==spec.identity and binding.birth_occurrence=="62" and binding.body_occurrence=="68" and binding.admission_occurrence=="69",label+" actual birth, body disclosure and spatial admission are separate native identities")
                    var method:Dictionary=Report.native_method(component)
                    check(method.destination_admission==binding,label+" structured Studio inspection preserves every exact original admission identity")
                    check(method.runtime_binding=="not_examined" and method.projected_channels.is_empty(),label+" stored destination evidence does not claim dynamic input or rendered output qualification")
                    check(Studio.effect_lines(component).any(func(line):return line.begins_with("Destination admission:") and ("public admission "+spec.admission) in line and ("publication "+spec.publication) in line),label+" human inspector names the actual separate admission and publication")
                    var retained:PackedByteArray=var_to_bytes(component)
                    method.destination_admission.source_occurrence="inspection-copy-control"
                    if method.destination_admission.has("position"):method.destination_admission.position[0]=-100
                    check(var_to_bytes(component)==retained,label+" editing a copied inspection report cannot modify original runtime admission operands")
                    var casts:Array=group.actor_tracks.filter(func(track):return track.source_event_uuid==owner.id and track.get("activity")=="cast")
                    check(casts.size()==1,label+" finite optical trace inserts no independent casting body")
                    negatives(owner,descriptor,graph,group.commits,destination,label)
                    evidence.append({"case":spec.case,"seat":seat,"publication_ms":group_starts[index]+component.start_ms,"binding":binding,"clip":spec.clip})
        check(var_to_bytes([before,folded.normalized])==held,label+" compile preserves actual canonical prefix and original packet")
    var timeline:RefCounted=Timeline.new();timeline.accept({"kind":"initialization","state":initial,"sequence":0});timeline.accept({"kind":"operation","groups":groups})
    timeline.advance(duration+1500.0)
    check(not timeline.busy() and Compare.difference(timeline.state,journal.state).is_empty(),label+" ordinary timeline retains exact independent canonical final state")
    var replay:RefCounted=Timeline.new();replay.accept({"kind":"initialization","state":initial,"sequence":0});replay.accept({"kind":"operation","groups":groups});replay.advance(duration+1500.0)
    check(Compare.difference(replay.state,journal.state).is_empty(),label+" rewind/replay preserves original canonical facts and no new lifetime")
    return count
func negatives(owner:Dictionary,descriptor:Dictionary,graph:Dictionary,commits:Array,destination:Dictionary,label:String)->void:
    var held:PackedByteArray=var_to_bytes([owner,descriptor,graph,commits])
    var canceled:Dictionary=owner.duplicate(true);canceled.canceled=true
    check(observed(canceled,descriptor,graph,commits).is_empty(),label+" canceled declaration cannot admit a trace")
    var wrong:Dictionary=descriptor.duplicate(true)
    wrong["creature_id" if descriptor.kind=="actor_birth" else "content_id"]="not-the-original-content"
    check(observed(owner,wrong,graph,commits).is_empty(),label+" unrelated content cannot replace actual destination")
    var absent:Array=commits.duplicate(true)
    for commit in absent:
        if descriptor.kind=="actor_birth":commit.delta.get("actors",{}).erase(destination.target_uuid)
        else:
            var absent_senses:Variant=commit.delta.get("set",{}).get("senses")
            if absent_senses!=null:
                for effect in absent_senses.spatial_effects.values():effect.erase("anchor_position")
    check(observed(owner,descriptor,graph,absent).is_empty(),label+" missing public destination cannot fall back to footprint, cached actor or review point")
    if descriptor.kind=="spatial_creation":
        var lower:Array=commits.duplicate(true)
        for commit in lower:
            var lower_senses:Variant=commit.delta.get("set",{}).get("senses")
            if lower_senses!=null:
                for effect in lower_senses.spatial_effects.values():effect.erase("anchor_elevation_steps")
        check(observed(owner,descriptor,graph,lower).is_empty(),label+" missing actual anchor elevation cannot default to ground")
    else:
        var missing:Dictionary=graph.duplicate(true)
        for record in missing.body_records:record.erase("birth")
        check(observed(owner,descriptor,missing,commits).is_empty(),label+" visible actor alone cannot manufacture birth ancestry")
    check(observed(owner,descriptor,graph,[]).is_empty(),label+" retained or future canonical state cannot replace the actual admission cut")
    if descriptor.kind=="spatial_creation":
        var hidden:Array=commits.duplicate(true)
        for commit in hidden:
            var hidden_senses:Variant=commit.delta.get("set",{}).get("senses")
            if hidden_senses!=null:
                for effect in hidden_senses.spatial_effects.values():effect.apparent_presence=false
        check(observed(owner,descriptor,graph,hidden).is_empty(),label+" withdrawn sensory membership cannot admit an old anchor")
        var undisclosed:Array=commits.duplicate(true)
        for commit in undisclosed:commit.delta.get("set",{})["senses"]=null
        check(observed(owner,descriptor,graph,undisclosed).is_empty(),label+" explicit null sensory after-value refuses missing anchor without a script error")
    var unrelated:Dictionary=graph.duplicate(true)
    for node in unrelated.nodes.values():
        if node.get("fact")!=null and (node.fact.get("operation")=="created" or node.fact.get("creation")!=null):node.parent_lineage=null
    check(observed(owner,descriptor,unrelated,commits).is_empty(),label+" unrelated source branch cannot supply an actual destination")
    check(var_to_bytes([owner,descriptor,graph,commits])==held,label+" positive and negative projection preserve original operands")
