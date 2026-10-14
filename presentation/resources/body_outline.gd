class_name PresentationBodyOutline
extends Resource
## Passive parameters for the existing assembled-alpha Pygame contour mechanism.
@export_color_no_alpha var color: Color = Color.WHITE
@export_color_no_alpha var pulse_color: Color = Color.WHITE
@export_range(1, 255) var alpha_threshold: int = 100
@export_range(0.0, 1.0) var opacity: float = 0.55
@export_range(0.0, 1.0) var pulse_opacity: float = 0.75
@export_range(1.0, 10000.0) var period_ms: float = 1400.0
@export_range(1.0, 10000.0) var onset_ms: float = 300.0
