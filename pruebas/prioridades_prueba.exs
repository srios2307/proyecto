# Pruebas del ordenamiento por prioridad (funciones puras y recursivas).
# Ejecutar: elixir -pa ebin pruebas/prioridades_prueba.exs
ExUnit.start()

defmodule PrioridadesPrueba do
  use ExUnit.Case

  defp necesidad(id, prioridad, fecha) do
    Necesidad.crear(id, "agua", "prueba", 10, "centro", prioridad, "laura", fecha)
  end

  test "ordena por prioridad descendente y luego por fecha ascendente" do
    lista = [
      necesidad("N001", "baja", "2026-11-09 08:00:00"),
      necesidad("N002", "critica", "2026-11-09 09:00:00"),
      necesidad("N003", "media", "2026-11-09 07:00:00"),
      necesidad("N004", "critica", "2026-11-09 08:30:00"),
      necesidad("N005", "alta", "2026-11-09 10:00:00")
    ]

    assert lista |> Prioridades.ordenar() |> Enum.map(& &1.id) == ["N004", "N002", "N005", "N003", "N001"]
  end

  test "inserción ordenada en una lista ya ordenada" do
    ordenada = [necesidad("N001", "critica", "2026-11-09 08:00:00"), necesidad("N002", "baja", "2026-11-09 08:00:00")]
    nueva = necesidad("N003", "media", "2026-11-09 09:00:00")
    assert nueva |> Prioridades.insertar_ordenado(ordenada) |> Enum.map(& &1.id) == ["N001", "N003", "N002"]
  end

  test "seleccionar la de mayor prioridad" do
    lista = [necesidad("N001", "media", "2026-11-09 08:00:00"), necesidad("N002", "alta", "2026-11-09 09:00:00")]
    assert {:ok, %Necesidad{id: "N002"}} = Prioridades.seleccionar_mayor(lista)
    assert Prioridades.seleccionar_mayor([]) == {:error, :sin_pendientes}
  end

  test "empate total: decide el id" do
    a = necesidad("N002", "alta", "2026-11-09 08:00:00")
    b = necesidad("N001", "alta", "2026-11-09 08:00:00")
    assert [a, b] |> Prioridades.ordenar() |> Enum.map(& &1.id) == ["N001", "N002"]
  end
end
