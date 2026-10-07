extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var api = ApiClient.new()
	root.add_child(api)
	api.base_url = "http://127.0.0.1:1"
	var reply = await api.call_api("/unreachable")
	if reply.ok or reply.status != 0:
		push_error("Connection failure must remain an ambiguous transport error")
		quit(1)
		return
	print("CLIENT TRANSPORT: unreachable server handled without JSON parsing errors")
	quit(0)
