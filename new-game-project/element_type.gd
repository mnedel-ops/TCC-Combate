class_name ElementType
extends RefCounted

## Categoria quimica de um Alchemon (GDD sec 6). So Metal muda o resultado
## do laco por enquanto - Ametal/Metaloide tratados como "nao-metal".

const METAL := "metal"
const AMETAL := "ametal"
const METALOIDE := "metaloide"


static func is_metal(type: String) -> bool:
	return type == METAL
