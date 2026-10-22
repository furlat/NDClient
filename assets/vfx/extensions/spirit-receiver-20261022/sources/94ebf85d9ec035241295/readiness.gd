extends "res://assets/vfx/extensions/speed-completion-20261021/sources/0a2e4c03a47f2ffa18de/source_readiness.gd"
const Canonical = preload("res://assets/vfx/extensions/production-review-20261020/sources/7dd1897cdd5ee8a903b9/source_readiness.gd")
const MaskBank = preload("res://assets/vfx/extensions/spirit-receiver-20261022/sources/832f814a9a2922d948a8/bank.gd")
const SpiritBank = preload("res://assets/vfx/extensions/spirit-receiver-20261022/sources/0228862d3241f77bc1d4/bank_ready.gd")
const GroundBank = preload("res://assets/vfx/extensions/spirit-receiver-20261022/sources/5105bf8a41463fcc3e67/direct_restore_bank.gd")


static func admitted(value: Resource) -> bool:
	return value.get_script() == MaskBank or value.get_script() == SpiritBank or value.get_script() == GroundBank


static func step(job: Dictionary) -> Dictionary:
	if not job.complete and job.error.is_empty():
		var value: Resource = resources.get(job.pending[job.at].path)
		if value != null and admitted(value):
			return Canonical.step(job)
	return super.step(job)


static func drain(job: Dictionary) -> Dictionary:
	if job.at < job.pending.size():
		var value: Resource = resources.get(job.pending[job.at].path)
		if value != null and admitted(value):
			if value.get_script() == MaskBank:
				return value.drain_immutable_interface_step()
			return {"complete": true, "operation": "original_synchronous_spirit_unit_finished"}
	return super.drain(job)
