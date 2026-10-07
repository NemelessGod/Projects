extends SceneTree
## Real client -> HTTP -> PostgreSQL. Run twice, second time with -- --restore.
var failures = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var session: GameSession = scene.session
	for i in range(300):
		if session.online and not session.busy:
			break
		await create_timer(.05).timeout
	check(session.online, "Guest authentication / profile load failed")
	if not session.online:
		quit(1)
		return
	var restore = "--restore" in OS.get_cmdline_user_args()
	if restore:
		var expected = JSON.parse_string(
			FileAccess.get_file_as_string("user://smoke_expected.json")
		)
		for field in ["player_id", "coins", "xp", "level", "world_index"]:
			check(session.state[field] == expected[field], "Restart did not restore " + field)
		check(
			session.state.world.buildings[0].level == expected.world.buildings[0].level,
			"Building not restored"
		)
		check(session.state.spins >= expected.spins, "Restart lost energy")
		check(
			session.state.spins <= maxi(int(expected.spins), int(expected.max_spins)),
			"Energy exceeded valid regeneration cap"
		)
		print("CLIENT RESTART: guest identity, balances, XP and building restored")
	else:
		check(
			session.state.coins == 300, "Smoke test requires a fresh isolated user-data directory"
		)
		scene._navigate("slot")
		await session.command("spin")
		check(session.online, "Spin failed")
		check(session.state.xp == 2, "Server spin XP missing")
		scene._navigate("home")
		await session.command("upgrade", "beacon")
		check(session.state.world.buildings[0].level == 1, "Upgrade failed")
		check(session.state.xp == 17, "Upgrade XP missing")
		# Simulate an acknowledged-on-server but lost-on-client response.
		var body = {"idempotency_key": LocalStore.new_key()}
		var committed = await session.api.call_api("/v1/spins", HTTPClient.METHOD_POST, body)
		check(committed.ok, "Replay setup spin failed")
		session.cache["pending"] = {"path": "/v1/spins", "action": "spin", "body": body}
		check(LocalStore.save_data(session.cache), "Pending request was not persisted")
		await session.reconnect()
		check(session.state.coins == committed.data.state.coins, "Retry duplicated coin reward")
		check(session.state.spins == committed.data.state.spins, "Retry duplicated energy reward")
		check(session.state.xp == 19, "Retry duplicated XP reward")
		var f = FileAccess.open("user://smoke_expected.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(session.state))
		f.close()
		print("CLIENT E2E: guest -> spin -> upgrade -> lost-response replay verified")
	await create_timer(1).timeout
	quit(0 if failures == 0 else 1)
