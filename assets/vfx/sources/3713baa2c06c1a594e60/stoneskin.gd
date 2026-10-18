extends "res://assets/vfx/sources/c9b08b288e56a08b0458/ward.gd"


static func make_component(input: Dictionary) -> Node3D:
	return construct("res://assets/vfx/sources/3713baa2c06c1a594e60/stoneskin.gd", input)


func advance_lifecycle(_delta: float) -> void:
	if not is_instance_valid(subject):
		return
	tick += 1
	var age = float(tick) / 144.0
	var envelope = 1.0
	if settings.id == "stone_hold":
		# Exact periodic Kepler ellipses: shared semimajor axis and central mu,
		# varied eccentricity/inclination/phase. No reversal or seam crossfade.
		var period = 6.0
		for i in range(stones.size()):
			var angle = float(i) * TAU / 16.0 + 0.12 * sin(float(i) * 1.7)
			var eccentricity = 0.04 + float(i % 4) * 0.045
			var mean_anomaly = angle + age * TAU / period
			var eccentric_anomaly = mean_anomaly
			for iteration in range(6):
				eccentric_anomaly -= (
					(eccentric_anomaly - eccentricity * sin(eccentric_anomaly) - mean_anomaly)
					/ (1.0 - eccentricity * cos(eccentric_anomaly))
				)
			var x = 1.31 * (cos(eccentric_anomaly) - eccentricity)
			var z = 1.31 * sqrt(1.0 - eccentricity * eccentricity) * sin(eccentric_anomaly)
			var tilt = -0.48 + float(i % 5) * 0.23
			stones[i].position = Vector3(x, 1.05 + z * sin(tilt), z * cos(tilt))
			var base = Basis.from_euler(Vector3(angle, angle * 0.7, angle * 1.3))
			var spin = Basis(
				Vector3(0.3, 0.8, 0.2).normalized(), age * TAU / period * float(1 + i % 2)
			)
			var size = stones[i].scale
			stones[i].basis = base * spin
			stones[i].scale = size
	if settings.id == "stone_cast":
		var dt = 1.0 / 144.0
		for i in range(stones.size()):
			var rock = stones[i]
			velocities[i].y -= 6.0 * dt
			rock.position += velocities[i] * dt
			var radial = Vector2(rock.position.x, rock.position.z)
			# Rounded body proxy only for this application audition; no actor deformation.
			var surface = 1.45 if radial.length() < 0.52 else 0.08
			if rock.position.y < surface and velocities[i].y < 0:
				rock.position.y = surface
				velocities[i].y = -velocities[i].y * 0.18
				var outward = radial.normalized()
				velocities[i].x = outward.x * 0.65
				velocities[i].z = outward.y * 0.65
			rock.rotate_object_local(
				Vector3(0.3, 0.8, 0.2).normalized(), dt * (1.0 + float(i) * 0.13)
			)
	if settings.id != "stone_hold":
		envelope = 1.0 - smoothstep(1.2, 1.95, age)
	for mat in mats:
		mat.set_shader_parameter("vfx_clock", age)
		mat.set_shader_parameter("vfx_alpha", envelope)
