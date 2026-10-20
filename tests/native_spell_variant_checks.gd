extends SceneTree
## Shared typed dispatch. Authored test predicates below are compiler controls;
## original journal bytes and outcomes remain unchanged and are checked apart.
const Build=preload("res://tools/presentation_build/abilities.gd")
const Records=preload("res://tools/presentation_build/ability_records.gd")
const Common=preload("res://tools/presentation_build/common.gd")
const SpellVariant=preload("res://presentation/source/abilities/spell_variant.gd")
const NativeSpells=preload("res://presentation/native_spell_authoring.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const Requirements=preload("res://presentation/requirements.gd")
const Components=preload("res://presentation/components.gd")
const Compiler=preload("res://presentation/compiler.gd")
const Journal=preload("res://sdk/journal.gd")
const Fixtures=preload("res://tests/recording_fixtures.gd")
const Timeline=preload("res://presentation/timeline.gd")
const Occurrences=preload("res://presentation/occurrences.gd")
const Play=preload("res://play.gd")
const Recording=preload("res://studio/recording.gd")
const ID="spell.fire_bolt"
const PATH="res://authoring/abilities/spells/spell.fire_bolt.tres"
var checks:int=0
var failures:Array=[]
var evidence:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("NATIVE_SPELL_VARIANT_FAIL ",label)
func variant(id:String,when:Dictionary,entry:Resource)->Resource:
    var row:Resource=SpellVariant.new();row.id=id;row.kind="outcome";row.status="partial";row.when=when
    row.effects.append(entry.effects[-1].duplicate(true))
    # A real same-family source, explicitly authored as a valid partial contact
    # in the test. This is not a production Miss-visual assignment/acceptance.
    row.effects[0].role="impact"
    return row
func built(entry:Resource,id:String=ID,path:String=PATH)->Dictionary:
    return Build.documents({"spells":{id:entry},"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},{"spells":{id:path}})
func source_cache(record:Resource,id:String=ID,path:String=PATH)->Dictionary:
    var cache:Dictionary={};var admitted:Dictionary=Sources.admission(cache)
    var index:Resource=admitted.index.duplicate();index.spells=admitted.index.spells.duplicate();index.spells[id]=path
    var loaded:Dictionary=admitted.loaded.duplicate();loaded[id]=record
    cache[Sources.CACHE_KEY]=Sources.make_admission(index,loaded)
    return cache
func run()->void:
    var entry:Resource=load(PATH).duplicate(true)
    var miss:Resource=variant("test.actual_miss",{"attack_outcome":["Miss","Crit Miss"]},entry)
    var crit:Resource=variant("test.actual_critical",{"attack_outcome":["Crit"]},entry)
    var draft:Resource=variant("miss_name_is_not_a_predicate",{},entry);draft.value="Miss"
    var blocked:Resource=variant("source_not_bound",{"attack_outcome":["Hit"],"target_kind":["object"]},entry)
    blocked.dispatch_gap="review_endpoint_position_not_bound"
    var receiver:Resource=variant("test.actual_hit_receiver",{"attack_outcome":["Hit"],"target_kind":["creature"]},entry)
    receiver.recipe=Build.raw_recipe(entry).duplicate(true)
    receiver.recipe.damage.impactDelayMs=91.0
    entry.variants.assign([miss,crit,draft,blocked,receiver])
    var report:Dictionary=Common.report();Build._check_variants(entry,ID,report)
    check(report.errors.is_empty(),"Disjoint canonical public predicates pass offline validation; drafts/gaps stay explicit")
    var output:Dictionary=built(entry)
    # The ordinary selectors below consume an actually saved/reloaded owner,
    # not Dictionary aliases that exist only in the builder process.
    check(output.native.records[ID].variants.slice(0,4).all(func(row):return row.inherits_recipe),"Empty authored recipient recipes explicitly inherit the base owner")
    check(not output.native.records[ID].variants[4].inherits_recipe and output.native.records[ID].variants[4].recipe.damage.impactDelayMs==91.0,"A nonempty authored recipient recipe is independently an overriding payload")
    var record:Resource=serialized(output.native.records[ID],"main")
    if record==null:
        print("NATIVE_SPELL_VARIANT ",JSON.stringify({"checks":checks,"failures":failures}));quit(1);return
    var cache:Dictionary=source_cache(record)
    var source:Dictionary=NativeSpells.source(ID,cache)
    var overridden:Dictionary=NativeSpells.selected(source,{"attack_outcome":"Hit","target_kind":"creature"})
    check(overridden.recipe.damage.impactDelayMs==91.0 and not is_same(overridden.recipe,record.recipe),"Actual selected disk override retains its independent recipient damage")
    var required:Array=Requirements._prepared_recipe(overridden.recipe,overridden.requirement_source,"spell",ID,cache)
    check(required==overridden.requirements and required.size()==overridden.requirements.size(),"Actual reloaded selected override consumes its prepared requirement values")
    for at in required.size():check(is_same(required[at],overridden.requirements[at]),"Prepared override requirement rows are borrowed, not recomputed: "+str(at))
    var immutable:PackedByteArray=var_to_bytes([record.selection,record.recipe,record.variants])
    check(record.variants.size()==5,"Every typed alternative survives native serialization, including inherited, overriding, draft and source-gap records")
    check(record.variants[2].dispatch_gap=="public_fact_predicate_not_authored" and record.variants[3].dispatch_gap=="review_endpoint_position_not_bound","Exact unknown-selector and source blockers remain distinct")
    for pair in [[{},""],[{"attack_outcome":null},""],[{"attack_outcome":"Hit"},""],[{"attack_outcome":"Miss"},miss.id],[{"attack_outcome":"Crit Miss"},miss.id],[{"attack_outcome":"Crit"},crit.id],[{"attack_outcome":"Hit","target_kind":"object"},""],[{"attack_outcome":"Hit","target_kind":"creature"},receiver.id]]:
        var selected:Dictionary=NativeSpells.selected(source,pair[0])
        check(selected.selection.get("variant",{}).get("id","")==pair[1],"Exact per-application choice "+str(pair))
        check(is_same(selected.recipe.cast,record.recipe.cast),"All recipient alternatives borrow the same immutable caster body")
    var same:Dictionary=NativeSpells.selected(source,{"attack_outcome":"Miss"})
    check(is_same(NativeSpells.selection_for({"behavior_id":ID,"attack_outcome":"Miss"},cache),same.selection),"Occurrence API and direct shared selector agree")
    check(is_same(NativeSpells.recipe({"behavior_id":ID,"attack_outcome":"Miss"},cache),same.recipe),"Occurrence recipe follows the same explicit selector")
    check(is_same(NativeSpells.selection(ID,cache),record.selection),"Static inventory/condition ownership remains the baseline")
    var prepared:Dictionary=NativeSpells.preparation_selection(ID,cache)
    check(prepared.preparation_variants.size()==3,"Only eligible alternatives join active-selection optional preparation")
    check(not record.selection.has("preparation_variants"),"Optional preparation never mutates the behavior-owned selection")
    var expected:Dictionary={}
    for choice in [record.selection,record.variants[0].selection,record.variants[1].selection,record.variants[4].selection]:
        for clip in NativeSpells.effect_clips(choice):expected[clip.id]=true
    check(NativeSpells.effect_clips(prepared).map(func(clip):return clip.id).size()==expected.size(),"Active optional closure is the deduplicated exact eligible clip union")
    check(NativeSpells.effect_clips(record.selection).size()==NativeSpells.effect_clips(NativeSpells.selection(ID,cache)).size(),"Ordinary startup/other offered choices do not warm every alternative")
    optional_controls(prepared,record,cache)
    validate_negative(entry)
    effect_identity_controls(entry)
    component_controls(source,cache)
    check(var_to_bytes([record.selection,record.recipe,record.variants])==immutable,"Application/phase/preparation sampling leaves the shared immutable source unchanged")
    inventory()
    await originals()
    mixed_siblings()
    print("NATIVE_SPELL_VARIANT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Explicit typed selector/compiler/preparation ownership and actual original outcomes; no automatic Factory variant activation, native pixels or visual acceptance."}))
    quit(0 if failures.is_empty() else 1)
func serialized(original:Resource,label:String,behavior:String=ID)->Resource:
    var unchanged:PackedByteArray=var_to_bytes([original.selection,original.recipe,original.requirements,original.variants])
    var compact:Resource=Build.persisted_native_record(original)
    check(compact!=original,label+" compact disk Resource does not replace the existing admitted source")
    check(compact.recipe==original.recipe and compact.requirements==original.requirements,label+" base recipe/requirements values survive compact projection")
    for at in compact.variants.size():
        var disk:Dictionary=compact.variants[at];var before:Dictionary=original.variants[at]
        check(disk.id==before.id and disk.inherits_recipe==before.inherits_recipe,label+" explicit inheritance identity is serialized: "+str(disk.id))
        if disk.inherits_recipe:
            check(not disk.has("recipe") and not disk.has("requirements"),label+" inherited variant omits duplicate recipe/requirements payload: "+str(disk.id))
        else:
            check(disk.has("recipe") and disk.has("requirements") and not disk.recipe.has("cast"),label+" recipient override stores its own payload without duplicating the common caster: "+str(disk.id))
            check(disk.recipe.damage.impactDelayMs==91.0,label+" actual independently authored recipient damage survives compact projection")
    var folder:String="res://.runtime/native-spell-variant-serialization"
    check(DirAccess.make_dir_recursive_absolute(folder)==OK,label+" ignored serialization output directory is available")
    var path:String=folder.path_join(label+".res")
    check(ResourceSaver.save(compact,path,ResourceSaver.FLAG_COMPRESS)==OK,label+" compact native Resource saves to disk")
    var loaded:Resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
    check(loaded!=null and loaded!=compact and loaded!=original,label+" CACHE_IGNORE obtains an independent physical disk Resource")
    if loaded==null:return null
    # Inspect what was truly stored before hydration can attach borrowed data.
    for disk in loaded.variants:
        if disk.inherits_recipe:check(not disk.has("recipe") and not disk.has("requirements"),label+" actual disk inherited payload is absent before binding: "+str(disk.id))
        else:check(not disk.recipe.has("cast") and disk.recipe.damage.impactDelayMs==91.0,label+" actual disk override retains recipient damage and omits caster")
    var hydrated:Resource=Sources._bind_recipe_owners(loaded)
    check(hydrated==loaded,label+" one-time recipe binding retains the actual loaded source owner")
    check(hydrated.recipe==original.recipe and hydrated.requirements==original.requirements,label+" hydrated base values equal the original independently built source")
    for at in hydrated.variants.size():
        var actual:Dictionary=hydrated.variants[at]
        check(actual.selection==original.variants[at].selection,label+" exact selection metadata survives disk round trip: "+str(actual.id))
        check(is_same(actual.recipe.cast,hydrated.recipe.cast),label+" each hydrated variant borrows the common caster Dictionary: "+str(actual.id))
        if actual.inherits_recipe:
            check(is_same(actual.recipe,hydrated.recipe) and is_same(actual.requirements,hydrated.requirements),label+" inherited recipe/requirements share the admitted physical base: "+str(actual.id))
        else:
            check(not is_same(actual.recipe,hydrated.recipe) and not is_same(actual.requirements,hydrated.requirements),label+" recipient override keeps its own recipe and prepared requirement owner")
            check(actual.recipe.damage.impactDelayMs==91.0 and hydrated.recipe.damage.get("impactDelayMs",0.0)!=91.0,label+" changed recipient damage is retained without mutating base damage")
    # Exercise the real cold reader too: a private admitted index points at
    # the compact .res with no loaded entries, so find must read and bind it.
    var cold_cache:Dictionary={};var admitted:Dictionary=Sources.admission(cold_cache)
    var index:Resource=admitted.index.duplicate();index.spells={behavior:path}
    cold_cache[Sources.CACHE_KEY]=Sources.make_admission(index,{})
    var physical:Resource=Sources.find(behavior,cold_cache)
    check(physical!=null and physical!=original and physical!=compact,label+" actual cold Sources.find admits the saved physical Resource")
    if physical==null:return null
    check(physical.recipe_owners_bound,label+" actual physical reader completes one-time recipe-owner attachment")
    check(is_same(Sources.find(behavior,cold_cache),physical),label+" warm Sources.find retains the same admitted physical Resource")
    for actual in physical.variants:
        check(is_same(actual.recipe.cast,physical.recipe.cast),label+" cold reader attaches the exact common caster for "+str(actual.id))
        if actual.inherits_recipe:
            check(is_same(actual.recipe,physical.recipe) and is_same(actual.requirements,physical.requirements),label+" cold reader shares inherited owners for "+str(actual.id))
        else:
            check(actual.recipe.damage.impactDelayMs==91.0 and not is_same(actual.recipe,physical.recipe),label+" cold reader keeps overriding recipient damage for "+str(actual.id))
    var before_bind:Array=physical.variants.map(func(row):return row.recipe)
    check(Sources._bind_recipe_owners(physical)==physical,label+" repeated attachment retains the same physical source")
    for at in before_bind.size():check(is_same(before_bind[at],physical.variants[at].recipe),label+" repeated attachment does not replace private overriding/inherited recipes "+str(at))
    check(var_to_bytes([original.selection,original.recipe,original.requirements,original.variants])==unchanged,label+" compact saving/loading/hydration/cold admission never mutates a preexisting source")
    evidence.append({"serialization":label,"path":path,"variants":hydrated.variants.size(),"inherited":hydrated.variants.filter(func(row):return row.inherits_recipe).size(),"source_owner":"actual CACHE_IGNORE Resource, hydrated once"})
    return physical

func optional_controls(prepared:Dictionary,record:Resource,cache:Dictionary)->void:
    var world:Node=Play.new();world.catalog_cache=cache
    world.selection_media.value={"native_selection":prepared};world.selection_media.revision=1
    var request:Dictionary=world._native_startup_request(0.0,true)
    check(not request.plan.is_empty() and request.required.is_empty(),"Active capability alternatives are real optional work, never base readiness requirements")
    check(request.plan.all(func(item):return is_inf(item.due_ms)),"Unobserved eligible alternatives have no invented authoritative deadline")
    check(Play.NativeStartup.status(request).ready,"Unwarmed optional selection cannot hold current publication")
    var component:Dictionary={"native_spell":true,"status":"available","native_clip":NativeSpells.effect_clips(record.variants[0].selection)[0],"start_ms":0.0}
    world.timeline.queue=[{"id":"received-actual-variant-control","components":[component],"duration_ms":1000.0}]
    request=world._native_startup_request(0.0,true)
    check(request.required.size()==1 and request.required[0].key==Play.NativeStartup.Effects.key(component.native_clip),"A received selected alternative acquires its exact required source deadline")
    check(not Play.NativeStartup.status(request).ready,"Required selected source remains pending until actual preparation, independently of optional alternatives")
    world.context_menu.free();world.free()

func validate_negative(entry:Resource)->void:
    for control in ["unknown","noncanonical","empty","overlap","cue_indices","cast","empty_effect","nontext_effect"]:
        var invalid:Resource=entry.duplicate(true)
        match control:
            "unknown":invalid.variants[0].when={"saved":[true]}
            "noncanonical":invalid.variants[0].when={"attack_outcome":["Crit Hit"]}
            "empty":invalid.variants[0].when={"attack_outcome":[]}
            "overlap":invalid.variants[1].when={"attack_outcome":["Miss"]}
            "cue_indices":invalid.owner_cues=PackedInt32Array([0])
            "cast":invalid.variants[0].recipe={"cast":{"actionClip":"invented"}}
            "empty_effect":invalid.variants[0].when={"effect_id":[""]}
            "nontext_effect":invalid.variants[0].when={"effect_id":[true]}
        var report:Dictionary=Common.report();Build._check_variants(invalid,ID,report)
        check(not report.errors.is_empty(),"Offline rejection: "+control)
func effect_identity_controls(original:Resource)->void:
    var entry:Resource=original.duplicate(true)
    var first:Resource=variant("test.actual_option",{"effect_id":["support.fixture.first"]},entry)
    var second:Resource=variant("test.other_option",{"effect_id":["support.fixture.second"]},entry)
    entry.variants.assign([first,second])
    var report:Dictionary=Common.report();Build._check_variants(entry,ID,report)
    check(report.errors.is_empty(),"Disjoint literal effect identities pass the ordinary offline predicate check")
    var built_source:Resource=built(entry).native.records[ID]
    var source:Dictionary={"recipe":built_source.recipe,"selection":built_source.selection,"variants":built_source.variants}
    for pair in [[{},""],[{"effect_id":null},""],[{"effect_id":"support.fixture.first"},first.id],[{"effect_id":"support.fixture.second"},second.id],[{"effect_id":"support.fixture.first.suffix"},""],[{"effect_id":"support.fixture.First"},""],[{"effect_id":"unknown","name":"support.fixture.first"},""]]:
        var selected:Dictionary=NativeSpells.selected(source,pair[0])
        check(selected.selection.get("variant",{}).get("id","")==pair[1],"Only the actual exact disclosed option selects its recipient source: "+str(pair))
        check(is_same(selected.recipe.cast,built_source.recipe.cast),"Literal option selection retains one shared cast owner")
func component_controls(source:Dictionary,cache:Dictionary)->void:
    var group:Dictionary={"operation_sequence":1,"components":[],"commits":[]}
    var node:Dictionary={"id":"compiler-control","lineage_id":"compiler-control","resolution_record":{},"fact":{}}
    var owner:Dictionary={"source_event_uuid":"one-real-cast","start":0.0,"prepare":0.0,"release":100.0}
    var points:Dictionary={"from_position":[3,7],"to_position":[6,7]}
    var fact:Dictionary={"behavior_id":ID,"source_entity_uuid":"actual-caster-control","target_entity_uuid":"actual-target-control","attack_outcome":"Miss"}
    Components.native_spell(group,node,source.recipe,source.selection,100.0,200.0,points,cache,owner,fact)
    check(group.components.all(func(row):return row.native_cue.role!="impact"),"Default Miss keeps the existing baseline impact suppression")
    group.components=[]
    var selected:Dictionary=NativeSpells.selected(source,fact)
    Components.native_spell(group,node,selected.recipe,selected.selection,100.0,200.0,points,cache,owner,fact)
    check(group.components.size()==1 and group.components[0].native_cue.role=="impact" and group.components[0].native_variant.id=="test.actual_miss","An explicit selected Miss partial-contact phase is not deleted by baseline suppression")
    check(group.components[0].native_cast_id=="one-real-cast","Variant native phase retains the actual cast owner")
    var unrelated:Dictionary=selected.selection.duplicate();unrelated.variant={"when":{"target_kind":["creature"]},"replaces_effects":true}
    check(not NativeSpells.miss_impact_authored(unrelated,fact),"A target-kind-only variant cannot authorize successful impacts on a Miss")
    var inherited:Dictionary=selected.selection.duplicate();inherited.variant={"when":{"attack_outcome":["Miss"]},"replaces_effects":false}
    check(not NativeSpells.miss_impact_authored(inherited,fact),"An effects-empty Miss variant retains the inherited baseline impact policy")
    for negative in [unrelated,inherited]:
        var control:Dictionary={"operation_sequence":2,"components":[],"commits":[]}
        Components.native_spell(control,node,selected.recipe,negative,100.0,200.0,points,cache,owner,fact)
        check(control.components.is_empty(),"Unrelated/inherited variant cannot render the default hit impact on a Miss")
    var row:Dictionary=group.components[0];row.native_cue.source_rate=2.0
    check(not selected.selection.staging.cues[0].has("source_rate") or selected.selection.staging.cues[0].source_rate!=2.0,"Per-occurrence private cue mutation never alters the selected immutable source")
func inventory()->void:
    var root:Resource=load("res://authoring/abilities.tres")
    var count:int=0;var cues:int=0;var owners:int=0;var active:int=0;var entries:Dictionary={};var paths:Dictionary={}
    for id in root.sections.spells:
        var entry:Resource=load(root.sections.spells[id])
        if not entry.native_staging:continue
        entries[id]=entry;paths[id]=root.sections.spells[id]
        if not entry.variants.is_empty():owners+=1
        for alternative in entry.variants:
            count+=1;cues+=alternative.effects.size()
            if not alternative.when.is_empty() and alternative.dispatch_gap.is_empty():active+=1
    var output:Dictionary=Build.documents({"spells":entries,"contexts":{"hit_flash":load("res://authoring/abilities/contexts/hit_flash.tres")}},{"spells":paths})
    var emitted:int=0;var disk_cache:Dictionary={}
    for id in entries:
        var record:Resource=output.native.records[id]
        check(record.variants.size()==entries[id].variants.size(),id+" every original alternative is admitted")
        var physical:Resource=Sources.find(id,disk_cache) if not record.variants.is_empty() else null
        if physical!=null:check(physical.variants.size()==record.variants.size(),id+" all production alternatives survive actual disk admission")
        for at in entries[id].variants.size():
            var original:Resource=entries[id].variants[at];var actual:Dictionary=record.variants[at]
            emitted+=1
            check(actual.id==original.id and actual.when==original.when and actual.selection.staging.cues.size()==(original.effects.size() if not original.effects.is_empty() else entries[id].effects.size()),id+" exact alternative identity/predicate/cue count "+original.id)
            check(physical!=null,id+" production source is physically admitted")
            if physical!=null:
                var admitted:Dictionary=physical.variants[at]
                check(admitted.id==actual.id and is_same(admitted.recipe.get("cast"),physical.recipe.get("cast")),id+" loaded alternative shares its actual caster owner "+original.id)
                if admitted.inherits_recipe:check(is_same(admitted.recipe,physical.recipe) and is_same(admitted.requirements,physical.requirements),id+" loaded inherited recipe and requirements share their base owner "+original.id)
            if original.when.is_empty():check(actual.dispatch_gap=="public_fact_predicate_not_authored",id+" no title/value inference for "+original.id)
    check(emitted==count,"Every authored alternative survives the native build, including explicitly assigned production branches")
    evidence.append({"native_variant_owners":owners,"alternatives":count,"alternative_cues":cues,"active_production_predicates":active,"all_typed_alternatives_serialized":emitted})
func originals()->void:
    var id:String="spell.ray_of_sickness";var entry:Resource=load("res://authoring/abilities/spells/"+id+".tres").duplicate(true)
    var miss:Resource=SpellVariant.new();miss.id="test.recorded_miss";miss.kind="outcome";miss.when={"attack_outcome":["Miss","Crit Miss"]}
    # The existing delivery has actual actor endpoints; the imported Factory
    # miss art still has an unbound review point and is intentionally unused.
    miss.effects.append(entry.effects[0].duplicate(true));entry.variants.assign([miss])
    var output:Dictionary=built(entry,id,"res://authoring/abilities/spells/"+id+".tres")
    # Both seats fold their own actual bytes; a test-only predicate may select
    # an existing source, but cannot change any native fact or reducer state.
    for seat in ["amber","blue"]:
        var path:String="res://tests/fixtures/schema16/typed-variants-miss/"+seat+"/journal"
        if not DirAccess.dir_exists_absolute(path):
            check(false,seat+" actual Miss original is required, not a synthetic outcome");continue
        var journal:RefCounted=Journal.new();check(journal.open(path,true,false).ok,seat+" opens original fixed-seed legal outcome")
        var files:PackedStringArray=DirAccess.get_files_at(path);files.sort();var found:int=0
        var cache:Dictionary=source_cache(output.native.records[id],id,"res://authoring/abilities/spells/"+id+".tres")
        var timeline:RefCounted=Timeline.new();var duration:float=0.0
        for file in files:
            if not file.get_basename().is_valid_int():continue
            var sequence:int=int(file.get_basename());var raw:PackedByteArray=FileAccess.get_file_as_bytes(path.path_join(file))
            var decoded:Dictionary=journal.decode_record(sequence,raw);check(decoded.ok,seat+" decode "+file)
            if not decoded.ok:break
            var before:Dictionary=journal.state
            var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true);check(folded.ok,seat+" independent fold "+file)
            if not folded.ok:break
            if sequence==0:
                timeline.accept({"kind":"initialization","state":journal.state.duplicate(true),"sequence":0});continue
            var unchanged:PackedByteArray=var_to_bytes(folded.normalized)
            var compiled:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
            check(compiled.ok,seat+" genuine Miss original compiles "+file)
            if not compiled.ok:break
            timeline.accept({"kind":"operation","groups":compiled.value.groups})
            for group in compiled.value.groups:duration+=float(group.duration_ms)
            check(var_to_bytes(folded.normalized)==unchanged,seat+" actual original is unchanged by selection/compiler")
            for lineage in folded.normalized.get("lineages",[]):
                for node in lineage.events:
                    var fact:Variant=node.get("fact")
                    if fact==null or fact.get("kind")!="spell" or fact.get("behavior_id")!="spell.ray_of_sickness":continue
                    found+=1;check(fact.attack_outcome in ["Miss","Crit Miss"],seat+" genuine recorded attack supplies a Miss outcome")
                    var rows:Array=[];var caster_tracks:Array=[]
                    for group in compiled.value.groups:
                        rows.append_array(group.components.filter(func(row):return row.get("native_variant",{}).get("id")==miss.id))
                        caster_tracks.append_array(group.actor_tracks.filter(func(track):return track.get("activity")=="cast"))
                    check(rows.size()==1 and rows[0].actor_uuid==fact.source_entity_uuid and rows[0].target_uuid==fact.target_entity_uuid,seat+" genuine Miss chooses its private declared source/recipient component")
                    check(caster_tracks.size()==1,seat+" genuine Miss has one original caster gesture")
                    evidence.append({"seat":seat,"sequence":sequence,"occurrence":node.occurrence,"fact":fact})
        check(found==1,seat+" exactly one legal cast, no retry or forced outcomes")
        timeline.advance(duration+1000.0)
        check(not timeline.busy() and timeline.state==journal.state,seat+" actual canonical prefix drains unchanged in original event order")

func mixed_siblings()->void:
    # Independent original three-application cast, then explicitly labelled
    # compiler-only outcome controls. The original journal/state is untouched.
    var id:String="spell.scorching_ray";var path:String="res://authoring/abilities/spells/"+id+".tres"
    var entry:Resource=load(path).duplicate(true)
    var miss:Resource=variant("test.mixed_miss",{"attack_outcome":["Miss"]},entry)
    var critical:Resource=variant("test.mixed_critical",{"attack_outcome":["Crit"]},entry)
    entry.variants.assign([miss,critical])
    var output:Dictionary=built(entry,id,path);var record:Resource=serialized(output.native.records[id],"mixed",id)
    if record==null:return
    for seat in ["amber","blue"]:
        var directory:String="res://tests/fixtures/schema16/typed-variants-mixed-original/"+seat+"/journal"
        var journal:RefCounted=Journal.new();check(journal.open(directory,true,false).ok,seat+" original three-application cast opens")
        var cache:Dictionary=source_cache(record,id,path);var seen:int=0
        var files:PackedStringArray=DirAccess.get_files_at(directory);files.sort()
        for file in files:
            if not file.get_basename().is_valid_int():continue
            var sequence:int=int(file.get_basename());var raw:PackedByteArray=FileAccess.get_file_as_bytes(directory.path_join(file))
            var decoded:Dictionary=journal.decode_record(sequence,raw)
            check(decoded.ok,seat+" mixed original decode "+str(sequence));if not decoded.ok:break
            var before:Dictionary=journal.state;var folded:Dictionary=journal._consume_admitted(decoded.value,raw,true)
            check(folded.ok,seat+" mixed original fold "+str(sequence));if not folded.ok:break
            if sequence==0:continue
            var original_bytes:PackedByteArray=var_to_bytes(folded.normalized)
            var actual:Dictionary=Compiler.compile_recorded(before,folded.normalized,cache,journal.state,folded.transitions)
            check(actual.ok,seat+" original compiler remains valid "+str(sequence))
            var control:Dictionary=folded.normalized.duplicate(true);var outcomes:Dictionary={}
            for lineage in control.lineages:
                for original in lineage.events:
                    if original.get("resolution")==null or original.get("fact")==null or original.fact.kind!="spell":continue
                    var resolution:Dictionary=lineage.resolutions[int(original.resolution)]
                    if resolution.get("application_id")==null:continue
                    original.fact.attack_outcome=["Hit","Miss","Crit"][outcomes.size()]
                    outcomes[str(original.occurrence)]=original.fact.attack_outcome
            if outcomes.is_empty():continue
            seen+=1;check(outcomes.size()==3,seat+" independent recording has exactly three genuine application identities")
            var compiled:Dictionary=Compiler.compile_recorded(before,control,cache,journal.state,folded.transitions)
            check(compiled.ok,seat+" labelled mixed-outcome compiler control compiles")
            var tracks:Array=[];var selected:Dictionary={};var owners:Dictionary={}
            for group in compiled.value.groups:
                tracks.append_array(group.actor_tracks.filter(func(track):return track.get("activity")=="cast"))
                for component in group.components:
                    if not component.get("native_spell",false):continue
                    owners[component.native_cast_id]=true
                    if outcomes.has(component.source_event_uuid):
                        if not selected.has(component.source_event_uuid):selected[component.source_event_uuid]=[]
                        selected[component.source_event_uuid].append(component.get("native_variant",{}).get("id","default"))
            check(tracks.size()==1 and owners.size()==1,seat+" mixed application outcomes retain one original caster body and native cast owner")
            for occurrence in outcomes:
                var expected:String={"Hit":"default","Miss":"test.mixed_miss","Crit":"test.mixed_critical"}[outcomes[occurrence]]
                check(selected.has(occurrence) and selected[occurrence].all(func(value):return value==expected),seat+" application-private selection "+occurrence+" "+expected)
            check(var_to_bytes(folded.normalized)==original_bytes,seat+" original facts remain byte-exact after compiler controls")
            evidence.append({"seat":seat,"compiler_control":"mixed sibling outcomes; not an original-outcome claim","actual_application_ids":outcomes.keys(),"selected":selected,"caster_tracks":tracks.size()})
        check(seen==1,seat+" exactly one original three-application spell cast")
