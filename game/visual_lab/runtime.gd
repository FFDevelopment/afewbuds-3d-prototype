extends "res://visual_lab/study.gd"
# Normal game adapter: preserve the live clock, input bindings and HUD.
func setup(host:Node3D)->void:
 super.setup(host)
 label.get_parent().get_parent().hide()
 set_process(false)
 set_process_input(false)
 set_process_unhandled_input(false)
