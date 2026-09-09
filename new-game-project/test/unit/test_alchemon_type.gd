extends GdUnitTestSuite

## GDD secao 6 - ciclo de vantagem de tipo: Metal > Metaloide > Ametal > Metal.
## Cobertura completa das 9 combinacoes (3 neutras + 3 super efetivas + 3
## resistidas) - com um ciclo fechado de 3, isso e a tabela inteira.

func test_same_type_is_neutral() -> void:
	assert_float(AlchemonType.effectiveness(AlchemonType.Type.METAL, AlchemonType.Type.METAL)).is_equal_approx(1.0, 0.001)
	assert_float(AlchemonType.effectiveness(AlchemonType.Type.AMETAL, AlchemonType.Type.AMETAL)).is_equal_approx(1.0, 0.001)
	assert_float(AlchemonType.effectiveness(AlchemonType.Type.METALOIDE, AlchemonType.Type.METALOIDE)).is_equal_approx(1.0, 0.001)


func test_metal_is_super_effective_against_metaloide() -> void:
	assert_float(AlchemonType.effectiveness(AlchemonType.Type.METAL, AlchemonType.Type.METALOIDE)).is_equal_approx(1.5, 0.001)


func test_metaloide_is_super_effective_against_ametal() -> void:
	assert_float(AlchemonType.effectiveness(AlchemonType.Type.METALOIDE, AlchemonType.Type.AMETAL)).is_equal_approx(1.5, 0.001)


func test_ametal_is_super_effective_against_metal() -> void:
	assert_float(AlchemonType.effectiveness(AlchemonType.Type.AMETAL, AlchemonType.Type.METAL)).is_equal_approx(1.5, 0.001)


func test_metaloide_resists_metal() -> void:
	assert_float(AlchemonType.effectiveness(AlchemonType.Type.METALOIDE, AlchemonType.Type.METAL)).is_equal_approx(0.66, 0.001)


func test_ametal_resists_metaloide() -> void:
	assert_float(AlchemonType.effectiveness(AlchemonType.Type.AMETAL, AlchemonType.Type.METALOIDE)).is_equal_approx(0.66, 0.001)


func test_metal_resists_ametal() -> void:
	assert_float(AlchemonType.effectiveness(AlchemonType.Type.METAL, AlchemonType.Type.AMETAL)).is_equal_approx(0.66, 0.001)
