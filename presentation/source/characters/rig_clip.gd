class_name PresentationRigClip
extends Resource
## One clip of a rig: the role it plays, the source animation that draws it
## (named exactly as the files name it) and the facts of that animation.
const BodySurface = preload("res://presentation/source/characters/body_surface.gd")
const ArtSource = preload("res://presentation/source/art_source.gd")
## The clip key recipes and contexts use ("Attack1", "Death", "PhysicalGesture").
@export var name: String = ""
## Shared role vocabulary: idle, walk, run, attack_1, cast, block_start, hurt, die ...
@export var role: String = ""
## The animation's own name in the delivery ("Attack 1", "Zombie melee 1", "MeleeSpin").
@export var source_clip: String = ""
@export_range(0, 1024) var frames: int = 0
## 0 means no clock is authored for this clip.
@export_range(0.0, 240.0) var fps: float = 0.0
## loop or once; rig leaves the rig's loop policy (idle and run loop, deaths hold).
@export_enum("rig", "loop", "once") var loop: String = "rig"
@export var reversed: bool = false
## Frames of this animation: prepare, release, contact, effect, recover.
@export var markers: Dictionary[String, int] = {}
## Category -> sheet key for every layer this clip draws (part sheets are
## "/spritesheets/<Part>/<Action>.png"; own sheets "/rigs/<rig>/<layer>/<clip>.png").
## Empty on the layered rig: the build takes every part that has source_clip.
@export var sheets: Dictionary[String, String] = {}
## Own-sheet art by layer role, paths relative to res://assets/: combined (the
## delivered sheet), body (the clean body shown), shadow, effect, mask_material,
## mask_component.
@export var art: Dictionary[String, String] = {}
## Effect layers the clip carries: category -> drawn (the source effect sheet is optional).
@export var effect_layers: Dictionary[String, bool] = {}
## Layered rig: the effect parts (Magic, Effect, Slash ...) this clip offers.
## Solid parts are offered whenever they have a sheet for source_clip.
@export var effect_parts: PackedStringArray = []
## The clip owns its cast preparation (casters whose cast is this clip).
@export var owns_cast_preparation: bool = false
## Depth and normals of the body layer.
@export var surface: BodySurface
## Exact native atlas per declared display facing. Empty preserves the ordinary sheet.
@export var body_banks: Dictionary[String, ArtSource] = {}
## true when this clip stands in for a role the art does not have.
@export var stand_in: bool = false
@export_multiline var notes: String = ""
