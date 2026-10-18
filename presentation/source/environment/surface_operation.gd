class_name PresentationSurfaceOperation
extends Resource
## What a surface does under one server interaction operation (ignite, douse,
## freeze, electrify, vaporize, disperse, dry): the transition it plays and the
## surface it becomes (empty: it is removed).
const EffectUse = preload("res://presentation/source/effect_use.gd")
@export_enum("ignite", "douse", "freeze", "electrify", "vaporize", "disperse", "dry") var operation: String = "ignite"
@export var transition: EffectUse
@export var becomes: String = ""
## Another surface the operation also creates (water + vaporize -> steam).
@export var also_creates: String = ""
