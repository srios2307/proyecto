defmodule Albergues do
  @moduledoc """
  GenServer de los albergues: registro, ingreso y salida de personas, cupos y
  reporte de ocupación.

  La ocupación NUNCA supera la capacidad: revisar el cupo y agregar a la persona
  ocurren dentro del mismo `handle_call`, así dos ingresos simultáneos no pueden
  tomar el mismo último cupo. Para cambiar el estado de la persona a "en_albergue"
  este GenServer llama a `Personas` (Personas nunca llama a Albergues: no hay ciclos).

  Estado: `%{directorio, albergues: %{codigo => %Albergue{}}}`
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  use GenServer

  # ---------------------------------------------------------------
  # API del cliente
  # ---------------------------------------------------------------

  def start_link(directorio), do: GenServer.start_link(__MODULE__, directorio, name: __MODULE__)

  @doc "Registra un albergue. Retorna `{:ok, albergue}` o `{:error, motivo}`."
  def registrar(codigo, nombre, zona, capacidad), do: GenServer.call(__MODULE__, {:registrar, codigo, nombre, zona, capacidad})

  @doc "`{:ok, albergue}` o `{:error, {:albergue_no_encontrado, codigo}}`."
  def consultar(codigo), do: GenServer.call(__MODULE__, {:consultar, codigo})

  @doc "Lista de albergues."
  def listar(), do: GenServer.call(__MODULE__, :listar)

  @doc """
  Ingresa una persona (documento) al albergue y la deja "en_albergue".
  Retorna `{:ok, albergue}` o `{:error, :albergue_lleno}` u otro motivo.
  """
  def registrar_ingreso(codigo, documento, usuario \\ "sistema") do
    GenServer.call(__MODULE__, {:ingreso, codigo, documento, usuario})
  end

  @doc """
  Saca una persona del albergue y le pone el estado `estado_destino`
  ("trasladada" por defecto, o "reunificada"). Retorna `{:ok, albergue}`.
  """
  def registrar_salida(codigo, documento, usuario \\ "sistema", estado_destino \\ "trasladada") do
    GenServer.call(__MODULE__, {:salida, codigo, documento, usuario, estado_destino})
  end

  @doc "Albergues ordenados del más ocupado (porcentaje) al menos ocupado."
  def reporte_ocupacion(), do: GenServer.call(__MODULE__, :reporte_ocupacion)

  # ---------------------------------------------------------------
  # Servidor
  # ---------------------------------------------------------------

  @doc false
  def init(directorio) do
    albergues =
      directorio
      |> Persistencia.cargar_albergues()
      |> Enum.map(fn albergue -> {albergue.codigo, albergue} end)
      |> Enum.into(%{})

    {:ok, %{directorio: directorio, albergues: albergues}}
  end

  @doc false
  def handle_call({:registrar, codigo, nombre, zona, capacidad}, _de, estado) do
    [
      Validaciones.validar_texto(codigo, :codigo),
      Validaciones.validar_texto(nombre, :nombre),
      Validaciones.validar_texto(zona, :zona),
      Validaciones.validar_positivo(capacidad, :capacidad),
      Validaciones.validar_no_repetido(estado.albergues, codigo)
    ]
    |> Validaciones.primer_error()
    |> registrar_si_valido({codigo, nombre, zona, capacidad}, estado)
  end

  def handle_call({:consultar, codigo}, _de, estado) do
    {:reply, estado.albergues |> Map.get(codigo) |> resultado_busqueda(codigo), estado}
  end

  def handle_call(:listar, _de, estado) do
    {:reply, estado.albergues |> Map.values() |> Enum.sort_by(& &1.codigo), estado}
  end

  def handle_call({:ingreso, codigo, documento, usuario}, _de, estado) do
    albergue = Map.get(estado.albergues, codigo)

    albergue
    |> validar_ingreso(codigo, documento)
    |> cambiar_estado_persona(documento, "en_albergue", usuario)
    |> confirmar(albergue, &Albergue.ingresar(&1, documento), estado)
  end

  def handle_call({:salida, codigo, documento, usuario, estado_destino}, _de, estado) do
    albergue = Map.get(estado.albergues, codigo)

    albergue
    |> validar_salida(codigo, documento)
    |> cambiar_estado_persona(documento, estado_destino, usuario)
    |> confirmar(albergue, &Albergue.retirar(&1, documento), estado)
  end

  def handle_call(:reporte_ocupacion, _de, estado) do
    lista =
      estado.albergues
      |> Map.values()
      |> Enum.sort_by(&Albergue.porcentaje_ocupacion/1, :desc)

    {:reply, lista, estado}
  end

  # ---------------------------------------------------------------
  # Funciones privadas
  # ---------------------------------------------------------------

  defp registrar_si_valido(:ok, {codigo, nombre, zona, capacidad}, estado) do
    albergue = Albergue.crear(codigo, nombre, zona, capacidad)
    nuevo_estado = %{estado | albergues: Map.put(estado.albergues, codigo, albergue)}
    guardar(nuevo_estado)
    {:reply, {:ok, albergue}, nuevo_estado}
  end

  defp registrar_si_valido(error, _datos, estado), do: {:reply, error, estado}

  defp validar_ingreso(nil, codigo, _documento), do: {:error, {:albergue_no_encontrado, codigo}}

  defp validar_ingreso(albergue, _codigo, documento) do
    cond do
      Albergue.presente?(albergue, documento) -> {:error, {:ya_esta_en_albergue, documento}}
      Albergue.lleno?(albergue) -> {:error, :albergue_lleno}
      true -> :ok
    end
  end

  defp validar_salida(nil, codigo, _documento), do: {:error, {:albergue_no_encontrado, codigo}}

  defp validar_salida(albergue, _codigo, documento) do
    albergue
    |> Albergue.presente?(documento)
    |> resultado_presente(documento)
  end

  defp resultado_presente(true, _documento), do: :ok
  defp resultado_presente(false, documento), do: {:error, {:no_esta_en_albergue, documento}}

  # Solo si el albergue aceptó se le pide a Personas cambiar el estado de la persona.
  defp cambiar_estado_persona(:ok, documento, estado_nuevo, usuario) do
    Personas.actualizar_estado(documento, estado_nuevo, usuario)
  end

  defp cambiar_estado_persona(error, _documento, _estado_nuevo, _usuario), do: error

  # Solo si Personas confirmó, se actualiza el albergue (ingresar o retirar) y se guarda.
  defp confirmar({:ok, _persona}, albergue, cambio, estado) do
    actualizado = cambio.(albergue)
    nuevo_estado = %{estado | albergues: Map.put(estado.albergues, actualizado.codigo, actualizado)}
    guardar(nuevo_estado)
    {:reply, {:ok, actualizado}, nuevo_estado}
  end

  defp confirmar(error, _albergue, _cambio, estado), do: {:reply, error, estado}

  defp resultado_busqueda(nil, codigo), do: {:error, {:albergue_no_encontrado, codigo}}
  defp resultado_busqueda(albergue, _codigo), do: {:ok, albergue}

  defp guardar(estado) do
    estado.albergues
    |> Map.values()
    |> Enum.sort_by(& &1.codigo)
    |> Persistencia.guardar_albergues(estado.directorio)
  end
end
