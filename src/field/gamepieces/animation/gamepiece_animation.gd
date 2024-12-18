@tool
## Encapsulates [Gamepiece] animation as an optional component.
##
## Allows [method play]ing animations that automatically adapt to the parent [Gamepiece]'s state.
## Transitions between animations are handled automatically, including changes to direction.
## [br][br][b]Note:[/b] Requires a [Gamepiece] as parent.
@icon("res://assets/editor/icons/GamepieceAnimation.svg")
class_name GamepieceAnimation extends Marker2D

## Name of the animation sequence used to reset animation properties to default. Note that this
## animation is only played for a single frame during animation transitions.
const RESET_SEQUENCE_KEY: = "RESET"

## Mapping that pairs cardinal [constant Directions.Points] with a [String] suffix.
const DIRECTION_SUFFIXES: = {
	Directions.Points.N: "_n",
	Directions.Points.E: "_e",
	Directions.Points.S: "_s",
	Directions.Points.W: "_w",
}

## The animation currently being played.
var current_sequence_id: = "":
	set = play

## The direction faced by the gamepiece.
## [br][br]Animations may optionally be direction-based. Setting the direction will use directional 
## animations if they are available; otherwise non-directional animations will be used.
var direction: = Directions.Points.S:
	set = set_direction

@onready var _anim: = $AnimationPlayer as AnimationPlayer
@onready var _collision_shape: = $Area2D/CollisionShape2D as CollisionShape2D

# At times the current 'graphics' (the visible element, at times abbreviated 'gfx') will move
# separately from the rest of the animation or gamepiece.
# For example, when travelling between cells, the gamepiece needs to move instantly so that the
# physics element of the gamepiece fully occupies it's current cell. The gfx will lag behind and
# appear to run to catch up to the cell.
@onready var _gfx: = $GFX as Marker2D


func _ready() -> void:
	if not Engine.is_editor_hint():
		var gamepiece = get_parent() as Gamepiece
		assert(gamepiece, "GamepieceAnimation expects gamepiece information exposed via signals."
			+ " Please only use GamepieceAnimation as a child of a Gamepiece for correct animation."
			+ " Current parent is named %s." % get_parent().name)
		
		# Collisions will find the Area2D node as the collider. We'll point its owner reference to
		# the gamepiece itself to allow easily identify colliding gamepieces.
		$Area2D.owner = gamepiece
		
		gamepiece.blocks_movement_changed.connect( \
			_on_gamepiece_blocks_movement_changed.bind(gamepiece))
		_on_gamepiece_blocks_movement_changed(gamepiece)
		
		gamepiece.arrived.connect(_on_gamepiece_arrived)
		gamepiece.direction_changed.connect(_on_gamepiece_direction_changed)
		gamepiece.travel_begun.connect(_on_gamepiece_travel_begun)
		
		# Need to wait one frame in the event that the parent gamepiece is not yet ready. We cannot
		# just wait for the ready signal since there is no guarantee that it will be emitted (for
		# example we may be swapping animation objects on an existing gamepiece).
		await get_tree().process_frame
		gamepiece.gfx_anchor.remote_path = gamepiece.gfx_anchor.get_path_to(_gfx)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not get_parent() is Gamepiece:
		warnings.append("GamepieceAnimation expects gamepiece information exposed via signals. "
			+ "Please only use GamepieceAnimation as a child of a Gamepiece for correct animation.")
	
	return warnings


## Change the currently playing animation to a new value, if it exists.
## [br][br]Animations may be added with or without a directional suffix (i.e. _n for north/up).
## Directional animations will be preferred with direction-less animations as a fallback.
func play(value: String) -> void:
	if value == current_sequence_id:
		return
	
	if not is_inside_tree():
		await ready
	
	# We need to check to see if the animation is valid.
	# First of all, look for a directional equivalent - e.g. idle_n. If that fails, look for 
	# the new sequence id itself.
	var sequence_suffix: String = DIRECTION_SUFFIXES.get(direction, "")
	if _anim.has_animation(value + sequence_suffix):
		current_sequence_id = value
		_swap_animation(value + sequence_suffix, false)
	
	elif _anim.has_animation(value):
		current_sequence_id = value
		_swap_animation(value, false)


## Change the animation's direction.
## If the currently running animation has a directional variant matching the new direction it will
## be played. Otherwise the direction-less animation will play.
func set_direction(value: Directions.Points) -> void:
	if value == direction:
		return
	
	direction = value
	
	if not is_inside_tree():
		await ready
	
	var sequence_suffix: String = DIRECTION_SUFFIXES.get(direction, "")
	if _anim.has_animation(current_sequence_id + sequence_suffix):
		_swap_animation(current_sequence_id + sequence_suffix, true)
	
	elif _anim.has_animation(current_sequence_id):
		_swap_animation(current_sequence_id, true)


func get_gfx_position() -> Vector2:
	return _gfx.position


# Transition to the next animation sequence, accounting for the RESET track and current animation
# elapsed time.
func _swap_animation(next_sequence: String, keep_position: bool) -> void:
	var next_anim = _anim.get_animation(next_sequence)
	
	if next_anim:
		# If keeping the current position, we want to do so as a ratio of the
		# position / animation length to account for animations of different length.
		var current_position_ratio = 0
		if keep_position:
			current_position_ratio = \
				_anim.current_animation_position / _anim.current_animation_length
		
		# RESET the animation immediately to its default reset state before the next sequence.
		# Take advantage of the default RESET animation to clear uncommon changes (i.e. flip_h).
		if _anim.has_animation(RESET_SEQUENCE_KEY):
			_anim.play(RESET_SEQUENCE_KEY)
			_anim.advance(0)
		
		_anim.play(next_sequence)
		_anim.advance(current_position_ratio * next_anim.length)


func _on_gamepiece_arrived() -> void:
	_gfx.position = Vector2(0, 0)
	
	play("idle")


func _on_gamepiece_direction_changed(new_direction: Vector2) -> void:
	# The line "is_equal_approx(Vector2.ZERO)" makes sure the new direction is not Vector2.ZERO
	if not new_direction.is_equal_approx(Vector2.ZERO):
		var direction_value: = Directions.angle_to_direction(new_direction.angle())
		set_direction(direction_value)


# Change the collision shape's color depending on whether or not it blocks pathfinding.
# Please turn on 'Visible Collision Shapes' under the editor's Debug menu to see which cells are
# occupied by gamepieces.
func _on_gamepiece_blocks_movement_changed(gamepiece: Gamepiece) -> void:
	if gamepiece.blocks_movement:
		_collision_shape.disabled = false
	
	else:
		_collision_shape.disabled = true


func _on_gamepiece_travel_begun():
	play("run")
