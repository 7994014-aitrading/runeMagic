extends Control
## 타이틀·메인 메뉴. 첫 실행이면 "시작하기" 하나(1-1로 바로), 이후엔 메뉴 4개.

var _t := 0.0
var _gap: Control

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
	_build()

func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 120
	box.offset_right = -120
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := UI.label("룬 마법 디펜스", 100, UI.GOLD)
	box.add_child(title)
	box.add_child(UI.label("룬을 그려 마법사의 공격에 속성을 입혀라", 34, UI.DIM))
	_gap = Control.new()
	_gap.custom_minimum_size = Vector2(0, 420)
	box.add_child(_gap)

	if GameState.is_first_run():
		var start := UI.button("시작하기", 150, 56)
		start.pressed.connect(func(): GameState.start_stage(1))
		box.add_child(start)
	else:
		var stones := UI.label("마력석 %d  ·  별 %d / %d" % [GameState.data.stones, GameState.total_stars(),
			GameState.chapter.stage_count * 3], 34, UI.STAR_ON)
		box.add_child(stones)
		var play := UI.button("스테이지", 140, 52)
		play.pressed.connect(func(): GameState.go(GameState.SCENE_MAP))
		box.add_child(play)
		var shop := UI.button("영구 강화")
		shop.pressed.connect(func(): GameState.go(GameState.SCENE_SHOP))
		box.add_child(shop)
		var practice := UI.button("룬 연습")
		practice.pressed.connect(func(): GameState.go(GameState.SCENE_PRACTICE))
		box.add_child(practice)
	var settings := UI.button("설정")
	settings.pressed.connect(func(): SettingsPanel.open(self))
	box.add_child(settings)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	# 가운데 빈자리에 룬 셋이 천천히 떠 있는 장식
	if _gap == null:
		return
	var cy := _gap.global_position.y - global_position.y + _gap.size.y / 2.0
	var order := [Element.FIRE, Element.ICE, Element.LIGHTNING]
	for i in 3:
		var bob := sin(_t * 1.4 + i * 2.1) * 14.0
		var cx := 270.0 + i * 270.0
		draw_circle(Vector2(cx, cy + bob), 120, Color(1, 1, 1, 0.035))
		UI.draw_rune(self, order[i], Vector2(cx, cy + bob), 150, 9.0, 0.9)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
