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
	t.set_stylebox("hover", "Button", box(Color(0.21, 0.21, 0.29), GOLD.darkened(0.2)))
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
	var r := label(right_text, 34, STAR_ON, HORIZONTAL_ALIGNMENT_RIGHT)
	r.custom_minimum_size.x = 200
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
