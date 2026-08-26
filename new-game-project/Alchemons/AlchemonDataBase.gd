class_name AlchemonDataBase extends Resource
@export var alchemons : Array[alchemon_sheet]
func get_sheet(id: int) -> alchemon_sheet:
	for item in alchemons:
		if item.id == id:
			return item
	return null
