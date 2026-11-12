class_name Lang
## Language of the game's texts: Ukrainian when the game is opened in Ukraine, English everywhere else.
##
## The Ukrainian texts are the keys: Lang.t("Поверх %d з %d") % [n, total] gives the English template in English
## and the text itself in Ukrainian (a text that is not in EN stays as it is).
##
## Which language (first match):
##   1. --lang=uk / --lang=en on the command line (testing), ?lang=uk / ?lang=en in the web address;
##   2. the player's own choice: L in the menu switches the language and it is remembered;
##   3. opened in Ukraine: the time zone is Ukraine's (Europe/Kyiv, ...) or the system / browser region is UA,
##      or the system / browser language is Ukrainian -> Ukrainian;
##   4. otherwise English.
## On the web the page itself decides (export_presets.cfg, html/head_include: the same rules, so the loading
## screen and the page title are in the same language) and passes it on in window.ecLang.

static var code := "uk"   # "uk" or "en"

const UA_ZONES := ["Europe/Kyiv", "Europe/Kiev", "Europe/Uzhgorod", "Europe/Zaporozhye", "Europe/Simferopol"]
const SETTINGS := "user://settings.cfg"
const WEB_KEY := "ecLang"   # localStorage key and window.ecLang on the web page

const EN := {
	# title, menu, name input
	"Енергетична криза": "Energy Crisis",
	"Нажміть": "Press",
	"Пробіл": "Space",
	"щоб почати": "to start",
	"щоб продовжити": "to continue",
	"Швидкість": "Speed",
	"Вимикання": "Switch-off",
	"Ім'я гравця": "Player name",
	"Нікнейм": "Nickname",
	"Введіть ім'я гравця": "Enter your name",
	# characters
	"Джоан": "Joan",
	"Рекс": "Rex",
	"Алекс": "Alex",
	"Ніка": "Nika",
	# play HUD
	"Поверх 1": "Floor 1",
	"Поверх %d з %d": "Floor %d of %d",
	"Навантаження мережі": "Grid load",
	"%.1f / %.1f кВт": "%.1f / %.1f kW",
	"0.0 / 4.0 кВт": "0.0 / 4.0 kW",
	"Спожито: %.1f Вт • год": "Used: %.1f Wh",
	"Спожито: 0.0 Вт • год": "Used: 0.0 Wh",
	"%d%% економія": "%d%% saved",
	"100% економія": "100% saved",
	"Увімкнено приладів: %d": "Appliances on: %d",
	"Увімкнено приладів: 0": "Appliances on: 0",
	"Поверх %d": "Floor %d",
	"Вимикай прилади, бережи енергію!": "Switch things off, save energy!",
	"Новий прилад: ": "New appliance: ",
	"Нові прилади: ": "New appliances: ",
	"%s · %d Вт": "%s · %d W",
	"Старт!": "Go!",
	"Нажміть [color=#ffae00]%s[/color] щоб вимкнути: %s · %d Вт": "Press [color=#ffae00]%s[/color] to switch off: %s · %d W",
	"%s — його не можна вимикати": "%s can't be switched off",
	"Холодильник не можна вимикати!": "The fridge can't be switched off!",
	"Музика: %s": "Music: %s",
	"увімкнено": "on",
	"вимкнено": "off",
	"Масштаб: %.1f": "Zoom: %.1f",
	# results
	"Поверх пройдено!": "Floor cleared!",
	"Поверх не пройдено!": "Floor failed!",
	"Будинок врятовано!": "The building is saved!",
	"Коротке замикання! Вибило пробки.": "Short circuit! The fuses blew.",
	"Не всі прилади вимкнені.": "Not all appliances are off.",
	"Економія %d%% — нижче за поріг %d%%.": "Saved %d%%, below the %d%% target.",
	"Зекономлено: %.1f Вт • год": "Energy saved: %.1f Wh",
	"Економія %d%%  (потрібно ≥ %d%%)": "Saved %d%%  (need ≥ %d%%)",
	"Рахунок гри: %.1f Вт • год  (рекорд %.1f)": "Game score: %.1f Wh  (best %.1f)",
	"Рахунок гри: %.1f Вт • год  — новий рекорд!": "Game score: %.1f Wh, a new best!",
	"Рахунок гри: 0 Вт • год": "Game score: 0 Wh",
	"Рахунок гри: %.1f Вт • год": "Game score: %.1f Wh",
	"Місце в рейтингу: %d": "Rank: %d",
	"Ви пройшли всі %d поверхів.": "You cleared all %d floors.",
	"Зірок зібрано: %d з %d": "Stars collected: %d of %d",
	"до фіналу": "to see the finale",
	"спробувати ще раз": "to try again",
	"спочатку": "to start over",
	"щоб грати знову": "to play again",
	# leaderboard (hidden for now: GameConfig.SHOW_LEADERBOARD)
	"Рейтинг енергії": "Energy ranking",
	"№": "#",
	"Гравець": "Player",
	"Енергія, Вт • год": "Energy, Wh",
	"Поки що порожньо — стань першим!": "Nothing here yet. Be the first!",
	# appliances (label_uk in the apartments' layout files)
	"Телевізор": "TV",
	"Ігрова приставка": "Game console",
	"Торшер": "Floor lamp",
	"Обігрівач": "Heater",
	"Плита з духовкою": "Stove",
	"Чайник": "Kettle",
	"Мікрохвильовка": "Microwave",
	"Холодильник": "Fridge",
	"Настільна лампа": "Bedside lamp",
	"Праска": "Iron",
	"Комп'ютер": "Computer",
	"Лампа на столі": "Desk lamp",
	"Нічник": "Night light",
	"Світло над дзеркалом": "Mirror light",
	"Фен": "Hair dryer",
	"Пральна машина": "Washing machine",
	"Бойлер": "Water heater",
}


static func t(s: String) -> String:
	if code == "uk":
		return s
	return EN.get(s, s)


static func detect() -> void:
	code = _choose()


## Switch to the other language and remember the choice.
static func toggle() -> String:
	code = "en" if code == "uk" else "uk"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			return code   # a test run with a fixed language: do not remember the switch
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.setItem('%s', '%s'); } catch (e) {} window.%s = '%s';"
				% [WEB_KEY, code, WEB_KEY, code], true)
	else:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS)
		cfg.set_value("game", "lang", code)
		cfg.save(SETTINGS)
	return code


static func _choose() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			return "en" if a.substr(7) == "en" else "uk"
	if OS.has_feature("web"):
		var page = JavaScriptBridge.eval("window.%s || ''" % WEB_KEY, true)   # the page's decision
		if page is String and (page == "uk" or page == "en"):
			return page
	else:
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS) == OK:
			var saved := String(cfg.get_value("game", "lang", ""))
			if saved == "uk" or saved == "en":
				return saved
	return "uk" if in_ukraine() else "en"


## Opened in Ukraine (or by someone whose system / browser speaks Ukrainian).
static func in_ukraine() -> bool:
	if _time_zone() in UA_ZONES:
		return true
	var loc := OS.get_locale().replace("-", "_")   # "uk_UA", "en_UA", "en_US", "uk"
	return loc.begins_with("uk") or loc.ends_with("_UA")


static func _time_zone() -> String:
	## IANA name of the time zone ("Europe/Kyiv"), "" if unknown.
	if OS.has_feature("web"):
		var z = JavaScriptBridge.eval("(Intl.DateTimeFormat().resolvedOptions().timeZone || '')", true)
		return z if z is String else ""
	if OS.get_name() in ["macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		var d := DirAccess.open("/etc")   # /etc/localtime -> .../zoneinfo/Europe/Kyiv
		if d and d.is_link("localtime"):
			var target := d.read_link("localtime")
			var i := target.find("zoneinfo/")
			if i >= 0:
				return target.substr(i + 9)
	return ""
