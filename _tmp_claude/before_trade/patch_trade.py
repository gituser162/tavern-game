#!/usr/bin/env python3
"""Trade rework: visitor wants 1-2 categories and has a purse; keeper drags shelf pieces onto a sale tray,
may give -10% (reputation) or try +10% (risk). Applies targeted string patches to the CURRENT files."""
import sys, pathlib

root = pathlib.Path(sys.argv[1])
files = {}


def patch(name, old, new, count=1):
    p = root / "scripts" / name
    text = files.get(name) or p.read_text(encoding="utf-8")
    n = text.count(old)
    if n != count:
        sys.exit(f"[{name}] expected {count} match(es), got {n}:\n{old[:200]}")
    files[name] = text.replace(old, new)


# ---------------- game_data.gd ----------------
patch("game_data.gd", '''## accept: base chance the customer agrees; rep: reputation change on a sale.
const PRICE_OPTIONS := [
	{"label": "Дешево", "mult": 0.8, "accept": 1.0, "rep": 1},
	{"label": "Чесно", "mult": 1.0, "accept": 0.9, "rep": 0},
	{"label": "Дорого", "mult": 1.35, "accept": 0.6, "rep": 0},
	{"label": "Здирство", "mult": 1.8, "accept": 0.3, "rep": -2},
]
''', '''# ---------- Trading (sale tray) ----------
## A visitor wants one category from their type's tags, sometimes two (this chance).
const DEAL_SECOND_WANT_CHANCE := 0.35
## Purse (budget) = average price of the wanted categories today x random(MIN..MAX) x the type's "purse".
## Two wanted categories: x DEAL_PURSE_TWO_WANTS. Never less than the cheapest wanted item.
const DEAL_PURSE_MIN := 0.9
const DEAL_PURSE_MAX := 2.2
const DEAL_PURSE_TWO_WANTS := 1.3
## Most pieces one visitor takes at once (slots on the sale tray).
const DEAL_SLOTS := 4
## One price step the keeper can take (only -10% / +10% for now).
const DEAL_STEP := 0.10
## Reputation for a discount, per 10% off.
const DEAL_REP_PER_10_OFF := 1
## Base chance a visitor agrees to +10% (+ the type's tolerance + reputation bonus).
const DEAL_RAISE_ACCEPT := 0.7
## When the visitor says no to +10%: chance they leave offended (no sale, REP_UNHAPPY_CUSTOMER),
## otherwise they just refuse and the price stays normal.
const DEAL_RAISE_LEAVE := 0.3
''')
patch("game_data.gd", '''## Every reputation point changes the chance that a visitor agrees to a price by this much.''',
      '''## Every reputation point changes the chance that a visitor agrees to a raised price by this much.''')
for old, new in [
    ('"peasant": {"title": "Селянин", "tags": ["food", "drink"], "tolerance": 0.0,', '"peasant": {"title": "Селянин", "tags": ["food", "drink"], "tolerance": 0.0, "purse": 0.9,'),
    ('"reveler": {"title": "Гуляка", "tags": ["drink"], "tolerance": 0.05,', '"reveler": {"title": "Гуляка", "tags": ["drink"], "tolerance": 0.05, "purse": 1.1,'),
    ('"herbalist": {"title": "Травниця", "tags": ["resource", "potion"], "tolerance": 0.1,', '"herbalist": {"title": "Травниця", "tags": ["resource", "potion"], "tolerance": 0.1, "purse": 1.0,'),
    ('"merchant": {"title": "Купець", "tags": ["resource", "magic", "drink"], "tolerance": 0.2,', '"merchant": {"title": "Купець", "tags": ["resource", "magic", "drink"], "tolerance": 0.2, "purse": 1.3,'),
    ('"hero": {"title": "Шукач пригод", "tags": ["food", "drink", "potion", "gear"], "tolerance": 0.1,', '"hero": {"title": "Шукач пригод", "tags": ["food", "drink", "potion", "gear"], "tolerance": 0.1, "purse": 1.0,'),
    ('"mage": {"title": "Чарівниця", "tags": ["magic", "potion", "resource"], "tolerance": 0.2,', '"mage": {"title": "Чарівниця", "tags": ["magic", "potion", "resource"], "tolerance": 0.2, "purse": 1.2,'),
]:
    patch("game_data.gd", old, new)
patch("game_data.gd", '''## tags: item categories this visitor may want; each visitor picks one and buys only that category.''',
      '''## tags: item categories this visitor may want (each visitor picks one or two of them and buys only those).
## tolerance: how easily they agree to +10%; purse: how much money they carry (see DEAL_PURSE_*).''')

# ---------------- storage.gd ----------------
patch("storage.gd", '''## Where the piece with this uid came from: {"c": gold, "k": kind} ({} if unknown).''',
      '''## Removes the piece with this uid (from any place) and returns where it came from, or {} if there is none.
func take_uid(uid: int) -> Dictionary:
	for place_id in layout:
		var list: Array = layout[place_id]
		for i in list.size():
			if list[i]["uid"] == uid:
				var item_id: String = list[i]["id"]
				var origin: Dictionary = origins.get(uid, {"c": 0, "k": "free"})
				origins.erase(uid)
				list.remove_at(i)
				items[item_id] = count(item_id) - 1
				if items[item_id] <= 0:
					items.erase(item_id)
				return origin
	return {}


## Item id of the piece with this uid ("" if there is none).
func id_of_uid(uid: int) -> String:
	for place_id in layout:
		for p in layout[place_id]:
			if p["uid"] == uid:
				return p["id"]
	return ""


## Where the piece with this uid came from: {"c": gold, "k": kind} ({} if unknown).''')

# ---------------- game_state.gd ----------------
patch("game_state.gd", '''var awaiting_quest: bool = false
''', '''var awaiting_quest: bool = false
## Sale tray in front of the visitor: shelf pieces [{"uid", "id"}] (they stay in storage until sold),
## the price step (-1 = -10%, 0 = normal, +1 = +10%) and whether +10% was already tried with this visitor.
var deal: Array[Dictionary] = []
var deal_step: int = 0
var deal_raise_tried: bool = false
''')
patch("game_state.gd", '''func _next_customer() -> void:
	awaiting_quest = false
''', '''func _next_customer() -> void:
	awaiting_quest = false
	_clear_deal()
''')

old_trade = files.get("game_state.gd") or (root / "scripts/game_state.gd").read_text(encoding="utf-8")
start = old_trade.index("func customer_accepts(item_id: String) -> bool:")
end = old_trade.index("func refuse() -> void:")
patch("game_state.gd", old_trade[start:end], '''func customer_accepts(item_id: String) -> bool:
	return phase == Phase.SERVICE and not awaiting_quest and not brawl_active \\
			and customer_wants(GameData.ITEMS[item_id]["cat"])


## Categories the current visitor wants to buy from.
func customer_wants_list() -> Array:
	return current_customer.get("wants", [current_customer.get("tag", "")])


func customer_wants(cat: String) -> bool:
	return cat in customer_wants_list()


func customer_purse() -> int:
	return int(current_customer.get("purse", 0))


## True while the visitor waits for goods (the sale tray is in use).
func trading() -> bool:
	return phase == Phase.SERVICE and not awaiting_quest and not brawl_active and not current_customer.is_empty()


func _clear_deal() -> void:
	deal.clear()
	deal_step = 0
	deal_raise_tried = false


func deal_has(uid: int) -> bool:
	for e in deal:
		if e["uid"] == uid:
			return true
	return false


## Price of the tray at normal prices.
func deal_base() -> int:
	var total := 0
	for e in deal:
		total += item_price(e["id"])
	return total


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
	for e in deal:
		var item_id: String = e["id"]
		if storage.take_uid(e["uid"]).is_empty():
			continue
		var price := roundi(item_price(item_id) * k)
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
	_clear_deal()
	_after_customer()


''')

patch("game_state.gd", '''	Audio.play("refuse")
	var tag_name: String = GameData.CATEGORIES[current_customer["tag"]]["name"]
	if storage.ids_in_category(current_customer["tag"]).is_empty():
		_log("%s шукав товар з категорії «%s», але на складі такого немає." % [_who(), tag_name])
		var tag: String = current_customer["tag"]
		day_stats["missed"][tag] = day_stats["missed"].get(tag, 0) + 1
		day_stats["missed_gold"] += missed_sale_value(tag)
''', '''	Audio.play("refuse")
	var wants := customer_wants_list()
	var has_any := false
	var tag_names: PackedStringArray = []
	for cat in wants:
		tag_names.append("«%s»" % GameData.CATEGORIES[cat]["name"])
		if not storage.ids_in_category(cat).is_empty():
			has_any = true
	if not has_any:
		_log("%s шукав %s, але на складі такого немає." % [_who(), " або ".join(tag_names)])
		var tag: String = wants[0]
		day_stats["missed"][tag] = day_stats["missed"].get(tag, 0) + 1
		day_stats["missed_gold"] += mini(customer_purse(), missed_sale_value(tag)) if customer_purse() > 0 else missed_sale_value(tag)
''')
patch("game_state.gd", '''	_change_rep(GameData.REP_UNHAPPY_CUSTOMER)
	day_stats["refused"] += 1
	_after_customer()
''', '''	_change_rep(GameData.REP_UNHAPPY_CUSTOMER)
	day_stats["refused"] += 1
	_clear_deal()
	_after_customer()
''')
patch("game_state.gd", '''		"tag": tags[randi() % tags.size()],
		"tolerance": t["tolerance"] + randf_range(-0.1, 0.1),
	}
''', '''		"tolerance": t["tolerance"] + randf_range(-0.1, 0.1),
	}
	var wants: Array = [tags[randi() % tags.size()]]
	if tags.size() > 1 and randf() < GameData.DEAL_SECOND_WANT_CHANCE:
		var others: Array = tags.filter(func(x: String) -> bool: return x != wants[0])
		wants.append(others[randi() % others.size()])
	c["tag"] = wants[0]
	c["wants"] = wants
	c["purse"] = _roll_purse(wants, float(t.get("purse", 1.0)))
''')
patch("game_state.gd", '''## A free hero who comes to the tavern today: a known one or a new one. {} if nobody can come.''',
      '''## How much money a visitor brings: about 1-2 average items of the categories they want (see DEAL_PURSE_*).
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


## A free hero who comes to the tavern today: a known one or a new one. {} if nobody can come.''')

for name, text in files.items():
    (root / "scripts" / name).write_text(text, encoding="utf-8", newline="")
    print("patched", name)
