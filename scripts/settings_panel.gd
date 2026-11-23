class_name SettingsPanel
extends RefCounted
## 설정 창 (타이틀·일시정지에서 연다). 닫으면 on_close 호출.

const ITEMS := [
	["sfx", "효과음"],
	["music", "음악"],
	["vibration", "진동"],
	["dev", "개발자 정보 (디버그 패널)"],
]

static func open(parent: Node, on_close: Callable = Callable()) -> Control:
	var o := UI.overlay(parent)
	var dim: Control = o[0]
	var vb: VBoxContainer = o[1]
	vb.add_child(UI.label("설정", 56, UI.GOLD))
	for it in ITEMS:
		var c := CheckButton.new()
		var title: String = it[1]
		c.button_pressed = GameState.setting(it[0])
		c.text = "%s   %s" % [title, "켜짐" if c.button_pressed else "꺼짐"]
		c.add_theme_font_size_override("font_size", 40)
		c.custom_minimum_size = Vector2(0, 100)
		var key: String = it[0]
		c.toggled.connect(func(on):
			GameState.set_setting(key, on)
			c.text = "%s   %s" % [title, "켜짐" if on else "꺼짐"])
		vb.add_child(c)
	var reset := UI.button("저장 초기화", 90, 32)
	reset.add_theme_color_override("font_color", UI.BAD)
	var armed := [false]
	reset.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			reset.text = "한 번 더 누르면 모든 진행이 지워집니다"
			return
		GameState.reset_save()
		reset.text = "초기화했습니다"
		reset.disabled = true)
	vb.add_child(reset)
	var credits := UI.button("크레딧", 90, 32)
	credits.pressed.connect(func(): open_credits(parent))
	vb.add_child(credits)
	var close := UI.button("닫기")
	close.pressed.connect(func():
		dim.queue_free()
		if on_close.is_valid():
			on_close.call())
	vb.add_child(close)
	return dim

const CREDITS := """[ 룬 마법 디펜스 · 데모 ]

캐릭터·몬스터 그림  GegX
마법 이펙트  Mira Forge
음악·효과음  pixel-boy & AAA (Ninja Adventure)
속성 타격음  lentikula
글꼴  Galmuri (quiple, SIL OFL 1.1)
엔진  Godot Engine"""

static func open_credits(parent: Node) -> void:
	UI.notice(parent, "크레딧", CREDITS)

