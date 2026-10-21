extends SceneTree
const Conditions=preload("res://presentation/conditions.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
const Palette=preload("res://presentation/palette.gd")
const NativePersistent=preload("res://presentation/native_persistent.gd")
const Effects=preload("res://presentation/effect_package.gd")
const ComponentRenderer=preload("res://presentation/component_renderer.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
class WitnessWorld extends Node:
    var timeline={"display_ms":600.0}
var checks=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("CONDITION_SELECTION_FAIL ",label)
func owner(condition:Dictionary,initial:bool=false)->Dictionary:
    return {"id":condition.condition_uuid,"actor_uuid":"actor","condition":condition,"initial":initial,"start_ms":0.0,"end_ms":INF,"life_state":"alive"}
## Selector controls use native-shaped members; the separate recorder
## owns actual gameplay evidence. No recorded/native-pixel claim is made here.
func _explicit_lifecycle_owner(cache:Dictionary)->void:
    var identity:String="trait.skeleton_archer_marked"
    var source:Resource=load("res://authoring/abilities/conditions/trait.skeleton_archer_marked.tres")
    check(source.play_package_lifecycle and Array(source.lifecycle_selections)==["condition_guiding_mark_native"],"Marked explicitly selects its installed marker source")
    var selected:Dictionary=Effects.condition_selection("condition_guiding_mark_native")
    var held:Dictionary=selected.duplicate(true)
    check(Effects.conditions(identity).is_empty(),"Explicit Marked assignment does not rewrite the sealed package owner index")
    check(Effects.condition_selection("condition_guiding_mark_native-missing").is_empty(),"An unknown explicit selection is refused rather than guessed")
    var member:Dictionary={"condition_uuid":"actual-shaped-mark-owner","behavior_id":identity,"state":null}
    var record:Dictionary=owner(member);record.start_ms=100.0
    var rows:Array=Conditions.samples({record.id:record},200.0,cache).filter(func(row):return row.has("lifecycle_phases"))
    check(rows.size()==1,"Actual Marked member shape emits one explicit marker occurrence")
    if rows.size()!=1:return
    var component:Dictionary=rows[0]
    check(component.condition_uuid==member.condition_uuid and component.condition.behavior_id==identity and component.actor_uuid==record.actor_uuid,"Marker preserves actual member and recipient identities")
    check(component.spell_id.is_empty(),"Reused marker does not fabricate a Guiding Bolt spell occurrence")
    check(component.lifecycle_marker.group==source.group and component.lifecycle_marker.priority==source.priority,"Explicit marker retains its own authored group rather than merging unrelated Guiding Bolt owners")
    check(component.source.ends_with("::lifecycle_selections/0") and component.lifecycle_source=="assets/vfx/index.json#/selections/condition_guiding_mark_native/condition","Actual resource assignment and delivered source provenance remain distinct")
    check(NativePersistent.lifecycle_state(component,.10).phase=="application" and NativePersistent.lifecycle_state(component,.30).phase=="sustain","Explicit marker follows the actual owner clock through application and hold")
    var another:Dictionary=record.duplicate(true);another.id="other-mark-owner";another.condition.condition_uuid=another.id;another.actor_uuid="other-recipient"
    var other:Array=Conditions.samples({another.id:another},300.0,cache).filter(func(row):return row.has("lifecycle_phases"))
    check(other.size()==1 and other[0].id!=component.id and other[0].condition_uuid!=component.condition_uuid,"Independent real-shaped members retain separate marker occurrences")
    record.end_ms=800.0
    var removed:Array=Conditions.samples({record.id:record},900.0,cache).filter(func(row):return row.has("lifecycle_phases"))
    check(removed.size()==1 and NativePersistent.lifecycle_state(removed[0],.8).phase=="removal","Actual member removal starts the selected source return")
    check(Conditions.samples({record.id:record},1050.0,cache).is_empty(),"Selected marker retires after its real removal tail")
    check(selected==held,"Explicit reuse leaves package owner IDs, phases and marker metadata immutable")
    var isolated:Dictionary=cache.duplicate()
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache).duplicate(true)
    var ordinary:String="condition.spell.guiding_bolt.marked"
    var recipe:Dictionary=recipes.get(ordinary,{}).duplicate(true)
    var persistent:Dictionary=recipe.get("persistent",{}).duplicate(true)
    persistent.lifecycleSelections=["condition_guiding_mark_native"]
    recipe.persistent=persistent;recipes[ordinary]=recipe
    isolated["catalog/condition_recipes.json"]=recipes
    var dedup:Array=NativePersistent.lifecycles({"behavior_id":ordinary,"state":null},isolated)
    check(dedup.filter(func(selection):return selection.key=="condition_guiding_mark_native").size()==1,"Explicit and ordinary owner-indexed selection deduplicate by exact package key")

## Private public-API controls only. Genuine original cast/grant evidence is
## separately retained by the current Library False Life baseline.
func _temporary_hp_grant_owner(cache:Dictionary)->void:
    var source:Resource=load("res://authoring/abilities/conditions/spell.false_life.tres")
    check(source.owner_kind=="temporary_hp_grant" and Array(source.lifecycle_selections)==["condition_aid_retained_native"],"False Life explicitly selects a distinct actual grant owner and existing vitality source")
    var selection:Dictionary=Effects.condition_selection("condition_aid_retained_native")
    var unchanged_selection:Dictionary=selection.duplicate(true)
    var grant:Dictionary={"instance_uuid":"grant-a","source_id":"spell.false_life"}
    var actor:Dictionary={"uuid":"grant-recipient","temporary_hp":6,"temporary_hp_grant":grant,"life_state":"alive"}
    var original:Dictionary=actor.duplicate(true)
    var initial:Dictionary={}
    NativePersistent.observe_grants(initial,{actor.uuid:actor},0.0,cache,true)
    var first:Array=NativePersistent.grant_samples(initial,50.0,cache)
    check(first.size()==1 and first[0].native_grant and first[0].grant_uuid==grant.instance_uuid and first[0].grant_source_id==grant.source_id,"Canonical initial grant retains its exact distinct UUID/source")
    if first.is_empty():return
    check(not first[0].has("condition") and not first[0].has("condition_uuid") and first[0].actor_uuid==actor.uuid and first[0].target_uuid==actor.uuid,"Grant source preserves actual recipient without inventing a ConditionRow or condition UUID")
    check(NativePersistent.lifecycle_state(first[0],.05).phase=="sustain","An initially disclosed grant skips an invented application")
    var applied:Dictionary={}
    var fact:Dictionary={"kind":"temporary_hit_points","entity_uuid":actor.uuid,"resulting_temporary_hp":6,"grant":grant}
    NativePersistent.observe_grants(applied,{actor.uuid:actor},100.0,cache,false,"actual-shaped-grant-event",fact)
    var onset:Array=NativePersistent.grant_samples(applied,150.0,cache)
    check(onset.size()==1 and NativePersistent.lifecycle_state(onset[0],.05).phase=="application" and onset[0].source_event_uuid=="actual-shaped-grant-event","Only the actual completed grant fact admits onset on its real owner clock")
    NativePersistent.observe_grants(applied,{actor.uuid:actor},400.0,cache)
    check(applied[grant.instance_uuid].start_ms==100.0 and not applied[grant.instance_uuid].initial,"An unchanged canonical grant does not restart its original onset/age")
    var revealed:Dictionary={}
    NativePersistent.observe_grants(revealed,{actor.uuid:actor},400.0,cache)
    var revealed_rows:Array=NativePersistent.grant_samples(revealed,450.0,cache)
    check(revealed_rows.size()==1 and NativePersistent.lifecycle_state(revealed_rows[0],.05).phase=="sustain" and revealed_rows[0].source_event_uuid.is_empty(),"First disclosure without its actual granting fact starts at hold, not a fabricated cast")
    check(NativePersistent.grant_samples(applied,450.0,cache,{}, {actor.uuid:true}).is_empty() and applied[grant.instance_uuid].start_ms==100.0,"Existing invisible-owner policy hides the grant without deleting/restarting membership")
    var replacement:Dictionary=actor.duplicate(true);replacement.temporary_hp_grant={"instance_uuid":"grant-b","source_id":"spell.false_life"}
    NativePersistent.observe_grants(applied,{actor.uuid:replacement},500.0,cache)
    var overlap:Array=NativePersistent.grant_samples(applied,550.0,cache)
    check(applied[grant.instance_uuid].end_ms==500.0 and overlap.size()==2 and overlap.map(func(row):return row.grant_uuid).has("grant-b"),"Real replacement retains independent actual UUIDs and the original source removal tail")
    var cleared:Dictionary=replacement.duplicate(true);cleared.temporary_hp_grant=null
    NativePersistent.observe_grants(applied,{actor.uuid:cleared},800.0,cache)
    check(applied["grant-b"].end_ms==800.0 and NativePersistent.grant_samples(applied,1300.0,cache).is_empty(),"Canonical null retires exactly at its real cut and sources close after their declared return")
    var zero:Dictionary={};NativePersistent.observe_grants(zero,{actor.uuid:actor},0.0,cache,true)
    var depleted:Dictionary=actor.duplicate(true);depleted.temporary_hp=0
    NativePersistent.observe_grants(zero,{actor.uuid:depleted},700.0,cache)
    check(zero[grant.instance_uuid].end_ms==700.0,"A canonical zero pool retires its actual grant without a private expiry rule")
    var retained:Dictionary={};NativePersistent.observe_grants(retained,{actor.uuid:actor},0.0,cache,true)
    var unseen:Dictionary=actor.duplicate(true);unseen.last_visual_position=null
    NativePersistent.observe_grants(retained,{actor.uuid:unseen},600.0,cache)
    check(is_inf(retained[grant.instance_uuid].end_ms) and retained[grant.instance_uuid].start_ms==0.0,"Loss of visual position alone does not retire or restart a canonical grant")
    var departed:Dictionary=unseen.duplicate(true);departed.present=false
    NativePersistent.observe_grants(retained,{actor.uuid:departed},900.0,cache)
    check(retained[grant.instance_uuid].end_ms==900.0,"A canonical terminal departure retires the disclosed grant owner")
    var unknown:Dictionary=actor.duplicate(true);unknown.temporary_hp_grant={"instance_uuid":"foreign","source_id":"unselected.grant"}
    var refused:Dictionary={};NativePersistent.observe_grants(refused,{actor.uuid:unknown},0.0,cache)
    check(refused.is_empty() and NativePersistent.grant_samples(refused,0.0,cache).is_empty(),"Unknown grant source does not borrow False Life artwork")
    unknown.temporary_hp_grant={"instance_uuid":"anonymous","source_id":null}
    NativePersistent.observe_grants(refused,{actor.uuid:unknown},0.0,cache)
    check(refused.is_empty(),"Undisclosed grant source ID has no invented donor/default artwork")
    var legacy:Dictionary=owner({"condition_uuid":"not-a-grant","behavior_id":"spell.false_life","state":null})
    check(Conditions.samples({legacy.id:legacy},200.0,cache).is_empty(),"The grant-only recipe cannot be admitted by a fake or archived condition-shaped alias")
    check(actor==original and selection==unchanged_selection,"Grant projection preserves immutable public operands and original package metadata")

func run()->void:
    var path=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--oracle="):path=arg.trim_prefix("--oracle=")
    if path.is_empty():push_error("Pass explicit --oracle=<original-source generated fixture>");quit(2);return
    var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
    var cache={}
    _explicit_lifecycle_owner(cache)
    _temporary_hp_grant_owner(cache)
    check(not Conditions.suppressed({"state":null}),"Nullable condition state has no invented suppression")
    for case in oracle.cases:
        var rows:Array=[]
        for source in case.rows:
            var row:Dictionary=source.duplicate(true)
            row.actor_uuid="actor";row.condition_uuid=row.owner_uuid;row.initial=not row.application;row.life_state=case.life_state
            rows.append(row)
        var held=rows.duplicate(true)
        var actual=Conditions.select_layers(rows,case.time_ms,{"actor":case.activity})
        check(actual.map(func(row):return [row.condition_uuid,row.layer.id])==case.expected,"Original marker selector "+case.name)
        check(rows==held,"Selection retains immutable inputs "+case.name)
    var owners={}
    for id in ["condition.poisoned","condition.paralyzed","class_feature.barbarian.raging"]:
        var record=owner(oracle.conditions[id]);owners[record.id]=record
    var raw=Conditions.samples(owners.duplicate(true),600,cache,{},false)
    var material=Conditions.material("actor",raw)
    var chosen=Conditions.select_recipes("actor",raw).filter(func(row):return row.recipe.persistent.get("bodyColor")!=null)[0]
    var color:Dictionary=chosen.recipe.persistent.bodyColor
    check(material.tint.is_equal_approx(Palette.rgb(int(color.tintRgb))) and is_equal_approx(material.saturation,color.saturation) and is_equal_approx(material.brightness,color.brightness),"Highest selected original bodyColor alone wins while lower owners remain semantic")
    var base=owner(oracle.conditions["condition.poisoned"])
    var applied=Conditions.samples({base.id:base},0,cache).filter(func(row):return row.has("lifecycle_phases"))
    check(not applied.is_empty(),"The current exact package replaces the original Poisoned marker with native lifecycles")
    for component in applied:
        check(NativePersistent.lifecycle_state(component,0).phase=="application","Actual application owner begins at its native application, not an invented fade")
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache)
    _native_owner_witnesses(raw)
    for id in ["class_feature.sorcerer.elemental_affinity.resistance","class_feature.sorcerer.metamagic_active","condition.spell.enhance_ability","condition.spell.enlarge_reduce"]:
        if not recipes.has(id):continue
        for layer in recipes[id].persistent.layers:
            for pair in [["whenEnergyType","energy_type"],["whenAbility","enhanced_ability"],["whenMetamagicMode","metamagic_mode"],["whenSizeChange","size_change"]]:
                if layer.get(pair[0])==null:continue
                var row={"layer":layer,"condition":{"state":{pair[1]:layer[pair[0]]}},"actor_uuid":"actor","condition_uuid":"owner","initial":true,"age_ms":0,"alpha":1.0}
                check(Conditions.select_layers([row],0).size()==1,"Authored state selector matches "+layer.id)
                row.condition.state[pair[1]]="different"
                check(Conditions.select_layers([row],0).is_empty(),"Authored state selector rejects other value "+layer.id)
    var charm={"condition_uuid":"charm","behavior_id":"condition.charmed","state":{}}
    var start=owner(charm)
    var charm_samples=Conditions.samples({start.id:start},0,cache).filter(func(row):return row.has("lifecycle_phases"))
    check(not charm_samples.is_empty(),"Charmed exposes the delivered application/sustain/removal source contract")
    for component in charm_samples:
        var duration:float=component.lifecycle_phases.application.seconds
        check(duration>0 and NativePersistent.lifecycle_state(component,duration-.00001).phase=="application","Native sustain is withheld until its authored application source ends")
        var after:Dictionary=NativePersistent.lifecycle_state(component,duration+.05)
        check(after.phase=="sustain" and is_equal_approx(after.phase_age_seconds,.05),"Native sustain source age subtracts the actual authored application duration")
        var initial_component:Dictionary=component.duplicate();initial_component.initial=true
        var initial:Dictionary=NativePersistent.lifecycle_state(initial_component,.05)
        check(initial.phase=="sustain" and is_equal_approx(initial.phase_age_seconds,.05),"An initially active owner starts at sustain, without replaying application")
        var removed:Dictionary=component.duplicate();removed.duration_ms=(duration+.1)*1000.0
        var removal:Dictionary=NativePersistent.lifecycle_state(removed,duration+.15)
        check(removal.phase=="removal" and is_equal_approx(removal.phase_age_seconds,.05),"Removal starts at the real owner end and has its own source clock")
        for phase in ["application","sustain","removal"]:
            var declared:Dictionary=Effects.clip(str(component.lifecycle_phases[phase].id))
            check(declared==component.lifecycle_phases[phase] and not declared.is_empty(),"Native phase retains exact installed package registration: "+phase)
        var registration:Dictionary=Effects.conditions("condition.charmed").filter(func(selection):return selection.key==component.lifecycle_key)[0].condition.registration
        check(component.native_cue.scale==registration.scale and component.native_cue.attachment==registration.attachment,"Native layer keeps its original package attachment and registration scale")
    var deceased={base.id:owner(oracle.conditions["condition.poisoned"])}
    Conditions.observe(deceased,{"actor":{"life_state":"dead","conditions":[]}},600)
    check(Conditions.samples(deceased,601,cache).filter(func(row):return row.has("layer")).is_empty(),"Removal tails use current disclosed actor life state rather than stale living marker eligibility")
    var paired=[]
    for source in oracle.cases[0].rows:
        if source.condition.behavior_id!="condition.paralyzed":continue
        for identity in ["z-owner","a-owner"]:
            var row=source.duplicate(true);row.condition_uuid=identity;row.actor_uuid="actor";row.initial=true;paired.append(row)
    var paired_selection=Conditions.select_layers(paired,0)
    check(not paired_selection.is_empty() and paired_selection.all(func(row):return row.condition_uuid=="a-owner"),"Overlapping marker owners select one stable complete bundle")
    for row in paired:
        if row.condition_uuid=="a-owner":row.removal_age_ms=10
    check(Conditions.select_layers(paired,0).all(func(row):return row.condition_uuid=="z-owner"),"Live marker owner wins over lower-UUID fading owner without deleting semantic lifetime")
    var thumbnails=Thumbnails.new()
    var native_rows:Array=raw.filter(func(row):return row.has("lifecycle_phases"))
    check(not native_rows.is_empty(),"Current condition sources provide actual native preview candidates")
    if not native_rows.is_empty():
        var marker:Dictionary=native_rows[0]
        var unbound={"id":"unbound-preview-control","kind":marker.kind,"status":marker.status,"component":marker,"start_ms":0.0}
        var rejected:String=thumbnails.request(unbound,600,0,false)
        check(thumbnails.errors.get(rejected,"")=="Composed source preview requires this actual recording" and thumbnails.pending.is_empty(),"A source fragment cannot invent an actor/pose recording for its composed preview")
    thumbnails.reset()
    check(thumbnails.pending.is_empty() and thumbnails.requested.is_empty() and thumbnails.inactive.is_empty(),"Thumbnail reset cancels all queued/inactive generation state")
    var preview_candidates:int=0
    for id in ["poisoned","haste"]:
        var recorded:Dictionary=Fixtures.read(id)
        check(recorded.ok,"Original condition recording admits for composed thumbnail ownership: "+id)
        if not recorded.ok:continue
        thumbnails.recording=recorded
        var candidates:Array=recorded.rows.filter(func(row):return Thumbnails._composed_row(row) and row.end_ms>row.start_ms and row.get("component",{}).has("lifecycle_phases"))
        check(not candidates.is_empty(),"Actual recorded condition has composed lifecycle rows: "+id)
        for actual in candidates:
            preview_candidates+=1
            var component:Dictionary=actual.component
            var at:float=lerpf(float(actual.start_ms),float(actual.end_ms),.5)
            var key:String=thumbnails.request(actual,at,0,false)
            check(thumbnails.requested.has(key) and not thumbnails.pending.is_empty(),"Actual composed lifecycle sample queues through the recording path: "+id)
            if thumbnails.pending.is_empty():continue
            var job:Dictionary=thumbnails.pending[-1]
            check(job.composed and is_same(job.recording,recorded) and is_equal_approx(job.sample_ms,at),"Composed restore retains the exact recording and absolute sample clock: "+id)
            check(job.component==component and job.component.lifecycle_phases==component.lifecycle_phases,"Composed request retains the exact owner and phase registration: "+id)
            var expected_phase:Dictionary=NativePersistent.lifecycle_state(component,(at-float(component.absolute_start_ms))/1000.0)
            check(expected_phase.phase==actual.lifecycle_phase,"Absolute recorded row clock selects its actual authored lifecycle phase: "+id)
            thumbnails.reset();thumbnails.recording=recorded
    check(preview_candidates>0,"Recorded composed lifecycle requests were exercised without synthetic actors or native pixel claims")
    thumbnails.close()
    var result={"checks":checks,"failures":failures,"original_source":oracle.source,"recordings":oracle.recordings,"scope":"Original marker operator and authored composition/state predicates; current exact native lifecycle source clocks/registration and thumbnail jobs; no native pixel claim"}
    FileAccess.open("res://generated/condition_selection_checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("CONDITION_SELECTION_CHECKS ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)

func _native_owner_witnesses(recorded:Array)->void:
    # Private composition-policy control, using actual recorded owners and
    # their typed body adjustments; this is not a simultaneous gameplay claim.
    var samples:Array=[]
    for source in recorded:
        if source.kind!="condition" or source.condition.behavior_id not in ["condition.poisoned","class_feature.barbarian.raging"]:continue
        var sample:Dictionary=source.duplicate(true)
        sample.recipe.erase("definitionRef")
        sample.recipe.persistent={"bodyColor":sample.recipe.persistent.bodyColor}
        sample.recipe.composition={"exclusiveGroup":"witness-policy-control","priority":samples.size()}
        samples.append(sample)
    check(samples.size()==2,"Witness control retains two actual recorded UUIDs and typed body adjustments")
    if samples.size()!=2:return
    var held:Array=samples.duplicate(true)
    var renderer=ComponentRenderer.new();var world=WitnessWorld.new()
    renderer._condition_witnesses(world,"actor",samples)
    check(renderer.pending_evidence.size()==1 and renderer.pending_evidence[0].trace_track_id=="condition:"+samples[1].condition_uuid+":bodyColor","Missing definitionRef cannot give the suppressed native owner a body witness: "+JSON.stringify(renderer.pending_evidence))
    renderer.pending_evidence.clear()
    renderer._condition_witnesses(world,"actor",[samples[0]])
    check(renderer.pending_evidence.size()==1 and renderer.pending_evidence[0].trace_track_id=="condition:"+samples[0].condition_uuid+":bodyColor","Previously suppressed actual owner receives its own witness after the winning owner ends")
    check(samples==held,"Witness selection never mutates real owner or typed-source inputs")
    # The same explicit legacy recipe also selects one strongest UUID. Equal
    # recipe keys do not mean the weaker owner's requested alpha was rendered.
    var source:Dictionary=recorded.filter(func(sample):return sample.kind=="condition" and sample.condition.behavior_id=="condition.poisoned")[0]
    var shared:Dictionary=source.recipe.duplicate(true)
    shared.persistent={"bodyColor":shared.persistent.bodyColor}
    check(not shared.get("definitionRef",{}).is_empty(),"Legacy alias control retains its actual authored ContentRef")
    var aliases:Array=samples.duplicate(true)
    for sample in aliases:sample.recipe=shared
    aliases[0].alpha=.3;aliases[1].alpha=.7
    renderer.pending_evidence.clear();renderer._condition_witnesses(world,"actor",aliases)
    check(renderer.pending_evidence.size()==1 and renderer.pending_evidence[0].trace_track_id=="condition:"+aliases[1].condition_uuid+":bodyColor","A shared explicit recipe cannot give the unselected weaker UUID a rendering witness")
    renderer.pending_evidence.clear();renderer._condition_witnesses(world,"actor",[aliases[0]])
    check(renderer.pending_evidence.size()==1 and renderer.pending_evidence[0].trace_track_id=="condition:"+aliases[0].condition_uuid+":bodyColor","The weaker actual UUID regains its own witness after the stronger instance ends")
    world.free()
