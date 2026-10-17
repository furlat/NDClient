extends RefCounted
## Radial light cookies, generated as images off the main thread with the same
## float32 arithmetic as Godot 4.7.2 GradientTexture2D._update (radial fill from
## the centre to the right edge, no repeat, RGBA8, 256²). The texture carries
## its image (meta cookie_image), so CPU consumers never read the GPU copy back:
## a readback waits for the GPU and stalled a whole frame.
const SIZE := 256

## Starts generating; texture() returns the finished texture once it is ready.
static func start(gradient: Gradient) -> Dictionary:
    gradient.sample(0.0) # Sorts the points on this thread, before a worker reads them.
    var cookie := {"gradient": gradient, "image": null, "texture": null, "task": -1}
    cookie.task = WorkerThreadPool.add_task(_generate.bind(cookie), false, "Generate light cookie")
    return cookie

static func texture(cookie: Dictionary) -> Texture2D:
    if cookie.texture == null and cookie.task >= 0 and WorkerThreadPool.is_task_completed(cookie.task):
        WorkerThreadPool.wait_for_task_completion(cookie.task)
        cookie.task = -1
        var made := ImageTexture.create_from_image(cookie.image)
        made.set_meta(&"cookie_image", cookie.image)
        cookie.texture = made
    return cookie.texture

static func _generate(cookie: Dictionary) -> void:
    var gradient: Gradient = cookie.gradient
    var data := PackedByteArray()
    data.resize(SIZE * SIZE * 4)
    var from := Vector2(0.5, 0.5)
    var i := 0
    for y in SIZE:
        for x in SIZE:
            # Vector2 arithmetic is float32 like the engine's. The fill length is
            # exactly 0.5, so the engine's float division equals length * 2.
            var pos := Vector2(x, y) / float(SIZE - 1)
            var colour := gradient.sample(clampf((pos - from).length() * 2.0, 0.0, 1.0))
            data[i] = colour.r8; data[i + 1] = colour.g8; data[i + 2] = colour.b8; data[i + 3] = colour.a8
            i += 4
    cookie.image = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, data)
