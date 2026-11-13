defmodule ArbolZonas do
  @moduledoc """
  Funciones puras y RECURSIVAS sobre la jerarquía zona → sector → punto de atención.

  El árbol completo es una lista de zonas (`NodoZona` con tipo `:zona`); cada zona
  tiene sus sectores en `hijos` y cada sector sus puntos en `hijos`. Muchas funciones
  vienen en pareja: una para un nodo y otra para una lista de nodos, que se llaman
  entre sí (recursión indirecta, como `determinar_par?` / `determinar_impar?` en clase).
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  # Peso de cada nivel de afectación para saber cuál es "más crítico".
  @valor_nivel %{"critico" => 4, "alto" => 3, "medio" => 2, "bajo" => 1}

  @doc """
  Inserta `hijo` dentro del nodo cuyo código es `codigo_padre`, en cualquier nivel.
  Retorna el NUEVO nodo (el original no cambia).
  """
  # RECURSIVA: insertar_hijo
  # Caso base: este nodo es el padre → se agrega el hijo al final de sus hijos.
  # (el patrón repite `codigo`, así solo coincide si el código del nodo es igual al buscado)
  def insertar_hijo(%NodoZona{codigo: codigo} = nodo, codigo, hijo) do
    %{nodo | hijos: nodo.hijos ++ [hijo]}
  end

  # Caso recursivo: el padre no es este nodo → se busca en sus hijos.
  def insertar_hijo(nodo, codigo_padre, hijo) do
    %{nodo | hijos: insertar_en_lista(nodo.hijos, codigo_padre, hijo)}
  end

  @doc """
  Aplica `insertar_hijo/3` a cada nodo de una lista.
  """
  # RECURSIVA (indirecta con insertar_hijo): caso base lista vacía.
  def insertar_en_lista([], _codigo_padre, _hijo), do: []

  def insertar_en_lista([nodo | resto], codigo_padre, hijo) do
    [insertar_hijo(nodo, codigo_padre, hijo) | insertar_en_lista(resto, codigo_padre, hijo)]
  end

  @doc """
  Busca un nodo por código en cualquier nivel del subárbol.

  ## Retorna
    - `{:ok, nodo}` o `{:error, :zona_no_encontrada}`
  """
  # RECURSIVA: buscar
  # Caso base: el nodo actual es el buscado.
  def buscar(%NodoZona{codigo: codigo} = nodo, codigo), do: {:ok, nodo}
  # Caso recursivo: buscar en los hijos.
  def buscar(%NodoZona{hijos: hijos}, codigo), do: buscar_en_lista(hijos, codigo)

  @doc """
  Busca un nodo por código en una lista de nodos (y en sus descendientes).
  """
  # RECURSIVA (indirecta con buscar): caso base lista vacía → no está.
  def buscar_en_lista([], _codigo), do: {:error, :zona_no_encontrada}

  def buscar_en_lista([nodo | resto], codigo) do
    nodo
    |> buscar(codigo)
    |> continuar_busqueda(resto, codigo)
  end

  defp continuar_busqueda({:ok, encontrado}, _resto, _codigo), do: {:ok, encontrado}
  defp continuar_busqueda({:error, _motivo}, resto, codigo), do: buscar_en_lista(resto, codigo)

  @doc """
  Retorna true si el código existe en algún nivel de la lista de nodos.
  """
  def existe?(nodos, codigo), do: buscar_en_lista(nodos, codigo) != {:error, :zona_no_encontrada}

  @doc """
  Estadísticas ACUMULADAS de un nodo y todo lo que tiene debajo (zona y sus sectores y puntos).

  ## Retorna
      %{personas_afectadas: total, sectores: n, puntos: n, nivel_mas_critico: "critico"}

  ## Ejemplo
  Zona (100 personas, medio) con sector S1 (40, alto) que tiene un punto (5, critico):
  → %{personas_afectadas: 145, sectores: 1, puntos: 1, nivel_mas_critico: "critico"}
  """
  # RECURSIVA: estadisticas
  # Caso base: un nodo sin hijos → solo sus propios datos.
  # Caso recursivo: sus datos + las estadísticas de cada hijo.
  def estadisticas(nodo) do
    nodo.hijos
    |> sumar_estadisticas_hijos(estadisticas_propias(nodo))
  end

  # RECURSIVA (indirecta con estadisticas): recorre los hijos acumulando.
  defp sumar_estadisticas_hijos([], acumulado), do: acumulado

  defp sumar_estadisticas_hijos([hijo | resto], acumulado) do
    combinadas = combinar(acumulado, estadisticas(hijo))
    sumar_estadisticas_hijos(resto, combinadas)
  end

  defp estadisticas_propias(nodo) do
    %{
      personas_afectadas: nodo.personas_afectadas,
      sectores: contar_si(nodo.tipo == :sector),
      puntos: contar_si(nodo.tipo == :punto),
      nivel_mas_critico: nodo.nivel
    }
  end

  defp contar_si(true), do: 1
  defp contar_si(false), do: 0

  defp combinar(a, b) do
    %{
      personas_afectadas: a.personas_afectadas + b.personas_afectadas,
      sectores: a.sectores + b.sectores,
      puntos: a.puntos + b.puntos,
      nivel_mas_critico: nivel_mas_critico(a.nivel_mas_critico, b.nivel_mas_critico)
    }
  end

  @doc """
  Retorna el nivel más grave entre dos niveles de afectación.
  """
  def nivel_mas_critico(nivel1, nivel2) do
    elegir_nivel(Map.get(@valor_nivel, nivel1, 0) >= Map.get(@valor_nivel, nivel2, 0), nivel1, nivel2)
  end

  defp elegir_nivel(true, nivel1, _nivel2), do: nivel1
  defp elegir_nivel(false, _nivel1, nivel2), do: nivel2

  @doc """
  Reconstruye el árbol a partir de las líneas del archivo. Cada entrada es una
  tupla `{nodo_sin_hijos, codigo_padre}` (codigo_padre "" para las zonas).
  Las entradas vienen en el orden en que se guardaron (cada padre antes que sus hijos).
  """
  # RECURSIVA: construir
  def construir(entradas), do: construir(entradas, [])

  # Caso base: no hay más entradas → el árbol está listo.
  defp construir([], arbol), do: arbol
  # Caso recursivo: una zona se agrega al final; un sector o punto se inserta bajo su padre.
  defp construir([{nodo, ""} | resto], arbol), do: construir(resto, arbol ++ [nodo])

  defp construir([{nodo, codigo_padre} | resto], arbol) do
    construir(resto, insertar_en_lista(arbol, codigo_padre, nodo))
  end

  @doc """
  Convierte el árbol en una lista plana de `{nodo_sin_hijos, codigo_padre}` para guardarlo
  (recorrido en preorden: primero el padre y luego sus hijos).
  """
  # RECURSIVA: aplanar
  def aplanar(nodos), do: aplanar(nodos, "")

  defp aplanar([], _codigo_padre), do: []

  defp aplanar([nodo | resto], codigo_padre) do
    [{%{nodo | hijos: []}, codigo_padre}] ++ aplanar(nodo.hijos, nodo.codigo) ++ aplanar(resto, codigo_padre)
  end

  @doc """
  Lista con el código del nodo y los códigos de todos sus descendientes.
  Sirve para saber qué necesidades, albergues o personas pertenecen a una zona.
  """
  # RECURSIVA: codigos (caso base: lista de hijos vacía)
  def codigos(nodo), do: [nodo.codigo] ++ codigos_de_lista(nodo.hijos)

  defp codigos_de_lista([]), do: []
  defp codigos_de_lista([nodo | resto]), do: codigos(nodo) ++ codigos_de_lista(resto)
end
