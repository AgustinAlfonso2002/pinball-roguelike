class_name ShopScreen
extends Control
## Tienda entre noches: comprar, renovar la oferta, vender y continuar.

signal closed

var _offer: Array[Item] = []
var _rerolls := 0
var _coins := UiTheme.label("", GameFonts.BODY_SIZE, UiTheme.ACCENT)
var _info := UiTheme.label("", GameFonts.BODY_SIZE, UiTheme.MUTED)
var _cards := HBoxContainer.new()
var _owned := HFlowContainer.new()
var _reroll := Button.new()
var _continue := Button.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.position = Vector2(24, 16)
	box.custom_minimum_size = Vector2(912, 508)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := UiTheme.label("TIENDA DEL ARCADE", GameFonts.TITLE_SIZE, UiTheme.ACCENT)
	header.add_child(title)
	var sub := UiTheme.label("  Noche %d superada" % Run.night, GameFonts.BODY_SIZE, UiTheme.MUTED)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(sub)
	_coins.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(_coins)

	_cards.add_theme_constant_override("separation", 12)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_cards)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	_reroll.custom_minimum_size = Vector2(260, 40)
	_reroll.pressed.connect(_on_reroll)
	actions.add_child(_reroll)
	_continue.text = "Continuar a la noche %d >" % (Run.night + 1)
	_continue.custom_minimum_size = Vector2(320, 40)
	_continue.pressed.connect(func() -> void: closed.emit())
	actions.add_child(_continue)

	box.add_child(_info)
	box.add_child(UiTheme.label("TUS OBJETOS (tocá uno para venderlo)", GameFonts.BODY_SIZE, UiTheme.MUTED))
	_owned.add_theme_constant_override("h_separation", 6)
	_owned.add_theme_constant_override("v_separation", 4)
	box.add_child(_owned)

	_new_offer()
	_refresh()
	_continue.grab_focus()


func _new_offer() -> void:
	_offer = Items.random_offer(int(Run.stat(&"shop_slots")), Run.rng, Run.owned_unique_ids())


func _reroll_cost() -> int:
	return int(Run.stat(&"reroll_base_cost")) + _rerolls


func _on_reroll() -> void:
	var cost := _reroll_cost()
	if Run.coins < cost:
		_info.text = "No te alcanzan las fichas para renovar."
		return
	Run.add_coins(-cost)
	_rerolls += 1
	_new_offer()
	Sfx.play("target")
	_refresh()


func _on_buy(item: Item) -> void:
	var reason := Run.cannot_buy_reason(item)
	if reason != "":
		_info.text = reason
		return
	var replaced := Run.ball_item.display_name if item.kind == Item.Kind.BALL and Run.ball_item else ""
	Run.buy(item)
	_offer.erase(item)
	Sfx.play("bank_complete", 0.6)
	_info.text = "Compraste %s.%s" % [item.display_name, (" Reemplazó a %s." % replaced) if replaced != "" else ""]
	_refresh()


func _on_sell(item: Item) -> void:
	var value := item.sell_value()
	Run.sell(item)
	Sfx.play("drain", 0.5)
	_info.text = "Vendiste %s por %d fichas." % [item.display_name, value]
	_refresh()


func _refresh() -> void:
	_coins.text = "Fichas: %d" % Run.coins
	_reroll.text = "Renovar oferta (%d)" % _reroll_cost()

	for c in _cards.get_children():
		c.queue_free()
	for item in _offer:
		_cards.add_child(_make_card(item))
	if _offer.is_empty():
		_cards.add_child(UiTheme.label("No quedan objetos en la oferta.", GameFonts.BODY_SIZE, UiTheme.MUTED))

	for c in _owned.get_children():
		c.queue_free()
	for item in Run.all_items():
		var btn := Button.new()
		btn.text = "%s (+%d)" % [item.display_name, item.sell_value()]
		btn.tooltip_text = item.get_description()
		btn.pressed.connect(_on_sell.bind(item))
		_owned.add_child(btn)
	if Run.all_items().is_empty():
		_owned.add_child(UiTheme.label("Todavía no tenés objetos.", GameFonts.BODY_SIZE, UiTheme.MUTED))
	_fix_focus.call_deferred()


## Si el botón con foco desapareció (compra/venta), el foco vuelve a "Continuar"
## para poder seguir navegando con el joystick.
func _fix_focus() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or not is_instance_valid(owner) or owner.is_queued_for_deletion():
		_continue.grab_focus()


func _make_card(item: Item) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(214, 270)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var price := Run.price_of(item)
	btn.text = "%s\n%s · %s\n\n%s\n\n%d fichas" % [
		item.display_name,
		Item.KIND_NAMES[item.kind],
		Item.RARITY_NAMES[item.rarity],
		item.get_description(),
		price,
	]
	btn.add_theme_color_override("font_color", Item.RARITY_COLORS[item.rarity])
	var reason := Run.cannot_buy_reason(item)
	if reason != "":
		btn.modulate = Color(1, 1, 1, 0.55)
		btn.tooltip_text = reason
	btn.pressed.connect(_on_buy.bind(item))
	return btn
