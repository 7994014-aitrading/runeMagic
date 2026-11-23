extends Node
## 자동 로드 "GameState": 저장(user://save.json), 설정, 진행, 마력석, 영구 강화, 화면 이동.

const SAVE_PATH := "user://save.json"
const SCENE_TITLE := "res://scenes/title.tscn"
const SCENE_MAP := "res://scenes/stage_map.tscn"
const SCENE_BATTLE := "res://scenes/main.tscn"
const SCENE_SHOP := "res://scenes/perm_shop.tscn"
const SCENE_PRACTICE := "res://scenes/rune_test.tscn"

var chapter: ChapterConfig = preload("res://data/chapter1.tres")
var perm_list: UpgradeList = preload("res://data/perm_upgrades.tres")

## 지금 고른 스테이지 (전투 장면이 읽는다). 0이면 전투 장면을 직접 실행한 것.
var current_stage := 0

var data := {}

func _ready() -> void:
	load_game()
	process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 중에도 소리
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -8.0
	add_child(_music_player)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)

func _defaults() -> Dictionary:
	return {
		"version": 1,
		"stones": 0,
		"stages": {},  # "1" → {"cleared": bool, "stars": int, "best_wave": int}
		"perm": {},  # id → level
		"tutorial": {},  # 키 → true (s1, s2, s3, upgrade, shield)
		"settings": {"sfx": true, "music": true, "vibration": true, "dev": false},
	}

func load_game() -> void:
	data = _defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for k in parsed.keys():
			if data.has(k) and data[k] is Dictionary and parsed[k] is Dictionary:
				data[k].merge(parsed[k], true)
			else:
				data[k] = parsed[k]

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))

func reset_save() -> void:
	data = _defaults()
	save_game()

# ---- 진행 ----

func stage_info(s: int) -> Dictionary:
	return data.stages.get(str(s), {"cleared": false, "stars": 0, "best_wave": 0})

func is_cleared(s: int) -> bool:
	return stage_info(s).get("cleared", false)

## 들어갈 수 있는 가장 높은 스테이지 (깬 스테이지 + 1)
func max_open_stage() -> int:
	var s := 1
	while s < chapter.stage_count and is_cleared(s):
		s += 1
	return s

func is_open(s: int) -> bool:
	return s >= 1 and s <= max_open_stage()

func is_first_run() -> bool:
	return data.stages.is_empty()

func runes() -> Array:
	return chapter.runes_at(max_open_stage())

func total_stars() -> int:
	var n := 0
	for k in data.stages.keys():
		n += int(data.stages[k].get("stars", 0))
	return n

## 판 결과 기록. 반환: {stars, stones, first_clear, new_runes: [element]}
func record_result(s: int, won: bool, wave_reached: int, castle_ratio: float) -> Dictionary:
	var before := runes()
	var info := stage_info(s).duplicate()
	var out := {"stars": 0, "stones": 0, "first_clear": false, "new_runes": []}
	if won:
		out.stars = chapter.stars_for(castle_ratio)
		out.first_clear = not info.get("cleared", false)
		out.stones = chapter.clear_reward(s) + (chapter.first_clear_bonus if out.first_clear else 0)
		info.cleared = true
		info.stars = maxi(int(info.get("stars", 0)), out.stars)
	else:
		out.stones = chapter.loss_reward_per_wave * maxi(wave_reached - 1, 0)
	info.best_wave = maxi(int(info.get("best_wave", 0)), wave_reached)
	data.stages[str(s)] = info
	data.stones = int(data.stones) + out.stones
	for e in runes():
		if not before.has(e):
			out.new_runes.append(e)
	save_game()
	return out

# ---- 영구 강화 ----

func perm_level(id: String) -> int:
	return int(data.perm.get(id, 0))

func perm(id: String) -> PermUpgradeData:
	for u in perm_list.items:
		if u.id == id:
			return u
	return null

## 영구 강화 총 효과 (레벨 x 레벨당 효과)
func perm_value(id: String) -> float:
	var u := perm(id)
	return 0.0 if u == null else u.amount * perm_level(id)

func can_buy(id: String) -> bool:
	var u := perm(id)
	var lv := perm_level(id)
	return u != null and lv < u.max_stacks and int(data.stones) >= u.cost_at(lv)

func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	var u := perm(id)
	data.stones = int(data.stones) - u.cost_at(perm_level(id))
	data.perm[id] = perm_level(id) + 1
	save_game()
	return true

# ---- 튜토리얼 · 설정 ----

func tutorial_done(key: String) -> bool:
	return data.tutorial.get(key, false)

func mark_tutorial(key: String) -> void:
	data.tutorial[key] = true
	save_game()

func setting(key: String) -> bool:
	return data.settings.get(key, false)

func set_setting(key: String, value: bool) -> void:
	data.settings[key] = value
	save_game()
	if key == "music":
		var want := _music_name
		_music_name = ""
		music(want if value else "")
		_music_name = want

func vibrate(ms: int) -> void:
	if setting("vibration"):
		Input.vibrate_handheld(ms)

# ---- 화면 이동 ----

func go(scene: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(scene)

func start_stage(s: int) -> void:
	current_stage = s
	go(SCENE_BATTLE)

# ---- 소리 (assets/third_party, 없으면 조용히 넘어감) ----

const SFX_DIR := "res://assets/third_party/"
const SFX := {
	"click": ["ninja/sfx/click.wav", -6.0],
	"fail": ["ninja/sfx/fail.wav", -8.0],
	"cast": ["ninja/sfx/cast.wav", -6.0],
	"hit": ["ninja/sfx/hit.wav", -16.0],
	"castle": ["ninja/sfx/castle.wav", -4.0],
	"upgrade": ["ninja/sfx/upgrade.wav", -4.0],
	"boss": ["ninja/sfx/boss.wav", -2.0],
	"explosion": ["ninja/sfx/explosion.wav", -8.0],
	"win": ["ninja/sfx/win.wav", -2.0],
	"lose": ["ninja/sfx/lose.wav", -2.0],
	"fire": ["lentikula/fire.wav", -14.0],
	"ice": ["lentikula/ice.wav", -14.0],
	"lightning": ["lentikula/lightning.wav", -14.0],
}
const MUSIC := {"menu": "ninja/music/menu.ogg", "battle": "ninja/music/battle.ogg", "boss": "ninja/music/boss.ogg"}
const SFX_MIN_GAP := 0.07  # 같은 소리를 이보다 자주 내지 않는다 (탄이 많을 때)

var _music_player: AudioStreamPlayer
var _music_name := ""
var _sfx_players: Array = []
var _sfx_next := 0
var _sfx_last := {}
var _streams := {}

func _stream(rel: String) -> AudioStream:
	if not _streams.has(rel):
		var path := SFX_DIR + rel
		_streams[rel] = load(path) if ResourceLoader.exists(path) else null
	return _streams[rel]

func sfx(name: String, volume_db := 0.0) -> void:
	if not setting("sfx") or not SFX.has(name) or _sfx_players.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_sfx_last.get(name, -1.0)) < SFX_MIN_GAP:
		return
	var st := _stream(SFX[name][0])
	if st == null:
		return
	_sfx_last[name] = now
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = st
	p.volume_db = SFX[name][1] + volume_db
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()

## 배경 음악 바꾸기 ("" = 끄기). 같은 곡이면 이어서 튼다.
func music(name: String) -> void:
	if _music_player == null:
		return
	if name == _music_name and (_music_player.playing or not setting("music")):
		return
	_music_name = name
	_music_player.stop()
	if name == "" or not setting("music") or not MUSIC.has(name):
		return
	var st := _stream(MUSIC[name])
	if st == null:
		return
	if st is AudioStreamOggVorbis:
		st.loop = true
	_music_player.stream = st
	_music_player.play()
