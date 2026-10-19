extends RefCounted
## Test-only staging of an existing delivered coating, never production art.
const Sources=preload("res://presentation/body_sources.gd")
const Builder=preload("res://tools/presentation_build/characters.gd")
const BodyIndex=preload("res://presentation/resources/body_source_index.gd")
static func cache()->Dictionary:
    var current:Dictionary=Sources.admission({})
    var selected:Resource=current.index.duplicate(false)
    var staged=BodyIndex.new()
    var fixture=load("res://tests/fixtures/wielded_weapon_overlay.tres")
    var scimitar=load("res://authoring/characters/gear/weapon.scimitar.tres")
    Builder._equipment({"index":staged},{fixture.id:fixture,scimitar.id:scimitar})
    selected.item_effects=staged.item_effects
    return {Sources.KEY:{"index":selected,"loaded":current.loaded}}
