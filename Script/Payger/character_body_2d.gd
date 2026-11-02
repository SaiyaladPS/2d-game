extends CharacterBody2D

# ค่าความเร็วและพลังโจมตีปรับได้จาก Inspector โดยระยะโจมตีวัดจากจุดกลางของตัวละคร
@export var speed: float = 150.0
@export var attack_range: float = 90.0
@export var attack_width: float = 50.0
@export var knockback_force: float = 220.0
@export_range(1, 100, 1) var attack_damage: int = 20
@export_range(1, 1000, 1) var max_health: int = 100
@export_range(0.1, 2.0, 0.1) var hurt_animation_duration: float = 0.45

# อ้างอิงโหนดที่วางไว้แล้วใน Scene เพื่อควบคุมภาพและแสดง HP โดยไม่สร้าง UI ผ่านโค้ด
@onready var animated_sprite: AnimatedSprite2D = $AnimatedPayyer
@onready var health_bar: ProgressBar = $HealthBar

# เก็บทิศสุดท้ายไว้เลือกภาพ Idle และทิศโจมตีเมื่อผู้เล่นไม่ได้กดเดิน
var last_direction: String = "Front"
var health: int
var is_dead: bool = false
var hurt_time_left: float = 0.0

# เริ่มเกมด้วย HP เต็ม และกำหนดช่วงของ ProgressBar ให้ตรงกับ HP สูงสุด
func _ready() -> void:
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	if animated_sprite.sprite_frames.has_animation("Dying"):
		animated_sprite.sprite_frames.set_animation_loop("Dying", false)

# อ่านปุ่มเดินทุก physics frame และขยับด้วยความเร็วคงที่
# การโจมตีเกิดครั้งเดียวตอนกดเมาส์ลง แต่ภาพโจมตีเล่นต่อขณะกดค้าง
func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

	if direction != Vector2.ZERO:
		_update_facing(direction)

	if Input.is_action_just_pressed("left_mouse_button"):
		_try_attack()

	if hurt_time_left > 0.0:
		hurt_time_left = maxf(0.0, hurt_time_left - _delta)
		_play_animation(last_direction + "-Hurt")
		return

	if Input.is_action_pressed("left_mouse_button"):
		_play_animation(last_direction + "-Attacking")
	elif direction != Vector2.ZERO:
		_play_animation(last_direction + "-Running")
	else:
		_play_animation(last_direction + "-Idle")

# เลือก Mousater ที่ยังมีชีวิตและใกล้ที่สุด แล้วหันเข้าหาก่อนตรวจ hit zone
# hit zone เป็นสี่เหลี่ยมด้านหน้า: attack_range คือความลึก และ attack_width คือครึ่งความกว้างด้านข้าง
func _try_attack() -> void:
	var target: CharacterBody2D
	var nearest_distance := attack_range
	for node in get_tree().get_nodes_in_group("mousaters"):
		var enemy := node as CharacterBody2D
		if enemy == null:
			continue

		var distance := global_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			target = enemy

	if target == null:
		return

	# หันเข้าหา Mousater ก่อน เพื่อไม่ให้ทิศจากการเดินทำให้การโจมตีพลาด
	var to_mousater := target.global_position - global_position
	if to_mousater.length() > attack_range:
		return
	_update_facing(to_mousater)

	var facing_direction := Vector2.ZERO
	match last_direction:
		"Left":
			facing_direction = Vector2.LEFT
		"Right":
			facing_direction = Vector2.RIGHT
		"Back":
			facing_direction = Vector2.UP
		_:
			facing_direction = Vector2.DOWN

	var forward_distance := facing_direction.dot(to_mousater)
	var side_distance := absf(facing_direction.cross(to_mousater))
	if forward_distance < 0.0 or side_distance > attack_width:
		return

	if target.has_method("receive_hit"):
		target.receive_hit(facing_direction, knockback_force, attack_damage)

# ลด HP โดยไม่ให้ต่ำกว่าศูนย์; เมื่อหมดจะหยุดรับ input และเล่นแอนิเมชันตาย
func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	health = maxi(0, health - amount)
	health_bar.value = health
	if health == 0:
		is_dead = true
		velocity = Vector2.ZERO
		_play_animation("Dying")
	else:
		# Hurt มีเวลาจำกัดเพื่อให้ภาพกลับไป Idle หรือ Running ได้เองหลังโดนตี
		hurt_time_left = hurt_animation_duration
		_play_animation(last_direction + "-Hurt")

# เลือกหนึ่งในสี่ทิศจากแกนที่ผู้เล่นเคลื่อนที่มากกว่า เพื่อให้การเดินแนวทแยงยังใช้ภาพได้ชัด
func _update_facing(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		last_direction = "Left" if direction.x < 0.0 else "Right"
	else:
		last_direction = "Back" if direction.y < 0.0 else "Front"

# ป้องกันการเรียกชื่อแอนิเมชันที่ไม่มีใน SpriteFrames และไม่เริ่มภาพเดิมซ้ำทุกเฟรม
func _play_animation(animation_name: String) -> void:
	if animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)
