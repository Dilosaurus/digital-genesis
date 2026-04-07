@tool
extends Resource
class_name DungeonVariant
## A DungeonVariant describes one combat arena configuration: which base
## dungeon scene to load, which decay overlay to composite on top, and which
## lighting preset to apply. The map generator picks a variant when placing a
## combat node, and the combat scene loads it on setup.
##
## Variants are .tres files under res://resources/dungeons/variants/ so they
## can be browsed and edited in the Godot editor.

## The base dungeon layout (walls, floor, pillars, torches).
## Must be a PackedScene whose root is Node3D.
@export var base_dungeon: PackedScene

## Optional decay overlay — rubble, broken props, hanging debris. Composited
## on top of the base dungeon as a child node. Leave null for pristine.
@export var decay_overlay: PackedScene

## Lighting preset string, consumed by combat_3d_stage.set_act_lighting().
## Accepted: "act1", "act2", "act3", "boss".
@export var lighting_preset: String = "act1"

## Whether this is a boss arena. Boss arenas skip decay overlays and use the
## "boss" lighting preset regardless of the lighting_preset field.
@export var is_boss_arena: bool = false

## Display name shown in debug logs / map tooltips.
@export var display_name: String = "Unknown Dungeon"
