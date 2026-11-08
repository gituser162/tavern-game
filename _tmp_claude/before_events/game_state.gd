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
var day_stats: Dictionary = {}
## Personal actions the keeper has left today (trips to locations spend them).
var actions_left: int = GameData.ACTIONS_PER_DAY
## Result of the last trip today: {"location": id, "found": {item: n}, "left": {item: n}, "event": id}. Empty = no trip yet.
var last_trip: Dictionary = {}
## The location the keeper is in right now: {"location": id, "event": event id or "",
## "nodes": [{"item": id, "spot": Vector2 (bg pixels), "taken": bool}], "found": {item: n}}. Empty = in the tavern.
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


func new_game() -> void:
	day = 1
	wallet = Wallet.new()
	wallet.add(GameData.START_MONEY)
	reputation = GameData.START_REPUTATION
	_announced_rank = GameData.rep_rank_index(reputation)
	_best_rank = _announced_rank
	prosperity = GameData.START_PROSPERITY
	won = false
	storage = Storage.new()
	for id in GameData.START_ITEMS:
		for i in GameData.START_ITEMS[id]:
			storage.add(id)
	active_quests.clear()
	heroes.clear()
	_next_hero_id = 1
	_log("[b]Ти отримав у спадок таверну «Втомлений Грифон».[/b] Борг гільдії: %s до кінця %d-го дня." % [Wallet.format_amount(GameData.GOAL_MONEY, true), GameData.LAST_DAY])
	_start_morning()


# ---------- Reputation ----------

func rep_rank() -> Dictionary:
	return GameData.rep_rank(reputation)


func max_heroes() -> int:
	return rep_rank()["max_heroes"]


## True if the reputation is high enough for this contract / hero class / recipe entry.
func is_unlocked(entry: Dictionary) -> bool:
	return reputation >= GameData.rep_needed(entry)


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


# ---------- Prices ----------

## Sale price of an item today (before the haggling choice). Depends on city prosperity.
func item_price(item_id: String) -> int:
	return maxi(1, roundi(GameData.ITEMS[item_id]["price"] * GameData.prosperity_mult(prosperity)))


## Market price today. -1 if the item cannot be bought.
func item_cost(item_id: String) -> int:
	var cost: int = GameData.ITEMS[item_id]["cost"]
	if cost <= 0:
		return -1
	return maxi(1, roundi(cost * GameData.prosperity_mult(prosperity)))


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
	day_stats = {"income": 0, "spent": 0, "sales": 0, "refused": 0, "quest_income": 0, "trips": 0, "gathered": 0, "brewed": 0}
	_log("\n[color=gold]— День %d —[/color]" % day)
	_heal_heroes()
	_resolve_returning_quests()
	_announce_rank()
	_generate_quest_board()
	changed.emit()


## True if the keeper can open the market now (already there today, or has an action to go there).
func can_visit_market() -> bool:
	return phase == Phase.MARKET and (market_visited or actions_left >= GameData.MARKET_ACTION_COST)


## Goes to the market. The first visit of the day spends MARKET_ACTION_COST actions,
## after that the market stays open until the tavern opens. Returns true if the keeper is at the market.
func visit_market() -> bool:
	if phase != Phase.MARKET:
		return false
	if market_visited:
		return true
	if actions_left < GameData.MARKET_ACTION_COST:
		return false
	actions_left -= GameData.MARKET_ACTION_COST
	market_visited = true
	_log("Ти йдеш на міський ринок.")
	changed.emit()
	return true


## Total price of an order {item: n} at today's market prices.
func order_cost(order: Dictionary) -> int:
	var total := 0
	for id in order:
		total += item_cost(id) * int(order[id])
	return total


## How many places an order needs in every storage place: {place id: n}.
func order_places(order: Dictionary) -> Dictionary:
	var result := {}
	for id in order:
		var place := Storage.place_of(id)
		result[place] = result.get(place, 0) + int(order[id])
	return result


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
	var places := order_places(order)
	for place in places:
		if places[place] > storage.free_space(place):
			return "У сховищі «%s» вільно лише %d місць." % [GameData.STORAGES[place]["name"], storage.free_space(place)]
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
			storage.add(id)
		if int(order[id]) > 0:
			bought[id] = int(order[id])
			bought_today[id] = bought_today.get(id, 0) + int(order[id])
	day_stats["spent"] += cost
	_log("Ринок: куплено %s за %s." % [_items_text(bought), Wallet.format_amount(cost, true)])
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
	if phase != Phase.MARKET or not GameData.RECIPES.has(potion_id) or not is_unlocked(GameData.RECIPES[potion_id]):
		return false
	var recipe: Dictionary = GameData.RECIPES[potion_id]
	for ing in recipe["ingredients"]:
		if missing_ingredient(potion_id, ing) > 0:
			return false
	return true


## Brews a potion: takes the ingredients from storage and puts the potion into storage. Costs no actions.
## If the potion does not fit even after the ingredients are taken out, nothing changes.
func brew(potion_id: String) -> void:
	if not can_brew(potion_id):
		return
	var recipe: Dictionary = GameData.RECIPES[potion_id]
	var amount: int = recipe.get("amount", 1)
	var potion_name: String = GameData.ITEMS[potion_id]["name"]
	var backup := storage.snapshot()
	for ing in recipe["ingredients"]:
		for i in recipe["ingredients"][ing]:
			storage.take(ing)
	for i in amount:
		if not storage.add(potion_id):
			storage.restore(backup)
			last_brew = {"item": potion_id, "ok": false}
			_log("[color=salmon]Зварити «%s» не вийде: у сховищі «%s» немає місця.[/color]" % [potion_name, GameData.storage_name_of(potion_id)])
			changed.emit()
			return
	day_stats["brewed"] += amount
	last_brew = {"item": potion_id, "ok": true}
	_log("Ти вариш «%s» (%s). Готово: %d шт." % [potion_name, _items_text(recipe["ingredients"]), amount])
	changed.emit()


# ---------- Locations ----------

func can_travel() -> bool:
	return phase == Phase.MARKET and trip.is_empty() and actions_left >= GameData.LOCATION_ACTION_COST


## True if the keeper can go to this location now (has an action and it is not closed today).
func can_travel_to(location_id: String) -> bool:
	return can_travel() and not location_id in closed_locations and not location_id in visited_locations


## Goes to a location: spends an action, rolls an event and lays out the resources on the location screen.
## The player picks them up with gather(); leave_location() returns to the tavern.
func travel(location_id: String) -> void:
	if not can_travel_to(location_id) or not GameData.LOCATIONS.has(location_id):
		return
	var loc: Dictionary = GameData.LOCATIONS[location_id]
	actions_left -= GameData.LOCATION_ACTION_COST
	day_stats["trips"] += 1
	visited_locations.append(location_id)
	var entry := _roll_location_event(loc)
	var event_id: String = entry.get("id", "")
	var event: Dictionary = GameData.LOCATION_EVENTS.get(event_id, {}).duplicate()
	if entry.has("text"):
		event["text"] = entry["text"]
	trip = {"location": location_id, "event": event_id, "event_text": event.get("text", ""), "nodes": [], "found": {}}
	if event.get("effect", "") == "expel":
		# Driven out: the action is lost, nothing is gathered, no way back until tomorrow.
		closed_locations.append(location_id)
		_log("Похід: %s. [color=salmon]%s![/color] %s" % [loc["name"], event["name"], event["text"]])
		changed.emit()
		return
	var rolled := _roll_location_loot(loc, event.get("mult", 1) if event.get("effect", "") == "loot_mult" else 1)
	var spots: Array = loc["spots"].duplicate()
	spots.shuffle()
	for i in mini(rolled.size(), spots.size()):
		var spot := Vector2(spots[i][0] + randi_range(-3, 3), spots[i][1] + randi_range(-2, 2))
		trip["nodes"].append({"item": rolled[i], "spot": spot, "taken": false})
	if not event.is_empty():
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
func _roll_location_loot(loc: Dictionary, mult: int) -> Array[String]:
	var rolled: Array[String] = []
	if loc.has("count"):
		var total := 0.0
		for entry in loc["loot"]:
			total += entry["weight"]
		for i in randi_range(loc["count"][0], loc["count"][1]) * mult:
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
	if node["taken"] or not storage.add(node["item"]):
		return false
	node["taken"] = true
	trip["found"][node["item"]] = trip["found"].get(node["item"], 0) + 1
	day_stats["gathered"] += 1
	changed.emit()
	return true


## Returns from the location to the tavern. What was not picked up stays there.
func leave_location() -> void:
	if trip.is_empty():
		return
	var loc: Dictionary = GameData.LOCATIONS[trip["location"]]
	var left := {}
	for node in trip["nodes"]:
		if not node["taken"]:
			left[node["item"]] = left.get(node["item"], 0) + 1
	var found: Dictionary = trip["found"]
	last_trip = {"location": trip["location"], "found": found, "left": left, "event": trip["event"]}
	var expelled: bool = GameData.LOCATION_EVENTS.get(trip["event"], {}).get("effect", "") == "expel"
	trip = {}
	if not expelled:
		var text := "Похід: %s. " % loc["name"]
		text += ("Зібрано: %s." % _items_text(found)) if not found.is_empty() else "Нічого не зібрано."
		if not left.is_empty():
			text += " [color=salmon]Залишено в локації: %s.[/color]" % _items_text(left)
		_log(text)
	changed.emit()


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
	for i in GameData.CUSTOMERS_PER_DAY:
		customers_today.append(_make_customer(heroes_today))
	customer_index = 0
	_log("Двері таверни відчинено.")
	_next_customer()


# ---------- Service ----------

func _next_customer() -> void:
	awaiting_quest = false
	if customer_index >= customers_today.size():
		_end_day()
		return
	current_customer = customers_today[customer_index]
	customer_index += 1
	changed.emit()


## True if the current visitor is willing to buy this item (its category matches the visitor's tag).
func customer_accepts(item_id: String) -> bool:
	return phase == Phase.SERVICE and not awaiting_quest \
			and GameData.ITEMS[item_id]["cat"] == current_customer.get("tag", "")


func sale_price(item_id: String, option_index: int) -> int:
	return maxi(1, roundi(item_price(item_id) * GameData.PRICE_OPTIONS[option_index]["mult"]))


func sale_chance(option_index: int) -> float:
	var opt: Dictionary = GameData.PRICE_OPTIONS[option_index]
	var chance: float = opt["accept"] + current_customer["tolerance"] + reputation * GameData.REP_SALE_BONUS_PER_POINT
	return clampf(chance, 0.05, 1.0)


func serve(item_id: String, option_index: int) -> void:
	if not customer_accepts(item_id) or storage.count(item_id) <= 0:
		return
	var who := _who()
	var item_name: String = GameData.ITEMS[item_id]["name"]
	if randf() <= sale_chance(option_index):
		var price := sale_price(item_id, option_index)
		storage.take(item_id)
		wallet.add(price)
		day_stats["income"] += price
		day_stats["sales"] += 1
		_change_rep(GameData.PRICE_OPTIONS[option_index]["rep"])
		_log("%s купує «%s» за %s" % [who, item_name, Wallet.format_amount(price, true)])
	else:
		_change_rep(GameData.REP_UNHAPPY_CUSTOMER)
		_log("%s обурено пирхає через ціну і йде геть." % who)
		day_stats["refused"] += 1
		_next_customer()
		return
	_after_customer()


func refuse() -> void:
	if phase != Phase.SERVICE or awaiting_quest:
		return
	var tag_name: String = GameData.CATEGORIES[current_customer["tag"]]["name"]
	if storage.ids_in_category(current_customer["tag"]).is_empty():
		_log("%s шукав товар з категорії «%s», але на складі такого немає." % [_who(), tag_name])
	else:
		_log("Ти відмовляєш %s." % current_customer["name"])
	_change_rep(GameData.REP_UNHAPPY_CUSTOMER)
	day_stats["refused"] += 1
	_after_customer()


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
		result.append_array(storage.ids_in_category(cat))
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
	if item_id != "":
		storage.take(item_id)
	quest_board.remove_at(quest_index)
	var job := quest.duplicate()
	job["hero_id"] = hero["id"]
	job["hero"] = hero["name"]
	job["chance"] = quest_chance(quest, item_id)
	job["item"] = item_id
	job["return_day"] = day + int(quest["days"])
	active_quests.append(job)
	hero["status"] = "quest"
	hero["quest"] = quest["title"]
	var text := "%s береться за контракт «%s» (%s, %d дн.)." % [_who(), quest["title"], GameData.CONTRACT_TIERS[quest["tier"]]["name"].to_lower(), quest["days"]]
	if item_id != "":
		text += " З собою: «%s»." % GameData.ITEMS[item_id]["name"]
	_log(text)
	_next_customer()


func skip_quest() -> void:
	if awaiting_quest:
		_next_customer()


func _generate_quest_board() -> void:
	quest_board.clear()
	var ids: Array = unlocked_ids(GameData.CONTRACTS)
	ids.shuffle()
	var picked: Array = []
	# One contract of every tier first, so there is always something easy and something big.
	for tier in GameData.CONTRACT_TIERS:
		for id in ids:
			if GameData.CONTRACTS[id]["tier"] == tier and not id in picked:
				picked.append(id)
				break
	for id in ids:
		if picked.size() >= GameData.CONTRACTS_PER_DAY:
			break
		if not id in picked:
			picked.append(id)
	for id in picked:
		quest_board.append(_make_contract(id))


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
	}


func _heal_heroes() -> void:
	for h in heroes:
		if h["status"] == "injured" and day >= h["injured_until"]:
			h["status"] = "free"
			_log("%s одужав і знову шукає роботу." % h["name"])


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
		if randf() <= q["chance"]:
			wallet.add(q["reward"])
			day_stats["quest_income"] += q["reward"]
			_change_rep(tier["rep"])
			_change_prosperity(GameData.PROSPERITY_ON_QUEST_SUCCESS)
			hero["status"] = "free"
			hero["done"] = hero.get("done", 0) + 1
			var text := "[color=lime]%s виконав контракт «%s»! Твоя частка: %s. Репутація +%d, процвітання +%d.[/color]" % [q["hero"], q["title"], Wallet.format_amount(q["reward"], true), tier["rep"], GameData.PROSPERITY_ON_QUEST_SUCCESS]
			if item_back:
				text += " Повертає «%s»%s." % [GameData.ITEMS[item_id]["name"], _store_or_sell(item_id)]
			for entry in q["loot"]:
				if randf() <= entry.get("chance", 1.0):
					for i in randi_range(entry["min"], entry["max"]):
						text += " Трофей: «%s»%s." % [GameData.ITEMS[entry["item"]]["name"], _store_or_sell(entry["item"])]
			_log(text)
		elif randf() <= tier["death"]:
			_change_rep(GameData.REP_HERO_DIED)
			_change_prosperity(GameData.PROSPERITY_ON_HERO_DEATH)
			heroes.erase(hero)
			var text := "[color=salmon]%s загинув на контракті «%s». У залі шепочуться... Репутація %d.[/color]" % [q["hero"], q["title"], GameData.REP_HERO_DIED]
			if item_back:
				text += " [color=salmon]«%s» втрачено разом із героєм.[/color]" % GameData.ITEMS[item_id]["name"]
			_log(text)
		else:
			_change_rep(GameData.REP_HERO_INJURED)
			hero["status"] = "injured"
			hero["injured_until"] = day + GameData.INJURY_DAYS
			var text := "[color=orange]%s провалив контракт «%s» і ледве дістався назад, поранений. Відпочиватиме %d дн. Репутація %d.[/color]" % [q["hero"], q["title"], GameData.INJURY_DAYS, GameData.REP_HERO_INJURED]
			if item_back:
				text += " Повертає «%s»%s." % [GameData.ITEMS[item_id]["name"], _store_or_sell(item_id)]
			_log(text)
	active_quests = still_out


## Puts an item that a hero brought into its storage place. If there is no room, sells it at once.
## Returns a short note for the log ("" if it was stored).
func _store_or_sell(item_id: String) -> String:
	if storage.add(item_id):
		return ""
	var money := maxi(1, roundi(item_price(item_id) * GameData.OVERFLOW_SALE_SHARE))
	wallet.add(money)
	day_stats["quest_income"] += money
	return " (у сховищі «%s» немає місця, продано за %s)" % [GameData.storage_name_of(item_id), Wallet.format_amount(money, true)]


# ---------- Evening ----------

func _end_day() -> void:
	_announce_rank()
	wallet.add(-GameData.DAILY_UPKEEP)
	_log("Вечір. Утримання таверни: −%s." % Wallet.format_amount(GameData.DAILY_UPKEEP, true))
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
		"tag": tags[randi() % tags.size()],
		"tolerance": t["tolerance"] + randf_range(-0.1, 0.1),
	}
	if not hero.is_empty():
		heroes_today.append(hero["id"])
		c["hero_id"] = hero["id"]
		c["name"] = hero["name"]
		c["portrait"] = hero.get("portrait", "")
		c["title"] = GameData.HERO_CLASSES[hero["class"]]["name"]
		c["asks_contract"] = randf() < GameData.HERO_ASKS_CHANCE
	return c


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
	var prev: Dictionary = GameData.REP_RANKS[rank_index - 1] if rank_index > 0 else {}
	if prev.is_empty() or rank["max_heroes"] > prev["max_heroes"]:
		parts.append("Героїв у місті до %d." % rank["max_heroes"])
	if rank["hero_bonus"] > 0 and (prev.is_empty() or rank["hero_bonus"] > prev["hero_bonus"]):
		parts.append("Нові герої сильніші: +%d до характеристик." % rank["hero_bonus"])
	return " ".join(parts)


func _change_prosperity(delta: int) -> void:
	prosperity = clampi(prosperity + delta, 0, 100)


func _log(text: String) -> void:
	logged.emit(text)
