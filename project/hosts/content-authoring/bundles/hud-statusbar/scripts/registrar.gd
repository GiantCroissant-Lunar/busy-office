extends Node

const SLOT_PATH := "HudRoot/VBox/StatusBarSlot"
const CONTENT_SCENE := "res://bundles/hud-statusbar/scenes/statusbar.tscn"


func _ready() -> void:
	_register.call_deferred()


func _register() -> void:
	var slot := _find_slot()
	if slot:
		_do_register(slot)
	else:
		get_tree().root.child_entered_tree.connect(_on_root_child)


func _on_root_child(node: Node) -> void:
	var slot := _find_slot()
	if slot:
		get_tree().root.child_entered_tree.disconnect(_on_root_child)
		_do_register.call_deferred(slot)


func _do_register(slot: Node) -> void:
	var scene := load(CONTENT_SCENE) as PackedScene
	if scene:
		slot.add_child(scene.instantiate())


func _find_slot() -> Node:
	for child in get_tree().root.get_children():
		var slot := child.get_node_or_null(SLOT_PATH)
		if slot:
			return slot
	return null
