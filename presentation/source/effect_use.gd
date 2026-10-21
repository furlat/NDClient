class_name PresentationEffectUse
extends Resource
## How one Factory effect is played: the effect itself is the package clip_id
## (or selection key) in res://assets/vfx/index.json; everything here is the
## client's staging of it.
const Look = preload("res://presentation/source/look.gd")
@export var clip: String = ""
@export var selection: String = ""
## Explicit standalone PhaseResource delivered in the package's public source
## table. It is a typed source assignment, not an entry in index.json/clips.
@export var source_phase: Resource
## Exact source/public occurrence setter names required by this assignment.
@export var source_inputs: Dictionary[String, String] = {}
## Arguments of a declared source setter, in order. Names address the finite
## occurrence's projected values; no shader/source-specific dispatch is needed
## in the renderer for setters taking more than one argument.
@export var input_arguments: Dictionary = {}
## Only select after this exact source has a bounded seek/absolute clock proof.
@export var source_seekable: bool = false
## Timing role of the cue: cast, flight, strike, spray, impact, area, attached,
## application, sustain, removal, transition.
@export var role: String = ""
## Empty inherits the spell delivery scope. Explicit scopes separate a cast's
## single area source from its actually resolved recipient applications.
@export var scope: String = ""
## Object-body artwork needs the actual disclosed spatial anchor; arbitrary
## visible footprint cells are not interchangeable body placements.
@export var requires_spatial_anchor: bool = false
## Sources with their own actual footprint/cut admission omit the outer flat
## AreaMask; other spatial artwork keeps the existing receiving mask.
@export var area_mask: bool = true
## Finite native result projection: kind, projection, component_path, input_field,
## save_effect_id and damage_type. Static source/art settings stay in Factory.
@export var constructor_input: Dictionary = {}
## A finite geometry-only source starts on this actual descendant result.
## Admission/placement data do not become invented source constructor operands.
@export var observed_result: Dictionary = {}
## An actual observed effect can own this occurrence without another casting
## gesture. The factual constructor must admit it before the body is omitted.
@export var replaces_cast_body: bool = false
## Source owner contract for a child member whose public state names its exact
## retained parent: parent_field, parent_behavior_id and child_input.
@export var owner_projection: Dictionary = {}
## Exact disclosed owner state selecting this held cue. Absence of a
## required value leaves the branch absent; no gameplay is evaluated.
@export var when: Dictionary = {}
## Existing incoming body preparation retained at this actual reaction cut.
@export var incoming_track: Dictionary = {}
## Actual motion trajectory/condition predicates, cadence and authored phase.
## Movement sources use the same cue compiler and source clock as other uses.
@export var movement: Dictionary = {}
## Exact native result predicate for a finite condition response.
@export var condition_response: Dictionary = {}
## Sources with actual role mapping consume entity UUIDs in endpoint.actor.
@export var endpoint_actor_uuids: bool = false
## When it starts (cast_start, release, contact, application, removal,
## state_change, owner_start) and the delay after that.
@export var at: String = ""
@export var delay: float = 0.0
## caster_hand, caster_ground, caster_release, recipient_body, recipient_ground, cell, area.
@export var attachment: String = ""
## Optical receiver channels for a modular equipment decoration. A weapon
## channel means the exact item's separate weapon sheet, never the whole body.
@export var recipient_slots: PackedStringArray = []
## Gear.effects: empty selects an intrinsic decoration. Otherwise this use
## belongs to exact disclosed ItemRecord.effects membership with this behavior.
@export var item_effect_behavior_id: String = ""
## Optional exact public damage-type selector; never infers a damage outcome.
@export var item_effect_damage_type: String = ""
@export var follow: bool = false
@export var scale: float = 1.0
## Source-coordinate calibration, independent of artistic uniform scale.
@export var axis_scale: Vector3 = Vector3.ONE
@export var rotation_degrees: Vector3 = Vector3.ZERO
@export_enum("facing", "world", "aim") var orientation: String = "facing"
@export var offset: Vector3 = Vector3.ZERO
## Source clock window: where the clip starts, launches, makes contact and ends, and its rate.
@export var source_start: float = 0.0
@export var source_launch: float = -1.0
@export var source_contact: float = -1.0
## Contact of a source which draws its own delivery (for example a cone).
## The existing scheduler places actual recipient outcomes at this source age.
@export var result_contact_seconds: float = -1.0
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
## Exact source-owned begin/step coordinator for an explicitly selected package
## approach. Empty retains the package's production preparation contract.
@export var immutable_preparation: String = ""
## Construction operands normally select immutable dependencies. A public
## constructor with opaque owner operands can explicitly prepare the unchanged
## Phase when its source dependencies are independent of those operands.
@export_enum("construction", "phase") var preparation_inputs: String = "construction"
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
