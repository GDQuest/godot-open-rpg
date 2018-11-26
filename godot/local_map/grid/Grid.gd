extends TileMap

enum CELL_TYPES {EMPTY = -1, ACTOR, OBSTACLE, OBJECT}

onready var pawns = get_node("Pawns")

func _ready():
	for child in pawns.get_children():
		child.position = request_move(child, Vector2(0, 0))
		set_cellv(world_to_map(child.position), child.type)

func get_cell_pawn(coordinates):
	for node in pawns.get_children():
		if world_to_map(node.position) == coordinates:
			return(node)

func request_move(pawn, direction):
	var cell_start = world_to_map(pawn.position)
	var cell_target = cell_start + direction
	
	var cell_target_type = get_cellv(cell_target)
	match cell_target_type:
		CELL_TYPES.EMPTY:
			return update_pawn_position(pawn, cell_start, cell_target)
		CELL_TYPES.OBJECT:
			var object_pawn = get_cell_pawn(cell_target)
		
			if object_pawn.has_node("Dialogue"):
				var dialogue = object_pawn.get_node("Dialogue").load()
				get_parent().emit_signal("dialogue", dialogue)
				
			object_pawn.queue_free()
			return update_pawn_position(pawn, cell_start, cell_target)
		CELL_TYPES.ACTOR:
			var enemy = get_cell_pawn(cell_target)
			get_parent().emit_signal("encounter" , enemy.formation.instance())

func update_pawn_position(pawn, cell_start, cell_target):
	set_cellv(cell_target, pawn.type)
	set_cellv(cell_start, CELL_TYPES.EMPTY)
	return map_to_world(cell_target) + cell_size / 2
