extends RefCounted
## Local save: last player name + leaderboard of saved energy (best result per nickname) + whether the first
## floor's lessons have been done + the progress: best stars of each floor (they open the characters), the energy
## bank and the upgrades bought with it, the highest floor passed (endless record), the floor the player stopped on
## (the start screen continues from it) and the day the controls were last shown through.
## Stored as JSON in user:// (macOS: ~/Library/Application Support/Godot/app_userdata/Енергетична криза/).
## On CrazyGames it is also kept in the site's data store (SDK.data): a signed-in player gets it on any device.

const MAX_ENTRIES := 100

var path := "user://save.json"
var last_name := ""
var entries: Array = []   # [{name, score, floor, character, date}], sorted best first
var tutorial_done := false
var stars := {}           # floor number (as text) -> best stars on it (1..3)
var bank := 0.0           # energy saved and not spent yet, Wh
var upgrades := {}        # upgrade id -> level (0..3)
var best_floor := 0       # highest floor passed
var next_floor := 0       # floor (index from 0) the player continues from: the one they reached; Restart game -> 0
var controls_day := ""    # the day (YYYY-MM-DD) the controls hint was last done: shown again on a new day
var cloud := false        # also keep it in CrazyGames' data store

const CLOUD_KEY := "ec_save"


func _init(file_path := "user://save.json", use_cloud := false) -> void:
	path = file_path
	cloud = use_cloud and OS.has_feature("web")
	load_data()


func load_data() -> void:
	var text := ""
	if cloud:   # CrazyGames: the site's copy first (the same player on another device)
		var c = JavaScriptBridge.eval("(function(){try{return window.CrazyGames.SDK.data.getItem('%s')||''}catch(e){return ''}})()" % CLOUD_KEY, true)
		text = c if c is String else ""
	if text == "" and FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	if text == "":
		return
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	last_name = str(data.get("last_name", ""))
	tutorial_done = bool(data.get("tutorial_done", false))
	var st = data.get("stars", {})
	stars = st if typeof(st) == TYPE_DICTIONARY else {}
	bank = maxf(float(data.get("bank", 0.0)), 0.0)
	var up = data.get("upgrades", {})
	upgrades = up if typeof(up) == TYPE_DICTIONARY else {}
	best_floor = int(data.get("best_floor", 0))
	next_floor = maxi(int(data.get("next_floor", 0)), 0)   # older saves have none: start from floor 1
	controls_day = str(data.get("controls_day", ""))
	var list = data.get("leaderboard", [])
	if typeof(list) == TYPE_ARRAY:
		entries = list.filter(func(e): return typeof(e) == TYPE_DICTIONARY and e.has("name") and e.has("score"))
	_sort()


func save_data() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write save file %s" % path)
		return
	var text := JSON.stringify({"last_name": last_name, "tutorial_done": tutorial_done, "stars": stars, "bank": bank,
			"upgrades": upgrades, "best_floor": best_floor, "next_floor": next_floor, "controls_day": controls_day,
			"leaderboard": entries}, "  ")
	f.store_string(text)
	f.close()
	if cloud:
		JavaScriptBridge.eval("try{window.CrazyGames.SDK.data.setItem('%s', %s)}catch(e){}" % [CLOUD_KEY, JSON.stringify(text)], true)


func set_last_name(n: String) -> void:
	last_name = n
	save_data()


func set_tutorial_done() -> void:
	tutorial_done = true
	save_data()


## The floor (index from 0) the start screen continues from.
func set_next_floor(idx: int) -> void:
	if next_floor != idx:
		next_floor = maxi(idx, 0)
		save_data()


## The controls hint is done for `day` (YYYY-MM-DD): the next time it is shown is on another day.
func set_controls_day(day: String) -> void:
	controls_day = day
	save_data()


## A passed floor (number from 1) with `n` stars: keeps the best; returns how many stars the total grew by.
func record_floor(floor_num: int, n: int) -> int:
	best_floor = maxi(best_floor, floor_num)
	var key := str(floor_num)
	var before := int(stars.get(key, 0))
	if n > before:
		stars[key] = n
	save_data()
	return maxi(n - before, 0)


## Stars of floors 1..`floors` (the main building; the endless floors give no stars).
func total_stars(floors := 10) -> int:
	var n := 0
	for i in floors:
		n += int(stars.get(str(i + 1), 0))
	return n


func add_bank(wh: float) -> void:
	bank += maxf(wh, 0.0)
	save_data()


func level(id: String) -> int:
	return int(upgrades.get(id, 0))


## Buy the next level of an upgrade if the bank has enough: true when bought.
func buy(id: String, cost: float) -> bool:
	if bank + 0.001 < cost:
		return false
	bank -= cost
	upgrades[id] = level(id) + 1
	save_data()
	return true


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
