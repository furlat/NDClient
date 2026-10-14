class_name PresentationFeedbackText
extends Resource
## Independent floating feedback: it does not hold the authoritative event join.
@export var enabled: bool = true
@export var prefix: String = "+"
@export var color: Color = Color.WHITE
@export_range(1.0, 10000.0) var duration_ms: float = 1400.0
