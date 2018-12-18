extends Node2D

class_name CombatArena

const BattlerNode = preload("res://combat/battlers/Battler.tscn")

onready var turn_queue : TurnQueue = $TurnQueue
onready var interface = $CombatInterface
onready var rewards = $Rewards

var active : bool = false
var party : Array = []
var initial_formation : Formation

# sent when the battler is starting to end (before battle_ended)
signal battle_ends
# sent when battle is completed, contains status updates for the party
# so that we may persist the data
signal battle_ended(party)
signal victory
signal gameover

func initialize(formation : Formation, party : Array):
	initial_formation = formation
	ready_field(formation, party)
		
	# reparent the enemy battlers into the turn queue
	var battlers = turn_queue.get_battlers()
	for battler in battlers:
		battler.initialize()
		
	interface.initialize(self, turn_queue, battlers)
	rewards.initialize(battlers)
	turn_queue.initialize()
	
func battle_start():
	yield(play_intro(), "completed")
	active = true
	play_turn()

func play_intro():
	# Play the appear animation on all battlers in cascade
	for battler in turn_queue.get_party():
		battler.appear()
#		yield(get_tree().create_timer(0.15), "timeout")
	yield(get_tree().create_timer(0.5), "timeout")
	for battler in turn_queue.get_monsters():
		battler.appear()
#		yield(get_tree().create_timer(0.15), "timeout")
	yield(get_tree().create_timer(0.5), "timeout")

func ready_field(formation : Formation, party_members : Array):
	"""
	use a formation as a factory for the scene's content
	@param formation - the combat template of what the player will be fighting
	@param party_members - list of active party battlers that will go to combat
	"""
	var spawn_positions = $SpawnPositions/Monsters
	for enemy in formation.get_children():
	 	# spawn a platform where the enemy is supposed to stand
		var platform = formation.platform_template.instance()
		platform.position = enemy.position
		spawn_positions.add_child(platform)
		var combatant = enemy.duplicate()
		turn_queue.add_child(combatant)
		combatant.stats.reset() # enemies need to start with full health
		
	var party_spawn_positions = $SpawnPositions/Party
	for i in len(party_members):
		# TODO move this into a battler factory and pass already copied info into the scene
		var party_member = party_members[i]
		var platform = formation.platform_template.instance()
		var spawn_point = party_spawn_positions.get_child(i)
		platform.position = spawn_point.position
		var combatant = party_member.ready_for_combat() as Battler
		combatant.position = spawn_point.position
		combatant.name = party_member.name
		# stats are copied from the external party member so we may restart combat cleanly,
		# such as allowing players to retry a fight if they get game over
		spawn_point.replace_by(platform)
		turn_queue.add_child(combatant)
		self.party.append(combatant)
		# safely attach the interface to the AI in case player input is needed
		combatant.ai.set("interface", interface)

func battle_end():
	emit_signal("battle_ends")
	active = false
	var active_battler = get_active_battler()
	active_battler.selected = false
	var player_won = active_battler.party_member
	if player_won:
		emit_signal("victory")
		yield(rewards.on_battle_completed(), "completed")
		emit_signal("battle_ended", self.party)
	else:
		emit_signal("gameover")

func play_turn():
	var battler : Battler = get_active_battler()
	var targets : Array
	var action : CombatAction

	while not battler.is_able_to_play():
		turn_queue.skip_turn()
		battler = get_active_battler()

	battler.selected = true
	var opponents : Array = get_targets()
	if not opponents:
		battle_end()
		return

	action = yield(battler.ai.choose_action(battler, opponents), "completed")
	targets = yield(battler.ai.choose_target(battler, action, opponents), "completed")
	battler.selected = false
	
	if targets != []:
		yield(turn_queue.play_turn(action, targets), "completed")
	if active:
		play_turn()

func get_active_battler() -> Battler:
	return turn_queue.active_battler

func get_targets() -> Array:
	if get_active_battler().party_member:
		return turn_queue.get_monsters()
	else:
		return turn_queue.get_party()
