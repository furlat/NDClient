class_name PresentationLookStep
extends Resource
## One step of a look. Only the fields of its kind are read.
##   palette_ramp: luminance ramp onto a palette (hand glow, sprite effects,
##     Factory effect finish, hit flash).
##   colour_replace: exact colours to targets within a tolerance.
##   tint: multiply (gear recolours, skin, hair, item variants).
##   body_adjust: tint, saturation, brightness, alpha (condition looks).
##   body_film: flowing texture ramp (rage, frenzy; petrified, barkskin).
##   outline: body outline with optional pulse.
##   layers: add, hide or replace rig slots (wings, hidden weapons).
##   pose: hold a clip role or a clip frame (paralyzed, petrified, prone).
@export_enum("palette_ramp", "colour_replace", "tint", "body_adjust", "body_film", "outline", "layers", "pose") var kind: String = "tint"
@export var palette: String = ""
@export var colours: PackedColorArray = []
@export var noise: String = ""
@export var gamma: float = 1.0
@export var ramp_floor: float = 0.0
@export var ramp_ceiling: float = 1.0
@export var uses_luma: bool = true
@export var replace_from: PackedColorArray = []
@export var replace_tolerance: float = 0.0
@export_color_no_alpha var rgb: Color = Color.WHITE
@export_range(0.0, 4.0) var saturation: float = 1.0
@export_range(0.0, 4.0) var brightness: float = 1.0
@export_range(0.0, 1.0) var alpha: float = 1.0
## body_film: texture path relative to res://assets/, its frames, fps, gain, weight, mapping.
@export var texture: String = ""
@export var texture_frames: int = 0
@export var texture_fps: float = 0.0
@export var gain: float = 1.0
@export var weight: float = 1.0
@export var mapping: String = ""
@export var width: float = 1.0
@export_color_no_alpha var pulse_colour: Color = Color.WHITE
## layers: slot -> part to add or replace; slots to hide.
@export var add: Dictionary[String, String] = {}
@export var replace: Dictionary[String, String] = {}
@export var hide: PackedStringArray = []
## pose: a clip role, or an explicit clip and frame, optionally per rig.
@export var pose_role: String = ""
@export var pose_clip: String = ""
@export var pose_frame: int = -1
@export var capture_current: bool = false
@export var pose_by_rig: Dictionary[String, String] = {}
## Fade times when the look comes and goes.
@export var fade_in: float = 0.0
@export var fade_out: float = 0.0
