extends Resource
## Offline compiled receiver hooks indexed by exact original shader source hash.
## A renderer revision needs explicit preparation, never runtime code generation.
@export var programs: Dictionary = {}
@export var uniforms: Dictionary = {}
@export var default_textures: Dictionary = {}
@export var source_revisions: Dictionary = {}
