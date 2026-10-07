class_name GameUi
extends RefCounted

const INK = Color("111d39")
const GOLD = Color("ffd275")
const MINT = Color("66e3c4")
const TEXT = Color("f0f5ff")


static func style(color: Color, radius: int = 18) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func button(text: String, action: Callable, primary: bool = false) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = 56
	node.add_theme_font_size_override("font_size", 22)
	node.add_theme_stylebox_override("normal", style(GOLD if primary else Color("243754")))
	node.add_theme_stylebox_override(
		"hover", style(Color("ffe4aa") if primary else Color("304967"))
	)
	node.add_theme_stylebox_override("pressed", style(MINT if primary else Color("365b70")))
	node.add_theme_stylebox_override("disabled", style(Color("273142")))
	node.add_theme_color_override("font_color", INK if primary else TEXT)
	node.pressed.connect(action)
	return node


static func card(content: Control, color: Color = INK) -> PanelContainer:
	var node = PanelContainer.new()
	node.add_theme_stylebox_override("panel", style(color))
	node.add_child(content)
	return node


static func paragraph(text: String, size: int = 20) -> Label:
	var node = label(text, size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node
