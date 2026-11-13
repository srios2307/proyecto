defmodule Centros do
  @moduledoc """
  GenServer con los centros de apoyo (centros de acopio, albergues y puntos de atención).
  Son las ubicaciones donde están los recursos.

  Estado: `%{directorio, centros: %{codigo => %Centro{}}}`
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  use GenServer

  # ---------------------------------------------------------------
  # API del cliente
  # ---------------------------------------------------------------

  def start_link(directorio), do: GenServer.start_link(__MODULE__, directorio, name: __MODULE__)

  @doc "Registra un centro. Retorna `{:ok, centro}` o `{:error, motivo}`."
  def registrar(codigo, nombre, tipo, zona), do: GenServer.call(__MODULE__, {:registrar, codigo, nombre, tipo, zona})

  @doc "Lista de centros ordenada por código."
  def listar(), do: GenServer.call(__MODULE__, :listar)

  @doc "`{:ok, centro}` o `{:error, {:centro_no_encontrado, codigo}}`."
  def obtener(codigo), do: GenServer.call(__MODULE__, {:obtener, codigo})

  @doc "Retorna true si el centro existe."
  def existe?(codigo), do: GenServer.call(__MODULE__, {:existe, codigo})

  # ---------------------------------------------------------------
  # Servidor
  # ---------------------------------------------------------------

  @doc false
  def init(directorio) do
    centros =
      directorio
      |> Persistencia.cargar_centros()
      |> Enum.map(fn centro -> {centro.codigo, centro} end)
      |> Enum.into(%{})

    {:ok, %{directorio: directorio, centros: centros}}
  end

  @doc false
  def handle_call({:registrar, codigo, nombre, tipo, zona}, _de, estado) do
    tipo = Validaciones.normalizar(tipo)

    [
      Validaciones.validar_texto(codigo, :codigo),
      Validaciones.validar_texto(nombre, :nombre),
      Validaciones.validar_opcion(tipo, Validaciones.tipos_centro(), :tipo),
      Validaciones.validar_texto(zona, :zona),
      Validaciones.validar_no_repetido(estado.centros, codigo)
    ]
    |> Validaciones.primer_error()
    |> registrar_centro(Centro.crear(codigo, nombre, tipo, zona), estado)
  end

  def handle_call(:listar, _de, estado) do
    {:reply, estado.centros |> Map.values() |> Enum.sort_by(& &1.codigo), estado}
  end

  def handle_call({:obtener, codigo}, _de, estado) do
    {:reply, estado.centros |> Map.get(codigo) |> resultado_busqueda(codigo), estado}
  end

  def handle_call({:existe, codigo}, _de, estado), do: {:reply, Map.has_key?(estado.centros, codigo), estado}

  defp registrar_centro(:ok, centro, estado) do
    nuevo_estado = %{estado | centros: Map.put(estado.centros, centro.codigo, centro)}

    nuevo_estado.centros
    |> Map.values()
    |> Persistencia.guardar_centros(estado.directorio)

    {:reply, {:ok, centro}, nuevo_estado}
  end

  defp registrar_centro(error, _centro, estado), do: {:reply, error, estado}

  defp resultado_busqueda(nil, codigo), do: {:error, {:centro_no_encontrado, codigo}}
  defp resultado_busqueda(centro, _codigo), do: {:ok, centro}
end
