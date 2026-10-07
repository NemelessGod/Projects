extends Control

var session = GameSession.new()
var brand = GameUi.label("SPIN KINGDOM", 30, GameUi.GOLD)
var counters = GameUi.label("", 22, GameUi.GOLD)
var energy = GameUi.label("", 20, GameUi.MINT)
var level = GameUi.label("", 20)
var notice = GameUi.paragraph("Подключение…", 17)
var tutorial = GameUi.paragraph("", 19)
var world_title = GameUi.label("Звёздная пристань", 26)
var world_description = GameUi.paragraph("", 18)
var world = WorldView.new()
var building_list = VBoxContainer.new()
var home_page = VBoxContainer.new()
var slot_page = VBoxContainer.new()
var profile_page = VBoxContainer.new()
var reels: Array[SlotReel] = []
var spin_button: Button
var retry_button: Button
var profile_text = GameUi.paragraph("", 18)
var xp_bar = ProgressBar.new()
var world_bar = ProgressBar.new()
var refresh_elapsed = 0.0
var page = "home"
var last_result = GameUi.paragraph("Три символа — одна история. Награды определяет сервер.", 20)


func _ready() -> void:
	_build_ui()
	add_child(session)
	session.changed.connect(_render)
	session.outcome.connect(_on_outcome)
	session.start()


func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color("0b142c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	root.add_child(brand)
	var wallet = VBoxContainer.new()
	wallet.add_child(counters)
	wallet.add_child(energy)
	wallet.add_child(level)
	xp_bar.custom_minimum_size.y = 8
	xp_bar.show_percentage = false
	wallet.add_child(xp_bar)
	root.add_child(GameUi.card(wallet))
	root.add_child(notice)
	retry_button = GameUi.button("Повторить подключение", session.reconnect)
	root.add_child(retry_button)
	root.add_child(tutorial)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var pages = VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	for panel in [home_page, slot_page, profile_page]:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_constant_override("separation", 12)
		pages.add_child(panel)
	home_page.add_child(world_title)
	home_page.add_child(world_description)
	home_page.add_child(GameUi.card(world))
	world_bar.show_percentage = true
	world_bar.custom_minimum_size.y = 24
	home_page.add_child(world_bar)
	home_page.add_child(building_list)
	var grid = GridContainer.new()
	grid.columns = 2
	home_page.add_child(grid)
	for feature in ["События", "Коллекции", "Рейтинг", "Друзья", "Магазин", "Колесо"]:
		var button = GameUi.button(feature, _future_feature.bind(feature))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	slot_page.add_child(GameUi.label("Механизм звёзд", 30, GameUi.GOLD))
	slot_page.add_child(
		GameUi.paragraph(
			"Собери свет для своего острова. Три одинаковых символа умножают монеты.", 20
		)
	)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in range(3):
		var reel = SlotReel.new()
		reels.append(reel)
		row.add_child(reel)
	slot_page.add_child(row)
	spin_button = GameUi.button("ВРАЩАТЬ · 1 искра", _spin, true)
	slot_page.add_child(spin_button)
	slot_page.add_child(GameUi.card(last_result))
	slot_page.add_child(
		GameUi.paragraph("Искры — игровая энергия. Награды: монеты, энергия и XP.", 17)
	)
	profile_page.add_child(GameUi.label("Паспорт навигатора", 28, GameUi.GOLD))
	profile_page.add_child(profile_text)
	profile_page.add_child(
		GameUi.paragraph(
			"Гостевой ключ хранится в приложении. Не удаляйте данные: Google-вход ещё не готов.", 18
		)
	)
	if OS.is_debug_build():
		profile_page.add_child(GameUi.label("DEV ONLY · адрес сервера", 20, GameUi.MINT))
		var endpoint = LineEdit.new()
		endpoint.placeholder_text = "http://127.0.0.1:8000"
		endpoint.custom_minimum_size.y = 52
		profile_page.add_child(endpoint)
		profile_page.add_child(
			GameUi.button("Сохранить адрес и перезапустить", _set_endpoint.bind(endpoint))
		)
	var navigation = HBoxContainer.new()
	for item in [["home", "Остров"], ["slot", "Слот"], ["profile", "Профиль"]]:
		var button = GameUi.button(item[1], _navigate.bind(item[0]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navigation.add_child(button)
	root.add_child(navigation)
	_navigate("home")


func _render() -> void:
	if not session.config.is_empty():
		brand.text = str(session.config.brand.title).to_upper()
		spin_button.text = "ВРАЩАТЬ · %d искра" % session.config.energy.cost
	var state = session.state
	notice.text = "Синхронизация…" if session.busy else session.message
	notice.modulate = Color.WHITE if session.online else GameUi.GOLD
	retry_button.visible = not session.online and not session.busy
	spin_button.disabled = (
		session.busy
		or not session.online
		or int(state.get("spins", 0)) < int(session.config.get("energy", {}).get("cost", 1))
	)
	for reel in reels:
		reel.spinning = session.busy and page == "slot"
	if state.is_empty():
		return
	counters.text = "Монеты  %d    ·    Кристаллы  %d" % [state.coins, state.premium]
	_update_energy()
	level.text = (
		"%s · Уровень %d · XP %d / %d"
		% [state.display_name, state.level, state.xp, state.xp_required]
	)
	xp_bar.max_value = state.xp_required
	xp_bar.value = state.xp
	world_title.text = state.world.name
	world_description.text = state.world.description
	world.world_index = state.world_index
	world.levels = state.world.buildings.map(func(b): return b.level)
	world.queue_redraw()
	var upgrades = 0
	var maximum = 0
	for child in building_list.get_children():
		child.hide()
		child.queue_free()
	for building in state.world.buildings:
		upgrades += int(building.level)
		maximum += building.costs.size()
		var row = VBoxContainer.new()
		row.add_child(
			GameUi.label(
				"%s · %d / %d" % [building.name, building.level, building.costs.size()], 21
			)
		)
		var button = GameUi.button(
			(
				"Построено"
				if building.next_cost == null
				else "Улучшить · %d монет" % building.next_cost
			),
			_upgrade.bind(building.id)
		)
		button.disabled = (
			session.busy
			or not session.online
			or building.next_cost == null
			or int(state.coins) < int(building.next_cost)
		)
		row.add_child(button)
		building_list.add_child(GameUi.card(row))
	world_bar.max_value = maximum
	world_bar.value = upgrades
	profile_text.text = (
		"ID: %s\nМир: %s\nВерсия баланса: %s\nСостояние: %s\nПрогресс хранится на сервере."
		% [
			state.player_id,
			state.world.name,
			state.config_revision,
			"онлайн" if session.online else "кэш / нет связи"
		]
	)
	var stage = session.cache.get("tutorial", "done")
	tutorial.visible = stage != "done"
	tutorial.text = (
		"Добро пожаловать! Откройте Слот и сделайте первое вращение."
		if stage == "spin"
		else "Отлично! Вернитесь на Остров и улучшите здание за монеты."
	)
	if state.get("campaign_complete", false):
		world_description.text = "Оба мира восстановлены! Новые острова появятся в следующих этапах."


func _process(delta: float) -> void:
	_update_energy()
	refresh_elapsed += delta
	if refresh_elapsed >= 30.0:
		refresh_elapsed = 0.0
		session.refresh()


func _update_energy() -> void:
	if session.state.is_empty():
		return
	var seconds = session.energy_seconds()
	var timer_text = "запас полон" if session.online else "нет связи"
	if seconds >= 0:
		timer_text = "новая через %02d:%02d" % [seconds / 60, seconds % 60]
	energy.text = "Искры  %d / %d · %s" % [session.state.spins, session.state.max_spins, timer_text]


func _navigate(target: String) -> void:
	page = target
	home_page.visible = page == "home"
	slot_page.visible = page == "slot"
	profile_page.visible = page == "profile"


func _spin() -> void:
	session.command("spin")


func _upgrade(id: String) -> void:
	session.command("upgrade", id)


func _on_outcome(result: Dictionary) -> void:
	if result.has("symbols"):
		for i in range(3):
			var id: String = result.symbols[i]
			var title = id
			for symbol in session.config.get("symbols", []):
				if symbol.id == id:
					title = symbol.label
			reels[i].reveal(id, title, .35 + i * .2)
		var reward: Dictionary = result.rewards
		last_result.text = (
			"%s+%d монет · +%d искр · +%d XP"
			% [
				"Тройное совпадение!\n" if reward.triple else "",
				reward.coins,
				reward.spins,
				reward.xp
			]
		)
	else:
		_popup(
			"Остров стал ярче",
			(
				"Здание улучшено. Стоимость: %d монет.\n%s"
				% [
					result.price,
					(
						"Мир завершён — награда сохранена!"
						if result.world_complete
						else "XP и прогресс сохранены на сервере."
					)
				]
			)
		)


func _future_feature(feature: String) -> void:
	_popup(
		feature, "Пока запланировано. Работают слот, энергия, строительство и сохранение прогресса."
	)


func _popup(title: String, text: String) -> void:
	var popup = AcceptDialog.new()
	popup.title = title
	popup.dialog_text = text
	popup.dialog_autowrap = true
	popup.min_size = Vector2i(400, 180)
	add_child(popup)
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)
	popup.popup_centered()


func _set_endpoint(input: LineEdit) -> void:
	var url = input.text.strip_edges().trim_suffix("/")
	if not url.begins_with("http://") and not url.begins_with("https://"):
		_popup("Адрес сервера", "Укажите полный HTTP(S) адрес.")
		return
	if session.busy:
		return
	if not session.cache.get("pending", {}).is_empty():
		_popup("Есть незавершённый запрос", "Сначала повторите подключение к прежнему серверу.")
		return
	session.cache["api_url"] = url
	# Endpoint changes deliberately require a new guest; do not send tokens to another host.
	session.cache.erase("token")
	session.cache.erase("profile")
	LocalStore.save_data(session.cache)
	get_tree().reload_current_scene()
