extends SceneTree
## 앱 아이콘(icon.png 512)과 시작 화면 그림(splash.png)을 코드로 그려 저장한다. 창 모드에서 실행.
## 사용: godot --path . -s tools/make_icon.gd

class Art2D extends Node2D:
	var size := 512.0
	var splash := false
	func _draw() -> void:
		var c := Vector2(size, size) / 2.0
		if not splash:
			# 둥근 사각 배경 (안드로이드가 다시 깎으므로 꽉 채운다)
			draw_rect(Rect2(Vector2.ZERO, Vector2(size, size)), Color(0.09, 0.08, 0.16))
			for i in 24:
				var k := float(i) / 24.0
				draw_circle(c, size * 0.5 * (1.0 - k), Color(0.25, 0.14, 0.38, 0.05))
		var gold := Color(0.95, 0.78, 0.42)
		var r := size * 0.36
		draw_arc(c, r, 0, TAU, 96, gold, size * 0.022, true)
		draw_arc(c, r * 0.84, 0, TAU, 96, Color(gold, 0.5), size * 0.008, true)
		# 바깥 고리의 작은 룬 눈금
		for i in 12:
			var a := TAU * i / 12.0
			var p := c + Vector2(cos(a), sin(a)) * r * 0.92
			draw_circle(p, size * 0.012, gold)
		# 가운데 불 룬 ∧ (빛번짐 → 선 → 흰 시작점)
		var s := size * 0.42
		var o := c - Vector2(s, s) / 2.0 + Vector2(0, s * 0.04)
		var pts := PackedVector2Array([o + Vector2(0.08, 0.92) * s, o + Vector2(0.5, 0.1) * s, o + Vector2(0.92, 0.92) * s])
		for w in [0.16, 0.11, 0.07]:
			draw_polyline(pts, Color(1.0, 0.45, 0.12, 0.18), size * w, true)
		draw_polyline(pts, Color(1.0, 0.55, 0.2), size * 0.05, true)
		draw_polyline(pts, Color(1.0, 0.85, 0.55), size * 0.018, true)
		draw_circle(pts[0], size * 0.04, Color.WHITE)

func _init() -> void:
	await process_frame
	await _render(512, false, "res://icon.png")
	await _render(720, true, "res://splash.png")
	print("icon and splash written")
	quit()

func _render(px: int, splash: bool, out: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = splash
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var n := Art2D.new()
	n.size = px
	n.splash = splash
	vp.add_child(n)
	get_root().add_child(vp)
	await process_frame
	await process_frame
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(out))
	vp.queue_free()
