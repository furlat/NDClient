extends Resource
## Reusable local electric detail. No camera, target arrangement or actor data.
@export var source_seed: int = 0
@export var reference_length_cells: float = 32.0
@export var primary_lanes: int = 1
@export var primary_segments: int = 131
@export var fork_count: int = 36
@export var fork_samples: int = 13
@export var variations: int = 32
@export var morphology_hz: float = 11.0
@export var atlas: Image
@export var source_paths: PackedStringArray = []
@export var source_recipe: Dictionary = {}
