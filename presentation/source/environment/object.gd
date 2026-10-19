class_name PresentationEnvironmentObject
extends Resource
## One environment object: a server environment item id (doors, windows,
## furniture, chests, traps, levers, torches, devices, barrels...) or, in the
## library section, a catalogue piece no server id uses yet.
const ImageRef = preload("res://presentation/source/image_ref.gd")
const State = preload("res://presentation/source/environment/object_state.gd")
const Transition = preload("res://presentation/source/environment/object_transition.gd")
const Part = preload("res://presentation/source/environment/object_part.gd")
@export var id: String = ""
## door, window, furniture, chest, trap, lever, torch, campfire, device, blocker,
## barrel, wall, cliff, spell_object, decor, ground, roof, flora, ...
@export var kind: String = ""
## Camera views the art has, in the order the art stores them.
@export var views: PackedStringArray = []
## Server field whose value selects the state (is_open, is_engaged, trap_state);
## doors select by is_open and door_swing.
@export var select_field: String = ""
## State -> what is shown at rest. Keys are the server values as the game names
## them: default, true/false, closed, open.inward, open.outward, ready, activated.
@export var states: Dictionary[String, State] = {}
## Destroyed state (state, or state.outcome for doors) -> destruction bank,
## shown at its last frame; the second set applies when an attachment is gone.
@export var destructions: Dictionary[String, String] = {}
@export var destructions_without_attachments: Dictionary[String, String] = {}
## Remnant item ids the server may name for a destroyed object -> outcome.
@export var wrecks: Dictionary[String, String] = {}
@export var transitions: Array[Transition] = []
@export var parts: Array[Part] = []
## Light: an appearance in the lighting section and the flame art it plays while lit.
@export var light: String = ""
@export var flame: String = ""
## Picking masks and window apertures per camera view.
@export var hit_masks: Dictionary[String, ImageRef] = {}
@export var aperture_masks: Dictionary[String, ImageRef] = {}
## Draw inputs: grid footprint, height, flat on the ground (authored; the draw
## order does not use it today), whether it hides an actor's face behind it,
## and the passage point through an opening (object-local).
@export var footprint: Vector2i = Vector2i.ONE
@export var height_steps: int = 0
@export var flat_ground: bool = false
@export var occludes_actor_face: bool = false
@export var passage_point: Vector3 = Vector3.ZERO
## The art that draws it when no state applies (catalogue pieces, devices,
## portals): art entry ids.
@export var art: PackedStringArray = []
## Catalogue identity (library pieces): group (A vendor, B reviewed animated
## versions, C new props), label, the vendor original it modifies.
@export var catalogue_group: String = ""
@export var label: String = ""
@export var original: String = ""
## Delivery-only blocks kept as delivered (door assemblies, source records), res://assets/ relative.
@export var measurements: String = ""
## Where it has no art of its own: the object whose art draws it instead, silently (status stand_in).
@export var stand_in: String = ""
@export var icon: ImageRef
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
@export_multiline var notes: String = ""
