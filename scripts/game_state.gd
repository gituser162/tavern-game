extends Node
## Autoload "GameState": all game rules live here. The UI only calls these methods.

signal changed
signal logged(text: String)

enum Phase { MARKET, SERVICE, EVENING, GAME_OVER }

const GameData := preload("res://scripts/game_data.gd")
const Wallet := preload("res://scripts/wallet.gd")
const Storage := preload("res://scripts/storage.gd")
const Portraits := preload("res://scripts/portraits.gd")

var day: int = 1
var wallet := Wallet.new()
var reputation: int = 0
var prosperity: int = GameData.START_PROSPERITY
var phase: Phase = Phase.MARKET
var storage := Storage.new()
## Contracts on the board today: {id, title, tier, diff, reward, days, loot, desc}.
var quest_board: Array[Dictionary] = []
## Contracts heroes are doing now: board entry + {hero_id, hero, chance, item, return_day}.
var active_quests: Array[Dictionary] = []
## All heroes of the town: {id, name, class, stats {stat: n}, status "free"/"quest"/"injured",
## injured_until (day), quest (title), done (contracts finished)}.
var heroes: Array[Dictionary] = []
var _next_hero_id: int = 1
var customers_today: Array[Dictionary] = []
var current_customer: Dictionary = {}
var customer_index: int = 0
var awaiting_quest: bool = false
## Sale tray in front of the visitor: shelf pieces [{"uid", "id"}] (they stay in storage until sold),
## the price step (-1 = -10%, 0 = normal, +1 = +10%) and whether +10% was already tried with this visitor.
var deal: Array[Dictionary] = []
var deal_step: int = 0
var deal_raise_tried: bool = false
var day_stats: Dictionary = {}
## Personal actions the keeper has left today (trips to locations spend them).
var actions_left: int = GameData.ACTIONS_PER_DAY
## Result of the last trip today: {"location": id, "found": {item: n}, "left": {item: n}, "event": id}. Empty = no trip yet.
var last_trip: Dictionary = {}
## The location the keeper is in right now: {"location": id, "event": event id or "",
## "nodes": [{"item": id, "spot": Vector2 (bg pixels), "taken": bool, "gone": bool, "timed": bool}],
## "found": {item: n}, "grave": "" / "closed" / "searched"}. Empty = in the tavern.
## A "timed" node vanishes ("gone") if it is not picked up in time (see expire_node).
var trip: Dictionary = {}
## Locations closed until the end of the day (the keeper was driven out by an event).
var closed_locations: Array[String] = []
## Locations already visited today: every location can be visited only once a day.
var visited_locations: Array[String] = []
## Result of the last brewing today: {"item": potion id, "ok": bool}. Empty = nothing brewed yet.
var last_brew: Dictionary = {}
## Rank the log last told about, and the highest rank reached this game (its unlocks are told only once).
var _announced_rank: int = 0
var _best_rank: int = 0
## True once the keeper went to the market today (the visit costs an action, then the market stays open all morning).
var market_visited: bool = false
## What was bought on the market today: {item: n}.
var bought_today: Dictionary = {}
var won: bool = false
## Today's morning event: "" / "tax" / "fair" (see GameData.TAX_COLLECTOR, GameData.FAIR).
var town_event: String = ""
## Text about today's morning event for the morning screen ("" = none).
var town_event_text: String = ""
## Day each morning event happened last ({"tax": day, "fair": day}), for the cooldowns.
var _event_last_day: Dictionary = {}
## Brawl in the hall today: the visitor number it happens before (-1 = no brawl today).
var brawl_at: int = -1
## True while the brawl is waiting for the keeper's decision (resolve_brawl).
var brawl_active: bool = false
## Mugs left in the ale keg on the counter today.
var keg_left: int = 0
## Tavern upgrades bought from the carpenter: upgrade id -> level (missing = 0). See GameData.UPGRADES.
var upgrades: Dictionary = {}
## Result of the last cooking in the kitchen (for the kitchen window): {"item", "ok", "amount"}.
var last_cook: Dictionary = {}
## Lines of the event log of this game (kept so the ledger is the same after loading a save).
var log_lines: Array[String] = []
## Reputation with the other factions (GameData.FACTIONS): {"state": n, "crime": n}. Містяни ("people") = `reputation`.
var faction_rep: Dictionary = {}
## How closely the guard watches the tavern, 0..GameData.SUSPICION_MAX (100 = the keeper is arrested).
var suspicion: int = 0
## Suspicion level (GameData.SUSPICION_LEVELS index) the log last told about.
var _announced_susp: int = 0
## True once the keeper has met the fence: from then on criminal orders appear on the contract board.
var crime_known: bool = false
## The fence stays away until this day (he was reported to the guard).
var fence_away_until: int = 0
## The smuggler's sealed crate kept in the tavern: {"due": day he takes it back, "pay": gold}. {} = none.
var smuggle_job: Dictionary = {}
## Potion recipes the keeper has found (GameData.START_RECIPES + experiments). Dishes are all known.
var known_recipes: Array = []
## Best quality reached per potion / dish id (for the recipe book).
var recipe_best: Dictionary = {}
## How the next game screen starts: "new" = new game, "load" = from the save file (set by the main menu).
var start_mode: String = "new"


func new_game() -> void:
	day = 1
	wallet = Wallet.new()
	wallet.add(GameData.START_MONEY)
	reputation = GameData.START_REPUTATION
	_announced_rank = GameData.rep_rank_index(reputation)
	_best_rank = _announced_rank
	prosperity = GameData.START_PROSPERITY
	won = false
	upgrades = {}
	apply_upgrades()
	_reset_factions()
	smuggle_job = {}
	known_recipes = GameData.START_RECIPES.duplicate()
	recipe_best = {}
	storage = Storage.new()
	for id in GameData.START_ITEMS:
		for i in GameData.START_ITEMS[id]:
			storage.add(id)
	active_quests.clear()
	heroes.clear()
	_event_last_day = {}
	_next_hero_id = 1
	log_lines.clear()
	_log("[b]Ти отримав у спадок таверну «Втомлений Грифон».[/b] Борг гільдії: %s до кінця %d-го дня." % [Wallet.format_amount(GameData.GOAL_MONEY, true), GameData.LAST_DAY])
	_start_morning()


# ---------- Reputation ----------

func rep_rank() -> Dictionary:
	return GameData.rep_rank(reputation)


func max_heroes() -> int:
	return rep_rank()["max_heroes"] + int(upgrade_value("rooms", "heroes"))


## True if the reputation is high enough for this contract / hero class / recipe / upgrade entry
## ("rep" = reputation among the townsfolk, "need" = {faction: value} for the other factions).
func is_unlocked(entry: Dictionary) -> bool:
	if reputation < GameData.rep_needed(entry):
		return false
	var need: Dictionary = entry.get("need", {})
	for f in need:
		if faction_value(f) < int(need[f]):
			return false
	return true


## What is still missing for an entry, e.g. "Потрібна репутація 25 («Шанована таверна»)" ("" = nothing).
func need_text(entry: Dictionary) -> String:
	var parts: PackedStringArray = []
	var rep := GameData.rep_needed(entry)
	if reputation < rep:
		parts.append("репутація %d («%s»)" % [rep, GameData.rep_rank_name(rep)])
	var need: Dictionary = entry.get("need", {})
	for f in need:
		if faction_value(f) < int(need[f]):
			parts.append("%s %d («%s»)" % [GameData.FACTIONS[f]["name"], int(need[f]), GameData.faction_rank(f, int(need[f]))[1]])
	return "" if parts.is_empty() else "Потрібно: " + ", ".join(parts)


## Ids of the entries of a table (CONTRACTS, HERO_CLASSES, RECIPES) open at the current reputation.
func unlocked_ids(table: Dictionary) -> Array:
	var result: Array = []
	for id in table:
		if is_unlocked(table[id]):
			result.append(id)
	return result


## Reputation still missing for the next rank (0 if the rank is the highest).
func rep_to_next_rank() -> int:
	var i := GameData.rep_rank_index(reputation)
	if i + 1 >= GameData.REP_RANKS.size():
		return 0
	return GameData.REP_RANKS[i + 1]["min"] - reputation


# ---------- Factions and suspicion ----------

func _reset_factions() -> void:
	faction_rep = {}
	for f in GameData.FACTIONS:
		if f != "people":
			faction_rep[f] = int(GameData.FACTIONS[f]["start"])
	suspicion = 0
	_announced_susp = 0
	crime_known = false
	fence_away_until = 0


## Reputation with a faction: "people" (the old reputation), "state" or "crime".
func faction_value(f: String) -> int:
	if f == "people":
		return reputation
	return int(faction_rep.get(f, GameData.FACTIONS[f].get("start", 0)))


## Changes the reputation with a faction. A gain also changes the other factions by their "spill" share
## (GDD 14.6: helping the magistrate angers the underworld and the other way round).
## Returns a short text for the log, e.g. "Магістрат +4, Тіньова гільдія −1".
func change_faction(f: String, delta: int, spill: bool = true) -> String:
	if delta == 0:
		return ""
	var note := "%s %+d" % [GameData.FACTIONS[f]["name"], delta]
	if f == "people":
		_change_rep(delta)
	else:
		var data: Dictionary = GameData.FACTIONS[f]
		faction_rep[f] = clampi(faction_value(f) + delta, int(data["min"]), int(data["max"]))
		day_stats[f] = int(day_stats.get(f, 0)) + delta
	if spill and delta > 0:
		# The spill only cools a friendship down to neutral: it never makes an enemy by itself.
		var shares: Dictionary = GameData.FACTIONS[f]["spill"]
		for other in shares:
			var d := maxi(roundi(delta * float(shares[other])), -maxi(0, faction_value(other)))
			if d != 0:
				note += ", " + change_faction(other, d, false)
	return note


func suspicion_level() -> Array:
	return GameData.suspicion_level(suspicion)


## True during the official investigation (the second-highest suspicion level).
func investigation() -> bool:
	return suspicion >= GameData.SUSPICION_LEVELS[3][0]


## Changes the suspicion and tells the log when it crosses a level.
func change_suspicion(delta: int) -> void:
	if delta == 0:
		return
	suspicion = clampi(suspicion + delta, 0, GameData.SUSPICION_MAX)
	day_stats["susp"] = int(day_stats.get("susp", 0)) + delta
	var level := GameData.suspicion_level_index(suspicion)
	if level == _announced_susp:
		return
	var data: Array = GameData.SUSPICION_LEVELS[level]
	if level > _announced_susp:
		Audio.play("rank_down", 1.3)
		if level < GameData.SUSPICION_LEVELS.size() - 1:
			_log("[color=#%s][b]Підозра варти: «%s».[/b] %s[/color]" % [data[3], data[1], data[2]])
	else:
		_log("[color=#%s]Підозра варти спала: «%s».[/color]" % [data[3], data[1]])
	_announced_susp = level


## Suspicion that fades every night (by the state reputation).
func suspicion_decay() -> int:
	return int(GameData.pick_by(GameData.SUSPICION_DECAY, faction_value("state"))[1])


## Arrest at the highest suspicion. True if the game is over.
func _check_arrest() -> bool:
	if suspicion < GameData.SUSPICION_MAX or phase == Phase.GAME_OVER:
		return false
	Audio.play("defeat")
	_game_over(false, "Варта вибиває двері таверни: підозр зібралося надто багато. Власника «Втомленого Грифона» арештовано.")
	return true


## Ids (uids) of the stolen pieces in storage.
func stolen_uids() -> Array[int]:
	var result: Array[int] = []
	for uid in storage.origins:
		if String(storage.origins[uid].get("k", "")) == "stolen" and storage.id_of_uid(int(uid)) != "":
			result.append(int(uid))
	return result


func is_stolen(uid: int) -> bool:
	return String(storage.origin_of(uid).get("k", "")) == "stolen"


## Chance that a visitor recognises a stolen piece when it is sold (crime reputation and the stash help).
func stolen_witness_chance() -> float:
	var chance := float(GameData.pick_by(GameData.STOLEN_WITNESS, faction_value("crime"))[1])
	return chance * float(upgrade_value("stash", "witness"))


## Morning guard inspection: stolen goods are taken away and fined.
func _inspection() -> void:
	var data: Dictionary = GameData.INSPECTION
	_event_last_day["inspection"] = day
	town_event = "inspection"
	Audio.play("tax", 0.6)
	var stolen := stolen_uids()
	var hide := float(upgrade_value("stash", "hide"))
	var found: Array[int] = []
	for uid in stolen:
		if randf() >= hide:
			found.append(uid)
	var crate_note := ""
	if not smuggle_job.is_empty():
		if randf() >= hide:
			crate_note = _lose_smuggle_crate()
		else:
			stolen.append(-1)  # only for the "(схованка не підвела)" note
	if found.is_empty() and crate_note == "":
		change_suspicion(GameData.SUSP_INSPECTION_CLEAN)
		var note := change_faction("state", int(data["state_clean"]))
		town_event_text = "Зранку прийшла варта з перевіркою. Нічого підозрілого не знайшли%s. Підозра %d, %s." % [
			" (схованка не підвела)" if not stolen.is_empty() else "", GameData.SUSP_INSPECTION_CLEAN, note]
		_log("[color=#a8d08d][b]%s.[/b] %s[/color]" % [data["name"], town_event_text])
		return
	var counts := {}
	for uid in found:
		var id := storage.id_of_uid(uid)
		storage.take_uid(uid)
		counts[id] = int(counts.get(id, 0)) + 1
	if found.is_empty():
		town_event_text = "Зранку прийшла варта з перевіркою. " + crate_note
		_log("[color=#e0904a][b]%s.[/b] %s[/color]" % [data["name"], town_event_text])
		return
	var fine := found.size() * int(data["fine"]) * (2 if investigation() else 1)
	fine = mini(fine, maxi(0, wallet.total))
	wallet.add(-fine)
	day_stats["fine"] = int(day_stats.get("fine", 0)) + fine
	change_suspicion(GameData.SUSP_INSPECTION_FOUND)
	change_faction("state", int(data["state_found"]))
	town_event_text = "Зранку прийшла варта з перевіркою і знайшла крадене: %s. Усе забрали, штраф %s. Підозра +%d, магістрат %d." % [
		_items_text(counts), Wallet.format_amount(fine, true), GameData.SUSP_INSPECTION_FOUND, int(data["state_found"])]
	if crate_note != "":
		town_event_text += " " + crate_note
	_log("[color=#e0904a][b]%s.[/b] %s[/color]" % [data["name"], town_event_text])


## Price of a bribe to the guard captain now.
func bribe_cost() -> int:
	return int(GameData.BRIBE["base"]) + roundi(suspicion * float(GameData.BRIBE["per_point"]))


## Why the keeper cannot bribe the guard now ("" = can).
func bribe_problem() -> String:
	if phase != Phase.MARKET:
		return "Казарма приймає лише зранку."
	if suspicion <= 0:
		return "Варта тебе й так не підозрює."
	if "barracks" in visited_locations:
		return "Сьогодні ти вже був у казармі."
	if not has_actions(int(GameData.BRIBE["action_cost"])):
		return "Не лишилося дій."
	if wallet.total < bribe_cost():
		return "Бракує золота: треба %s." % Wallet.format_amount(bribe_cost(), true)
	return ""


## Bribes the guard captain: suspicion goes down (during an investigation he may refuse and get angry).
func bribe() -> void:
	if bribe_problem() != "":
		return
	var b: Dictionary = GameData.BRIBE
	var cost := bribe_cost()
	spend_actions(int(b["action_cost"]))
	visited_locations.append("barracks")
	if investigation() and randf() < float(b["refuse_chance"]):
		Audio.play("angry")
		change_suspicion(int(b["refused"]))
		_log("[color=salmon]Капітан варти відштовхує гаманець: «Розслідування вже йде, і ти мені щойно допоміг». Підозра +%d.[/color]" % int(b["refused"]))
	else:
		wallet.add(-cost)
		day_stats["spent"] = int(day_stats.get("spent", 0)) + cost
		Audio.play("coin")
		change_suspicion(-int(b["drop"]))
		change_faction("state", int(b["state"]), false)
		_log("Ти заносиш капітанові варти гаманець (%s). Він обіцяє, що його люди дивитимуться в інший бік. Підозра −%d, магістрат %d." % [Wallet.format_amount(cost, true), int(b["drop"]), int(b["state"])])
	changed.emit()


# ---------- The fence (shady deals) ----------

## [lowest crime rep, chance he comes today, price share] for the current crime reputation.
func _fence_terms() -> Array:
	return GameData.pick_by(GameData.FENCE["by_rep"], faction_value("crime"))


func _fence_comes_today() -> bool:
	if day < int(GameData.FENCE["from_day"]) or day < fence_away_until:
		return false
	return randf() < float(_fence_terms()[1])


func _make_fence() -> Dictionary:
	var face := Portraits.pick("fence")
	var gender: String = face.get("gender", "")
	if gender == "":
		gender = "m"
	var crime := faction_value("crime")
	var total := 0
	for id in GameData.FENCE_LOTS:
		if crime >= int(GameData.FENCE_LOTS[id][3]):
			total += int(GameData.FENCE_LOTS[id][0])
	var roll := randi_range(1, maxi(1, total))
	var item := "wine"
	for id in GameData.FENCE_LOTS:
		var lot: Array = GameData.FENCE_LOTS[id]
		if crime < int(lot[3]):
			continue
		roll -= int(lot[0])
		if roll <= 0:
			item = id
			break
	var lot: Array = GameData.FENCE_LOTS[item]
	var n := randi_range(int(lot[1]), int(lot[2]))
	# The price is a share of the market price (things the market does not sell: 80% of the sale price).
	var base := item_cost(item)
	if base <= 0:
		base = roundi(item_price(item) * 0.8)
	var price := maxi(1, roundi(base * n * float(_fence_terms()[2])))
	return {"type": "fence", "title": "Скупниця" if gender == "f" else GameData.CUSTOMER_TYPES["fence"]["title"], "name": random_name(gender),
		"portrait": face.get("path", ""), "tolerance": 0.0, "tag": "", "wants": [], "purse": 0,
		"lot": {"item": item, "n": n, "price": price}}


func fence_here() -> bool:
	return phase == Phase.SERVICE and not brawl_active and current_customer.get("type", "") == "fence"


## The fence's offer {"item", "n", "price"} ({} if he is not at the counter).
func fence_lot() -> Dictionary:
	return current_customer.get("lot", {}) if fence_here() else {}


## Why the fence's lot cannot be bought ("" = it can).
func fence_problem() -> String:
	var lot := fence_lot()
	if lot.is_empty():
		return "Скупника немає."
	if wallet.total < int(lot["price"]):
		return "Бракує золота: треба %s." % Wallet.format_amount(int(lot["price"]), true)
	if not storage.can_fit(lot["item"], int(lot["n"])):
		return "На полицях немає місця."
	return ""


## Buys the fence's lot: cheap, but stolen.
func fence_buy() -> void:
	if not fence_here() or fence_problem() != "":
		return
	var lot := fence_lot()
	var price := int(lot["price"])
	var n := int(lot["n"])
	wallet.add(-price)
	day_stats["spent"] = int(day_stats.get("spent", 0)) + price
	for i in n:
		storage.add(lot["item"], {"c": roundi(float(price) / n), "k": "stolen"})
	Audio.play("buy")
	var crime_rep := int(GameData.FENCE["crime_rep"])
	var note := change_faction("crime", crime_rep)
	change_suspicion(GameData.SUSP_FENCE_DEAL)
	var text := "Ти купуєш у скупника «%s» ×%d за %s. Крадене, звісно. %s, підозра +%d." % [GameData.ITEMS[lot["item"]]["name"], n, Wallet.format_amount(price, true), note, GameData.SUSP_FENCE_DEAL]
	if randf() < stolen_witness_chance():
		change_suspicion(GameData.SUSP_WITNESS)
		text += " [color=salmon]Хтось у залі бачив, як ви тиснули руки. Підозра ще +%d.[/color]" % GameData.SUSP_WITNESS
	_log("[color=#c08ae0]%s[/color]" % text)
	if not crime_known:
		crime_known = true
		_log("[color=#c08ae0][b]Тепер ти знаєш людей тіньової гільдії.[/b] Відсьогодні на дошці з'являтимуться злочинні замовлення (темні листки).[/color]")
	_after_customer()


## True if storage has something of this category an ordinary visitor would buy (not the fence's side potions).
func has_sellable(cat: String) -> bool:
	for id in storage.ids_in_category(cat):
		if not GameData.ITEMS[id].get("fence_only", false):
			return true
	return false


## Side-effect potions in storage the fence would buy: {item: count}.
func fence_side_stock() -> Dictionary:
	var stock := {}
	for id in GameData.FENCE_BUYS:
		if storage.count(id) > 0:
			stock[id] = storage.count(id)
	return stock


## What the fence pays for all of them.
func fence_side_value() -> int:
	var total := 0
	var stock := fence_side_stock()
	for id in stock:
		total += int(GameData.FENCE_BUYS[id]) * int(stock[id])
	return total


## Sells all side-effect potions to the fence (he stays at the counter with his own lot).
func fence_sell_side() -> void:
	if not fence_here() or fence_side_stock().is_empty():
		return
	var stock := fence_side_stock()
	var total := fence_side_value()
	for id in stock:
		for i in int(stock[id]):
			storage.take(id)
	wallet.add(total)
	day_stats["income"] += total
	var d: Dictionary = GameData.FENCE_BUY_DEAL
	var note := change_faction("crime", int(d["crime"]))
	change_suspicion(int(d["susp"]))
	Audio.play("coin")
	_log("[color=#c08ae0]Скупник ховає під плащ %s і відраховує %s. «Знайду, кому підлити.» %s, підозра +%d.[/color]" % [
		_items_text(stock), Wallet.format_amount(total, true), note, int(d["susp"])])
	changed.emit()


## Sends the fence away without a deal.
func fence_refuse() -> void:
	if not fence_here():
		return
	Audio.play("refuse")
	_log("Ти відмовляєш скупникові. Він знизує плечима і зникає в тіні.")
	_after_customer()


## Reports the fence to the guard: the magistrate likes it, the underworld does not forget.
func fence_report() -> void:
	if not fence_here():
		return
	var f: Dictionary = GameData.FENCE
	Audio.play("contract")
	var note := change_faction("state", int(f["report_state"]), false)
	change_faction("crime", int(f["report_crime"]), false)
	change_suspicion(GameData.SUSP_REPORT_FENCE)
	fence_away_until = day + int(f["report_days"])
	_log("[color=#7fa8e0]Ти киваєш вартовому біля дверей, і скупника виводять під руки. %s, Тіньова гільдія %d, підозра %d. Кілька днів скупник не з'явиться.[/color]" % [
		note, int(f["report_crime"]), GameData.SUSP_REPORT_FENCE])
	_after_customer()


# ---------- Prices ----------

## Sale price of an item today (before the haggling choice). Depends on city prosperity.
func item_price(item_id: String) -> int:
	return maxi(1, roundi(GameData.ITEMS[item_id]["price"] * GameData.prosperity_mult(prosperity)))


## Market price today. -1 if the item cannot be bought.
func item_cost(item_id: String) -> int:
	var cost: int = GameData.ITEMS[item_id]["cost"]
	if cost <= 0:
		return -1
	var mult := GameData.prosperity_mult(prosperity)
	if town_event == "fair":
		mult *= GameData.FAIR["market_mult"]
	return maxi(1, roundi(cost * mult))


# ---------- Town events (morning) ----------

func _event_ready(id: String, data: Dictionary) -> bool:
	if day < int(data.get("from_day", 1)):
		return false
	if _event_last_day.has(id) and day - int(_event_last_day[id]) < int(data.get("cooldown", 0)):
		return false
	return true


## Share of the gold the tax collector takes: by the state reputation (+5% during an investigation).
func tax_rate() -> float:
	var rate := float(GameData.pick_by(GameData.TAX_COLLECTOR["rates"], faction_value("state"))[1])
	return rate + (0.05 if investigation() else 0.0)


## At most one morning event a day: the tax collector or the town fair.
func _roll_town_event() -> void:
	town_event = ""
	town_event_text = ""
	var tax: Dictionary = GameData.TAX_COLLECTOR
	var fair: Dictionary = GameData.FAIR
	var insp: Dictionary = GameData.INSPECTION
	var insp_chance := 0.0
	if investigation():
		insp_chance = float(insp["chance_investigation"])
	elif suspicion >= GameData.SUSPICION_LEVELS[2][0]:
		insp_chance = float(insp["chance"])
	if not smuggle_job.is_empty():
		# The smuggler's crate in the tavern: customs men are about, the guard may come even if the town is calm.
		insp_chance = maxf(insp_chance, float(GameData.SMUGGLER["job"]["inspect_chance"]))
	if insp_chance > 0.0 and _event_ready("inspection", insp) and randf() < insp_chance:
		_inspection()
	elif _event_ready("tax", tax) and randf() < tax["chance"]:
		_event_last_day["tax"] = day
		town_event = "tax"
		Audio.play("tax", 0.6)
		var rate := tax_rate()
		var amount := maxi(0, floori(wallet.total * rate))
		wallet.add(-amount)
		day_stats["tax"] = amount
		town_event_text = "Зранку прийшов збирач податків і забрав %d%% золота: %s." % [roundi(rate * 100), Wallet.format_amount(amount, true)]
		if investigation():
			town_event_text += " Поки йде розслідування, податок на 5% більший."
		elif faction_value("state") < 60:
			town_event_text += " Що більше тобі довіряє магістрат, то менший податок."
		change_faction("state", GameData.STATE_REP_FOR_TAX)
		town_event_text += " Магістрат +%d." % GameData.STATE_REP_FOR_TAX
		_log("[color=orange][b]%s.[/b] %s[/color]" % [tax["name"], town_event_text])
	elif _event_ready("fair", fair) and randf() < fair["chance"]:
		_event_last_day["fair"] = day
		town_event = "fair"
		Audio.play("fair", 0.6)
		town_event_text = "Сьогодні в місті ярмарок! Ціни на ринку −%d%%, а ввечері в таверну зайде на %d гостей більше." % [roundi((1.0 - fair["market_mult"]) * 100), fair["extra_customers"]]
		_log("[color=lime][b]%s![/b] %s[/color]" % [fair["name"], town_event_text])


# ---------- Morning / market ----------

func _start_morning() -> void:
	phase = Phase.MARKET
	actions_left = GameData.ACTIONS_PER_DAY
	last_trip = {}
	trip = {}
	closed_locations.clear()
	visited_locations.clear()
	last_brew = {}
	market_visited = false
	bought_today = {}
	keg_left = keg_mugs()
	last_cook = {}
	day_stats = {"income": 0, "spent": 0, "sales": 0, "refused": 0, "quest_income": 0, "trips": 0, "gathered": 0, "brewed": 0, "tax": 0,
			"sold": {}, "cat_income": {}, "missed": {}, "missed_gold": 0, "susp": 0, "state": 0, "crime": 0, "fine": 0}
	brawl_at = -1
	brawl_active = false
	_log("\n[color=gold]— День %d —[/color]" % day)
	_heal_heroes()
	_resolve_returning_quests()
	_collect_rent()
	if suspicion >= GameData.SUSPICION_LEVELS[1][0]:
		_change_rep(-1)
		_log("[color=#e0c84a]Містом ходять чутки, що в «Грифоні» не все чисто. Репутація серед містян −1.[/color]")
	_announce_rank()
	_roll_town_event()
	_resolve_smuggling()
	if _check_arrest():
		return
	_generate_quest_board()
	changed.emit()
	if Settings.autosave:
		save_game()


## True if the keeper can open the market now (already there today, or has an action to go there).
func can_visit_market() -> bool:
	return phase == Phase.MARKET and (market_visited or has_actions(GameData.MARKET_ACTION_COST))


## Goes to the market. The first visit of the day spends MARKET_ACTION_COST actions,
## after that the market stays open until the tavern opens. Returns true if the keeper is at the market.
func visit_market() -> bool:
	if phase != Phase.MARKET:
		return false
	if market_visited:
		return true
	if not has_actions(GameData.MARKET_ACTION_COST):
		return false
	spend_actions(GameData.MARKET_ACTION_COST)
	market_visited = true
	Audio.play("door")
	_log("Ти йдеш на міський ринок.")
	changed.emit()
	return true


## Total price of an order {item: n} at today's market prices.
func order_cost(order: Dictionary) -> int:
	var total := 0
	for id in order:
		total += item_cost(id) * int(order[id])
	return total


## How many cells an order needs in all (any item lies on any shelf).
func order_cells(order: Dictionary) -> int:
	var n := 0
	for id in order:
		var sz := GameData.item_size(id)
		n += int(order[id]) * sz.x * sz.y
	return n


## Why this order cannot be bought right now ("" = it can).
func order_problem(order: Dictionary) -> String:
	if phase != Phase.MARKET:
		return "Ринок працює лише зранку."
	if not market_visited:
		return "Спершу треба піти на ринок."
	var pieces := 0
	for id in order:
		if not GameData.is_buyable(id):
			return "«%s» на ринку не продається." % GameData.ITEMS[id]["name"]
		pieces += int(order[id])
	if pieces <= 0:
		return "Кошик порожній."
	if not storage.can_fit_order(order):
		return "На полицях усе це не влізе: вільно %d клітинок." % storage.free_total()
	if not wallet.can_afford(order_cost(order)):
		return "Не вистачає грошей."
	return ""


## Buys a whole order {item: n} at once and puts everything into storage. Nothing is bought if anything does not fit.
func buy_order(order: Dictionary) -> bool:
	if order_problem(order) != "":
		return false
	var cost := order_cost(order)
	wallet.spend(cost)
	var bought := {}
	for id in order:
		for i in int(order[id]):
			storage.add(id, {"c": item_cost(id), "k": "buy"})
		if int(order[id]) > 0:
			bought[id] = int(order[id])
			bought_today[id] = bought_today.get(id, 0) + int(order[id])
	day_stats["spent"] += cost
	Audio.play("buy")
	_log("Ринок: куплено %s за %s." % [_items_text(bought), Wallet.format_amount(cost, true)])
	changed.emit()
	return true


## The keeper moves a piece on a shelf (puzzle storage). Returns false if it does not fit there.
func move_piece(place_id: String, uid: int, level: int, x: int, y: int, turned: bool = false) -> bool:
	if not storage.move(place_id, uid, level, x, y, turned):
		return false
	changed.emit()
	return true


## Lays a shelf out tightly, biggest things first. Returns false if it could not.
func tidy_storage(place_id: String) -> bool:
	if not storage.tidy(place_id):
		return false
	changed.emit()
	return true


## Buys one piece (a shortcut for buy_order). Goes to the market first if needed.
func buy(item_id: String) -> void:
	if visit_market():
		buy_order({item_id: 1})


# ---------- Alchemy ----------

## How many of an ingredient are missing for one brew of this recipe (0 = enough).
func missing_ingredient(potion_id: String, ingredient_id: String) -> int:
	var need: int = GameData.RECIPES[potion_id]["ingredients"][ingredient_id]
	return maxi(0, need - storage.count(ingredient_id))


func can_brew(potion_id: String) -> bool:
	if phase != Phase.MARKET or not GameData.RECIPES.has(potion_id) or not recipe_open(GameData.RECIPES[potion_id]) \
			or not recipe_known(potion_id):
		return false
	var recipe: Dictionary = GameData.RECIPES[potion_id]
	for ing in recipe["ingredients"]:
		if missing_ingredient(potion_id, ing) > 0:
			return false
	return true


## Brews a potion: takes the ingredients from storage and puts the potion into storage. Costs no actions.
## If the potion does not fit even after the ingredients are taken out, nothing changes.
## quality: GameData.QUALITY of the brew (-1 = none, e.g. the balance bot); boils: how many times it boiled over
## (GameData.SPOIL_BOILS or more = spoiled: one GameData.SPOILED_POTION instead).
func brew(potion_id: String, quality: int = -1, boils: int = 0) -> void:
	if not can_brew(potion_id):
		return
	var recipe: Dictionary = GameData.RECIPES[potion_id]
	var spoiled := boils >= GameData.SPOIL_BOILS
	var out := GameData.SPOILED_POTION if spoiled else potion_id
	var amount: int = 1 if spoiled else recipe.get("amount", 1)
	var potion_name: String = GameData.ITEMS[potion_id]["name"]
	if not _craft(recipe["ingredients"], out, amount, -1 if spoiled else quality):
		last_brew = {"item": out, "ok": false}
		Audio.play("error")
		_log("[color=salmon]Зварити «%s» не вийде: на полицях немає місця.[/color]" % GameData.ITEMS[out]["name"])
		changed.emit()
		return
	if spoiled:
		day_stats["brewed"] += 1
		last_brew = {"item": out, "ok": true, "spoiled": potion_id}
		Audio.play("fail")
		_log("[color=#c08ae0]«%s» википіло %d рази й зіпсувалося: вийшов «%s». Звичайний гість таке не купить, хіба скупник.[/color]" % [potion_name, boils, GameData.ITEMS[out]["name"]])
		changed.emit()
		return
	# The alchemy station upgrade: sometimes the same ingredients give one more potion (if it fits).
	var bonus := 0
	if randf() < float(upgrade_value("alchemy", "double")) and storage.add(potion_id, _piece_origin(0, quality)):
		bonus = 1
	day_stats["brewed"] += amount + bonus
	_note_quality(potion_id, quality)
	last_brew = {"item": potion_id, "ok": true, "bonus": bonus, "q": quality}
	Audio.play("brew")
	_log("Ти вариш «%s» (%s). Готово: %d шт.%s" % [potion_name, _items_text(recipe["ingredients"]), amount + bonus, quality_note(quality)]
		+ (" [color=#a8d08d]Алхімічна станція подвоїла зілля![/color]" if bonus > 0 else ""))
	changed.emit()


## Takes `ingredients` {item: n} from storage and puts `amount` pieces of `out` (with this quality) into it.
## The ingredients' cost is shared out between the pieces. False (and nothing changes) if they do not fit.
func _craft(ingredients: Dictionary, out: String, amount: int, quality: int) -> bool:
	var backup := storage.snapshot()
	var spent := 0
	for ing in ingredients:
		for i in int(ingredients[ing]):
			spent += int(storage.take_piece(ing).get("c", 0))
	for i in amount:
		var share := spent / amount + (1 if i < spent % amount else 0)
		if not storage.add(out, _piece_origin(share, quality)):
			storage.restore(backup)
			return false
	return true


func _piece_origin(cost: int, quality: int) -> Dictionary:
	var origin := {"c": cost, "k": "craft"}
	if quality >= 0:
		origin["q"] = quality
	return origin


func _note_quality(id: String, quality: int) -> void:
	if quality >= 0 and quality > int(recipe_best.get(id, -1)):
		recipe_best[id] = quality


## " Якість: Добра (+10%)." for the log ("" without a quality).
func quality_note(quality: int) -> String:
	if quality < 0:
		return ""
	var tier := GameData.quality_tier(quality)
	var pct := roundi((float(tier[2]) - 1.0) * 100)
	return " Якість: [color=#%s]%s[/color]%s." % [tier[3], tier[1], " (%+d%% до ціни)" % pct if pct != 0 else ""]


## Quality 0..100 from what the station measured: order (0..1 share of the ingredients put in the recipe's order),
## precision (0..1 share of the heating near the middle of the green zone), boils (boil-overs / burns).
func craft_quality(order: float, precision: float, boils: int, prep: float = 1.0) -> int:
	var q: Dictionary = GameData.QUALITY
	var total := float(q["base"]) + float(upgrade_value("tools", "quality")) + order * float(q["order"]) + precision * float(q["precision"]) + prep * float(q["prep"])
	total += float(q["clean"]) if boils == 0 else -float(q["spoil"]) * boils
	return clampi(roundi(total), 0, 100)


# ---------- Recipe book, experiments ----------

## True if the keeper knows this recipe (potions: found or known from the start; dishes: always).
func recipe_known(id: String) -> bool:
	if GameData.KITCHEN_RECIPES.has(id):
		return true
	return id in known_recipes


## A potion recipe is "rumoured" when it is open (reputation / upgrade) but not found yet: the book gives a hint.
func recipe_rumoured(id: String) -> bool:
	return GameData.RECIPES.has(id) and not recipe_known(id) and recipe_open(GameData.RECIPES[id])


## Ingredients that can go into an experiment: everything in storage that can be prepared at the alchemy table,
## {item: count}.
func experiment_stock() -> Dictionary:
	var stock := {}
	for id in GameData.BREW_PREP:
		var n := storage.count(id)
		if n > 0:
			stock[id] = n
	return stock


func can_experiment() -> bool:
	if phase != Phase.MARKET:
		return false
	var n := 0
	for id in experiment_stock():
		n += int(experiment_stock()[id])
	return n >= GameData.EXPERIMENT_MIN


## What an experiment with these pieces (item ids in the order they went in) gives:
## {"item": result, "kind": "discover" | "known" | "locked" | "near" | "miss", "recipe": the recipe it is about}.
func experiment_outcome(pieces: Array) -> Dictionary:
	var counts := {}
	for id in pieces:
		counts[id] = int(counts.get(id, 0)) + 1
	for rid in GameData.RECIPES:
		var ings: Dictionary = GameData.RECIPES[rid]["ingredients"]
		if ings.size() != counts.size():
			continue
		var same := true
		for ing in ings:
			if int(counts.get(ing, 0)) != int(ings[ing]):
				same = false
				break
		if same:
			if not recipe_open(GameData.RECIPES[rid]):
				return {"item": GameData.EXPERIMENT_MISS, "kind": "locked", "recipe": rid}
			return {"item": rid, "kind": "known" if recipe_known(rid) else "discover", "recipe": rid}
	for rid in GameData.RECIPES:
		var ings: Dictionary = GameData.RECIPES[rid]["ingredients"]
		if not recipe_open(GameData.RECIPES[rid]) or ings.size() != counts.size():
			continue
		var same_set := true
		for ing in counts:
			if not ings.has(ing):
				same_set = false
		if same_set:
			return {"item": GameData.EXPERIMENT_NEAR, "kind": "near", "recipe": rid}
	return {"item": GameData.EXPERIMENT_MISS, "kind": "miss", "recipe": ""}


## Brews an experiment: the pieces are taken from storage, the outcome (experiment_outcome) is put in.
## A new recipe goes into the book. Returns the outcome ({} if it could not be done).
func brew_experiment(pieces: Array, quality: int = -1, boils: int = 0) -> Dictionary:
	if phase != Phase.MARKET or pieces.size() < GameData.EXPERIMENT_MIN:
		return {}
	var counts := {}
	for id in pieces:
		counts[id] = int(counts.get(id, 0)) + 1
	for id in counts:
		if storage.count(id) < int(counts[id]):
			return {}
	var outcome := experiment_outcome(pieces)
	var out: String = outcome["item"]
	var real := GameData.RECIPES.has(out)
	if real and boils >= GameData.SPOIL_BOILS:
		out = GameData.SPOILED_POTION
		real = false
	var amount: int = int(GameData.RECIPES[out].get("amount", 1)) if real else 1
	if not _craft(counts, out, amount, quality if real else -1):
		last_brew = {"item": out, "ok": false}
		Audio.play("error")
		_log("[color=salmon]Експеримент не вдався: на полицях немає місця.[/color]")
		changed.emit()
		return {}
	day_stats["brewed"] += amount
	var ings := _items_text(counts)
	var out_name: String = GameData.ITEMS[out]["name"]
	match String(outcome["kind"]):
		"discover", "known":
			var rid: String = outcome["recipe"]
			if out != rid:
				Audio.play("fail")
				_log("[color=#c08ae0]Експеримент (%s): суміш википіла й зіпсувалася, вийшов «%s». Але склад був правильний![/color]" % [ings, out_name])
			if outcome["kind"] == "discover":
				known_recipes.append(rid)
				Audio.play("rank_up")
				_log("[color=#f2c14e][b]Новий рецепт: «%s»![/b][/color] Ти записуєш у книгу рецептів: %s." % [GameData.ITEMS[rid]["name"], ings])
			if out == rid:
				_note_quality(rid, quality)
				_log("Експеримент: «%s» ×%d.%s" % [out_name, amount, quality_note(quality)])
		"locked":
			Audio.play("fail")
			var need := GameData.rep_needed(GameData.RECIPES[outcome["recipe"]])
			_log("[color=#c08ae0]Експеримент (%s): щось майже вийшло, але бракує вміння (репутація %d). Вийшла «%s».[/color]" % [ings, need, out_name])
		"near":
			Audio.play("fail")
			_log("[color=#c08ae0]Експеримент (%s): майже! Запах знайомий, та пропорції не ті. Вийшов «%s» з побічною дією (купує тільки скупник).[/color]" % [ings, out_name])
		_:
			Audio.play("fail")
			_log("[color=#c08ae0]Експеримент (%s): нічого путнього, вийшла «%s» (купує тільки скупник).[/color]" % [ings, out_name])
	last_brew = {"item": out, "ok": true, "experiment": outcome["kind"], "recipe": outcome["recipe"], "q": quality if real else -1}
	changed.emit()
	return outcome


## True if a recipe can be used: reputation is high enough and the needed upgrade ("upgrade": [id, level]) is built.
func recipe_open(recipe: Dictionary) -> bool:
	if not is_unlocked(recipe):
		return false
	if recipe.has("upgrade"):
		return upgrade_level(recipe["upgrade"][0]) >= int(recipe["upgrade"][1])
	if recipe.has("kitchen"):
		return upgrade_level("kitchen") >= int(recipe["kitchen"])
	return true


# ---------- Kitchen ----------

func has_kitchen() -> bool:
	return upgrade_level("kitchen") >= 1


## Pieces one cooking of this dish gives (the kitchen level 2 adds its bonus).
func cook_amount(dish_id: String) -> int:
	return int(GameData.KITCHEN_RECIPES[dish_id].get("amount", 1)) + int(upgrade_value("kitchen", "bonus"))


func can_cook(dish_id: String) -> bool:
	if phase != Phase.MARKET or not has_kitchen() or not GameData.KITCHEN_RECIPES.has(dish_id):
		return false
	var recipe: Dictionary = GameData.KITCHEN_RECIPES[dish_id]
	if not recipe_open(recipe):
		return false
	for ing in recipe["ingredients"]:
		if storage.count(ing) < int(recipe["ingredients"][ing]):
			return false
	return true


## Cooks a dish: takes the ingredients, puts cook_amount() pieces onto the food shelf. Costs no actions.
## If the dish does not fit, nothing changes.
func cook(dish_id: String, quality: int = -1) -> void:
	if not can_cook(dish_id):
		return
	var recipe: Dictionary = GameData.KITCHEN_RECIPES[dish_id]
	var amount := cook_amount(dish_id)
	var dish_name: String = GameData.ITEMS[dish_id]["name"]
	if not _craft(recipe["ingredients"], dish_id, amount, quality):
		last_cook = {"item": dish_id, "ok": false, "amount": amount}
		Audio.play("error")
		_log("[color=salmon]Приготувати «%s» не вийде: на полицях немає місця.[/color]" % dish_name)
		changed.emit()
		return
	day_stats["brewed"] += amount
	_note_quality(dish_id, quality)
	last_cook = {"item": dish_id, "ok": true, "amount": amount, "q": quality}
	Audio.play("brew")
	_log("Ти готуєш «%s» (%s). Готово: %d шт.%s" % [dish_name, _items_text(recipe["ingredients"]), amount, quality_note(quality)])
	changed.emit()


# ---------- Tavern upgrades ----------

## Level of an upgrade (0 = not built).
func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func upgrade_max(id: String) -> int:
	return GameData.UPGRADES[id]["levels"].size()


## Value `key` of the current level of an upgrade (level 0 = "base").
func upgrade_value(id: String, key: String) -> Variant:
	var u: Dictionary = GameData.UPGRADES[id]
	var level := upgrade_level(id)
	if level <= 0:
		return u["base"][key]
	return u["levels"][level - 1].get(key, u["base"][key])


## The next level of an upgrade ({} if it is at the top).
func upgrade_next(id: String) -> Dictionary:
	var level := upgrade_level(id)
	var levels: Array = GameData.UPGRADES[id]["levels"]
	return levels[level] if level < levels.size() else {}


## Why the next level cannot be ordered now ("" = it can).
func upgrade_problem(id: String) -> String:
	var next := upgrade_next(id)
	if next.is_empty():
		return "Уже збудовано все."
	if phase != Phase.MARKET:
		return "Тесля приходить лише зранку, поки таверна зачинена."
	if not is_unlocked(next):
		return need_text(next) + "."
	if wallet.total < int(next["cost"]):
		return "Бракує золота: треба %s." % Wallet.format_amount(int(next["cost"]), true)
	return ""


## Buys the next level of an upgrade from the carpenter. It works at once. True if it was bought.
func buy_upgrade(id: String) -> bool:
	if upgrade_problem(id) != "":
		return false
	var next := upgrade_next(id)
	var cost := int(next["cost"])
	var mugs_before := keg_mugs()
	var contracts_before := contracts_per_day()
	wallet.add(-cost)
	day_stats["spent"] = int(day_stats.get("spent", 0)) + cost
	upgrades[id] = upgrade_level(id) + 1
	apply_upgrades()
	# Things that count per day get the new level today already.
	keg_left += keg_mugs() - mugs_before
	if contracts_per_day() > contracts_before:
		_fill_quest_board()
	Audio.play("build")
	_log("[color=#f2c14e]Тесля збудував: %s, рівень %d.[/color] %s (−%s)" % [GameData.UPGRADES[id]["name"], upgrade_level(id) + int(GameData.UPGRADES[id].get("level_shift", 0)), next["text"], Wallet.format_amount(cost, true)])
	changed.emit()
	return true


## Tells the storage how big the shelves and the attic are now.
func apply_upgrades() -> void:
	var over := {}
	var built := int(upgrade_value("shelves", "shelves"))
	for i in GameData.SHELF_ORDER.size():
		if i >= built:
			over[GameData.SHELF_ORDER[i]] = {"locked": true}
	var cols := int(upgrade_value("attic", "cols"))
	var rows := int(upgrade_value("attic", "rows"))
	if cols <= 0 or rows <= 0:
		over["attic"] = {"locked": true}
	else:
		over["attic"] = {"cols": cols, "rows": rows}
	Storage.grid_override = over


## Mugs of ale the keg holds a day, and seconds between two mugs (the "Пивний погріб" upgrade).
## Extra visitors a day: the reputation rank ("guests" in REP_RANKS) + the built upgrade levels ("guests").
func extra_guests() -> int:
	var n := int(rep_rank().get("guests", 0))
	for id in upgrades:
		var levels: Array = GameData.UPGRADES[id]["levels"]
		for l in mini(int(upgrades[id]), levels.size()):
			n += int(levels[l].get("guests", 0))
	return n


func keg_mugs() -> int:
	return int(upgrade_value("cellar", "mugs"))


func keg_cooldown() -> float:
	return float(upgrade_value("cellar", "cooldown"))


func contracts_per_day() -> int:
	return int(upgrade_value("board", "contracts"))


## Morning: heroes who slept in the rooms upstairs (not on a contract) pay for the night.
func _collect_rent() -> void:
	var rooms := int(upgrade_value("rooms", "rooms"))
	if rooms <= 0:
		return
	var guests := 0
	for h in heroes:
		if h["status"] == "free" or h["status"] == "injured":
			guests += 1
	guests = mini(guests, rooms)
	if guests <= 0:
		return
	var gold := guests * int(upgrade_value("rooms", "rent"))
	wallet.add(gold)
	day_stats["income"] = int(day_stats.get("income", 0)) + gold
	_log("У кімнатах нагорі ночувало героїв: %d. За постій: +%s." % [guests, Wallet.format_amount(gold, true)])


# ---------- Locations ----------

## True if the keeper has n actions left (always true while GameData.ACTIONS_ENABLED is false).
func has_actions(n: int) -> bool:
	return not GameData.ACTIONS_ENABLED or actions_left >= n


## Spends n actions (does nothing while the action limit is switched off).
func spend_actions(n: int) -> void:
	if GameData.ACTIONS_ENABLED:
		actions_left -= n


func can_travel() -> bool:
	return phase == Phase.MARKET and trip.is_empty() and has_actions(GameData.LOCATION_ACTION_COST)


## True if the keeper can go to this location now (has an action and it is not closed today).
func can_travel_to(location_id: String) -> bool:
	return can_travel() and not location_id in closed_locations and not location_id in visited_locations


## Goes to a location: spends an action, rolls an event and lays out the resources on the location screen.
## The player picks them up with gather(); leave_location() returns to the tavern.
func travel(location_id: String) -> void:
	if not can_travel_to(location_id) or not GameData.LOCATIONS.has(location_id):
		return
	var loc: Dictionary = GameData.LOCATIONS[location_id]
	spend_actions(GameData.LOCATION_ACTION_COST)
	day_stats["trips"] += 1
	Audio.play("door")
	visited_locations.append(location_id)
	var entry := _roll_location_event(loc)
	var event_id: String = entry.get("id", "")
	var event: Dictionary = GameData.LOCATION_EVENTS.get(event_id, {}).duplicate()
	if entry.has("text"):
		event["text"] = entry["text"]
	trip = {"location": location_id, "event": event_id, "event_text": event.get("text", ""), "nodes": [], "found": {},
		"grave": "closed" if event.get("effect", "") == "grave" else ""}
	if event.get("effect", "") == "expel":
		# Driven out: the action is lost, nothing is gathered, no way back until tomorrow.
		closed_locations.append(location_id)
		Audio.play("expelled", 0.6)
		_log("Похід: %s. [color=salmon]%s![/color] %s" % [loc["name"], event["name"], event["text"]])
		changed.emit()
		return
	var effect: String = event.get("effect", "")
	if loc.has("fishing"):
		trip["casts"] = int(GameData.FISHING["casts"]) + (int(event.get("extra", 0)) if effect == "casts" else 0)
	if effect == "wisp":
		trip["wisp"] = "free"
	if loc.get("kind", "") == "port":
		trip["port"] = _roll_port(effect)
	var rolled := _roll_location_loot(loc, event.get("mult", 1) if effect == "loot_mult" else 1, event.get("extra", 0) if effect == "fog" else 0)
	var timed: Array[String] = []
	if effect == "timed_rare":
		for i in randi_range(event["amount"][0], event["amount"][1]):
			timed.append(event["item"])
	var spots: Array = loc["spots"].duplicate()
	if effect == "grave":
		# Keep the resources off the grave.
		var g := Vector2(entry["grave"][0], entry["grave"][1])
		spots = spots.filter(func(p): return Vector2(p[0], p[1]).distance_to(g) > 22.0)
	spots.shuffle()
	var all_items: Array = timed + rolled
	for i in mini(all_items.size(), spots.size()):
		var spot := Vector2(spots[i][0] + randi_range(-3, 3), spots[i][1] + randi_range(-2, 2))
		trip["nodes"].append({"item": all_items[i], "spot": spot, "taken": false, "gone": false, "timed": i < timed.size()})
	if not event.is_empty():
		Audio.play("magic" if effect in ["loot_mult", "timed_rare", "wisp", "casts"] else "event", 0.6)
		_log("Похід: %s. [color=violet]%s![/color] %s" % [loc["name"], event["name"], event["text"]])
	changed.emit()


## The location's "events" entry that happens on arrival ({} = none). At most one event per trip.
## An event with "always_if_contract" always happens while such a contract is on the board or in progress.
func _roll_location_event(loc: Dictionary) -> Dictionary:
	for e in loc.get("events", []):
		for contract_id in e.get("always_if_contract", []):
			if has_contract(contract_id):
				return e
	var r := randf()
	for e in loc.get("events", []):
		if r < e["chance"]:
			return e
		r -= e["chance"]
	return {}


## True if this contract is on the board today or a hero is doing it now.
func has_contract(contract_id: String) -> bool:
	for q in quest_board + active_quests:
		if q.get("id", "") == contract_id:
			return true
	return false


## Item ids lying in the location this trip.
## mult: the amount is multiplied by it; extra: pieces added on top (only for locations with "count").
func _roll_location_loot(loc: Dictionary, mult: int, extra: int = 0) -> Array[String]:
	var rolled: Array[String] = []
	if loc.has("count"):
		var total := 0.0
		for entry in loc["loot"]:
			total += entry["weight"]
		for i in randi_range(loc["count"][0], loc["count"][1]) * mult + extra:
			var r := randf() * total
			for entry in loc["loot"]:
				r -= entry["weight"]
				if r < 0.0:
					rolled.append(entry["item"])
					break
	else:
		for entry in loc["loot"]:
			if randf() <= entry.get("chance", 1.0):
				for i in randi_range(entry["min"], entry["max"]) * mult:
					rolled.append(entry["item"])
	return rolled


## Picks up the resource with this index on the location screen. Returns false if it cannot
## (already taken, or its storage place is full).
func gather(index: int) -> bool:
	if trip.is_empty() or index < 0 or index >= trip["nodes"].size():
		return false
	var node: Dictionary = trip["nodes"][index]
	if node["taken"] or node.get("gone", false) or not storage.add(node["item"]):
		return false
	node["taken"] = true
	trip["found"][node["item"]] = trip["found"].get(node["item"], 0) + 1
	Audio.play("gather")
	day_stats["gathered"] += 1
	changed.emit()
	return true


## A timed resource (glowing mushrooms) was not picked up in time and vanished.
func expire_node(index: int) -> void:
	if trip.is_empty() or index < 0 or index >= trip["nodes"].size():
		return
	var node: Dictionary = trip["nodes"][index]
	if node["taken"] or node.get("gone", false):
		return
	node["gone"] = true
	changed.emit()


## The event data of the current trip ({} = no event / not in a location).
func trip_event() -> Dictionary:
	if trip.is_empty():
		return {}
	return GameData.LOCATION_EVENTS.get(trip["event"], {})


## Searches the dug-up grave on the current trip. Returns the result text ("" if there is no grave to search).
## Gold goes to the wallet, an item to storage (sold at once if there is no room).
func search_grave() -> String:
	var event := trip_event()
	if event.get("effect", "") != "grave" or trip.get("grave", "") != "closed":
		return ""
	trip["grave"] = "searched"
	Audio.play("dig")
	Audio.play("grave_loot", 0.75)
	var text: String
	if randf() < event["gold_chance"]:
		var gold := randi_range(event["gold"][0], event["gold"][1])
		wallet.add(gold)
		day_stats["income"] += gold
		text = "У трухлявій труні знайшовся гаманець: %s." % Wallet.format_amount(gold, true)
	else:
		var total := 0
		for id in event["items"]:
			total += int(event["items"][id])
		var roll := randi_range(1, total)
		var item_id := ""
		for id in event["items"]:
			roll -= int(event["items"][id])
			if roll <= 0:
				item_id = id
				break
		text = "Між кістками блищить «%s»%s." % [GameData.ITEMS[item_id]["name"], _store_or_sell(item_id, {"c": 0, "k": "stolen"})]
	if randf() < event["rep_chance"]:
		_change_rep(event["rep"])
		change_suspicion(GameData.SUSP_WITNESS)
		text += " Але сторож тебе помітив: по місту піде поголос, а варта щось запише. Репутація %d, підозра +%d." % [event["rep"], GameData.SUSP_WITNESS]
	else:
		text += " Здається, ніхто не бачив."
	_log("[color=violet]Розкопана могила.[/color] " + text)
	changed.emit()
	return text


## Returns from the location to the tavern. What was not picked up stays there.
func leave_location() -> void:
	if trip.is_empty():
		return
	var loc: Dictionary = GameData.LOCATIONS[trip["location"]]
	var left := {}
	for node in trip["nodes"]:
		if not node["taken"] and not node.get("gone", false):
			left[node["item"]] = left.get(node["item"], 0) + 1
	var found: Dictionary = trip["found"]
	last_trip = {"location": trip["location"], "found": found, "left": left, "event": trip["event"]}
	var expelled: bool = GameData.LOCATION_EVENTS.get(trip["event"], {}).get("effect", "") == "expel" or trip.get("wisp", "") == "sunk"
	trip = {}
	Audio.play("door")
	if loc.get("kind", "") == "port":
		_log("Порт: повертаєшся з пристані в таверну.")
	elif not expelled:
		var text := "Похід: %s. " % loc["name"]
		text += ("Зібрано: %s." % _items_text(found)) if not found.is_empty() else "Нічого не зібрано."
		if not left.is_empty():
			text += " [color=salmon]Залишено в локації: %s.[/color]" % _items_text(left)
		_log(text)
	changed.emit()


# ---------- Swamp: the will-o'-wisp ----------

## Tries to catch the wisp on the current trip. Returns {"ok": bool, "title", "text"}.
## Success: the wisp goes into a jar (attic). Failure: it lures the keeper into the quagmire, part of what was gathered
## on this trip sinks and the trip is over (the swamp is closed until tomorrow).
func catch_wisp() -> Dictionary:
	if trip.get("wisp", "") != "free":
		return {}
	var event := trip_event()
	if randf() < float(event["catch_chance"]):
		var item: String = event["item"]
		if not storage.add(item):
			trip["wisp"] = "gone"
			Audio.play("refuse")
			changed.emit()
			return {"ok": false, "title": "Вогник утік", "text": "Ти майже накрив вогник банкою, але на полицях немає місця, тож довелося його відпустити."}
		trip["wisp"] = "caught"
		trip["found"][item] = int(trip["found"].get(item, 0)) + 1
		day_stats["gathered"] += 1
		Audio.play("wisp")
		_log("[color=violet]Блукаючий вогник![/color] Ти впіймав його в банку: «%s»." % GameData.ITEMS[item]["name"])
		changed.emit()
		return {"ok": true, "title": "Вогник у банці!", "text": "Ти тихенько підкрався і накрив вогник банкою. Він дзвенить і світиться блакитним. Алхіміки за таке платять щедро."}
	# Lured into the bog.
	trip["wisp"] = "sunk"
	var pieces: Array[String] = []
	for id in trip["found"]:
		for i in int(trip["found"][id]):
			pieces.append(id)
	pieces.shuffle()
	var lost := {}
	for i in ceili(pieces.size() * float(event["lose_share"])):
		var id := pieces[i]
		if storage.take(id):
			lost[id] = int(lost.get(id, 0)) + 1
			trip["found"][id] = int(trip["found"][id]) - 1
			if int(trip["found"][id]) <= 0:
				trip["found"].erase(id)
	for node in trip["nodes"]:
		if not node["taken"]:
			node["gone"] = true
	if not trip["location"] in closed_locations:
		closed_locations.append(trip["location"])
	Audio.play("splash")
	Audio.play("expelled", 0.3)
	var text := "Вогник поплив углиб болота, ти ступив за ним і провалився в трясовину по пояс. Ледве вибрався!"
	if lost.is_empty():
		text += " Добре, що кошик був порожній."
	else:
		text += " У багні лишилося: %s." % _items_text(lost)
	text += " Сьогодні на болото краще не повертатися."
	_log("[color=salmon]Блукаючий вогник.[/color] " + text)
	changed.emit()
	return {"ok": false, "title": "Трясовина!", "text": text}


# ---------- Lake: fishing ----------

## Casts of the rod left on this trip (0 when not at the lake).
func fishing_casts_left() -> int:
	return int(trip.get("casts", 0))


## Spends a cast. Returns false if none are left.
func fish_cast() -> bool:
	if fishing_casts_left() <= 0:
		return false
	trip["casts"] = fishing_casts_left() - 1
	changed.emit()
	return true


## Which fish bites a cast of this power (0..1): picked by weight among GameData.FISHING["fish"] that bite at that distance.
func fish_roll(power: float) -> String:
	var options: Array[String] = []
	var total := 0.0
	for id in GameData.FISHING["fish"]:
		var f: Dictionary = GameData.FISHING["fish"][id]
		if power >= float(f["power"][0]) and power <= float(f["power"][1]):
			options.append(id)
			total += float(f["weight"])
	var r := randf() * total
	for id in options:
		r -= float(GameData.FISHING["fish"][id]["weight"])
		if r < 0.0:
			return id
	return "perch"


## The fish is landed: it goes to storage (or the purse to the wallet). Returns the text for the mini-game.
func land_fish(fish_id: String) -> String:
	if trip.is_empty():
		return ""
	var f: Dictionary = GameData.FISHING["fish"].get(fish_id, {})
	if f.has("gold"):
		var gold := randi_range(int(f["gold"][0]), int(f["gold"][1]))
		wallet.add(gold)
		day_stats["income"] += gold
		Audio.play("coin")
		_log("Риболовля: на гачку старий мокрий гаманець, а в ньому %s." % Wallet.format_amount(gold, true))
		changed.emit()
		return "На гачку старий мокрий гаманець! У ньому %s." % Wallet.format_amount(gold)
	if not storage.add(fish_id):
		Audio.play("refuse")
		changed.emit()
		return "«%s» на гачку, але на полицях немає місця. Довелося відпустити." % GameData.ITEMS[fish_id]["name"]
	trip["found"][fish_id] = int(trip["found"].get(fish_id, 0)) + 1
	day_stats["gathered"] += 1
	Audio.play("catch")
	changed.emit()
	return "Упіймано: «%s»!" % GameData.ITEMS[fish_id]["name"]


# ---------- Port: the merchant ship and the smuggler ----------

## Price of a piece at the port today: market cost x share (port-only goods: their "port_cost"), scaled by prosperity.
func port_price(item_id: String, share: float) -> int:
	var item: Dictionary = GameData.ITEMS[item_id]
	var base := float(item["port_cost"]) if item.has("port_cost") else float(item["cost"]) * share
	if item.has("port_cost") and share < float(GameData.PORT["share"]):
		base *= share / float(GameData.PORT["share"])  # the smuggler is cheaper for port goods too
	if base <= 0.0:
		base = float(item["price"]) * 0.5 * share
	return maxi(1, roundi(base * GameData.prosperity_mult(prosperity)))


func _roll_lots(table: Dictionary, n: int, share: float) -> Array:
	var ids: Array = table.keys()
	var lots: Array = []
	for k in n:
		var total := 0.0
		for id in ids:
			total += float(table[id][0])
		if total <= 0.0:
			break
		var r := randf() * total
		for id in ids:
			r -= float(table[id][0])
			if r < 0.0:
				lots.append({"item": id, "n": randi_range(int(table[id][1]), int(table[id][2])), "price": port_price(id, share)})
				ids.erase(id)
				break
	return lots


## What the port offers on this trip: {"merchant": [lots], "smuggler": [lots], "smuggler_here": bool, "job": bool}.
func _roll_port(effect: String) -> Dictionary:
	var sm: Dictionary = GameData.SMUGGLER
	var here := effect != "no_smuggler"
	return {
		"merchant": [] if effect == "no_merchant" else _roll_lots(GameData.PORT["goods"], int(GameData.PORT["lots"]), float(GameData.PORT["share"])),
		"smuggler": _roll_lots(sm["goods"], int(sm["lots"]), float(sm["share"])) if here else [],
		"smuggler_here": here,
		"job": here,
	}


## The port data of the current trip ({} if not at the port).
func port() -> Dictionary:
	return trip.get("port", {})


## True if the smuggler deals with the keeper (crime reputation high enough).
func smuggler_talks() -> bool:
	return faction_value("crime") >= int(GameData.SMUGGLER["min_crime"])


## Why "count" pieces of lot "index" of "who" ("merchant" / "smuggler") cannot be bought ("" = they can).
func port_problem(who: String, index: int, count: int) -> String:
	var lots: Array = port().get(who, [])
	if index < 0 or index >= lots.size():
		return "Цього товару вже немає."
	var lot: Dictionary = lots[index]
	if int(lot["n"]) < count or count <= 0:
		return "Стільки немає."
	if who == "smuggler" and not smuggler_talks():
		return "Контрабандист не говорить з донощиками."
	if wallet.total < int(lot["price"]) * count:
		return "Бракує золота: треба %s." % Wallet.format_amount(int(lot["price"]) * count, true)
	if not storage.can_fit(lot["item"], count):
		return "На полицях немає місця."
	return ""


## Buys "count" pieces of a lot. The smuggler's goods are stolen (see FENCE) and raise suspicion.
func port_buy(who: String, index: int, count: int) -> void:
	if port_problem(who, index, count) != "":
		return
	var lot: Dictionary = port()[who][index]
	var price := int(lot["price"]) * count
	wallet.add(-price)
	day_stats["spent"] = int(day_stats.get("spent", 0)) + price
	var origin := {"c": int(lot["price"])}
	if who == "smuggler":
		origin["k"] = "stolen"
	for i in count:
		storage.add(lot["item"], origin.duplicate())
	lot["n"] = int(lot["n"]) - count
	Audio.play("buy")
	var name: String = GameData.ITEMS[lot["item"]]["name"]
	if who == "smuggler":
		var sm: Dictionary = GameData.SMUGGLER
		var note := change_faction("crime", int(sm["deal_crime"]))
		change_suspicion(int(sm["deal_susp"]))
		_log("[color=#c08ae0]Порт: контрабандист продає тобі «%s» ×%d за %s. Без мита й без питань. %s, підозра +%d.[/color]" % [name, count, Wallet.format_amount(price, true), note, int(sm["deal_susp"])])
		if not crime_known:
			crime_known = true
			_log("[color=#c08ae0][b]Тепер ти знаєш людей тіньової гільдії.[/b] Відсьогодні на дошці з'являтимуться злочинні замовлення (темні листки).[/color]")
	else:
		_log("Порт: у заморського купця куплено «%s» ×%d за %s." % [name, count, Wallet.format_amount(price, true)])
	changed.emit()


## Gold the smuggler pays for keeping his crate, by the crime reputation.
func smuggle_pay() -> int:
	return int(GameData.pick_by(GameData.SMUGGLER["job"]["pay"], faction_value("crime"))[1])


## Why the keeper cannot take the smuggler's crate now ("" = can).
func smuggle_job_problem() -> String:
	if not port().get("job", false):
		return "Контрабандиста сьогодні немає."
	if not smuggler_talks():
		return "Контрабандист не довіряє донощикам."
	if not smuggle_job.is_empty():
		return "У таверні вже стоїть його ящик. Спершу хай забере той."
	return ""


## Takes the smuggler's sealed crate: he collects it in a few days and pays then.
func take_smuggle_job() -> void:
	if smuggle_job_problem() != "":
		return
	var job: Dictionary = GameData.SMUGGLER["job"]
	smuggle_job = {"due": day + int(job["days"]), "pay": smuggle_pay()}
	trip["port"]["job"] = false
	Audio.play("contract")
	_log("[color=#c08ae0]Порт: ти забираєш запечатаний ящик контрабандиста. Він прийде по нього на %d-й день і заплатить %s. Поки ящик у таверні, варта може навідатися будь-якого ранку.[/color]" % [int(smuggle_job["due"]), Wallet.format_amount(int(smuggle_job["pay"]), true)])
	changed.emit()


## Morning: the smuggler collects his crate and pays.
func _resolve_smuggling() -> void:
	if smuggle_job.is_empty() or day < int(smuggle_job["due"]):
		return
	var pay := int(smuggle_job["pay"])
	smuggle_job = {}
	wallet.add(pay)
	day_stats["income"] += pay
	var note := change_faction("crime", int(GameData.SMUGGLER["job"]["crime_done"]))
	Audio.play("coin", 0.4)
	_log("[color=#c08ae0]На світанку контрабандист тихо забрав свій ящик і залишив на стійці %s. %s.[/color]" % [Wallet.format_amount(pay, true), note])


## The guard found the smuggler's crate during an inspection. Returns the text.
func _lose_smuggle_crate() -> String:
	var job: Dictionary = GameData.SMUGGLER["job"]
	smuggle_job = {}
	var fine := mini(int(job["fine"]) * (2 if investigation() else 1), maxi(0, wallet.total))
	wallet.add(-fine)
	day_stats["fine"] = int(day_stats.get("fine", 0)) + fine
	change_suspicion(int(job["susp_found"]))
	var note := change_faction("crime", int(job["crime_lost"]))
	return "Варта знайшла ящик контрабандиста й забрала його. Штраф %s, підозра +%d, а гільдія тобі цього не пробачить: %s." % [
		Wallet.format_amount(fine, true), int(job["susp_found"]), note]


## Names of the storage places these items belong to, e.g. "Горище".
func _places_text(counts: Dictionary) -> String:
	var names: PackedStringArray = []
	for id in counts:
		var place_name := GameData.storage_name_of(id)
		if not place_name in names:
			names.append(place_name)
	return ", ".join(names)


func _items_text(counts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id in counts:
		parts.append("%s ×%d" % [GameData.ITEMS[id]["name"], counts[id]])
	return ", ".join(parts)


func open_tavern() -> void:
	if phase != Phase.MARKET:
		return
	leave_location()
	phase = Phase.SERVICE
	customers_today.clear()
	var heroes_today: Array[int] = []
	var count := GameData.CUSTOMERS_PER_DAY
	if town_event == "fair":
		count += int(GameData.FAIR["extra_customers"])
	count += extra_guests()
	for i in count:
		customers_today.append(_make_customer(heroes_today))
	if _fence_comes_today():
		customers_today.insert(randi_range(1, customers_today.size() - 1), _make_fence())
		count = customers_today.size()
	customer_index = 0
	# The brawl starts after at least two visitors and before the last one.
	brawl_at = randi_range(2, count - 1) if count >= 3 and randf() < GameData.BRAWL["chance"] else -1
	brawl_active = false
	_log("Двері таверни відчинено." + (" Через ярмарок у залі людно." if town_event == "fair" else ""))
	_next_customer()


# ---------- Service ----------

func _next_customer() -> void:
	awaiting_quest = false
	_clear_deal()
	if customer_index == brawl_at and customer_index < customers_today.size():
		brawl_at = -1
		brawl_active = true
		Audio.play("brawl")
		_log("[color=orange][b]%s![/b] Двоє гостей не поділили лавку, і в хід пішли кухлі.[/color]" % GameData.BRAWL["name"])
		changed.emit()
		return
	if customer_index >= customers_today.size():
		_end_day()
		return
	current_customer = customers_today[customer_index]
	Audio.play("visitor", 0.15)
	customer_index += 1
	changed.emit()


## True if the current visitor is willing to buy this item (its category matches the visitor's tag).
## The keeper decides what to do with the brawl. stop_it: true = restore order (the next visitors leave),
## false = let them fight (reputation drops).
func resolve_brawl(stop_it: bool) -> void:
	if not brawl_active:
		return
	brawl_active = false
	var b: Dictionary = GameData.BRAWL
	if stop_it:
		var lost := 0
		for i in int(b["lost_customers"]):
			if customer_index < customers_today.size():
				customer_index += 1
				lost += 1
		var who := "Поки ти наводив лад, наступний гість пішов, нічого не купивши." if lost == 1 \
				else "Поки ти наводив лад, %d гостей пішли, нічого не купивши." % lost if lost > 1 \
				else "Більше гостей сьогодні й не було."
		_log("Ти розбороняєш бійку. " + who)
	else:
		_change_rep(b["rep"])
		_log("[color=salmon]Ти не втручаєшся. Бійка розбиває кілька лавок, а гості розносять по місту, що в тебе небезпечно. Репутація %d.[/color]" % b["rep"])
	_next_customer()


func customer_accepts(item_id: String) -> bool:
	return phase == Phase.SERVICE and not awaiting_quest and not brawl_active \
			and customer_wants(GameData.ITEMS[item_id]["cat"])


## Categories the current visitor wants to buy from.
func customer_wants_list() -> Array:
	return current_customer.get("wants", [current_customer.get("tag", "")])


func customer_wants(cat: String) -> bool:
	return cat in customer_wants_list()


func customer_purse() -> int:
	return int(current_customer.get("purse", 0))


## True while the visitor waits for goods (the sale tray is in use).
## Why the keg cannot pour a mug right now ("" = it can). The cooldown is kept by the screen (real time).
func keg_problem() -> String:
	if phase != Phase.MARKET and phase != Phase.SERVICE:
		return "Таверна зачинена на ніч."
	if keg_left <= 0:
		return "Бочка на сьогодні порожня. Уранці її знову наповнять."
	if not storage.can_fit(GameData.KEG_ITEM):
		return "На полиці з напоями немає місця для ще одного кухля."
	return ""


## Pours one mug of ale from the keg onto the drinks shelf. True if it worked.
func pour_from_keg() -> bool:
	if keg_problem() != "":
		return false
	if not storage.add(GameData.KEG_ITEM, {"c": 0, "k": "free"}):
		return false
	keg_left -= 1
	changed.emit()
	return true


func trading() -> bool:
	return phase == Phase.SERVICE and not awaiting_quest and not brawl_active and not current_customer.is_empty() \
			and current_customer.get("type", "") != "fence"


func _clear_deal() -> void:
	deal.clear()
	deal_step = 0
	deal_raise_tried = false


func deal_has(uid: int) -> bool:
	for e in deal:
		if e["uid"] == uid:
			return true
	return false


## Price of the tray at normal prices (crafted pieces: x their quality, GameData.QUALITY_TIERS).
func deal_base() -> int:
	var total := 0
	for e in deal:
		total += piece_price(e["uid"], e["id"])
	return total


## Sale price today of one piece: item_price x its quality multiplier.
func piece_price(uid: int, item_id: String = "") -> int:
	if item_id == "":
		item_id = storage.id_of_uid(uid)
	return maxi(1, roundi(item_price(item_id) * GameData.quality_mult(piece_quality(uid))))


## Quality of a piece in storage (-1 = none).
func piece_quality(uid: int) -> int:
	return int(storage.origin_of(uid).get("q", -1))


## What the visitor pays for the whole tray at a price step (default: the current one).
## The step is taken from the sum, and always moves the price by at least 1 gold.
func deal_total(step: int = 99) -> int:
	if step == 99:
		step = deal_step
	var base := deal_base()
	if base <= 0 or step == 0:
		return base
	var exact := base * (1.0 + step * GameData.DEAL_STEP)
	if step < 0:
		return maxi(1, mini(base - 1, floori(exact)))
	return maxi(base + 1, ceili(exact))


## What the pieces on the tray cost the keeper (bought/brewed); free ones count 0.
func deal_cost() -> int:
	var total := 0
	for e in deal:
		total += int(storage.origin_of(e["uid"]).get("c", 0))
	return total


## Reputation the keeper gets for the current discount.
func deal_discount_rep() -> int:
	return roundi(-deal_step * GameData.DEAL_STEP * 10.0 * GameData.DEAL_REP_PER_10_OFF) if deal_step < 0 else 0


## Puts a shelf piece on the sale tray. Returns "" or why not.
func deal_put(uid: int) -> String:
	if not trading():
		return "Зараз нікому продавати."
	var item_id := storage.id_of_uid(uid)
	if item_id == "" or deal_has(uid):
		return ""
	if GameData.ITEMS[item_id].get("fence_only", false):
		return "«%s» чесний гість не купить. Таке бере тільки скупник." % GameData.ITEMS[item_id]["name"]
	if not customer_wants(GameData.ITEMS[item_id]["cat"]):
		return "«%s» відвідувачу не потрібне." % GameData.ITEMS[item_id]["name"]
	if deal.size() >= GameData.DEAL_SLOTS:
		return "На прилавку вже %d речі: більше за раз не візьмуть." % GameData.DEAL_SLOTS
	deal.append({"uid": uid, "id": item_id})
	changed.emit()
	return ""


## Takes a piece off the tray (it goes back on its shelf).
func deal_remove(uid: int) -> void:
	for i in deal.size():
		if deal[i]["uid"] == uid:
			deal.remove_at(i)
			if deal.is_empty() and deal_step < 0:
				deal_step = 0
			changed.emit()
			return


## Turns the -10% discount on / off (not after the visitor agreed to +10%).
func deal_toggle_discount() -> void:
	if not trading() or deal_step > 0:
		return
	deal_step = 0 if deal_step < 0 else -1
	changed.emit()


## Chance the visitor agrees to +10%.
func raise_chance() -> float:
	var chance: float = GameData.DEAL_RAISE_ACCEPT + current_customer.get("tolerance", 0.0) + reputation * GameData.REP_SALE_BONUS_PER_POINT
	return clampf(chance, 0.05, 0.98)


## Why +10% cannot be tried now ("" = it can).
func raise_problem() -> String:
	if deal.is_empty():
		return "Спершу поклади товар на прилавок."
	if deal_step > 0:
		return "Відвідувач уже погодився на +10%."
	if deal_raise_tried:
		return "Цей відвідувач уже відмовився платити більше."
	if deal_step < 0:
		return "Спершу прибери знижку."
	if deal_total(1) > customer_purse():
		return "У відвідувача не вистачить грошей на +10%."
	return ""


## Tries to sell for 10% more. Yes: the price goes up. No: the price stays (or the visitor leaves offended).
func deal_try_raise() -> void:
	if not trading() or raise_problem() != "":
		return
	deal_raise_tried = true
	var who := _who()
	if randf() <= raise_chance():
		deal_step = 1
		Audio.play("coin")
		_log("%s бурчить, але погоджується на +10%%." % who)
		changed.emit()
	elif randf() < GameData.DEAL_RAISE_LEAVE:
		_change_rep(GameData.REP_UNHAPPY_CUSTOMER)
		Audio.play("angry")
		_log("[color=salmon]%s ображається на здирство і йде геть. Репутація %d.[/color]" % [who, GameData.REP_UNHAPPY_CUSTOMER])
		day_stats["refused"] += 1
		_next_customer()
	else:
		Audio.play("refuse")
		_log("%s не погоджується платити більше. Ціна лишається звичайною." % who)
		changed.emit()


## Why the tray cannot be sold now ("" = it can).
func sell_problem() -> String:
	if deal.is_empty():
		return "Перетягни товар з полиць на прилавок."
	if deal_total() > customer_purse():
		return "У відвідувача лише %s." % Wallet.format_amount(customer_purse(), true)
	return ""


## Sells everything on the tray at the current price.
func sell_deal() -> void:
	if not trading() or sell_problem() != "":
		return
	var who := _who()
	var names: PackedStringArray = []
	var total := deal_total()
	var k := float(total) / maxi(1, deal_base())
	var stolen_n := 0
	var shady_n := 0
	for e in deal:
		if is_stolen(e["uid"]):
			stolen_n += 1
		if GameData.ITEMS[e["id"]].get("shady", false):
			shady_n += 1
	for e in deal:
		var item_id: String = e["id"]
		if storage.take_uid(e["uid"]).is_empty():
			continue
		var price := roundi(piece_price(e["uid"], item_id) * k)
		names.append("«%s»" % GameData.ITEMS[item_id]["name"])
		day_stats["sales"] += 1
		day_stats["sold"][item_id] = day_stats["sold"].get(item_id, 0) + 1
		var cat: String = GameData.ITEMS[item_id]["cat"]
		day_stats["cat_income"][cat] = day_stats["cat_income"].get(cat, 0) + price
	wallet.add(total)
	day_stats["income"] += total
	var note := ""
	var rep := deal_discount_rep()
	if rep != 0:
		note = " (знижка %d%%, репутація %+d)" % [roundi(-deal_step * GameData.DEAL_STEP * 100), rep]
		_change_rep(rep)
	elif deal_step > 0:
		note = " (+%d%%)" % roundi(deal_step * GameData.DEAL_STEP * 100)
	Audio.play("coin")
	_log("%s купує %s за %s%s" % [who, ", ".join(names), Wallet.format_amount(total, true), note])
	if stolen_n > 0:
		# Selling stolen goods: the underworld respects it, but a visitor may recognise the thing.
		change_faction("crime", 1)
		if randf() < 1.0 - pow(1.0 - stolen_witness_chance(), stolen_n):
			Audio.play("angry")
			change_suspicion(GameData.SUSP_WITNESS)
			_log("[color=salmon]%s придивляється до покупки: «Звідки це в тебе? Я цю річ уже бачив...» Підозра +%d.[/color]" % [who, GameData.SUSP_WITNESS])
	if shady_n > 0:
		# Poison sold over the counter: somebody will tell the guard.
		change_suspicion(shady_n * GameData.SUSP_SHADY_SALE)
		_log("[color=#c08ae0]Отрута з-під стійки не лишається непоміченою. Підозра +%d.[/color]" % (shady_n * GameData.SUSP_SHADY_SALE))
	_clear_deal()
	_after_customer()


func refuse() -> void:
	if phase != Phase.SERVICE or awaiting_quest or brawl_active:
		return
	if fence_here():
		fence_refuse()
		return
	Audio.play("refuse")
	var wants := customer_wants_list()
	var has_any := false
	var tag_names: PackedStringArray = []
	for cat in wants:
		tag_names.append("«%s»" % GameData.CATEGORIES[cat]["name"])
		if has_sellable(cat):
			has_any = true
	if not has_any:
		_log("%s шукав %s, але на складі такого немає." % [_who(), " або ".join(tag_names)])
		var tag: String = wants[0]
		day_stats["missed"][tag] = day_stats["missed"].get(tag, 0) + 1
		day_stats["missed_gold"] += mini(customer_purse(), missed_sale_value(tag)) if customer_purse() > 0 else missed_sale_value(tag)
	else:
		_log("Ти відмовляєш %s." % current_customer["name"])
	_change_rep(GameData.REP_UNHAPPY_CUSTOMER)
	day_stats["refused"] += 1
	_clear_deal()
	_after_customer()


## Roughly how much money a visitor who wanted this category would have paid (average price of its items today).
func missed_sale_value(cat: String) -> int:
	var ids := GameData.items_of(cat)
	if ids.is_empty():
		return 0
	var total := 0
	for id in ids:
		total += item_price(id)
	return roundi(float(total) / ids.size())


func _after_customer() -> void:
	if current_customer["type"] == "hero" and not quest_board.is_empty() and current_hero().get("status", "") == "free":
		awaiting_quest = true
		changed.emit()
	else:
		_next_customer()


# ---------- Heroes & contracts ----------

func hero_by_id(hero_id: int) -> Dictionary:
	for h in heroes:
		if h["id"] == hero_id:
			return h
	return {}


## The hero standing at the counter ({} if the visitor is not a hero).
func current_hero() -> Dictionary:
	return hero_by_id(current_customer.get("hero_id", -1))


func hero_count(status: String) -> int:
	var n := 0
	for h in heroes:
		if h["status"] == status:
			n += 1
	return n


## Items in storage the current hero could take on a contract.
func hero_item_choices() -> Array[String]:
	var result: Array[String] = []
	for cat in GameData.HERO_ITEM_CATEGORIES:
		for id in storage.ids_in_category(cat):
			if not GameData.ITEMS[id].get("fence_only", false):
				result.append(id)
	return result


## Hero power for a contract: sum of all stats plus the stats of the item he takes.
func hero_power(hero: Dictionary, item_id: String = "") -> int:
	var power := GameData.stats_sum(hero.get("stats", {}))
	if item_id != "":
		power += GameData.stats_sum(GameData.ITEMS[item_id].get("hero_stats", {}))
	return power


func contract_chance(quest: Dictionary, hero: Dictionary, item_id: String = "") -> float:
	var chance: float = 0.5 + (hero_power(hero, item_id) - int(quest["diff"])) * GameData.CHANCE_PER_POINT
	return clampf(chance, GameData.CHANCE_MIN, GameData.CHANCE_MAX)


## Chance of the current hero on this contract.
func quest_chance(quest: Dictionary, item_id: String = "") -> float:
	return contract_chance(quest, current_hero(), item_id)


## True if the current hero agrees to this contract. A hero who asked for work takes anything;
## a hero the keeper approached himself refuses contracts that look too risky.
func hero_will_take(quest: Dictionary, item_id: String = "") -> bool:
	return current_customer.get("asks_contract", false) or quest_chance(quest, item_id) >= GameData.PICKY_HERO_MIN_CHANCE


## Sends the current hero on a contract. item_id: an item from storage to give them ("" = nothing).
func assign_quest(quest_index: int, item_id: String = "") -> void:
	if not awaiting_quest or quest_index < 0 or quest_index >= quest_board.size():
		return
	var hero := current_hero()
	if hero.is_empty() or hero["status"] != "free":
		return
	var quest: Dictionary = quest_board[quest_index]
	if item_id != "" and (not GameData.ITEMS[item_id]["cat"] in GameData.HERO_ITEM_CATEGORIES or storage.count(item_id) <= 0):
		item_id = ""
	if not hero_will_take(quest, item_id):
		return
	var item_origin := {}
	if item_id != "":
		item_origin = storage.take_piece(item_id)
	quest_board.remove_at(quest_index)
	var job := quest.duplicate()
	job["hero_id"] = hero["id"]
	job["hero"] = hero["name"]
	job["chance"] = quest_chance(quest, item_id)
	job["item"] = item_id
	job["item_origin"] = item_origin
	job["return_day"] = day + int(quest["days"])
	active_quests.append(job)
	hero["status"] = "quest"
	hero["quest"] = quest["title"]
	var text := "%s береться за контракт «%s» (%s, %d дн.)." % [_who(), quest["title"], GameData.CONTRACT_TIERS[quest["tier"]]["name"].to_lower(), quest["days"]]
	Audio.play("contract")
	if item_id != "":
		text += " З собою: «%s»." % GameData.ITEMS[item_id]["name"]
	_log(text)
	_next_customer()


func skip_quest() -> void:
	if awaiting_quest:
		_next_customer()


## True if this contract can be offered today: reputation is enough; a criminal order needs the fence met;
## the magistrate gives nothing during an investigation.
func contract_available(id: String) -> bool:
	var c: Dictionary = GameData.CONTRACTS[id]
	if not is_unlocked(c):
		return false
	match c.get("faction", "people"):
		"crime":
			return crime_known and faction_value("crime") >= 0
		"state":
			return not investigation()
	return true


## Ids of the contracts that can be on the board today (crime=true: only criminal orders, false: all others).
func available_contracts(crime: bool) -> Array:
	var result: Array = []
	for id in GameData.CONTRACTS:
		if contract_available(id) and (GameData.CONTRACTS[id].get("faction", "people") == "crime") == crime:
			result.append(id)
	return result


func _generate_quest_board() -> void:
	quest_board.clear()
	var ids: Array = available_contracts(false)
	ids.shuffle()
	var crime_ids: Array = available_contracts(true)
	crime_ids.shuffle()
	# One note of the board goes to a criminal order once the keeper knows the underworld.
	var slots := contracts_per_day() - (1 if not crime_ids.is_empty() else 0)
	var picked: Array = []
	# One contract of every tier first, so there is always something easy and something big.
	for tier in GameData.CONTRACT_TIERS:
		for id in ids:
			if GameData.CONTRACTS[id]["tier"] == tier and not id in picked:
				picked.append(id)
				break
	for id in ids:
		if picked.size() >= slots:
			break
		if not id in picked:
			picked.append(id)
	if not crime_ids.is_empty():
		picked.append(crime_ids[0])
	for id in picked:
		quest_board.append(_make_contract(id))


## Adds contracts to today's board up to contracts_per_day() (after the board was made bigger).
func _fill_quest_board() -> void:
	var on_board: Array = []
	for q in quest_board:
		on_board.append(q["id"])
	var ids: Array = available_contracts(false)
	ids.shuffle()
	for id in ids:
		if quest_board.size() >= contracts_per_day():
			break
		if not id in on_board:
			quest_board.append(_make_contract(id))
			on_board.append(id)


func _make_contract(id: String) -> Dictionary:
	var t: Dictionary = GameData.CONTRACTS[id]
	var tier: Dictionary = GameData.CONTRACT_TIERS[t["tier"]]
	return {
		"id": id,
		"title": t["title"],
		"desc": t["desc"],
		"tier": t["tier"],
		"diff": t["diff"],
		"reward": randi_range(t["reward"][0], t["reward"][1]),
		"days": randi_range(tier["days"][0], tier["days"][1]),
		"loot": t["loot"],
		"faction": t.get("faction", "people"),
	}


func _heal_heroes() -> void:
	for h in heroes:
		if h["status"] == "injured" and day >= h["injured_until"]:
			h["status"] = "free"
			_log("%s одужав і знову шукає роботу." % h["name"])
		elif h["status"] == "jailed" and day >= int(h.get("jailed_until", 0)):
			h["status"] = "free"
			_log("Варта відпустила %s з в'язниці. Герой знову шукає роботу." % h["name"])


func _resolve_returning_quests() -> void:
	var still_out: Array[Dictionary] = []
	for q in active_quests:
		if q["return_day"] > day:
			still_out.append(q)
			continue
		var hero := hero_by_id(q["hero_id"])
		var item_id: String = q.get("item", "")
		var item_back: bool = item_id != "" and GameData.ITEMS[item_id]["cat"] in GameData.RETURNING_CATEGORIES
		var tier: Dictionary = GameData.CONTRACT_TIERS[q["tier"]]
		var faction: String = q.get("faction", "people")
		var crime := faction == "crime"
		if randf() <= q["chance"]:
			wallet.add(q["reward"])
			day_stats["quest_income"] += q["reward"]
			var prosperity := int(GameData.CONTRACTS.get(q["id"], {}).get("prosperity", GameData.PROSPERITY_ON_QUEST_SUCCESS))
			_change_prosperity(prosperity)
			hero["status"] = "free"
			hero["done"] = hero.get("done", 0) + 1
			Audio.play("success", 0.6)
			var notes: PackedStringArray = []
			match faction:
				"state":
					var half := ceili(tier["rep"] / 2.0)
					notes.append(change_faction("state", tier["rep"]))
					_change_rep(half)
					change_suspicion(int(GameData.SUSP_STATE_CONTRACT[q["tier"]]))
					notes.append("містяни +%d" % half)
					if suspicion > 0 or GameData.SUSP_STATE_CONTRACT[q["tier"]] != 0:
						notes.append("підозра %d" % GameData.SUSP_STATE_CONTRACT[q["tier"]])
				"crime":
					notes.append(change_faction("crime", tier["rep"]))
					var susp := GameData.SUSP_CRIME_DONE
					if randf() < GameData.CRIME_WITNESS_CHANCE:
						susp += GameData.SUSP_WITNESS
					change_suspicion(susp)
					notes.append("підозра +%d%s" % [susp, " (були свідки)" if susp > GameData.SUSP_CRIME_DONE else ""])
				_:
					_change_rep(tier["rep"])
					notes.append("репутація +%d" % tier["rep"])
			notes.append("процвітання %+d" % prosperity)
			var notes_text := ", ".join(notes)
			notes_text = notes_text.left(1).to_upper() + notes_text.substr(1)
			var text := "[color=%s]%s виконав %s «%s»! Твоя частка: %s. %s.[/color]" % ["#c08ae0" if crime else "lime", q["hero"], "замовлення" if crime else "контракт", q["title"], Wallet.format_amount(q["reward"], true), notes_text]
			if item_back:
				text += " Повертає «%s»%s." % [GameData.ITEMS[item_id]["name"], _store_or_sell(item_id, q.get("item_origin", {}))]
			for entry in q["loot"]:
				if randf() <= entry.get("chance", 1.0):
					for i in randi_range(entry["min"], entry["max"]):
						var origin := {"c": 0, "k": "stolen"} if crime else {}
						text += " %s: «%s»%s." % ["Здобич (крадене)" if crime else "Трофей", GameData.ITEMS[entry["item"]]["name"], _store_or_sell(entry["item"], origin)]
			_log(text)
		elif crime and randf() < GameData.CRIME_CAUGHT_CHANCE:
			# A hero caught on a criminal job goes to jail, the gear given to him is taken by the guard.
			change_suspicion(GameData.SUSP_HERO_CAUGHT)
			hero["status"] = "jailed"
			hero["jailed_until"] = day + GameData.JAIL_DAYS
			Audio.play("fail", 0.6)
			var text := "[color=salmon]%s попався на замовленні «%s»! Варта кинула героя до в'язниці на %d дн., і на допиті прозвучала назва твоєї таверни. Підозра +%d.[/color]" % [q["hero"], q["title"], GameData.JAIL_DAYS, GameData.SUSP_HERO_CAUGHT]
			if item_back:
				text += " [color=salmon]«%s» забрала варта.[/color]" % GameData.ITEMS[item_id]["name"]
			_log(text)
		elif randf() <= tier["death"]:
			if crime:
				change_suspicion(GameData.SUSP_CRIME_FAIL)
			_change_rep(GameData.REP_HERO_DIED)
			_change_prosperity(GameData.PROSPERITY_ON_HERO_DEATH)
			heroes.erase(hero)
			Audio.play("death", 0.6)
			var text := "[color=salmon]%s загинув на контракті «%s». У залі шепочуться... Репутація %d.[/color]" % [q["hero"], q["title"], GameData.REP_HERO_DIED]
			if item_back:
				text += " [color=salmon]«%s» втрачено разом із героєм.[/color]" % GameData.ITEMS[item_id]["name"]
			_log(text)
		else:
			if crime:
				change_suspicion(GameData.SUSP_CRIME_FAIL)
			_change_rep(GameData.REP_HERO_INJURED)
			hero["status"] = "injured"
			hero["injured_until"] = day + GameData.INJURY_DAYS
			Audio.play("fail", 0.6)
			var text := "[color=orange]%s провалив контракт «%s» і ледве дістався назад, поранений. Відпочиватиме %d дн. Репутація %d.[/color]" % [q["hero"], q["title"], GameData.INJURY_DAYS, GameData.REP_HERO_INJURED]
			if item_back:
				text += " Повертає «%s»%s." % [GameData.ITEMS[item_id]["name"], _store_or_sell(item_id, q.get("item_origin", {}))]
			_log(text)
	active_quests = still_out


## Puts an item that a hero brought into its storage place. If there is no room, sells it at once.
## Returns a short note for the log ("" if it was stored).
func _store_or_sell(item_id: String, origin: Dictionary = {}) -> String:
	if storage.add(item_id, origin):
		return ""
	var money := maxi(1, roundi(item_price(item_id) * GameData.OVERFLOW_SALE_SHARE))
	wallet.add(money)
	day_stats["quest_income"] += money
	return " (на полицях немає місця, продано за %s)" % Wallet.format_amount(money, true)


# ---------- Evening ----------

func _end_day() -> void:
	_announce_rank()
	if _check_arrest():
		return
	if day_stats["missed_gold"] > 0:
		var parts: PackedStringArray = []
		for cat in day_stats["missed"]:
			parts.append("%s ×%d" % [GameData.CATEGORIES[cat]["name"].to_lower(), day_stats["missed"][cat]])
		_log("[color=salmon]Через порожні полиці сьогодні втрачено ≈ %s (%s).[/color]" % [Wallet.format_amount(day_stats["missed_gold"], true), ", ".join(parts)])
	wallet.add(-GameData.DAILY_UPKEEP)
	_log("Вечір. Утримання таверни: −%s." % Wallet.format_amount(GameData.DAILY_UPKEEP, true))
	var decay := mini(suspicion, suspicion_decay())
	if decay > 0:
		change_suspicion(-decay)
	if suspicion >= GameData.SUSPICION_MAX - 15:
		_log("[color=#ff6040][b]Варта вже майже готова до арешту (підозра %d з %d)![/b] Хабар у казармі або державний контракт можуть урятувати.[/color]" % [suspicion, GameData.SUSPICION_MAX])
	if wallet.total < 0:
		_game_over(false, "Таверна збанкрутувала. Гільдія забирає ключі.")
		return
	if day >= GameData.LAST_DAY:
		if wallet.total >= GameData.GOAL_MONEY:
			_game_over(true, "Борг гільдії сплачено! «Втомлений Грифон» тепер повністю твій.")
		else:
			_game_over(false, "Час вийшов: %s з %s. Гільдія забирає таверну." % [wallet.format(true), Wallet.format_amount(GameData.GOAL_MONEY, true)])
		return
	phase = Phase.EVENING
	changed.emit()


func next_day() -> void:
	if phase != Phase.EVENING:
		return
	day += 1
	_start_morning()


func _game_over(victory: bool, text: String) -> void:
	won = victory
	phase = Phase.GAME_OVER
	_log("[b]%s[/b]" % text)
	# The game is over: there is nothing to continue.
	delete_save()
	changed.emit()


# ---------- Helpers ----------

## heroes_today: ids of heroes already coming today (a hero comes at most once a day).
func _make_customer(heroes_today: Array[int]) -> Dictionary:
	var type_id := _pick_customer_type()
	var hero := {}
	if type_id == "hero":
		hero = _pick_hero_visitor(heroes_today)
		while hero.is_empty():
			type_id = _pick_customer_type()
			if type_id != "hero":
				break
			hero = _pick_hero_visitor(heroes_today)
	var t: Dictionary = GameData.CUSTOMER_TYPES[type_id]
	var tags: Array = t["tags"]
	var face := Portraits.pick(type_id, t.get("gender", ""))
	var gender: String = face.get("gender", "")
	if gender == "":
		gender = t.get("gender", "m" if randf() < 0.5 else "f")
	var c := {
		"type": type_id,
		"title": t["title"],
		"name": random_name(gender),
		"portrait": face.get("path", ""),
		"tolerance": t["tolerance"] + randf_range(-0.1, 0.1),
	}
	var wants: Array = [tags[randi() % tags.size()]]
	if tags.size() > 1 and randf() < GameData.DEAL_SECOND_WANT_CHANCE:
		var others: Array = tags.filter(func(x: String) -> bool: return x != wants[0])
		wants.append(others[randi() % others.size()])
	c["tag"] = wants[0]
	c["wants"] = wants
	c["purse"] = _roll_purse(wants, float(t.get("purse", 1.0)))
	if not hero.is_empty():
		heroes_today.append(hero["id"])
		c["hero_id"] = hero["id"]
		c["name"] = hero["name"]
		c["portrait"] = hero.get("portrait", "")
		c["title"] = GameData.HERO_CLASSES[hero["class"]]["name"]
		c["asks_contract"] = randf() < GameData.HERO_ASKS_CHANCE
	return c


## How much money a visitor brings: about 1-2 average items of the categories they want (see DEAL_PURSE_*).
func _roll_purse(wants: Array, factor: float) -> int:
	var total := 0
	var n := 0
	var cheapest := 1 << 30
	for cat in wants:
		for id in GameData.items_of(cat):
			var p := item_price(id)
			total += p
			n += 1
			cheapest = mini(cheapest, p)
	if n == 0:
		return 10
	var purse := float(total) / n * randf_range(GameData.DEAL_PURSE_MIN, GameData.DEAL_PURSE_MAX) * factor
	if wants.size() > 1:
		purse *= GameData.DEAL_PURSE_TWO_WANTS
	return maxi(cheapest, roundi(purse))


## A free hero who comes to the tavern today: a known one or a new one. {} if nobody can come.
func _pick_hero_visitor(heroes_today: Array[int]) -> Dictionary:
	var known: Array[Dictionary] = []
	for h in heroes:
		if h["status"] == "free" and not h["id"] in heroes_today:
			known.append(h)
	var can_add := heroes.size() < max_heroes()
	if can_add and (known.is_empty() or randf() < GameData.NEW_HERO_CHANCE):
		return _new_hero()
	if known.is_empty():
		return {}
	return known[randi() % known.size()]


func _new_hero() -> Dictionary:
	var classes := unlocked_ids(GameData.HERO_CLASSES)
	var class_id: String = classes[randi() % classes.size()]
	var stats := {}
	var base: Dictionary = GameData.HERO_CLASSES[class_id]["stats"]
	for stat in GameData.HERO_STATS:
		stats[stat] = maxi(1, int(base.get(stat, 1)) + randi_range(-GameData.HERO_STAT_SPREAD, GameData.HERO_STAT_SPREAD))
	# A tavern with a good name attracts stronger heroes.
	var stat_ids: Array = GameData.HERO_STATS.keys()
	for i in rep_rank()["hero_bonus"]:
		var stat: String = stat_ids[randi() % stat_ids.size()]
		stats[stat] += 1
	# Face: one of the class portraits that no other hero has yet. The name matches its gender.
	var used_faces: Array = []
	var used: Array[String] = []
	for h in heroes:
		used.append(h["name"])
		used_faces.append(h.get("portrait", ""))
	var face := Portraits.pick("hero_" + class_id, "", used_faces)
	var gender: String = face.get("gender", "")
	if gender == "":
		gender = "m" if randf() < 0.5 else "f"
	var names: Array[String] = []
	for n in (GameData.NAMES_M if gender == "m" else GameData.NAMES_F):
		if not n in used:
			names.append(n)
	var hero := {
		"id": _next_hero_id,
		"name": names[randi() % names.size()] if not names.is_empty() else "Герой %d" % _next_hero_id,
		"gender": gender,
		"portrait": face.get("path", ""),
		"class": class_id,
		"stats": stats,
		"status": "free",
		"injured_until": 0,
		"quest": "",
		"done": 0,
	}
	_next_hero_id += 1
	heroes.append(hero)
	return hero


## A random name for this gender ("m" / "f").
func random_name(gender: String) -> String:
	var names: Array = GameData.NAMES_F if gender == "f" else GameData.NAMES_M
	return names[randi() % names.size()]


func _pick_customer_type() -> String:
	var total := 0
	for id in GameData.CUSTOMER_TYPES:
		total += GameData.CUSTOMER_TYPES[id]["weight"]
	var roll := randi_range(1, total)
	for id in GameData.CUSTOMER_TYPES:
		roll -= GameData.CUSTOMER_TYPES[id]["weight"]
		if roll <= 0:
			return id
	return "peasant"


func _who() -> String:
	return "%s (%s)" % [current_customer["name"], String(current_customer["title"]).to_lower()]


func _change_rep(delta: int) -> void:
	reputation = clampi(reputation + delta, GameData.REP_MIN, GameData.REP_MAX)


## Logs rank changes once in the morning (after heroes return) and once in the evening,
## so the log is not spammed when reputation jumps around a border during the day.
func _announce_rank() -> void:
	var rank := GameData.rep_rank_index(reputation)
	if rank == _announced_rank:
		return
	if rank > _best_rank:
		for i in range(_best_rank + 1, rank + 1):
			_log(_rank_up_text(i))
		_best_rank = rank
	elif rank > _announced_rank:
		_log("[color=gold]Репутація знову «%s».[/color]" % GameData.REP_RANKS[rank]["name"])
	else:
		_log("[color=salmon]Слава таверни гасне: тепер ти «%s». Героїв у місті може бути лише %d.[/color]" % [GameData.REP_RANKS[rank]["name"], GameData.REP_RANKS[rank]["max_heroes"]])
	Audio.play("rank_up" if rank > _announced_rank else "rank_down", 1.3)
	_announced_rank = rank


func _rank_up_text(rank_index: int) -> String:
	var rank: Dictionary = GameData.REP_RANKS[rank_index]
	var text := "[color=gold][b]Репутація зросла: «%s»![/b][/color]" % rank["name"]
	var news := rank_unlocks_text(rank_index)
	if news != "":
		text += " " + news
	return text


## What a rank opens, as one line ("" if nothing new).
func rank_unlocks_text(rank_index: int) -> String:
	var rank: Dictionary = GameData.REP_RANKS[rank_index]
	var lo: int = rank["min"]
	var hi: int = GameData.REP_RANKS[rank_index + 1]["min"] if rank_index + 1 < GameData.REP_RANKS.size() else GameData.REP_MAX + 1
	var parts: PackedStringArray = []
	var names: PackedStringArray = []
	for id in GameData.CONTRACTS:
		var need := GameData.rep_needed(GameData.CONTRACTS[id])
		if need >= lo and need < hi and need > GameData.REP_MIN:
			names.append("«%s»" % GameData.CONTRACTS[id]["title"])
	if not names.is_empty():
		parts.append("Нові контракти: " + ", ".join(names) + ".")
	names = []
	for id in GameData.HERO_CLASSES:
		var need := GameData.rep_needed(GameData.HERO_CLASSES[id])
		if need >= lo and need < hi and need > GameData.REP_MIN:
			names.append(GameData.HERO_CLASSES[id]["name"])
	if not names.is_empty():
		parts.append("Тепер приходять герої класу: " + ", ".join(names) + ".")
	names = []
	for id in GameData.RECIPES:
		var need := GameData.rep_needed(GameData.RECIPES[id])
		if need >= lo and need < hi and need > GameData.REP_MIN:
			names.append("«%s»" % GameData.ITEMS[id]["name"])
	if not names.is_empty():
		parts.append("Новий рецепт: " + ", ".join(names) + ".")
	names = []
	for id in GameData.UPGRADES:
		var levels: Array = GameData.UPGRADES[id]["levels"]
		for i in levels.size():
			var need := GameData.rep_needed(levels[i])
			if need >= lo and need < hi and need > GameData.REP_MIN:
				names.append("%s (рівень %d)" % [GameData.UPGRADES[id]["name"], i + 1])
	if not names.is_empty():
		parts.append("Тесля може збудувати: " + ", ".join(names) + ".")
	var prev: Dictionary = GameData.REP_RANKS[rank_index - 1] if rank_index > 0 else {}
	if prev.is_empty() or rank["max_heroes"] > prev["max_heroes"]:
		parts.append("Героїв у місті до %d." % rank["max_heroes"])
	if int(rank.get("guests", 0)) > 0 and (prev.is_empty() or int(rank.get("guests", 0)) > int(prev.get("guests", 0))):
		parts.append("Більше гостей: +%d на день." % int(rank["guests"]))
	if rank["hero_bonus"] > 0 and (prev.is_empty() or rank["hero_bonus"] > prev["hero_bonus"]):
		parts.append("Нові герої сильніші: +%d до характеристик." % rank["hero_bonus"])
	return " ".join(parts)


func _change_prosperity(delta: int) -> void:
	prosperity = clampi(prosperity + delta, 0, 100)


func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > LOG_KEEP:
		log_lines = log_lines.slice(log_lines.size() - LOG_KEEP)
	logged.emit(text)


# ---------- Save / load ----------

const SAVE_PATH := "user://savegame.dat"
## 2: shelves have 4 rows (the top one opens with the "Полиці" upgrade), tavern upgrades.
## 3: factions (faction_rep), suspicion, the fence, stolen goods (storage origin "k": "stolen").
## 4: swamp, lake, port: new items, the smuggler's crate (smuggle_job). Older saves load as they are.
## 5: recipe book (known_recipes, recipe_best), quality of crafted pieces (storage origin "q"). Older saves: every
##    recipe open at the time counts as found, old pieces have no quality (x1 price).
## 6: shelves without categories; 1 shelf at the start, the "Полиці" upgrade builds the others, "Горище" opens the
##    attic. Older saves get all 4 shelves and the attic one level up (they had them already).
const SAVE_VERSION := 6
## How many log lines are kept (and saved).
const LOG_KEEP := 400
## Variables that are not saved (or are saved in their own way).
const SAVE_SKIP := ["wallet", "storage", "start_mode"]


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## True if the game can be saved right now: not in a location (its screen keeps its own state) and not over.
func can_save() -> bool:
	return phase != Phase.GAME_OVER and trip.is_empty()


## Why the game cannot be saved now ("" = it can).
func save_problem() -> String:
	if phase == Phase.GAME_OVER:
		return "Гру завершено."
	if not trip.is_empty():
		return "Не можна зберегтися в поході. Повернись у таверну."
	return ""


## Writes the whole game to SAVE_PATH. Every script variable is saved by itself, so new variables
## get saved without changes here (only objects need their own lines: wallet, storage).
func save_game() -> bool:
	if not can_save():
		return false
	var data := {"version": SAVE_VERSION, "time": Time.get_datetime_string_from_system(false, true),
		"gold": wallet.total, "storage": storage.snapshot(), "vars": {}}
	for prop in get_script().get_script_property_list():
		var name: String = prop["name"]
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) or name in SAVE_SKIP:
			continue
		var value: Variant = get(name)
		if typeof(value) == TYPE_OBJECT:
			continue
		data["vars"][name] = value
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write the save: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_var(data)
	f.close()
	return true


## Reads the save file. {} if there is none or it is broken.
func _read_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = f.get_var()
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("vars"):
		return {}
	return data


## Short description of the save for the menu: {"day", "gold", "time"}. {} = no save.
func save_info() -> Dictionary:
	var data := _read_save()
	if data.is_empty():
		return {}
	return {"day": int(data["vars"].get("day", 1)), "gold": int(data.get("gold", 0)), "time": String(data.get("time", ""))}


## Loads the game from SAVE_PATH. Returns false (and changes nothing) if there is no good save.
func load_game() -> bool:
	var data := _read_save()
	if data.is_empty():
		return false
	var vars: Dictionary = data["vars"]
	# Saves made before the upgrades existed have none.
	upgrades = {}
	last_cook = {}
	# Saves made before the factions existed start with neutral factions and no suspicion.
	_reset_factions()
	# Saves made before the port existed have no smuggler's crate.
	smuggle_job = {}
	# Saves made before the recipe book: every recipe open then counts as found (set after the variables below).
	known_recipes = []
	recipe_best = {}
	for prop in get_script().get_script_property_list():
		var name: String = prop["name"]
		if not (prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) or not vars.has(name):
			continue
		var current: Variant = get(name)
		var value: Variant = vars[name]
		if current is Array and value is Array:
			current.clear()
			current.assign(value)  # keeps typed arrays typed
		elif typeof(current) == typeof(value) or current == null:
			set(name, value)
		elif typeof(current) == TYPE_INT and typeof(value) == TYPE_FLOAT:
			set(name, int(value))
	wallet = Wallet.new()
	wallet.total = int(data.get("gold", 0))
	if int(data.get("version", 1)) < 6:
		# Before 2026-11-10 every tavern had 4 shelves and the attic; "Полиці" levels opened rows (now always open).
		upgrades["shelves"] = GameData.UPGRADES["shelves"]["levels"].size()
		upgrades["attic"] = mini(int(upgrades.get("attic", 0)) + 1, GameData.UPGRADES["attic"]["levels"].size())
	apply_upgrades()
	if not vars.has("known_recipes"):
		known_recipes = GameData.START_RECIPES.duplicate()
		for rid in GameData.RECIPES:
			if recipe_open(GameData.RECIPES[rid]) and not rid in known_recipes:
				known_recipes.append(rid)
	storage = Storage.new()
	storage.restore(data["storage"])
	if int(data.get("version", 1)) < 2:
		# Version 1 shelves had 3 rows; now the grid has 4 and the old rows are the lower 3.
		for place_id in storage.layout:
			if place_id != "attic":
				for p in storage.layout[place_id]:
					p["y"] = int(p["y"]) + (GameData.SHELF_ROWS - 3)
	# The visitor at the counter is the same dictionary as their entry in the list of today's visitors.
	var i := customer_index - 1
	if not current_customer.is_empty() and i >= 0 and i < customers_today.size() and customers_today[i] == current_customer:
		customers_today[i] = current_customer
	changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
