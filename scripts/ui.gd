class_name UI
extends RefCounted
## 화면 공통: 테마, 색, 버튼·글자·패널 만들기. 모든 메뉴 화면이 코드로 UI를 짠다.

const BG := Color(0.1, 0.1, 0.14)
const GOLD := Color(0.85, 0.75, 0.5)
const TEXT := Color(0.93, 0.93, 0.96)
const DIM := Color(0.6, 0.6, 0.7)
const GOOD := Color(0.6, 1.0, 0.6)
const BAD := Color(1.0, 0.5, 0.5)
const STAR_ON := Color(1.0, 0.85, 0.3)
const STAR_OFF := Color(0.35, 0.35, 0.42)

static var _theme: Theme
static var _font: Font
static var _font_bold: Font

## 한글 픽셀 폰트 Galmuri11 (OFL, assets/fonts). 없으면 엔진 기본.
static func font(bold := false) -> Font:
	if _font == null:
		_font = load("res://assets/fonts/Galmuri11.ttf") if ResourceLoader.exists("res://assets/fonts/Galmuri11.ttf") else ThemeDB.fallback_font
		_font_bold = load("res://assets/fonts/Galmuri11-Bold.ttf") if ResourceLoader.exists("res://assets/fonts/Galmuri11-Bold.ttf") else _font
	return _font_bold if bold else _font

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 36
	t.set_stylebox("normal", "Button", box(Color(0.18, 0.18, 0.25), GOLD.darkened(0.45)))
	# 터치 화면: 손을 뗀 뒤 남는 hover 모양이 "선택됨"처럼 보이지 않게 hover = normal
	t.set_stylebox("hover", "Button", box(Color(0.18, 0.18, 0.25), GOLD.darkened(0.45)))
	t.set_stylebox("pressed", "Button", box(Color(0.3, 0.27, 0.2), GOLD))
	t.set_stylebox("hover_pressed", "Button", box(Color(0.3, 0.27, 0.2), GOLD))
	t.set_stylebox("disabled", "Button", box(Color(0.13, 0.13, 0.17), Color(0.28, 0.28, 0.33)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", DIM.darkened(0.2))
	t.set_color("font_color", "Label", TEXT)
	var panel := box(Color(0.13, 0.13, 0.18, 0.98), GOLD, 20, 4)
	panel.set_content_margin_all(40)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(st, "CheckButton", box(Color(0.16, 0.16, 0.22), GOLD.darkened(0.5)) if st != "focus" else StyleBoxEmpty.new())
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", TEXT)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_constant("separation", "VBoxContainer", 20)
	t.set_constant("separation", "HBoxContainer", 20)
	_theme = t
	return t

static func box(bg: Color, border: Color, radius := 16, width := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(16)
	return s

static func button(text: String, height := 110, font_size := 40) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(func(): GameState.sfx("click"))
	return b

static func label(text: String, font_size := 36, color := TEXT, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if font_size >= 56:
		l.add_theme_font_override("font", font(true))
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func stars_text(n: int, total := 3) -> String:
	return "★".repeat(n) + "☆".repeat(maxi(total - n, 0))

static func fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## 화면 전체를 덮는 어두운 막 + 가운데 패널. 반환: [막, 패널 안 VBox]
static func overlay(parent: Node, width := 880.0) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.theme = theme()
	parent.add_child(dim)
	fill(dim)
	var center := CenterContainer.new()
	dim.add_child(center)
	fill(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	panel.add_child(vb)
	return [dim, vb]

## 위쪽 막대: [뒤로 버튼, 제목, 오른쪽 글자]
static func top_bar(parent: Control, title: String, right_text := "") -> Array:
	var bar := HBoxContainer.new()
	bar.position = Vector2(30, 30)
	bar.size = Vector2(1020, 110)
	parent.add_child(bar)
	var back := button("‹ 뒤로", 100, 36)
	back.custom_minimum_size.x = 200
	bar.add_child(back)
	var t := label(title, 48, GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(t)
	var r := label(right_text, 32, STAR_ON, HORIZONTAL_ALIGNMENT_RIGHT)
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.custom_minimum_size.x = 240
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(r)
	return [back, t, r]

## 룬 모양을 그린다 (메뉴 장식·안내용)
static func draw_rune(ci: CanvasItem, element: int, center: Vector2, size: float, width := 7.0, alpha := 1.0) -> void:
	var shape: PackedVector2Array = RuneRecognizer.shapes()[element]
	var origin := center - Vector2(size, size) / 2.0
	var pts := PackedVector2Array()
	for p in shape:
		pts.append(origin + p * size)
	var c := Element.color_of(element)
	c.a = alpha
	ci.draw_polyline(pts, c, width, true)
	ci.draw_circle(pts[0], width * 1.4, Color(1, 1, 1, alpha))

# ---- 공통 막대: 위(재화) · 아래(탭) ----

const NAV := [
	["store", "상점", "res://scenes/store.tscn"],
	["perm", "강화", "res://scenes/perm_shop.tscn"],
	["home", "홈", "res://scenes/home.tscn"],
	["skins", "스킨", "res://scenes/skins.tscn"],
	["practice", "연습", "res://scenes/rune_test.tscn"],
]

## 화면 맨 아래 탭 막대. current = 지금 탭 id
static func bottom_nav(parent: Control, current: String) -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 16
	bar.offset_right = -16
	bar.offset_top = -170
	bar.offset_bottom = -20
	parent.add_child(bar)
	for it in NAV:
		var b := button(it[1], 150, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if it[0] == current:
			b.add_theme_stylebox_override("normal", box(Color(0.3, 0.26, 0.16), GOLD, 16, 4))
			b.add_theme_color_override("font_color", GOLD)
		else:
			var path: String = it[2]
			b.pressed.connect(func(): GameState.go(path))
		bar.add_child(b)
	return bar

## 화면 맨 위 재화 막대: 마력석 · 수정(+ → 상점). 반환: 막대
static func wallet_bar(parent: Control, show_settings := true) -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	bar.position = Vector2(24, 30)
	bar.size = Vector2(1032, 100)
	parent.add_child(bar)
	var stones := _pill("마력석", STAR_ON)
	var gems := _pill("수정", Color(0.6, 0.85, 1.0))
	bar.add_child(stones)
	bar.add_child(gems)
	var plus := button("+", 90, 44)
	plus.custom_minimum_size.x = 90
	plus.pressed.connect(func(): GameState.go("res://scenes/store.tscn"))
	bar.add_child(plus)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	if show_settings:
		var gear := button("설정", 90, 32)
		gear.custom_minimum_size.x = 130
		gear.pressed.connect(func(): SettingsPanel.open(parent))
		bar.add_child(gear)
	var refresh := func():
		stones.get_child(0).text = "마력석 %d" % GameState.stones()
		gems.get_child(0).text = "수정 %d" % GameState.gems()
	refresh.call()
	GameState.wallet_changed.connect(refresh)
	bar.tree_exiting.connect(func(): GameState.wallet_changed.disconnect(refresh))
	return bar

static func _pill(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(0.08, 0.08, 0.12, 0.9), color.darkened(0.3), 40, 3)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(270, 90)
	var l := label(text, 32, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

## 테스트 결제 확인 창. 확인하면 on_ok 호출.
static func confirm_purchase(parent: Node, title: String, price: String, on_ok: Callable) -> void:
	var o := overlay(parent, 860.0)
	var dim: Control = o[0]
	var vb: VBoxContainer = o[1]
	vb.add_child(label(title, 48, GOLD))
	vb.add_child(label(price, 44, TEXT))
	vb.add_child(label("테스트 결제입니다. 실제로 돈이 나가지 않습니다.", 30, BAD))
	var ok := button("구매", 120, 44)
	ok.pressed.connect(func():
		dim.queue_free()
		on_ok.call())
	vb.add_child(ok)
	var cancel := button("취소", 100, 36)
	cancel.pressed.connect(func(): dim.queue_free())
	vb.add_child(cancel)

## 짧은 알림 창 (확인 하나)
static func notice(parent: Node, title: String, body: String) -> void:
	var o := overlay(parent, 860.0)
	var dim: Control = o[0]
	var vb: VBoxContainer = o[1]
	vb.add_child(label(title, 52, GOLD))
	if body != "":
		vb.add_child(label(body, 36))
	var ok := button("확인", 110, 40)
	ok.pressed.connect(func(): dim.queue_free())
	vb.add_child(ok)

## 원 스타일 시간 표시 (예: 71:59:30)
static func hms(sec: int) -> String:
	return "%d:%02d:%02d" % [sec / 3600, (sec / 60) % 60, sec % 60]

const HUE_SHADER := preload("res://scripts/hue_shift.gdshader")

## 스킨 색 변형 재질 (ShopData.SKINS 항목)
static func skin_material(skin: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HUE_SHADER
	m.set_shader_parameter("hue", skin.get("hue", 0.0))
	m.set_shader_parameter("sat", skin.get("sat", 1.0))
	m.set_shader_parameter("val", skin.get("val", 1.0))
	return m
