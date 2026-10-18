extends RefCounted
## Runtime counterpart to GLTFDocument authoring calls. The Factory already
## generated and saved the scene; the game never invokes a model importer.
const PackageIO = preload("res://assets/vfx/sources/6c7e97d33d579dd6b3bc/resource_io.gd")
var scene: PackedScene


func append_from_file(path: String, _state: GLTFState) -> Error:
	scene = PackageIO.resource(path)
	return OK if scene != null else ERR_CANT_OPEN


func generate_scene(_state: GLTFState) -> Node3D:
	return scene.instantiate()
