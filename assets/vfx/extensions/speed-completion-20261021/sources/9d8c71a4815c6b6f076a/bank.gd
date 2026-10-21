extends "res://assets/vfx/extensions/speed-completion-20261021/sources/4cb2ad2731b641eeb48e/bank.gd"
## The original StandardMaterial remains only the ordered logical Color writer.
## This source never assigns it to a draw or reads its native material RID.


func prepare_immutable_interface_step() -> Dictionary:
	if preparation_stage == "original_feed_rid" and preparation_error.is_empty() and not interface_ready:
		preparation_stage = "debris_properties"
		var unit := {"operation": "unused_native_feed_rid_omitted", "ordinal": preparation_index, "us": 0, "progress": {}}
		preparation_units.append(unit)
		return {"complete": false, "error": "", "operation": unit.operation, "unit": unit}
	return super.prepare_immutable_interface_step()
