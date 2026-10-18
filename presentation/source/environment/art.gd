class_name PresentationEnvironmentArt
extends Resource
## One piece of environment art, by short client id, that terrain, structures,
## objects and surfaces refer to. Its art source holds the hand-set numbers
## (cell, view order, frames, clock, scale, status); its `measurements` file
## under res://assets/measured/environment/ is the delivery's own registration
## (atlas rects, per-view contacts, depth/normal packets and their matrices),
## kept exactly as delivered.
const ArtSource = preload("res://presentation/source/art_source.gd")
@export var id: String = ""
## bank: frames per camera view (doors, props, traps, windows, destruction).
## images: single named images (floor views, wall pieces, fixture poses, flame
## frames); `images` names each one. samples: a catalogue family's every view,
## state and frame (library pieces). device: an 8-direction device bank.
## sprite: an old pre-rendered effect sheet (web, trap fields, residues).
## portal: entrance/exit page sets of a portal.
@export_enum("bank", "images", "samples", "device", "sprite", "portal") var kind: String = "images"
@export var art: ArtSource
## images: the client id of each image, parallel to art.files.
@export var images: PackedStringArray = []
## Camera quarter each view was captured from, when the bank says so (indoor
## doors are captured e0/s3/w2/n1; walls and floors e0/s1/w2/n3).
@export var camera_quarters: Dictionary[String, int] = {}
## Frame where the piece visibly changes state (-1: none marked).
@export var state_change_frame: int = -1
## The last frame is an empty end state: the piece is gone.
@export var clear_at_end: bool = false
## Numeric packets too large for one texture are split into pages by the build.
@export var paged: bool = false
## The rest pose shows this library family's original art instead of the
## bank's first frame (the reconstructed rest disagrees with the original view).
@export var rest_library: String = ""
