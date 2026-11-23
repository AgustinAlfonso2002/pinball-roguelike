extends Node
## Efectos de sonido (autoload "Sfx").
##
## Usa un grupo de reproductores para que varios sonidos puedan sonar a la
## vez. Los archivos están en assets/sfx/ y se pueden reemplazar por los
## definitivos manteniendo el mismo nombre.

const NAMES := [
	"flipper_up", "flipper_down", "bumper", "sling", "post", "launch",
	"target", "bank_complete", "drain", "tilt", "nudge", "game_over",
]
const POOL_SIZE := 12

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for sound_name in NAMES:
		var path := "res://assets/sfx/%s.wav" % sound_name
		if ResourceLoader.exists(path):
			_streams[sound_name] = load(path)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Reproduce un sonido. volume va de 0 a 1; pitch_variation evita que los
## sonidos repetidos suenen idénticos.
func play(sound: String, volume := 1.0, pitch_variation := 0.06) -> void:
	if not _streams.has(sound):
		return
	var level := Tuning.v("sfx_volume") * volume
	if level <= 0.001:
		return
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _streams[sound]
	player.volume_db = linear_to_db(level)
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
