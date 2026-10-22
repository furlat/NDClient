extends "res://assets/vfx/extensions/spike-readiness-20261022/sources/b6b5751949b0f73dc6f3/filtered_readiness.gd"
const MaterialCanonicalReadiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const MaterialBank = preload("res://assets/vfx/extensions/spike-readiness-20261022/sources/4c8fa755d821f8a9a10f/material_bank.gd")


static func step(job: Dictionary) -> Dictionary:
	if not job.complete and job.error.is_empty():
		var entry: Dictionary = job.pending[job.at]
		var value: Resource = resources.get(entry.path)
		if value != null and value.get_script() == MaterialBank:
			return MaterialCanonicalReadiness.step(job)
	return super.step(job)


static func drain(job: Dictionary) -> Dictionary:
	if job.at < job.pending.size():
		var entry: Dictionary = job.pending[job.at]
		var value: Resource = resources.get(entry.path)
		if value != null and value.get_script() == MaterialBank:
			return value.drain_immutable_interface_step()
	return super.drain(job)
