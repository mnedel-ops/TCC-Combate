class_name AlchemonType
extends RefCounted

## Sistema de tipos (GDD secao 6). Ciclo fechado de vantagem entre 3
## categorias - sem STAB (o dano nao ganha bonus por golpe do mesmo tipo
## de quem ataca; so importa o tipo do GOLPE contra o tipo da criatura
## alvo, GDD secao 10.1 explicito sobre isso).
##
## Ciclo: Metal supera Metaloide -> Metaloide supera Ametal -> Ametal supera Metal

enum Type {
	METAL,
	AMETAL,
	METALOIDE,
}

## Mapa "quem esse tipo supera" - unica fonte de verdade do ciclo. Os 3
## pares reversos (quem resiste) sao derivados disso em effectiveness(),
## nunca duplicados numa segunda tabela.
const _BEATS := {
	Type.METAL: Type.METALOIDE,
	Type.METALOIDE: Type.AMETAL,
	Type.AMETAL: Type.METAL,
}

const SUPER_EFFECTIVE := 1.5
const RESISTED := 0.66
const NEUTRAL := 1.0


## Multiplicador de dano de um golpe do tipo attack_type contra uma
## criatura do tipo defender_type. GDD secao 6:
## - mesmo tipo -> neutro (1,0x) - unico caso sem vantagem definida no ciclo
## - attack_type supera defender_type no ciclo -> super efetivo (1,5x)
## - caso contrario (o inverso e verdade) -> resistido (0,66x)
static func effectiveness(attack_type: int, defender_type: int) -> float:
	if attack_type == defender_type:
		return NEUTRAL
	if _BEATS[attack_type] == defender_type:
		return SUPER_EFFECTIVE
	return RESISTED


static func type_name(t: int) -> String:
	match t:
		Type.METAL:
			return "Metal"
		Type.AMETAL:
			return "Ametal"
		Type.METALOIDE:
			return "Metaloide"
		_:
			return "Desconhecido"
