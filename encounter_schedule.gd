extends RefCounted

const FINAL_ENCOUNTER_TIME := 900.0
const CYCLE_SECONDS := 60.0


static func ordinary_spawns_enabled(seconds: float) -> bool:
	return seconds < FINAL_ENCOUNTER_TIME


static func period(seconds: float) -> String:
	if not ordinary_spawns_enabled(seconds):
		return "Final encounter"
	var cycle := fposmod(seconds, CYCLE_SECONDS)
	if cycle < 20.0:
		return "Gathering"
	if cycle < 40.0:
		return "Pressure"
	return "Recovery"


static func pursuer_rate_multiplier(seconds: float) -> float:
	match period(seconds):
		"Gathering": return 0.65
		"Pressure": return 1.0
		"Recovery": return 0.25
	return 0.0


static func chargers_enabled(seconds: float) -> bool:
	return period(seconds) == "Pressure"
