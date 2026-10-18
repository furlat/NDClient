extends RefCounted
## Generated node IDs are process-local, not evidence of changing topology.
## Normalize those IDs only, retaining authored names and resolving animation
## track targets before renaming. Used by recording/comparison construction.
static func normalize(root: Node) -> void:
	var animations := []
	for node in root.find_children("*", "AnimationPlayer", true, false):
		var animation_root: Node = node.get_node_or_null(node.root_node)
		if animation_root == null:
			continue
		for library_name in node.get_animation_library_list():
			var library: AnimationLibrary = node.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				var animation: Animation = library.get_animation(animation_name)
				for track in animation.get_track_count():
					var path: NodePath = animation.track_get_path(track)
					var target: Node = animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
					if target != null:
						animations.append({"animation":animation,"track":track,"root":animation_root,"target":target,"subnames":path.get_concatenated_subnames()})
	for node in root.find_children("*", "Node", true, false):
		if str(node.name).begins_with("@"):
			node.name = "FactoryGenerated_%04d_%s" % [node.get_index(true), node.get_class()]
	for entry in animations:
		var path := str(entry.root.get_path_to(entry.target))
		if not str(entry.subnames).is_empty():
			path += ":" + str(entry.subnames)
		entry.animation.track_set_path(entry.track, NodePath(path))
