extends Control
## 영구 강화: 마력석으로 항목 레벨업.

var _stones_label: Label
var _list: VBoxContainer

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
	var bar := UI.top_bar(self, "영구 강화")
	bar[0].pressed.connect(func(): GameState.go(GameState.SCENE_TITLE))
	_stones_label = bar[2]
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 30)
	_list.position = Vector2(60, 200)
	_list.size = Vector2(960, 0)
	add_child(_list)
	_refresh()

func _refresh() -> void:
	_stones_label.text = "마력석 %d" % GameState.data.stones
	for c in _list.get_children():
		c.queue_free()
	for u in GameState.perm_list.items:
		_list.add_child(_row(u))
	var note := UI.label("상한이 있어서, 정확하게 그리고 속성을 바꾸는 실력이 여전히 핵심입니다.", 28, UI.DIM)
	_list.add_child(note)

func _row(u: PermUpgradeData) -> Control:
	var panel := PanelContainer.new()
	var sb := UI.box(Color(0.15, 0.15, 0.21), UI.GOLD.darkened(0.5), 18, 3)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	panel.add_child(hb)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	hb.add_child(left)
	var lv := GameState.perm_level(u.id)
	left.add_child(UI.label("%s   Lv %d / %d" % [u.title, lv, u.max_stacks], 40, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	left.add_child(UI.label(u.description, 30, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	if lv > 0 and u.max_stacks > 1:
		var now := u.amount * lv
		var txt := "지금: +%d%s" % [int(round(now * 100)) if u.unit == "%" else int(now), u.unit]
		left.add_child(UI.label(txt, 28, UI.GOOD, HORIZONTAL_ALIGNMENT_LEFT))
	var b := UI.button("", 120, 34)
	b.custom_minimum_size.x = 260
	if lv >= u.max_stacks:
		b.text = "최대"
		b.disabled = true
	else:
		b.text = "강화\n마력석 %d" % u.cost_at(lv)
		b.disabled = not GameState.can_buy(u.id)
		b.pressed.connect(func():
			if GameState.buy(u.id):
				_refresh())
	hb.add_child(b)
	return panel

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.go(GameState.SCENE_TITLE)
