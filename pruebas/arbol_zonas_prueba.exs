# Pruebas del árbol de zonas (funciones puras y recursivas).
# Ejecutar: elixir -pa ebin pruebas/arbol_zonas_prueba.exs
ExUnit.start()

defmodule ArbolZonasPrueba do
  use ExUnit.Case

  # Zona "centro" con 2 sectores y 3 puntos:
  #   centro (100, medio)
  #   ├── S1 (40, alto)
  #   │   ├── P1 (5, bajo)
  #   │   └── P2 (5, critico)
  #   └── S2 (20, bajo)
  #       └── P3 (0, bajo)
  defp arbol_ejemplo() do
    [NodoZona.crear("centro", "Centro", :zona, "medio", 100)]
    |> ArbolZonas.insertar_en_lista("centro", NodoZona.crear("S1", "Sector 1", :sector, "alto", 40))
    |> ArbolZonas.insertar_en_lista("centro", NodoZona.crear("S2", "Sector 2", :sector, "bajo", 20))
    |> ArbolZonas.insertar_en_lista("S1", NodoZona.crear("P1", "Punto 1", :punto, "bajo", 5))
    |> ArbolZonas.insertar_en_lista("S1", NodoZona.crear("P2", "Punto 2", :punto, "critico", 5))
    |> ArbolZonas.insertar_en_lista("S2", NodoZona.crear("P3", "Punto 3", :punto, "bajo", 0))
  end

  test "insertar coloca cada hijo bajo su padre" do
    [centro] = arbol_ejemplo()
    assert length(centro.hijos) == 2
    [s1, s2] = centro.hijos
    assert Enum.map(s1.hijos, & &1.codigo) == ["P1", "P2"]
    assert Enum.map(s2.hijos, & &1.codigo) == ["P3"]
  end

  test "buscar encuentra nodos en cualquier nivel" do
    arbol = arbol_ejemplo()
    assert {:ok, %NodoZona{nombre: "Punto 3"}} = ArbolZonas.buscar_en_lista(arbol, "P3")
    assert {:ok, %NodoZona{tipo: :sector}} = ArbolZonas.buscar_en_lista(arbol, "S1")
    assert ArbolZonas.buscar_en_lista(arbol, "X9") == {:error, :zona_no_encontrada}
  end

  test "estadísticas acumuladas de una zona con 2 sectores y 3 puntos" do
    [centro] = arbol_ejemplo()

    assert ArbolZonas.estadisticas(centro) == %{
             personas_afectadas: 170,
             sectores: 2,
             puntos: 3,
             nivel_mas_critico: "critico"
           }

    {:ok, s2} = ArbolZonas.buscar(centro, "S2")
    assert ArbolZonas.estadisticas(s2) == %{personas_afectadas: 20, sectores: 1, puntos: 1, nivel_mas_critico: "bajo"}
  end

  test "aplanar y construir son inversos" do
    arbol = arbol_ejemplo()
    plano = ArbolZonas.aplanar(arbol)
    assert Enum.map(plano, fn {nodo, padre} -> {nodo.codigo, padre} end) ==
             [{"centro", ""}, {"S1", "centro"}, {"P1", "S1"}, {"P2", "S1"}, {"S2", "centro"}, {"P3", "S2"}]

    assert ArbolZonas.construir(plano) == arbol
  end

  test "códigos del subárbol" do
    [centro] = arbol_ejemplo()
    assert ArbolZonas.codigos(centro) == ["centro", "S1", "P1", "P2", "S2", "P3"]
  end
end
