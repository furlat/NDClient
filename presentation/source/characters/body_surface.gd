class_name PresentationBodySurface
extends "res://presentation/source/surface.gd"
## The depth/normal packet of one body or part sheet: the shared surface fields
## plus the delivery's validation status and its per-frame qualifications.

## validated_complete, validated_partial, excluded_non_solid (effects, shadow),
## empty_source_no_surface (blank sheets).
@export var status: String = ""
## Qualification flags the delivery raised for this sheet (silhouette_iou_below_75_percent ...).
@export var flags: PackedStringArray = []
## The delivered depth range at full precision (depth_range holds it at float precision).
@export var depth_limits: PackedFloat64Array = []
