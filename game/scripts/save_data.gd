extends RefCounted
## Local save: last player name + leaderboard of saved energy (best result per nickname).
## Stored as JSON in user:// (macOS: ~/Library/Application Support/Godot/app_userdata/Енергетична криза/).

const MAX_ENTRIES := 100

var path := "user://save.json"
var last_name := ""
var entries: Array = []   # [{name, score, floor, character, date}], sorted best first


func _init(file_path := "user://save.json") -> void:
	path = file_path
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return
	last_name = str(data.get("last_name", ""))
	var list = data.get("leaderboard", [])
	if typeof(list) == TYPE_ARRAY:
		entries = list.filter(func(e): return typeof(e) == TYPE_DICTIONARY and e.has("name") and e.has("score"))
	_sort()


func save_data() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write save file %s" % path)
		return
	f.store_string(JSON.stringify({"last_name": last_name, "leaderboard": entries}, "  "))
	f.close()


func set_last_name(n: String) -> void:
	last_name = n
	save_data()


## Records a result; keeps only the best score per nickname (case-insensitive).
## Returns the player's 1-based position in the table.
func submit(player: String, score: float, floor_reached: int, character: String) -> int:
	score = snappedf(maxf(score, 0.0), 0.1)
	var key := player.strip_edges().to_lower()
	var found: Dictionary = {}
	for e in entries:
		if str(e["name"]).strip_edges().to_lower() == key:
			found = e
			break
	var stamp := Time.get_datetime_string_from_system(false, true)
	if found.is_empty():
		entries.append({"name": player, "score": score, "floor": floor_reached, "character": character, "date": stamp})
	elif score > float(found["score"]):
		found["name"] = player
		found["score"] = score
		found["floor"] = floor_reached
		found["character"] = character
		found["date"] = stamp
	_sort()
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	save_data()
	return rank_of(player)


func rank_of(player: String) -> int:
	var key := player.strip_edges().to_lower()
	for i in entries.size():
		if str(entries[i]["name"]).strip_edges().to_lower() == key:
			return i + 1
	return 0


func best_of(player: String) -> float:
	var r := rank_of(player)
	return float(entries[r - 1]["score"]) if r > 0 else 0.0


func top(n: int) -> Array:
	return entries.slice(0, n)


func _sort() -> void:
	entries.sort_custom(func(a, b):
		if float(a["score"]) != float(b["score"]):
			return float(a["score"]) > float(b["score"])
		return str(a.get("date", "")) < str(b.get("date", "")))
