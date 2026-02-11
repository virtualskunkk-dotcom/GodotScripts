extends CharacterBody2D

@onready var animations = $AnimatedSprite2D

var parent_node = null
var follow_index = 2 # Keeps them 48px behind
var is_moving = false

# --- NEW: Match Player's "Step Toggle" Logic ---
var step_toggle = false 
# -----------------------------------------------

var position_history: Array[Vector2] = []

func _process(_delta):
	if parent_node == null or is_moving: return
	
	var target_pos = parent_node.get_breadcrumb(follow_index)
	
	# Only move if we aren't already there AND the leader has moved away
	if global_position.distance_to(target_pos) > 1 and parent_node.global_position != target_pos:
		move_to_tile(target_pos)

func move_to_tile(target_pos: Vector2):
	is_moving = true
	
	# 1. Get Direction Name (e.g., "walk_up")
	var direction = (target_pos - global_position).normalized()
	var anim_name = get_anim_name(direction)
	
	# 2. Setup Frames (Exact copy of Player Logic)
	# 0 = Left Step, 1 = Stand, 2 = Right Step, 3 = Stand (Assuming 4-frame sheet)
	var start_frame = 0 if not step_toggle else 2
	var mid_frame = 1 if not step_toggle else 3
	var end_frame = 2 if not step_toggle else 0
	
	# Set initial frame manually (No .play()!)
	animations.animation = anim_name
	animations.frame = start_frame
	
	# 3. Move and Animate
	var tween = create_tween()
	# Use TRANS_LINEAR for that constant speed look
	tween.tween_property(self, "global_position", target_pos, 0.25).set_trans(Tween.TRANS_LINEAR)
	
	# Callback: Switch to "Mid Frame" exactly halfway through the step
	tween.parallel().tween_callback(func(): 
		animations.frame = mid_frame
	).set_delay(0.25 / 2.0)
	
	await tween.finished
	
	# 4. Finish Step
	animations.frame = end_frame
	step_toggle = !step_toggle # Flip the toggle for the next step
	
	# Record history
	position_history.push_front(global_position)
	if position_history.size() > 20: position_history.pop_back()
	
	is_moving = false

func get_anim_name(dir: Vector2) -> String:
	if dir.y > 0: return "walk_down"
	if dir.y < 0: return "walk_up"
	if dir.x > 0: return "walk_right"
	if dir.x < 0: return "walk_left"
	return "walk_down"

func get_breadcrumb(step_back: int) -> Vector2:
	if position_history.size() == 0: return global_position
	var index = min(step_back - 1, position_history.size() - 1)
	return position_history[index]
