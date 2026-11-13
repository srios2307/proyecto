defmodule Necesidades do
  @moduledoc """
  GenServer de las necesidades puntuales: registro, consultas ordenadas por prioridad,
  cambios de estado y asignación de recursos (diagrama `3b_secuencia_conflicto.png`).

  Para asignar, este GenServer valida la necesidad y le pide el recurso a `Inventario`.
  Como también atiende UN mensaje a la vez, una necesidad no puede recibir dos
  asignaciones mezcladas, y una necesidad cerrada nunca vuelve a consumir recursos.

  Estado: `%{directorio, necesidades: %{id => %Necesidad{}}, siguiente: n}`
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  use GenServer

  # ---------------------------------------------------------------
  # API del cliente
  # ---------------------------------------------------------------

  def start_link(directorio), do: GenServer.start_link(__MODULE__, directorio, name: __MODULE__)

  @doc "Registra una necesidad (id automático N001, N002...). Retorna `{:ok, necesidad}`."
  def registrar(tipo, cantidad, prioridad, zona, descripcion, responsable) do
    GenServer.call(__MODULE__, {:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable})
  end

  @doc "Necesidades que cumplen los filtros (zona, tipo, prioridad, estado), ordenadas por prioridad."
  def listar(filtros \\ %{}), do: GenServer.call(__MODULE__, {:listar, filtros})

  @doc "Necesidades en estado pendiente, ordenadas por prioridad."
  def pendientes(), do: listar(%{"estado" => "pendiente"})

  @doc """
  La necesidad pendiente que se debe atender primero (opcionalmente de una zona).
  Retorna `{:ok, necesidad}` o `{:error, :sin_pendientes}`.
  """
  def siguiente(zona \\ nil), do: GenServer.call(__MODULE__, {:siguiente, zona})

  @doc "`{:ok, necesidad}` o `{:error, {:necesidad_no_encontrada, id}}`."
  def obtener(id), do: GenServer.call(__MODULE__, {:obtener, id})

  @doc "Cambia el estado siguiendo las transiciones válidas. Retorna `{:ok, necesidad}`."
  def actualizar_estado(id, estado_nuevo, usuario \\ "sistema") do
    GenServer.call(__MODULE__, {:actualizar_estado, id, estado_nuevo, usuario})
  end

  @doc """
  Asigna recursos a una necesidad (todo o nada).

  ## Retorna
    - `{:ok, necesidad_actualizada}`
    - `{:error, {:inventario_insuficiente, disponible: n}}`, `{:error, :ya_cerrada}`, ...
  """
  def asignar_recurso(id, categoria_o_codigo, cantidad, usuario) do
    GenServer.call(__MODULE__, {:asignar_recurso, id, categoria_o_codigo, cantidad, usuario})
  end

  @doc """
  Mapa `{tipo, zona} => cantidad que falta` de las necesidades pendientes
  (lo usa `critical_resources`).
  """
  def faltantes_pendientes(), do: GenServer.call(__MODULE__, :faltantes_pendientes)

  # ---------------------------------------------------------------
  # Servidor
  # ---------------------------------------------------------------

  @doc false
  def init(directorio) do
    lista = Persistencia.cargar_necesidades(directorio)
    necesidades = lista |> Enum.map(fn n -> {n.id, n} end) |> Enum.into(%{})
    siguiente = lista |> Enum.map(& &1.id) |> Validaciones.siguiente_numero("N")
    {:ok, %{directorio: directorio, necesidades: necesidades, siguiente: siguiente}}
  end

  @doc false
  def handle_call({:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable}, _de, estado) do
    tipo = Validaciones.normalizar(tipo)
    prioridad = Validaciones.normalizar(prioridad)

    [
      Validaciones.validar_opcion(tipo, Validaciones.tipos_necesidad(), :tipo),
      Validaciones.validar_positivo(cantidad, :cantidad),
      Validaciones.validar_opcion(prioridad, Prioridades.prioridades(), :prioridad),
      Validaciones.validar_texto(zona, :zona),
      Validaciones.validar_texto(descripcion, :descripcion),
      Validaciones.validar_texto(responsable, :responsable)
    ]
    |> Validaciones.primer_error()
    |> registrar_si_valida({tipo, cantidad, prioridad, zona, descripcion, responsable}, estado)
  end

  def handle_call({:listar, filtros}, _de, estado) do
    lista =
      estado.necesidades
      |> Map.values()
      |> Enum.filter(fn necesidad -> cumple_filtros?(necesidad, filtros) end)
      |> Prioridades.ordenar()

    {:reply, lista, estado}
  end

  def handle_call({:siguiente, zona}, _de, estado) do
    respuesta =
      estado.necesidades
      |> Map.values()
      |> Enum.filter(fn necesidad -> necesidad.estado == "pendiente" and de_la_zona?(necesidad, zona) end)
      |> Prioridades.seleccionar_mayor()

    {:reply, respuesta, estado}
  end

  def handle_call({:obtener, id}, _de, estado) do
    {:reply, estado.necesidades |> Map.get(id) |> resultado_busqueda(id), estado}
  end

  def handle_call({:actualizar_estado, id, estado_nuevo, _usuario}, _de, estado) do
    estado_nuevo = Validaciones.normalizar(estado_nuevo)

    estado.necesidades
    |> Map.get(id)
    |> validar_cambio(id, estado_nuevo)
    |> aplicar_cambio(estado_nuevo, estado)
  end

  def handle_call({:asignar_recurso, id, categoria_o_codigo, cantidad, usuario}, _de, estado) do
    necesidad = Map.get(estado.necesidades, id)

    necesidad
    |> validar_asignacion(id, cantidad)
    |> pedir_a_inventario(necesidad, categoria_o_codigo, cantidad, usuario)
    |> aplicar_asignacion(necesidad, cantidad, estado)
  end

  def handle_call(:faltantes_pendientes, _de, estado) do
    faltantes =
      estado.necesidades
      |> Map.values()
      |> Enum.filter(fn necesidad -> necesidad.estado == "pendiente" end)
      |> acumular_faltantes(%{})

    {:reply, faltantes, estado}
  end

  # ---------------------------------------------------------------
  # Funciones privadas
  # ---------------------------------------------------------------

  defp registrar_si_valida(:ok, {tipo, cantidad, prioridad, zona, descripcion, responsable}, estado) do
    id = Validaciones.generar_id("N", estado.siguiente)
    necesidad = Necesidad.crear(id, tipo, descripcion, cantidad, zona, prioridad, responsable, Validaciones.fecha_actual())

    nuevo_estado = %{
      estado
      | necesidades: Map.put(estado.necesidades, id, necesidad),
        siguiente: estado.siguiente + 1
    }

    guardar(nuevo_estado)
    {:reply, {:ok, necesidad}, nuevo_estado}
  end

  defp registrar_si_valida(error, _datos, estado), do: {:reply, error, estado}

  defp validar_cambio(nil, id, _estado_nuevo), do: {:error, {:necesidad_no_encontrada, id}}

  # "asignada" solo se alcanza con assign_resource cuando se cubre toda la cantidad.
  defp validar_cambio(%Necesidad{estado: "pendiente"}, _id, "asignada"), do: {:error, :asignada_solo_con_recursos}

  defp validar_cambio(necesidad, _id, estado_nuevo) do
    :necesidad
    |> Transiciones.validar(necesidad.estado, estado_nuevo)
    |> con_necesidad(necesidad)
  end

  defp aplicar_cambio({:ok, necesidad}, estado_nuevo, estado) do
    actualizada = %{necesidad | estado: estado_nuevo}
    nuevo_estado = %{estado | necesidades: Map.put(estado.necesidades, actualizada.id, actualizada)}
    guardar(nuevo_estado)
    {:reply, {:ok, actualizada}, nuevo_estado}
  end

  defp aplicar_cambio(error, _estado_nuevo, estado), do: {:reply, error, estado}

  # Paso 1 del diagrama 3b: la necesidad existe, está pendiente y lo pedido no supera lo que falta.
  defp validar_asignacion(nil, id, _cantidad), do: {:error, {:necesidad_no_encontrada, id}}

  defp validar_asignacion(%Necesidad{estado: estado}, _id, _cantidad) when estado in ["atendida", "cancelada"],
    do: {:error, :ya_cerrada}

  defp validar_asignacion(%Necesidad{estado: "pendiente"} = necesidad, _id, cantidad) do
    [Validaciones.validar_positivo(cantidad, :cantidad), no_supera_faltante(necesidad, cantidad)]
    |> Validaciones.primer_error()
  end

  defp validar_asignacion(%Necesidad{estado: estado}, _id, _cantidad), do: {:error, {:estado_no_permite_asignar, estado}}

  defp no_supera_faltante(necesidad, cantidad) when is_integer(cantidad) do
    falta = Necesidad.faltante(necesidad)
    resultado_faltante(cantidad <= falta, falta)
  end

  defp no_supera_faltante(_necesidad, _cantidad), do: :ok

  defp resultado_faltante(true, _falta), do: :ok
  defp resultado_faltante(false, falta), do: {:error, {:supera_faltante, falta}}

  # Paso 2: se le pide el recurso a Inventario (que lo verifica y lo resta en UN solo mensaje).
  defp pedir_a_inventario(:ok, necesidad, categoria_o_codigo, cantidad, usuario) do
    Inventario.asignar(categoria_o_codigo, cantidad, necesidad.zona, necesidad.id, usuario)
  end

  defp pedir_a_inventario(error, _necesidad, _categoria_o_codigo, _cantidad, _usuario), do: error

  # Paso 3: solo si Inventario confirmó se actualiza la necesidad; si no, NO cambia.
  defp aplicar_asignacion({:ok, codigo_recurso, _restante}, necesidad, cantidad, estado) do
    actualizada = Necesidad.agregar_asignacion(necesidad, codigo_recurso, cantidad)
    nuevo_estado = %{estado | necesidades: Map.put(estado.necesidades, actualizada.id, actualizada)}
    guardar(nuevo_estado)
    {:reply, {:ok, actualizada}, nuevo_estado}
  end

  defp aplicar_asignacion(error, _necesidad, _cantidad, estado), do: {:reply, error, estado}

  defp con_necesidad(:ok, necesidad), do: {:ok, necesidad}
  defp con_necesidad(error, _necesidad), do: error

  defp de_la_zona?(_necesidad, nil), do: true
  defp de_la_zona?(necesidad, zona), do: necesidad.zona == zona

  defp cumple_filtros?(necesidad, filtros) do
    Validaciones.cumple_filtros?(filtros, fn clave, valor -> cumple_filtro?(clave, valor, necesidad) end)
  end

  defp cumple_filtro?("zona", valor, necesidad), do: necesidad.zona == valor
  defp cumple_filtro?("tipo", valor, necesidad), do: necesidad.tipo == Validaciones.normalizar(valor)
  defp cumple_filtro?("prioridad", valor, necesidad), do: necesidad.prioridad == Validaciones.normalizar(valor)
  defp cumple_filtro?("estado", valor, necesidad), do: necesidad.estado == Validaciones.normalizar(valor)
  defp cumple_filtro?("responsable", valor, necesidad), do: necesidad.responsable == valor
  defp cumple_filtro?(_clave, _valor, _necesidad), do: false

  # RECURSIVA: suma lo que falta de cada necesidad por {tipo, zona} (caso base: lista vacía).
  defp acumular_faltantes([], faltantes), do: faltantes

  defp acumular_faltantes([necesidad | resto], faltantes) do
    clave = {necesidad.tipo, necesidad.zona}
    total = Map.get(faltantes, clave, 0) + Necesidad.faltante(necesidad)
    acumular_faltantes(resto, Map.put(faltantes, clave, total))
  end

  defp resultado_busqueda(nil, id), do: {:error, {:necesidad_no_encontrada, id}}
  defp resultado_busqueda(necesidad, _id), do: {:ok, necesidad}

  defp guardar(estado) do
    estado.necesidades
    |> Map.values()
    |> Enum.sort_by(& &1.id)
    |> Persistencia.guardar_necesidades(estado.directorio)
  end
end
