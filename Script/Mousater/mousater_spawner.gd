extends Node

# กำหนดความถี่และรัศมีรอบจุดเริ่มต้นที่ใช้ปล่อยศัตรูตัวใหม่
@export_range(0.5, 60.0, 0.5) var spawn_interval: float = 3.0
@export_range(0.0, 500.0, 1.0) var spawn_radius: float = 80.0

# ใช้ตัว Mousater ใน Scene เป็นต้นแบบ เพื่อคัดลอกภาพ, collider และการตั้งค่าเดิม
@onready var template: CharacterBody2D = get_node_or_null("../Mousater")

var time_until_spawn: float = 0.0

# เริ่มนับถอยหลังหลัง Scene พร้อมแล้ว ทำให้ตัวแรกที่มีในฉากไม่ถูกสร้างซ้ำทันที
func _ready() -> void:
	time_until_spawn = spawn_interval

# สร้างศัตรูหนึ่งตัวทุกช่วงเวลาที่กำหนด โดยไม่ตรวจว่าตัวอื่นยังมีชีวิตอยู่หรือไม่
func _process(delta: float) -> void:
	if template == null:
		return

	time_until_spawn -= delta
	if time_until_spawn > 0.0:
		return

	# ตั้งเวลารอบถัดไปจากเวลาปัจจุบัน เพื่อไม่ให้เฟรมช้าสร้างศัตรูหลายตัวรวดเดียว
	time_until_spawn = spawn_interval
	_spawn_mousater()

# ทำสำเนา Node ต้นแบบใต้ parent เดิม เพื่อให้ path ไปยังผู้เล่นยังใช้งานได้
# สุ่มตำแหน่งบนวงรอบจุดเกิด แล้วรีเซ็ต HP กับ collider ของสำเนาก่อนเริ่มเกม
func _spawn_mousater() -> void:
	var new_mousater := template.duplicate() as CharacterBody2D
	if new_mousater == null:
		return

	var angle := randf_range(0.0, TAU)
	var offset := Vector2.from_angle(angle) * spawn_radius
	template.get_parent().add_child(new_mousater)
	new_mousater.call_deferred("prepare_for_spawn", template.global_position + offset)
