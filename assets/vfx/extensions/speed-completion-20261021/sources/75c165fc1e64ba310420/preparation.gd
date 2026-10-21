extends RefCounted
## Explicit, bounded publication work on actual immutable Images.
## get_data is one separately measured native operation; hashing/building step.
const Recipe = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/6a377421dc20574abb2a/recipe.gd")
const FIELDS: Array[String] = ["colour", "depth", "support", "normal_valid", "normal"]
const HASH_BYTES := 65536
const PIXELS_PER_STEP := 128


static func begin(images: Dictionary, frame: Vector4, descriptor: Dictionary) -> Dictionary:
	var job := {"done": false, "error": "", "stage": "validate", "images": images.duplicate(false),
		"frame": frame, "descriptor": descriptor.duplicate(true), "recipe": Recipe.new(),
		"data": {}, "image_index": 0, "hash_offset": 0, "hasher": null,
		"pixel_ordinal": 0, "channels": PackedFloat32Array(), "steps": [], "total_us": 0,
		"binding_existing": false}
	return job


static func begin_binding(recipe: Resource, images: Dictionary, descriptor: Dictionary) -> Dictionary:
	if recipe == null or recipe.get_script() != Recipe:
		var rejected := begin(images, Vector4.ZERO, descriptor)
		reject(rejected, "unknown_prepared_recipe")
		return rejected
	var job := begin(images, recipe.frame_uv, descriptor)
	if not recipe.valid() or recipe.descriptor != descriptor:
		reject(job, "prepared_recipe_descriptor_mismatch")
		return job
	job.recipe = recipe
	job.binding_existing = true
	return job


static func reject(job: Dictionary, reason: String) -> void:
	job.error = reason
	job.done = true
	job.data.clear()
	job.hasher = null


static func step(job: Dictionary) -> Dictionary:
	if job.done:
		return {"done": true, "error": job.error}
	var began := Time.get_ticks_usec()
	var stage: String = job.stage
	_step(job)
	var elapsed := Time.get_ticks_usec() - began
	job.total_us += elapsed
	job.steps.append({"stage": stage, "us": elapsed})
	return {"done": job.done, "error": job.error, "stage": stage, "us": elapsed}


static func _step(job: Dictionary) -> void:
	var recipe: Resource = job.recipe
	if job.stage == "validate":
		if job.descriptor.get("source_path", "").is_empty() \
				or job.descriptor.get("normal_profile", "").is_empty() \
				or not job.descriptor.get("paths", {}) is Dictionary:
			reject(job, "missing_actual_source_descriptor")
			return
		for field: String in FIELDS:
			if not job.images.get(field) is Image or not job.descriptor.paths.has(field):
				reject(job, "missing_actual_image_" + field)
				return
			var image: Image = job.images[field]
			var expected := Image.FORMAT_L8 if field in ["support", "normal_valid"] else Image.FORMAT_RGBA8
			if image.is_empty() or image.is_compressed() or image.get_format() != expected:
				reject(job, "unsupported_actual_image_format_" + field)
				return
		var colour: Image = job.images.colour
		var offset := Vector2i(roundi(job.frame.x * colour.get_width()), roundi(job.frame.y * colour.get_height()))
		var size := Vector2i(roundi(job.frame.z * colour.get_width()), roundi(job.frame.w * colour.get_height()))
		var region := Rect2i(offset, size)
		for field: String in FIELDS:
			var image: Image = job.images[field]
			if not region.has_area() or not Rect2i(Vector2i.ZERO, image.get_size()).encloses(region):
				reject(job, "unsupported_actual_frame_region")
				return
		if job.binding_existing:
			if recipe.region != region:
				reject(job, "prepared_recipe_region_mismatch")
				return
		else:
			recipe.descriptor = job.descriptor.duplicate(true)
			recipe.frame_uv = job.frame
			recipe.region = region
		for value: int in 256:
			job.channels.append(float(value) / 255.0)
		job.stage = "image_get_data"
		return
	if job.stage == "image_get_data":
		var field: String = FIELDS[job.image_index]
		var image: Image = job.images[field]
		job.data[field] = image.get_data()
		job.hasher = HashingContext.new()
		if job.hasher.start(HashingContext.HASH_SHA256) != OK:
			reject(job, "image_hash_start_failed")
			return
		job.hash_offset = 0
		job.stage = "image_hash_chunk"
		return
	if job.stage == "image_hash_chunk":
		var field: String = FIELDS[job.image_index]
		var bytes: PackedByteArray = job.data[field]
		var end: int = mini(job.hash_offset + HASH_BYTES, bytes.size())
		if job.hasher.update(bytes.slice(job.hash_offset, end)) != OK:
			reject(job, "image_hash_update_failed")
			return
		job.hash_offset = end
		if end < bytes.size():
			return
		var image: Image = job.images[field]
		var witness := {"field": field, "path": job.descriptor.paths[field],
			"format": image.get_format(), "width": image.get_width(), "height": image.get_height(),
			"mipmaps": image.has_mipmaps(), "bytes": bytes.size(), "sha256": job.hasher.finish().hex_encode()}
		if job.binding_existing:
			if recipe.image_witnesses[job.image_index] != witness:
				reject(job, "prepared_recipe_image_content_mismatch_" + field)
				return
		else:
			recipe.image_witnesses.append(witness)
		job.hasher = null
		job.image_index += 1
		if job.image_index == FIELDS.size():
			job.stage = "publish" if job.binding_existing else "admitted_pixels"
		else:
			job.stage = "image_get_data"
		return
	if job.stage == "admitted_pixels":
		_pixels(job)
		return
	if job.stage == "publish":
		if not recipe.valid():
			reject(job, "invalid_prepared_source_arrays")
			return
		recipe.pixels.make_read_only()
		recipe.descriptor.make_read_only()
		for witness: Dictionary in recipe.image_witnesses:
			witness.make_read_only()
		recipe.image_witnesses.make_read_only()
		job.data.clear()
		job.done = true


static func _pixels(job: Dictionary) -> void:
	var recipe: Resource = job.recipe
	var size: Vector2i = recipe.region.size
	var offset: Vector2i = recipe.region.position
	var values: PackedFloat32Array = job.channels
	var colour: PackedByteArray = job.data.colour
	var depth: PackedByteArray = job.data.depth
	var normal: PackedByteArray = job.data.normal
	var support: PackedByteArray = job.data.support
	var valid: PackedByteArray = job.data.normal_valid
	var colour_width: int = job.images.colour.get_width()
	var depth_width: int = job.images.depth.get_width()
	var normal_width: int = job.images.normal.get_width()
	var support_width: int = job.images.support.get_width()
	var valid_width: int = job.images.normal_valid.get_width()
	var end := mini(job.pixel_ordinal + PIXELS_PER_STEP, size.x * size.y)
	for ordinal: int in range(job.pixel_ordinal, end):
		var pixel := Vector2i(ordinal % size.x, ordinal / size.x)
		var sheet := pixel + offset
		var colour_index := (sheet.y * colour_width + sheet.x) * 4
		if values[colour[colour_index + 3]] < .99:
			continue
		var depth_index := (sheet.y * depth_width + sheet.x) * 4
		var normal_index := (sheet.y * normal_width + sheet.x) * 4
		if values[depth[depth_index + 3]] < .5 or values[normal[normal_index + 3]] < .5 \
				or values[support[sheet.y * support_width + sheet.x]] < .5 \
				or values[valid[sheet.y * valid_width + sheet.x]] < .5:
			continue
		var centre := Vector2(pixel.x + .5, pixel.y + .5)
		var direction := Vector3(values[normal[normal_index]],
			values[normal[normal_index + 1]], values[normal[normal_index + 2]]) * 2.0 - Vector3.ONE
		recipe.pixels.append(pixel)
		recipe.centres.append(centre)
		recipe.uvs.append(centre / Vector2(size))
		recipe.depth_red.append(values[depth[depth_index]])
		recipe.raw_normals.append(direction.normalized())
	job.pixel_ordinal = end
	if end == size.x * size.y:
		job.stage = "publish"


static func identity_key(images: Dictionary, frame: Vector4, descriptor: Dictionary) -> Array:
	return [descriptor.source_path, descriptor.normal_profile,
		images.colour.get_instance_id(), images.depth.get_instance_id(),
		images.support.get_instance_id(), images.normal_valid.get_instance_id(),
		images.normal.get_instance_id(), frame]


static func publication(jobs: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for job: Dictionary in jobs:
		if not job.done or not job.error.is_empty() or not job.recipe.valid():
			return {"ready": false, "reason": "source_recipe_not_prepared", "recipes": {}}
		var key := identity_key(job.images, job.frame, job.descriptor)
		# Retain the actual Images, not only recyclable object IDs. Immutable
		# inputs are a publication precondition; no runtime content scan occurs.
		var record := {"recipe": job.recipe, "images": job.images.duplicate(false)}
		record.images.make_read_only()
		record.make_read_only()
		result[key] = record
	result.make_read_only()
	return {"ready": true, "reason": "", "recipes": result}
