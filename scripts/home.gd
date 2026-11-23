extends Control
## 홈: 위 재화 막대, 출석·스타터 팩·월정액 알림, 가운데 마법사(지금 스킨), 다음 스테이지 도전, 아래 탭.

var _t := 0.0
var _frames: Array = []
var _wizard: Node2D  # 마법사 그림 (스킨 재질)
var _starter_label: Label
var _daily_button: Button
var _starter_button: Button

func _ready() -> void:
	theme = UI.theme()
	UI.fill(self)
	GameState.music("menu")
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	add_child(bg)
	UI.fill(bg)
	_frames = Art.wizard_frames("south")
	_wizard = Node2D.new()
	_wizard.material = UI.skin_material(GameState.skin())
	_wizard.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_wizard)
	_wizard.draw.connect(_draw_wizard)
	UI.wallet_bar(self)
	_build_side_buttons()
	_build_center()
	UI.bottom_nav(self, "home")
	_auto_rewards.call_deferred()

## 왼쪽 위: 출석, 오른쪽 위: 스타터 팩 (있을 때)
func _build_side_buttons() -> void:
	_daily_button = UI.button("", 130, 32)
	_daily_button.position = Vector2(24, 160)
	_daily_button.size = Vector2(300, 130)
	_daily_button.pressed.connect(_claim_daily)
	add_child(_daily_button)
	_starter_button = UI.button("", 130, 32)
	_starter_button.position = Vector2(756, 160)
	_starter_button.size = Vector2(300, 130)
	_starter_button.add_theme_stylebox_override("normal", UI.box(Color(0.35, 0.18, 0.12), UI.STAR_ON, 16, 4))
	_starter_button.add_theme_color_override("font_color", UI.STAR_ON)
	_starter_button.pressed.connect(func(): GameState.go(GameState.SCENE_STORE))
	add_child(_starter_button)
	_refresh_side()

func _refresh_side() -> void:
	if GameState.daily_available():
		var r := GameState.daily_reward()
		_daily_button.text = "출석 %d일째 !\n%s" % [r[2], _reward_text(r[0], r[1])]
		_daily_button.add_theme_color_override("font_color", UI.STAR_ON)
	else:
		_daily_button.text = "출석 완료\n내일 또 오세요"
		_daily_button.add_theme_color_override("font_color", UI.DIM)
	_starter_button.visible = GameState.starter_active()
	if _starter_button.visible:
		_starter_button.text = "스타터 팩\n" + UI.hms(GameState.starter_seconds_left())

func _reward_text(st: int, gm: int) -> String:
	var parts := []
	if st > 0:
		parts.append("마력석 %d" % st)
	if gm > 0:
		parts.append("수정 %d" % gm)
	return " + ".join(parts)

func _claim_daily() -> void:
	var r := GameState.claim_daily()
	if r.is_empty():
		return
	GameState.sfx("upgrade")
	UI.notice(self, "출석 %d일째" % r[2], _reward_text(r[0], r[1]) + " 받았습니다")
	_refresh_side()

## 들어올 때: 월정액 오늘 몫
func _auto_rewards() -> void:
	var g := GameState.claim_pass()
	if g > 0:
		UI.notice(self, "마법사의 서약", "오늘의 수정 %d 받았습니다\n남은 날: %d일" % [g, int(GameState.data.pass.days_left)])

func _build_center() -> void:
	var s := GameState.max_open_stage()
	var ch := GameState.chapter
	var all_clear := GameState.is_cleared(ch.stage_count)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 90
	box.offset_right = -90
	box.offset_top = -560
	box.offset_bottom = -200
	add_child(box)
	box.add_child(UI.label(GameState.skin().title, 34, UI.DIM))
	box.add_child(UI.label("별 %d / %d" % [GameState.total_stars(), ch.stage_count * 3], 32, UI.STAR_ON))
	var go := UI.button("스테이지 %s 도전" % ch.stage_name(s) if not all_clear else "챕터 1 완료! 별 모으기", 150, 52)
	go.add_theme_stylebox_override("normal", UI.box(Color(0.32, 0.25, 0.12), UI.STAR_ON, 18, 4))
	go.pressed.connect(func(): GameState.start_stage(s) if not all_clear else GameState.go(GameState.SCENE_MAP))
	box.add_child(go)
	var map := UI.button("스테이지 맵", 100, 38)
	map.pressed.connect(func(): GameState.go(GameState.SCENE_MAP))
	box.add_child(map)

func _process(delta: float) -> void:
	_t += delta
	if _starter_button != null and _starter_button.visible and int(_t * 10) % 10 == 0:
		_refresh_side()
	queue_redraw()
	_wizard.queue_redraw()

func _wizard_center() -> Vector2:
	return Vector2(540, size.y * 0.42)

func _draw() -> void:
	# 가운데 마법사 + 발밑 룬 원
	var center := _wizard_center()
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	draw_set_transform(center + Vector2(0, 190), 0.0, Vector2(1.0, 0.32))
	draw_arc(Vector2.ZERO, 260, 0, TAU, 64, Color(UI.GOLD, 0.25 + 0.2 * pulse), 6, true)
	draw_arc(Vector2.ZERO, 200, 0, TAU, 64, Color(UI.GOLD, 0.15), 3, true)
	draw_circle(Vector2.ZERO, 180, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _frames.is_empty():
		UI.draw_rune(self, Element.FIRE, center, 260, 12.0)

func _draw_wizard() -> void:
	if _frames.is_empty():
		return
	var center := _wizard_center()
	var tex: Texture2D = _frames[int(_t * 10.0) % _frames.size()]
	var sz := Vector2(tex.get_width(), tex.get_height()) * 3.2
	var foot := sz.y * 140.0 / 164.0
	_wizard.draw_texture_rect(tex, Rect2(center + Vector2(-sz.x / 2.0, 190 - foot), sz), false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
