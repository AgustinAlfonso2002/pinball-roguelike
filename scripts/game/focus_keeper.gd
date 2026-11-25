class_name FocusKeeper
extends Node
## Si ningún botón tiene el foco (por ejemplo, después de un clic con el mouse)
## y se usa la cruceta, el stick o Cruz, enfoca el primer botón visible.
## Así todos los menús se pueden manejar siempre con el joystick.

const NAV_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]

var root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not root or root.get_viewport().gui_get_focus_owner() != null:
		return
	for a in NAV_ACTIONS:
		if event.is_action_pressed(a):
			var b := _first_button(root)
			if b:
				b.grab_focus()
				get_viewport().set_input_as_handled()
			return


## Busca en la pantalla de más arriba (último hijo visible del root) su
## primer botón habilitado, en el orden normal de lectura.
func _first_button(top: Node) -> Button:
	var screens := top.get_children()
	screens.reverse()
	for screen in screens:
		if screen is CanvasItem and not screen.is_visible_in_tree():
			continue
		var b := _first_in(screen)
		if b:
			return b
	return null


func _first_in(node: Node) -> Button:
	if node is Button and node.is_visible_in_tree() and not node.disabled and node.focus_mode != Control.FOCUS_NONE:
		return node
	for c in node.get_children():
		if c is CanvasItem and not c.is_visible_in_tree():
			continue
		var b := _first_in(c)
		if b:
			return b
	return null
