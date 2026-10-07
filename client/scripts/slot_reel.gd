class_name SlotReel
extends PanelContainer
var icon = SymbolIcon.new()
var caption = GameUi.label("Монета", 16, GameUi.GOLD)
var spinning = false
var elapsed = 0.0
var ids: Array = ["coin", "bag", "energy", "star", "jackpot"]
var index = 0


func _ready() -> void:
	add_theme_stylebox_override("panel", GameUi.style(Color("192b48")))
	custom_minimum_size = Vector2(130, 160)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column = VBoxContainer.new()
	icon.custom_minimum_size = Vector2(80, 100)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(icon)
	column.add_child(caption)
	add_child(column)


func _process(delta: float) -> void:
	if spinning:
		elapsed += delta
		if elapsed > .08:
			elapsed = 0.0
			index = (index + 1) % ids.size()
			icon.symbol = ids[index]
			caption.text = "• • •"


func reveal(id: String, title: String, delay: float) -> void:
	spinning = true
	await get_tree().create_timer(delay).timeout
	spinning = false
	icon.symbol = id
	caption.text = title
	var tween = create_tween()
	tween.tween_property(icon, "modulate", Color(1.5, 1.5, 1.5), .12)
	tween.tween_property(icon, "modulate", Color.WHITE, .25)
