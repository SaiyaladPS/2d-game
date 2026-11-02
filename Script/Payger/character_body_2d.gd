extends CharacterBody2D

@export var speed: float = 300.0
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: String = "Front"

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	velocity = direction * speed
	move_and_slide()
	
	update_animation(direction)

func update_animation(dir: Vector2) -> void:
	var anim_name = ""
	
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y):
			if dir.x < 0:
				last_direction = "Left"
				anim_name = "Left-Running"
			else:
				last_direction = "Right"
				anim_name = "Right-Running"
		else:
			if dir.y < 0:
				last_direction = "Back"
				anim_name = "Back-Running"
			else:
				last_direction = "Front"
				anim_name = "Front-Running"
	else:
		anim_name = last_direction + "-Idle"
	
	# ตรวจสอบว่ามีอนิเมชันชื่อนี้อยู่จริงไหม ก่อนสั่งเล่น (ป้องกัน Error)
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
