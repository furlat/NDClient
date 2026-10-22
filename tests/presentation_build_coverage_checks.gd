extends SceneTree
## The written coverage report is the Studio's shared input. These isolated
## metadata controls never build art or change the production coverage file.
const Build=preload("res://tools/build_presentation.gd")
const OUTPUT="res://.runtime/presentation-build-coverage-checks/coverage.json"
var checks:int=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr("PRESENTATION_BUILD_COVERAGE_FAIL ",label)

func written()->Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(OUTPUT))

func run()->void:
    DirAccess.make_dir_recursive_absolute(OUTPUT.get_base_dir())
    var spell:Resource=load("res://authoring/abilities/spells/spell.aegis_spark.tres")
    check(spell.status=="stand_in","The real Aegis cast gesture still requires stand-in review")
    var previous:Dictionary={"coverage":{
        "creature":{"creature.goblin":"partial","creature.removed-control":"ready"},
        "item":{"item.removed-control":"ready"},"spell":{spell.id:spell.status},
        "condition":{"condition.removed-control":"partial"},"damage_type":{"damage.removed-control":"ready"},
        "action":{"action.removed-control":"ready"},"trait":{"trait.removed-control":"ready"},
        "reaction":{"reaction.removed-control":"ready"},"class_feature":{"feature.removed-control":"ready"},
        "feat":{"feat.removed-control":"ready"},"connector":{"connector.removed-control":"ready"},
        "battlefield":{"battlefield.removed-control":"ready"},"tile_material":{"tile.removed-control":"ready"},
        "boundary_structure":{"boundary.removed-control":"ready"},"environment_object":{"door.removed-control":"partial"},
        "spatial_effect":{"field.removed-control":"ready"},"residue":{"residue.removed-control":"ready"},
        "spatial_effect_layer":{"layer.removed-control":"internal"},"light_appearance":{"light.removed-control":"ready"},
        "retired_kind":{"old-control":"ready"}},"errors":["prior failure"],"warnings":["prior warning"]}
    FileAccess.open(OUTPUT,FileAccess.WRITE).store_string(JSON.stringify(previous))
    var ids:Dictionary={"ids":{"creature":["creature.goblin","creature.removed-control"],
        "spell":[spell.id],"condition":["condition.removed-control"],"environment_object":["door.removed-control"]}}
    var current:Dictionary={"coverage":{"creature":{"creature.goblin":"ready"}},"errors":[],"warnings":["current character warning"]}
    var before:PackedByteArray=var_to_bytes(current)
    Build.publish_coverage(current,["characters"],ids,OUTPUT)
    var partial:Dictionary=written()
    check(partial.coverage.spell=={spell.id:spell.status} and partial.coverage.condition==previous.coverage.condition,
        "Character-only publication preserves the real spell stand-in and condition review rows")
    check(partial.coverage.environment_object==previous.coverage.environment_object,"Character-only publication preserves environment coverage")
    check(partial.coverage.creature=={"creature.goblin":"ready"} and not partial.coverage.has("item"),
        "Selected kinds are replaced, removing retired IDs and an entire newly empty kind")
    check(partial.errors.is_empty() and partial.warnings==current.warnings and partial.selected_domains==["characters"],
        "Diagnostics and declared build scope belong only to this invocation")
    check(partial.unlisted_server_ids=={"creature":1.0},"Gaps are recomputed against preserved and replaced coverage together")
    check(var_to_bytes(current)==before,"Publishing never adds previous domains or diagnostics to the builder's report")
    var replacement:Dictionary={"coverage":{"spell":{spell.id:spell.status},"environment_object":{"door.new-control":"ready"}},
        "errors":["current abilities failure"],"warnings":[]}
    Build.publish_coverage(replacement,["abilities","environment"],ids,OUTPUT)
    var multiple:Dictionary=written()
    check(multiple.coverage=={"creature":{"creature.goblin":"ready"},"spell":{spell.id:spell.status},
        "environment_object":{"door.new-control":"ready"},"retired_kind":{"old-control":"ready"}},
        "Two selected domains replace every owned kind without keeping omitted old IDs or erasing characters")
    check(multiple.errors==replacement.errors and multiple.warnings.is_empty(),"A new invocation neither retains old warnings nor hides its own errors")
    check(multiple.unlisted_server_ids=={"creature":1.0,"condition":1.0,"environment_object":1.0},"Removed condition and environment IDs become explicit coverage gaps")
    var full:Dictionary={"coverage":{"creature":{"creature.goblin":"ready"}},"errors":[],"warnings":[]}
    Build.publish_coverage(full,["characters","environment","abilities"],ids,OUTPUT)
    check(written().coverage==full.coverage,"A full build starts fresh, including removal of unknown historical kinds")
    DirAccess.remove_absolute(OUTPUT)
    Build.publish_coverage(current,["characters"],ids,OUTPUT)
    check(written().coverage==current.coverage,"A first partial build with no previous report publishes only actual current coverage")
    print("PRESENTATION_BUILD_COVERAGE ",JSON.stringify({"checks":checks,"failures":failures,
        "scope":"Actual isolated coverage-file publication, selected-domain replacement, preserved source review status and current-invocation diagnostics; no art or runtime qualification."}))
    quit(0 if failures.is_empty() else 1)
