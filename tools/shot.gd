extends SceneTree
## 장면 하나를 띄워 몇 프레임 뒤 화면을 PNG로 저장 (창 모드에서만 됨, headless는 그림이 없음).
## 사용: godot --path . -s tools/shot.gd -- res://scenes/title.tscn out.png [프레임 수] [화면 높이] [스테이지]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: String = args[0]
	var out: String = args[1]
	var frames := int(args[2]) if args.size() > 2 else 30
	if args.size() > 3:
		get_root().size = Vector2i(540, int(args[3]) / 2)
	await process_frame
	if args.size() > 4:
		get_root().get_node("GameState").current_stage = int(args[4])
	change_scene_to_file(scene)
	for i in frames:
		await process_frame
	get_root().get_texture().get_image().save_png(out)
	quit()
