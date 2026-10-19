extends RefCounted
## Test-only staging of an existing delivered coating, never production art.
const Sources=preload("res://presentation/body_sources.gd")
const Builder=preload("res://tools/presentation_build/characters.gd")
const BodyIndex=preload("res://presentation/resources/body_source_index.gd")
static func cache(impact:bool=false)->Dictionary:
    var current:Dictionary=Sources.admission({})
    var selected:Resource=current.index.duplicate(false)
    var staged=BodyIndex.new()
    var fixture=load("res://tests/fixtures/wielded_weapon_impact.tres" if impact else "res://tests/fixtures/wielded_weapon_overlay.tres")
    var scimitar=load("res://authoring/characters/gear/weapon.scimitar.tres")
    var gear:Dictionary={fixture.id:fixture}
    if not impact:gear[scimitar.id]=scimitar
    Builder._equipment({"index":staged},gear)
    selected.item_effects=staged.item_effects
    selected.item_impact_effects=staged.item_impact_effects
    return {Sources.KEY:{"index":selected,"loaded":current.loaded}}
