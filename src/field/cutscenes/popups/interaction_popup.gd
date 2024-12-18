@tool
## A [UIPopup] used specifically to mark [Interaction]s and other points of interest for the player.
##
## InteractionPopups may be added as children to a variety of objects. They respond to the player's
## physics layer and show up as an emote bubble when the player is nearby.
class_name InteractionPopup extends UIPopup

## The different emote types that may be selected.
enum EmoteTypes { COMBAT, EMPTY, EXCLAMATION, QUESTION}

## The emote textures that may appear over a point of interest.
const EMOTES: = {
	EmoteTypes.COMBAT: preload("res://assets/gui/emotes/emote_combat.png"),
	EmoteTypes.EMPTY: preload("res://assets/gui/emotes/emote__.png"),
	EmoteTypes.EXCLAMATION: preload("res://assets/gui/emotes/emote_exclamations.png"),
	EmoteTypes.QUESTION: preload("res://assets/gui/emotes/emote_question.png"),
}

## The emote bubble that will be displayed when the character is nearby.
@export var emote: = EmoteTypes.EMPTY:
	set(value):
		emote = value
		
		if not is_inside_tree():
			await ready
		
		_sprite.texture = EMOTES.get(emote, EMOTES[EmoteTypes.EMPTY])

## How close the player must be to the emote before it will display.
@export var radius: = 32:
	set(value):
		radius = value
		
		if not is_inside_tree():
			await ready
		
		_collision_shape.shape.radius = radius

## Is true if the InteractionPopup should respond to the player's presence. Otherwise, the popup
## will not be triggered.
@export var is_active: = true:
	set(value):
		is_active = value
		
		if not Engine.is_editor_hint():
			if not is_inside_tree():
				await ready
			
			_area.monitoring = is_active
			_collision_shape.disabled = !is_active

@onready var _area: = $Area2D as Area2D
@onready var _collision_shape: = $Area2D/CollisionShape2D as CollisionShape2D


func _ready() -> void:
	super._ready()
	
	if not Engine.is_editor_hint():
		FieldEvents.input_paused.connect(_on_input_paused)

## The areas are designed to ensure the player is
## 1. Inside the area, and
## 2. The necessary animations are loaded.
func _on_area_entered(_entered_area: Area2D) -> void:
	_is_shown = true


func _on_area_exited(_exited_area: Area2D) -> void:
	_is_shown = false


# Be sure to hide input when the player is not able to do anything (e.g. cutscenes).
func _on_input_paused(paused: bool) -> void:
	_area.monitoring = !paused
