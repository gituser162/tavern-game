# Завдання: портрети відвідувачів і героїв

Таверна «Втомлений Грифон», Godot 4. Документ для художника або генератора зображень (Gemini тощо) і для подальшої зміни коду.

## 1. Навіщо

Зараз у грі лише 2 тимчасові портрети (жінка з зіллям і чоловік з мотузкою, згенеровані Gemini). Кожен відвідувач отримує один із них випадково, тому Селянин, Чарівниця і Воїн виглядають однаково. Потрібно, щоб з першого погляду було видно, **хто прийшов**: тип відвідувача, а для героя ще й клас.

## 2. Хто приходить до таверни (з коду гри)

### Звичайні відвідувачі (`CUSTOMER_TYPES` у `game_data.gd`)

| id | Назва в грі | Що купує | Як має виглядати |
|---|---|---|---|
| `peasant` | Селянин | їжа, напої | простий льняний одяг, капелюх або хустка, засмагле обличчя, руки робітника; можна з вилами, кошиком, мішком |
| `reveler` | Гуляка | напої | розхристаний, червоні щоки, кухоль у руці, весела або сонна усмішка, яскравий пом'ятий одяг |
| `herbalist` | Травниця | ресурси, зілля | зелено-коричневий плащ, сумка з травами, пучок трав або ступка, вінок або хустка |
| `merchant` | Купець | ресурси, магія, напої | добротний оксамитовий одяг, хутряний комір, гаманець, перстні, хитрий погляд |
| `mage` | Чарівниця | магія, зілля, ресурси | мантія з зірками або рунами, гостра шапка або каптур, посох чи кристал, легке сяйво |

### Герої (`HERO_CLASSES`)

Тип `hero` («Шукач пригод») у грі завжди перетворюється на конкретного героя одного з 4 класів. Окремий портрет «Шукача пригод» не потрібен.

| id | Клас | Як має виглядати |
|---|---|---|
| `warrior` | Воїн | кольчуга або латні наплічники, меч на плечі чи за спиною, шрам, рішучий погляд |
| `archer` | Лучник | шкіряна куртка, каптур, лук і сагайдак за спиною, худорлявий, уважні очі |
| `mage` | Маг | темна мантія, посох з кристалом або книга, світло магії на обличчі (має відрізнятися від цивільної Чарівниці: бойовий, у дорожньому одязі) |
| `tank` | Танк | дуже широкий, важкі обладунки, великий щит, шолом у руці або на голові, спокійний і масивний |

Герої постійні (до 8 одночасно, залежно від репутації). Один герой має **завжди виглядати однаково**: після першого візиту його портрет закріплюється за ним.

## 3. Скільки портретів

| Група | Мінімум для MVP | Бажано |
|---|---|---|
| Селянин | 2 (ч + ж) | 4 |
| Гуляка | 2 (ч + ж) | 4 |
| Травниця | 2 (ж) | 3 |
| Купець | 2 (ч + ж) | 4 |
| Чарівниця | 2 (ж) | 3 |
| Воїн | 2 (ч + ж) | 4 |
| Лучник | 2 (ч + ж) | 4 |
| Маг | 2 (ч + ж) | 4 |
| Танк | 2 (ч + ж) | 4 |
| **Разом** | **18** | **34** |

Бажаний набір героїв (16) дорівнює кількості імен у грі, тому 8 героїв одночасно майже ніколи не повторюватимуть обличчя. Різноманітність усередині групи: вік (молодий / середній / старий), раси (люди, гноми, ельфи, напіврослики, бо в іменах є «Грімбальд», «Еладріель», «Торін»), колір шкіри та волосся.

## 4. Стиль

- **Піксель-арт**, як фон таверни (320×180, теплі коричнево-бурштинові тони, світло від каміна). Поточні портрети Gemini мальовані, не піксельні, і випадають зі стилю.
- Погруддя (голова + плечі + руки з предметом), погляд на гравця, легкий поворот на 3/4.
- Освітлення тепле, ніби від свічок і каміна, зліва-спереду.
- Чіткий темний контур (1 px), обмежена палітра (24–32 кольори на портрет), без згладжування і без розмиття.
- Однаковий масштаб голів у всіх портретах: голова займає приблизно верхню третину кадру.
- Без тексту, рамок і підписів.

## 5. Технічні вимоги до файлу

- **Формат:** PNG з **справжньою прозорістю** (альфа-канал). Не JPEG і не «шахівниця», намальована на картинці (саме така була в зображеннях Gemini, її довелося вирізати вручну).
- **Розмір:** 96×128 px (ширина × висота), 1 піксель = 1 піксель арту. Гра сама збільшить у 4–5 разів. Якщо генератор віддає велике зображення (напр. 1024×1365), його зменшать до 96×128 скриптом без згладжування.
- **Персонаж стоїть на нижньому краї кадру** (плечі обрізані низом), зверху 4–8 px вільного місця.
- **Назви файлів:** `assets/portraits/<група>_<стать>_<номер>.png`, малими латинськими літерами:
  - `peasant_m_01.png`, `peasant_f_01.png`, `reveler_m_01.png`, `herbalist_f_01.png`, `merchant_f_02.png`, `mage_f_01.png`
  - герої з префіксом `hero_`: `hero_warrior_m_01.png`, `hero_archer_f_01.png`, `hero_mage_m_01.png`, `hero_tank_f_02.png`
  - `m` чоловік, `f` жінка; номер двозначний.

## 6. Готові промпти для генерації

Спільна частина (додається до кожного промпту):

> pixel art character portrait, bust shot, medieval fantasy tavern visitor, facing the viewer in 3/4 view, warm candle and fireplace lighting from the front-left, 1px dark outline, limited palette of about 32 colors, no anti-aliasing, crisp pixels, 96x128 pixel sprite style, character cut off by the bottom edge at the chest, **transparent background**, no text, no frame, consistent style for a game character set

Індивідуальна частина:

| Файл | Промпт |
|---|---|
| peasant_m_01 | middle-aged male peasant farmer, straw hat, rough linen shirt, sunburnt face, stubble, holding a small sack of grain over his shoulder, tired kind smile |
| peasant_f_01 | young female peasant, headscarf, simple brown dress with apron, rosy cheeks, holding a wicker basket of eggs |
| reveler_m_01 | jolly drunk man, red cheeks and nose, unbuttoned colorful doublet, raising a foaming beer mug, big grin |
| reveler_f_01 | cheerful tipsy woman, messy curly hair, bright red bodice, holding a wine cup, laughing |
| herbalist_f_01 | young herbalist woman, green hooded cloak, flower wreath, leather bag full of herbs, holding a bundle of dried plants |
| herbalist_f_02 | old wise herbalist woman, grey braid, brown shawl, holding a small stone mortar with herbs, knowing smile |
| merchant_m_01 | plump wealthy merchant man, velvet coat with fur collar, gold rings, holding a coin purse, sly smile, trimmed beard |
| merchant_f_01 | elegant merchant woman, dark green velvet dress, pearl necklace, holding a ledger book, calculating look |
| mage_f_01 | young sorceress, deep blue robe with silver stars, pointed hat, glowing crystal in her palm lighting her face |
| mage_f_02 | elf enchantress, long silver hair, violet robe with runes, pointed ears, holding a small staff with a glowing tip |
| hero_warrior_m_01 | battle-hardened human warrior, chainmail and leather pauldron, scar across the cheek, greatsword resting on his shoulder, determined look |
| hero_warrior_f_01 | strong female warrior, braided red hair, steel breastplate, short sword and round shield, confident smirk |
| hero_archer_m_01 | lean elf archer man, green hood, leather jerkin, longbow and quiver over his back, sharp focused eyes |
| hero_archer_f_01 | young female ranger, brown hood down, freckles, leather armor, holding a bow, arrow feathers visible behind shoulder |
| hero_mage_m_01 | travelling battle mage, dark grey hooded robe, short beard, wooden staff with a blue crystal, arcane glow in his eyes |
| hero_mage_f_01 | young battle mage woman, crimson travel cloak, spellbook under arm, small flame hovering above her hand |
| hero_tank_m_01 | huge dwarf defender, heavy plate armor, thick braided beard, enormous tower shield in front of him, calm stern face |
| hero_tank_f_01 | massive female knight, full heavy plate armor, helmet tucked under arm, short dark hair, big kite shield, serene face |

Для «бажаного» набору (34) робіть варіації: змінюйте вік, расу (human, dwarf, elf, halfling), колір волосся і шкіри, предмет у руках.

**Порада для Gemini:** генеруйте всіх одного типу в одній розмові («now make another one in exactly the same style»), так стиль буде стабільнішим. Gemini часто малює «шахівницю» замість прозорості: просіть «plain solid flat magenta background (#FF00FF)», тоді фон легко прибрати скриптом.

## 7. Як код вибиратиме портрет (зміни в `client_portrait.gd`)

Зараз: список із 2 файлів у `PORTRAITS`, вибір за хешем імені, без урахування типу.

Буде:
1. Під час запуску гра сама сканує `assets/portraits/` (`ResourceLoader.list_directory`, Godot 4.4+) і групує файли за префіксом: `peasant`, `reveler`, `herbalist`, `merchant`, `mage`, `hero_warrior`, `hero_archer`, `hero_mage`, `hero_tank`. Нові портрети додаються простим копіюванням файлу, без правок коду.
2. **Звичайний відвідувач:** випадковий портрет з групи свого типу (за хешем імені+типу, щоб у межах дня не мигав).
3. **Герой:** при створенні героя (`_new_hero`) йому записується поле `portrait` з групи його класу, з тих, що ще не зайняті іншими героями. Тоді герой виглядає однаково в таверні, у вікні «Герої» і при поверненні з контракту.
4. **Стать і ім'я:** зараз імена не мають статі, тож Травниця може зватися «Тарас». Пропоную розділити `NAMES` на чоловічі й жіночі та вибирати ім'я за статтю з назви файлу портрета (`_m_` / `_f_`). Для Травниці й Чарівниці беруться лише жіночі портрети та імена.
5. Якщо для групи немає жодного файлу, береться будь-який наявний портрет (як зараз), тож гра не зламається, поки малюнки готуються частинами.
6. Фільтр текстури змінюється з `LINEAR` на `NEAREST`, щоб піксельні портрети були чіткими при збільшенні.

## 8. Як здавати роботу

- Файли PNG покласти в `A:/godot/tavern-game/assets/portraits/` з назвами за п. 5.
- Старі `portrait_01.png` і `portrait_02.png` можна залишити: вони не підпадають під жоден префікс і використовуватимуться лише як запасні.
- Порядок: спершу мінімальний набір (18), потім решта.
