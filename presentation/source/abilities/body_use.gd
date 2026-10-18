class_name PresentationBodyUse
extends Resource
## How the body plays for one spell, action, attack, condition change or
## context: a clip role on the actor's rig with its playback and markers.
## Frames are source frames of that clip; release and contact belong to the
## rig clip (characters), these are this entry's overrides of them.
## The gesture role in the shared vocabulary: cast, cast_alt, touch, attack,
## act, idle, die, hurt, ...; `clip` is the rig clip it plays today.
@export var role: String = ""
@export var clip: String = ""
@export var enabled: bool = true
@export var playback_speed: float = 1.0
## Plays the clip backwards (a reversed fall when standing up).
@export var reversed: bool = false
## Marker name -> source frame: action_start, prepare, release, contact,
## effect, recover, commit.
@export var markers: Dictionary[String, float] = {}
## Rig slots hidden while it plays (weapon, offhand).
@export var hidden_slots: PackedStringArray = []
## The rig this body applies to when it is rig-specific (empty: any rig).
@export var rig: String = ""
## Old-model fields with no runtime reader beyond the requirement reports
## (recovery poses, media lists): kept as they were exported.
@export var unported: Dictionary = {}
