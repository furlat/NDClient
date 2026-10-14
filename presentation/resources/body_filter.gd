class_name PresentationBodyFilter
extends Resource
## Shared source-colour operations, sampled per actor; never mutable playback state.
@export_range(0.0, 1.0) var opacity: float = 1.0
@export_color_no_alpha var tint: Color = Color.WHITE
@export_range(0.0, 2.0) var saturation: float = 1.0
@export_range(0.0, 2.0) var brightness: float = 1.0
