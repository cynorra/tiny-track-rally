class_name Progress


const LOGIN_REWARDS: = [60, 80, 100, 130, 160, 200, 300]
const MISSION_BONUS: = 30
const ACH_REWARD: = 50
const COIN_VALUE: = 2

const ACHIEVEMENTS: = [
	{"id": "first_race", "name": "First Laps", "desc": "Finish a race"}, 
	{"id": "first_win", "name": "Winner!", "desc": "Win a race"}, 
	{"id": "wins_10", "name": "Champion", "desc": "Win 10 races"}, 
	{"id": "cup1_all", "name": "Cup 1 Complete", "desc": "Earn a star on every Cup 1 track"}, 
	{"id": "cup2_unlock", "name": "Moving Up", "desc": "Unlock Cup 2"}, 
	{"id": "stars_30", "name": "Star Collector", "desc": "Earn 30 stars"}, 
	{"id": "coins_500", "name": "Pocket Money", "desc": "Pick up 500 coins on track"}, 
	{"id": "drift_5k", "name": "Drift King", "desc": "Score 5000 drift points"}, 
	{"id": "nitro_100", "name": "Nitro Junkie", "desc": "Use nitro 100 times"}, 
	{"id": "elim_win", "name": "Last One Standing", "desc": "Win an Elimination race"}, 
	{"id": "cp_clear", "name": "Beat the Clock", "desc": "Finish a Checkpoint run"}, 
	{"id": "tt_3star", "name": "Perfectionist", "desc": "Get 3 stars in Time Trial"}, 
	{"id": "night_win", "name": "Night Owl", "desc": "Win a night race"}, 
	{"id": "rain_win", "name": "Singing in the Rain", "desc": "Win a rain race"}, 
	{"id": "painter", "name": "Fresh Paint", "desc": "Buy a paint job"}, 
	{"id": "garage3", "name": "Collector", "desc": "Own 3 vehicles"}, 
	{"id": "streak_7", "name": "Loyal Racer", "desc": "Log in 7 days in a row"}, 
	{"id": "missions_20", "name": "On a Mission", "desc": "Complete 20 missions"}, 
]


static func _yesterday(today: String) -> String:
	var u: = Time.get_unix_time_from_datetime_string(today + "T12:00:00")
	return Time.get_date_string_from_unix_time(int(u) - 86400)


static func login_pending() -> Dictionary:
	var l: Dictionary = Game.data["login"]
	var today: = Game.today()
	if String(l.get("claimed", "")) == today: return {}
	var streak: = int(l.get("streak", 0))
	streak = streak + 1 if String(l.get("last", "")) == _yesterday(today) else 1
	return {"day": streak, "reward": LOGIN_REWARDS[min(streak, LOGIN_REWARDS.size()) - 1]}

static func claim_login() -> int:
	var p: = login_pending()
	if p.is_empty(): return 0
	var l: Dictionary = Game.data["login"]
	l["streak"] = p["day"];l["last"] = Game.today();l["claimed"] = Game.today()
	Game.data["coins"] = int(Game.data["coins"]) + int(p["reward"])
	if int(p["day"]) >= 7: unlock("streak_7")
	Game.save_game()
	return int(p["reward"])


static func ach_def(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a["id"] == id: return a
	return {}

static func has(id: String) -> bool: return Game.data["ach"].has(id)

static func unlock(id: String) -> bool:
	if has(id) or ach_def(id).is_empty(): return false
	Game.data["ach"][id] = Game.today()
	Game.data["coins"] = int(Game.data["coins"]) + ACH_REWARD
	Game.achievement_unlocked.emit(id)
	return true


static func check_all() -> Array:
	var got: Array = []
	var st: = func(k): return Game.stat(k)
	var conds: = {
		"first_race": st.call("races_done") >= 1, "first_win": st.call("wins") >= 1, "wins_10": st.call("wins") >= 10, 
		"stars_30": Game.total_stars() >= 30, "coins_500": st.call("coins_picked") >= 500, "drift_5k": st.call("drift") >= 5000, 
		"nitro_100": st.call("nitro_uses") >= 100, "elim_win": st.call("elim_wins") >= 1, "cp_clear": st.call("cp_clears") >= 1, 
		"night_win": st.call("night_wins") >= 1, "rain_win": st.call("rain_wins") >= 1, "painter": st.call("paints") >= 1, 
		"missions_20": st.call("missions") >= 20, "tt_3star": st.call("tt3") >= 1, 
		"garage3": _owned_count() >= 3, 
	}
	var cup1: = true
	for i in Game.TRACKS.size():
		if int(Game.TRACKS[i].get("cup", 1)) == 1 and int(Game.data["stars"].get(Game.TRACKS[i]["id"], 0)) < 1: cup1 = false
	conds["cup1_all"] = cup1
	conds["cup2_unlock"] = Game.track_unlocked(5)
	for id in conds.keys():
		if conds[id] and unlock(id): got.append(id)
	return got

static func _owned_count() -> int:
	var n: = 0
	for c in Game.CARS:
		if Game.car_owned(c["id"]): n += 1
	return n



static func pick_missions(mode: String, track: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	var racing: = mode in ["race", "daily", "elimination"]
	if racing: pool.append({"id": "top3", "text": "Finish in the top 3", "n": 3})
	if racing: pool.append({"id": "win", "text": "Win the race", "n": 1})
	pool.append({"id": "coins", "text": "Collect %d coins", "n": [8, 12, 16][rng.randi_range(0, 2)]})
	pool.append({"id": "drift", "text": "Score %d drift points", "n": [150, 300, 450][rng.randi_range(0, 2)]})
	pool.append({"id": "nitro", "text": "Use nitro %d times", "n": [2, 3, 4][rng.randi_range(0, 2)]})
	pool.append({"id": "pads", "text": "Hit %d boost pads", "n": [2, 3, 4][rng.randi_range(0, 2)]})
	pool.append({"id": "clean", "text": "Finish with %d or fewer wall hits", "n": [2, 4, 6][rng.randi_range(0, 2)]})
	pool.append({"id": "norespawn", "text": "Finish without a respawn", "n": 0})
	pool.append({"id": "speed", "text": "Reach %d km/h", "n": [70, 78, 85][rng.randi_range(0, 2)]})
	if mode in ["time_trial", "checkpoint"]:
		pool.append({"id": "time", "text": "Finish under %s", "n": int(Game.track_par(track) * 1.12)})

	for i in range(pool.size() - 1, 0, -1):
		var j: = rng.randi_range(0, i); var t = pool[i];pool[i] = pool[j];pool[j] = t
	var out: Array = []
	for m in pool:
		if out.size() >= 3: break
		if m["id"] == "win" and out.any( func(x): return x["id"] == "top3"): continue
		if m["id"] == "top3" and out.any( func(x): return x["id"] == "win"): continue
		out.append(m)
	return out

static func mission_text(m: Dictionary) -> String:
	var t: String = TranslationServer.translate(m["text"])
	if m["id"] == "time": return t % Race.fmt_time(float(m["n"]))
	return t % int(m["n"]) if t.contains("%d") else t

const LIVE_MISSIONS: = ["coins", "drift", "nitro", "pads", "speed"]

static func live_progress(m: Dictionary, s: Dictionary) -> Array:
	var n: = int(m["n"])
	match m["id"]:
		"coins": return [int(s["coins"]), n]
		"drift": return [int(s["drift"]), n]
		"nitro": return [int(s["nitro_uses"]), n]
		"pads": return [int(s["pads"]), n]
		"speed": return [int(float(s["max_kmh"])), n]
	return [0, 0]


static func evaluate(missions: Array, s: Dictionary, res: Dictionary) -> Array:
	var finished: bool = res.get("finished", true)
	for m in missions:
		var n: = int(m["n"])
		var ok: = false
		match m["id"]:
			"top3": ok = finished and int(res["position"]) <= 3
			"win": ok = finished and int(res["position"]) == 1
			"coins": ok = int(s["coins"]) >= n
			"drift": ok = int(s["drift"]) >= n
			"nitro": ok = int(s["nitro_uses"]) >= n
			"pads": ok = int(s["pads"]) >= n
			"clean": ok = finished and int(s["wall_hits"]) <= n
			"norespawn": ok = finished and int(s["respawns"]) == 0
			"speed": ok = float(s["max_kmh"]) >= n
			"time": ok = finished and float(res["time"]) <= n
		m["done"] = ok
	return missions
