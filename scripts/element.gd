class_name Element
extends RefCounted
## 속성 상수, 이름, 색.

enum { NONE, FIRE, ICE, LIGHTNING }

const NAMES := {NONE: "무속성", FIRE: "불", ICE: "얼음", LIGHTNING: "번개"}
const COLORS := {
	NONE: Color(0.85, 0.85, 0.85),
	FIRE: Color(1.0, 0.45, 0.15),
	ICE: Color(0.45, 0.8, 1.0),
	LIGHTNING: Color(1.0, 0.9, 0.25),
}

static func name_of(e: int) -> String:
	return NAMES.get(e, "?")

static func color_of(e: int) -> Color:
	return COLORS.get(e, Color.WHITE)
