defmodule Personas do
  @moduledoc """
  GenServer de la comunicación entre familiares: personas afectadas, historial de
  cambios de estado y mensajes para una persona o familia.

  Estado: `%{directorio, personas: %{documento => %Persona{}}, mensajes: %{id => %Mensaje{}},
  siguiente_persona: n, siguiente_mensaje: n}`
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  use GenServer

  # ---------------------------------------------------------------
  # API del cliente
  # ---------------------------------------------------------------

  def start_link(directorio), do: GenServer.start_link(__MODULE__, directorio, name: __MODULE__)

  @doc """
  Registra una persona afectada. El estado inicial puede ser "sin_informacion" o uno al
  que se llegue desde él ("reportada" o "localizada").
  Retorna `{:ok, persona}` o `{:error, motivo}`.
  """
  def registrar(documento, nombre, edad, zona, estado_inicial, usuario) do
    GenServer.call(__MODULE__, {:registrar, documento, nombre, edad, zona, estado_inicial, usuario})
  end

  @doc "Cambia el estado de una persona (queda en el historial). Retorna `{:ok, persona}`."
  def actualizar_estado(documento, estado_nuevo, usuario) do
    GenServer.call(__MODULE__, {:actualizar_estado, documento, estado_nuevo, usuario})
  end

  @doc "`{:ok, persona}` o `{:error, {:persona_no_encontrada, documento}}`."
  def obtener(documento), do: GenServer.call(__MODULE__, {:obtener, documento})

  @doc "Busca por `documento`, `nombre` (contiene, sin importar mayúsculas), `zona` o `estado`."
  def buscar(filtros), do: GenServer.call(__MODULE__, {:buscar, filtros})

  @doc "Todas las personas."
  def listar(), do: buscar(%{})

  @doc "`{:ok, historial}` de una persona."
  def historial(documento), do: GenServer.call(__MODULE__, {:historial, documento})

  @doc "Deja un mensaje para una persona (documento) o familia. Retorna `{:ok, mensaje}`."
  def enviar_mensaje(remitente, destinatario, contenido) do
    GenServer.call(__MODULE__, {:enviar_mensaje, remitente, destinatario, contenido})
  end

  @doc "Mensajes dirigidos a un destinatario."
  def mensajes_para(destinatario), do: GenServer.call(__MODULE__, {:mensajes_para, destinatario})

  @doc "Todos los mensajes."
  def listar_mensajes(), do: GenServer.call(__MODULE__, :listar_mensajes)

  @doc "Marca un mensaje como \"entregado\" o \"pendiente\". Retorna `{:ok, mensaje}`."
  def marcar_mensaje(id, estado_nuevo), do: GenServer.call(__MODULE__, {:marcar_mensaje, id, estado_nuevo})

  # ---------------------------------------------------------------
  # Servidor
  # ---------------------------------------------------------------

  @doc false
  def init(directorio) do
    historial = Persistencia.cargar_historial(directorio)

    personas =
      directorio
      |> Persistencia.cargar_personas()
      |> Enum.map(fn persona -> {persona.documento, %{persona | historial: historial_de(historial, persona.documento)}} end)
      |> Enum.into(%{})

    mensajes =
      directorio
      |> Persistencia.cargar_mensajes()
      |> Enum.map(fn mensaje -> {mensaje.id, mensaje} end)
      |> Enum.into(%{})

    {:ok,
     %{
       directorio: directorio,
       personas: personas,
       mensajes: mensajes,
       siguiente_persona: personas |> Map.values() |> Enum.map(& &1.id) |> Validaciones.siguiente_numero("P"),
       siguiente_mensaje: mensajes |> Map.keys() |> Validaciones.siguiente_numero("MS")
     }}
  end

  @doc false
  def handle_call({:registrar, documento, nombre, edad, zona, estado_inicial, usuario}, _de, estado) do
    estado_inicial = Validaciones.normalizar(estado_inicial)

    [
      Validaciones.validar_texto(documento, :documento),
      Validaciones.validar_texto(nombre, :nombre),
      Validaciones.validar_no_negativo(edad, :edad),
      Validaciones.validar_texto(zona, :zona),
      validar_estado_inicial(estado_inicial),
      Validaciones.validar_no_repetido(estado.personas, documento)
    ]
    |> Validaciones.primer_error()
    |> registrar_si_valida({documento, nombre, edad, zona, estado_inicial, usuario}, estado)
  end

  def handle_call({:actualizar_estado, documento, estado_nuevo, usuario}, _de, estado) do
    estado_nuevo = Validaciones.normalizar(estado_nuevo)

    estado.personas
    |> Map.get(documento)
    |> validar_cambio(documento, estado_nuevo)
    |> aplicar_cambio(estado_nuevo, usuario, estado)
  end

  def handle_call({:obtener, documento}, _de, estado) do
    {:reply, estado.personas |> Map.get(documento) |> resultado_busqueda(documento), estado}
  end

  def handle_call({:buscar, filtros}, _de, estado) do
    lista =
      estado.personas
      |> Map.values()
      |> Enum.filter(fn persona -> cumple_filtros?(persona, filtros) end)
      |> Enum.sort_by(& &1.id)

    {:reply, lista, estado}
  end

  def handle_call({:historial, documento}, _de, estado) do
    respuesta =
      estado.personas
      |> Map.get(documento)
      |> resultado_busqueda(documento)
      |> solo_historial()

    {:reply, respuesta, estado}
  end

  def handle_call({:enviar_mensaje, remitente, destinatario, contenido}, _de, estado) do
    [
      Validaciones.validar_texto(remitente, :remitente),
      Validaciones.validar_texto(destinatario, :destinatario),
      Validaciones.validar_texto(contenido, :contenido)
    ]
    |> Validaciones.primer_error()
    |> enviar_si_valido({remitente, destinatario, contenido}, estado)
  end

  def handle_call({:mensajes_para, destinatario}, _de, estado) do
    lista =
      estado.mensajes
      |> Map.values()
      |> Enum.filter(fn mensaje -> mensaje.destinatario == destinatario end)
      |> Enum.sort_by(& &1.id)

    {:reply, lista, estado}
  end

  def handle_call(:listar_mensajes, _de, estado) do
    {:reply, estado.mensajes |> Map.values() |> Enum.sort_by(& &1.id), estado}
  end

  def handle_call({:marcar_mensaje, id, estado_nuevo}, _de, estado) do
    estado_nuevo = Validaciones.normalizar(estado_nuevo)

    estado.mensajes
    |> Map.get(id)
    |> validar_marca(id, estado_nuevo)
    |> aplicar_marca(estado_nuevo, estado)
  end

  # ---------------------------------------------------------------
  # Funciones privadas
  # ---------------------------------------------------------------

  # Historial de una persona a partir de las líneas de historial_personas.csv.
  defp historial_de(historial, documento) do
    historial
    |> Enum.filter(fn {doc, _cambio} -> doc == documento end)
    |> Enum.map(fn {_doc, cambio} -> cambio end)
  end

  defp validar_estado_inicial("sin_informacion"), do: :ok
  defp validar_estado_inicial(estado_inicial), do: Transiciones.validar(:persona, "sin_informacion", estado_inicial)

  defp registrar_si_valida(:ok, {documento, nombre, edad, zona, estado_inicial, usuario}, estado) do
    id = Validaciones.generar_id("P", estado.siguiente_persona)
    persona = Persona.crear(id, documento, nombre, edad, zona, estado_inicial, Validaciones.fecha_actual(), usuario)

    nuevo_estado = %{
      estado
      | personas: Map.put(estado.personas, documento, persona),
        siguiente_persona: estado.siguiente_persona + 1
    }

    guardar_personas(nuevo_estado)
    persona.historial |> List.last() |> agregar_historial(documento, estado)
    {:reply, {:ok, persona}, nuevo_estado}
  end

  defp registrar_si_valida(error, _datos, estado), do: {:reply, error, estado}

  defp validar_cambio(nil, documento, _estado_nuevo), do: {:error, {:persona_no_encontrada, documento}}

  defp validar_cambio(persona, _documento, estado_nuevo) do
    :persona
    |> Transiciones.validar(persona.estado, estado_nuevo)
    |> con_dato(persona)
  end

  defp aplicar_cambio({:ok, persona}, estado_nuevo, usuario, estado) do
    actualizada = Persona.cambiar_estado(persona, estado_nuevo, Validaciones.fecha_actual(), usuario)
    nuevo_estado = %{estado | personas: Map.put(estado.personas, persona.documento, actualizada)}
    guardar_personas(nuevo_estado)
    actualizada.historial |> List.last() |> agregar_historial(persona.documento, estado)
    {:reply, {:ok, actualizada}, nuevo_estado}
  end

  defp aplicar_cambio(error, _estado_nuevo, _usuario, estado), do: {:reply, error, estado}

  defp enviar_si_valido(:ok, {remitente, destinatario, contenido}, estado) do
    id = Validaciones.generar_id("MS", estado.siguiente_mensaje)
    mensaje = Mensaje.crear(id, Validaciones.fecha_actual(), remitente, destinatario, contenido)

    nuevo_estado = %{
      estado
      | mensajes: Map.put(estado.mensajes, id, mensaje),
        siguiente_mensaje: estado.siguiente_mensaje + 1
    }

    guardar_mensajes(nuevo_estado)
    {:reply, {:ok, mensaje}, nuevo_estado}
  end

  defp enviar_si_valido(error, _datos, estado), do: {:reply, error, estado}

  defp validar_marca(nil, id, _estado_nuevo), do: {:error, {:mensaje_no_encontrado, id}}

  defp validar_marca(mensaje, _id, estado_nuevo) do
    :mensaje
    |> Transiciones.validar(mensaje.estado, estado_nuevo)
    |> con_dato(mensaje)
  end

  defp aplicar_marca({:ok, mensaje}, estado_nuevo, estado) do
    actualizado = %{mensaje | estado: estado_nuevo}
    nuevo_estado = %{estado | mensajes: Map.put(estado.mensajes, mensaje.id, actualizado)}
    guardar_mensajes(nuevo_estado)
    {:reply, {:ok, actualizado}, nuevo_estado}
  end

  defp aplicar_marca(error, _estado_nuevo, estado), do: {:reply, error, estado}

  defp con_dato(:ok, dato), do: {:ok, dato}
  defp con_dato(error, _dato), do: error

  defp resultado_busqueda(nil, documento), do: {:error, {:persona_no_encontrada, documento}}
  defp resultado_busqueda(persona, _documento), do: {:ok, persona}

  defp solo_historial({:ok, persona}), do: {:ok, persona.historial}
  defp solo_historial(error), do: error

  defp cumple_filtros?(persona, filtros) do
    Validaciones.cumple_filtros?(filtros, fn clave, valor -> cumple_filtro?(clave, valor, persona) end)
  end

  defp cumple_filtro?("documento", valor, persona), do: persona.documento == valor
  defp cumple_filtro?("zona", valor, persona), do: persona.zona == valor
  defp cumple_filtro?("estado", valor, persona), do: persona.estado == Validaciones.normalizar(valor)

  # String.contains? revisa si un texto está dentro de otro (búsqueda parcial por nombre).
  defp cumple_filtro?("nombre", valor, persona) do
    persona.nombre
    |> String.downcase()
    |> String.contains?(String.downcase(valor))
  end

  defp cumple_filtro?(_clave, _valor, _persona), do: false

  defp guardar_personas(estado) do
    estado.personas
    |> Map.values()
    |> Enum.sort_by(& &1.id)
    |> Persistencia.guardar_personas(estado.directorio)
  end

  defp agregar_historial(cambio, documento, estado), do: Persistencia.agregar_historial({documento, cambio}, estado.directorio)

  defp guardar_mensajes(estado) do
    estado.mensajes
    |> Map.values()
    |> Enum.sort_by(& &1.id)
    |> Persistencia.guardar_mensajes(estado.directorio)
  end
end
