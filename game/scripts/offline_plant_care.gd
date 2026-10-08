extends RefCounted

# Away-time care for ONE existing crop batch. This module cannot plant, harvest,
# sell, buy supplies, change the day or award progression. All state is explicit.
const PlantGrowth = preload("res://scripts/plant_growth.gd")
const CARE_INTERVAL: float = 5.0
const WATER_THRESHOLD: float = 38.0
const FERTILIZER_THRESHOLD: float = 15.0
const EPS: float = 0.0000001

static func _growing(slot: Dictionary) -> bool:
	var stage: int = int(slot.get("stage", -1))
	return stage >= 0 and stage < 3 and not bool(slot.get("dead", false)) and float(slot.get("health", 100.0)) > EPS

static func _next_service(value: float) -> float:
	return clampf(value, EPS, CARE_INTERVAL) if is_finite(value) and value > 0.0 else CARE_INTERVAL

static func advance(plants: Array[Dictionary], elapsed_seconds: float, settings: Dictionary, fertilizer_units: int, worker_enabled: bool, next_service_seconds: float = CARE_INTERVAL) -> Dictionary:
	var slots: Array[Dictionary] = plants.duplicate(true)
	var remaining_units: int = maxi(0, fertilizer_units)
	var next_service: float = _next_service(next_service_seconds)
	var waterings: int = 0
	var water_by_slot:Dictionary={}
	var fertilizes: int = 0
	var service_ticks: int = 0
	if elapsed_seconds > 0.0 and is_finite(elapsed_seconds):
		if not worker_enabled:
			# Keep unattended plant outcomes identical to the established integrator.
			for i: int in range(slots.size()):
				slots[i] = PlantGrowth.advance(slots[i], elapsed_seconds, settings.get("per_slot",[])[i] if i<settings.get("per_slot",[]).size() else settings)
		else:
			var remaining: float = elapsed_seconds
			# Only currently planted crops can be serviced. All actual game growth
			# settings are positive, so this ends at maturity/death even after years
			# away, instead of iterating through every second of the absence.
			while remaining > EPS:
				var has_growing: bool = false
				for slot: Dictionary in slots:
					if _growing(slot):
						has_growing = true
						break
				if not has_growing:
					break
				var step: float = minf(remaining, next_service)
				for i: int in range(slots.size()):
					slots[i] = PlantGrowth.advance(slots[i], step, settings.get("per_slot",[])[i] if i<settings.get("per_slot",[]).size() else settings)
				remaining = maxf(0.0, remaining - step)
				next_service = maxf(0.0, next_service - step)
				if next_service > EPS:
					continue
				next_service = CARE_INTERVAL
				service_ticks += 1
				# Growth/death is settled BEFORE a care action. Never revive a plant
				# that died before the worker reached it or spend on a ready plant.
				var target: int = -1
				var lowest_water: float = WATER_THRESHOLD
				for i: int in range(slots.size()):
					if (i>=settings.get("care_slots",[]).size() or settings.care_slots[i]) and _growing(slots[i]) and float(slots[i].get("water", 0.0)) < lowest_water:
						target = i
						lowest_water = float(slots[i].get("water", 0.0))
				if target >= 0:
					slots[target]["water"] = 100.0
					slots[target]["health"] = minf(100.0, float(slots[target].get("health", 100.0)) + 2.0)
					waterings += 1
					water_by_slot[target]=int(water_by_slot.get(target,0))+1
					continue
				if remaining_units <= 0:
					continue
				var lowest_feed: float = FERTILIZER_THRESHOLD
				for i: int in range(slots.size()):
					var slot: Dictionary = slots[i]
					if (i>=settings.get("care_slots",[]).size() or settings.care_slots[i]) and _growing(slot) and int(slot.get("stage", -1)) >= 1 and float(slot.get("fertilizer", 0.0)) < lowest_feed:
						target = i
						lowest_feed = float(slot.get("fertilizer", 0.0))
				if target >= 0:
					slots[target]["fertilizer"] = 100.0
					remaining_units -= 1
					fertilizes += 1
	return {"water_by_slot":water_by_slot,"plants": slots, "fertilizer_units": remaining_units, "waterings": waterings, "fertilizes": fertilizes, "service_in": next_service, "service_ticks": service_ticks}
