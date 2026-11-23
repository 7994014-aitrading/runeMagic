extends SceneTree
## 이어하기 흐름 검사 (headless): 스테이지 4를 아무것도 안 그리고 두어 성이 무너지면
## 이어하기 창이 뜨는지, 이어한 뒤 판이 계속되는지, 두 번째로 무너지면 바로 패배인지 본다.
## 사용: godot --headless --path . --fixed-fps 30 -s tools/test_continue.gd

func _init() -> void:
	await process_frame
	var gs = get_root().get_node("GameState")
	gs.current_stage = 4
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	var battle = main.battle
	var pending := [0]
	var finished := [null]
	battle.defeat_pending.connect(func(): pending[0] += 1)
	battle.finished.connect(func(won): finished[0] = won)
	battle.wave_cleared.connect(func(_w): main._choose.call_deferred(0))  # 강화는 첫 번째로
	for i in 30 * 600:
		await process_frame
		if pending[0] == 1:
			break
	print("[test] defeat_pending=%d panel=%s paused=%s" % [pending[0], main._continue_panel != null, paused])
	main._close_continue()
	paused = false
	battle.revive(0.5)
	print("[test] after revive castle=%d running=%s" % [battle.castle_hp, battle.running])
	for i in 30 * 600:
		await process_frame
		if finished[0] != null:
			break
	print("[test] second fall: pending=%d finished=%s" % [pending[0], finished[0]])
	quit()
