class_name ActionCommand
extends Resource

## Value object - uma intencao de acao (jogador ou IA), referenciando
## combatentes por ID, nunca por referencia direta de objeto.

@export var actor_id: int = -1
@export var kind: String = ""       # "attack" | "item" | "capture" | "flee"
@export var target_id: int = -1     # -1 quando kind == "flee" (sem alvo)
@export var attack_index: int = -1  # indice em AlchemonSheet.attacks; -1 quando kind != "attack"

func _init(
	p_actor_id: int = -1,
	p_kind: String = "",
	p_target_id: int = -1,
	p_attack_index: int = -1
) -> void:
	actor_id = p_actor_id
	kind = p_kind
	target_id = p_target_id
	attack_index = p_attack_index
