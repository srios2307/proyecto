# Pruebas de Validaciones (funciones puras).
# Ejecutar: elixir -pa ebin pruebas/validaciones_prueba.exs
ExUnit.start()

defmodule ValidacionesPrueba do
  use ExUnit.Case

  test "cantidades negativas" do
    assert Validaciones.validar_no_negativo(0, :cantidad) == :ok
    assert Validaciones.validar_no_negativo(-1, :cantidad) == {:error, {:cantidad_negativa, :cantidad}}
    assert Validaciones.validar_positivo(0, :cantidad) == {:error, {:cantidad_invalida, :cantidad}}
    assert Validaciones.validar_positivo(5, :cantidad) == :ok
  end

  test "ids repetidos" do
    assert Validaciones.validar_no_repetido(%{"R001" => :x}, "R001") == {:error, {:id_repetido, "R001"}}
    assert Validaciones.validar_no_repetido(%{"R001" => :x}, "R002") == :ok
  end

  test "caracteres no permitidos en el texto" do
    assert Validaciones.validar_texto("hola; mundo", :descripcion) ==
             {:error, {:caracter_no_permitido, :descripcion}}

    assert Validaciones.validar_texto("a|b", :nombre) == {:error, {:caracter_no_permitido, :nombre}}
    assert Validaciones.validar_texto("dos\nlineas", :nombre) == {:error, {:caracter_no_permitido, :nombre}}
    assert Validaciones.validar_texto("   ", :nombre) == {:error, {:campo_vacio, :nombre}}
    assert Validaciones.validar_texto("Albergue Norte", :nombre) == :ok
  end

  test "conversión de números sin lanzar errores" do
    assert Validaciones.convertir_entero("30") == {:ok, 30}
    assert Validaciones.convertir_entero("treinta") == {:error, {:numero_invalido, "treinta"}}
  end

  test "primer_error reemplaza a with" do
    assert Validaciones.primer_error([:ok, :ok]) == :ok
    assert Validaciones.primer_error([:ok, {:error, :a}, {:error, :b}]) == {:error, :a}
  end

  test "ids con ceros a la izquierda" do
    assert Validaciones.generar_id("N", 1) == "N001"
    assert Validaciones.generar_id("MV", 12, 4) == "MV0012"
    assert Validaciones.generar_id("N", 1234) == "N1234"
    assert Validaciones.siguiente_numero(["N001", "N007", "N003"], "N") == 8
    assert Validaciones.siguiente_numero([], "N") == 1
  end
end
