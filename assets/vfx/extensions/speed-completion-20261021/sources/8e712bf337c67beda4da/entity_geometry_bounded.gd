extends "res://assets/vfx/extensions/speed-completion-20261021/sources/004047466f7c8e2f212e/entity_geometry.gd"
## Opt-in Factory producer: exact original pixels/order/operands, fewer empty
## pixel scans and native transform getter calls. No public packet schema change.
var original_frame_pixels := 0
var scanned_frame_pixels := 0


func sample(world: Node,actor: String,slots: Array) -> Dictionary:
	var result:={"actor":actor,"points":[],"origin":Vector3.ZERO,"pose_key":[]}
	if not world.visual_actors.has(actor):return result
	result.origin=world.get_node(world.actor_markers[actor]).global_position
	var selected:=[]
	var relative_frames:=[]
	var entries: Array=world.visual_actors[actor].entries
	for index in range(entries.size()-1,-1,-1):
		var entry: Dictionary=entries[index]
		var slot: String=entry.actor_layer.slot
		if not entry.node.visible or not slots.has(slot) or entry.role=="shadow":continue
		var key: Array=[entry.texture_path,entry.material.get_shader_parameter("frame_uv"),world.quarter,world.character_light_profile]
		var transform: Transform3D=entry.node.global_transform
		result.pose_key.append(key)
		relative_frames.append([transform.basis,transform.origin-result.origin])
		selected.append({"entry":entry,"key":key,"slot":slot,"transform":transform})
	result.gpu_geometry_key=[result.pose_key.duplicate(true),relative_frames]
	var owner_key: Array=[actor,slots]
	var revision: Array=[result.gpu_geometry_key,result.origin]
	if world_packets.has(owner_key) and world_packets[owner_key].revision==revision:
		return world_packets[owner_key].packet.duplicate(false)
	var owned:={}
	for description in selected:
		var entry: Dictionary=description.entry
		if not cache.has(description.key):cache[description.key]=_source_points(world,entry)
		var transform: Transform3D=description.transform
		for point in cache[description.key]:
			if owned.has(point.pixel):continue
			owned[point.pixel]=true
			result.points.append({"position":transform*point.local,"normal":point.normal,"uv":point.uv,"pixel":point.pixel,"slot":description.slot})
	world_packet_builds+=1
	if not world_packets.has(owner_key):packet_order.append(owner_key.duplicate(true))
	world_packets[owner_key.duplicate(true)]={"revision":revision.duplicate(true),"packet":result}
	if packet_order.size()>PACKET_LIMIT:world_packets.erase(packet_order.pop_front())
	return result.duplicate(false)


func _source_points(world: Node,entry: Dictionary) -> Array:
	var result: Array=[]
	var source:=Geometry.record(entry.texture_path,entry.actor_layer.slot,world.catalog_cache)
	if source.is_empty():return result
	var root: String=Geometry._root(source)
	var normal_paths: Dictionary=Geometry.normal_paths(entry.texture_path,entry.actor_layer.slot,world.catalog_cache)
	if not normal_paths.ok:return result
	var paths:={"depth":root.path_join(source.files.depth),"support":root.path_join(source.files.support),
		"normal_valid":root.path_join(source.files.normal_valid),"normal":normal_paths.value[world.character_light_profile]}
	for path in paths.values():
		if not world.source_images.has(path):
			world.presentation_errors.append("Measured VFX surface not prepared: "+path)
			return result
	var colour: Image=world.source_images[entry.texture_path]
	var frame: Vector4=entry.material.get_shader_parameter("frame_uv")
	var offset:=Vector2i(roundi(frame.x*colour.get_width()),roundi(frame.y*colour.get_height()))
	var size:=Vector2i(roundi(frame.z*colour.get_width()),roundi(frame.w*colour.get_height()))
	var region:=Rect2i(offset,size)
	if size.x<=0 or size.y<=0 or not Rect2i(Vector2i.ZERO,colour.get_size()).encloses(region):
		# Retain the original behaviour for invalid/unexpected source metadata;
		# this optimization never silently clamps or reconstructs a frame.
		return super._source_points(world,entry)
	var occupied:=colour.get_region(region).get_used_rect()
	original_frame_pixels+=size.x*size.y
	scanned_frame_pixels+=occupied.size.x*occupied.size.y
	if not occupied.has_area():return result
	var depth_image: Image=world.source_images[paths.depth]
	var support_image: Image=world.source_images[paths.support]
	var valid_image: Image=world.source_images[paths.normal_valid]
	var normal_image: Image=world.source_images[paths.normal]
	var units: float=entry.material.get_shader_parameter("component_units")
	var elevation: float=entry.material.get_shader_parameter("component_elevation")
	var origin: Vector2=entry.material.get_shader_parameter("component_reconstruction_origin")
	var depth_range: Vector2=entry.material.get_shader_parameter("component_depth_range")
	var camera_basis: Basis=world.camera.global_basis
	var toward: Vector3=camera_basis.z
	var cosine:=cos(elevation)
	var sine:=sin(elevation)
	var pivot: Vector2=entry.pivot
	var ground_pixels:=float(entry.get("geometry_ground_pixels",19.))
	var horizontal:=Vector3(toward.x,0.,toward.z).normalized()
	var source_up:=Vector3(0.,cosine,0.)-horizontal*sine
	var source_toward:=horizontal*cosine+Vector3(0.,sine,0.)
	var normal_basis:=Basis(camera_basis.x,source_up,source_toward)
	# Original frame coordinates and row-major source order remain unchanged.
	# get_used_rect includes every nonzero alpha; the original>=.99 test stays.
	for y in range(occupied.position.y,occupied.end.y):
		for x in range(occupied.position.x,occupied.end.x):
			var pixel:=Vector2i(x,y)
			var sheet_pixel:=pixel+offset
			if colour.get_pixelv(sheet_pixel).a<.99:continue
			var depth: Color=depth_image.get_pixelv(sheet_pixel)
			var normal: Color=normal_image.get_pixelv(sheet_pixel)
			if depth.a<.5 or normal.a<.5 or support_image.get_pixelv(sheet_pixel).r<.5:continue
			if valid_image.get_pixelv(sheet_pixel).r<.5:continue
			var centre:=Vector2(x+.5,y+.5)
			var decoded: float=depth_range.x+(depth.r*255.-32.)*(depth_range.y-depth_range.x)/192.
			var height: float=((origin.y-centre.y)*cosine+decoded*sine)*units
			height-=ground_pixels*units
			var painted:=Vector3(centre.x-pivot.x,pivot.y-centre.y,0.)*units
			var view_depth: float=(height-(camera_basis*painted).y)/toward.y
			var direction:=Vector3(normal.r,normal.g,normal.b)*2.-Vector3.ONE
			result.append({"local":painted+Vector3(0,0,view_depth),"normal":(normal_basis*direction.normalized()).normalized(),
				"uv":centre/Vector2(size),"pixel":pixel})
	return result
