class_name ManaSystem
extends RefCounted

## Calculates effective mana regen for a player, running through modifier stack.
static func get_effective_regen(player: PlayerState) -> int:
	var base = player.mana_regen
	return int(player.modifier_stack.resolve(Enums.Stat.MANA_REGEN, float(base), {}))

## Calculates effective max mana for a player, running through modifier stack.
static func get_effective_max_mana(player: PlayerState) -> int:
	return int(player.modifier_stack.resolve(Enums.Stat.MAX_ENERGY, float(player.max_energy), {}))

## Regenerates mana for a player (called at start of turn).
## Returns the actual amount of mana gained.
static func regen(player: PlayerState) -> int:
	var regen_amount = get_effective_regen(player)
	var max_mana = get_effective_max_mana(player)
	var old_energy = player.energy
	player.energy = mini(player.energy + regen_amount, max_mana)
	return player.energy - old_energy

## Checks if player can afford a card's mana cost.
static func can_afford(player: PlayerState, cost: int) -> bool:
	return player.energy >= cost
