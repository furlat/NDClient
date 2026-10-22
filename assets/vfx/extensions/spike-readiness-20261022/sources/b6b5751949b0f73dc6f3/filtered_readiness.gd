extends "res://assets/vfx/extensions/spike-readiness-20261022/sources/f58730136d05a768b5d8/readiness.gd"
## Admit this exact new Resource class; keep every existing request/cache API.
const Canonical = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const FilteredBank = preload("res://assets/vfx/extensions/spike-readiness-20261022/sources/355a1b1e609d6615199c/filtered_bank.gd")


static func step(job: Dictionary) -> Dictionary:
	if not job.complete and job.error.is_empty():
		var entry: Dictionary = job.pending[job.at]
		var value: Resource = resources.get(entry.path)
		if value != null and value.get_script() == FilteredBank:
			return Canonical.step(job)
	return super.step(job)


static func drain(job: Dictionary) -> Dictionary:
	if job.at < job.pending.size():
		var entry: Dictionary = job.pending[job.at]
		var value: Resource = resources.get(entry.path)
		if value != null and value.get_script() == FilteredBank:
			return value.drain_immutable_interface_step()
	return super.drain(job)
