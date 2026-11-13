defmodule Inventario do
  @moduledoc """
  GenServer del inventario de recursos: registro, entradas, salidas, transferencias
  entre centros, asignación a necesidades e historial de movimientos.

  CÓMO SE RESUELVE EL CONFLICTO CONCURRENTE (diagrama `3b_secuencia_conflicto.png`):
  un GenServer atiende UN mensaje a la vez. Si dos usuarios piden el mismo recurso al
  mismo tiempo, sus mensajes quedan en fila en el buzón. Cada `handle_call` hace TODO
  junto: verificar que alcance, restar, registrar el movimiento y guardar. Ninguna otra
  solicitud se puede meter en medio, así que lo asignado nunca supera el inventario
  y la cantidad nunca queda negativa.

  Este módulo NO llama a `Necesidades` (así no hay ciclos ni bloqueos mutuos).

  Estado: `%{directorio, recursos: %{codigo => %Recurso{}}, movimientos: [%Movimiento{}],
  siguiente_movimiento: n, ubicaciones: %{codigo_centro => zona}}`
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  use GenServer

  # Por debajo de esta cantidad un recurso se considera crítico.
  @umbral_critico 10

  # ---------------------------------------------------------------
  # API del cliente
  # ---------------------------------------------------------------

  def start_link(directorio), do: GenServer.start_link(__MODULE__, directorio, name: __MODULE__)

  @doc """
  Registra un recurso nuevo en un centro. La categoría debe ser un tipo de necesidad
  (agua, alimentos, ...) para poder asignarlo por categoría.
  Retorna `{:ok, recurso}` o `{:error, motivo}`.
  """
  def registrar_recurso(codigo, nombre, categoria, cantidad, unidad, ubicacion, usuario \\ "sistema") do
    GenServer.call(__MODULE__, {:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion, usuario})
  end

  @doc "Entrada de inventario (donación, compra...). Retorna `{:ok, recurso}`."
  def registrar_entrada(codigo, cantidad, usuario \\ "sistema") do
    GenServer.call(__MODULE__, {:entrada, codigo, cantidad, usuario})
  end

  @doc "Salida de inventario. Retorna `{:ok, recurso}` o `{:error, {:inventario_insuficiente, disponible: n}}`."
  def registrar_salida(codigo, cantidad, usuario \\ "sistema") do
    GenServer.call(__MODULE__, {:salida, codigo, cantidad, usuario})
  end

  @doc """
  Transfiere `cantidad` del recurso desde `origen` hacia el centro `destino`.
  Retorna `{:ok, recurso_origen, recurso_destino}` o `{:error, motivo}`.
  """
  def transferir(codigo, origen, destino, cantidad, usuario \\ "sistema") do
    GenServer.call(__MODULE__, {:transferir, codigo, origen, destino, cantidad, usuario})
  end

  @doc """
  Asigna `cantidad` a una necesidad (todo o nada, de un solo recurso).
  `categoria_o_codigo` puede ser el código de un recurso ("R001") o una categoría ("agua");
  con una categoría se busca primero en la zona de la necesidad y luego en cualquier zona.

  ## Retorna
    - `{:ok, codigo_recurso, cantidad_restante}`
    - `{:error, {:inventario_insuficiente, disponible: n}}`
  """
  def asignar(categoria_o_codigo, cantidad, zona, referencia, usuario \\ "sistema") do
    GenServer.call(__MODULE__, {:asignar, categoria_o_codigo, cantidad, zona, referencia, usuario})
  end

  @doc "Recursos que cumplen los filtros (`categoria`, `zona`, `ubicacion`), ordenados por código."
  def listar(filtros \\ %{}), do: GenServer.call(__MODULE__, {:listar, filtros})

  @doc "`{:ok, recurso}` o `{:error, {:recurso_no_encontrado, codigo}}`."
  def obtener(codigo), do: GenServer.call(__MODULE__, {:obtener, codigo})

  @doc "Movimientos de un recurso (como origen o como destino de una transferencia)."
  def historial(codigo), do: GenServer.call(__MODULE__, {:historial, codigo})

  @doc "Avisa al inventario en qué zona queda un centro (se llama al registrar centros y albergues)."
  def registrar_ubicacion(codigo_centro, zona), do: GenServer.call(__MODULE__, {:registrar_ubicacion, codigo_centro, zona})

  @doc "Mapa `categoria => cantidad total` (para `summary`)."
  def totales_por_categoria(), do: GenServer.call(__MODULE__, :totales_por_categoria)

  @doc """
  Recursos críticos: cantidad menor que el umbral (10) o menor que lo que falta por
  atender en su zona. `faltantes` es un mapa `{categoria, zona} => cantidad` (ver
  `Necesidades.faltantes_pendientes/0`). Retorna lista de `{recurso, faltante}`.
  """
  def recursos_criticos(faltantes \\ %{}), do: GenServer.call(__MODULE__, {:criticos, faltantes})

  @doc "Umbral de recurso crítico."
  def umbral_critico(), do: @umbral_critico

  # ---------------------------------------------------------------
  # Servidor
  # ---------------------------------------------------------------

  @doc false
  def init(directorio) do
    recursos =
      directorio
      |> Persistencia.cargar_recursos()
      |> Enum.map(fn recurso -> {recurso.codigo, recurso} end)
      |> Enum.into(%{})

    movimientos = Persistencia.cargar_movimientos(directorio)

    # Inventario no llama a Centros: lee el archivo de centros solo para saber en qué zona está cada uno.
    ubicaciones =
      directorio
      |> Persistencia.cargar_centros()
      |> Enum.map(fn centro -> {centro.codigo, centro.zona} end)
      |> Enum.into(%{})

    {:ok,
     %{
       directorio: directorio,
       recursos: recursos,
       movimientos: movimientos,
       siguiente_movimiento: movimientos |> Enum.map(& &1.id) |> Validaciones.siguiente_numero("MV"),
       ubicaciones: ubicaciones
     }}
  end

  @doc false
  def handle_call({:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion, usuario}, _de, estado) do
    categoria = Validaciones.normalizar(categoria)

    [
      Validaciones.validar_texto(codigo, :codigo),
      Validaciones.validar_texto(nombre, :nombre),
      Validaciones.validar_opcion(categoria, Validaciones.tipos_necesidad(), :categoria),
      Validaciones.validar_no_negativo(cantidad, :cantidad),
      Validaciones.validar_texto(unidad, :unidad),
      Validaciones.validar_texto(ubicacion, :ubicacion),
      Validaciones.validar_no_repetido(estado.recursos, codigo),
      validar_ubicacion(estado.ubicaciones, ubicacion)
    ]
    |> Validaciones.primer_error()
    |> registrar_si_valido(Recurso.crear(codigo, nombre, categoria, cantidad, unidad, ubicacion), usuario, estado)
  end

  def handle_call({:entrada, codigo, cantidad, usuario}, _de, estado) do
    estado.recursos
    |> Map.get(codigo)
    |> validar_entrada(codigo, cantidad)
    |> aplicar_entrada(cantidad, usuario, estado)
  end

  def handle_call({:salida, codigo, cantidad, usuario}, _de, estado) do
    estado.recursos
    |> Map.get(codigo)
    |> validar_retiro(codigo, cantidad)
    |> aplicar_salida(cantidad, usuario, estado)
  end

  def handle_call({:transferir, codigo, origen, destino, cantidad, usuario}, _de, estado) do
    estado.recursos
    |> Map.get(codigo)
    |> validar_transferencia(codigo, origen, destino, cantidad, estado.ubicaciones)
    |> aplicar_transferencia(destino, cantidad, usuario, estado)
  end

  # Todo el conflicto concurrente se resuelve aquí: verificar + restar + guardar en un solo mensaje.
  def handle_call({:asignar, categoria_o_codigo, cantidad, zona, referencia, usuario}, _de, estado) do
    cantidad
    |> Validaciones.validar_positivo(:cantidad)
    |> elegir_para_asignar(categoria_o_codigo, cantidad, zona, estado)
    |> aplicar_asignacion(cantidad, zona, referencia, usuario, estado)
  end

  def handle_call({:listar, filtros}, _de, estado) do
    lista =
      estado.recursos
      |> Map.values()
      |> Enum.filter(fn recurso -> cumple_filtros?(recurso, filtros, estado.ubicaciones) end)
      |> Enum.sort_by(& &1.codigo)

    {:reply, lista, estado}
  end

  def handle_call({:obtener, codigo}, _de, estado) do
    {:reply, estado.recursos |> Map.get(codigo) |> resultado_busqueda(codigo), estado}
  end

  def handle_call({:historial, codigo}, _de, estado) do
    lista = Enum.filter(estado.movimientos, fn m -> m.codigo_recurso == codigo or m.referencia == codigo end)
    {:reply, lista, estado}
  end

  def handle_call({:registrar_ubicacion, codigo_centro, zona}, _de, estado) do
    {:reply, :ok, %{estado | ubicaciones: Map.put(estado.ubicaciones, codigo_centro, zona)}}
  end

  def handle_call(:totales_por_categoria, _de, estado) do
    {:reply, estado.recursos |> Map.values() |> sumar_por_categoria(%{}), estado}
  end

  def handle_call({:criticos, faltantes}, _de, estado) do
    criticos =
      estado.recursos
      |> Map.values()
      |> Enum.sort_by(& &1.codigo)
      |> Enum.map(fn recurso -> {recurso, faltante_de(recurso, faltantes, estado.ubicaciones)} end)
      |> Enum.filter(fn {recurso, faltante} -> recurso.cantidad < @umbral_critico or recurso.cantidad < faltante end)

    {:reply, criticos, estado}
  end

  # ---------------------------------------------------------------
  # Elección del recurso (función pura y recursiva)
  # ---------------------------------------------------------------

  @doc """
  Busca el PRIMER recurso de la categoría con existencia suficiente.
  `recursos` es una lista de tuplas `{zona_del_recurso, %Recurso{}}`.
  Con `zona = :cualquiera` sirve cualquier zona.

  ## Retorna
    - `{:ok, recurso}` o `:ninguno`
  """
  # RECURSIVA: elegir_recurso
  # Caso base: no quedan recursos → ninguno alcanza.
  def elegir_recurso([], _categoria, _cantidad, _zona), do: :ninguno

  # Caso base: el primero es de la categoría (el patrón repite `categoria`), alcanza y está en la zona.
  def elegir_recurso(
        [{zona_recurso, %Recurso{categoria: categoria, cantidad: disponible, ubicacion: ubicacion} = recurso} | _resto],
        categoria,
        cantidad,
        zona
      )
      when disponible >= cantidad and (zona == :cualquiera or zona == zona_recurso or zona == ubicacion) do
    {:ok, recurso}
  end

  # Caso recursivo: el primero no sirve → se busca en el resto.
  def elegir_recurso([_otro | resto], categoria, cantidad, zona), do: elegir_recurso(resto, categoria, cantidad, zona)

  # ---------------------------------------------------------------
  # Funciones privadas
  # ---------------------------------------------------------------

  defp validar_ubicacion(ubicaciones, ubicacion) do
    ubicaciones
    |> Map.has_key?(ubicacion)
    |> ubicacion_registrada(ubicacion)
  end

  defp ubicacion_registrada(true, _ubicacion), do: :ok
  defp ubicacion_registrada(false, ubicacion), do: {:error, {:ubicacion_no_registrada, ubicacion}}

  defp registrar_si_valido(:ok, recurso, usuario, estado) do
    movimiento = nuevo_movimiento(estado, "entrada", recurso.codigo, recurso.cantidad, "registro", recurso.ubicacion, usuario, "registro")
    {:reply, {:ok, recurso}, confirmar(estado, [recurso], movimiento)}
  end

  defp registrar_si_valido(error, _recurso, _usuario, estado), do: {:reply, error, estado}

  defp validar_entrada(nil, codigo, _cantidad), do: {:error, {:recurso_no_encontrado, codigo}}

  defp validar_entrada(recurso, _codigo, cantidad) do
    cantidad
    |> Validaciones.validar_positivo(:cantidad)
    |> con_recurso(recurso)
  end

  defp aplicar_entrada({:ok, recurso}, cantidad, usuario, estado) do
    actualizado = Recurso.sumar(recurso, cantidad)
    movimiento = nuevo_movimiento(estado, "entrada", recurso.codigo, cantidad, "externo", recurso.ubicacion, usuario, "entrada")
    {:reply, {:ok, actualizado}, confirmar(estado, [actualizado], movimiento)}
  end

  defp aplicar_entrada(error, _cantidad, _usuario, estado), do: {:reply, error, estado}

  defp validar_retiro(nil, codigo, _cantidad), do: {:error, {:recurso_no_encontrado, codigo}}

  defp validar_retiro(recurso, _codigo, cantidad) do
    [Validaciones.validar_positivo(cantidad, :cantidad), verificar_existencia(recurso, cantidad)]
    |> Validaciones.primer_error()
    |> con_recurso(recurso)
  end

  defp aplicar_salida({:ok, recurso}, cantidad, usuario, estado) do
    actualizado = Recurso.restar(recurso, cantidad)
    movimiento = nuevo_movimiento(estado, "salida", recurso.codigo, cantidad, recurso.ubicacion, "externo", usuario, "salida")
    {:reply, {:ok, actualizado}, confirmar(estado, [actualizado], movimiento)}
  end

  defp aplicar_salida(error, _cantidad, _usuario, estado), do: {:reply, error, estado}

  defp validar_transferencia(nil, codigo, _origen, _destino, _cantidad, _ubicaciones),
    do: {:error, {:recurso_no_encontrado, codigo}}

  defp validar_transferencia(recurso, _codigo, origen, destino, cantidad, ubicaciones) do
    [
      Validaciones.validar_positivo(cantidad, :cantidad),
      origen_correcto(recurso, origen),
      destino_valido(origen, destino, ubicaciones),
      verificar_existencia(recurso, cantidad)
    ]
    |> Validaciones.primer_error()
    |> con_recurso(recurso)
  end

  defp origen_correcto(%Recurso{ubicacion: origen}, origen), do: :ok
  defp origen_correcto(recurso, _origen), do: {:error, {:origen_incorrecto, recurso.ubicacion}}

  defp destino_valido(origen, origen, _ubicaciones), do: {:error, :mismo_origen_y_destino}
  defp destino_valido(_origen, destino, ubicaciones), do: validar_ubicacion(ubicaciones, destino)

  defp aplicar_transferencia({:ok, recurso}, destino, cantidad, usuario, estado) do
    # Si en el destino ya hay un recurso igual (mismo nombre, categoría y unidad) se suma ahí;
    # si no, se crea uno nuevo con código "R001-destino".
    destino_actual =
      estado.recursos
      |> Map.values()
      |> Enum.sort_by(& &1.codigo)
      |> buscar_equivalente(recurso, destino)
      |> o_recurso_nuevo(recurso, destino)

    origen_nuevo = Recurso.restar(recurso, cantidad)
    destino_nuevo = Recurso.sumar(destino_actual, cantidad)

    movimiento =
      nuevo_movimiento(estado, "transferencia", recurso.codigo, cantidad, recurso.ubicacion, destino, usuario, destino_nuevo.codigo)

    {:reply, {:ok, origen_nuevo, destino_nuevo}, confirmar(estado, [origen_nuevo, destino_nuevo], movimiento)}
  end

  defp aplicar_transferencia(error, _destino, _cantidad, _usuario, estado), do: {:reply, error, estado}

  # RECURSIVA: busca en la lista un recurso equivalente que ya esté en el destino.
  # Caso base: lista vacía → no hay. Caso recursivo: revisa el primero y sigue con el resto.
  defp buscar_equivalente([], _recurso, _destino), do: nil

  defp buscar_equivalente([candidato | resto], recurso, destino) do
    candidato
    |> equivalente?(recurso, destino)
    |> equivalente_o_seguir(candidato, resto, recurso, destino)
  end

  defp equivalente?(candidato, recurso, destino) do
    candidato.ubicacion == destino and candidato.nombre == recurso.nombre and
      candidato.categoria == recurso.categoria and candidato.unidad == recurso.unidad
  end

  defp equivalente_o_seguir(true, candidato, _resto, _recurso, _destino), do: candidato
  defp equivalente_o_seguir(false, _candidato, resto, recurso, destino), do: buscar_equivalente(resto, recurso, destino)

  defp o_recurso_nuevo(nil, recurso, destino) do
    Recurso.crear(recurso.codigo <> "-" <> destino, recurso.nombre, recurso.categoria, 0, recurso.unidad, destino)
  end

  defp o_recurso_nuevo(existente, _recurso, _destino), do: existente

  defp elegir_para_asignar(:ok, categoria_o_codigo, cantidad, zona, estado) do
    estado.recursos
    |> Map.get(categoria_o_codigo)
    |> elegir_por_codigo_o_categoria(categoria_o_codigo, cantidad, zona, estado)
  end

  defp elegir_para_asignar(error, _categoria_o_codigo, _cantidad, _zona, _estado), do: error

  # Es el código de un recurso: se usa ese recurso, si alcanza.
  defp elegir_por_codigo_o_categoria(%Recurso{} = recurso, _codigo, cantidad, _zona, _estado) do
    recurso
    |> verificar_existencia(cantidad)
    |> con_recurso(recurso)
  end

  # Es una categoría: primero en la zona de la necesidad, luego en cualquier zona.
  defp elegir_por_codigo_o_categoria(nil, categoria, cantidad, zona, estado) do
    categoria = Validaciones.normalizar(categoria)
    candidatos = recursos_con_zona(estado)

    candidatos
    |> elegir_recurso(categoria, cantidad, zona)
    |> o_en_cualquier_zona(candidatos, categoria, cantidad)
    |> o_insuficiente(candidatos, categoria)
  end

  defp o_en_cualquier_zona({:ok, recurso}, _candidatos, _categoria, _cantidad), do: {:ok, recurso}

  defp o_en_cualquier_zona(:ninguno, candidatos, categoria, cantidad),
    do: elegir_recurso(candidatos, categoria, cantidad, :cualquiera)

  defp o_insuficiente({:ok, recurso}, _candidatos, _categoria), do: {:ok, recurso}

  defp o_insuficiente(:ninguno, candidatos, categoria) do
    {:error, {:inventario_insuficiente, disponible: maximo_disponible(candidatos, categoria)}}
  end

  defp aplicar_asignacion({:ok, recurso}, cantidad, zona, referencia, usuario, estado) do
    actualizado = Recurso.restar(recurso, cantidad)
    movimiento = nuevo_movimiento(estado, "asignacion", recurso.codigo, cantidad, recurso.ubicacion, zona, usuario, referencia)
    {:reply, {:ok, recurso.codigo, actualizado.cantidad}, confirmar(estado, [actualizado], movimiento)}
  end

  defp aplicar_asignacion(error, _cantidad, _zona, _referencia, _usuario, estado), do: {:reply, error, estado}

  defp verificar_existencia(recurso, cantidad) do
    recurso
    |> Recurso.alcanza?(cantidad)
    |> resultado_existencia(recurso)
  end

  defp resultado_existencia(true, _recurso), do: :ok
  defp resultado_existencia(false, recurso), do: {:error, {:inventario_insuficiente, disponible: recurso.cantidad}}

  defp con_recurso(:ok, recurso), do: {:ok, recurso}
  defp con_recurso(error, _recurso), do: error

  # Cada recurso con la zona de su centro: [{zona, recurso}, ...] ordenados por código.
  defp recursos_con_zona(estado) do
    estado.recursos
    |> Map.values()
    |> Enum.sort_by(& &1.codigo)
    |> Enum.map(fn recurso -> {Map.get(estado.ubicaciones, recurso.ubicacion, ""), recurso} end)
  end

  defp maximo_disponible(candidatos, categoria) do
    cantidades =
      candidatos
      |> Enum.filter(fn {_zona, recurso} -> recurso.categoria == categoria end)
      |> Enum.map(fn {_zona, recurso} -> recurso.cantidad end)

    Enum.max([0] ++ cantidades)
  end

  defp nuevo_movimiento(estado, tipo, codigo, cantidad, origen, destino, usuario, referencia) do
    id = Validaciones.generar_id("MV", estado.siguiente_movimiento, 4)
    Movimiento.crear(id, Validaciones.fecha_actual(), tipo, codigo, cantidad, origen, destino, usuario, referencia)
  end

  # Confirma un cambio: actualiza el estado, guarda recursos.csv y AGREGA el movimiento.
  # Se crea un estado NUEVO (%{estado | ...}): nada se modifica en su lugar.
  defp confirmar(estado, recursos_cambiados, movimiento) do
    nuevo_estado = %{
      estado
      | recursos: actualizar_recursos(estado.recursos, recursos_cambiados),
        movimientos: estado.movimientos ++ [movimiento],
        siguiente_movimiento: estado.siguiente_movimiento + 1
    }

    nuevo_estado.recursos
    |> Map.values()
    |> Enum.sort_by(& &1.codigo)
    |> Persistencia.guardar_recursos(estado.directorio)

    Persistencia.agregar_movimiento(movimiento, estado.directorio)
    nuevo_estado
  end

  # RECURSIVA: pone cada recurso cambiado en el mapa (caso base: lista vacía).
  defp actualizar_recursos(mapa, []), do: mapa
  defp actualizar_recursos(mapa, [recurso | resto]), do: actualizar_recursos(Map.put(mapa, recurso.codigo, recurso), resto)

  # RECURSIVA: suma la cantidad de cada recurso en su categoría (caso base: lista vacía).
  defp sumar_por_categoria([], totales), do: totales

  defp sumar_por_categoria([recurso | resto], totales) do
    total = Map.get(totales, recurso.categoria, 0) + recurso.cantidad
    sumar_por_categoria(resto, Map.put(totales, recurso.categoria, total))
  end

  defp cumple_filtros?(recurso, filtros, ubicaciones) do
    Validaciones.cumple_filtros?(filtros, fn clave, valor -> cumple_filtro?(clave, valor, recurso, ubicaciones) end)
  end

  defp cumple_filtro?("categoria", valor, recurso, _ubicaciones), do: recurso.categoria == Validaciones.normalizar(valor)
  defp cumple_filtro?("tipo", valor, recurso, _ubicaciones), do: recurso.categoria == Validaciones.normalizar(valor)
  defp cumple_filtro?("ubicacion", valor, recurso, _ubicaciones), do: recurso.ubicacion == valor

  defp cumple_filtro?("zona", valor, recurso, ubicaciones) do
    recurso.ubicacion == valor or Map.get(ubicaciones, recurso.ubicacion) == valor
  end

  defp cumple_filtro?(_clave, _valor, _recurso, _ubicaciones), do: false

  defp faltante_de(recurso, faltantes, ubicaciones) do
    zona = Map.get(ubicaciones, recurso.ubicacion, "")
    Map.get(faltantes, {recurso.categoria, zona}, 0) + Map.get(faltantes, {recurso.categoria, recurso.ubicacion}, 0)
  end

  defp resultado_busqueda(nil, codigo), do: {:error, {:recurso_no_encontrado, codigo}}
  defp resultado_busqueda(recurso, _codigo), do: {:ok, recurso}
end
