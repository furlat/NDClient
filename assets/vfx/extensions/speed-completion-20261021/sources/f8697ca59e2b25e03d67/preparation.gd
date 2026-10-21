extends RefCounted
## Opt-in preparation-session reuse under the original immutable-Image contract.
## Original validation, byte access, region admission and publication stay live.
const Original = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/75c165fc1e64ba310420/preparation.gd")
var _limit: int
var _token := RefCounted.new()
var _images: Dictionary = {}
var _order: Array[Image] = []
var original_hash_chunks := 0
var original_hash_bytes_attempted := 0
var completed_image_hashes := 0
var reused_image_witnesses := 0
var reused_hash_bytes := 0
var metadata_invalidations := 0
var evictions := 0
var image_data_calls := 0


func _init(retained_image_limit: int) -> void:
	_limit = maxi(retained_image_limit, 0)


func begin(images: Dictionary, frame: Vector4, descriptor: Dictionary) -> Dictionary:
	var job := Original.begin(images, frame, descriptor)
	job.image_witness_owner = _token
	return job


func begin_binding(recipe: Resource, images: Dictionary, descriptor: Dictionary) -> Dictionary:
	var job := Original.begin_binding(recipe, images, descriptor)
	job.image_witness_owner = _token
	return job


func clear() -> void:
	_images.clear()
	_order.clear()


func counters() -> Dictionary:
	return {"retained_images": _images.size(), "retained_image_limit": _limit,
		"original_hash_chunks": original_hash_chunks,
		"original_hash_bytes_attempted": original_hash_bytes_attempted,
		"completed_image_hashes": completed_image_hashes,
		"reused_image_witnesses": reused_image_witnesses,
		"reused_hash_bytes": reused_hash_bytes, "metadata_invalidations": metadata_invalidations,
		"evictions": evictions, "image_data_calls": image_data_calls,
		"extra_retained_image_byte_arrays": 0}


func _signature(image: Image, bytes: int) -> Array:
	return [image.get_format(), image.get_width(), image.get_height(), image.has_mipmaps(), bytes]


func _lookup(image: Image, bytes: int) -> Dictionary:
	if not _images.has(image):
		return {}
	var retained: Dictionary = _images[image]
	if retained.signature != _signature(image, bytes):
		_images.erase(image)
		_order.erase(image)
		metadata_invalidations += 1
		return {}
	_order.erase(image)
	_order.append(image)
	return retained


func _retain(image: Image, witness: Dictionary) -> void:
	completed_image_hashes += 1
	if _limit == 0:
		return
	_images[image] = {"signature": [witness.format, witness.width, witness.height,
		witness.mipmaps, witness.bytes], "sha256": witness.sha256}
	_order.erase(image)
	_order.append(image)
	if _order.size() > _limit:
		_images.erase(_order.pop_front())
		evictions += 1


func _reuse(job: Dictionary, retained: Dictionary) -> void:
	var field: String = Original.FIELDS[job.image_index]
	var signature: Array = retained.signature
	var witness := {"field": field, "path": job.descriptor.paths[field],
		"format": signature[0], "width": signature[1], "height": signature[2],
		"mipmaps": signature[3], "bytes": signature[4], "sha256": retained.sha256}
	if job.binding_existing:
		if job.recipe.image_witnesses[job.image_index] != witness:
			Original.reject(job, "prepared_recipe_image_content_mismatch_" + field)
			return
	else:
		job.recipe.image_witnesses.append(witness)
	reused_image_witnesses += 1
	reused_hash_bytes += int(witness.bytes)
	job.hasher = null
	job.image_index += 1
	if job.image_index == Original.FIELDS.size():
		job.stage = "publish" if job.binding_existing else "admitted_pixels"
	else:
		job.stage = "image_get_data"


func step(job: Dictionary) -> Dictionary:
	if job.done or not is_same(job.get("image_witness_owner"), _token):
		return Original.step(job)
	var began := Time.get_ticks_usec()
	var stage: String = job.stage
	var image_index: int = job.image_index
	var image: Image
	var byte_count := 0
	if stage == "image_hash_chunk":
		var field: String = Original.FIELDS[image_index]
		image = job.images[field]
		byte_count = job.data[field].size()
		if int(job.hash_offset) == 0:
			var retained := _lookup(image, byte_count)
			if not retained.is_empty():
				_reuse(job, retained)
				var elapsed := Time.get_ticks_usec() - began
				job.total_us += elapsed
				job.steps.append({"stage": "image_witness_reuse", "us": elapsed})
				return {"done": job.done, "error": job.error, "stage": "image_witness_reuse", "us": elapsed}
		original_hash_chunks += 1
		original_hash_bytes_attempted += mini(Original.HASH_BYTES, byte_count - int(job.hash_offset))
	elif stage == "image_get_data":
		image_data_calls += 1
	var progress := Original.step(job)
	if stage == "image_hash_chunk" and job.error.is_empty() and int(job.image_index) == image_index + 1:
		_retain(image, job.recipe.image_witnesses[image_index])
	# Include all cache lookup/retention/counter work in this actual step's cost.
	var complete_us := Time.get_ticks_usec() - began
	job.total_us += complete_us - int(progress.us)
	job.steps.back().us = complete_us
	progress.us = complete_us
	return progress
