defmodule Zonas do
  @moduledoc """
  GenServer con el árbol de zonas → sectores → puntos de atención.
  El recorrido del árbol lo hacen las funciones recursivas de `ArbolZonas`.

  Estado: `%{directorio, zonas: [%NodoZona{tipo: :zona}, ...]}`
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  use GenServer

  # ---------------------------------------------------------------
  # API del cliente
  # ---------------------------------------------------------------

  def start_link(directorio), do: GenServer.start_link(__MODULE__, directorio, name: __MODULE__)

  @doc "Registra una zona. Retorna `{:ok, nodo}` o `{:error, motivo}`."
  def registrar_zona(codigo, nombre, nivel, personas) do
    GenServer.call(__MODULE__, {:registrar, "", :zona, codigo, nombre, nivel, personas})
  end

  @doc "Registra un sector dentro de una zona."
  def registrar_sector(codigo_zona, codigo, nombre, nivel, personas) do
    GenServer.call(__MODULE__, {:registrar, codigo_zona, :sector, codigo, nombre, nivel, personas})
  end

  @doc "Registra un punto de atención dentro de un sector."
  def registrar_punto(codigo_sector, codigo, nombre, nivel \\ "bajo", personas \\ 0) do
    GenServer.call(__MODULE__, {:registrar, codigo_sector, :punto, codigo, nombre, nivel, personas})
  end

  @doc "Árbol completo (lista de zonas con sus hijos)."
  def listar(), do: GenServer.call(__MODULE__, :listar)

  @doc "Busca un nodo en cualquier nivel: `{:ok, nodo}` o `{:error, :zona_no_encontrada}`."
  def buscar(codigo), do: GenServer.call(__MODULE__, {:buscar, codigo})

  @doc "Retorna true si el código existe (zona, sector o punto)."
  def existe?(codigo), do: GenServer.call(__MODULE__, {:existe, codigo})

  @doc "Estadísticas acumuladas: `{:ok, estadisticas}` o `{:error, :zona_no_encontrada}`."
  def estadisticas(codigo), do: GenServer.call(__MODULE__, {:estadisticas, codigo})

  @doc """
  Nodo, estadísticas y códigos de todo su subárbol (para `zone_status`).
  Retorna `{:ok, %{nodo, estadisticas, codigos}}` o `{:error, :zona_no_encontrada}`.
  """
  def consultar(codigo), do: GenServer.call(__MODULE__, {:consultar, codigo})

  # ---------------------------------------------------------------
  # Servidor
  # ---------------------------------------------------------------

  @doc false
  def init(directorio) do
    zonas =
      directorio
      |> Persistencia.cargar_zonas()
      |> ArbolZonas.construir()

    {:ok, %{directorio: directorio, zonas: zonas}}
  end

  @doc false
  def handle_call({:registrar, padre, tipo, codigo, nombre, nivel, personas}, _de, estado) do
    nivel = Validaciones.normalizar(nivel)

    [
      Validaciones.validar_texto(codigo, :codigo),
      Validaciones.validar_texto(nombre, :nombre),
      Validaciones.validar_opcion(nivel, Validaciones.niveles_afectacion(), :nivel),
      Validaciones.validar_no_negativo(personas, :personas_afectadas),
      validar_codigo_libre(estado.zonas, codigo),
      validar_padre(estado.zonas, padre, tipo)
    ]
    |> Validaciones.primer_error()
    |> registrar_nodo(padre, NodoZona.crear(codigo, nombre, tipo, nivel, personas), estado)
  end

  def handle_call(:listar, _de, estado), do: {:reply, estado.zonas, estado}

  def handle_call({:buscar, codigo}, _de, estado) do
    {:reply, ArbolZonas.buscar_en_lista(estado.zonas, codigo), estado}
  end

  def handle_call({:existe, codigo}, _de, estado), do: {:reply, ArbolZonas.existe?(estado.zonas, codigo), estado}

  def handle_call({:estadisticas, codigo}, _de, estado) do
    respuesta =
      estado.zonas
      |> ArbolZonas.buscar_en_lista(codigo)
      |> calcular_estadisticas()

    {:reply, respuesta, estado}
  end

  def handle_call({:consultar, codigo}, _de, estado) do
    respuesta =
      estado.zonas
      |> ArbolZonas.buscar_en_lista(codigo)
      |> armar_consulta()

    {:reply, respuesta, estado}
  end

  defp calcular_estadisticas({:ok, nodo}), do: {:ok, ArbolZonas.estadisticas(nodo)}
  defp calcular_estadisticas(error), do: error

  defp armar_consulta({:ok, nodo}) do
    {:ok, %{nodo: nodo, estadisticas: ArbolZonas.estadisticas(nodo), codigos: ArbolZonas.codigos(nodo)}}
  end

  defp armar_consulta(error), do: error

  defp validar_codigo_libre(zonas, codigo) do
    zonas
    |> ArbolZonas.existe?(codigo)
    |> codigo_libre(codigo)
  end

  defp codigo_libre(true, codigo), do: {:error, {:id_repetido, codigo}}
  defp codigo_libre(false, _codigo), do: :ok

  # Una zona no tiene padre; un sector va dentro de una zona; un punto dentro de un sector.
  defp validar_padre(_zonas, "", :zona), do: :ok

  defp validar_padre(zonas, padre, tipo) do
    zonas
    |> ArbolZonas.buscar_en_lista(padre)
    |> padre_compatible(padre, tipo)
  end

  defp padre_compatible({:ok, %NodoZona{tipo: :zona}}, _padre, :sector), do: :ok
  defp padre_compatible({:ok, %NodoZona{tipo: :sector}}, _padre, :punto), do: :ok
  defp padre_compatible({:ok, %NodoZona{tipo: tipo_padre}}, _padre, tipo), do: {:error, {:padre_invalido, tipo_padre, tipo}}
  defp padre_compatible({:error, _motivo}, padre, _tipo), do: {:error, {:zona_no_encontrada, padre}}

  defp registrar_nodo(:ok, padre, nodo, estado) do
    nuevo_estado = %{estado | zonas: insertar(estado.zonas, padre, nodo)}
    guardar(nuevo_estado)
    {:reply, {:ok, nodo}, nuevo_estado}
  end

  defp registrar_nodo(error, _padre, _nodo, estado), do: {:reply, error, estado}

  defp insertar(zonas, "", nodo), do: zonas ++ [nodo]
  defp insertar(zonas, padre, nodo), do: ArbolZonas.insertar_en_lista(zonas, padre, nodo)

  defp guardar(estado) do
    estado.zonas
    |> ArbolZonas.aplanar()
    |> Persistencia.guardar_zonas(estado.directorio)
  end
end
