extends Control
## 스킨: 마법사 색 변형. 수정으로 사거나 스타터 팩으로 얻고, 장착한다.

var _list: VBoxContainer
var _t := 0.0
var _frames: Array = []
var _previews: Array = []  # [Node2D] 미리보기 (재질마다 하나)

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
	UI.wallet_bar(self)
	var scroll := ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 40
	scroll.offset_right = -40
	scroll.offset_top = 160
	scroll.offset_bottom = -200
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 20)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	UI.bottom_nav(self, "skins")
	_refresh()

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	_previews.clear()
	for id in ShopData.SKIN_ORDER:
		_list.add_child(_row(id))

func _row(id: String) -> Control:
	var sk: Dictionary = ShopData.SKINS[id]
	var owned := GameState.owns_skin(id)
	var equipped: bool = GameState.data.skin == id
	var panel := PanelContainer.new()
	var sb := UI.box(Color(0.15, 0.15, 0.21), UI.STAR_ON if equipped else UI.GOLD.darkened(0.5), 18, 4 if equipped else 3)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	panel.add_child(hb)
	# 미리보기 칸 (그림은 재질이 있는 Node2D로)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(200, 200)
	hb.add_child(holder)
	var prev := Node2D.new()
	prev.material = UI.skin_material(sk)
	prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(prev)
	prev.draw.connect(func(): _draw_preview(prev))
	_previews.append(prev)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(mid)
	mid.add_child(UI.label(sk.title, 40, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var note := "장착 중" if equipped else ("보유" if owned else ("스타터 팩 전용" if int(sk.cost) < 0 else "수정 %d" % int(sk.cost)))
	mid.add_child(UI.label(note, 30, UI.GOOD if owned else UI.DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var b := UI.button("", 110, 36)
	b.custom_minimum_size.x = 220
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if equipped:
		b.text = "장착 중"
		b.disabled = true
	elif owned:
		b.text = "장착"
		b.pressed.connect(func():
			GameState.set_skin(id)
			_refresh())
	elif int(sk.cost) < 0:
		b.text = "상점 보기"
		b.disabled = not GameState.can_buy_product("starter")
		b.pressed.connect(func(): GameState.go(GameState.SCENE_STORE))
	else:
		b.text = "구매"
		b.disabled = GameState.gems() < int(sk.cost)
		b.pressed.connect(func():
			if GameState.buy_skin(id):
				GameState.set_skin(id)
				GameState.sfx("upgrade")
				_refresh())
	hb.add_child(b)
	return panel

func _draw_preview(n: Node2D) -> void:
	if _frames.is_empty():
		return
	var tex: Texture2D = _frames[int(_t * 10.0) % _frames.size()]
	var sz := Vector2(tex.get_width(), tex.get_height()) * 1.5
	n.draw_texture_rect(tex, Rect2(Vector2(100, 100) - sz / 2.0, sz), false)

func _process(delta: float) -> void:
	_t += delta
	for p in _previews:
		if is_instance_valid(p):
			p.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.go(GameState.SCENE_HOME)
