extends Node

const SAVE_PATH = "user://lore.json"

var _intro_seen: bool = false
var _unlocked_entries: Dictionary = {}  # category -> Array[String]

func _ready() -> void:
	_load()

func has_seen_intro() -> bool:
	return _intro_seen

func mark_intro_seen() -> void:
	_intro_seen = true
	_save()

func unlock_entry(category: String, entry_id: String) -> void:
	if not _unlocked_entries.has(category):
		_unlocked_entries[category] = []
	if entry_id not in _unlocked_entries[category]:
		_unlocked_entries[category].append(entry_id)
		_save()

func is_unlocked(category: String, entry_id: String) -> bool:
	return _unlocked_entries.has(category) and entry_id in _unlocked_entries[category]

func get_unlocked(category: String) -> Array:
	return _unlocked_entries.get(category, [])

func _save() -> void:
	var data = {
		"intro_seen": _intro_seen,
		"unlocked": _unlocked_entries,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_intro_seen = parsed.get("intro_seen", false)
		_unlocked_entries = parsed.get("unlocked", {})
