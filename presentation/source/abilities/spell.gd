class_name PresentationSpell
extends Resource
## One server spell id (spell.fire_bolt): how the client presents casting it.
## The body side (gesture, release, hand glow) is the client's; the effects
## are Factory clips (assets/vfx/index.json) staged here; conditions and
## surfaces it creates are referenced, never repeated.
const EffectUse = preload("res://presentation/source/effect_use.gd")
const ImageRef = preload("res://presentation/source/image_ref.gd")
const SoundRef = preload("res://presentation/source/sound_ref.gd")
const Look = preload("res://presentation/source/look.gd")
const Palette = preload("res://presentation/source/palette.gd")
const BodyUse = preload("res://presentation/source/abilities/body_use.gd")
const CastLayer = preload("res://presentation/source/abilities/cast_layer.gd")
const SpellVariant = preload("res://presentation/source/abilities/spell_variant.gd")

@export var id: String = ""
@export var icon: ImageRef
## projectile, ray, touch, melee_spell, self, cone, line, sphere, wall, zone,
## cloud, summon, buff, teleport (from the server's delivery shape).
@export var delivery: String = ""

@export_group("Body")
## Gesture role and clip, playback, release/prepare frames, hidden slots.
@export var body: BodyUse
## Sprite overlays drawn on the caster during the cast (hand glow, effects).
@export var hand_layers: Array[CastLayer] = []
## Measured hand/release sockets per facing (res path relative to res://assets/).
@export var sockets: String = ""

@export_group("Effects")
## The staged effects, in cue order; each cue's role is its phase (cast,
## flight, strike, spray, impact, area, attached).
@export var effects: Array[EffectUse] = []
## True when these effects play in the game (the spell is staged natively);
## false keeps the old sprite path and the effects are review data.
@export var native_staging: bool = false
## Which cues play per fact: single, application or area.
@export var effect_scope: String = ""
## Roles kept for the whole spell, and per server effect id {roles, scope}.
@export var effect_roles: PackedStringArray = []
@export var effect_roles_by_effect: Dictionary = {}
## Cues that play only for explicit events; cues never played in the game
## (sandbox probes).
@export var event_cues: PackedInt32Array = []
@export var explicit_event_cues: bool = false
@export var excluded_cues: PackedInt32Array = []
## Lifecycle owner: the condition or spatial effect whose owner plays the
## cues in `owner_cues` (windows in each effect's `lifecycle`), contact cues
## played on real interceptions, and who owns its light.
@export var owner_kind: String = ""
@export var owner_ids: PackedStringArray = []
@export var owner_cues: PackedInt32Array = []
@export var contact_cues: PackedInt32Array = []
@export var optical_owner: String = ""
## Missile bends per application (sideways, up), in world units.
@export var bends: Array = []
## Effect light colour override and the decorative light multiplier.
@export var light_colour: String = ""
@export var light_multiplier: float = -1.0

@export_group("Flight")
## Projectile speed in tiles per second (0: the default 800 px/s), the
## shortest travel and the delay between missiles.
@export var flight_tiles_per_second: float = 0.0
@export var minimum_travel_seconds: float = -1.0
@export var stagger_seconds: float = -1.0

@export_group("Hit")
## Damage response delay after contact, hit flash and number frames (on the
## recipient's hurt clip), flash duration and look, number duration.
@export var impact_delay: float = -1.0
@export var flash_frame: float = -1.0
@export var flash_duration: float = -1.0
@export var flash_look: Look
@export var number_frame: float = -1.0
@export var number_duration: float = -1.0
## Native body-material hit: the package clip and node whose material
## shades the recipient (clip, node, surface, clock parameter, overrides).
@export var body_material: Dictionary = {}

@export_group("Palette")
## Element colours (primary, secondary, tertiary); empty inherits the damage type's.
@export var colours: Palette
## Finish of the Factory effects: a palette_ramp step and its parameters.
@export var finish: Look
## Ordered hand/flash ramp the staging asked for (feedback palette).
@export var feedback_ramp: PackedStringArray = []

@export_group("References")
@export var variants: Array[SpellVariant] = []
## Condition and spatial-effect ids it creates, and the creatures it summons.
@export var applies_conditions: PackedStringArray = []
@export var applies_surfaces: PackedStringArray = []
@export var summons: PackedStringArray = []
@export var sounds: Array[SoundRef] = []

@export_group("Status")
## Where the staging values came from: client or factory@<package version>.
@export var staging_from: String = ""
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
## Measured effect bounds (animation end, particle tails, emitters, lights)
## per staged clip, res path relative to res://assets/.
@export var bounds: String = ""
## Staging fields the game reads with no typed home yet (the staging's
## source pointer, the finish profile's other parameters), as imported.
@export var staging_unported: Dictionary = {}
## Old-model recipe fields with no typed home (condition, contact, media,
## area, arcs, ... and the rest of projectile/damage), kept as exported: the
## requirement reports list them as gaps; nothing renders them.
@export var unported: Dictionary = {}
@export_multiline var notes: String = ""
