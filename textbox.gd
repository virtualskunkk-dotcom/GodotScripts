extends CanvasLayer

# --- NODES ---
@onready var label = $Textbox/RichTextLabel
@onready var textbox_container = $Textbox
@onready var name_container = $Nametag
@onready var name_label = $Nametag/Label
@onready var thought_container = $ThoughtBox
@onready var thought_label = $ThoughtBox/RichTextLabel
@onready var portrait_sprite = $Portrait
@onready var background = $Textbox/background
@onready var thought_background = $ThoughtBox/background
@onready var choice_menu = $ChoiceMenu
@onready var choice_button_base = $Button 

# --- CONFIGURATION ---
var box_start_y = 0
var box_target_y = 0
var name_start_x = -200
var name_target_x = 200 
var thought_start_y = -200
var thought_target_y = 0
var typing_tween: Tween # This will "catch" the active text animation
var typing_speed = 0.03
var backspace_speed = 0.01 
var last_character = ""

# --- DATA ---
const PORTRAITS = {
	"Poppy": { "neutral": preload("res://UIScenes/UIAssets/MainUI/Portraits/poppybust_idle.png") },
	"Orion": { "neutral": preload("res://UIScenes/UIAssets/MainUI/Portraits/orionbust1.png") },
	"Roxy": { "neutral": preload("res://UIScenes/UIAssets/MainUI/Portraits/roxybust1.png") },
	"Rei": { "neutral": preload("res://UIScenes/UIAssets/MainUI/Portraits/reibust_idle.png") },
	"Juno_Masc": { "neutral": preload("res://UIScenes/UIAssets/MainUI/Portraits/dadbust_idle_grayscale.png") },
	"Juno_Fem": { "neutral": preload("res://UIScenes/UIAssets/MainUI/Portraits/junobust_idle_grayscale.png") }
}

const CHAR_COLORS = {
	"default": Color("292929"),
	"Poppy": Color("259c25"),
	"Orion": Color("026181"),
	"Roxy": Color("bc4e85"),
	"Rei": Color("b57500"),
	"White": Color("ababab")
}

const TEXTBOX_COLORS = {
	"default": Color(1.0, 1.0, 1.0, 1.0),
	"Poppy": Color("a4e0a4"),
	"Orion": Color("96e5ff"),
	"Roxy": Color("f5b5d5"),
	"Rei": Color("ffc966ff")
}

const TIME_COLORS = {
	"Day": Color(1, 1, 1, 1),
	"Night": Color(0.8, 0.8, 0.8, 1)
}

# --- STATE ---
enum State { HIDDEN, SLIDING_IN, TYPING, WAITING_FOR_INPUT, ERASING, SLIDING_OUT, THOUGHT_MODE, CHOICE_MODE }
signal dialogue_finished

var current_resource: DialogueResource 
var current_state = State.HIDDEN

func _ready():
	# Setup Initial Positions
	box_target_y = textbox_container.position.y
	box_start_y = box_target_y + 250
	textbox_container.position.y = box_start_y
	
	background.frame = 0
	thought_background.frame = 0

	name_target_x = name_container.position.x
	name_start_x = name_target_x - 200
	name_container.position.x = name_start_x
	
	thought_container.position.y = thought_start_y
	
	label.bbcode_enabled = true 
	label.text = ""
	
	# Ensure Nametag and Portrait are hidden at start
	name_container.visible = false
	portrait_sprite.visible = false

# --- ENTRY POINT ---
func show_dialogue(resource: DialogueResource, title: String):
	current_resource = resource
	var line = await DialogueManager.get_next_dialogue_line(resource, title)
	_process_dialogue_line(line)

# --- MAIN LOGIC ---
func _process_dialogue_line(line: DialogueLine):
	if not line:
		_slide_down()
		last_character = "" # Reset when done
		return

	# 1. Parse Tags
	var expression = "neutral"
	var is_thought = false
	for tag in line.tags:
		if tag == "thought": is_thought = true
		else: expression = tag

	# 2. CHARACTER SWITCH LOGIC
	# If the speaker changed, refresh UI
	if line.character != last_character and last_character != "":
		# Only animate out if a box is actually visible
		if textbox_container.position.y == box_target_y:
			await _animate_main_box_out()
		elif thought_container.position.y == thought_target_y:
			await _animate_thought_out()
	
	last_character = line.character

	# 3. Setup UI
	apply_style(line.character, "Day", expression)
	
	if not is_thought:
		# Hide immediately if starting a new animation sequence
		if textbox_container.position.y != box_target_y:
			portrait_sprite.visible = false 
			name_container.visible = false
		
		# Wait for thought bubble to leave if it was up
		if thought_container.position.y == thought_target_y:
			await _animate_thought_out()
			
		# Slide up if currently down
		if textbox_container.position.y != box_target_y:
			await _slide_up_logic()
		
		# Show visuals
		if portrait_sprite.texture != null:
			portrait_sprite.visible = true
		if line.character != "default":
			name_container.visible = true
			
		# Type text
		label.text = line.text
		label.visible_ratio = 0.0
		
		# Change 'var tween' to 'typing_tween'


		typing_tween = create_tween()
		current_state = State.TYPING
		typing_tween.tween_property(label, "visible_ratio", 1.0, line.text.length() * typing_speed)
		typing_tween.tween_callback(func(): current_state = State.WAITING_FOR_INPUT)
		
	else:
		# Handling Thoughts
		if textbox_container.position.y == box_target_y:
			await _animate_main_box_out()
			
		await _animate_thought_bubble(line.text)

	# 4. Wait for Player Input
	await self.dialogue_finished 
	
	# 5. Decide What Happens Next (Choices/Next/End)
	if line.responses.size() > 0:
		# Don't reset last_character here so it stays correct after choice
		if thought_container.position.y == thought_target_y:
			await _animate_thought_out()
		else:
			await _animate_main_box_out()
			
		_display_choices(line.responses)
		
	elif line.next_id != "" and line.next_id != "END":
		var next_line = await DialogueManager.get_next_dialogue_line(current_resource, line.next_id)
		_process_dialogue_line(next_line)
	else:
		_slide_down()
		last_character = ""
# --- CHOICE LOGIC ---
func _display_choices(responses: Array):
	current_state = State.CHOICE_MODE 

	# Clear old buttons
	for child in choice_menu.get_children():
		child.queue_free()
	
	# Re-add the columns logic if kept the GridContainer change
	if responses.size() > 2 and choice_menu is GridContainer:
		choice_menu.columns = 2
	elif choice_menu is GridContainer:
		choice_menu.columns = 1

	# Show Juno for the decision
	apply_style("Juno", "Day", "neutral")
	portrait_sprite.visible = true
	name_container.visible = true 
	
	var name_tween = create_tween()
	name_tween.tween_property(name_container, "position:x", name_target_x, 0.3).set_trans(Tween.TRANS_CUBIC)
	
	var stagger_delay = 0.0 
	
	for response in responses:
		var new_btn = choice_button_base.duplicate()
		new_btn.text = response.text
		new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_btn.custom_minimum_size.x = choice_menu.size.x / (2 if responses.size() > 2 else 1)
		# --- NEW COLOR LOGIC ---
		# 1. Reset to default
		new_btn.self_modulate = Color(1, 1, 1, 1)
		
		# 2. Check tags for character names
		for tag in response.tags:
			if CHAR_COLORS.has(tag):
				new_btn.self_modulate = TEXTBOX_COLORS[tag]

		choice_menu.add_child(new_btn)
		
		# Button Pop-in Animation
		new_btn.modulate.a = 0.0
		new_btn.scale.y = 0.0
		new_btn.show()
		
		await get_tree().process_frame
		new_btn.pivot_offset = new_btn.size / 2
		
		var tween = create_tween().set_parallel(true)
		tween.tween_property(new_btn, "modulate:a", 1.0, 0.2).set_delay(stagger_delay)
		tween.tween_property(new_btn, "scale:y", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(stagger_delay)
		
		stagger_delay += 0.1
		
		new_btn.pressed.connect(func(): _on_choice_selected(response.next_id))
	
	choice_menu.show()
	if choice_menu.get_child_count() > 0:
		choice_menu.get_child(0).grab_focus()

func _on_choice_selected(next_id: String):
	for child in choice_menu.get_children():
		if child is Button: child.disabled = true
			
	var tween = create_tween().set_parallel(true)
	tween.tween_property(choice_menu, "modulate:a", 0.0, 0.2)
	tween.tween_property(name_container, "position:x", name_start_x, 0.2).set_trans(Tween.TRANS_CUBIC)
	
	await tween.finished
	
	choice_menu.hide()
	choice_menu.modulate.a = 1.0 
	
	var line = await DialogueManager.get_next_dialogue_line(current_resource, next_id)
	_process_dialogue_line(line)

# --- ANIMATIONS ---
func _slide_up_logic():
	textbox_container.position.y = box_target_y + 60
	background.frame = 0
	
	name_container.position.x = name_target_x
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(textbox_container, "position:y", box_target_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	background.play("unfold")
	await background.animation_finished

func _animate_main_box_out():
	current_state = State.SLIDING_OUT
	portrait_sprite.visible = false
	
	background.play("unfold", -1.0, true)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(textbox_container, "position:y", box_start_y, 0.3).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(name_container, "position:x", name_start_x, 0.3)
	
	await tween.finished
	if background.is_playing():
		await background.animation_finished
	
	current_state = State.HIDDEN

func _animate_thought_bubble(thought_text: String):
	# Don't set State.TYPING yet! Let's call it State.SLIDING_IN (or just leave it)
	thought_label.text = thought_text
	thought_label.visible_ratio = 0.0
	
	thought_background.frame = 0
	thought_background.play("grow")
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(thought_container, "position:y", thought_target_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await thought_background.animation_finished
	
	# NOW we start typing
	current_state = State.TYPING
	typing_tween = create_tween()
	typing_tween.tween_property(thought_label, "visible_ratio", 1.0, thought_text.length() * typing_speed)
	typing_tween.tween_callback(func(): current_state = State.WAITING_FOR_INPUT)

func _animate_thought_out():
	current_state = State.SLIDING_OUT
	thought_background.play("grow", -1.0, true)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(thought_container, "position:y", thought_start_y, 0.3).set_trans(Tween.TRANS_CUBIC)
	
	await tween.finished
	if thought_background.is_playing():
		await thought_background.animation_finished
		
	current_state = State.HIDDEN

func _slide_down():
	if current_state == State.HIDDEN:
		return
		
	choice_menu.hide()
	
	if textbox_container.position.y == box_target_y:
		await _animate_main_box_out()
	if thought_container.position.y == thought_target_y:
		await _animate_thought_out()
		
	current_state = State.HIDDEN



# --- INPUT & STYLE ---
func _input(event):
	if event.is_action_pressed("ui_accept"):
		# Ignore input if hidden, sliding, or choosing
		if current_state in [State.HIDDEN, State.SLIDING_IN, State.SLIDING_OUT, State.CHOICE_MODE]:
			return
			
		get_viewport().set_input_as_handled() 
		
		match current_state:
			State.TYPING:
				# --- THE SKIP LOGIC ---
				if typing_tween and typing_tween.is_running():
					typing_tween.kill() # Stop the rolling animation
				
				# Determine which box is active and snap it to full
				var active_label = thought_label if thought_container.position.y == thought_target_y else label
				active_label.visible_ratio = 1.0
				
				current_state = State.WAITING_FOR_INPUT
				
			State.WAITING_FOR_INPUT:
				_erase_current_text()
				
			State.ERASING:
				# OPTIONAL: Press Enter again to skip the "backspace" effect
				# and jump straight to the next line.
				dialogue_finished.emit()

func _erase_current_text():
	var active_label = thought_label if thought_container.position.y == thought_target_y else label
	var tween = create_tween()
	var duration = active_label.text.length() * backspace_speed
	
	current_state = State.ERASING 
	
	tween.tween_property(active_label, "visible_ratio", 0.0, duration)
	tween.tween_callback(func():
		dialogue_finished.emit()
	)

func apply_style(character_name: String, time_of_day: String, emotion: String = "neutral"):
	var lookup_name = character_name
	if character_name == "Juno":
		lookup_name = "Juno_Masc" if Global.preferred_style == "masc" else "Juno_Fem"

	if PORTRAITS.has(lookup_name) and PORTRAITS[lookup_name].has(emotion):
		portrait_sprite.texture = PORTRAITS[lookup_name][emotion]
	else:
		portrait_sprite.texture = null

	if TIME_COLORS.has(time_of_day):
		var environment_tint = TIME_COLORS[time_of_day]
		portrait_sprite.modulate = environment_tint
		background.modulate = environment_tint
		name_container.get_node("TextureRect").modulate = environment_tint

	var char_color = CHAR_COLORS.get(character_name, CHAR_COLORS["default"])
	label.add_theme_color_override("default_color", char_color)
	name_label.add_theme_color_override("font_color", char_color)

	name_label.text = Global.player_name if character_name == "Juno" else character_name
