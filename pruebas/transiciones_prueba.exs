# Pruebas de Transiciones (funciones puras).
# Ejecutar: elixir -pa ebin pruebas/transiciones_prueba.exs
#
# ExUnit (NO visto en clase) es la herramienta de pruebas de Elixir:
#   - `test "nombre" do ... end` define una prueba
#   - `assert expresion` falla si la expresión es falsa
#   - `refute expresion` falla si la expresión es verdadera
ExUnit.start()

defmodule TransicionesPrueba do
  use ExUnit.Case

  test "necesidad: transiciones válidas del diagrama" do
    assert Transiciones.validar(:necesidad, "pendiente", "asignada") == :ok
    assert Transiciones.validar(:necesidad, "pendiente", "cancelada") == :ok
    assert Transiciones.validar(:necesidad, "asignada", "en_atencion") == :ok
    assert Transiciones.validar(:necesidad, "asignada", "cancelada") == :ok
    assert Transiciones.validar(:necesidad, "en_atencion", "atendida") == :ok
  end

  test "necesidad: transición inválida y cierre doble" do
    assert Transiciones.validar(:necesidad, "pendiente", "atendida") ==
             {:error, {:transicion_invalida, "pendiente", "atendida"}}

    assert Transiciones.validar(:necesidad, "atendida", "cancelada") == {:error, :ya_cerrada}
    assert Transiciones.validar(:necesidad, "cancelada", "cancelada") == {:error, :ya_cerrada}
    assert Transiciones.validar(:necesidad, "pendiente", "volando") == {:error, {:estado_invalido, "volando"}}
  end

  test "persona: transiciones válidas e inválidas" do
    assert Transiciones.transicion_valida?(:persona, "sin_informacion", "localizada")
    assert Transiciones.transicion_valida?(:persona, "localizada", "en_albergue")
    assert Transiciones.transicion_valida?(:persona, "en_albergue", "reunificada")
    refute Transiciones.transicion_valida?(:persona, "sin_informacion", "en_albergue")
    assert Transiciones.validar(:persona, "reunificada", "localizada") == {:error, :ya_reunificada}
  end

  test "mascota: no se resuelve dos veces" do
    assert Transiciones.validar(:mascota, "activa", "posible_coincidencia") == :ok
    assert Transiciones.validar(:mascota, "posible_coincidencia", "activa") == :ok
    assert Transiciones.validar(:mascota, "activa", "resuelta") == :ok
    assert Transiciones.validar(:mascota, "resuelta", "resuelta") == {:error, :ya_resuelta}
  end

  test "mensaje: pendiente <-> entregado" do
    assert Transiciones.validar(:mensaje, "pendiente", "entregado") == :ok
    assert Transiciones.validar(:mensaje, "entregado", "pendiente") == :ok

    assert Transiciones.validar(:mensaje, "entregado", "entregado") ==
             {:error, {:transicion_invalida, "entregado", "entregado"}}
  end
end
