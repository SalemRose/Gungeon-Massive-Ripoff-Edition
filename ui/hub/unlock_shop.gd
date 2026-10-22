class_name UnlockShop
extends CanvasLayer
## The hub's unlock terminal screen: every permanent unlock with its price.
## Works with mouse, keyboard (arrows + Enter) and gamepad (D-pad + A);
## Esc / B (ui_cancel) or the Close button leaves.
##
##     shop.open()      # shows it and pauses the game behind it
##     shop.closed      # emitted when the player leaves
##
## All the rules (can I afford it? do I own it?) live in UnlockCatalog; this
## file only draws buttons and calls UnlockCatalog.purchase().
##
## ART: it is plain Controls; give the Panel a theme / StyleBox to restyle.

signal closed
signal purchased(unlock_id: StringName)

var _panel: PanelContainer
var _currency_label: Label
var _info_label: Label
var _list: VBoxContainer
var _buttons: Dictionary = {}   # unlock id -> Button


func _ready() -> void:
	layer = 50
	# Keep working while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(440.0, 0.0)
	_panel.position = Vector2(-220.0, -150.0)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var title := Label.new()
	title.text = "UNLOCKS"
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	_currency_label = Label.new()
	column.add_child(_currency_label)
	_list = VBoxContainer.new()
	column.add_child(_list)
	_info_label = Label.new()
	_info_label.custom_minimum_size = Vector2(0.0, 36.0)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 12)
	column.add_child(_info_label)
	var close := Button.new()
	close.name = "Close"
	close.text = "Close"
	close.pressed.connect(close_shop)
	column.add_child(close)


func open() -> void:
	_refresh()
	visible = true
	get_tree().paused = true
	# Put keyboard / gamepad focus on the first thing you can buy (or Close).
	_focus_first()


func close_shop() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_shop()


## Rebuilds the rows from the catalog and the current save.
func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	_buttons.clear()
	_currency_label.text = "Currency: %d" % int(get_node("/root/SaveData").get_value("currency", 0))   # by path: see UnlockCatalog._save
	for entry in UnlockCatalog.all():
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var kind_text := "gun" if entry.kind == UnlockData.Kind.GUN else "item"
		if UnlockCatalog.is_owned(entry.id):
			button.text = "%s (%s)   OWNED" % [entry.display_name, kind_text]
			button.disabled = true
		else:
			button.text = "%s (%s)   %d" % [entry.display_name, kind_text, entry.cost]
			# Affordability is shown by colour; pressing without money just says so.
			if not UnlockCatalog.can_buy(entry.id):
				button.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
		button.pressed.connect(_on_buy.bind(entry.id))
		button.focus_entered.connect(func(): _info_label.text = entry.description)
		button.mouse_entered.connect(func(): _info_label.text = entry.description)
		_list.add_child(button)
		_buttons[entry.id] = button


func _on_buy(unlock_id: StringName) -> void:
	if UnlockCatalog.purchase(unlock_id):
		purchased.emit(unlock_id)
		_refresh()
		_focus_first()
	else:
		_info_label.text = "Not enough currency."


func _focus_first() -> void:
	# Wait a frame: the rows were just (re)created.
	await get_tree().process_frame
	for button in _list.get_children():
		if button is Button and not button.disabled:
			button.grab_focus()
			return
	(_panel.find_child("Close", true, false) as Button).grab_focus()
