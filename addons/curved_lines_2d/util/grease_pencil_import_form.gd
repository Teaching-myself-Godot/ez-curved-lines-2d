@tool
extends Control

signal choice_confirmed()
signal opened()

var _dragging := false
var _drag_start := Vector2.ZERO


func _on_confirm_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%ImportingNormallyLabel.hide()
		%AnimationNameContainer.show()
		%ResourceDirContainer.show()
	else:
		%ImportingNormallyLabel.show()
		%AnimationNameContainer.hide()
		%ResourceDirContainer.hide()


func _on_ok_button_pressed() -> void:
	choice_confirmed.emit()
	hide()

func show_form() -> void:
	opened.emit()
	show()



func get_animation_name() -> String:
	return %AnimationNameLineEdit.text


func set_animation_name(name : String) -> void:
	%AnimationNameLineEdit.text = name


func get_resource_dir() -> String:
	return %ResourceDirLineEdit.text


func set_resource_dir(path : String) -> void:
	%ResourceDirLineEdit.text = path


func is_confirmed() -> bool:
	return %ConfirmCheckBox.button_pressed


func _on_dir_picker_button_pressed() -> void:
	%DirPickerEditorFileDialog.popup_file_dialog()


func _on_dir_picker_editor_file_dialog_dir_selected(dir: String) -> void:
	%ResourceDirLineEdit.text = dir
