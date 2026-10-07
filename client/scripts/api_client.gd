class_name ApiClient
extends Node

var base_url: String = ""
var token: String = ""


func call_api(
	path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}
) -> Dictionary:
	var request = HTTPRequest.new()
	request.timeout = 12.0
	add_child(request)
	var headers = PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var error = request.request(
		base_url + path,
		headers,
		method,
		JSON.stringify(body) if method != HTTPClient.METHOD_GET else ""
	)
	if error != OK:
		request.queue_free()
		return {
			"ok": false,
			"status": 0,
			"message": "Не удалось отправить запрос. Проверьте подключение."
		}
	var reply = await request.request_completed
	request.queue_free()
	var code: int = reply[1]
	var data = JSON.parse_string(reply[3].get_string_from_utf8())
	if reply[0] != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"status": 0,
			"message":
			"Нет связи с сервером. Результат сохранённого запроса можно повторить безопасно."
		}
	if not data is Dictionary:
		return {"ok": false, "status": code, "message": "Сервер вернул некорректный ответ."}
	if code < 200 or code >= 300:
		return {"ok": false, "status": code, "message": str(data.get("detail", "Ошибка сервера"))}
	return {"ok": true, "status": code, "data": data}
