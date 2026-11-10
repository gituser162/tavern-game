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
## Base visitors a day. More come with the reputation rank ("guests" in REP_RANKS) and some upgrades ("guests" in UPGRADES levels).
const CUSTOMERS_PER_DAY := 6
const LAST_DAY := 20
const GOAL_MONEY := 2800 * GOLD  # balance 2026-11-09: was 1500 (sim: average player ~56% wins)

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
## guests: extra visitors a day at this rank (balance 2026-11-09).
## hero_bonus: extra stat points a NEW hero gets (spread randomly over his stats).
## Contracts, hero classes and recipes are unlocked by their own "rep" value (see below).
const REP_RANKS := [
	{"min": -20, "name": "Погана слава", "guests": 0, "max_heroes": 3, "hero_bonus": 0},
	{"min": -5, "name": "Невідома корчма", "guests": 0, "max_heroes": 4, "hero_bonus": 0},
	{"min": 10, "name": "Знайома місцевим", "guests": 1, "max_heroes": 5, "hero_bonus": 0},
	{"min": 25, "name": "Шанована таверна", "guests": 2, "max_heroes": 6, "hero_bonus": 2},
	{"min": 45, "name": "Відома в краї", "guests": 3, "max_heroes": 7, "hero_bonus": 4},
	{"min": 70, "name": "Легендарна таверна", "guests": 4, "max_heroes": 8, "hero_bonus": 6},
]

# ---------- Factions (GDD 14.5-14.6) ----------
## Three separate reputations instead of one scale:
##   "people" = Містяни: the old reputation (GameState.reputation, REP_RANKS above): visitors, heroes, recipes, ranks.
##   "state"  = Магістрат: taxes, state contracts, how fast the guard forgets (GameState.faction_rep["state"]).
##   "crime"  = Тіньова гільдія: the fence, stolen goods, criminal contracts (GameState.faction_rep["crime"]).
## spill: when this faction GAINS reputation, the other ones change by gain x this share (GDD 14.6: "+10 state = -3 crime").
## ranks: [lowest value, name, what it gives (text for the ledger)].
const FACTIONS := {
	"people": {"name": "Містяни", "color": "a8d08d", "spill": {},
		"desc": "Прості люди міста: від них залежать гості, герої, рецепти й покращення (ранги нижче)."},
	"state": {"name": "Магістрат", "color": "7fa8e0", "min": -50, "max": 100, "start": 0, "spill": {"crime": -0.3},
		"desc": "Влада й варта. Росте від державних контрактів, чистих перевірок, сплачених податків і доносів на скупника.",
		"ranks": [
			[-50, "Ворог магістрату", "Податок 12%, варта нічого не забуває: підозра не спадає сама."],
			[-15, "Сумнівний заклад", "Податок 10%, підозра спадає на 2 за ніч."],
			[10, "Благонадійна таверна", "Податок 8%, підозра спадає на 3 за ніч."],
			[35, "Друзі магістрату", "Податок 6%, підозра спадає на 4 за ніч. Важкі державні контракти."],
			[60, "Опора міста", "Податок 4%, підозра спадає на 5 за ніч."],
		]},
	"crime": {"name": "Тіньова гільдія", "color": "c08ae0", "min": -50, "max": 100, "start": 0, "spill": {"state": -0.5},
		"desc": "Злочинний світ. Росте від угод зі скупником, злочинних контрактів і продажу краденого.",
		"ranks": [
			[-50, "Донощик", "Скупник не приходить, злочинних контрактів немає."],
			[0, "Чужак", "Скупник інколи заходить і продає крадене за пів ринкової ціни."],
			[10, "Свій для скупника", "Скупник приходить частіше, ціни нижчі. Середні злочинні контракти. Тесля може зробити схованку."],
			[30, "Людина гільдії", "Скупник носить рідкісні речі. Важкі злочинні контракти. Свідки мовчать частіше."],
			[60, "Тіньовий партнер", "Найкращі ціни скупника, свідки майже завжди мовчать."],
		]},
}
## Tax collector rate by the state reputation: [lowest state rep, rate]. During an investigation (SUSPICION_LEVELS) +5%.
const STATE_TAX_RATES := [[60, 0.04], [35, 0.06], [10, 0.08], [-15, 0.10], [-100, 0.12]]
## How much suspicion fades every night, by the state reputation: [lowest state rep, points].
const SUSPICION_DECAY := [[60, 5], [35, 4], [10, 3], [-15, 2], [-100, 0]]
## State reputation for paying the tax collector without arguing.
const STATE_REP_FOR_TAX := 1

# ---------- Suspicion (GDD 14.7) ----------
## How closely the guard watches the tavern, 0..100. At 100 the keeper is arrested (game over).
const SUSPICION_MAX := 100
## [lowest value, name, effect text, colour]. Effects themselves are in GameState (rumours, inspections, investigation).
const SUSPICION_LEVELS := [
	[0, "Спокійно", "Варта тебе не помічає.", "8fc070"],
	[25, "Чутки", "Містом ходять чутки: щоранку −1 до репутації серед містян.", "e0c84a"],
	[50, "Перевірки", "Варта може прийти з позаплановою перевіркою (20% щоранку).", "e0904a"],
	[75, "Розслідування", "Офіційне розслідування: перевірки частіше (40%), штрафи вдвічі більші, податок +5%, магістрат не дає контрактів.", "e05a4a"],
	[100, "Арешт", "Власника таверни арештовують. Кінець гри.", "ff3030"],
]
## Where suspicion comes from (GDD: failed crime contract +20, witnesses +10, a hero caught +35).
const SUSP_WITNESS := 10
const SUSP_CRIME_FAIL := 20
const SUSP_HERO_CAUGHT := 35
const SUSP_CRIME_DONE := 4
const SUSP_FENCE_DEAL := 3
const SUSP_INSPECTION_FOUND := 10
## Suspicion lost after an inspection that found nothing, after reporting the fence, per state contract tier.
const SUSP_INSPECTION_CLEAN := -10
const SUSP_REPORT_FENCE := -5
const SUSP_STATE_CONTRACT := {"easy": -3, "medium": -6, "hard": -10}
## Morning guard inspection: chance a day at "Перевірки" / "Розслідування", days between two inspections.
## Every stolen piece found is taken away, and the keeper pays "fine" gold for it (x2 during an investigation).
const INSPECTION := {"name": "Перевірка варти", "chance": 0.2, "chance_investigation": 0.4, "cooldown": 2, "fine": 8,
	"state_found": -4, "state_clean": 2}
## Guard barracks (the door popup): a bribe lowers suspicion. Costs an action and gold:
## cost = base + per_point x suspicion. During an investigation the captain may refuse (refuse_chance): suspicion +refused.
const BRIBE := {"name": "Казарма варти", "base": 15, "per_point": 0.6, "drop": 15, "refuse_chance": 0.4, "refused": 10,
	"state": -1, "action_cost": 1}

# ---------- Crime: the fence and stolen goods ----------
## The fence (customer type "fence") sells stolen goods. He comes at most once a day from "from_day", with "chance"
## by the crime reputation ([lowest crime rep, chance, price share of the market price; items the market does not sell:
## of 80% of their sale price]).
## Reporting him to the guard: state +report_state, crime +report_crime, he stays away for report_days.
const FENCE := {"from_day": 2, "report_state": 4, "report_crime": -6, "report_days": 3, "crime_rep": 2,
	"by_rep": [[60, 0.6, 0.35], [30, 0.5, 0.4], [10, 0.45, 0.45], [0, 0.35, 0.5], [-100, 0.0, 0.5]]}
## What the fence can offer: item -> [weight, min pieces, max pieces, crime rep needed].
const FENCE_LOTS := {
	"wine": [3, 2, 4, 0], "mead": [2, 3, 5, 0], "chicken": [1, 3, 5, 0],
	"shield": [3, 1, 1, 0], "axe": [3, 1, 1, 0], "chainmail": [2, 1, 1, 0],
	"crystal": [2, 1, 2, 0], "fire_scroll": [2, 1, 1, 10], "moon_amulet": [1, 1, 1, 30],
	"sapphire_ring": [1, 1, 1, 30], "ether_essence": [1, 1, 2, 30],
}
## Selling a stolen piece: chance a visitor recognises it (a witness: suspicion +SUSP_WITNESS),
## by the crime reputation [lowest crime rep, chance]. The "Схованка" upgrade lowers it further ("witness" value).
const STOLEN_WITNESS := [[60, 0.04], [30, 0.08], [10, 0.12], [-100, 0.16]]
## A successful criminal contract: chance somebody saw the heroes (+SUSP_WITNESS on top of SUSP_CRIME_DONE).
const CRIME_WITNESS_CHANCE := 0.25
## A failed criminal contract: chance the hero is caught (jailed JAIL_DAYS, suspicion SUSP_HERO_CAUGHT instead of SUSP_CRIME_FAIL).
const CRIME_CAUGHT_CHANCE := 0.4
const JAIL_DAYS := 4
## Contract factions: what the board note looks like and whom the contract pleases.
const CONTRACT_FACTIONS := {
	"people": {"name": "Контракт населення", "color": "a8d08d"},
	"state": {"name": "Державний контракт", "color": "7fa8e0"},
	"crime": {"name": "Злочинне замовлення", "color": "c08ae0"},
}

# ---------- Storage ----------
## Storage places (2026-11-10: no categories any more, any item lies on any shelf or in the attic).
## Every place is a grid of cells: `surfaces` levels (2 = the middle shelf and the floor plank under the counter),
## each `cols` x `rows` cells. Items take cells by their shape (ITEM_SIZES), like a puzzle.
## All four shelves under the counter have the same grid (the narrowest compartment fits 8 cells of 8 px).
## At the start only the first shelf (SHELF_ORDER[0]) is built; the "Полиці" upgrade builds the others one by one,
## the "Горище" upgrade opens the attic (see UPGRADES; Storage.grid_override "locked").
const SHELF_COLS := 8
const SHELF_ROWS := 4
## The attic is one big grid (its own window, no shelves in the background). Its size grows with the "Горище" upgrade.
const ATTIC_COLS := 12
const ATTIC_ROWS := 4
## Shelves under the counter, left to right = the order they are built in.
const SHELF_ORDER := ["cellar", "pantry", "chest", "cabinet"]
const STORAGES := {
	"cellar": {"name": "Полиця 1", "short": "Полиця 1", "cols": SHELF_COLS, "rows": SHELF_ROWS,
		"desc": "Перша полиця під стійкою. Клади сюди що завгодно: їжу, напої, зілля, спорядження чи ресурси."},
	"pantry": {"name": "Полиця 2", "short": "Полиця 2", "cols": SHELF_COLS, "rows": SHELF_ROWS,
		"desc": "Друга полиця під стійкою. Тут може лежати будь-що."},
	"chest": {"name": "Полиця 3", "short": "Полиця 3", "cols": SHELF_COLS, "rows": SHELF_ROWS,
		"desc": "Третя полиця під стійкою. Тут може лежати будь-що."},
	"cabinet": {"name": "Полиця 4", "short": "Полиця 4", "cols": SHELF_COLS, "rows": SHELF_ROWS,
		"desc": "Четверта полиця під стійкою. Тут може лежати будь-що."},
	"attic": {"name": "Горище", "short": "Горище", "cols": ATTIC_COLS, "rows": ATTIC_ROWS, "surfaces": 1,
		"desc": "Під дахом сушаться трави й коріння, у кутку лежать мішки. Сюди влазить будь-що, ресурси кладуться сюди першими."},
}
## Shape of every item on the shelves, in cells (w, h). Items not listed take one cell.
const ITEM_SIZES := {
	"ale": Vector2i(1, 1), "mead": Vector2i(2, 1), "wine": Vector2i(1, 2),
	"bread": Vector2i(1, 1), "chicken": Vector2i(2, 1), "stew": Vector2i(2, 2),
	"heal_potion": Vector2i(1, 2), "antidote": Vector2i(1, 2), "strength_potion": Vector2i(1, 2),
	"shield": Vector2i(2, 2), "chainmail": Vector2i(2, 3), "axe": Vector2i(1, 3),
	"fire_scroll": Vector2i(2, 1), "moon_amulet": Vector2i(1, 2), "sapphire_ring": Vector2i(1, 1),
	"herb_soup": Vector2i(1, 1), "berry_pie": Vector2i(2, 1), "forest_roast": Vector2i(2, 1), "luck_elixir": Vector2i(1, 2),
	"mushroom_soup": Vector2i(1, 1), "berry_uzvar": Vector2i(1, 2), "chicken_pie": Vector2i(2, 1),
	# Swamp, lake and port (2026-11-08).
	"swamp_draught": Vector2i(1, 2), "poison": Vector2i(1, 2), "wisp_elixir": Vector2i(1, 2), "rum": Vector2i(1, 2),
	"fish_soup": Vector2i(1, 1), "baked_pike": Vector2i(2, 1), "crayfish_fry": Vector2i(2, 1),
	# Side-effect potions (2026-11-09).
	"murky_brew": Vector2i(1, 2), "sleep_draught": Vector2i(1, 2),
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
	"cook": "кухня таверни",
	"contract": "нагорода з контрактів",
	"fishing": "риболовля на озері",
	"port": "порт (заморський купець, контрабандист)",
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
	"rum": {"name": "Заморський ром", "cat": "drink", "price": 14, "cost": -1, "port_cost": 6, "icon": [4, 10, 0],
		"sources": ["port"], "desc": "Темний, солодкий і міцний. Привозять кораблі з південних островів, а в місті його не роблять."},
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
	# Swamp (Болото): ingredients for the darker potions. wisp_jar only from the event "wisp".
	"swamp_moss": {"name": "Болотний мох", "cat": "resource", "price": 4, "cost": -1, "icon": [1, 1, 3],
		"sources": ["location"], "desc": "Сірувато-зелений мох з купин. Мокрий, важкий і пахне гниллю, але алхіміки без нього не варять відварів."},
	"toad": {"name": "Болотяна жаба", "cat": "resource", "price": 7, "cost": -1, "icon": "res://assets/icons/toad.png",
		"sources": ["location"], "desc": "Бородавчаста, з жовтим черевом. Шкіра трохи отруйна, тому її й беруть."},
	"nightshade": {"name": "Беладона", "cat": "resource", "price": 11, "cost": -1, "icon": [4, 1, 7],
		"sources": ["location"], "desc": "Темно-фіолетові квіти й чорні ягоди. Крапля соку розширює зіниці, жменька зупиняє серце."},
	"wisp_jar": {"name": "Вогник у банці", "cat": "resource", "price": 30, "cost": -1, "icon": "res://assets/icons/wisp_jar.png",
		"sources": ["location"], "desc": "Блукаючий вогник, якого вдалося зачинити в банку. Тихо дзвенить і просить на волю."},
	# Lake (Озеро): weed and crayfish lie on the shore, fish are caught with the rod (FISHING).
	"lake_weed": {"name": "Озерні водорості", "cat": "resource", "price": 3, "cost": -1, "icon": "res://assets/icons/lake_weed.png",
		"sources": ["location"], "desc": "Довгі зелені пасма з мілини. Їх кидають у юшку і в зілля."},
	"crayfish": {"name": "Річкові раки", "cat": "resource", "price": 6, "cost": -1, "icon": "res://assets/icons/crayfish.png",
		"sources": ["location", "fishing"], "desc": "Ховаються під камінням біля берега. Хто не встиг сховатися, той у кошику."},
	"perch": {"name": "Окунь", "cat": "resource", "price": 5, "cost": -1, "icon": "res://assets/icons/perch.png",
		"sources": ["fishing"], "desc": "Смугастий, колючий і завжди голодний. Найчастіша здобич на озері."},
	"pike": {"name": "Щука", "cat": "resource", "price": 13, "cost": -1, "icon": "res://assets/icons/pike.png",
		"sources": ["fishing"], "desc": "Зубата хижачка з глибини. Клює далеко від берега і тягне так, що вудка гнеться."},
	# Port (Порт): foreign goods, only from the merchant ship and the smuggler ("port_cost" = their price at 50 prosperity).
	"spices": {"name": "Заморські прянощі", "cat": "resource", "price": 12, "cost": -1, "port_cost": 5, "icon": [1, 5, 6],
		"sources": ["port"], "desc": "Мішечок перцю, кориці й шафрану з-за моря. Від одного запаху в кухаря сльозяться очі."},
	# Potions: brewed by the player from ingredients in storage (see RECIPES). Not sold on the market.
	"heal_potion": {"name": "Зілля лікування", "cat": "potion", "price": 26, "cost": -1, "icon": [1, 11, 1],
		"sources": ["craft"], "hero_stats": {"end": 3}, "desc": "Затягує рани за кілька хвилин. Героям потрібне завжди."},
	"antidote": {"name": "Протиотрута", "cat": "potion", "price": 18, "cost": -1, "icon": [1, 10, 0],
		"sources": ["craft"], "hero_stats": {"end": 2}, "desc": "Від укусів павуків, змій і поганого вина."},
	"strength_potion": {"name": "Зілля сили", "cat": "potion", "price": 34, "cost": -1, "icon": [1, 9, 1],
		"sources": ["craft"], "hero_stats": {"str": 4}, "desc": "На годину дає силу трьох ковалів."},
	# Brewed only with the alchemy station upgraded to level 2.
	"luck_elixir": {"name": "Еліксир удачі", "cat": "potion", "price": 44, "cost": -1, "icon": [1, 7, 1],
		"sources": ["craft"], "hero_stats": {"luck": 4}, "desc": "Золотий, з іскрою всередині. Хто його вип'є, той спіткнеться якраз над скарбом."},
	# Darker potions from the swamp ingredients. "shady": selling it in the hall raises suspicion by SUSP_SHADY_SALE.
	"swamp_draught": {"name": "Болотяний відвар", "cat": "potion", "price": 22, "cost": -1, "icon": [1, 6, 1],
		"sources": ["craft"], "hero_stats": {"end": 2, "agi": 1}, "desc": "Каламутний, гіркий, з плівкою зверху. Зате після нього не беруть ні холод, ні втома."},
	"poison": {"name": "Отрута для клинків", "cat": "potion", "price": 38, "cost": -1, "icon": [1, 0, 0], "shady": true,
		"sources": ["craft"], "hero_stats": {"str": 2, "agi": 2}, "desc": "Чорна, густа, без запаху. Мисливці мажуть нею стріли, а інші... краще не питати. Варта її не любить."},
	"wisp_elixir": {"name": "Еліксир блукаючого вогника", "cat": "potion", "price": 58, "cost": -1, "icon": [1, 12, 0],
		"sources": ["craft"], "hero_stats": {"int": 3, "luck": 3}, "desc": "Усередині кружляє маленький блакитний вогник. Хто вип'є, бачить у темряві стежки, яких немає на мапах."},
	# Side-effect potions (2026-11-09): what comes out of a failed experiment or a spoiled brew. "fence_only": ordinary
	# visitors do not buy them, only the fence does (FENCE_BUYS). Their "price" is only what the book shows.
	"murky_brew": {"name": "Каламутна суміш", "cat": "potion", "price": 6, "cost": -1, "icon": "res://assets/icons/murky_brew.png", "fence_only": true,
		"sources": ["craft"], "desc": "Невдалий експеримент: сіро-бура, пахне болотом і пригорілим. Чесний гість таке не купить, а скупник візьме: у гільдії на все знайдеться покупець."},
	"sleep_draught": {"name": "Сонний відвар", "cat": "potion", "price": 15, "cost": -1, "icon": "res://assets/icons/sleep_draught.png", "fence_only": true,
		"sources": ["craft"], "desc": "Майже вдалий рецепт з побічною дією: хто вип'є, засинає на пів дня. Чесним людям не продаси, а тіньова гільдія знає, кому його підлити."},
	# Dishes: cooked in the tavern kitchen (an upgrade) from forest resources, see KITCHEN_RECIPES.
	"herb_soup": {"name": "Трав'яна юшка", "cat": "food", "price": 7, "cost": -1, "icon": [5, 4, 3],
		"sources": ["cook"], "desc": "Миска гарячої юшки з лопухом і зеленню. Дешево, ситно, пахне лісом."},
	"berry_pie": {"name": "Ягідний пиріг", "cat": "food", "price": 16, "cost": -1, "icon": [5, 8, 6],
		"sources": ["cook"], "desc": "Пиріг з лісовими ягодами, ще теплий. Купці беруть його до вина."},
	"forest_roast": {"name": "Лісова печеня", "cat": "food", "price": 15, "cost": -1, "icon": [5, 3, 0],
		"sources": ["cook"], "desc": "Печеня з коренем мандрагори й травами. Герої кажуть, після неї не страшно й у склеп."},
	"mushroom_soup": {"name": "Юшка зі світних грибів", "cat": "food", "price": 20, "cost": -1, "icon": [5, 3, 3],
		"sources": ["cook"], "desc": "Бліда юшка, в якій ще ледь світяться блакитні шапочки. Маги кажуть, від неї ясніє в голові."},
	"berry_uzvar": {"name": "Ягідний узвар", "cat": "drink", "price": 8, "cost": -1, "icon": [4, 4, 7],
		"sources": ["cook"], "desc": "Темний узвар з лісових ягід і м'яти. Тим, хто не п'є елю, наливають його."},
	"chicken_pie": {"name": "Курячий пиріг", "cat": "food", "price": 13, "cost": -1, "icon": [5, 7, 1],
		"sources": ["cook"], "desc": "Золотистий пиріг з куркою і травами. Ситний, як обід удома."},
	"fish_soup": {"name": "Рибна юшка", "cat": "food", "price": 12, "cost": -1, "icon": [5, 5, 2],
		"sources": ["cook"], "desc": "Юшка з окуня і водоростей, з кропом. Рибалки кажуть, що вона лікує все, крім туги."},
	"crayfish_fry": {"name": "Смажені раки", "cat": "food", "price": 15, "cost": -1, "icon": [5, 11, 2],
		"sources": ["cook"], "desc": "Червоні, хрусткі, з часником і травами. До них просять другу кружку."},
	"baked_pike": {"name": "Щука з прянощами", "cat": "food", "price": 27, "cost": -1, "icon": [5, 7, 3],
		"sources": ["cook"], "desc": "Ціла щука, запечена із заморськими прянощами. Таку подають на бенкетах у магістраті."},
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
## false = the daily action limit is switched off and hidden (trips are limited by once-a-day visits and closures).
## Set to true to bring the limit and its UI back.
const ACTIONS_ENABLED := false
## Ale keg on the counter: a click pours one KEG_ITEM onto its shelf for free. Then the keg needs KEG_COOLDOWN real
## seconds before the next mug, and it holds KEG_MUGS_PER_DAY mugs a day (refilled every morning).
const KEG_ITEM := "ale"
const KEG_COOLDOWN := 3.0
const KEG_MUGS_PER_DAY := 6
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
	"swamp": {"name": "Болото", "icon": [4, 1, 7], "bg": "res://assets/backgrounds/swamp.png",
		"desc": "Гниле болото за старим трактом. Мох, жаби й беладона для темних зілль. Обережно з вогниками.",
		"count": [1, 3],
		"loot": [
			{"item": "swamp_moss", "weight": 4},
			{"item": "toad", "weight": 3},
			{"item": "nightshade", "weight": 2},
		],
		# On the hummocks (dry land), never in the water.
		"spots": [[30, 132], [52, 150], [78, 126], [96, 158], [130, 140], [150, 160], [176, 128], [204, 154],
			[230, 136], [262, 150], [288, 130], [118, 118], [244, 162], [22, 158]],
		"events": [
			{"id": "wisp", "chance": 0.12},
			{"id": "fog", "chance": 0.06,
				"text": "З болота піднявся густий сизий туман. Ресурси видно, лише коли наведеш на них курсор. Зате в тумані їх лежить більше."},
		]},
	"lake": {"name": "Озеро", "icon": "res://assets/icons/perch.png", "bg": "res://assets/backgrounds/lake.png",
		"desc": "Тихе озеро за пагорбом. Водорості й раки на березі, а з помосту можна закинути вудку.",
		"count": [1, 2],
		"loot": [
			{"item": "lake_weed", "weight": 3},
			{"item": "crayfish", "weight": 2},
		],
		# Items shown in the door popup (besides the loot): what the rod can bring.
		"show": ["perch", "pike"],
		"spots": [[24, 150], [48, 158], [70, 146], [96, 160], [118, 152], [142, 158], [166, 148], [36, 140],
			[300, 156], [278, 150], [128, 144]],
		# "fishing": the pier where the rod is cast (FISHING), [x, y] of its end in bg pixels.
		"fishing": [222, 118],
		"events": [
			{"id": "rich_bite", "chance": 0.1},
			{"id": "magic_rain", "chance": 0.04,
				"text": "Над озером пройшов магічний дощ: хвилі викинули на берег купу водоростей і раків. Ресурсів удвічі більше!"},
		]},
	"port": {"name": "Порт", "icon": [4, 10, 0], "bg": "res://assets/backgrounds/port.png",
		"desc": "Річкова пристань, куди заходять заморські кораблі. Дешевий товар у купця, а під помостом шепоче контрабандист.",
		# No resources: two people to deal with (PORT, SMUGGLER). "people": clickable rects [x, y, w, h] in bg pixels.
		"kind": "port",
		"loot": [],
		"show": ["rum", "spices"],
		"spots": [],
		"people": {"merchant": [88, 96, 26, 40], "smuggler": [246, 112, 22, 36]},
		"events": [
			{"id": "storm", "chance": 0.08},
			{"id": "customs", "chance": 0.1},
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
	# Swamp: a will-o'-wisp floats over the bog. Clicking it: with "catch_chance" it goes into a jar ("item"),
	# otherwise it lures the keeper into the quagmire: "lose_share" of what was gathered on this trip sinks
	# (taken out of storage) and the trip is over.
	"wisp": {"name": "Блукаючий вогник", "effect": "wisp", "item": "wisp_jar", "catch_chance": 0.6, "lose_share": 0.5,
		"text": "Над трясовиною пливе блакитний вогник. Кажуть, його можна впіймати в банку, а можна піти за ним і не повернутися. Натисни на вогник, якщо наважишся. Спершу краще зібрати, що лежить."},
	# Lake: the fish bite well today, the rod gets "extra" more casts.
	"rich_bite": {"name": "Рибний день", "effect": "casts", "extra": 2,
		"text": "Вода тиха й тепла, риба аж вистрибує. Сьогодні на вудку буде на 2 закиди більше!"},
	# Port: the merchant ship did not come (only the smuggler is there) / customs guards on the quay (no smuggler).
	"storm": {"name": "Шторм на морі", "effect": "no_merchant",
		"text": "Уночі був шторм, і заморський корабель не дійшов до пристані. Купця сьогодні немає, лише контрабандист, як завжди, тиняється під помостом."},
	"customs": {"name": "Митна варта", "effect": "no_smuggler",
		"text": "На пристані чергує митна варта: перевіряє ящики й записує, хто що купує. Контрабандист сьогодні не висовується."},
}

# ---------- Lake: fishing ----------
## The rod on the pier (scripts/fishing_game.gd): "casts" per visit. A cast: click when the power bar is where you want it
## (farther = bigger fish), wait for a bite and click while the float is under water ("bite_window" s), then reel:
## hold the mouse to keep the green zone on the fish until the progress bar is full.
## fish: item -> weight (chance), power [min, max] of the cast where it bites, speed (how wildly it moves, 1 = normal),
## zone (height of the catch zone in px of the 60 px bar: smaller = harder). "gold": a lost purse instead of a fish.
const FISHING := {
	"casts": 3, "wait": [1.4, 3.6], "bite_window": 0.9, "start": 0.3, "gain": 0.42, "loss": 0.3,
	"fish": {
		"perch": {"weight": 6, "power": [0.0, 1.0], "speed": 0.8, "zone": 20},
		"crayfish": {"weight": 4, "power": [0.0, 0.45], "speed": 0.55, "zone": 22},
		"pike": {"weight": 4, "power": [0.55, 1.0], "speed": 1.35, "zone": 15},
		"purse": {"weight": 1, "power": [0.75, 1.0], "speed": 0.5, "zone": 22, "gold": [6, 18]},
	},
}

# ---------- Port ----------
## Foreign merchant ship: "lots" offers a visit, picked from "goods" {item: [weight, min pieces, max pieces]}.
## Price of a piece: the market cost x "share" (port-only items: their "port_cost"), scaled by prosperity like the market.
const PORT := {"lots": 4, "share": 0.65,
	"goods": {
		"rum": [5, 2, 4], "spices": [5, 2, 4], "wine": [3, 2, 4], "mead": [2, 2, 4], "mandrake": [2, 2, 3],
		"crystal": [2, 1, 2], "shield": [1, 1, 1], "chainmail": [1, 1, 1], "fire_scroll": [1, 1, 1], "moon_amulet": [1, 1, 1],
	}}
## Smuggler under the pier (Тіньова гільдія). Talks only to keepers with crime reputation >= "min_crime".
## Contraband: "lots" offers at "share" of the price (stolen goods, see FENCE): crime +deal_crime, suspicion +deal_susp.
## Job "hide a crate": the keeper keeps a sealed crate for "days" days and gets paid by the crime rank
## ("pay" [lowest crime rep, gold]) + crime "crime_done". While the crate is in the tavern a guard inspection
## can come even at low suspicion ("inspect_chance"); if it finds the crate (the stash upgrade hides it with its "hide"):
## fine "fine", suspicion +susp_found, crime "crime_lost".
const SMUGGLER := {"min_crime": 0, "lots": 2, "share": 0.35, "deal_crime": 1, "deal_susp": 2,
	"goods": {
		"rum": [3, 3, 5], "spices": [3, 3, 5], "wine": [2, 3, 5], "crystal": [2, 1, 2], "fire_scroll": [1, 1, 1],
		"moon_amulet": [1, 1, 1], "ether_essence": [1, 1, 2], "chainmail": [1, 1, 1],
	},
	"job": {"days": 2, "pay": [[60, 75], [30, 60], [10, 48], [-100, 38]], "crime_done": 3, "crime_lost": -5,
		"fine": 30, "susp_found": 12, "inspect_chance": 0.25}}
## Selling a "shady" item (poison) in the hall: suspicion +this per piece.
const SUSP_SHADY_SALE := 1

# ---------- Tavern events ----------
## Rolled every morning (at most one morning event a day: first "tax_collector", then "fair").
## from_day: not before this day. cooldown: days before the same event can happen again.
## Tax: takes "rate" of the gold; a tavern with a good name pays less: "rates" [lowest reputation, rate],
## the first one that fits wins.
const TAX_COLLECTOR := {"name": "Збирач податків", "chance": 0.06, "from_day": 3, "cooldown": 5,
	"rates": STATE_TAX_RATES}
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
## "color" = colour of the potion in the cauldron, "herb" = colour of what is ground in the mortar (interactive brewing).
const RECIPES := {
	"heal_potion": {"ingredients": {"herbs": 2, "berries": 1, "burdock": 1}, "amount": 1, "color": "c8393a", "herb": "4f8a3a"},
	"antidote": {"ingredients": {"herbs": 1, "berries": 1, "bones": 1}, "amount": 1, "rep": 10, "color": "5cbf5a", "herb": "6e8a3a"},
	"strength_potion": {"ingredients": {"mandrake": 1, "grave_dust": 1, "burdock": 1}, "amount": 1, "rep": 25, "color": "e07a2a", "herb": "8a6a4a"},
	# "upgrade": [upgrade id, level] needed before the recipe can be used.
	"luck_elixir": {"ingredients": {"crystal": 1, "herbs": 1, "berries": 1}, "amount": 1, "upgrade": ["alchemy", 2], "color": "e8c040", "herb": "8ab8d8"},
	# Darker potions from the swamp.
	"swamp_draught": {"ingredients": {"swamp_moss": 2, "toad": 1}, "amount": 1, "color": "5a6a2a", "herb": "4a5a34"},
	"poison": {"ingredients": {"nightshade": 1, "toad": 1, "grave_dust": 1}, "amount": 1, "rep": 10, "color": "2a1e34", "herb": "4a2a5a"},
	"wisp_elixir": {"ingredients": {"wisp_jar": 1, "nightshade": 1, "swamp_moss": 1}, "amount": 1, "upgrade": ["alchemy", 2], "color": "6ad8f0", "herb": "4a5a34"},
}

# ---------- Kitchen ----------
## Opened by the "Кухня" upgrade (the cauldron in the fireplace). Cooking is done in the morning and costs no actions,
## like brewing, and is interactive too (scripts/cook_station.gd): prepare the ingredients (COOK_PREP), mix,
## cook with heat control, put the portions on plates. "amount" pieces of the dish go onto its shelf;
## kitchen level 2 adds its "bonus" pieces. "kitchen": kitchen level needed (no field = level 1).
## "method": how it is cooked: "boil" (pot: stir, simmer), "bake" (oven: knead the dough, bake),
## "fry" (pan: season, fry and flip once). "color": colour of the finished dish (broth, filling, meat).
const KITCHEN_RECIPES := {
	"herb_soup": {"ingredients": {"herbs": 1, "burdock": 1}, "amount": 2, "method": "boil", "color": "6a9a3a"},
	"berry_uzvar": {"ingredients": {"berries": 2, "herbs": 1}, "amount": 2, "method": "boil", "color": "7a2448"},
	"berry_pie": {"ingredients": {"berries": 2, "bread": 1}, "amount": 1, "method": "bake", "color": "6a2a7a"},
	"mushroom_soup": {"ingredients": {"glow_mushroom": 1, "herbs": 1, "burdock": 1}, "amount": 2, "method": "boil", "color": "8ab8c0"},
	"forest_roast": {"ingredients": {"mandrake": 1, "herbs": 1, "berries": 1}, "amount": 2, "kitchen": 2, "method": "fry", "color": "8a4a22"},
	"chicken_pie": {"ingredients": {"chicken": 1, "bread": 1, "herbs": 1}, "amount": 2, "kitchen": 2, "method": "bake", "color": "c8a050"},
	# Lake fish and the port spices.
	"fish_soup": {"ingredients": {"perch": 1, "lake_weed": 1, "herbs": 1}, "amount": 2, "method": "boil", "color": "c8a868"},
	"crayfish_fry": {"ingredients": {"crayfish": 2, "herbs": 1}, "amount": 2, "method": "fry", "color": "c84a2a"},
	"baked_pike": {"ingredients": {"pike": 1, "spices": 1, "bread": 1}, "amount": 2, "kitchen": 2, "method": "bake", "color": "b88848"},
}
## How every ingredient is prepared in the kitchen: "chop" on the board (clicks), "mash" in the bowl (hold and rub),
## "crumble" in the bowl (clicks). Not listed = "chop".
## Handled in a special way on the kitchen table: cleaned (scaled / shelled) before chopping, leave scraps for the
## bucket when chopped, shaken out over the dish by hand.
const COOK_CLEAN := ["perch", "pike", "crayfish"]
const COOK_SCRAPS := ["burdock", "mandrake", "chicken"]
const COOK_SPRINKLE := ["spices"]
const COOK_PREP := {
	"herbs": "chop", "burdock": "chop", "mandrake": "chop", "glow_mushroom": "chop", "chicken": "chop",
	"berries": "mash", "bread": "crumble",
	"perch": "chop", "pike": "chop", "crayfish": "chop", "lake_weed": "chop", "spices": "crumble",
}

# ---------- Tavern upgrades ----------
## Ordered from the carpenter (the entrance door -> "Тесля"), in the morning, for gold. No actions spent.
## Every upgrade has "levels" (bought one after another); level 0 = what the tavern has from the start = "base".
## "guests" in a level: extra visitors a day while that level is built (balance 2026-11-09).
## Costs x0.7 on 2026-11-09 (balance sim: upgrades did not pay back).
## A level: cost (gold), rep (reputation needed, optional), text (what it gives) and its values; GameState.upgrade_value()
## gives the value of the current level (or "base"). Levels are visible in the room (sprites, more stock, notes...).
const UPGRADES := {
	# shelves: how many shelves under the counter are built (SHELF_ORDER), 64 cells each.
	"shelves": {"name": "Полиці", "icon": [5, 13, 4],
		"desc": "Тесля збиває нові полиці під стійкою. На початку є лише одна, на кожну нову влазить будь-який товар.",
		"base": {"shelves": 1},
		"levels": [
			{"cost": 40, "shelves": 2, "text": "Друга полиця під стійкою: +64 клітинки для будь-якого товару."},
			{"cost": 80, "shelves": 3, "text": "Третя полиця: ще +64 клітинки."},
			{"cost": 130, "rep": 10, "shelves": 4, "text": "Четверта полиця: усі полиці під стійкою збудовані."},
		]},
	# attic: cols x rows of the attic grid, 0 = not built yet (the hatch is shut).
	"attic": {"name": "Горище", "icon": [1, 3, 3],
		"desc": "Тесля відчиняє ляду й настилає підлогу на горищі. Там може лежати будь-що, а трави й коріння кладуться туди першими.",
		"base": {"cols": 0, "rows": 0},
		"levels": [
			{"cost": 45, "cols": 12, "rows": 4, "text": "Відкриває горище 12×4 (48 клітинок)."},
			{"cost": 90, "cols": 12, "rows": 6, "text": "Горище 12×6."},
			{"cost": 140, "rep": 10, "cols": 16, "rows": 6, "text": "Горище 16×6."},
		]},
	"cellar": {"name": "Пивний погріб", "icon": [4, 0, 0],
		"desc": "Погріб під таверною: бочка на стійці наливає більше елю і швидше.",
		"base": {"mugs": 6, "cooldown": 3.0},
		"levels": [
			{"cost": 55, "guests": 1, "mugs": 10, "cooldown": 2.0, "text": "10 кухлів на день, кухоль наливається за 2 с. +1 відвідувач щодня."},
			{"cost": 110, "rep": 10, "mugs": 14, "cooldown": 1.0, "text": "14 кухлів на день, кухоль за 1 с."},
		]},
	"kitchen": {"name": "Кухня", "icon": [5, 4, 3],
		"desc": "Казан над вогнищем: готуй страви з лісових ресурсів і продуктів з ринку, крок за кроком, як зілля.",
		"base": {"bonus": 0},
		"levels": [
			{"cost": 75, "guests": 1, "bonus": 0, "text": "Відкриває кухню: трав'яна юшка, ягідний узвар, ягідний пиріг і юшка зі світних грибів. +1 відвідувач щодня."},
			{"cost": 140, "guests": 1, "rep": 25, "bonus": 1, "text": "Нові рецепти «Лісова печеня» і «Курячий пиріг», +1 порція кожної страви. +1 відвідувач щодня."},
		]},
	# The station is in the room from the start (its level 1); upgrade level N = station level N + 1.
	"alchemy": {"name": "Алхімічна станція", "icon": [1, 9, 5], "level_shift": 1,
		"desc": "Перегінний куб і нові колби на алхімічній станції: інколи з одних інгредієнтів виходить два зілля.",
		"base": {"double": 0.0},
		"levels": [
			{"cost": 85, "rep": 10, "double": 0.25, "text": "25% шанс зварити 2 зілля замість одного."},
			{"cost": 155, "rep": 25, "double": 0.5, "text": "Шанс 50% і новий рецепт «Еліксир удачі»."},
		]},
	"rooms": {"name": "Кімнати нагорі", "icon": [2, 1, 5],
		"desc": "Кімнати для героїв: у місті живе більше героїв, а ті, що ночують у таверні, платять за постій.",
		# rooms: heroes that can sleep here (each pays "rent" every morning if not on a contract); heroes: + max heroes.
		"base": {"rooms": 0, "rent": 0, "heroes": 0},
		"levels": [
			{"cost": 75, "guests": 1, "rep": 10, "rooms": 2, "rent": 5, "heroes": 1, "text": "2 кімнати: +1 герой у місті, кожен гість платить 5 зол. щоранку. +1 відвідувач щодня."},
			{"cost": 140, "rep": 25, "rooms": 4, "rent": 5, "heroes": 2, "text": "4 кімнати: +2 герої в місті, до 20 зол. щоранку."},
		]},
	"board": {"name": "Дошка контрактів", "icon": [2, 9, 1],
		"desc": "Більша дошка: на ній уміщається більше контрактів щоранку.",
		"base": {"contracts": 4},
		"levels": [
			{"cost": 40, "contracts": 5, "text": "5 контрактів на дошці щоранку."},
			{"cost": 100, "rep": 25, "contracts": 6, "text": "6 контрактів на дошці щоранку."},
		]},
	# Crafting tools (2026-11-09): quality of potions and dishes, see QUALITY. zone: how much wider the green zone of the
	# thermometer is on each side; prep: one cut / crumble less and a shorter grind.
	"tools": {"name": "Інструменти", "icon": [3, 1, 5],
		"desc": "Тесля лагодить посуд і привозить кращий: казан, ступку, ножі й термометр. Зілля й страви виходять якіснішими, а якісні дорожчі.",
		"base": {"quality": 0, "zone": 0.0, "prep": 0},
		"levels": [
			{"cost": 45, "quality": 8, "zone": 0.03, "prep": 1, "text": "Мідний казан і гострий ніж: якість +8, зелена зона на термометрі ширша, різати й терти швидше."},
			{"cost": 95, "rep": 10, "quality": 15, "zone": 0.06, "prep": 1, "text": "Срібна ступка й точний термометр: якість +15 (разом), зелена зона ще ширша."},
		]},
	# need: other factions' reputation needed for a level ({faction id: value}), see GameState.is_unlocked.
	"stash": {"name": "Схованка", "icon": [3, 0, 5],
		"desc": "Тайник під мостинами: варта на перевірці не знаходить частину краденого, а гості рідше його впізнають.",
		# hide: chance a stolen piece is not found by the inspection; witness: the chance a visitor recognises it is x this.
		"base": {"hide": 0.0, "witness": 1.0},
		"levels": [
			{"cost": 65, "need": {"crime": 10}, "hide": 0.5, "witness": 0.75, "text": "Половину краденого варта не знаходить, свідків −25%."},
			{"cost": 125, "need": {"crime": 30}, "hide": 0.85, "witness": 0.5, "text": "85% краденого сховано від варти, свідків −50%."},
		]},
}


# ---------- Crafting depth (2026-11-09) ----------
## Potions the keeper knows from the start. The others have to be found by an experiment in the alchemy window
## (throw 2..EXPERIMENT_MAX ingredients into the cauldron): once a recipe is open (reputation / upgrade) the recipe book
## shows a rumour about it: every ingredient but the last one, and how many pieces in all. Dishes are all known.
const START_RECIPES := ["heal_potion", "swamp_draught"]
const EXPERIMENT_MIN := 2
const EXPERIMENT_MAX := 5
## Quality of a potion / dish, 0..100: base + tools ("Інструменти") + order x (share of ingredients put in the
## recipe's order) + precision x (share of the heating spent near the middle of the green zone, +-sweet)
## + clean if it never boiled over, else - spoil x boil-overs.
const QUALITY := {"base": 30, "order": 25, "precision": 20, "clean": 10, "prep": 15, "spoil": 12, "sweet": 0.07}
## [lowest quality, name, price multiplier, colour, stars]. Pieces without a quality (bought, gathered, old saves) x1.
const QUALITY_TIERS := [
	[0, "Погана", 0.85, "c8836a", 0],
	[40, "Звичайна", 1.0, "d8cbb0", 1],
	[75, "Добра", 1.1, "a8d08d", 2],
	[92, "Відмінна", 1.2, "f2c14e", 3],
]
## A known potion that boils over this many times is spoiled: it turns into SPOILED_POTION.
const SPOIL_BOILS := 3
const SPOILED_POTION := "sleep_draught"
## What a failed experiment gives: no recipe like this ("miss") / the right ingredients in the wrong amounts ("near").
const EXPERIMENT_MISS := "murky_brew"
const EXPERIMENT_NEAR := "sleep_draught"
## The fence buys the side-effect potions: gold per piece; every deal: crime faction + crime, suspicion + susp.
const FENCE_BUYS := {"murky_brew": 6, "sleep_draught": 15}
const FENCE_BUY_DEAL := {"crime": 1, "susp": 1}
## Colour of the side-effect potions in the cauldron.
const SIDE_COLORS := {"murky_brew": "6a5a48", "sleep_draught": "8a7ab0"}


## Quality tier of a quality value (-1 = none: the "Звичайна" tier).
static func quality_tier(q: int) -> Array:
	var tier: Array = QUALITY_TIERS[1]
	if q < 0:
		return tier
	for t in QUALITY_TIERS:
		if q >= int(t[0]):
			tier = t
	return tier


static func quality_mult(q: int) -> float:
	return float(quality_tier(q)[2]) if q >= 0 else 1.0


## Ingredients of a recipe one piece at a time, in the recipe's order (the order of its "ingredients").
static func recipe_order(id: String) -> Array:
	var order := []
	var ings: Dictionary = recipe_of(id).get("ingredients", {})
	for ing in ings:
		for n in int(ings[ing]):
			order.append(ing)
	return order


## How each ingredient is prepared in the interactive brewing (scripts/brew_station.gd):
## grind = in the mortar, chop = on the cutting board, squeeze / sprinkle = straight over the cauldron.
## Ingredients not listed here are ground.
## Handled in a special way on the alchemy table: plucked before grinding, cracked before grinding, hops away.
const BREW_PLUCK := ["herbs"]
const BREW_CRACK := ["bones", "crystal"]
const BREW_RUNAWAY := ["toad"]
const BREW_PREP := {
	"herbs": "grind", "bones": "grind", "crystal": "grind",
	"burdock": "chop", "mandrake": "chop", "glow_mushroom": "chop",
	"berries": "squeeze",
	"grave_dust": "sprinkle", "ether_essence": "sprinkle",
	"swamp_moss": "grind", "lake_weed": "grind", "toad": "chop", "nightshade": "squeeze", "wisp_jar": "sprinkle",
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
	# Never comes by chance (weight 0): GameState adds him to the visitors by FENCE rules. He sells, not buys.
	"fence": {"title": "Скупник", "tags": [], "tolerance": 0.0, "purse": 0.0, "weight": 0},
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
const HERO_STATUS_NAMES := {"free": "Вільний", "quest": "На завданні", "injured": "Поранений", "jailed": "У в'язниці"}
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
## faction: who gives the contract (CONTRACT_FACTIONS). people: reputation +tier rep. state: state +tier rep, people +half,
## suspicion SUSP_STATE_CONTRACT. crime: crime +tier rep, suspicion, loot is stolen; "prosperity": change on success (GDD 14.16).
## need: reputation of other factions needed ({faction: value}); crime contracts also need the fence met once.
const CONTRACTS := {
	"rats": {"title": "Вигнати щурів з льоху", "faction": "people", "tier": "easy", "diff": 15, "reward": [10, 16],
		"desc": "Пекар скаржиться: щури вже їдять борошно просто з мішків.", "loot": []},
	"wolves": {"title": "Полювання на вовків", "faction": "people", "tier": "easy", "diff": 18, "reward": [16, 24],
		"desc": "Зграя вовків ріже овець за млином.",
		"loot": [{"item": "herbs", "min": 1, "max": 2, "chance": 0.5}, {"item": "mandrake", "min": 1, "max": 1, "chance": 0.15}]},
	"herb_escort": {"title": "Провести травницю лісом", "faction": "people", "tier": "easy", "diff": 16, "reward": [12, 18],
		"desc": "Травниця боїться йти по корінь лопуха сама: у лісі бачили вовчі сліди.",
		"loot": [{"item": "burdock", "min": 1, "max": 2, "chance": 0.6}, {"item": "berries", "min": 1, "max": 2, "chance": 0.5}]},
	"caravan": {"title": "Супроводити караван", "faction": "state", "tier": "medium", "diff": 25, "reward": [38, 52],
		"desc": "Купці везуть кристали з гір і бояться засідки.",
		"loot": [{"item": "crystal", "min": 1, "max": 1, "chance": 0.35}]},
	"bandits": {"title": "Зачистка розбійників", "faction": "state", "tier": "medium", "diff": 27, "reward": [45, 62], "rep": 10,
		"desc": "Розбійники засіли в старій вежі біля тракту.",
		"loot": [{"item": "axe", "min": 1, "max": 1, "chance": 0.3}, {"item": "shield", "min": 1, "max": 1, "chance": 0.3}, {"item": "chainmail", "min": 1, "max": 1, "chance": 0.12}]},
	"skeletons": {"title": "Полювання на скелетів", "faction": "state", "tier": "medium", "diff": 29, "reward": [50, 68], "rep": 25,
		"desc": "На кладовищі ночами брязкають кістки. Ті, що ходять.",
		"loot": [{"item": "bones", "min": 2, "max": 3}, {"item": "grave_dust", "min": 1, "max": 2, "chance": 0.6}, {"item": "ether_essence", "min": 1, "max": 1, "chance": 0.3}]},
	"necromancer": {"title": "Вбивство некроманта", "faction": "state", "tier": "hard", "diff": 31, "reward": [140, 190], "rep": 25,
		"desc": "Той, хто піднімає скелетів, живе у склепі за пагорбом.",
		"loot": [{"item": "sapphire_ring", "min": 1, "max": 1, "chance": 0.4}, {"item": "fire_scroll", "min": 1, "max": 1, "chance": 0.4}, {"item": "ether_essence", "min": 1, "max": 2, "chance": 0.7}]},
	"wyvern": {"title": "Приборкати віверну", "faction": "people", "tier": "hard", "diff": 33, "reward": [150, 210], "rep": 45,
		"desc": "Віверна гніздиться на скелі над перевалом і хапає коней.",
		"loot": [{"item": "moon_amulet", "min": 1, "max": 1, "chance": 0.35}, {"item": "crystal", "min": 1, "max": 2, "chance": 0.6}]},
	"ruins": {"title": "Прокляті руїни", "faction": "state", "tier": "hard", "diff": 35, "reward": [230, 300], "rep": 70,
		"desc": "Про таверну вже співають барди, тож з тобою говорить сам граф: у руїнах замку прокинулося щось давнє.",
		"loot": [{"item": "moon_amulet", "min": 1, "max": 1, "chance": 0.5}, {"item": "sapphire_ring", "min": 1, "max": 1, "chance": 0.5}, {"item": "ether_essence", "min": 1, "max": 2, "chance": 0.8}]},
	# State contracts that need the magistrate's trust.
	"thief": {"title": "Зловити злодія", "faction": "state", "tier": "easy", "diff": 17, "reward": [14, 20],
		"desc": "Хтось обносить крамниці на ринковій площі. Магістрат платить за спійманого.", "loot": []},
	"cult": {"title": "Знищити культ", "faction": "state", "tier": "hard", "diff": 32, "reward": [160, 210], "need": {"state": 35},
		"desc": "У каналізації під ратушею співають щось недобре. Радники просять зробити це тихо.",
		"loot": [{"item": "fire_scroll", "min": 1, "max": 1, "chance": 0.5}, {"item": "crystal", "min": 1, "max": 2, "chance": 0.6}]},
	# Criminal orders: more gold, but suspicion grows and a failed hero can be caught.
	"burglary": {"title": "Нічна крадіжка", "faction": "crime", "tier": "easy", "diff": 16, "reward": [24, 34], "prosperity": -1,
		"desc": "Склад суконника на розі стоїть без сторожа. Гільдія хоче половину.",
		"loot": [{"item": "wine", "min": 1, "max": 2, "chance": 0.5}]},
	"smuggling": {"title": "Контрабанда через перевал", "faction": "crime", "tier": "medium", "diff": 26, "reward": [70, 95], "need": {"crime": 10}, "prosperity": -1,
		"desc": "Кілька ящиків без мита мають пройти повз митну заставу.",
		"loot": [{"item": "crystal", "min": 1, "max": 2, "chance": 0.5}, {"item": "mead", "min": 2, "max": 3, "chance": 0.5}]},
	"blackmail": {"title": "Шантаж радника", "faction": "crime", "tier": "medium", "diff": 28, "reward": [80, 105], "need": {"crime": 20}, "prosperity": -1,
		"desc": "У радника є листи, які не мають побачити ні дружина, ні магістрат.",
		"loot": [{"item": "moon_amulet", "min": 1, "max": 1, "chance": 0.2}]},
	"heist": {"title": "Пограбувати скарбницю", "faction": "crime", "tier": "hard", "diff": 33, "reward": [260, 340], "need": {"crime": 30}, "prosperity": -2,
		"desc": "Податки міста везуть до скарбниці раз на тиждень. Гільдія знає, якою дорогою.",
		"loot": [{"item": "sapphire_ring", "min": 1, "max": 1, "chance": 0.4}, {"item": "moon_amulet", "min": 1, "max": 1, "chance": 0.4}]},
}

const START_ITEMS := {"bread": 3, "ale": 3, "herbs": 2, "berries": 1, "burdock": 1}


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


## Index of the rank of a faction ("state" / "crime") for this value.
static func faction_rank_index(faction: String, value: int) -> int:
	var ranks: Array = FACTIONS[faction]["ranks"]
	var index := 0
	for i in ranks.size():
		if value >= ranks[i][0]:
			index = i
	return index


## [lowest value, name, effect text] of the faction rank for this value.
static func faction_rank(faction: String, value: int) -> Array:
	return FACTIONS[faction]["ranks"][faction_rank_index(faction, value)]


## The first entry [lowest value, ...] of a table sorted from the top whose lowest value fits.
static func pick_by(table: Array, value: int) -> Array:
	for entry in table:
		if value >= entry[0]:
			return entry
	return table.back()


static func suspicion_level_index(value: int) -> int:
	var index := 0
	for i in SUSPICION_LEVELS.size():
		if value >= SUSPICION_LEVELS[i][0]:
			index = i
	return index


static func suspicion_level(value: int) -> Array:
	return SUSPICION_LEVELS[suspicion_level_index(value)]


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


## Where items are kept, for messages like "На «%s» немає місця" (any item can lie on any shelf or in the attic).
static func storage_name_of(_item_id: String = "") -> String:
	return "полицях"


## Names of the locations where this item can be gathered.
static func item_locations(id: String) -> Array[String]:
	var result: Array[String] = []
	for loc in LOCATIONS:
		var found := false
		for entry in LOCATIONS[loc]["loot"]:
			if entry["item"] == id:
				found = true
		if LOCATIONS[loc].has("fishing") and FISHING["fish"].has(id):
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
	return RECIPES.has(id) or KITCHEN_RECIPES.has(id)


## The recipe of a potion (RECIPES) or a dish (KITCHEN_RECIPES); {} if there is none.
static func recipe_of(id: String) -> Dictionary:
	if RECIPES.has(id):
		return RECIPES[id]
	return KITCHEN_RECIPES.get(id, {})


## Names of the potions this item is an ingredient of.
static func used_in_recipes(id: String) -> Array[String]:
	var result: Array[String] = []
	for table in [RECIPES, KITCHEN_RECIPES]:
		for potion in table:
			if table[potion]["ingredients"].has(id):
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
