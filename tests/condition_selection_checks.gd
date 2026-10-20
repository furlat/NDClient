extends SceneTree
const Conditions=preload("res://presentation/conditions.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Thumbnails=preload("res://studio/thumbnail_cache.gd")
const Palette=preload("res://presentation/palette.gd")
const NativePersistent=preload("res://presentation/native_persistent.gd")
const Effects=preload("res://presentation/effect_package.gd")
const ComponentRenderer=preload("res://presentation/component_renderer.gd")
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
func run()->void:
    var path=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--oracle="):path=arg.trim_prefix("--oracle=")
    if path.is_empty():push_error("Pass explicit --oracle=<original-source generated fixture>");quit(2);return
    var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
    var cache={}
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
    var native_rows: Array=raw.filter(func(row):return row.has("lifecycle_phases"))
    check(not native_rows.is_empty(),"Current condition sources provide actual native preview candidates")
    if not native_rows.is_empty():
        var marker:Dictionary=native_rows[0]
        var preview_row={"id":"native-preview","kind":marker.kind,"status":marker.status,"component":marker,"start_ms":0.0,"source_start_ms":0.0}
        var key:String=thumbnails.request(preview_row,600,0,false)
        check(thumbnails.requested.has(key) and thumbnails.pending.size()==1 and is_equal_approx(thumbnails.pending[0].age_ms,600),"Native thumbnail queues the same unshifted owner clock used by its lifecycle")
        check(thumbnails.pending[0].component.lifecycle_phases==marker.lifecycle_phases,"Thumbnail retains the exact source phase records, not retired spritesheet aliases")
    thumbnails.reset()
    check(thumbnails.pending.is_empty() and thumbnails.requested.is_empty() and thumbnails.inactive.is_empty(),"Thumbnail reset cancels all queued/inactive generation state")
    for component in charm_samples:
        var at:float=float(component.lifecycle_phases.application.seconds)*1000.0+50
        var preview_row={"id":"charm-preview:"+component.id,"kind":component.kind,"status":component.status,"component":component,"start_ms":0.0,"source_start_ms":0.0}
        thumbnails.request(preview_row,at,0,false)
        check(is_equal_approx(thumbnails.pending[-1].age_ms,floorf(at*60/1000.0)*1000.0/60.0),"Native thumbnail clock retains the authored lifecycle boundary and exact sample quantization")
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
