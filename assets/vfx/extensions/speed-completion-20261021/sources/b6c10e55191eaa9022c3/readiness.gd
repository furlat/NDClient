extends "res://assets/vfx/extensions/speed-completion-20261021/sources/f689f3bee683f505c27d/source_readiness.gd"
## Selected Patches path only; retain the canonical shared resources/requests.
const CanonicalReadiness = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const WorkerBank = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/52c4080c85cdb2003ba4/bank.gd")


static func begin(clip: Dictionary) -> Dictionary:
	return super.begin(clip)


static func step(job: Dictionary) -> Dictionary:
	if not job.complete and job.error.is_empty():
		var entry: Dictionary = job.pending[job.at]
		var value: Resource = resources.get(entry.path)
		if value != null and value.get_script() == WorkerBank:
			return CanonicalReadiness.step(job)
	# The frozen bridge collects a successful current load before invoking any
	# hook and rejects unknown progressive classes. Never route them unchecked.
	return super.step(job)


static func drain(job: Dictionary) -> Dictionary:
	if job.at < job.pending.size():
		var entry: Dictionary = job.pending[job.at]
		var value: Resource = resources.get(entry.path)
		if value != null and value.get_script() == WorkerBank:
			return value.drain_immutable_interface_step()
	return super.drain(job)
