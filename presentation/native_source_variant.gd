extends Resource
## Offline prepared donor resources; no event, recipient or simulated history.
@export var format_version:int=2
@export var specification:Dictionary={}
@export var dependencies:Dictionary={}
@export var scene:PackedScene
@export var adapters:Array[Dictionary]=[]
@export var clocks:Array[Dictionary]=[]
## These are the exact prototype resources referenced by scene. Holding their
## native programs avoids regenerating them for each private scene instance.
@export var program_materials:Array[Material]=[]
@export var materials:Array[Dictionary]=[]
## Exact authored BaseMaterial3D fields prepared after donor material setup.
## Runtime checks the post-sample value before omitting an identical setter.
@export var material_overrides:Array[Dictionary]=[]
@export var after_ready:Array[Dictionary]=[]
