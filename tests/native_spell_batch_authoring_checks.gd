extends SceneTree
const Spells=preload("res://presentation/native_spell_authoring.gd")
const Playback=preload("res://presentation/native_spell_playback.gd")
const Authoring=preload("res://presentation/authoring.gd")
const Persistent=preload("res://presentation/native_persistent.gd")
var checks:int=0
var failures:Array=[]
var evidence:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);print("NATIVE_BATCH_AUTHORING_FAIL ",label)

func run()->void:
    var cache:Dictionary={}
    # The natively staged spells of the abilities source (the build's index).
    var entries:Dictionary=Spells.Sources.admission(cache).index.spells
    var expected:Array=entries.keys()
    check(entries.size()>=30 and ["spell.fire_bolt","spell.shield","spell.web","spell.magic_missile"].all(func(id):return id in expected),"Every natively staged spell is registered, the 30 the client staged among them")
    for authored in ["aid","bless","false_life","sacred_flame"]:check(not Spells.selection("spell."+authored,cache).is_empty(),authored+": source is assigned and inspectable; artwork review remains pending")
    var roles:Dictionary={}
    for id in expected:
        var selected:Dictionary=Spells.selection(id,cache)
        check(not selected.is_empty(),id+": selected imported source resolves")
        if selected.is_empty():continue
        check(selected.delivery.scope in ["area","application","single"],id+": delivery scope is explicit data")
        for field in ["deliveries","delivery_interval","body_actions","actor_items","target_position","contact_after_release","target_local"]:
            check(not selected.staging.has(field),id+": offline fixture field does not enter production selection: "+field)
        var before:Dictionary=selected.duplicate(true)
        var phases:Array=Spells.phases(selected,{"start":0.0,"prepare":0.0},1000.0,500.0,1,true)
        # Spatial owners hold their staged cue; a condition plays the package's lifecycle.
        var conditions:Array=Spells.condition_phases(selected) if selected.get("lifecycle",{}).get("owner_kind")=="spatial_effect" else []
        var owned:Array=Spells.owned_cues(selected)
        var contacts:Array=Spells.contact_phases(selected)
        var result_cues:Array=selected.staging.cues.filter(func(cue):
            return cue.source_index not in selected.get("excluded_cue_indices",[]) \
                and cue.get("constructor_input",{}).get("projection") in ["condition_contact","spatial_contact","weapon_component"])
        if id in ["spell.create_or_destroy_water","spell.enlarge_reduce","spell.plant_growth"]:delegated_phases(id,selected,phases,cache)
        elif id=="spell.magic_weapon":
            var context:Resource=load("res://authoring/abilities/contexts/item_attachments.tres")
            var matching:Array=context.effects.filter(func(use):return use.item_effect_behavior_id=="condition.spell.magic_weapon")
            check(phases.is_empty() and matching.size()==1 and matching[0].extra.get("item_lifecycle",{}).get("application")=="conditions/continuation/condition_magic_weapon_persistent/application",id+": actor-condition probes delegate to exact public item-effect membership and its measured lifecycle")
        elif id=="spell.continual_flame":
            var context:Resource=load("res://authoring/abilities/contexts/item_attachments.tres")
            var item_uses:Array=context.effects.filter(func(use):return use.item_effect_behavior_id=="condition.spell.continual_flame")
            var use:Resource=item_uses[0] if item_uses.size()==1 else null
            check(phases.is_empty() and use!=null and use.item_effect_behavior_id=="condition.spell.continual_flame" \
                and use.source_phase!=null and use.source_phase.clip_id=="production-review/continual-flame/source-hold-loop" \
                and use.source_inputs=={"root_path":"set_root_path","item_snapshot":"set_item_snapshot"} and use.source_seekable,
                id+": finite cast review delegates to the exact actual item/effect owner with a bounded clock and current item optical snapshot")
        else:
            var entry:Resource=load("res://authoring/abilities/spells/"+id+".tres")
            var delegated:Array=delegated_sources(entry,cache)
            check(not phases.is_empty() or not conditions.is_empty() or not owned.is_empty() or not delegated.is_empty() or not result_cues.is_empty(),id+": actual event, condition, item, reaction or canonical spatial owner has an authored source")
        for cue in result_cues:
            var clip:Dictionary=Spells.Effects.for_cue(cue,id,str(cue.role))
            var input:Dictionary=cue.constructor_input
            check(not clip.is_empty() and not Spells.Effects.choice(Spells.Effects.occurrence_clip({"native_clip":clip,"native_cue":cue})).approaches.is_empty(),id+": exact result-owned source resolves independently of a cast phase")
            check(input.get("kind")=="observed_event" and input.get("outcome")=="damage" \
                and (not str(input.get("damage_type","")).is_empty() or input.get("damage_type_policy")=="actual_component"),id+": deferred result cue requires its actual attributed damage contract")
            check(not phases.any(func(phase):return phase.native_cue.source_index==cue.source_index),id+": result-owned cue does not replay at the cast")
        for phase in phases+conditions+contacts:
            var cue:Dictionary=phase.native_cue
            roles[cue.role]=true
            check(not phase.native_clip.is_empty(),id+": the exact chosen clip is imported")
            var gaps:Array=cue.get("unbound_constructor_inputs",[])
            if gaps.is_empty():check(phase.get("status","available")!="missing",id+": a source with no declared input gap remains available")
            else:check(phase.get("status")=="missing" and phase.get("reason")=="native_constructor_inputs_unbound:"+",".join(gaps),id+": declared source inputs remain exactly missing instead of claiming an available source")
            # Measured bounds are keyed by the staged clip id (the package may rename it).
            var staged:String=str(cue.get("staged_clip",phase.native_clip.get("id","")))
            # Renamed/replaced sources need their actual current recording or
            # mesh contract; an unrelated historical bounds key proves neither.
            if str(selected.source).begins_with("sandbox/"):
                if selected.source_bounds.has(staged):check(true,id+": chosen clip has measured native source bounds")
                else:current_source_interval(id,phase)
            check(phase.source==cue.get("source",selected.source+"/cues/"+str(int(cue.source_index))),id+": phase keeps the exact editable authored cue pointer")
            check(phase.duration_ms>0 and not is_nan(phase.duration_ms),id+": phase duration is positive")
            check(cue.end>cue.begin and is_finite(cue.end),id+": native source has a finite visual interval")
            if cue.role in ["flight","strike"]:
                check(is_equal_approx(Playback.source_time(cue,cue.contact),cue.source_contact),id+": source contact is aligned with the actual delivery clock")
            if cue.get("stop_emission_at_contact",false):
                if selected.source_bounds.has(staged):check(cue.end+0.00001>=cue.contact+Spells.retained_particle_tail(selected.source_bounds[staged],cue,cue.contact),id+": retained source particle tail survives emission cutoff")
                else:recorded_cutoff(id,phase)
        for phase in conditions:
            check(is_inf(phase.duration_ms),id+": finite source duration is not the owner's game expiry")
            var window:Dictionary=phase.lifecycle
            check(not window.is_empty(),id+": spatial hold has an explicit authored window")
            check(window.enter_end_seconds>=0 and window.hold_start_seconds>=window.enter_end_seconds,id+": spatial entry/hold window is ordered")
            check(window.exit_start_seconds>=window.hold_start_seconds and window.exit_end_seconds>=window.exit_start_seconds,id+": spatial close window is ordered")
            check(not phases.any(func(transient):return transient.source==phase.source),id+": owner-held cue is not duplicated by event phases")
        for index in owned:
            check(not phases.any(func(transient):return int(transient.native_cue.source_index)==int(index)),id+": the cue the condition lifecycle carries is not played again at the cast")
        var lifecycle:Dictionary=selected.lifecycle
        if lifecycle.get("owner_kind")=="condition":
            for condition_id in lifecycle.owner_ids:
                var typed_path:String="res://authoring/abilities/conditions/"+condition_id+".tres"
                var typed:Resource=load(typed_path) if ResourceLoader.exists(typed_path) else null
                if typed!=null and not typed.inherit_spell_finish:
                    check(Spells.condition(condition_id,cache).is_empty(),id+": explicit condition finish refuses arbitrary parent-spell inheritance")
                    check(not Spells.Effects.conditions(condition_id).is_empty() or not typed.effects.is_empty(),id+": the condition owns its independently authored finish")
                else:check(Spells.condition(condition_id,cache).get("id")==selected.id,id+": exact disclosed condition behavior selects its source")
                if condition_id=="condition.spell.aura_of_life.owner":
                    var member:Array=Spells.Effects.conditions("condition.spell.aura_of_life.benefit")
                    check(member.size()==1 and member[0].key=="condition_aura_of_life_benefit_persistent" and member[0].condition.owner_ids==["condition.spell.aura_of_life.benefit"],id+": existing member lifecycle owns only the actual benefit, separate from the explicit main field owner")
                    check(owned==[1,2,3] and not phases.any(func(phase):return phase.native_clip.id=="high-level-22/aura-of-life/field"),id+": the main field cannot be credited as a finite cast or borrowed member lifecycle")
                    var owner:Resource=load("res://authoring/abilities/conditions/condition.spell.aura_of_life.owner.tres")
                    check(owner.effects.size()==1 and owner.effects[0].source_phase!=null \
                        and owner.effects[0].source_phase.clip_id=="production-review/aura-of-life/main_owner" \
                        and owner.effects[0].source_inputs=={"root_path":"set_root_path","owner_binding":"set_owner_binding","actual_owner_state":"set_owner_state"} \
                        and owner.effects[0].at=="owner_start" and owner.effects[0].fade_out==.38,
                        id+": exact standalone main-owner source binds actual condition/self identities, observed state/root and removal clock")
                elif condition_id=="condition.spell.magic_weapon":
                    var delegated:Resource=load("res://authoring/abilities/conditions/condition.spell.magic_weapon.tres")
                    check(not delegated.play_package_lifecycle and Spells.Effects.conditions(condition_id).is_empty(),id+": item membership does not fabricate an actor condition lifecycle")
                elif typed!=null and not typed.effects.is_empty():
                    var recipe:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache).get(condition_id,{})
                    check(not Persistent.authored_phases(recipe,condition_id,cache).is_empty(),id+": typed owner effects replace the old package review lifecycle for "+condition_id)
                else:check(not Spells.Effects.conditions(condition_id).is_empty(),id+": the package has a lifecycle for "+condition_id)
            if owned.is_empty():
                check(lifecycle.cue_ids.all(func(index):return phases.any(func(transient):return int(transient.native_cue.source_index)==int(index)) or int(index) in selected.get("excluded_cue_indices",[])),id+": a marker-only condition keeps the spell's own cue at the cast")
        check(before==selected,id+": phase compilation leaves retained authoring immutable")
        evidence.append({"spell_id":selected.id,"scope":selected.delivery.scope,"event_phases":phases.size(),"owner_phases":conditions.size(),"owned_cues":owned,"interception_phases":contacts.size(),"result_cues":result_cues.size(),"owners":lifecycle.get("owner_ids",[])})
    for role in ["cast","flight","impact","strike","spray","area","attached"]:check(roles.has(role),"Whole batch covers native role "+role)
    var shield=Spells.selection("spell.shield",cache)
    check(Spells.phases(shield,{"start":0},0,0,0,true).is_empty(),"Shield casting does not invent a hostile projectile or interception")
    var contact=Spells.contact_phases(shield)
    check(contact.size()==1 and contact[0].native_cue.role=="attached","Real Shield interception has exactly its native contact source")
    for field in ["launch_delay_seconds","from_actor","to_actor","travel_to_target"]:check(not contact[0].native_cue.has(field),"Shield interception omits demonstration field "+field)
    var lit:Dictionary={"id":"condition:light","actor_uuid":"actor","condition":{"behavior_id":"condition.spell.light","state":{}},"start_ms":0.0,"absolute_start_ms":0.0,"duration_ms":INF,"age_ms":0.0,"removal_age_ms":null,"initial":false}
    var light=Persistent.lifecycle_samples(lit,Persistent.lifecycles(lit.condition),cache)
    check(light.size()==1 and light[0].optical.energy_multiplier==0 and light[0].optical.owner=="authoritative_light","Native Light visual does not duplicate authoritative optical illumination")
    check(Spells.owned_cues(shield)==[0] and Spells.owned_cues(Spells.selection("spell.command",cache)).is_empty(),"Shield's bubble is the condition's; Command's glyph stays at its cast beside the marker")
    var ice=Spells.selection("spell.ice_knife",cache)
    check(ice.delivery.effects["spell.ice_knife.burst"].roles==["area"],"Ice Knife burst is separately selected by the actual burst effect ID")
    var report={"checks":checks,"failed":failures.size(),"failures":failures,"spells":evidence,"source_records":expected.size(),"scope":"Complete current built native source inventory, authored roles/clocks/tails, exact replacement recording/mesh contracts, delegated spatial/condition phases and explicit ambiguous parent ownership. Declared constructor gaps stay missing. Standalone Aura main-owner and exact Continual item-membership assignments remain separate from native pixel qualification; this metadata gate does not claim dynamic binding or artwork approval."}
    FileAccess.open("res://.runtime/native-spell-batch-authoring-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_BATCH_AUTHORING ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
    quit(0 if failures.is_empty() else 1)

func current_source_interval(id:String,phase:Dictionary)->void:
    var clip:Dictionary=Spells.Effects.occurrence_clip(phase)
    var chosen:Dictionary=Spells.Effects.choice(clip)
    if id in ["spell.chill_touch","spell.sleep","spell.false_life","spell.sacred_flame"]:
        check(chosen.kind=="recorded" and chosen.approaches.size()==3,id+": replacement keeps all three exact recorded source variants")
        for approach in chosen.approaches:
            var bundle:Resource=load(approach.path)
            check(bundle!=null,id+": replacement recording resource loads")
            if bundle==null:continue
            check(bundle.clip_id==phase.native_clip.id and bundle.frames==int(approach.frames) and is_equal_approx(bundle.rate,float(approach.rate)),id+": recording belongs to exact staged replacement and frame lattice")
            check(bundle.gaps.is_empty() and approach.seekable,id+": actual recording has no omitted source channels and supports seek")
            check(float(bundle.frames-1)/bundle.rate+.00001>=float(phase.native_cue.source_end),id+": recorded frame lattice covers the complete authored source interval")
        return
    if id=="spell.web" and clip.id=="original-repairs/web/continuous-net/lifecycle":
        check(chosen.kind=="gpu" and chosen.approaches.size()==1,id+": continuous net selects its exact mesh program")
        var source:Resource=load(chosen.approaches[0].source_phase)
        var description:Dictionary=source.to_clip()
        check(description.emitters.is_empty() and description.components.size()==1,id+": replacement mesh has no particle-tail system")
        var part:Dictionary=description.components[0]
        check(source.validate().is_empty() and part.script=="res://assets/vfx/sources/23ba344795a148310791/anchored_web.gd",id+": replacement uses the validated sealed anchored mesh constructor")
        var input:Dictionary=part.input
        check(float(input.rise_seconds)>0.0 and float(input.release_seconds)>0.0 and float(input.source_size)==10.6 and int(input.source_subdivisions)==100,id+": explicit source dimensions and formation/retirement clocks remain present")
        check(FileAccess.file_exists(input.source_shader) and ResourceLoader.exists(input.source_texture),id+": exact continuous source shader and texture resolve")
        check(["binding_owners","targets","recipient_geometry"].all(func(channel):return channel in clip.inputs and clip.input_setters.has(channel)),id+": mesh still requires actual binding owners, targets and recipient geometry")
        check(is_equal_approx(float(phase.native_cue.source_end),2.0) and phase.get("lifecycle",{})=={"enter_end_seconds":.8,"exit_end_seconds":.8,"exit_start_seconds":.8,"hold_start_seconds":.8},id+": selected source keeps its explicit owner-held mesh window; no particle-bound duration is fabricated")
        return
    check(false,id+": chosen clip lacks both exact measured bounds and an exact current source interval: "+str(clip.id))

func recorded_cutoff(id:String,phase:Dictionary)->void:
    var chosen:Dictionary=Spells.Effects.choice(Spells.Effects.occurrence_clip(phase))
    check(id=="spell.sleep" and chosen.kind=="recorded" and chosen.approaches.size()==3,id+": cutoff fallback is limited to the exact recorded replacement")
    for approach in chosen.approaches:
        var bundle:Resource=load(approach.path)
        check(bundle!=null and bundle.systems.is_empty() and bundle.trails.is_empty(),id+": actual recorded replacement has no emitted particle or trail tail to truncate")
    check(phase.native_cue.end>=phase.native_cue.contact and is_equal_approx(Spells.retained_particle_tail({},phase.native_cue,phase.native_cue.contact),0.0),id+": particle-free recorded cutoff retains its whole finite contact interval")

func delegated_phases(id:String,selected:Dictionary,phases:Array,cache:Dictionary)->void:
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache)
    check(phases.is_empty() and Spells.owned_cues(selected).is_empty(),id+": actual owner source is not duplicated as a spell event")
    if id=="spell.enlarge_reduce":
        check(selected.excluded_cue_indices==[0,1],id+": both demonstration spell cues remain explicitly excluded")
        var authored:Array=Persistent.authored_phases(recipes["condition.spell.enlarge_reduce"],"condition.spell.enlarge_reduce",cache)
        check(authored.size()==2,id+": actual size owner has exactly two finite selector sources")
        for mode in ["enlarge","reduce"]:
            var expected:String=("enlarge_reduce_native" if mode=="enlarge" else "enlarge_reduce_reduce_native")+"/application"
            var matches:Array=authored.filter(func(phase):return phase.source_id==expected and phase.native_cue.get("when",{})=={"size_change":mode})
            check(matches.size()==1 and matches[0].native_cue.authored_at=="application" and is_equal_approx(matches[0].duration_ms,720.0),id+": exact "+mode+" selector owns one .72second application")
        return
    var owner:String="spatial_effect.material.water_surface" if id=="spell.create_or_destroy_water" else "spatial_effect.spell.plant_growth"
    var authored:Array=Persistent.authored_phases(recipes[owner],owner,cache)
    if id=="spell.plant_growth":
        check(selected.excluded_cue_indices==[0] and authored.size()==1,id+": demonstration is replaced by exactly one spatial owner source")
        var cue:Dictionary=authored[0].native_cue
        check(authored[0].source_id=="bg3-36/plant-growth/plant_growth_native" and cue.authored_at=="owner_start" and is_inf(cue.end),id+": actual spatial lifetime holds the precise vegetation source")
        check(cue.constructor_input=={"kind":"spatial_owner","component_path":["nature"],"input_field":"","content_id":owner,"cell_input":"cells"},id+": exact actual footprint supplies source cells rather than a review patch")
    else:
        check(selected.excluded_cue_indices==[0,1] and authored.size()==2,id+": cast probes are replaced by exact water admission and DRY sources")
        var created:Dictionary=authored[0];var dry:Dictionary=authored[1]
        check(created.source_id=="bg3-36/create-or-destroy-water/create" and created.native_cue.authored_at=="owner_start" and is_inf(created.native_cue.end),id+": current water UUID owns the held native source")
        check(dry.source_id=="bg3-36/create-or-destroy-water/destroy" and dry.native_cue.authored_at=="spatial_removal" and dry.native_cue.spatial_removal_when=={"interaction_operation":"dry"} and is_equal_approx(dry.duration_ms,1200.0),id+": only an actual DRY removal owns the finite clear source")
        check(authored.all(func(phase):return phase.native_cue.constructor_input=={"kind":"spatial_owner","component_path":["surface"],"input_field":"","content_id":owner,"cell_input":"surface_groups"}),id+": both water phases consume exact admitted spatial surface groups")
        var wet:Array=Persistent.authored_phases(recipes["unbound:dnd.spatial.environmental_conditions.Wet"],"unbound:dnd.spatial.environmental_conditions.Wet",cache)
        check(wet.size()==1 and wet[0].source_id=="bg3-36/create-or-destroy-water/rain-wet" and wet[0].native_cue.membership_input=="wet_presence",id+": null-behavior Wet keeps its exact semantic owner and factual membership setter")

## Resolve explicit typed ownership, never activate an excluded cast review to
## make this inventory green. Native execution and current fact binding have
## their own gates; this checks that the named delegated source really exists.
func delegated_sources(entry:Resource,cache:Dictionary)->Array:
    var result:Array=[]
    var surfaces:Array=Array(entry.applies_surfaces)
    if entry.id=="spell.antimagic_field":surfaces.append("spatial_effect.spell.antimagic_field")
    for identity in surfaces:
        var config:Dictionary=Persistent.spatial_config(identity,cache)
        var phases:Array=Persistent.authored_phases(config,identity,cache)
        if not phases.is_empty():
            check(phases.all(func(phase):return not phase.native_clip.is_empty() and phase.get("status","available")!="missing"),entry.id+": exact canonical field source admits "+identity)
            result.append({"owner":identity,"phases":phases.size()})
    var recipes:Dictionary=Authoring.load_data("catalog/condition_recipes.json",cache)
    for identity in entry.applies_conditions:
        var config:Dictionary=recipes.get(identity,{})
        var phases:Array=Persistent.authored_phases(config,identity,cache)
        if not phases.is_empty():
            check(phases.all(func(phase):return not phase.native_clip.is_empty() and (phase.get("status","available")!="missing" \
                or not phase.native_cue.get("unbound_constructor_inputs",[]).is_empty())),entry.id+": exact typed condition source or explicit required-input refusal admits "+identity)
            result.append({"owner":identity,"phases":phases.size()})
    if entry.id=="spell.counterspell":
        var reaction:Resource=load("res://authoring/abilities/actions/reaction.spell.counterspell.tres")
        check(reaction.effects.size()==2 and reaction.effects.all(func(use):return use.constructor_input.get("kind")=="reaction_observation"),entry.id+": exact reaction owns success/failure source selection")
        result.append({"owner":reaction.id,"phases":reaction.effects.size()})
    return result
