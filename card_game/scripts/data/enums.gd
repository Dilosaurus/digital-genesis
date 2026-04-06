class_name Enums

enum CardType { ATTACK, SKILL, POWER, STATUS, CURSE }
enum SinType { WRATH, SLOTH, PRIDE }
enum TargetType { ENEMY, SELF, ALL_ENEMIES, ALL_PLAYERS, NONE, ALLY }
enum EnemyIntent { ATTACK, DEFEND, BUFF, DEBUFF, UNKNOWN, HACK }
enum CombatPhase { WAITING_FOR_PLAYERS, PLAYER_TURN, RESOLVING, ENEMY_TURN, COMBAT_OVER }

# --- Modifier system enums ---

enum Stat {
	DAMAGE,
	BLOCK,
	HEALING,
	MAX_HP,
	MAX_ENERGY,
	DRAW_PER_TURN,
	ENERGY_COST,
	CORRUPTION_GAIN,
	CORRUPTION_RESIST,
	MANA_REGEN,
}

enum ModOp {
	FLAT_ADD,       # +5 damage. Applied first.
	PERCENT_ADD,    # +25% damage. All stack additively, then multiply once.
	PERCENT_MULT,   # x1.5 damage. Each multiplies independently. Applied last.
	OVERRIDE,       # Sets the value directly. Highest override wins.
}

enum ModLifecycle {
	PERMANENT,      # Equipment, skill tree — lasts the whole run
	COMBAT,         # Applied at combat start, removed at combat end
	TURN,           # Ticks down each turn, removed at 0
	CARD_PLAY,      # Active only while resolving a card (gem effects)
	CONDITIONAL,    # Always present but only applies when conditions met
}

enum CardTag {
	MELEE,
	RANGED,
	FIRE,
	ICE,
	HOLY,
	SHADOW,
	TECH,
	EXPLOIT,
	CURSE,
	PIRACY,
}

enum EquipSlot {
	HEAD,
	CHEST,
	WEAPON,
	ACCESSORY,
}

enum CharacterClass { NETRUNNER, SYSADMIN, CRYPTOMANCER, WHITE_HAT, TECHNOMANCER, SCOURGE }

enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }
