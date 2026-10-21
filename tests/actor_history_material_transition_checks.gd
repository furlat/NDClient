extends SceneTree
## A genuine damage flash overlaps the rolling Blur owner. No altered journal.
const Recording=preload("res://studio/recording.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Conditions=preload("res://presentation/conditions.gd")
const Characters=preload("res://presentation/characters.gd")
const ACTOR="7f95fe86-17ea-4647-8f15-1639954bd31e"
const OWNER="b81bcd18-42f0-419a-aadd-0b0549890dce"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("HISTORY_MATERIAL_TRANSITION_FAIL ",label)

static func transition(index:Dictionary)->Dictionary:
    var owners:Array=index.rows.filter(func(row):return row.kind=="condition" and row.owner.id==OWNER)
    var flashes:Array=index.rows.filter(func(row):return row.get("component",{}).get("kind")=="material_flash" and row.component.actor_uuid==ACTOR)
    if owners.size()!=1 or flashes.size()!=1:return {}
    return {"owner":owners[0].owner,"flash":flashes[0],"at_ms":float(flashes[0].end_ms)+40.0}

static func native_studies()->Array:
    var result:Array=[]
    for spell in ["fire-bolt","magic-missile"]:
        var directory:String="res://tests/fixtures/schema16/history-native-hit/"+spell
        var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"/native-hit-evidence.json"))
        for seat in ["amber","blue"]:
            var owners:Dictionary=proof.views[seat].owners
            var original:String=str(proof.views[seat].applied_damage[0].disclosed_blur_owners_before_result[0])
            result.append({"directory":directory+"/"+seat,"label":spell+"-"+seat,"actor":proof.actor_uuid,
                "owner":original,"clock":proof.expected_authored_clock_parameter,"retirement_recorded":owners[original].has("removal")})
    return result

static func native_transition(index:Dictionary,source:Dictionary)->Dictionary:
    var owners:Array=index.rows.filter(func(row):return row.kind=="condition" and row.owner.id==source.owner)
    var flashes:Array=index.rows.filter(func(row):return row.get("component",{}).get("kind")=="material_flash" \
        and row.component.actor_uuid==source.actor and not row.component.get("native_hit",{}).is_empty())
    if owners.size()!=1 or flashes.size()!=1:return {}
    return {"owner":owners[0].owner,"flash":flashes[0],"at_ms":float(flashes[0].end_ms)+40.0}

func run()->void:
    for seat in ["amber","blue"]:inspect_seat(seat)
    for source in native_studies():inspect_native(source)
    var report:Dictionary={"checks":checks,"failures":failures,"evidence":evidence,
        "scope":"Untouched Blur journals and four real Fire Bolt/Magic Missile hit originals: logical original-age hit/treatment descriptors, independently restored prefixes and real owner retirement where recorded. No native output or visual acceptance is claimed."}
    FileAccess.open("res://.runtime/actor-history-material-transition-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("HISTORY_MATERIAL_TRANSITION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

func inspect_seat(seat:String)->void:
    var facts:Array=Fixtures.fact_rows("blur","damage",seat).filter(func(row):return row.fact.get("stage")=="applied" and row.fact.target_entity_uuid==ACTOR)
    check(facts.size()==1 and facts[0].fact.applied_damage==14 and facts[0].fact.damage_type=="Slashing",seat+" original packet contains actual 14 Slashing applied damage")
    var index:Dictionary=Fixtures.read("blur",seat)
    check(index.ok,seat+" original journal compiles")
    if not index.ok or facts.size()!=1:return
    var immutable:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var study:Dictionary=transition(index)
    check(not study.is_empty(),seat+" the actual owner has exactly one real finite damage treatment")
    if study.is_empty():return
    var owner:Dictionary=study.owner;var row:Dictionary=study.flash;var at:float=study.at_ms
    check(str(row.component.source_event_uuid)==str(int(facts[0].node.occurrence)) \
        and row.component.get("native_hit",{}).is_empty(),seat+" captured material treatment belongs to the actual result, without a borrowed native hit framebuffer")
    check(float(owner.start_ms)<float(row.start_ms) and at<float(owner.end_ms),seat+" actual Blur membership spans the impact and restored-current observation")
    var timeline:RefCounted=Recording.restore(index,at)
    var captured:Dictionary=timeline.history_captures(ACTOR,OWNER,at,[0.0,.08,.16,.24])
    check(captured.ready and captured.complete_window,seat+" authentic bounded history covers the actual material transition: "+str(captured.get("reason")))
    if not captured.ready:return
    var old:Array=captured.captures.filter(func(capture):return not capture.departure.material.flash.is_empty())
    var current:Dictionary=captured.captures.back()
    check(not old.is_empty() and current.departure.material.flash.is_empty(),seat+" earlier captures retain real flash while present body has restored")
    var positive:int=0
    for capture in captured.captures:
        var material:Dictionary=capture.departure.material
        var prefix:RefCounted=Recording.restore(index,float(capture.sample_ms))
        var source:Dictionary=prefix.state.actors[ACTOR]
        check(capture.departure.actor.appearance==source.appearance \
            and capture.departure.item_looks==Characters.item_looks(source,prefix.state),seat+" each material capture retains its own real prefix outfit")
        check(capture.rig==current.rig and capture.actor_uuid==ACTOR and capture.condition_uuid==OWNER,seat+" same-rig history never substitutes another body or owner")
        var strength:float=float(Conditions.parameters(material,{},{}).flash_strength)
        if not material.flash.is_empty():
            var flash:Dictionary=material.flash
            var expected_age:float=float(capture.sample_ms)-float(row.start_ms)
            check(flash.id==row.component.id and is_equal_approx(float(flash.age_ms),expected_age) \
                and expected_age>=0.0 and expected_age<float(row.component.duration_ms),seat+" retained treatment keeps the real result identity and its historical age")
            check(is_equal_approx(strength,1.0-expected_age/float(row.component.duration_ms)) and strength>0.0,seat+" production material projection uses historical treatment strength")
            positive+=1
        else:check(is_zero_approx(strength),seat+" pre-impact/restored samples carry no invented flash")
    check(positive>0 and is_zero_approx(float(Conditions.parameters(current.departure.material,{},{}).flash_strength)),seat+" positive old treatment and normal current material coexist in one real window")
    var frozen:PackedByteArray=var_to_bytes(captured.captures)
    var retired:RefCounted=Recording.restore(index,index.presentation_end_ms)
    check(not retired.state.actors[ACTOR].conditions.any(func(condition):return condition.condition_uuid==OWNER) \
        and retired.actor_history_cuts.is_empty(),seat+" actual concentration removal retires the history interest")
    var looped:RefCounted=Recording.restore(index,at)
    check(var_to_bytes(looped.history_captures(ACTOR,OWNER,at,[0.0,.08,.16,.24]).captures)==frozen,seat+" reverse seek reconstructs the identical earlier material history")
    check(var_to_bytes(captured.captures)==frozen and var_to_bytes([index.initialization,index.groups,index.rows])==immutable,seat+" later prefix/removal cannot mutate captured materials or original data")
    evidence.append({"seat":seat,"condition_uuid":OWNER,"actor_uuid":ACTOR,"damage_occurrence":str(int(facts[0].node.occurrence)),
        "flash_start_ms":row.start_ms,"flash_end_ms":row.end_ms,"at_ms":at,"historical_treated_samples":positive,"equipment_transition":"not_recorded"})

func inspect_native(source:Dictionary)->void:
    var index:Dictionary=Recording.read(source.directory)
    var label:String=source.label
    check(index.ok,label+" unchanged native-hit original compiles")
    if not index.ok:return
    var original:PackedByteArray=var_to_bytes([index.initialization,index.groups,index.rows])
    var study:Dictionary=native_transition(index,source)
    check(not study.is_empty(),label+" exactly one real applied native hit overlaps its original Blur UUID")
    if study.is_empty():return
    var timeline:RefCounted=Recording.restore(index,study.at_ms)
    var history:Dictionary=timeline.history_captures(source.actor,source.owner,study.at_ms,[0.0,.08,.16,.24])
    check(history.ready and history.get("complete_window",false),label+" native-hit overlap now retains an authentic complete prefix: "+str(history.get("reason")))
    if not history.ready:return
    var positive:int=0
    for capture in history.captures:
        var flash:Dictionary=capture.departure.material.flash
        if flash.is_empty():continue
        positive+=1
        var exact:RefCounted=Recording.restore(index,capture.sample_ms)
        var expected:Dictionary=Conditions.material(source.actor,exact.component_samples(index.cache)).flash
        check(flash.id==study.flash.component.id and flash.source_event_uuid==study.flash.component.source_event_uuid \
            and is_equal_approx(float(flash.age_ms),float(capture.sample_ms)-float(study.flash.start_ms)),label+" original result identity and absolute hit clock are preserved")
        check(flash.id==expected.id and flash.native_hit==expected.native_hit and is_equal_approx(flash.age_ms,expected.age_ms),label+" descriptor equals independently restored actual prefix")
        check(flash.native_hit.definition.get("clock_parameter","")==source.clock \
            and not flash.has("native_surface"),label+" selected animated/static native source is retained without a borrowed framebuffer")
    check(positive>0 and history.captures.back().departure.material.flash.is_empty(),label+" earlier native hit and restored current body coexist")
    var terminal:RefCounted=Recording.restore(index,index.presentation_end_ms)
    var retained:bool=terminal.state.actors[source.actor].conditions.any(func(condition):return condition.condition_uuid==source.owner)
    check(retained!=source.retirement_recorded,label+" actual removal/recast or absent removal is reported without invented expiration")
    var again:RefCounted=Recording.restore(index,study.at_ms)
    check(var_to_bytes(again.history_captures(source.actor,source.owner,study.at_ms,[0.0,.08,.16,.24]).captures)==var_to_bytes(history.captures),label+" reverse seek restores exact original operands")
    check(var_to_bytes([index.initialization,index.groups,index.rows])==original,label+" native-hit evidence remains immutable")
    evidence.append({"case":label,"actor_uuid":source.actor,"condition_uuid":source.owner,"at_ms":study.at_ms,
        "hit_component":study.flash.component.id,"historical_treated_samples":positive,"retirement_recorded":source.retirement_recorded})
