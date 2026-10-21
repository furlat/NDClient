extends "res://assets/vfx/extensions/speed-completion-20261021/sources/0a2e4c03a47f2ffa18de/source_readiness.gd"
## Exact direct-display Wind bank, with one observed loader status per step.
const WindCanonical = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const PreparedWindBank = preload("res://assets/vfx/extensions/speed-completion-20261021/sources/9d8c71a4815c6b6f076a/bank.gd")


static func step(job: Dictionary) -> Dictionary:
	if not job.complete and job.error.is_empty():
		var entry: Dictionary = job.pending[job.at]
		var value: Resource = resources.get(entry.path)
		if value != null and value.get_script() == PreparedWindBank:
			return WindCanonical.step(job)
	return super.step(job)


static func drain(job: Dictionary) -> Dictionary:
	if job.at < job.pending.size():
		var entry: Dictionary = job.pending[job.at]
		var value: Resource = resources.get(entry.path)
		if value != null and value.get_script() == PreparedWindBank:
			return value.drain_immutable_interface_step()
	return super.drain(job)
