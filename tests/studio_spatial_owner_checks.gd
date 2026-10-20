extends SceneTree
## Original two-seat Orb journals -> the same owner/source spans as Timeline.
## No invented removal, source construction or native framebuffer claim.
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Recording=preload("res://studio/recording.gd")
const Journal=preload("res://sdk/journal.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
const Channels=preload("res://presentation/native_spell_channels.gd")
const CONTENT="spatial_effect.spell.acid_surface"
const CLIP="bg3-36/chromatic-orb/acid/observed-surface"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("STUDIO_SPATIAL_OWNER_FAIL "+label)
func _initialize()->void:run.call_deferred()

func run()->void:
    for seat in ["amber","blue"]:
        var journal:RefCounted=Journal.new()
        var opened:Dictionary=journal.open(Fixtures.journal("chromatic-orb",seat),true)
        check(opened.ok,seat+" original journal independently reduces")
        if not opened.ok:continue
        var index:Dictionary=Fixtures.read("chromatic-orb",seat)
        check(index.ok,seat+" original Studio index compiles")
        if not index.ok:continue
        var unchanged:PackedByteArray=var_to_bytes([index.initialization,index.groups])
        var actual:Dictionary=journal.state.senses.spatial_effects
        var identities:Array=actual.keys().filter(func(id):return actual[id].content_ref.content_id==CONTENT)
        check(identities.size()==1,seat+" original public after-state has one exact Acid owner")
        for identity in identities:owner(index,identity,actual[identity],seat)
        var after:RefCounted=Recording.restore(index,index.presentation_end_ms+4100.0)
        check(after.state==journal.state,seat+" late Studio restore equals independent canonical reduction")
        var samples:Array=after.component_samples(index.cache).filter(func(row):return row.get("spatial_content_id")==CONTENT)
        check(samples.size()==identities.size() and samples.all(func(row):return is_inf(float(row.duration_ms))),seat+" still-disclosed owners outlive the old fixed three-second review expiry")
        var start:RefCounted=Recording.restore(index,0.0)
        check(not start.state.senses.spatial_effects.keys().any(func(id):return id in identities),seat+" backward seek publishes no future surface")
        check(not start.component_samples(index.cache).any(func(row):return row.get("spatial_effect_uuid") in identities),seat+" backward seek samples no future source")
        var looped:RefCounted=Recording.restore(index,index.presentation_end_ms+4100.0)
        var loop_samples:Array=looped.component_samples(index.cache).filter(func(row):return row.get("spatial_content_id")==CONTENT)
        check(looped.state==after.state and loop_samples.map(func(row):return row.id)==samples.map(func(row):return row.id),seat+" loop restores the same canonical owner and one source occurrence")
        check(var_to_bytes([index.initialization,index.groups])==unchanged,seat+" source selection and seeks preserve immutable original cuts")
    var report={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Original independent Acid journals, authored-only Studio source/lifetime/channel spans, exact admission prefixes, canonical seek/loop and immutable cuts. No recorded removal or native pixel qualification."}
    FileAccess.open("res://generated/studio_spatial_owner_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("STUDIO_SPATIAL_OWNER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

func owner(index:Dictionary,identity:String,effect:Dictionary,seat:String)->void:
    check(Persistent.spatial_selection(effect,index.cache).is_empty() and Persistent.spatial_lifecycles(effect).is_empty(),seat+" actual Acid uses the authored-only source arm, not a legacy spell or package lifecycle")
    var policy:Dictionary=Recording._spatial_presentation(effect,index.cache)
    var config:Dictionary=Recording.Compiler.Authoring.load_data("catalog/condition_recipes.json",index.cache)[CONTENT]
    check(policy.eligible and policy.close_ms==Persistent.authored_removal_ms(config),seat+" Studio eligibility and retirement use the production authored close policy")
    var lifetimes:Array=index.rows.filter(func(row):return row.kind=="spatial_effect" and row.owner.id==identity)
    check(lifetimes.size()==1,seat+" Studio exposes one lifetime for the actual spatial UUID")
    if lifetimes.size()!=1:return
    var life:Dictionary=lifetimes[0]
    check(life.owner.effect==effect and is_inf(float(life.owner.end_ms)) and life.end_ms==index.presentation_end_ms,seat+" open lifetime uses actual membership and the replay inspection boundary")
    var rows:Array=index.rows.filter(func(row):return row.get("parent")==life.id and row.has("component"))
    check(not rows.is_empty(),seat+" actual native held source has Studio member tracks")
    var source_ids:Dictionary={}
    for row in rows:
        var component:Dictionary=row.component
        source_ids[component.id]=true
        check(component.native_clip.id==CLIP and component.spatial_effect_uuid==identity,seat+" track selects exact authored source and spatial owner")
        check(component.actor_uuid==null and component.target_uuid==null and not component.has("condition"),seat+" spatial source invents no actor or condition owner")
        check(row.source=="res://authoring/abilities/conditions/"+CONTENT+".tres::effects/0" and row.source_start_ms==life.start_ms,seat+" editable typed field and private source clock stay attached to the lifetime")
        check(row.status==component.status and row.coverage.rendered=="not_witnessed" and row.coverage.prepared=="not_examined",seat+" track/source presence cannot become native render evidence")
        check(row.start_ms>=life.start_ms and row.end_ms<=life.end_ms and row.end_ms>row.start_ms,seat+" native member interval stays inside its actual lifetime")
        var restored:RefCounted=Recording.restore(index,(row.start_ms+row.end_ms)*.5)
        var active:Array=restored.component_samples(index.cache).filter(func(sample):return sample.id==component.id)
        check(active.size()==1 and active[0].native_clip.id==component.native_clip.id and active[0].resolved_area_positions==component.resolved_area_positions,seat+" timeline samples the same source and disclosed cells shown by Studio")
        for channel in Channels.channels(component):
            check(index.rows.any(func(child):return child.parent==row.id and child.component.id==channel.id and child.start_ms==row.start_ms and child.end_ms==row.end_ms),seat+" existing native property channel remains a child of this owner span")
    check(source_ids.size()==1,seat+" changing after-values split inspection spans without duplicating source occurrence")
    var admission:bool=false
    for group_index in index.groups.size():
        var entry:Dictionary=index.groups[group_index]
        for cut in entry.group.commits.size():
            var commit:Dictionary=entry.group.commits[cut]
            var senses:Variant=commit.delta.get("set",{}).get("senses")
            if senses==null or not senses.spatial_effects.has(identity):continue
            var before:RefCounted=Recording.restore_boundary(index,group_index,cut)
            if before.state.senses.spatial_effects.has(identity):continue
            var after:RefCounted=Recording.restore_boundary(index,group_index,cut+1)
            check(after.state.senses.spatial_effects.has(identity),seat+" exact original commit admits the UUID after its independent earlier prefix")
            check(is_equal_approx(life.start_ms,entry.start_ms+commit.at_ms) and life.parent==str(entry.group.operation_sequence)+":"+str(commit.event_uuid),seat+" Studio lifetime begins at the actual causing occurrence and ordered commit")
            admission=true
            break
        if admission:break
    check(admission,seat+" original native sensory admission is witnessed, not inferred from the final surface")
    evidence.append({"seat":seat,"spatial_effect_uuid":identity,"source":CLIP,"start_ms":life.start_ms,"end_ms":life.end_ms,"member_spans":rows.size(),"source_occurrences":source_ids.size()})
