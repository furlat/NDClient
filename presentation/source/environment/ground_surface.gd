class_name PresentationGroundSurface
extends Resource
## Something that lies on the ground or fills cells: a server spatial effect
## (spatial_effect.*), a residue (residue.*), or a decal.
const EffectUse = preload("res://presentation/source/effect_use.gd")
const Operation = preload("res://presentation/source/environment/surface_operation.gd")
@export var id: String = ""
@export_enum("spatial_effect", "residue", "decal") var source_kind: String = "spatial_effect"
## Server layer: ground_surface, cloud or field (none: a mechanism with no layer).
@export_enum("ground_surface", "cloud", "field", "none") var layer: String = "ground_surface"
## The steady look and how it covers the cells.
@export var lasting: EffectUse
## Alternative actual-owner forms/state choices, sharing the same owner clock.
@export var lasting_variants: Array[EffectUse] = []
## Explicitly compile lasting into the shared native spatial-owner path.
## Legacy review studies remain inspection data until this is authored.
@export var native_staging: bool = false
## Registered environment images and their authored state/activation program.
## Actual spatial UUIDs and committed events provide membership and clocks.
@export var world_media: Dictionary = {}
@export_enum("per_cell", "area_mask", "footprint") var coverage: String = "area_mask"
## Played at creation, removal and footprint_changed.
@export var appear: EffectUse
@export var disappear: EffectUse
@export var spread: EffectUse
@export var operations: Array[Operation] = []
## Residues: the server's maximum amount, and how amount changes the look
## (grow: the stain grows with each deposit; fixed: one look).
@export var max_amount: int = 0
@export_enum("grow", "fixed") var amount_look: String = "fixed"
## Residue region particles: the measured particle set the deposit flies and
## settles with (res://assets/ relative), or another domain's asset by id.
@export var region_particles: String = ""
@export var region_asset: String = ""
## Optional existing measured local-pool profile for actual retained
## MaterialDepositSource contributions. This does not create a body release.
@export var deposit_profile: String = ""
## Existing continuous ground-motif artwork sampled by the shared environment
## material. Actual tile residue ownership supplies coverage and adjacency.
@export var floor_motifs: Dictionary = {}
## Original image face-UV registrations for inert object residues.
@export var wall_motifs: Dictionary = {}
## Whether residues on wall faces are drawn.
@export var walls: bool = false
## Old pre-rendered art for it (art entry ids) and the old presentation
## blocks kept as delivered (res://assets/ relative); not drawn today.
@export var art: PackedStringArray = []
@export var legacy: String = ""
@export_enum("ready", "partial", "stand_in", "missing", "internal") var status: String = "missing"
@export_multiline var notes: String = ""
