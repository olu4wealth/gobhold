extends Node
## Gobhold save system: 3 slots + global settings. ConfigFile-backed.
## Slot file: user://gobhold_slot0..2.cfg ("meta", "progress" sections).

const SLOT_FMT := "user://gobhold_slot%d.cfg"
const SETTINGS_PATH := "user://gobhold_settings.cfg"
const SLOT_COUNT := 3

# In-memory run routing (never persisted): progression -> level/build/combat.
var active_slot := -1
var active_level := ""
var pending_layout := []
var pending_gold := 400
var pending_score := 0
var pending_kills := 0


func fresh_data() -> Dictionary:
	return {
		"meta": {"resources": {"shards": 0, "crystals": 0, "diamonds": 0}, "shards": 0,
			"lifetime": 0, "last": "", "current_level": "T", "tree": {"core": 1}, "tut": false},
		"progress": {"unlocked": [], "layouts": {}, "best": {}},
	}


func slot_exists(i: int) -> bool:
	return FileAccess.file_exists(SLOT_FMT % i)


func load_slot(i: int) -> Dictionary:
	var data := fresh_data()
	var cfg := ConfigFile.new()
	if cfg.load(SLOT_FMT % i) != OK:
		return data
	var meta: Dictionary = data["meta"]
	var old_shards := int(cfg.get_value("meta", "shards", 0))
	var resources := _as_dict(cfg.get_value("meta", "resources", {}))
	if resources.is_empty():
		resources = {"shards": old_shards, "crystals": 0, "diamonds": 0}
	if not resources.has("diamonds"):
		resources["diamonds"] = int(resources.get("sparks", 0))
	resources.erase("sparks")
	meta["resources"] = resources
	meta["shards"] = int(resources.get("shards", old_shards))
	meta["lifetime"] = int(cfg.get_value("meta", "lifetime", 0))
	meta["last"] = String(cfg.get_value("meta", "last", ""))
	meta["current_level"] = String(cfg.get_value("meta", "current_level", "T"))
	meta["tree"] = _as_dict(cfg.get_value("meta", "tree", {"core": 1}))
	if not meta["tree"].has("core"):
		meta["tree"]["core"] = 1
	meta["tut"] = bool(cfg.get_value("meta", "tut", false))
	var prog: Dictionary = data["progress"]
	prog["unlocked"] = _as_array(cfg.get_value("progress", "unlocked", []))
	prog["layouts"] = _as_dict(cfg.get_value("progress", "layouts", {}))
	prog["best"] = _as_dict(cfg.get_value("progress", "best", {}))
	return data


func write_slot(i: int, data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	var meta: Dictionary = data.get("meta", {})
	var prog: Dictionary = data.get("progress", {})
	var resources: Dictionary = meta.get("resources", {"shards": int(meta.get("shards", 0)), "crystals": 0, "diamonds": 0})
	resources["shards"] = int(resources.get("shards", meta.get("shards", 0)))
	resources["crystals"] = int(resources.get("crystals", 0))
	resources["diamonds"] = int(resources.get("diamonds", resources.get("sparks", 0)))
	resources.erase("sparks")
	cfg.set_value("meta", "resources", resources)
	cfg.set_value("meta", "shards", int(resources.get("shards", 0)))
	cfg.set_value("meta", "lifetime", int(meta.get("lifetime", 0)))
	cfg.set_value("meta", "last", String(meta.get("last", "")))
	cfg.set_value("meta", "current_level", String(meta.get("current_level", "T")))
	cfg.set_value("meta", "tree", meta.get("tree", {}))
	cfg.set_value("meta", "tut", bool(meta.get("tut", false)))
	cfg.set_value("progress", "unlocked", prog.get("unlocked", []))
	cfg.set_value("progress", "layouts", prog.get("layouts", {}))
	cfg.set_value("progress", "best", prog.get("best", {}))
	cfg.save(SLOT_FMT % i)


func delete_slot(i: int) -> void:
	if slot_exists(i):
		DirAccess.remove_absolute(SLOT_FMT % i)


func summary(i: int) -> Dictionary:
	if not slot_exists(i):
		return {"exists": false}
	var data := load_slot(i)
	var unlocked: Array = (data["progress"] as Dictionary).get("unlocked", [])
	var meta: Dictionary = data["meta"]
	var resources: Dictionary = meta.get("resources", {})
	return {
		"exists": true,
		"level": String(meta.get("current_level", "T")),
		"shards": int(resources.get("shards", meta.get("shards", 0))),
		"crystals": int(resources.get("crystals", 0)),
		"diamonds": int(resources.get("diamonds", 0)),
		"lifetime": int(meta.get("lifetime", 0)),
		"last": String(meta.get("last", "—")),
		"levels": unlocked.size(),
		"top": unlocked.back() if not unlocked.is_empty() else "-",
	}


func stamp() -> String:
	return Time.get_datetime_string_from_system(false, true).replace("T", " ")


func get_setting(key: String, fallback: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return fallback
	return cfg.get_value("settings", key, fallback)


func set_setting(key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("settings", key, value)
	cfg.save(SETTINGS_PATH)


func _as_dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


func _as_array(v: Variant) -> Array:
	return v if v is Array else []
