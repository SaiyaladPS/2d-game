extends CharacterBody2D

# แผ่นภาพ Hurt แยกตามทิศ ส่วน Dying เป็นแอนิเมชันชุดเดียวของตัวละคร
const HURT_SHEETS: Dictionary = {
	"Back": preload("res://Sprites/Mousater/Back - Hurt.png"),
	"Front": preload("res://Sprites/Mousater/Front - Hurt.png"),
	"Left": preload("res://Sprites/Mousater/Left - Hurt.png"),
	"Right": preload("res://Sprites/Mousater/Right - Hurt.png"),
}
const DYING_SHEET: Texture2D = preload("res://Sprites/Mousater/Dying.png")

# ค่าความเร็ว การหยุด และแรงหน่วงใช้ปรับพฤติกรรมศัตรูได้จาก Inspector
@export_range(0.0, 500.0, 1.0) var speed: float = 100.0
@export_range(0.0, 200.0, 1.0) var stop_distance: float = 28.0
@export_range(1.0, 5000.0, 1.0) var knockback_deceleration: float = 1400.0

# ค่าระบบต่อสู้; ศัตรูตีผู้เล่นเมื่อเข้าใกล้และมี HP แยกสำหรับแต่ละตัว
@export_range(1, 1000, 1) var max_health: int = 60
@export var contact_damage: int = 10
@export var contact_attack_range: float = 64.0
@export var contact_attack_cooldown: float = 1.0
@export_range(0.0, 30.0, 0.5) var corpse_lifetime: float = 3.0

@onready var target: Node2D = get_node_or_null("../Payer1")
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# จำทิศล่าสุดไว้เลือกภาพ Idle หลังหยุดเคลื่อนที่
var last_direction: String = "Front"
var knockback_time_left: float = 0.0
var health: int
var contact_cooldown_left: float = 0.0
var is_dead: bool = false
var hurt_time_left: float = 0.0

# สร้างแอนิเมชันที่ยังไม่มีใน SpriteFrames จากแผ่นภาพ แล้วตั้ง HP เต็ม
func _ready() -> void:
	_ensure_combat_animations()
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	add_to_group("mousaters")

# รับผลจากการโจมตีของผู้เล่น: ลด HP ก่อน แล้วค่อยเริ่มแรงผลักถ้ายังรอด
func receive_hit(direction: Vector2, force: float, damage: int) -> void:
	if is_dead or direction.is_zero_approx() or force <= 0.0:
		return

	take_damage(damage)
	if is_dead:
		return

	velocity = direction.normalized() * force
	# ลดแรงผลักจนหยุด แล้วค่อยกลับไปไล่ตามผู้เล่น
	knockback_time_left = force / knockback_deceleration

# ตัด HP ตามจำนวนดาเมจ; เมื่อหมดจะซ่อนตัวและให้ Spawner สร้างตัวใหม่ตามรอบเวลา
func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	health = maxi(0, health - amount)
	health_bar.value = health
	if health == 0:
		_die()
	else:
		# เล่น Hurt ตามทิศที่ศัตรูกำลังหัน และคงภาพไว้ชั่วครู่ระหว่างถูกผลัก
		hurt_time_left = 0.45
		_play_animation(last_direction + "-Hurt")

# ซ่อนตัวและปิด collider ระหว่างรอ เพื่อไม่ให้ศัตรูที่ตายแล้วบังทางผู้เล่น
func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	remove_from_group("mousaters")
	collision_shape.set_deferred("disabled", true)
	_play_animation("Dying")
	# คงภาพท่าตายไว้ 3 วินาที แล้วค่อยซ่อนซาก; ตัว Spawner ยังใช้อ้างอิงต้นแบบได้
	await get_tree().create_timer(corpse_lifetime).timeout
	if is_inside_tree():
		hide()

# เตรียมสำเนาศัตรูที่ Spawner สร้างให้เป็นตัวใหม่ โดยคืนสถานะก่อนเริ่มทำงาน
func prepare_for_spawn(new_position: Vector2) -> void:
	global_position = new_position
	health = max_health
	health_bar.value = health
	contact_cooldown_left = 0.0
	knockback_time_left = 0.0
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", false)
	show()
	is_dead = false
	add_to_group("mousaters")
	_play_animation(last_direction + "-Idle")

# ลำดับทำงานในแต่ละ physics frame: ถ้าตายให้หยุด, ถ้าถูกผลักให้ถอย, มิฉะนั้นไล่ตามและโจมตีเมื่อประชิด
func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	contact_cooldown_left = maxf(0.0, contact_cooldown_left - _delta)
	hurt_time_left = maxf(0.0, hurt_time_left - _delta)

	if knockback_time_left > 0.0:
		knockback_time_left = maxf(0.0, knockback_time_left - _delta)
		velocity = velocity.move_toward(Vector2.ZERO, knockback_deceleration * _delta)
		_update_animation(velocity)
		move_and_slide()
		return

	if target == null:
		velocity = Vector2.ZERO
		
		move_and_slide()
		return

	var distance_to_target := global_position.distance_to(target.global_position)
	if distance_to_target > stop_distance:
		velocity = global_position.direction_to(target.global_position) * speed
	else:
		velocity = Vector2.ZERO
	if distance_to_target <= contact_attack_range:
		_attack_target()
	_update_animation(velocity)
	move_and_slide()

# สร้างดาเมจเป็นจังหวะตาม cooldown แทนการลด HP ทุกเฟรมขณะยืนใกล้ผู้เล่น
func _attack_target() -> void:
	if contact_cooldown_left > 0.0 or contact_damage <= 0 or not target.has_method("take_damage"):
		return

	# ใช้ cooldown กันไม่ให้เลือดลดทุกเฟรมขณะยืนชิดกัน
	target.take_damage(contact_damage)
	contact_cooldown_left = contact_attack_cooldown
	
# เลือกภาพตามทิศความเร็ว; เมื่อหยุดจะคงทิศล่าสุดและเล่น Idle
func _update_animation(dir: Vector2) -> void:
	if hurt_time_left > 0.0:
		_play_animation(last_direction + "-Hurt")
		return

	var anim_name: String
	
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
	
	_play_animation(anim_name)

# เพิ่มแอนิเมชัน Hurt และ Dying ลงใน SpriteFrames เดิมครั้งเดียว เพื่อใช้ร่วมกับศัตรูที่เกิดเพิ่ม
func _ensure_combat_animations() -> void:
	var frames := animated_sprite.sprite_frames
	if frames == null:
		return

	for direction in HURT_SHEETS:
		_add_sheet_animation(direction + "-Hurt", HURT_SHEETS[direction], 11.0, true)
	_add_sheet_animation("Dying", DYING_SHEET, 5.0, false)

# แผ่นภาพตัวละครเป็นตาราง 5 คอลัมน์ x 2 แถว ขนาดเฟรม 840x720; สร้าง AtlasTexture สำหรับ 10 เฟรม
func _add_sheet_animation(animation_name: String, sheet: Texture2D, frames_per_second: float, loops: bool) -> void:
	var frames := animated_sprite.sprite_frames
	if frames == null or frames.has_animation(animation_name):
		return

	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, frames_per_second)
	frames.set_animation_loop(animation_name, loops)
	for frame_index in range(10):
		var atlas_frame := AtlasTexture.new()
		atlas_frame.atlas = sheet
		atlas_frame.region = Rect2((frame_index % 5) * 840, int(frame_index / 5) * 720, 840, 720)
		frames.add_frame(animation_name, atlas_frame)

# ตรวจว่ามีภาพที่ขอจริง และรักษาความคืบหน้าของแอนิเมชันเดิมระหว่างเฟรม
func _play_animation(animation_name: String) -> void:
	if animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	# เล่นต่อเนื่องเมื่อยังเป็นอนิเมชันเดิม ไม่รีเซ็ตกลับเฟรมแรกทุกฟิสิกส์เฟรม
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)
