class_name PresentationEffectUse
extends Resource
## How one Factory effect is played: the effect itself is the package clip_id
## (or selection key) in res://assets/vfx/index.json; everything here is the
## client's staging of it.
const Look = preload("res://presentation/source/look.gd")
@export var clip: String = ""
@export var selection: String = ""
## Timing role of the cue: cast, flight, strike, spray, impact, area, attached,
## application, sustain, removal, transition.
@export var role: String = ""
## Empty inherits the spell delivery scope. Explicit scopes separate a cast's
## single area source from its actually resolved recipient applications.
@export var scope: String = ""
## Finite native result projection: kind, component_path, input_field,
## save_effect_id and damage_type. Static source/art settings stay in Factory.
@export var constructor_input: Dictionary = {}
## Sources with actual role mapping consume entity UUIDs in endpoint.actor.
@export var endpoint_actor_uuids: bool = false
## When it starts (cast_start, release, contact, application, removal,
## state_change, owner_start) and the delay after that.
@export var at: String = ""
@export var delay: float = 0.0
## caster_hand, caster_ground, caster_release, recipient_body, recipient_ground, cell, area.
@export var attachment: String = ""
@export var follow: bool = false
@export var scale: float = 1.0
@export var rotation_degrees: Vector3 = Vector3.ZERO
@export_enum("facing", "world", "aim") var orientation: String = "facing"
@export var offset: Vector3 = Vector3.ZERO
## Source clock window: where the clip starts, launches, makes contact and ends, and its rate.
@export var source_start: float = 0.0
@export var source_launch: float = -1.0
@export var source_contact: float = -1.0
@export var source_end: float = -1.0
@export var source_rate: float = 1.0
@export var charge_seconds: float = 0.0
@export var charge_scale_from: float = -1.0
## authored: do not extend to the animation end.
@export var duration_policy: String = ""
@export var stop_emission_at_contact: bool = false
@export var stop_emission_at_release: bool = false
@export var emission_seconds: float = -1.0
@export var hide_at_contact: PackedStringArray = []
@export var hide_at_release: PackedStringArray = []
@export var hide_nodes: PackedStringArray = []
@export var show_nodes: PackedStringArray = []
@export var origin_path: String = ""
@export var opacity_keys: PackedVector2Array = []
@export var opacity_uniform: String = ""
@export var fade_in: float = 0.0
@export var fade_out: float = 0.0
## Lifecycle windows for lasting cues (enter end, hold, exit) when the clip has no own phases.
@export var lifecycle: Dictionary = {}
@export var light_colour: Color = Color(0, 0, 0, 0)
@export var light_multiplier: float = 1.0
@export var finish: Look
## recorded, gpu or native; empty means the client's default choice.
@export var approach: String = ""
## Qualified absolute material/geometry clocks have no particle history.
## Empty preserves the delivered approach's simulation policy.
@export var sampling: String = ""
## Required source-constructor operands which the client cannot yet supply.
## Keep the cue inspectable, but do not construct it with Factory fixture data.
@export var unbound_constructor_inputs: PackedStringArray = []
## Where the values came from, e.g. "factory@20261018-fa4e64489d2d25a8" or "client".
@export var staging_from: String = ""
## Any field the Factory or a later need adds before it gets its own export.
@export var extra: Dictionary = {}
