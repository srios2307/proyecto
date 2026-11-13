# Pruebas del conflicto concurrente (sección 6.2): muchas tareas al mismo tiempo.
# Ejecutar: elixir -pa ebin pruebas/concurrencia_prueba.exs
ExUnit.start()

defmodule ConcurrenciaPrueba do
  use ExUnit.Case

  setup do
    directorio = Path.join(System.tmp_dir!(), "emergencias_prueba_#{System.system_time(:microsecond)}_#{System.unique_integer([:positive])}")
    start_supervised!({SupervisorPrincipal, directorio: directorio})
    {:ok, _} = Centros.registrar("CA1", "Centro 1", "centro_acopio", "centro")
    :ok = Inventario.registrar_ubicacion("CA1", "centro")
    :ok
  end

  # Lanza todas las funciones al mismo tiempo y espera los resultados.
  defp en_paralelo(funciones) do
    funciones
    |> Enum.map(&Task.async/1)
    |> Enum.map(&Task.await/1)
  end

  defp contar_ok(resultados), do: Enum.count(resultados, fn resultado -> elem(resultado, 0) == :ok end)

  test "dos necesidades (30 y 25) sobre 50 litros: solo una se confirma, nunca 55" do
    {:ok, _} = Inventario.registrar_recurso("R001", "Agua", "agua", 50, "litros", "CA1")
    {:ok, _} = Necesidades.registrar("agua", 30, "critica", "centro", "Punto 3", "laura")
    {:ok, _} = Necesidades.registrar("agua", 25, "alta", "centro", "Albergue", "pedro")

    resultados =
      en_paralelo([
        fn -> Necesidades.asignar_recurso("N001", "agua", 30, "laura") end,
        fn -> Necesidades.asignar_recurso("N002", "agua", 25, "pedro") end
      ])

    assert contar_ok(resultados) == 1
    assert Enum.any?(resultados, fn r -> match?({:error, {:inventario_insuficiente, disponible: _}}, r) end)

    {:ok, r001} = Inventario.obtener("R001")
    {:ok, n1} = Necesidades.obtener("N001")
    {:ok, n2} = Necesidades.obtener("N002")
    asignado = n1.cantidad_asignada + n2.cantidad_asignada

    assert asignado <= 50
    assert asignado + r001.cantidad == 50
    assert r001.cantidad >= 0
  end

  test "20 tareas piden 10 de un recurso con 100: exactamente 10 confirmaciones e inventario en 0" do
    {:ok, _} = Inventario.registrar_recurso("R100", "Raciones", "alimentos", 100, "raciones", "CA1")

    resultados =
      1..20
      |> Enum.map(fn numero -> fn -> Inventario.asignar("R100", 10, "centro", "T#{numero}") end end)
      |> en_paralelo()

    assert contar_ok(resultados) == 10
    assert {:ok, %Recurso{cantidad: 0}} = Inventario.obtener("R100")
    # 1 movimiento del registro + 10 asignaciones confirmadas.
    assert length(Inventario.historial("R100")) == 11
  end

  test "cantidades distintas al mismo tiempo nunca dejan el inventario negativo" do
    {:ok, _} = Inventario.registrar_recurso("R200", "Medicinas", "medicamentos", 97, "cajas", "CA1")

    resultados =
      [5, 12, 30, 7, 25, 18, 40, 3, 9, 22, 11, 6]
      |> Enum.map(fn cantidad -> fn -> {Inventario.registrar_salida("R200", cantidad), cantidad} end end)
      |> en_paralelo()

    confirmado =
      resultados
      |> Enum.filter(fn {resultado, _cantidad} -> elem(resultado, 0) == :ok end)
      |> Enum.map(fn {_resultado, cantidad} -> cantidad end)
      |> Enum.sum()

    {:ok, r200} = Inventario.obtener("R200")
    assert r200.cantidad >= 0
    assert confirmado + r200.cantidad == 97
  end

  test "5 ingresos simultáneos a un albergue con 2 cupos dejan exactamente 2 adentro" do
    {:ok, _} = Albergues.registrar("A01", "Albergue", "centro", 2)
    documentos = ["1", "2", "3", "4", "5"]
    Enum.each(documentos, fn doc -> {:ok, _} = Personas.registrar(doc, "Persona #{doc}", 20, "centro", "localizada", "ana") end)

    resultados =
      documentos
      |> Enum.map(fn doc -> fn -> Albergues.registrar_ingreso("A01", doc) end end)
      |> en_paralelo()

    assert contar_ok(resultados) == 2
    assert Enum.count(resultados, &(&1 == {:error, :albergue_lleno})) == 3
    {:ok, albergue} = Albergues.consultar("A01")
    assert Albergue.ocupacion(albergue) == 2
    assert length(Personas.buscar(%{"estado" => "en_albergue"})) == 2
  end

  test "dos confirmaciones simultáneas de la misma coincidencia: una sola se acepta" do
    {:ok, _} = Mascotas.reportar("perdida", "perro", "Luna", "negra", "mediana", "norte", "300")
    {:ok, _} = Mascotas.reportar("encontrada", "perro", "desconocido", "negra", "mediana", "norte", "301")

    resultados =
      en_paralelo([
        fn -> Mascotas.confirmar_coincidencia("MA001", "MA002", "laura") end,
        fn -> Mascotas.confirmar_coincidencia("MA001", "MA002", "pedro") end
      ])

    assert contar_ok(resultados) == 1
    assert Enum.member?(resultados, {:error, :ya_resuelta})
  end

  test "registros simultáneos nunca repiten ids" do
    ids =
      1..30
      |> Enum.map(fn numero -> fn -> Necesidades.registrar("agua", numero, "media", "centro", "n#{numero}", "ana") end end)
      |> en_paralelo()
      |> Enum.map(fn {:ok, necesidad} -> necesidad.id end)

    assert ids |> MapSet.new() |> MapSet.size() == 30
  end

  test "el mismo usuario conectándose dos veces a la vez: solo una sesión" do
    resultados =
      en_paralelo([
        fn -> Usuarios.conectar("laura", "1234", "coordinador", "centro") end,
        fn -> Usuarios.conectar("laura", "1234", "coordinador", "centro") end
      ])

    assert contar_ok(resultados) == 1
    assert Enum.member?(resultados, {:error, :ya_conectado})
    assert SupervisorSesiones.cantidad() == 1
  end
end
