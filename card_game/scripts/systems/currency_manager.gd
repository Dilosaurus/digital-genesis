class_name CurrencyManager
extends RefCounted

## Static utility class for managing the four run currencies.
## Operates on RunState — NOT an autoload.

enum Type {
	GOLD,
	SOULS,
	CRYSTALS,
	CORRUPTION_ESSENCE,
}

## Get the current balance of a currency.
static func get_balance(run: RunState, currency: Type) -> int:
	match currency:
		Type.GOLD:
			return run.gold
		Type.SOULS:
			return run.souls
		Type.CRYSTALS:
			return run.crystals
		Type.CORRUPTION_ESSENCE:
			return run.corruption_essence
	return 0

## Add currency. Returns the new balance.
static func add(run: RunState, currency: Type, amount: int) -> int:
	var new_balance := get_balance(run, currency) + amount
	_set_balance(run, currency, new_balance)
	EventBus.currency_changed.emit(currency, new_balance, amount)
	return new_balance

## Spend currency. Returns true if successful (had enough), false otherwise.
static func spend(run: RunState, currency: Type, amount: int) -> bool:
	var current := get_balance(run, currency)
	if current < amount:
		return false
	_set_balance(run, currency, current - amount)
	EventBus.currency_changed.emit(currency, current - amount, -amount)
	return true

## Check if player can afford a cost.
static func can_afford(run: RunState, currency: Type, amount: int) -> bool:
	return get_balance(run, currency) >= amount

## Get display name for a currency.
static func get_display_name(currency: Type) -> String:
	match currency:
		Type.GOLD: return "Gold"
		Type.SOULS: return "Souls"
		Type.CRYSTALS: return "Crystals"
		Type.CORRUPTION_ESSENCE: return "Corruption Essence"
	return "Unknown"

## Get the theme color for a currency (for UI rendering).
static func get_color(currency: Type) -> Color:
	match currency:
		Type.GOLD: return Color(1.00, 0.84, 0.0)
		Type.SOULS: return Color(0.70, 0.50, 1.00)
		Type.CRYSTALS: return Color(0.30, 0.85, 0.95)
		Type.CORRUPTION_ESSENCE: return Color(0.85, 0.20, 0.40)
	return Color.WHITE

## Get all balances as a dictionary.
static func get_all_balances(run: RunState) -> Dictionary:
	return {
		Type.GOLD: run.gold,
		Type.SOULS: run.souls,
		Type.CRYSTALS: run.crystals,
		Type.CORRUPTION_ESSENCE: run.corruption_essence,
	}

static func _set_balance(run: RunState, currency: Type, value: int) -> void:
	value = maxi(value, 0)  # Never go negative
	match currency:
		Type.GOLD:
			run.gold = value
		Type.SOULS:
			run.souls = value
		Type.CRYSTALS:
			run.crystals = value
		Type.CORRUPTION_ESSENCE:
			run.corruption_essence = value
