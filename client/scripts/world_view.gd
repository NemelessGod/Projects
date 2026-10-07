class_name WorldView
extends Control
var levels: Array = [0, 0, 0, 0, 0]
var world_index = 0


func _ready() -> void:
	custom_minimum_size.y = 240
	resized.connect(queue_redraw)


func _draw() -> void:
	var w = size.x
	var h = size.y
	for i in range(22):
		var x = fmod(i * 83.7 + 31, w)
		var y = fmod(i * 47.3 + 9, h * .7)
		draw_circle(Vector2(x, y), 1.7, Color("809bc8"))
	draw_circle(Vector2(w * .84, h * .22), 21, Color("c9d6ec"))
	draw_circle(Vector2(w * .86, h * .18), 19, Color("111d39"))
	var c = Vector2(w * .5, h * .66)
	var pts = PackedVector2Array(
		[
			c + Vector2(-w * .43, -12),
			c + Vector2(-w * .29, 50),
			c + Vector2(0, 83),
			c + Vector2(w * .30, 50),
			c + Vector2(w * .43, -12)
		]
	)
	draw_colored_polygon(pts, Color("28395f"))
	_draw_island_ellipse(
		c, Vector2(w * .43, 55), Color("45656b") if world_index == 0 else Color("65648c")
	)
	for i in range(5):
		var pos = Vector2(w * (.16 + i * .17), h * .61 + (-16 if i % 2 == 0 else 12))
		var level = int(levels[i]) if i < levels.size() else 0
		var height = 22 + level * 14
		var color = Color("86b5bc") if level > 0 else Color("4b6073")
		draw_rect(Rect2(pos - Vector2(17, height), Vector2(34, height)), color)
		draw_colored_polygon(
			PackedVector2Array(
				[
					pos + Vector2(-22, -height),
					pos + Vector2(0, -height - 18),
					pos + Vector2(22, -height)
				]
			),
			GameUi.GOLD if level > 0 else Color("788392")
		)
		if level > 0:
			draw_rect(Rect2(pos - Vector2(5, height - 6), Vector2(10, 12)), GameUi.GOLD)


func _draw_island_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for i in range(64):
		points.append(center + Vector2(cos(i * TAU / 64) * radius.x, sin(i * TAU / 64) * radius.y))
	draw_colored_polygon(points, color)
