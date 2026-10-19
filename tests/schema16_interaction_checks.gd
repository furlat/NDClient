extends SceneTree
## Player gestures use current native rows, offered levels and exact Preview continuations.
const Interaction=preload("res://presentation/interaction.gd")
const Choices=preload("res://sdk/choices.gd")
const UI=preload("res://presentation/ui_catalog.gd")
const Cells=preload("res://sdk/fold_cells.gd")
var passed=0
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
    if value:passed+=1
    else:failures.append(message);print("FAIL "+message)
func run()->void:
    var row={"discovery_index":0,"discovery_generation":7,"behavior_id":"spell.wall_of_fire","display_name":"Wall of Fire","action_category":"spell","target_type":"position_aoe","target_set":0,"can_afford":true,"availability_status":"available","cast_at_level":4,"cast_levels":[4,5,6],"position_region":{"range_feet":60,"candidate_source":"visible","exclude_source_position":true,"requires_axis_or_diagonal_alignment":true},"range_origin":[0,0],"variant_facets":[{"key":"form","value":"segment","label":"Segment"}]}
    var choices={"entity_uuid":"caster","discovery_generation":7,"entity_actions":[],"position_actions":[row],"self_actions":[],"object_actions":[],"target_sets":[[]],"positions":[],"subjects":[]}
    var snapshot=choices.duplicate(true);var levels=Interaction.level_rows(row)
    check(levels.size()==3,"Every offered cast level has a bounded UI choice")
    for level in levels:
        check(Interaction.owns_action(choices,level),"Offered level retains actual native row ownership")
        var selection=Interaction.selection(level,[])
        check(selection.cast_at_level==level.cast_at_level and not selection.has("_native_action"),"Selection carries chosen level without UI wrapper metadata")
    var refreshed=choices.duplicate(true)
    check(not Interaction.owns_action(refreshed,levels[1]),"A stale discovery wrapper cannot select on a fresh response")
    check(choices==snapshot,"UI level choices do not mutate native metadata")
    check(UI.available(levels[1]),"Empty enumerated targets remain available with a native free-aim region")
    var prefix=Interaction.selection(levels[1],[])
    var state={"actors":{"caster":{"last_visual_position":[0,0]}},"senses":{"visible":Cells.mask([[0,0],[1,1],[2,1],[4,4]])}}
    var aim=Interaction.extend_selection(choices,levels[1],prefix,{},[4,4],"",true,state)
    check(not aim.is_empty() and aim.selection.target_indices.is_empty() and aim.selection.extra_target_positions==[[4,4]] and aim.selection.cast_at_level==5,"First free aim reaches real Preview without inventing a target index")
    check(Interaction.extend_selection(choices,levels[1],prefix,{},[0,0],"",true,state).is_empty(),"Descriptor excludes caster cell")
    check(Interaction.extend_selection(choices,levels[1],prefix,{},[2,1],"",true,state).is_empty(),"Descriptor enforces axis or diagonal")
    check(Interaction.extend_selection(choices,levels[1],prefix,{},[13,13],"",true,state).is_empty(),"Descriptor uses native floored Euclidean range")
    var preview={"can_confirm":false,"positions":[[5,4]],"subjects":[],"target_sets":[[]],"next_target_set":0,"next_positions":[0]}
    var continuation=Interaction.extend_selection(choices,levels[1],aim.selection,preview,[5,4],"",true,state)
    check(not continuation.is_empty() and continuation.selection.extra_target_positions==[[4,4],[5,4]],"Second wall vertex comes from this exact Preview")
    preview.next_positions=[]
    check(Interaction.extend_selection(choices,levels[1],aim.selection,preview,[5,4],"",true,state).is_empty(),"Empty computed continuation cannot fall back to initial free-aim region")
    var subject_row={"discovery_index":1,"target_set":1,"cast_levels":[],"behavior_id":"spell.fire_bolt","can_afford":true,"availability_status":"available","target_type":"entity"}
    choices.entity_actions=[subject_row];choices.subjects=[{"uuid":"seen-by-this-action"}];choices.positions=[[4,4]];choices.target_sets.append([{"kind":"subject","index":0,"subject":0,"position":0}])
    var chosen=Interaction.extend_selection(choices,subject_row,Interaction.selection(subject_row,[]),{},[4,4],"seen-by-this-action")
    check(not chosen.is_empty() and chosen.selection.target_indices==[0],"Character targeting uses admitted action subject")
    check(Interaction.extend_selection(choices,subject_row,Interaction.selection(subject_row,[]),{},[4,4],"other-member-only").is_empty(),"Another contact is not fabricated into a legal subject")
    var option={"subject_uuid":"device","behavior_id":"spell.wall_of_fire","variant_facets":row.variant_facets,"template_name":"wall-item","connector_uuid":null}
    var source=row.duplicate(true);source.discovery_index=2;source.source_item_uuid="device";source.template_name="wall-item";source.interaction_affordance={"surface":"world","binding":"source_item"};source.target_set=2
    choices.object_actions=[source];choices.target_sets.append([{"kind":"self","index":0}])
    check(Interaction.admitted(choices,option).size()==1,"Item-use facet resolves real source item without retired configured_action_ref")
    var admitted=Interaction.admitted(choices,option);check(admitted.size()==1 and admitted[0].get("needs_aim",false),"World item with a free-aim region opens aiming instead of submitting an empty selection")
    var other=option.duplicate(true);other.variant_facets=[{"key":"form","value":"ring","label":"Ring"}]
    check(Interaction.admitted(choices,other).is_empty() and not Interaction.same_option(option,other),"Distinct item-use forms remain distinct")
    print(JSON.stringify({"passed":passed,"failures":failures}));quit(0 if failures.is_empty() else 1)
