class_name PresentationSurface
extends Resource
## Depth and normals that line up with one art source. Each packet carries its
## own encoding and depth range; two deliveries never share a hard-coded range.

## normal_rgb_depth_byte: characters and creatures (camera-space RGB normals
## with the facing baked in; depth byte 32..224 over depth_range).
## rg16_depth_oct_normal: environment and paired effect banks (16-bit depth in
## RG, octahedral normal in BA, with matrices). metric_depth: depth in metres.
@export_enum("normal_rgb_depth_byte", "rg16_depth_oct_normal", "metric_depth", "none") var encoding: String = "none"
## Paths relative to res://assets/. Profiles: original, gentle, reference, quality.
@export var depth: String = ""
@export var normals: Dictionary[String, String] = {}
## Empty follows the global setting; a declared source profile stays exact.
@export var normal_profile: String = ""
## Masks: support, normal_valid, solid, lighting_valid.
@export var masks: Dictionary[String, String] = {}
@export var depth_range: Vector2 = Vector2.ZERO
@export var depth_byte_range: Vector2i = Vector2i(32, 224)
## Geometry may be sampled at a different resolution than the colour.
@export var sampling_scale: float = 1.0
@export var sampling_offset: Vector2 = Vector2.ZERO
## Reconstruction camera: origin in cell pixels, basis and matrices as delivered.
@export var camera_origin: Vector2 = Vector2.ZERO
## Optional body/part-facing reconstruction origins in cell pixels. Empty keeps
## camera_origin for every view; body keys are the rig's declared facing names.
@export var camera_origins: Dictionary[String, Vector2] = {}
@export var matrices: Dictionary = {}
## -INF means unprovided; zero is a real ground-relative calibration.
@export var optical_ground_pixels: float = -INF
## Fraction of source pixels with a surface, frames that failed, rows that repeat one view.
@export_range(0.0, 1.0) var coverage: float = 1.0
@export var failed_frames: PackedInt32Array = []
@export var repeated_rows: bool = false
## source, inferred or proxy (a coarse stand-in surface).
@export_enum("source", "inferred", "proxy") var qualification: String = "source"
@export var source: String = ""
