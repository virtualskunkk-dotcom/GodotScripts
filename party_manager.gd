extends Node

# --- CONFIGURATION ---
# Dictionary linking Names to their actual Scene files
const PARTY_SCENES = {
	"Poppy": preload("res://followers/poppyfollower.tscn"),
	"Orion": preload("res://followers/orionfollower.tscn"),
	"Roxy": preload("res://followers/roxyfollower.tscn"),
	"Rei": preload("res://followers/reifollower.tscn")
}

signal party_changed

# --- STATE ---
# This list determines WHO is following and in WHAT ORDER.
# Example: ["Poppy", "Orion", "Roxy"]
var active_party: Array[String] = ["Poppy", "Orion", "Roxy", "Rei"]

# Set this to FALSE during cutscenes if you don't want them appearing
var party_enabled: bool = true

# --- MANAGEMENT FUNCTIONS ---
func add_member(char_name: String):
	if char_name in PARTY_SCENES and not char_name in active_party:
		active_party.append(char_name)
		party_changed.emit()


func remove_member(char_name: String):
	if char_name in active_party:
		active_party.erase(char_name)
		party_changed.emit() # Shout to the world that the party changed!

func reorder_party(new_order: Array):
	# verify all names are valid before applying
	active_party = new_order

func swap_members(index1: int, index2: int):
	if index1 >= 0 and index1 < active_party.size() and index2 >= 0 and index2 < active_party.size():
		var temp = active_party[index1]
		active_party[index1] = active_party[index2]
		active_party[index2] = temp
