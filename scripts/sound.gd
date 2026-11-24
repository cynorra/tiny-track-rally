extends Node

var music: = AudioStreamPlayer.new()
var sfx_players: Array[AudioStreamPlayer] = []
var sounds: = {}

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	music.bus = "Music";add_child(music)
	for i in 6:
		var p: = AudioStreamPlayer.new();p.bus = "SFX";add_child(p);sfx_players.append(p)
	for n in ["click", "coin", "beep", "go", "nitro", "lap"]:
		sounds[n] = load("res://sounds/%s.ogg" % n)




var _music: = {}
func play_music(name: String) -> void :
	if not _music.has(name): _music[name] = load("res://sounds/music_%s.ogg" % name)
	var s = _music[name]
	if music.stream == s and music.playing: return
	s.loop = true
	music.stream = s;music.play()

func play(name: String, pitch: = 1.0) -> void :
	for p in sfx_players:
		if not p.playing:
			p.stream = sounds[name];p.pitch_scale = pitch;p.play();return



var warmed: = false
func warm() -> void :
	if warmed: return
	warmed = true
	for n in sounds.keys():
		var p: = AudioStreamPlayer.new();p.bus = "SFX";p.volume_db = -80.0;p.stream = sounds[n];add_child(p);p.play()
		get_tree().create_timer(0.15, true, false, true).timeout.connect(p.queue_free)
