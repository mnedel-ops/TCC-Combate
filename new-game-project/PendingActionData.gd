class_name PendingActionData
extends Resource

## Dado puro - uma acao escolhida pra rodada (quem faz, o que, em quem).
## Nao executa nada sozinho; CombatSystem consome isso.

@export var actor: AlchemonSheet
@export var kind: String = ""    # "attack" | "item" | "capture"
@export var target: AlchemonSheet

func _init(p_actor: AlchemonSheet = null, p_kind: String = "", p_target: AlchemonSheet = null) -> void:
	actor = p_actor
	kind = p_kind
	target = p_target
