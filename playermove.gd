extends CharacterBody2D


@export var tile_size = 24
@export var walk_speed = 0.25
@export var speed = 0.25
@export var run_speed = 0.15
@onready var animations = $AnimatedSprite2D
@onready var interact_ray = $RayCast2D

var is_moving = false
var step_toggle = false
var textbox = null # Store the reference here
var position_history: Array[Vector2] = []

func _ready():
	# 1. Find the Textbox ONCE at the start, not every frame
	textbox = get_tree().current_scene.find_child("Textbox", true, false)
	
	if Global.target_spawn_name != "":
		var spawn_point = get_tree().current_scene.find_child(Global.target_spawn_name)
		if spawn_point:
			global_position = spawn_point.global_position
			if Global.target_direction != "":
				animations.play("walk_" + Global.target_direction)
				# Update raycast to match spawn direction
				update_raycast(string_to_vector(Global.target_direction))
		Global.target_spawn_name = ""
		Global.target_direction = ""

func _process(_delta):
	# --- 1. BUSY CHECK ---
	var is_busy = false
	if textbox and textbox.get("current_state") != 0: 
	# --- 2. MOVEMENT GUARD ---
		is_busy = true

	# If interacting, busy, or moving, stop here.
	if Input.is_action_just_pressed("ui_accept"):
		if not is_moving and not is_busy and interact_ray.is_colliding():
			var collider = interact_ray.get_collider()
			if collider.has_method("interact"):
				collider.interact()
		return

	if is_busy or is_moving:
		return
	
	# --- 3. INPUT HANDLING ---
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
	if input_vector != Vector2.ZERO:
		# REMOVED: The code that forced input_vector.y = 0
		
		# Allow diagonals by rounding the normalized vector
		# (0.7, 0.7) becomes (1, 1) -> Moving diagonally
		input_vector = input_vector.normalized().round()
		
		var is_running = Input.is_action_pressed("shift")
		var current_duration = run_speed if is_running else walk_speed
		var anim_type = "walk_"
		
		# Update Raycast to face the new direction
		update_raycast(input_vector)
		
		# --- 4. ANIMATION & MOVEMENT ---
		# Determine which way to face (Up/Down takes priority visually)
		var dir_name = get_direction_name(input_vector)
		var full_anim_name = anim_type + dir_name
		
		animations.animation = full_anim_name
		animations.frame = 0 if not step_toggle else 2
		
		# Calculate step size
		var step = input_vector * tile_size
		
		# Check if the target tile (diagonal or straight) is free
		if not test_move(transform, step):
			move_smoothly(step, full_anim_name, current_duration)

func update_raycast(dir: Vector2):
	interact_ray.target_position = dir * tile_size

func get_direction_name(vec: Vector2) -> String:
	if vec.y > 0: return "down"
	if vec.y < 0: return "up"
	if vec.x > 0: return "right"
	if vec.x < 0: return "left"
	return "down"

# Helper for spawn logic
func string_to_vector(dir: String) -> Vector2:
	match dir:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN

func move_smoothly(step_vector, anim_name, duration):
	is_moving = true
	
	var start_frame = 0 if not step_toggle else 2
	var mid_frame = 1 if not step_toggle else 3
	var end_frame = 2 if not step_toggle else 0
	
	animations.animation = anim_name
	animations.frame = start_frame
	
	var tween = create_tween()
	tween.tween_property(self, "position", position + step_vector, duration)
	
	# FIX: Use tween callbacks instead of timers for perfect sync
	tween.parallel().tween_callback(func(): 
		animations.frame = mid_frame
	).set_delay(duration / 2.0)
	
	tween.tween_callback(func():
		animations.frame = end_frame
		is_moving = false
		step_toggle = !step_toggle
		position_history.push_front(global_position)
		if position_history.size() > 50: # 50 steps is plenty of history
			position_history.pop_back()
	)
func get_breadcrumb(step_back: int) -> Vector2:
	if position_history.size() == 0: 
		return global_position
		
	# Look back in the list. 'step_back' determines the gap between characters.
	var index = min(step_back, position_history.size() - 1)
	return position_history[index]
