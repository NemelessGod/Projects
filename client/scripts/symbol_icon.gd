class_name SymbolIcon
extends Control
## Original vector placeholders, replace through AssetManager in later phases.
var symbol = "coin":
	set(value):
		symbol = value
		queue_redraw()


func _draw() -> void:
	var center = size / 2
	var r = minf(size.x, size.y) * 0.31
	match symbol:
		"coin":
			draw_circle(center, r, GameUi.GOLD)
			draw_arc(center, r * 0.72, 0, TAU, 48, Color("bb8046"), 3, true)
			draw_line(
				center + Vector2(0, -r * .45), center + Vector2(0, r * .45), GameUi.INK, 5, true
			)
		"bag":
			draw_circle(center + Vector2(0, r * .18), r, Color("e5a976"))
			draw_colored_polygon(
				PackedVector2Array(
					[
						center + Vector2(-r * .6, -r),
						center + Vector2(r * .6, -r),
						center + Vector2(r * .4, -r * .35),
						center + Vector2(-r * .4, -r * .35)
					]
				),
				GameUi.GOLD
			)
			draw_line(
				center + Vector2(-r * .5, -r * .4),
				center + Vector2(r * .5, -r * .4),
				GameUi.INK,
				4,
				true
			)
		"energy":
			var pts = PackedVector2Array(
				[
					center + Vector2(r * .2, -r),
					center + Vector2(-r * .7, r * .1),
					center + Vector2(-r * .05, r * .1),
					center + Vector2(-r * .2, r),
					center + Vector2(r * .7, -r * .1),
					center + Vector2(r * .05, -r * .1)
				]
			)
			draw_colored_polygon(pts, GameUi.MINT)
		"star":
			var pts = PackedVector2Array()
			for i in range(10):
				pts.append(
					(
						center
						+ (
							Vector2.from_angle(-PI / 2 + i * PI / 5)
							* r
							* (1.0 if i % 2 == 0 else .45)
						)
					)
				)
			draw_colored_polygon(pts, Color("bca7ff"))
		"jackpot":
			var pts = PackedVector2Array(
				[
					center + Vector2(-r, r * .6),
					center + Vector2(-r, -r * .7),
					center + Vector2(-r * .4, -r * .15),
					center + Vector2(0, -r),
					center + Vector2(r * .4, -r * .15),
					center + Vector2(r, -r * .7),
					center + Vector2(r, r * .6)
				]
			)
			draw_colored_polygon(pts, GameUi.GOLD)
			draw_circle(center + Vector2(0, r * .2), r * .2, Color("af7ce0"))
