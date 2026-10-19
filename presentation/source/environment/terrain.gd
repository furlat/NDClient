class_name PresentationTerrain
extends Resource
## One server tile material (earth, sand, stone, wood, metal, fabric, glass,
## water, ice, vegetation): its floor art per camera view, how it receives
## effects, and how the material behaves under feet, blood and the elements.
const SoundRef = preload("res://presentation/source/sound_ref.gd")
const Slope = preload("res://presentation/source/environment/terrain_slope.gd")
@export var material: String = ""
## Floor art: an art entry with one image per camera view.
@export var floor: String = ""
## Other floor art a tile may use instead (none drawn today).
@export var variants: PackedStringArray = []
## Raised-edge art for a tile above its neighbour; empty: the floor art's own faces.
@export var skirt: String = ""
## flat_plane: effects lie on the tile plane. joined_faces: faces against an
## equal or higher neighbour are flattened, so raised floors join.
@export_enum("flat_plane", "joined_faces") var receiving: String = "joined_faces"
## environment: the lit environment shader. water: the animated water shader,
## driven by `water_look` and the mask, ripple and normal images.
@export_enum("environment", "water") var shader: String = "environment"
@export var water_look: Dictionary = {}
@export var water_images: Dictionary[String, String] = {}
## Material behaviour: footstep cue, how blood lies on it, whether it freezes or burns.
@export var footstep: SoundRef
@export_enum("pool", "soak", "none") var blood: String = "pool"
@export var freezes: bool = false
@export var burns: bool = false
## Stairs and ramps (server surface_kind with slope_axis) on this material.
@export var slopes: Array[Slope] = []
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
@export_multiline var notes: String = ""
