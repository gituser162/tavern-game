extends RefCounted
## Static game data and balance constants. Tweak numbers here.

# ---------- Currency ----------
## The game uses one coin: gold. Money is stored as a whole number of gold coins.
## The list is kept so another coin can be added later: "value" = how many of the smallest coin it is worth.
const CURRENCIES := [
	{"id": "gold", "name": "золотий", "plural": "золоті", "short": "зол.", "icon": "res://assets/coins/gold.png", "value": 1, "color": "f2c14e"},
]
const GOLD := 1
const COIN_ICON_SIZE := 24

# ---------- Balance (money values are in gold) ----------
const START_MONEY := 60 * GOLD
const DAILY_UPKEEP := 10 * GOLD
const CUSTOMERS_PER_DAY := 6
const LAST_DAY := 20
const GOAL_MONEY := 1500 * GOLD

# ---------- City prosperity (GDD 14.14) ----------
const START_PROSPERITY := 45
## Prices are multiplied by PRICE_MULT_MIN at prosperity 0 and PRICE_MULT_MAX at 100 (x1.0 at 50).
const PRICE_MULT_MIN := 0.5
const PRICE_MULT_MAX := 1.5
const PROSPERITY_ON_QUEST_SUCCESS := 1
const PROSPERITY_ON_HERO_DEATH := -1
## [lowest value, name]. Checked from the top, the first one that fits wins.
const PROSPERITY_LEVELS := [
	[90, "Золота епоха"],
	[75, "Процвітання"],
	[60, "Розвиток"],
	[40, "Звичайне місто"],
	[25, "Бідність"],
	[10, "Занепад"],
	[0, "Руїни"],
]

# ---------- Reputation ----------
## One reputation scale for the whole tavern (MVP). It is kept within REP_MIN..REP_MAX.
const REP_MIN := -20
const REP_MAX := 100
const START_REPUTATION := 0
## Every reputation point changes the chance that a visitor agrees to a raised price by this much.
const REP_SALE_BONUS_PER_POINT := 0.003
## Reputation lost when a visitor leaves unhappy (refused, or angry at the price).
const REP_UNHAPPY_CUSTOMER := -1
## Reputation for a failed contract: the hero came back injured / died.
const REP_HERO_INJURED := -2
const REP_HERO_DIED := -5
## Ranks from the lowest. min: lowest reputation of the rank.
## max_heroes: how many heroes the town can have at this rank.
## hero_bonus: extra stat points a NEW hero gets (spread randomly over his stats).
## Contracts, hero classes and recipes are unlocked by their own "rep" value (see below).
const REP_RANKS := [
	{"min": -20, "name": "Погана слава", "max_heroes": 3, "hero_bonus": 0},
	{"min": -5, "name": "Невідома корчма", "max_heroes": 4, "hero_bonus": 0},
	{"min": 10, "name": "Знайома місцевим", "max_heroes": 5, "hero_bonus": 0},
	{"min": 25, "name": "Шанована таверна", "max_heroes": 6, "hero_bonus": 2},
	{"min": 45, "name": "Відома в краї", "max_heroes": 7, "hero_bonus": 4},
	{"min": 70, "name": "Легендарна таверна", "max_heroes": 8, "hero_bonus": 6},
]

# ---------- Storage ----------
## The tavern has several separate storage places. Each one keeps only its categories ("cats")
## and holds "capacity" pieces (any item = 1 piece). Every category must be in exactly one place.
## Capacities are fixed for now (no upgrades in MVP). Change, add or rename places here; the UI picks them up.
## Storage places. Each is a grid of cells: `surfaces` levels (2 = the middle shelf and the floor plank under the
## counter), each `cols` x `rows` cells. Items take cells by their shape (ITEM_SIZES), like a puzzle.
## All four shelves under the counter have the same grid (the narrowest compartment fits 8 cells of 8 px).
const SHELF_COLS := 8
const SHELF_ROWS := 3
## The attic is one big grid (its own window, no shelves in the background).
const ATTIC_COLS := 12
const ATTIC_ROWS := 4
const STORAGES := {
	"pantry": {"name": "Полиця з їжею", "short": "Їжа", "cats": ["food"], "cols": SHELF_COLS, "rows": SHELF_ROWS,
		"desc": "Хліб, смажена курка й горщики рагу для голодних гостей."},
	"cellar": {"name": "Полиця з напоями", "short": "Напої", "cats": ["drink"], "cols": SHELF_COLS, "rows": SHELF_ROWS,
		"desc": "Барильця елю, медовуха в розі й пляшки вина."},
	"cabinet": {"name": "Полиця із зіллям", "short": "Зілля", "cats": ["potion"], "cols": SHELF_COLS, "rows": SHELF_ROWS,
		"desc": "Готові зілля, зварені в ступці."},
	"chest": {"name": "Полиця зі спорядженням", "short": "Спорядження", "cats": ["gear", "magic"], "cols": SHELF_COLS, "rows": SHELF_ROWS,
		"desc": "Спорядження для героїв і магічні речі. Усе, що герої можуть узяти з собою і повернути."},
	"attic": {"name": "Горище", "short": "Горище", "cats": ["resource"], "cols": ATTIC_COLS, "rows": ATTIC_ROWS, "surfaces": 1,
		"desc": "Під дахом сушаться трави й коріння, у кутку лежать мішки з кістками, прахом і кристалами."},
}
## Shape of every item on the shelves, in cells (w, h). Items not listed take one cell.
const ITEM_SIZES := {
	"ale": Vector2i(2, 2), "mead": Vector2i(2, 1), "wine": Vector2i(1, 2),
	"bread": Vector2i(1, 1), "chicken": Vector2i(2, 1), "stew": Vector2i(2, 2),
	"heal_potion": Vector2i(1, 1), "antidote": Vector2i(1, 2), "strength_potion": Vector2i(2, 2),
	"shield": Vector2i(2, 2), "chainmail": Vector2i(2, 3), "axe": Vector2i(1, 3),
	"fire_scroll": Vector2i(2, 1), "moon_amulet": Vector2i(1, 2), "sapphire_ring": Vector2i(1, 1),
}
## When a returning hero brings an item and the storage is full, it is sold for this share of its price.
const OVERFLOW_SALE_SHARE := 0.5

# ---------- Items ----------
## tag: what a visitor shows above their head; only items of that category can be sold to them.
const CATEGORIES := {
	"food": {"name": "Їжа", "tag": "ЇЖА", "color": "c07a3e"},
	"drink": {"name": "Напої", "tag": "НАПОЇ", "color": "c9a03a"},
	"resource": {"name": "Ресурси", "tag": "РЕСУРСИ", "color": "6f9a45"},
	"potion": {"name": "Зілля", "tag": "ЗІЛЛЯ", "color": "c4466a"},
	"gear": {"name": "Спорядження героїв", "tag": "СПОРЯДЖЕННЯ", "color": "5a86b8"},
	"magic": {"name": "Магічні речі", "tag": "МАГІЯ", "color": "8a62d0"},
}

## Where items come from (GDD answers).
const SOURCES := {
	"market": "ринок",
	"location": "збір у локаціях",
	"craft": "варка зілля",
	"contract": "нагорода з контрактів",
}

## Icon sheets in assets/: every sheet is a 14 x 8 grid of icons.
const ICON_SHEETS := {
	1: "res://assets/icons-1.png",
	2: "res://assets/icons-2.png",
	3: "res://assets/icons-3.png",
	4: "res://assets/icons-4.png",
	5: "res://assets/icons-5.png",
}
const ICON_SHEET_COLUMNS := 14
const ICON_SHEET_ROWS := 8

## price: base sale price at prosperity 50; cost: market (or brewing) price at prosperity 50.
## Both scale with prosperity. icon: [sheet, column, row], or a path to a separate icon file.
## hero_stats: stat points a hero gets if the item is given before a contract (see HERO_STATS).
## Potions are used up on the contract; gear and magic items come back if the hero survives.
const ITEMS := {
	# Food: bought on the market.
	"bread": {"name": "Житній хліб", "cat": "food", "price": 3, "cost": 1, "icon": [5, 13, 4],
		"sources": ["market"], "desc": "Свіжий, ще теплий. Селяни беруть його до всього."},
	"chicken": {"name": "Смажена курка", "cat": "food", "price": 8, "cost": 3, "icon": [5, 0, 0],
		"sources": ["market"], "desc": "Хрустка шкірка, часник і трохи меду."},
	"stew": {"name": "Рагу з оленини", "cat": "food", "price": 11, "cost": 4, "icon": [5, 0, 2],
		"sources": ["market"], "desc": "Густе рагу в глиняному горщику. Тримає до вечора."},
	# Drinks.
	"ale": {"name": "Темний ель", "cat": "drink", "price": 4, "cost": 1, "icon": [4, 0, 0],
		"sources": ["market"], "desc": "Гірковатий, з пінкою на два пальці."},
	"mead": {"name": "Медовуха в розі", "cat": "drink", "price": 7, "cost": 3, "icon": [4, 5, 0],
		"sources": ["market"], "desc": "Солодка й підступна. Північани п'ють її з рогу."},
	"wine": {"name": "Ельфійське вино", "cat": "drink", "price": 15, "cost": 6, "icon": [4, 12, 2],
		"sources": ["market"], "desc": "Пахне лісом після дощу. Купці платять не торгуючись."},
	# Resources: gathered in locations (see LOCATIONS) and, some of them, bought on the market.
	# cost -1 = not sold on the market, only gathered.
	"herbs": {"name": "Лікарські трави", "cat": "resource", "price": 3, "cost": 2, "icon": [4, 0, 4],
		"sources": ["location", "market"], "desc": "Пучок м'яти, звіробою й подорожника."},
	"berries": {"name": "Лісові ягоди", "cat": "resource", "price": 4, "cost": -1, "icon": [4, 0, 6],
		"sources": ["location"], "desc": "Чорниці з галявини за старим дубом. Травниці додають їх у настоянки."},
	"burdock": {"name": "Корінь лопуха", "cat": "resource", "price": 5, "cost": -1, "icon": [4, 1, 6],
		"sources": ["location"], "desc": "Товстий і гіркий. Звичайне коріння, але без нього не обходиться жодне зілля."},
	"mandrake": {"name": "Корінь мандрагори", "cat": "resource", "price": 9, "cost": 5, "icon": [1, 0, 4],
		"sources": ["location", "market"], "desc": "Викопаний на світанку. Кажуть, при цьому він кричить."},
	"bones": {"name": "Старі кістки", "cat": "resource", "price": 6, "cost": -1, "icon": [2, 12, 4],
		"sources": ["location"], "desc": "Пожовклі від часу. Некроманти й знахарі не питають, чиї вони."},
	"grave_dust": {"name": "Могильний прах", "cat": "resource", "price": 8, "cost": -1, "icon": [1, 5, 3],
		"sources": ["location"], "desc": "Сірий порох зі старих склепів. Холодить пальці навіть крізь рукавицю."},
	"ether_essence": {"name": "Ефірна есенція", "cat": "resource", "price": 28, "cost": -1, "icon": [2, 3, 0],
		"sources": ["location"], "desc": "Блакитний туман, що сам збирається над могилами опівночі. Рідкісна і дуже цінна."},
	"crystal": {"name": "Місячний кристал", "cat": "resource", "price": 22, "cost": 13, "icon": [1, 2, 4],
		"sources": ["market", "contract"], "desc": "Ледь світиться в темряві. Цінний для магів і алхіміків."},
	# Found only during the forest event "glow_mushrooms". The icon is its own file (assets/icons/).
	"glow_mushroom": {"name": "Світні гриби", "cat": "resource", "price": 16, "cost": -1, "icon": "res://assets/icons/glow_mushroom.png",
		"sources": ["location"], "desc": "Сяють блакитним світлом лише кілька хвилин після того, як виросли. Чарівниці платять за них щедро."},
	# Potions: brewed by the player from ingredients in storage (see RECIPES). Not sold on the market.
	"heal_potion": {"name": "Зілля лікування", "cat": "potion", "price": 26, "cost": -1, "icon": [1, 11, 1],
		"sources": ["craft"], "hero_stats": {"end": 3}, "desc": "Затягує рани за кілька хвилин. Героям потрібне завжди."},
	"antidote": {"name": "Протиотрута", "cat": "potion", "price": 18, "cost": -1, "icon": [1, 10, 0],
		"sources": ["craft"], "hero_stats": {"end": 2}, "desc": "Від укусів павуків, змій і поганого вина."},
	"strength_potion": {"name": "Зілля сили", "cat": "potion", "price": 34, "cost": -1, "icon": [1, 9, 1],
		"sources": ["craft"], "hero_stats": {"str": 4}, "desc": "На годину дає силу трьох ковалів."},
	# Hero gear: bought on the market or won on contracts.
	"shield": {"name": "Дубовий щит", "cat": "gear", "price": 45, "cost": 30, "icon": [3, 2, 0],
		"sources": ["market", "contract"], "hero_stats": {"end": 3}, "desc": "Окутий залізом. Витримає удар огра, але не два."},
	"chainmail": {"name": "Кольчуга", "cat": "gear", "price": 70, "cost": 48, "icon": [3, 10, 0],
		"sources": ["market", "contract"], "hero_stats": {"end": 4}, "desc": "Тисячі кілець, сплетених гномом-майстром."},
	"axe": {"name": "Бойова сокира", "cat": "gear", "price": 55, "cost": 36, "icon": [2, 0, 7],
		"sources": ["market", "contract"], "hero_stats": {"str": 3}, "desc": "Важка, але щойно нагострена."},
	# Magic items: bought on the market or won on contracts.
	"fire_scroll": {"name": "Сувій вогню", "cat": "magic", "price": 60, "cost": 40, "icon": [2, 9, 1],
		"sources": ["market", "contract"], "hero_stats": {"int": 4}, "desc": "Одне слово, і перед тобою стіна полум'я."},
	"moon_amulet": {"name": "Амулет місяця", "cat": "magic", "price": 90, "cost": 65, "icon": [2, 11, 6],
		"sources": ["market", "contract"], "hero_stats": {"luck": 3}, "desc": "Вночі власник бачить, як удень."},
	"sapphire_ring": {"name": "Сапфіровий перстень", "cat": "magic", "price": 120, "cost": -1, "icon": [2, 10, 7],
		"sources": ["contract"], "hero_stats": {"cha": 2, "luck": 2}, "desc": "Камінь холодний навіть у вогні. Не продається на ринку."},
}

# ---------- Locations ----------
## Personal actions of the tavern keeper per day. A trip to a location costs LOCATION_ACTION_COST.
const ACTIONS_PER_DAY := 5
const LOCATION_ACTION_COST := 1
## A visit to the market (GDD: "Закупитися на ринку") costs this many actions.
## After the first visit the market stays open for the rest of the morning: the window can be closed and opened again for free.
const MARKET_ACTION_COST := 1

## Places the keeper can visit in the morning. Each location has its own screen (bg, 320x180 pixel art)
## with the resources lying on it: the player clicks them to gather (see GameState.travel / gather).
## Loot, two ways:
##   "count": [min, max] total pieces per trip, each one picked from "loot" by "weight";
##   or without "count": every "loot" entry is rolled: with "chance" (1.0 if missing) you find min..max pieces.
## spots: where resources can lie, in background pixels (320x180). A spot is used once per trip.
## events: rolled once on arrival (at most one happens), see LOCATION_EVENTS.
## Whatever does not fit into its storage place cannot be picked up and stays in the location.
const LOCATIONS := {
	"forest": {"name": "Ліс", "icon": [4, 0, 4], "bg": "res://assets/backgrounds/forest.png",
		"desc": "Старий ліс за млином. Трави, ягоди й коріння для травниць і алхіміків.",
		"count": [1, 3],
		"loot": [
			{"item": "herbs", "weight": 4},
			{"item": "berries", "weight": 3},
			{"item": "burdock", "weight": 2},
			{"item": "mandrake", "weight": 1},
		],
		"spots": [[58, 116], [86, 136], [40, 150], [104, 156], [122, 126], [96, 112], [206, 118],
			[226, 134], [252, 130], [270, 146], [214, 158], [286, 162], [140, 146], [62, 166]],
		"events": [
			{"id": "wild_animal", "chance": 0.05, "eyes": [[22, 120], [28, 120], [284, 117], [290, 117]]},
			{"id": "magic_rain", "chance": 0.05},
			{"id": "glow_mushrooms", "chance": 0.05},
		]},
	"graveyard": {"name": "Кладовище", "icon": [2, 13, 4], "bg": "res://assets/backgrounds/graveyard.png",
		"desc": "Покинуте кладовище на пагорбі. Кістки, прах і, якщо пощастить, ефірна есенція.",
		# Balance 2026-11-06: 1-3 pieces like the forest (was ~4 pieces and ~32 gold a trip, it flooded the attic).
		"count": [1, 3],
		"loot": [
			{"item": "bones", "weight": 5},
			{"item": "grave_dust", "weight": 3},
			{"item": "ether_essence", "weight": 1},
		],
		"spots": [[40, 122], [94, 118], [132, 110], [166, 136], [204, 124], [266, 130], [40, 166],
			[100, 160], [140, 152], [256, 166], [200, 150], [120, 132], [282, 140]],
		"events": [
			# Only while the skeleton-hunting contract is on the board or being done (user, 2026-11-06).
			{"id": "risen_dead", "chance": 0.0, "eyes": [[73, 128], [77, 128], [228, 136], [232, 136], [154, 118], [157, 118]],
				"eyes_color": "7dff8a", "always_if_contract": ["skeletons"]},
			{"id": "magic_rain", "chance": 0.05,
				"text": "Над кладовищем пройшов магічний дощ: земля сама виштовхнула кістки й прах нагору. Ресурсів удвічі більше!"},
			# The grave is drawn at "grave" (bg pixels).
			{"id": "dug_grave", "chance": 0.05, "grave": [190, 132]},
			{"id": "fog", "chance": 0.05},
		]},
}

## Events that can happen on arrival at a location.
## effect "expel": the keeper is driven out, the action is lost, the location is closed until the next day.
## effect "loot_mult": the amount of generated resources is multiplied by "mult".
## effect "timed_rare": besides the usual loot, "amount" [min, max] pieces of "item" grow there; each one
##   vanishes "seconds" after the event message is closed if it is not picked up.
## effect "grave": besides the usual loot there is a dug-up grave. Searching it (GameState.search_grave) gives
##   gold "gold" [min, max] with "gold_chance", otherwise one item from "items" {item: weight}; with "rep_chance"
##   somebody sees it and the reputation changes by "rep".
## effect "fog": the resources are hidden until the cursor is over them; "extra" more pieces than usual.
## In a location's "events" list an entry can also have: "text" (overrides the event text for this location),
## "eyes" + "eyes_color" (glowing eyes drawn on the bg, bg pixels), "always_if_contract" (contract ids:
## while one of them is on the board or being done by a hero, the event always happens).
const LOCATION_EVENTS := {
	"wild_animal": {"name": "Дика тварина", "effect": "expel",
		"text": "З хащі вийшов розлючений ведмідь. Ти ледве встиг утекти! Похід зірвано, а в ліс сьогодні краще не повертатися."},
	"risen_dead": {"name": "Воскреслі мерці", "effect": "expel",
		"text": "Земля між могилами заворушилась, і з неї полізли скелети. Ти ледве встиг утекти! Похід зірвано, а на кладовище сьогодні краще не повертатися."},
	"magic_rain": {"name": "Магічний дощ", "effect": "loot_mult", "mult": 2,
		"text": "Над лісом пройшов магічний дощ: трави й коріння проросли просто на очах. Ресурсів удвічі більше!"},
	"glow_mushrooms": {"name": "Світні гриби", "effect": "timed_rare", "item": "glow_mushroom", "amount": [1, 2], "seconds": 6.0,
		"text": "Під старим дубом проросли світні гриби! Вони сяють лише кілька секунд, тож поспіши їх зібрати."},
	"dug_grave": {"name": "Розкопана могила", "effect": "grave",
		"gold": [15, 35], "gold_chance": 0.6, "items": {"ether_essence": 3, "crystal": 2},
		"rep_chance": 0.5, "rep": -1,
		"text": "Хтось уночі розкопав стару могилу і втік, не докопавши. Усередині ще може щось лежати... Але якщо хтось побачить, як ти там нишпориш, піде поголос."},
	"fog": {"name": "Туман", "effect": "fog", "extra": 1,
		"text": "Кладовище затягло густим туманом. Ресурси видно, лише коли наведеш на них курсор. Зате в тумані їх лежить більше."},
}

# ---------- Tavern events ----------
## Rolled every morning (at most one morning event a day: first "tax_collector", then "fair").
## from_day: not before this day. cooldown: days before the same event can happen again.
## Tax: takes "rate" of the gold; a tavern with a good name pays less: "rates" [lowest reputation, rate],
## the first one that fits wins.
const TAX_COLLECTOR := {"name": "Збирач податків", "chance": 0.06, "from_day": 3, "cooldown": 5,
	"rates": [[70, 0.04], [45, 0.06], [25, 0.08], [-100, 0.10]]}
## Fair: market prices x"market_mult" and "extra_customers" more visitors for one day.
const FAIR := {"name": "Міський ярмарок", "chance": 0.08, "from_day": 2, "cooldown": 3,
	"market_mult": 0.8, "extra_customers": 2}
## Brawl: rolled when the tavern opens; happens between two visitors.
## Stop it: the next "lost_customers" visitors leave while you restore order.
## Let it go: reputation changes by "rep".
const BRAWL := {"name": "Бійка в залі", "chance": 0.08, "lost_customers": 1, "rep": -3}

# ---------- Alchemy ----------
## Brewing is done in the morning and costs no actions.
## Every recipe: ingredients {item: how many} are taken from storage
## and "amount" pieces of the potion are put into storage (brewing fails if they do not fit).
## Change, add or remove recipes here; the UI picks them up by itself.
## rep: reputation needed to learn the recipe (no "rep" = known from the start).
const RECIPES := {
	"heal_potion": {"ingredients": {"herbs": 2, "berries": 1, "burdock": 1}, "amount": 1},
	"antidote": {"ingredients": {"herbs": 1, "berries": 1, "bones": 1}, "amount": 1, "rep": 10},
	"strength_potion": {"ingredients": {"mandrake": 1, "grave_dust": 1, "burdock": 1}, "amount": 1, "rep": 25},
}


## The mortar on the main screen that opens the alchemy window: [sheet, column, row].
const ALCHEMY_ICON := [1, 9, 5]


## Items that are given to a hero and come back if the hero survives.
const RETURNING_CATEGORIES := ["gear", "magic"]
## Categories a hero can take on a contract.
const HERO_ITEM_CATEGORIES := ["potion", "gear", "magic"]

# ---------- Trading (sale tray) ----------
## A visitor wants one category from their type's tags, sometimes two (this chance).
const DEAL_SECOND_WANT_CHANCE := 0.35
## Purse (budget) = average price of the wanted categories today x random(MIN..MAX) x the type's "purse".
## Two wanted categories: x DEAL_PURSE_TWO_WANTS. Never less than the cheapest wanted item.
const DEAL_PURSE_MIN := 0.9
const DEAL_PURSE_MAX := 2.2
const DEAL_PURSE_TWO_WANTS := 1.3
## Most pieces one visitor takes at once (slots on the sale tray).
const DEAL_SLOTS := 8
## One price step the keeper can take (only -10% / +10% for now).
const DEAL_STEP := 0.10
## Reputation for a discount, per 10% off.
const DEAL_REP_PER_10_OFF := 1
## Base chance a visitor agrees to +10% (+ the type's tolerance + reputation bonus).
const DEAL_RAISE_ACCEPT := 0.7
## When the visitor says no to +10%: chance they leave offended (no sale, REP_UNHAPPY_CUSTOMER),
## otherwise they just refuse and the price stays normal.
const DEAL_RAISE_LEAVE := 0.3

## tags: item categories this visitor may want (each visitor picks one or two of them and buys only those).
## tolerance: how easily they agree to +10%; purse: how much money they carry (see DEAL_PURSE_*).
const CUSTOMER_TYPES := {
	"peasant": {"title": "Селянин", "tags": ["food", "drink"], "tolerance": 0.0, "purse": 0.9, "weight": 4},
	"reveler": {"title": "Гуляка", "tags": ["drink"], "tolerance": 0.05, "purse": 1.1, "weight": 2},
	"herbalist": {"title": "Травниця", "tags": ["resource", "potion"], "tolerance": 0.1, "purse": 1.0, "weight": 2, "gender": "f"},
	"merchant": {"title": "Купець", "tags": ["resource", "magic", "drink"], "tolerance": 0.2, "purse": 1.3, "weight": 2},
	"hero": {"title": "Шукач пригод", "tags": ["food", "drink", "potion", "gear"], "tolerance": 0.1, "purse": 1.0, "weight": 3},
	"mage": {"title": "Чарівниця", "tags": ["magic", "potion", "resource"], "tolerance": 0.2, "purse": 1.2, "weight": 1, "gender": "f"},
}

## Names by gender. The gender comes from the portrait file (_m_ / _f_), see scripts/portraits.gd.
const NAMES_M := [
	"Борислав", "Гаврило", "Тарас", "Остап", "Добромир", "Святослав",
	"Грімбальд", "Торін", "Бруно", "Рангар",
]
const NAMES_F := [
	"Мирослава", "Олеся", "Ярина", "Злата", "Веселина", "Устина",
	"Еладріель", "Квіня", "Сівіра", "Ліра",
]

# ---------- Heroes ----------
## Hero stats from the GDD. Order here = order on screen.
const HERO_STATS := {
	"str": {"name": "Сила", "short": "Сил"},
	"agi": {"name": "Спритність", "short": "Спр"},
	"int": {"name": "Інтелект", "short": "Інт"},
	"end": {"name": "Витривалість", "short": "Вит"},
	"cha": {"name": "Харизма", "short": "Хар"},
	"luck": {"name": "Удача", "short": "Уд"},
}
## Every new hero gets the class stats, each one moved randomly by -HERO_STAT_SPREAD..+HERO_STAT_SPREAD (at least 1).
const HERO_STAT_SPREAD := 1
## rep: reputation needed before NEW heroes of this class come to the town (no "rep" = from the start).
const HERO_CLASSES := {
	"warrior": {"name": "Воїн", "stats": {"str": 7, "agi": 4, "int": 2, "end": 5, "cha": 3, "luck": 3}},
	"archer": {"name": "Лучник", "stats": {"str": 4, "agi": 7, "int": 3, "end": 3, "cha": 3, "luck": 4}},
	"mage": {"name": "Маг", "stats": {"str": 2, "agi": 3, "int": 8, "end": 2, "cha": 4, "luck": 4}, "rep": 25},
	"tank": {"name": "Танк", "stats": {"str": 5, "agi": 2, "int": 2, "end": 8, "cha": 3, "luck": 3}, "rep": 10},
}
const HERO_STATUS_NAMES := {"free": "Вільний", "quest": "На завданні", "injured": "Поранений"}
## A hero visitor is a known free hero or, with NEW_HERO_CHANCE, a new one
## (only while the town has fewer heroes than max_heroes of the reputation rank, see REP_RANKS).
const NEW_HERO_CHANCE := 0.4
## Chance that a hero asks for work by himself. Otherwise the keeper offers it,
## and such a hero agrees only if the chance of success is at least PICKY_HERO_MIN_CHANCE.
const HERO_ASKS_CHANCE := 0.6
const PICKY_HERO_MIN_CHANCE := 0.4
## Days an injured hero rests before he can visit and take contracts again.
const INJURY_DAYS := 2

# ---------- Contracts ----------
## Contracts offered on the board every morning (one of every tier first, the rest random).
const CONTRACTS_PER_DAY := 4
## Success: power = sum of all hero stats + stats of the item he took.
## chance = 0.5 + (power - difficulty) * CHANCE_PER_POINT, kept within CHANCE_MIN..CHANCE_MAX.
const CHANCE_PER_POINT := 0.05
const CHANCE_MIN := 0.02
const CHANCE_MAX := 0.97
## The player sees the chance only as words: [up to this chance, words, colour].
const RISK_LEVELS := [
	[0.15, "Майже неможливо", "e05a4a"],
	[0.40, "Ризиковано", "e0904a"],
	[0.65, "Помірно", "e0c84a"],
	[0.88, "Високий шанс", "a8d08d"],
	[1.01, "Майже гарантовано", "6fd06f"],
]
## days: [min, max]. rep: reputation on success.
## death: chance that a hero who failed dies (otherwise he comes back injured).
const CONTRACT_TIERS := {
	"easy": {"name": "Легкий", "days": [1, 1], "rep": 3, "death": 0.15},
	"medium": {"name": "Середній", "days": [2, 3], "rep": 6, "death": 0.35},
	"hard": {"name": "Важкий", "days": [6, 7], "rep": 12, "death": 0.6},
}
## diff: difficulty to compare with hero power. reward: [min, max] gold for the tavern.
## loot: rolled on success like location loot ({item, min, max, chance}).
## Brought items go to storage; if there is no room they are sold at OVERFLOW_SALE_SHARE.
## rep: reputation needed before the contract can appear on the board (no "rep" = from the start).
const CONTRACTS := {
	"rats": {"title": "Вигнати щурів з льоху", "tier": "easy", "diff": 15, "reward": [10, 16],
		"desc": "Пекар скаржиться: щури вже їдять борошно просто з мішків.", "loot": []},
	"wolves": {"title": "Полювання на вовків", "tier": "easy", "diff": 18, "reward": [16, 24],
		"desc": "Зграя вовків ріже овець за млином.",
		"loot": [{"item": "herbs", "min": 1, "max": 2, "chance": 0.5}, {"item": "mandrake", "min": 1, "max": 1, "chance": 0.15}]},
	"herb_escort": {"title": "Провести травницю лісом", "tier": "easy", "diff": 16, "reward": [12, 18],
		"desc": "Травниця боїться йти по корінь лопуха сама: у лісі бачили вовчі сліди.",
		"loot": [{"item": "burdock", "min": 1, "max": 2, "chance": 0.6}, {"item": "berries", "min": 1, "max": 2, "chance": 0.5}]},
	"caravan": {"title": "Супроводити караван", "tier": "medium", "diff": 25, "reward": [38, 52],
		"desc": "Купці везуть кристали з гір і бояться засідки.",
		"loot": [{"item": "crystal", "min": 1, "max": 1, "chance": 0.35}]},
	"bandits": {"title": "Зачистка розбійників", "tier": "medium", "diff": 27, "reward": [45, 62], "rep": 10,
		"desc": "Розбійники засіли в старій вежі біля тракту.",
		"loot": [{"item": "axe", "min": 1, "max": 1, "chance": 0.3}, {"item": "shield", "min": 1, "max": 1, "chance": 0.3}, {"item": "chainmail", "min": 1, "max": 1, "chance": 0.12}]},
	"skeletons": {"title": "Полювання на скелетів", "tier": "medium", "diff": 29, "reward": [50, 68], "rep": 25,
		"desc": "На кладовищі ночами брязкають кістки. Ті, що ходять.",
		"loot": [{"item": "bones", "min": 2, "max": 3}, {"item": "grave_dust", "min": 1, "max": 2, "chance": 0.6}, {"item": "ether_essence", "min": 1, "max": 1, "chance": 0.3}]},
	"necromancer": {"title": "Вбивство некроманта", "tier": "hard", "diff": 31, "reward": [140, 190], "rep": 25,
		"desc": "Той, хто піднімає скелетів, живе у склепі за пагорбом.",
		"loot": [{"item": "sapphire_ring", "min": 1, "max": 1, "chance": 0.4}, {"item": "fire_scroll", "min": 1, "max": 1, "chance": 0.4}, {"item": "ether_essence", "min": 1, "max": 2, "chance": 0.7}]},
	"wyvern": {"title": "Приборкати віверну", "tier": "hard", "diff": 33, "reward": [150, 210], "rep": 45,
		"desc": "Віверна гніздиться на скелі над перевалом і хапає коней.",
		"loot": [{"item": "moon_amulet", "min": 1, "max": 1, "chance": 0.35}, {"item": "crystal", "min": 1, "max": 2, "chance": 0.6}]},
	"ruins": {"title": "Прокляті руїни", "tier": "hard", "diff": 35, "reward": [230, 300], "rep": 70,
		"desc": "Про таверну вже співають барди, тож з тобою говорить сам граф: у руїнах замку прокинулося щось давнє.",
		"loot": [{"item": "moon_amulet", "min": 1, "max": 1, "chance": 0.5}, {"item": "sapphire_ring", "min": 1, "max": 1, "chance": 0.5}, {"item": "ether_essence", "min": 1, "max": 2, "chance": 0.8}]},
}

const START_ITEMS := {"bread": 3, "ale": 3}


static func currency_value(currency_id: String) -> int:
	for c in CURRENCIES:
		if c["id"] == currency_id:
			return c["value"]
	push_error("Unknown currency: " + currency_id)
	return 0


## [words, colour] for a chance of success.
static func risk_level(chance: float) -> Array:
	for level in RISK_LEVELS:
		if chance < level[0]:
			return [level[1], level[2]]
	var last: Array = RISK_LEVELS[RISK_LEVELS.size() - 1]
	return [last[1], last[2]]


static func risk_bbcode(chance: float) -> String:
	var r := risk_level(chance)
	return "[color=#%s]%s[/color]" % [r[1], r[0]]


## Stat points as text, e.g. "Сила +4, Удача +2".
static func stats_text(stats: Dictionary, with_plus: bool = true, short: bool = false) -> String:
	var parts: PackedStringArray = []
	for stat in HERO_STATS:
		if stats.has(stat):
			parts.append("%s %s%d" % [HERO_STATS[stat]["short" if short else "name"], "+" if with_plus else "", stats[stat]])
	return ", ".join(parts)


static func stats_sum(stats: Dictionary) -> int:
	var total := 0
	for stat in stats:
		total += int(stats[stat])
	return total


## Index of the reputation rank in REP_RANKS for this reputation value.
static func rep_rank_index(value: int) -> int:
	var index := 0
	for i in REP_RANKS.size():
		if value >= REP_RANKS[i]["min"]:
			index = i
	return index


static func rep_rank(value: int) -> Dictionary:
	return REP_RANKS[rep_rank_index(value)]


## Reputation needed for a contract / hero class / recipe entry (REP_MIN = no requirement).
static func rep_needed(entry: Dictionary) -> int:
	return int(entry.get("rep", REP_MIN))


## Name of the rank that has this reputation value, e.g. for "needs: Шанована таверна".
static func rep_rank_name(value: int) -> String:
	return rep_rank(value)["name"]


static func prosperity_name(value: int) -> String:
	for level in PROSPERITY_LEVELS:
		if value >= level[0]:
			return level[1]
	return PROSPERITY_LEVELS[PROSPERITY_LEVELS.size() - 1][1]


static func prosperity_mult(value: int) -> float:
	return lerpf(PRICE_MULT_MIN, PRICE_MULT_MAX, clampf(value / 100.0, 0.0, 1.0))


## Shape of an item in storage cells.
static func item_size(id: String) -> Vector2i:
	return ITEM_SIZES.get(id, Vector2i(1, 1))


## Id of the storage place that keeps this category (see STORAGES).
static func storage_of_category(cat: String) -> String:
	for place_id in STORAGES:
		if cat in STORAGES[place_id]["cats"]:
			return place_id
	push_error("No storage place for category: " + cat)
	return ""


static func storage_name_of(item_id: String) -> String:
	return STORAGES[storage_of_category(ITEMS[item_id]["cat"])]["name"]


## Names of the locations where this item can be gathered.
static func item_locations(id: String) -> Array[String]:
	var result: Array[String] = []
	for loc in LOCATIONS:
		var found := false
		for entry in LOCATIONS[loc]["loot"]:
			if entry["item"] == id:
				found = true
		for e in LOCATIONS[loc].get("events", []):
			var event: Dictionary = LOCATION_EVENTS[e["id"]]
			if event.get("item", "") == id or event.get("items", {}).has(id):
				found = true
		if found:
			result.append(LOCATIONS[loc]["name"])
	return result


static func category_color(cat: String) -> Color:
	return Color(CATEGORIES[cat]["color"])


static func items_of(cat: String) -> Array[String]:
	var result: Array[String] = []
	for id in ITEMS:
		if ITEMS[id]["cat"] == cat:
			result.append(id)
	return result


static func is_buyable(id: String) -> bool:
	return "market" in ITEMS[id]["sources"] and ITEMS[id]["cost"] > 0


static func is_brewable(id: String) -> bool:
	return RECIPES.has(id)


## Names of the potions this item is an ingredient of.
static func used_in_recipes(id: String) -> Array[String]:
	var result: Array[String] = []
	for potion in RECIPES:
		if RECIPES[potion]["ingredients"].has(id):
			result.append(ITEMS[potion]["name"])
	return result


# ---------- Icons ----------

## Loaded icon sheets. Kept here so they stay in memory while something draws them.
static var _sheet_cache := {}


## Path of the image file with the item's icon (a sheet, or a separate file).
static func icon_path(id: String) -> String:
	var icon = ITEMS[id]["icon"]
	if icon is String:
		return icon
	return ICON_SHEETS[icon[0]]


static func icon_sheet(id: String) -> Texture2D:
	var path := icon_path(id)
	if not _sheet_cache.has(path):
		_sheet_cache[path] = load(path)
	return _sheet_cache[path]


## Region of the item's icon on its sheet, in pixels (the whole image for a separate icon file).
static func icon_region(id: String) -> Rect2:
	var tex := icon_sheet(id)
	if ITEMS[id]["icon"] is String:
		return Rect2(Vector2.ZERO, tex.get_size())
	var icon: Array = ITEMS[id]["icon"]
	var cell := Vector2(tex.get_width() / float(ICON_SHEET_COLUMNS), tex.get_height() / float(ICON_SHEET_ROWS))
	var r := Rect2(Vector2(icon[1], icon[2]) * cell, cell)
	return Rect2(r.position.round(), r.size.floor())


static func icon_texture(id: String) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = icon_sheet(id)
	atlas.region = icon_region(id)
	return atlas


## BBCode for the icon inside RichTextLabel text.
static func icon_bbcode(id: String, size: int = 24) -> String:
	var r := icon_region(id)
	return "[img=%dx%d region=%d,%d,%d,%d]%s[/img]" % [size, size, r.position.x, r.position.y, r.size.x, r.size.y, icon_path(id)]
