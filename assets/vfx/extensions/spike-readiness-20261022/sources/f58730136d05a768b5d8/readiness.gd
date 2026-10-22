extends "res://assets/vfx/extensions/speed-completion-20261021/sources/0a2e4c03a47f2ffa18de/source_readiness.gd"
## Exact new Spike bank only; retain the canonical resource/request tables.
const CanonicalReadiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const WorkerBank = preload("res://assets/vfx/extensions/spike-readiness-20261022/sources/34191b3521d999d8b475/bank.gd")


static func begin(clip: Dictionary) -> Dictionary:
	return super.begin(clip)


static func step(job: Dictionary) -> Dictionary:
	if not job.complete and job.error.is_empty():
		var entry: Dictionary = job.pending[job.at]
		var value: Resource = resources.get(entry.path)
		if value != null and value.get_script() == WorkerBank:
			return CanonicalReadiness.step(job)
	return super.step(job)


static func drain(job: Dictionary) -> Dictionary:
	if job.at < job.pending.size():
		var entry: Dictionary = job.pending[job.at]
		var value: Resource = resources.get(entry.path)
		if value != null and value.get_script() == WorkerBank:
			return value.drain_immutable_interface_step()
	return super.drain(job)
