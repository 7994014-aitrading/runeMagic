extends Control
## 상점: 스타터 팩(한정), 월정액, 수정 묶음, 마력석 교환. 데모는 테스트 결제.

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
	_list.add_theme_constant_override("separation", 24)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	UI.bottom_nav(self, "store")
	_refresh()

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if GameState.can_buy_product("starter"):
		_list.add_child(_section("한정 상품 · 남은 시간 " + UI.hms(GameState.starter_seconds_left())))
		_list.add_child(_product_row("starter", true))
	_list.add_child(_section("매일 받는 수정"))
	var pass_note := "" if not GameState.pass_active() else "  (남은 %d일)" % int(GameState.data.pass.days_left)
	_list.add_child(_product_row("pass", false, pass_note))
	_list.add_child(_section("룬 수정"))
	for id in ["gems_100", "gems_550", "gems_1200"]:
		_list.add_child(_product_row(id, false))
	_list.add_child(_section("마력석 교환 (수정으로)"))
	for id in ShopData.EXCHANGE.keys():
		_list.add_child(_exchange_row(id))
	_list.add_child(UI.label("데모 버전: 모든 결제는 테스트 결제이며 실제로 돈이 나가지 않습니다.", 26, UI.DIM))

func _section(text: String) -> Label:
	var l := UI.label(text, 34, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	return l

func _row_panel(highlight: bool) -> Array:
	var panel := PanelContainer.new()
	var sb := UI.box(Color(0.3, 0.17, 0.1) if highlight else Color(0.15, 0.15, 0.21),
		UI.STAR_ON if highlight else UI.GOLD.darkened(0.5), 18, 4 if highlight else 3)
	sb.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	panel.add_child(hb)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	hb.add_child(left)
	return [panel, hb, left]

func _product_row(id: String, highlight: bool, note := "") -> Control:
	var p: Dictionary = ShopData.PRODUCTS[id]
	var r := _row_panel(highlight)
	r[2].add_child(UI.label(p.title + note, 40, UI.STAR_ON if highlight else UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	if p.desc != "":
		r[2].add_child(UI.label(p.desc, 28, UI.DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var b := UI.button(ShopData.price_text(p.price), 110, 36)
	b.custom_minimum_size.x = 250
	b.disabled = not GameState.can_buy_product(id)
	b.pressed.connect(func():
		UI.confirm_purchase(self, p.title, ShopData.price_text(p.price), func():
			GameState.grant(id)
			GameState.sfx("upgrade")
			UI.notice(self, "구매 완료", p.title)
			_refresh()))
	r[1].add_child(b)
	return r[0]

func _exchange_row(id: String) -> Control:
	var e: Dictionary = ShopData.EXCHANGE[id]
	var r := _row_panel(false)
	r[2].add_child(UI.label(e.title, 40, UI.STAR_ON, HORIZONTAL_ALIGNMENT_LEFT))
	r[2].add_child(UI.label("영구 강화를 더 빨리", 28, UI.DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var b := UI.button("수정 %d" % e.cost, 110, 36)
	b.custom_minimum_size.x = 250
	b.disabled = GameState.gems() < int(e.cost)
	b.pressed.connect(func():
		if GameState.exchange(id):
			GameState.sfx("upgrade")
			_refresh())
	r[1].add_child(b)
	return r[0]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameState.go(GameState.SCENE_HOME)
