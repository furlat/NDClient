class_name PresentationStructure
extends Resource
## One server boundary structure in one material (wall/stone,
## retaining_wall/wood, cliff/earth, fence/wood...): its straight and corner
## pieces per camera view, how corners join, height, cutaway and destruction.
@export_enum("wall", "retaining_wall", "cliff", "embankment", "door", "fence") var structure: String = "wall"
@export var material: String = ""
## Art entries with one image per camera view.
@export var straight: String = ""
@export var corner: String = ""
## The two boundary faces each corner view depicts (view -> [face, face]).
@export var corner_faces: Dictionary[String, PackedStringArray] = {}
## How a corner's view follows the camera quarter: against the authored face
## order (walls) or with it (cliffs).
@export_enum("against_quarter", "with_quarter") var corner_turn: String = "against_quarter"
## Art height in elevation steps; the art is not scaled to the server's height today.
@export var height_steps: int = 0
@export var scales_with_height: bool = false
## Front pieces in front of a visible tile turn translucent or hidden with the wall mode.
@export var cutaway: bool = true
## Lit from both sides (walls and doors receive light on either face).
@export var two_sided_light: bool = true
## Destruction bank shown when the piece is destroyed.
@export var destruction: String = ""
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
@export_multiline var notes: String = ""
