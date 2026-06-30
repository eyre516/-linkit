extends CanvasLayer

# 烟花庆祝层：在屏幕随机位置连续绽放多组烟花

const BURST_SCENE := preload("res://firework_burst.tscn")
const COLORS: Array[Color] = [
	Color.RED,
	Color.GREEN,
	Color.BLUE,
	Color.YELLOW,
	Color.CYAN,
	Color.MAGENTA,
	Color.ORANGE,
	Color.WHITE
]

const BURST_COUNT := 80
const WAIT_TIME := 0.22

@onready var timer: Timer = $Timer

var _bursts_left: int = BURST_COUNT

func _ready() -> void:
	timer.wait_time = WAIT_TIME
	timer.timeout.connect(_spawn_burst)
	_spawn_burst()
	timer.start()

func _spawn_burst() -> void:
	if _bursts_left <= 0:
		timer.stop()
		queue_free()
		return

	_bursts_left -= 1

	var burst: CPUParticles2D = BURST_SCENE.instantiate()
	var viewport_rect := get_viewport().get_visible_rect()
	var margin_x := viewport_rect.size.x * 0.1
	var margin_y := viewport_rect.size.y * 0.1
	burst.position = Vector2(
		randf_range(margin_x, viewport_rect.size.x - margin_x),
		randf_range(margin_y, viewport_rect.size.y - margin_y * 2.0)
	)
	burst.modulate = COLORS.pick_random()
	add_child(burst)
	burst.restart()
