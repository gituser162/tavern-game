extends RefCounted
## The player's purse. Keeps one number in the smallest coin from GameData.CURRENCIES
## (now only gold), so adding another coin later needs no changes here.

const GameData := preload("res://scripts/game_data.gd")

## Total value in the smallest coin. May go below zero (debt) after evening upkeep.
var total: int = 0


func add(amount: int, currency_id: String = "gold") -> void:
	total += amount * GameData.currency_value(currency_id)


func can_afford(amount: int) -> bool:
	return amount <= total


## Takes the amount if there is enough money. Returns false and changes nothing otherwise.
func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	total -= amount
	return true


## How many of each coin the purse holds, e.g. {"gold": 12}.
func coins() -> Dictionary:
	return split(total)


func format(rich: bool = false) -> String:
	return format_amount(total, rich)


static func split(amount: int) -> Dictionary:
	var result := {}
	var rest := absi(amount)
	for c in GameData.CURRENCIES:
		var value: int = c["value"]
		result[c["id"]] = rest / value
		rest = rest % value
	return result


## Human-readable amount. Zero coins are left out.
## rich = false: plain text "12 зол." (for print/debug).
## rich = true: BBCode with the coin icon, for RichTextLabel: "12 [gold icon]".
static func format_amount(amount: int, rich: bool = false) -> String:
	var parts: PackedStringArray = []
	var split_coins := split(amount)
	for c in GameData.CURRENCIES:
		var count: int = split_coins[c["id"]]
		if count == 0:
			continue
		parts.append(_coin_text(count, c, rich))
	if parts.is_empty():
		parts.append(_coin_text(0, GameData.CURRENCIES[GameData.CURRENCIES.size() - 1], rich))
	return ("−" if amount < 0 else "") + " ".join(parts)


static func _coin_text(count: int, currency: Dictionary, rich: bool) -> String:
	if not rich:
		return "%d %s" % [count, currency["short"]]
	var size: int = GameData.COIN_ICON_SIZE
	return "%d [img=%dx%d]%s[/img]" % [count, size, size, currency["icon"]]
