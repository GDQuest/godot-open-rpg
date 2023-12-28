@tool

@icon("res://assets/editor/icons/Contact.svg")
class_name Trigger extends Cutscene

## Emitted when a [Gamepiece] begins moving to the cell occupied by the [code]Trigger[/code].
signal gamepiece_entered(gamepiece: Gamepiece)

## Emitted when a [Gamepiece] begins moving away from the cell occupied by the [code]Trigger[/code].
signal gamepiece_exited(gamepiece: Gamepiece)

## Emitted when a [Gamepiece] is finishing moving to the cell occupied by the [code]Trigger[/code].
signal triggered(gamepiece: Gamepiece)

## An active [code]Trigger[/code] may be run, whereas one that is inactive may only be run
## directly through code via the [method Cutscene.run] method.
@export var is_active: = true:
	set(value):
		is_active = value
		
		if not Engine.is_editor_hint():
			if not is_inside_tree():
				await ready
			
			# We use "Visible Collision Shapes" to debug positions on the gameboard, so we'll want 
			# to change the state of child collision shapes.These could be either CollisionShape2Ds
			# or CollisionPolygon2Ds.
			# Note that we only want to disable the collision shapes of objects that are actually
			# connected to this Interaction.
			for data in get_incoming_connections():
				var callable: = data["callable"] as Callable
				if callable == _on_area_entered :
					var connected_area: = data["signal"].get_object() as Area2D
					if connected_area:
						for node in connected_area.find_children("*", "CollisionShape2D"):
							(node as CollisionShape2D).disabled = !is_active
						for node in connected_area.find_children("*", "CollisionPolygon2D"):
							(node as CollisionPolygon2D).disabled = !is_active


func _ready() -> void:
	if not Engine.is_editor_hint():
		FieldEvents.input_paused.connect(_on_input_paused)


# Ensure that something is connected to _on_area_entered, which the Trigger requires.
# If nothing is connected, issue a configuration warning.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var has_area_entered_bindings: = false
	
	for data in get_incoming_connections():
		if data["callable"] == _on_area_entered:
			has_area_entered_bindings = true
	
	if not has_area_entered_bindings:
		warnings.append("This object does not have a CollisionObject2D's signals connected to " + 
			"this Trigger's _on_area_entered method. The Trigger will never be triggered!")
	return warnings


# Pause any collision objects that would normally send signals regarding interactions.
# This will automatically accept or ignore currently overlapping areas.
func _on_input_paused(is_paused: bool) -> void:
	for data in get_incoming_connections():
		# Note that we only want to check _on_area_entered, since _on_area_exited will clean up any
		# lingering references once the Area2Ds are 'shut off' (i.e. not monitoring/monitorable).
		if data["callable"] == _on_area_entered:
			var connected_area: = data["signal"].get_object() as Area2D
			if connected_area:
				connected_area.monitoring = !is_paused
				connected_area.monitorable = !is_paused


func _on_area_entered(area: Area2D) -> void:
	var gamepiece: = area.owner as Gamepiece
	if gamepiece:
		gamepiece_entered.emit(gamepiece)
		
		# Check to make sure that the gamepiece is moving before connecting to its 'arriving'
		# signal. This catches edge cases where the Trigger is unpaused while a colliding object
		# is standing on top of it (which would mean that _on_gamepiece_arrived would trigger once
		# the gamepiece moves OFF of it. Which is bad.).
		if gamepiece.is_moving():
			gamepiece.arriving.connect(_on_gamepiece_arrived.bind(gamepiece), CONNECT_ONE_SHOT)


func _on_area_exited(area: Area2D) -> void:
	var gamepiece: = area.owner as Gamepiece
	if gamepiece:
		gamepiece_exited.emit(gamepiece)


func _on_gamepiece_arrived(_distance: float, gamepiece: Gamepiece) -> void:
	triggered.emit(gamepiece)
	run()
