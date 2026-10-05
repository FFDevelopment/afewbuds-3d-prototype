extends RefCounted

# Fictional game meters only. Integrate at resource/health boundaries rather than
# subtracting an entire absence first: maturity must beat later dehydration.
# No inventory, worker, money, story or clock references belong in this module.
const EPS: float = 0.0000001

static func advance(source: Dictionary, elapsed_seconds: float, settings: Dictionary) -> Dictionary:
	var slot: Dictionary = source.duplicate(true)
	if elapsed_seconds <= 0.0 or not is_finite(elapsed_seconds):
		return slot
	var stage: int = int(slot.get("stage", -1))
	if stage < 0 or bool(slot.get("dead", false)):
		return slot
	# Ready plants have already won the race. Never drain or kill them later.
	if stage >= 3:
		return slot
	var growth: float = clampf(float(slot.get("growth", 0.0)), 0.0, 100.0)
	var water: float = clampf(float(slot.get("water", 0.0)), 0.0, 100.0)
	var health: float = clampf(float(slot.get("health", 100.0)), 0.0, 100.0)
	var fertilizer: float = clampf(float(slot.get("fertilizer", 0.0)), 0.0, 100.0)
	if not is_finite(growth) or not is_finite(water) or not is_finite(health) or not is_finite(fertilizer):
		return slot
	var remaining: float = elapsed_seconds
	var water_decay: float = maxf(0.0, float(settings.get("water_decay", 0.289)))
	var fertilizer_decay: float = maxf(0.0, float(settings.get("fertilizer_decay", 0.10)))
	var health_loss: float = maxf(0.0, float(settings.get("health_loss", 0.55)))
	var health_recovery: float = maxf(0.0, float(settings.get("health_recovery", 0.06)))
	var base_rate: float = 100.0 / maxf(EPS, float(settings.get("growth_seconds", 300.0)))
	base_rate *= maxf(0.0, float(settings.get("light_factor", 1.0)))
	base_rate *= maxf(0.0, float(settings.get("ventilation_factor", 1.0)))
	var water_floor: float = 62.0 if bool(settings.get("auto_water", false)) else 0.0
	# At most a handful of monotonic boundaries exist (50/25/0 water, empty
	# fertilizer, 25/100/0 health, maturity). Returning after weeks is still O(pots).
	for _segment: int in range(32):
		if health <= EPS:
			health = 0.0
			slot["dead"] = true
			break
		if growth >= 100.0 - EPS:
			growth = 100.0
			break
		if remaining <= EPS:
			break
		water = maxf(water, water_floor)
		var duration: float = remaining
		var water_factor: float = 0.0
		if water > 50.0 + EPS:
			water_factor = 1.0
		elif water > 25.0 + EPS:
			water_factor = 0.78
		elif water > EPS:
			water_factor = 0.45
		if water_decay > EPS and water > water_floor + EPS:
			var next_water: float = water_floor
			if water > 50.0 + EPS:
				next_water = maxf(next_water, 50.0)
			elif water > 25.0 + EPS:
				next_water = maxf(next_water, 25.0)
			duration = minf(duration, (water - next_water) / water_decay)
		if fertilizer_decay > EPS and fertilizer > EPS:
			duration = minf(duration, fertilizer / fertilizer_decay)
		var health_rate: float = 0.0
		if water <= EPS:
			health_rate = -health_loss
		elif water > 25.0 + EPS and health < 100.0 - EPS:
			health_rate = health_recovery
		if health_rate > EPS:
			var next_health: float = 25.0 if health < 25.0 - EPS else 100.0
			duration = minf(duration, (next_health - health) / health_rate)
		elif health_rate < -EPS:
			var next_health: float = 25.0 if health > 25.0 + EPS else 0.0
			duration = minf(duration, (health - next_health) / -health_rate)
		var boost: float = 1.0 + (float(settings.get("fertilizer_bonus", 0.35)) if fertilizer > EPS else 0.0)
		var rate: float = base_rate * water_factor * boost
		var rate_start: float = rate * clampf(health / 100.0, 0.25, 1.0)
		var rate_slope: float = 0.0
		if (health_rate > EPS and health >= 25.0 - EPS) or (health_rate < -EPS and health > 25.0 + EPS):
			rate_slope = rate * health_rate / 100.0
		var gain: float = maxf(0.0, rate_start * duration + 0.5 * rate_slope * duration * duration)
		var finished: bool = growth + gain >= 100.0 - EPS
		if finished and rate_start > EPS:
			var needed: float = maxf(0.0, 100.0 - growth)
			if absf(rate_slope) <= EPS:
				duration = minf(duration, needed / rate_start)
			else:
				# Stable quadratic root avoids cancellation for short final intervals.
				var root: float = sqrt(maxf(0.0, rate_start * rate_start + 2.0 * rate_slope * needed))
				duration = minf(duration, 2.0 * needed / maxf(EPS, rate_start + root))
			gain = needed
		water = maxf(water_floor, water - water_decay * duration)
		fertilizer = maxf(0.0, fertilizer - fertilizer_decay * duration)
		health = clampf(health + health_rate * duration, 0.0, 100.0)
		growth = minf(100.0, growth + gain)
		remaining = maxf(0.0, remaining - duration)
		if finished:
			growth = 100.0
			break
	slot["growth"] = growth
	slot["water"] = water
	slot["health"] = health
	slot["fertilizer"] = fertilizer
	slot["stage"] = 3 if growth >= 100.0 else (2 if growth >= 62.0 else (1 if growth >= 25.0 else 0))
	if health <= EPS:
		slot["health"] = 0.0
		slot["dead"] = true
	return slot
