extends Control
## 스테이지 맵: 노드 10개를 지그재그 길로. 탭하면 스테이지 정보 창 → 시작.

const NODE_SIZE := 190.0
const BOSS_TRAITS: BossTraitList = preload("res://data/boss_traits.tres")

var _nodes: Array = []  # [{stage, center}]
var _info: Control

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
	var bar := UI.top_bar(self, GameState.chapter.title, "마력석 %d" % GameState.data.stones)
	bar[0].pressed.connect(func(): GameState.go(GameState.SCENE_HOME))
	resized.connect(_layout)
	_layout()

## 아래(1)에서 위(10)로 올라가는 지그재그. 화면 높이에 맞춰 간격을 나눈다.
func _layout() -> void:
	for n in _nodes:
		n.button.queue_free()
	_nodes.clear()
	var count := GameState.chapter.stage_count
	var top := 230.0
	var bottom := size.y - 170.0
	var xs := [270.0, 540.0, 810.0, 540.0]
	for i in count:
		var s := i + 1
		var y := lerpf(bottom, top, float(i) / maxf(count - 1, 1))
		var c := Vector2(xs[i % xs.size()], y)
		var b := _make_node(s)
		b.position = c - Vector2(NODE_SIZE, NODE_SIZE) / 2.0
		add_child(b)
		_nodes.append({"stage": s, "center": c, "button": b})
	queue_redraw()

func _make_node(s: int) -> Button:
	var b := Button.new()
	b.size = Vector2(NODE_SIZE, NODE_SIZE)
	var open := GameState.is_open(s)
	var info := GameState.stage_info(s)
	var cleared: bool = info.get("cleared", false)
	var next := open and not cleared
	var border := UI.STAR_ON if next else (UI.GOLD if cleared else Color(0.3, 0.3, 0.35))
	var bgc := Color(0.24, 0.2, 0.12) if next else Color(0.17, 0.17, 0.24)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := UI.box(bgc if open else Color(0.12, 0.12, 0.15), border, int(NODE_SIZE / 2), 5 if next else 3)
		if st == "pressed" or st == "hover_pressed":
			sb.bg_color = bgc.lightened(0.1)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_size_override("font_size", 46)
	if open:
		b.text = GameState.chapter.stage_name(s) + "\n" + (UI.stars_text(int(info.get("stars", 0))) if cleared else "")
	else:
		b.text = GameState.chapter.stage_name(s) + "\n잠김"
		b.add_theme_font_size_override("font_size", 36)
		b.disabled = true
	b.pressed.connect(_show_info.bind(s))
	return b

func _draw() -> void:
	for i in range(_nodes.size() - 1):
		var a: Vector2 = _nodes[i].center
		var b: Vector2 = _nodes[i + 1].center
		var done := GameState.is_cleared(_nodes[i].stage)
		draw_dashed_line(a, b, UI.GOLD if done else Color(0.3, 0.3, 0.36), 8.0, 22.0)

func _show_info(s: int) -> void:
	if _info != null:
		_info.queue_free()
	var ch := GameState.chapter
	var o := UI.overlay(self)
	_info = o[0]
	var vb: VBoxContainer = o[1]
	vb.add_child(UI.label("스테이지 " + ch.stage_name(s), 60, UI.GOLD))
	var info := GameState.stage_info(s)
	if info.get("cleared", false):
		vb.add_child(UI.label(UI.stars_text(int(info.stars)), 56, UI.STAR_ON))
	elif int(info.get("best_wave", 0)) > 0:
		vb.add_child(UI.label("최고 기록: 웨이브 %d" % int(info.best_wave), 34, UI.DIM))
	var lines := []
	lines.append("웨이브 %d · 마지막 웨이브 보스" % ch.waves_per_stage)
	var traits := Battle.preview_traits(BOSS_TRAITS.items, ch.boss_traits(s), ch.stage_seed(s),
		ch.waves_per_stage, GameState.runes().size() >= 3)
	var tnames := []
	for t in traits:
		tnames.append(t.title)
	lines.append("보스: %s" % ch.boss_name(s))
	lines.append("보스 특성: " + (" · ".join(tnames) if not tnames.is_empty() else "없음"))
	lines.append("적 체력 x%.2f · 보스 체력 x%.2f" % [ch.enemy_hp_mult(s), ch.boss_hp_mult(s)])
	var names := []
	for e in GameState.runes():
		names.append(Element.name_of(e))
	lines.append("쓸 수 있는 룬: " + " · ".join(names))
	var reward := "보상: 마력석 %d" % ch.clear_reward(s)
	if not info.get("cleared", false):
		reward += " (첫 클리어 +%d)" % ch.first_clear_bonus
	lines.append(reward)
	vb.add_child(UI.label("\n".join(lines), 36))
	var start := UI.button("시작", 140, 56)
	start.pressed.connect(func(): GameState.start_stage(s))
	vb.add_child(start)
	var close := UI.button("닫기", 100, 36)
	close.pressed.connect(func():
		_info.queue_free()
		_info = null)
	vb.add_child(close)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _info != null:
			_info.queue_free()
			_info = null
		else:
			GameState.go(GameState.SCENE_HOME)
