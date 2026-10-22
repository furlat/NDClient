extends "res://assets/vfx/extensions/cloud-body-speed-20261021/sources/84260a019e9468668dc4/program.gd"
## Same guarded private storage/revision/release; only exact input decoding.


func prepare() -> void:
	if started or closed:
		return
	started = true
	source = VfxPackageIO_08355a94de.text("res://assets/vfx/extensions/speed-completion-20261021/sources/ae89adf22862fe14e0b9/frame.glsl").trim_prefix("#[compute]\n")
	RenderingServer.call_on_render_thread(_prepare_thread)

const VfxPackageIO_08355a94de = preload("res://assets/vfx/extensions/cloud-body-speed-20261021/scoped_resource_io.gd")
