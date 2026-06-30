extends CPUParticles2D

# 单个烟花爆炸粒子：发射一次后自动释放

func _ready() -> void:
	finished.connect(queue_free)
