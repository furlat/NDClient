extends RefCounted
## Test-only staging of an existing delivered coating, never production art.
const Sources=preload("res://presentation/body_sources.gd")
const Builder=preload("res://tools/presentation_build/characters.gd")
const BodyIndex=preload("res://presentation/resources/body_source_index.gd")
const Common=preload("res://tools/presentation_build/common.gd")

## Supply actual source registrations required by the same equipment build.
## Fixture coatings still use their ordinary held/item-effect admission.
static func equipment(index:Resource,gear:Dictionary)->void:
    var root:Resource=load("res://authoring/characters.tres")
    var current:Dictionary=Sources.admission({})
    index.root_rig=current.index.root_rig
    var state:Dictionary={"index":index,"rigs":{},"parts":{},"headers":{},"report":Common.report()}
    state.rigs[index.root_rig]=load(root.sections.rigs[index.root_rig])
    for entry in gear.values():
        for ground in entry.ground:
            for field in ["part","shadow_part"]:
                var part:String=str(ground.get(field,""))
                if not part.is_empty():state.parts[part]=load(root.sections.parts[part])
    Builder._equipment(state,gear)
    assert(state.report.errors.is_empty(),"Fixture equipment retains valid actual source registrations")

static func cache(impact:bool=false)->Dictionary:
    var current:Dictionary=Sources.admission({})
    var selected:Resource=current.index.duplicate(false)
    var staged=BodyIndex.new()
    var fixture=load("res://tests/fixtures/wielded_weapon_impact.tres" if impact else "res://tests/fixtures/wielded_weapon_overlay.tres")
    var scimitar=load("res://authoring/characters/gear/weapon.scimitar.tres")
    var gear:Dictionary={fixture.id:fixture}
    if not impact:gear[scimitar.id]=scimitar
    equipment(staged,gear)
    selected.item_effects=staged.item_effects
    selected.item_impact_effects=staged.item_impact_effects
    return {Sources.KEY:{"index":selected,"loaded":current.loaded}}
