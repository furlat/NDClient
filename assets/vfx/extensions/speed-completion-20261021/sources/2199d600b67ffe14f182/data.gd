extends Resource
## Exact portable SPIR-V authority plus an optional device-specific container.
## No shader/pipeline RID, actor state, owner or rendered-frame readiness.
const SOURCE_PATH := "res://assets/vfx/extensions/speed-completion-20261021/sources/ae89adf22862fe14e0b9/frame.glsl"
const SOURCE_SHA256 := "98a43247fe1abddb268b5a4fa1c075d1098b69685fd80488fa517a5003338f41"
const RUNTIME_SOURCE_SHA256 := "5120af7b6a4788807fb83aaf3b462c940afa16d97250bda211d37825fad9060d"
const TARGET_FIELDS := ["engine_version", "engine_hash", "driver", "vendor", "device", "pipeline_cache_uuid"]
@export var schema := "factory.patch_frame_precompiled.v1"
@export var source_sha256: String
@export var runtime_source_sha256: String
@export var spirv: RDShaderSPIRV
@export var spirv_sha256: String
@export var native_code := PackedByteArray()
@export var native_sha256: String
@export var target: Dictionary = {}


static func hash_bytes(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


static func current_target(device: RenderingDevice) -> Dictionary:
	var version := Engine.get_version_info()
	return {"engine_version": str(version.string), "engine_hash": str(version.hash),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"vendor": device.get_device_vendor_name(), "device": device.get_device_name(),
		"pipeline_cache_uuid": device.get_device_pipeline_cache_uuid()}


func validate_data() -> String:
	if schema != "factory.patch_frame_precompiled.v1":
		return "Unknown prepared frame code schema"
	if source_sha256 != SOURCE_SHA256 or runtime_source_sha256 != RUNTIME_SOURCE_SHA256:
		return "Prepared code is not the exact unchanged typed frame source"
	if spirv == null or not spirv.compile_error_compute.is_empty() or spirv.bytecode_compute.is_empty():
		return "Portable original compute SPIR-V is missing or failed"
	for stage: int in [RenderingDevice.SHADER_STAGE_VERTEX, RenderingDevice.SHADER_STAGE_FRAGMENT,
		RenderingDevice.SHADER_STAGE_TESSELATION_CONTROL, RenderingDevice.SHADER_STAGE_TESSELATION_EVALUATION]:
		if not spirv.get_stage_bytecode(stage).is_empty() or not spirv.get_stage_compile_error(stage).is_empty():
			return "Prepared frame code contains an unrequested shader stage"
	if hash_bytes(spirv.bytecode_compute) != spirv_sha256:
		return "Portable compute SPIR-V checksum mismatch"
	if native_code.is_empty() or hash_bytes(native_code) != native_sha256:
		return "Optional native container is missing or its checksum differs"
	for field: String in TARGET_FIELDS:
		if not target.get(field) is String or str(target[field]).is_empty():
			return "Native container target is incomplete: " + field
	return ""


func validate_target(actual: Dictionary) -> String:
	for field: String in TARGET_FIELDS:
		if actual.get(field) != target.get(field):
			return "Optional native frame container target mismatch: " + field
	return ""
