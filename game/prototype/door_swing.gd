extends RefCounted
# Coordinates are in the fixed hinge frame, never the rotating leaf frame.
static func away_angle(point: Vector2) -> float:
	return PI/2.0 if point.y >= 0.0 else -PI/2.0

static func blocked(point: Vector2, width: float, angle: float, radius: float) -> bool:
	for i in range(49):
		var sample := float(i)/48.0*angle
		var direction := Vector2(cos(sample),-sin(sample))
		var nearest := direction*clampf(point.dot(direction),0.0,width)
		if point.distance_to(nearest) < radius: return true
	return false
