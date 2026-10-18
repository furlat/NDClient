extends RefCounted
## Stop only a source variant's explicitly excluded layers; retain native nodes
## and material references so original track/binding names remain inspectable.


static func stop(root: Node3D, excluded: Array) -> void:
	for node in excluded:
		if node is GPUParticles3D:
			node.emitting = false
			node.speed_scale = 0.0
		if node is Light3D:
			node.visible = false
	for player in root.find_children("*", "AnimationPlayer", true, false):
		var animation_root: Node = player.get_node(player.root_node)
		for library_name in player.get_animation_library_list():
			var library: AnimationLibrary = player.get_animation_library(library_name)
			for name in library.get_animation_list():
				var animation: Animation = library.get_animation(name)
				for index in animation.get_track_count():
					var path: NodePath = animation.track_get_path(index)
					var target: Node = animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
					if target in excluded:
						animation.track_set_enabled(index, false)
