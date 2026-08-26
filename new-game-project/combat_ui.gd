class_name CombatUI
extends Control

# UI Elements
@export var hplabel: Label
@onready var log_label: Label = $VBoxContainer/LogLabel
@onready var turn_label: Label = $VBoxContainer/TurnLabel
@onready var action_container: VBoxContainer = $VBoxContainer/ActionButtons
@onready var target_container: HBoxContainer = $VBoxContainer/TargetButtons
@onready var flee_button: Button = $VBoxContainer/FleeButton

func _ready() -> void:
	print(hplabel.text)
