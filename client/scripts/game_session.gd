class_name GameSession
extends Node

signal changed
signal outcome(result: Dictionary)

var api = ApiClient.new()
var state: Dictionary = {}
var config: Dictionary = {}
var cache: Dictionary = {}
var busy = false
var online = false
var message = "Подключение к звёздному морю…"
var received_at: int = 0


func _ready() -> void:
	add_child(api)


func start() -> void:
	cache = LocalStore.load_data()
	api.base_url = OS.get_environment("SPIN_API_URL")
	if api.base_url.is_empty():
		api.base_url = str(ProjectSettings.get_setting("game/api_url", ""))
	if api.base_url.is_empty() and OS.is_debug_build():
		api.base_url = str(cache.get("api_url", "http://127.0.0.1:8000"))
	if (
		not api.base_url.begins_with("https://")
		and not (OS.is_debug_build() and api.base_url.begins_with("http://"))
	):
		message = "Для release необходим HTTPS адрес backend в game/api_url."
		changed.emit()
		return
	if cache.get("api_url", "") != api.base_url:
		cache = {"api_url": api.base_url}
	api.token = str(cache.get("token", ""))
	state = cache.get("profile", {})
	config = cache.get("config", {})
	changed.emit()
	await reconnect()


func reconnect() -> void:
	if busy:
		return
	busy = true
	changed.emit()
	if api.token.is_empty():
		var auth = await api.call_api("/v1/auth/guest", HTTPClient.METHOD_POST)
		if not _check(auth):
			_finish()
			return
		api.token = auth.data.token
		cache["token"] = api.token
		cache["api_url"] = api.base_url
		cache["tutorial"] = "spin"
		state = auth.data.state
		cache["profile"] = state
		if not LocalStore.save_data(cache):
			message = "Не удалось сохранить гостевой ключ. Операции отключены."
			online = false
			_finish()
			return
	var cfg = await api.call_api("/v1/config")
	if not _check(cfg):
		_finish()
		return
	config = cfg.data
	cache["config"] = config
	var pending: Dictionary = cache.get("pending", {})
	if not pending.is_empty():
		await _send_pending(pending)
	else:
		await _refresh()
	_finish()


func refresh() -> void:
	if busy or not online:
		return
	busy = true
	await _refresh()
	_finish()


func _refresh() -> void:
	var reply = await api.call_api("/v1/player")
	if _check(reply):
		_accept(reply.data)
		message = "Прогресс синхронизирован"


func command(action: String, building_id: String = "") -> void:
	if busy or not online or not cache.get("pending", {}).is_empty():
		return
	busy = true
	var body = {"idempotency_key": LocalStore.new_key()}
	if action == "upgrade":
		body["building_id"] = building_id
	var pending = {
		"path": "/v1/spins" if action == "spin" else "/v1/buildings/upgrade",
		"body": body,
		"action": action
	}
	cache["pending"] = pending
	# Persist the exact key BEFORE any request. Reconnect/restart always reuses it.
	if not LocalStore.save_data(cache):
		message = "Не удалось сохранить запрос. Проверьте свободное место."
		cache.erase("pending")
		_finish()
		return
	changed.emit()
	await _send_pending(pending)
	_finish()


func _send_pending(pending: Dictionary) -> void:
	var reply = await api.call_api(pending.path, HTTPClient.METHOD_POST, pending.body)
	if not _check(reply):
		# Transport errors / 5xx can mean a committed operation: retain key.
		if reply.status >= 400 and reply.status < 500:
			cache.erase("pending")
			LocalStore.save_data(cache)
			if reply.status != 401:
				online = true
		return
	cache.erase("pending")
	_accept(reply.data.state)
	if pending.action == "spin" and cache.get("tutorial", "") == "spin":
		cache["tutorial"] = "upgrade"
	elif pending.action == "upgrade":
		cache["tutorial"] = "done"
	LocalStore.save_data(cache)
	outcome.emit(reply.data.result)
	# A replay returns the original snapshot. Fetch authoritative latest state.
	await _refresh()


func _accept(profile: Dictionary) -> void:
	state = profile
	received_at = Time.get_ticks_msec()
	cache["profile"] = profile
	online = true
	LocalStore.save_data(cache)
	changed.emit()


func _check(reply: Dictionary) -> bool:
	if reply.ok:
		return true
	online = false
	message = reply.message
	if reply.status == 401:
		message = "Сессия недействительна. Требуется восстановление доступа."
	return false


func _finish() -> void:
	busy = false
	changed.emit()


func energy_seconds() -> int:
	if not online or state.get("seconds_to_next_spin") == null:
		return -1
	return maxi(
		0, int(state.seconds_to_next_spin) - int((Time.get_ticks_msec() - received_at) / 1000)
	)
