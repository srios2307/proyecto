defmodule Comandos do
  @moduledoc """
  Despacho de comandos: revisa la sesión y los permisos, llama a la API del GenServer
  que corresponde y registra la acción en la bitácora (diagrama `3a_secuencia_connect.png`).

  `ejecutar/2` recibe la tupla de `AnalizadorComandos.analizar/1` y el estado de la
  consola, y retorna `{respuesta, nuevo_estado}`. La respuesta es la tupla que
  retorna el servidor (`{:ok, ...}` o `{:error, motivo}`); el texto lo arma `Consola`.

  Estado de la consola: `%{activa: usuario | nil, sesiones: %{usuario => %Usuario{}}}`.
  Puede haber varias sesiones abiertas a la vez; los comandos se ejecutan en nombre
  de la sesión activa.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  # Comandos que se pueden usar sin tener sesión.
  @comandos_basicos [:connect, :use, :sessions, :help, :exit]

  # Procesos que se pueden detener a la fuerza con `crash_server` (demostración de supervisión).
  @servidores %{
    "zonas" => Zonas,
    "centros" => Centros,
    "inventario" => Inventario,
    "necesidades" => Necesidades,
    "personas" => Personas,
    "mascotas" => Mascotas,
    "albergues" => Albergues,
    "bitacora" => :bitacora
  }

  @doc """
  Estado inicial de la consola: sin sesiones.
  """
  def estado_inicial(), do: %{activa: nil, sesiones: %{}}

  @doc """
  Ejecuta un comando ya analizado.

  ## Parámetros
    - `{comando, argumentos}` de `AnalizadorComandos.analizar/1`
    - estado de la consola

  ## Retorna
    - `{respuesta, nuevo_estado}`
  """
  def ejecutar({:vacio, _argumentos}, estado), do: {{:ok, :nada}, estado}
  def ejecutar({:error, motivo}, estado), do: {{:error, motivo}, estado}
  def ejecutar({:desconocido, [nombre]}, estado), do: {{:error, {:comando_desconocido, nombre}}, estado}
  def ejecutar({:exit, _argumentos}, estado), do: {{:ok, :salir}, estado}
  def ejecutar({:connect, argumentos}, estado), do: conectar(argumentos, estado)
  def ejecutar({:use, argumentos}, estado), do: usar(argumentos, estado)
  def ejecutar({:sessions, _argumentos}, estado), do: {{:ok, {listar_sesiones(), estado.activa}}, estado}
  def ejecutar({:help, _argumentos}, estado), do: {{:ok, ayuda(usuario_activo(estado))}, estado}

  def ejecutar({comando, argumentos}, estado) do
    estado
    |> usuario_activo()
    |> ejecutar_con_sesion(comando, argumentos, estado)
  end

  @doc """
  Desconecta todas las sesiones de la consola (se usa al salir con `exit`).
  """
  def cerrar_sesiones(estado) do
    estado.sesiones
    |> Map.keys()
    |> Enum.each(fn usuario ->
      respuesta = Usuarios.desconectar(usuario)
      registrar_actividad(usuario, :disconnect, respuesta)
    end)
  end

  # ---------------------------------------------------------------
  # Sesiones
  # ---------------------------------------------------------------

  defp usuario_activo(%{activa: nil}), do: nil
  defp usuario_activo(estado), do: Map.get(estado.sesiones, estado.activa)

  defp conectar(argumentos, estado) do
    respuesta = llamar_conectar(argumentos)
    argumentos |> nombre_usuario() |> registrar_actividad(:connect, respuesta)
    {respuesta, estado_tras_conectar(respuesta, estado)}
  end

  defp llamar_conectar([usuario, contrasena]), do: Usuarios.conectar(usuario, contrasena)
  defp llamar_conectar([usuario, contrasena, tipo, zona]), do: Usuarios.conectar(usuario, contrasena, tipo, zona)

  defp llamar_conectar([usuario, contrasena, tipo, zona, nombre]),
    do: Usuarios.conectar(usuario, contrasena, tipo, zona, nombre)

  defp llamar_conectar(_argumentos), do: {:error, {:uso_incorrecto, :connect}}

  defp nombre_usuario([usuario | _resto]), do: usuario
  defp nombre_usuario([]), do: "anonimo"

  # Si se conectó, la nueva sesión queda como activa.
  defp estado_tras_conectar({:ok, usuario, _modo}, estado) do
    %{estado | activa: usuario.usuario, sesiones: Map.put(estado.sesiones, usuario.usuario, usuario)}
  end

  defp estado_tras_conectar(_error, estado), do: estado

  defp usar([usuario], estado) do
    estado.sesiones
    |> Map.has_key?(usuario)
    |> cambiar_activa(usuario, estado)
  end

  defp usar(_argumentos, estado), do: {{:error, {:uso_incorrecto, :use}}, estado}

  defp cambiar_activa(true, usuario, estado), do: {{:ok, usuario}, %{estado | activa: usuario}}
  defp cambiar_activa(false, usuario, estado), do: {{:error, {:sesion_no_encontrada, usuario}}, estado}

  # Datos de cada proceso Sesion (los guarda el DynamicSupervisor).
  defp listar_sesiones() do
    Usuarios.sesiones()
    |> Map.values()
    |> Enum.map(&Sesion.consultar/1)
    |> Enum.sort_by(& &1.usuario)
  end

  # Al desconectarse, la sesión sale de la consola; queda activa otra si la hay.
  defp estado_tras_comando(:disconnect, {:ok, usuario}, estado) do
    sesiones = Map.delete(estado.sesiones, usuario)
    %{estado | sesiones: sesiones, activa: primera_sesion(Map.keys(sesiones))}
  end

  defp estado_tras_comando(_comando, _respuesta, estado), do: estado

  defp primera_sesion([]), do: nil
  defp primera_sesion([usuario | _resto]), do: usuario

  defp ayuda(nil), do: {nil, @comandos_basicos}
  defp ayuda(usuario), do: {usuario.tipo, @comandos_basicos ++ Permisos.comandos_permitidos(usuario.tipo)}

  # ---------------------------------------------------------------
  # Permisos + ejecución + bitácora
  # ---------------------------------------------------------------

  defp ejecutar_con_sesion(nil, _comando, _argumentos, estado), do: {{:error, :sin_sesion}, estado}

  defp ejecutar_con_sesion(usuario, comando, argumentos, estado) do
    respuesta =
      usuario.tipo
      |> Permisos.permitido?(comando)
      |> ejecutar_si_permitido(comando, argumentos, usuario)

    registrar_actividad(usuario.usuario, comando, respuesta)
    {respuesta, estado_tras_comando(comando, respuesta, estado)}
  end

  defp ejecutar_si_permitido(true, comando, argumentos, usuario), do: ejecutar_comando(comando, argumentos, usuario)
  defp ejecutar_si_permitido(false, comando, _argumentos, usuario), do: {:error, {:sin_permiso, usuario.tipo, comando}}

  # La bitácora es un proceso aparte: `registrar` usa `send` y no espera respuesta.
  defp registrar_actividad(usuario, comando, respuesta) do
    Bitacora.registrar(usuario, Atom.to_string(comando), resumir(respuesta))
  end

  # inspect convierte cualquier dato en texto, por ejemplo {:sin_permiso, "ciudadano", :summary}.
  defp resumir({:error, motivo}), do: "error " <> inspect(motivo)
  defp resumir(_respuesta), do: "ok"

  # ---------------------------------------------------------------
  # Un caso por comando (pattern matching sobre el nombre y los argumentos)
  # ---------------------------------------------------------------

  defp ejecutar_comando(:disconnect, [], usuario), do: Usuarios.desconectar(usuario.usuario)

  # --- Zonas ---
  defp ejecutar_comando(:register_zone, [codigo, nombre, nivel], _usuario), do: Zonas.registrar_zona(codigo, nombre, nivel, 0)

  defp ejecutar_comando(:register_zone, [codigo, nombre, nivel, personas], _usuario) do
    personas
    |> Validaciones.convertir_entero()
    |> continuar(fn numero -> Zonas.registrar_zona(codigo, nombre, nivel, numero) end)
  end

  defp ejecutar_comando(:register_sector, [zona, codigo, nombre, nivel], _usuario),
    do: Zonas.registrar_sector(zona, codigo, nombre, nivel, 0)

  defp ejecutar_comando(:register_sector, [zona, codigo, nombre, nivel, personas], _usuario) do
    personas
    |> Validaciones.convertir_entero()
    |> continuar(fn numero -> Zonas.registrar_sector(zona, codigo, nombre, nivel, numero) end)
  end

  defp ejecutar_comando(:register_point, [sector, codigo, nombre], _usuario), do: Zonas.registrar_punto(sector, codigo, nombre)

  defp ejecutar_comando(:register_point, [sector, codigo, nombre, nivel, personas], _usuario) do
    personas
    |> Validaciones.convertir_entero()
    |> continuar(fn numero -> Zonas.registrar_punto(sector, codigo, nombre, nivel, numero) end)
  end

  defp ejecutar_comando(:list_zones, [], _usuario), do: {:ok, Zonas.listar()}
  defp ejecutar_comando(:zone_stats, [codigo], _usuario), do: Zonas.consultar(codigo)

  defp ejecutar_comando(:zone_status, [codigo], _usuario) do
    codigo
    |> Zonas.consultar()
    |> continuar(&estado_de_zona/1)
  end

  # --- Centros ---
  defp ejecutar_comando(:register_center, [codigo, nombre, tipo, zona], _usuario) do
    zona
    |> validar_lugar()
    |> continuar(fn _lugar -> Centros.registrar(codigo, nombre, tipo, zona) end)
    |> continuar(&avisar_ubicacion/1)
  end

  defp ejecutar_comando(:list_centers, [], _usuario), do: {:ok, Centros.listar()}

  # --- Necesidades ---
  defp ejecutar_comando(:register_need, [tipo, cantidad, prioridad, zona | palabras], usuario) when palabras != [] do
    [Validaciones.convertir_entero(cantidad), validar_lugar(zona)]
    |> todos_ok()
    |> continuar(fn [numero, _lugar] ->
      Necesidades.registrar(tipo, numero, prioridad, zona, Enum.join(palabras, " "), usuario.usuario)
    end)
  end

  defp ejecutar_comando(:list_needs, [], _usuario), do: {:ok, Necesidades.listar()}
  defp ejecutar_comando(:list_needs, [filtros], _usuario) when is_map(filtros), do: {:ok, Necesidades.listar(filtros)}

  defp ejecutar_comando(:update_need, [id, estado], usuario),
    do: Necesidades.actualizar_estado(id_necesidad(id), estado, usuario.usuario)

  defp ejecutar_comando(:pending_needs, [], _usuario), do: {:ok, Necesidades.pendientes()}
  defp ejecutar_comando(:next_need, [], _usuario), do: Necesidades.siguiente()
  defp ejecutar_comando(:next_need, [zona], _usuario), do: Necesidades.siguiente(zona)

  defp ejecutar_comando(:assign_resource, [id, categoria_o_codigo, cantidad], usuario) do
    cantidad
    |> Validaciones.convertir_entero()
    |> continuar(fn numero -> Necesidades.asignar_recurso(id_necesidad(id), categoria_o_codigo, numero, usuario.usuario) end)
  end

  # --- Recursos ---
  defp ejecutar_comando(:register_resource, [codigo, categoria, cantidad, unidad, ubicacion], usuario),
    do: ejecutar_comando(:register_resource, [codigo, categoria, cantidad, unidad, ubicacion, categoria], usuario)

  defp ejecutar_comando(:register_resource, [codigo, categoria, cantidad, unidad, ubicacion, nombre], usuario) do
    cantidad
    |> Validaciones.convertir_entero()
    |> continuar(fn numero ->
      Inventario.registrar_recurso(codigo, nombre, categoria, numero, unidad, ubicacion, usuario.usuario)
    end)
  end

  defp ejecutar_comando(:list_resources, [], _usuario), do: {:ok, Inventario.listar()}
  defp ejecutar_comando(:list_resources, [filtros], _usuario) when is_map(filtros), do: {:ok, Inventario.listar(filtros)}

  defp ejecutar_comando(:resource_in, [codigo, cantidad], usuario) do
    cantidad
    |> Validaciones.convertir_entero()
    |> continuar(fn numero -> Inventario.registrar_entrada(codigo, numero, usuario.usuario) end)
  end

  defp ejecutar_comando(:resource_out, [codigo, cantidad], usuario) do
    cantidad
    |> Validaciones.convertir_entero()
    |> continuar(fn numero -> Inventario.registrar_salida(codigo, numero, usuario.usuario) end)
  end

  defp ejecutar_comando(:transfer_resource, [codigo, origen, destino, cantidad], usuario) do
    cantidad
    |> Validaciones.convertir_entero()
    |> continuar(fn numero -> Inventario.transferir(codigo, origen, destino, numero, usuario.usuario) end)
  end

  defp ejecutar_comando(:resource_history, [codigo], _usuario) do
    codigo
    |> Inventario.obtener()
    |> continuar(fn recurso -> {:ok, {recurso, Inventario.historial(codigo)}} end)
  end

  defp ejecutar_comando(:critical_resources, [], _usuario) do
    {:ok, {Inventario.umbral_critico(), Inventario.recursos_criticos(Necesidades.faltantes_pendientes())}}
  end

  # --- Personas y mensajes ---
  defp ejecutar_comando(:report_person, [documento, nombre, zona, estado], usuario),
    do: ejecutar_comando(:report_person, [documento, nombre, "0", zona, estado], usuario)

  defp ejecutar_comando(:report_person, [documento, nombre, edad, zona, estado], usuario) do
    [Validaciones.convertir_entero(edad), validar_lugar(zona)]
    |> todos_ok()
    |> continuar(fn [numero, _lugar] -> Personas.registrar(documento, nombre, numero, zona, estado, usuario.usuario) end)
  end

  defp ejecutar_comando(:update_person, [documento, estado], usuario),
    do: Personas.actualizar_estado(documento, estado, usuario.usuario)

  # Primero el caso con filtros (mapa); si no es mapa, el argumento es el documento.
  defp ejecutar_comando(:find_person, [filtros], _usuario) when is_map(filtros), do: {:ok, Personas.buscar(filtros)}
  defp ejecutar_comando(:find_person, [documento], _usuario), do: {:ok, Personas.buscar(%{"documento" => documento})}
  defp ejecutar_comando(:person_history, [documento], _usuario), do: Personas.obtener(documento)

  defp ejecutar_comando(:send_family_message, [destinatario | palabras], usuario) when palabras != [] do
    Personas.enviar_mensaje(usuario.usuario, destinatario, Enum.join(palabras, " "))
  end

  defp ejecutar_comando(:list_family_messages, [destinatario], _usuario), do: {:ok, Personas.mensajes_para(destinatario)}
  defp ejecutar_comando(:mark_message, [id, estado], _usuario), do: Personas.marcar_mensaje(String.upcase(id), estado)

  # --- Mascotas ---
  defp ejecutar_comando(:report_pet, [tipo, especie, nombre, color, tamano, zona, contacto | caracteristicas], _usuario) do
    zona
    |> validar_lugar()
    |> continuar(fn _lugar ->
      Mascotas.reportar(tipo_reporte(tipo), especie, nombre, color, tamano, zona, contacto, Enum.join(caracteristicas, " "))
    end)
  end

  defp ejecutar_comando(:list_pets, [], _usuario), do: {:ok, Mascotas.listar()}
  defp ejecutar_comando(:list_pets, [filtros], _usuario) when is_map(filtros), do: {:ok, Mascotas.listar(filtros)}
  defp ejecutar_comando(:match_pets, [], _usuario), do: Mascotas.buscar_coincidencias()

  defp ejecutar_comando(:confirm_pet_match, [id_perdida, id_encontrada], usuario),
    do: Mascotas.confirmar_coincidencia(String.upcase(id_perdida), String.upcase(id_encontrada), usuario.usuario)

  defp ejecutar_comando(:discard_pet_match, [id_perdida, id_encontrada], _usuario),
    do: Mascotas.descartar_coincidencia(String.upcase(id_perdida), String.upcase(id_encontrada))

  # --- Albergues ---
  defp ejecutar_comando(:register_shelter, [codigo, nombre, zona, capacidad], _usuario) do
    [Validaciones.convertir_entero(capacidad), validar_lugar(zona)]
    |> todos_ok()
    |> continuar(fn [numero, _lugar] -> Albergues.registrar(codigo, nombre, zona, numero) end)
    |> continuar(&registrar_albergue_como_centro/1)
  end

  defp ejecutar_comando(:check_shelter, [codigo], _usuario) do
    codigo
    |> Albergues.consultar()
    |> continuar(fn albergue ->
      {:ok,
       %{
         albergue: albergue,
         recursos: Inventario.listar(%{"ubicacion" => codigo}),
         necesidades: Necesidades.listar(%{"zona" => codigo})
       }}
    end)
  end

  defp ejecutar_comando(:register_entry, [codigo, documento], usuario),
    do: Albergues.registrar_ingreso(codigo, documento, usuario.usuario)

  defp ejecutar_comando(:register_exit, [codigo, documento], usuario),
    do: Albergues.registrar_salida(codigo, documento, usuario.usuario)

  defp ejecutar_comando(:register_exit, [codigo, documento, estado], usuario),
    do: Albergues.registrar_salida(codigo, documento, usuario.usuario, estado)

  defp ejecutar_comando(:shelter_report, [], _usuario), do: {:ok, Albergues.reporte_ocupacion()}

  # --- Reportes y administración ---
  defp ejecutar_comando(:summary, [], _usuario), do: {:ok, resumen_global()}
  defp ejecutar_comando(:list_users, [], _usuario), do: {:ok, Usuarios.listar()}
  defp ejecutar_comando(:activity, [], _usuario), do: {:ok, Bitacora.consultar()}
  defp ejecutar_comando(:activity, [usuario], _usuario_activo), do: {:ok, Bitacora.consultar(usuario)}

  defp ejecutar_comando(:crash_server, [nombre], _usuario) do
    @servidores
    |> Map.get(String.downcase(nombre))
    |> detener_a_la_fuerza(nombre)
  end

  # Cualquier otra cantidad de argumentos: se muestra cómo se usa el comando.
  defp ejecutar_comando(comando, _argumentos, _usuario), do: {:error, {:uso_incorrecto, comando}}

  # ---------------------------------------------------------------
  # Consultas en paralelo con Task (Guía 12)
  # ---------------------------------------------------------------

  # Lanza todas las consultas al mismo tiempo con Task.async y luego espera cada
  # resultado con Task.await. Las tareas son temporales y quedan vinculadas a la consola.
  defp consultar_en_paralelo(funciones) do
    funciones
    |> Enum.map(&Task.async/1)
    |> Enum.map(&Task.await/1)
  end

  defp resumen_global() do
    [totales, necesidades, personas, mensajes, mascotas, albergues] =
      consultar_en_paralelo([
        fn -> Inventario.totales_por_categoria() end,
        fn -> Necesidades.listar() end,
        fn -> Personas.listar() end,
        fn -> Personas.listar_mensajes() end,
        fn -> Mascotas.listar() end,
        fn -> Albergues.reporte_ocupacion() end
      ])

    pendientes = Enum.filter(necesidades, fn necesidad -> necesidad.estado == "pendiente" end)

    %{
      recursos_por_categoria: totales,
      necesidades_por_estado: Enum.frequencies_by(necesidades, & &1.estado),
      pendientes_por_prioridad: Enum.frequencies_by(pendientes, & &1.prioridad),
      pendientes: Enum.take(pendientes, 5),
      personas_por_estado: Enum.frequencies_by(personas, & &1.estado),
      mensajes_por_estado: Enum.frequencies_by(mensajes, & &1.estado),
      mascotas_por_estado: Enum.frequencies_by(mascotas, & &1.estado),
      albergues: albergues
    }
  end

  # Estado general de una zona: todo lo que está en ella o en sus sectores y puntos.
  defp estado_de_zona(%{nodo: nodo, estadisticas: estadisticas, codigos: codigos}) do
    [necesidades, albergues, personas, centros, recursos] =
      consultar_en_paralelo([
        fn -> Necesidades.listar() end,
        fn -> Albergues.listar() end,
        fn -> Personas.listar() end,
        fn -> Centros.listar() end,
        fn -> Inventario.listar() end
      ])

    # MapSet: conjunto de códigos de la zona, para preguntar rápido "¿este lugar es de la zona?".
    lugares = MapSet.new(codigos)
    centros_zona = Enum.filter(centros, fn centro -> MapSet.member?(lugares, centro.zona) end)
    lugares_y_centros = centros_zona |> Enum.map(& &1.codigo) |> Enum.into(lugares)

    {:ok,
     %{
       nodo: nodo,
       estadisticas: estadisticas,
       necesidades: Enum.filter(necesidades, fn n -> MapSet.member?(lugares_y_centros, n.zona) end),
       albergues: Enum.filter(albergues, fn a -> MapSet.member?(lugares, a.zona) end),
       personas: Enum.filter(personas, fn p -> MapSet.member?(lugares, p.zona) end),
       centros: centros_zona,
       recursos: Enum.filter(recursos, fn r -> MapSet.member?(lugares_y_centros, r.ubicacion) end)
     }}
  end

  # ---------------------------------------------------------------
  # Ayudantes
  # ---------------------------------------------------------------

  # Si el paso anterior salió bien, se ejecuta el siguiente; si no, se devuelve el error.
  # (Reemplaza a `with`, que no se vio en clase.)
  defp continuar({:ok, valor}, funcion), do: funcion.(valor)
  defp continuar(error, _funcion), do: error

  # RECURSIVA: junta varios {:ok, valor} en {:ok, [valores]}, o retorna el primer error.
  # Caso base: lista vacía. Caso recursivo: el primero está bien → se junta con el resto.
  defp todos_ok([]), do: {:ok, []}
  defp todos_ok([{:ok, valor} | resto]), do: juntar(valor, todos_ok(resto))
  defp todos_ok([error | _resto]), do: error

  defp juntar(valor, {:ok, valores}), do: {:ok, [valor | valores]}
  defp juntar(_valor, error), do: error

  # Un lugar válido es una zona, sector o punto del árbol, o un centro de apoyo (por ejemplo, un albergue).
  defp validar_lugar(codigo) do
    (Zonas.existe?(codigo) or Centros.existe?(codigo))
    |> resultado_lugar(codigo)
  end

  defp resultado_lugar(true, codigo), do: {:ok, codigo}
  defp resultado_lugar(false, codigo), do: {:error, {:zona_no_registrada, codigo}}

  # El inventario necesita saber en qué zona está cada centro para elegir recursos cercanos.
  defp avisar_ubicacion(centro) do
    Inventario.registrar_ubicacion(centro.codigo, centro.zona)
    {:ok, centro}
  end

  # Un albergue también es un centro de apoyo: así se le pueden transferir recursos.
  defp registrar_albergue_como_centro(albergue) do
    Centros.registrar(albergue.codigo, albergue.nombre, "albergue", albergue.zona)
    Inventario.registrar_ubicacion(albergue.codigo, albergue.zona)
    {:ok, albergue}
  end

  # "need001" (como en el enunciado) o "n001" → "N001".
  defp id_necesidad(id) do
    id
    |> String.downcase()
    |> String.starts_with?("need")
    |> convertir_id_necesidad(id)
  end

  defp convertir_id_necesidad(true, id), do: "N" <> (id |> String.downcase() |> String.replace("need", ""))
  defp convertir_id_necesidad(false, id), do: String.upcase(id)

  defp tipo_reporte(tipo) do
    tipo
    |> String.downcase()
    |> traducir_tipo_reporte()
  end

  defp traducir_tipo_reporte("lost"), do: "perdida"
  defp traducir_tipo_reporte("found"), do: "encontrada"
  defp traducir_tipo_reporte(otro), do: otro

  defp detener_a_la_fuerza(nil, nombre), do: {:error, {:servidor_desconocido, nombre}}

  defp detener_a_la_fuerza(proceso, nombre) do
    pid_viejo = Process.whereis(proceso)
    Process.exit(pid_viejo, :kill)
    {:ok, {nombre, pid_viejo, esperar_reinicio(proceso, pid_viejo)}}
  end

  # RECURSIVA: pregunta hasta que el supervisor haya iniciado un proceso NUEVO con ese nombre.
  defp esperar_reinicio(proceso, pid_viejo) do
    proceso
    |> Process.whereis()
    |> revisar_pid(proceso, pid_viejo)
  end

  defp revisar_pid(nil, proceso, pid_viejo), do: esperar_reinicio(proceso, pid_viejo)
  defp revisar_pid(pid, proceso, pid_viejo) when pid == pid_viejo, do: esperar_reinicio(proceso, pid_viejo)
  defp revisar_pid(pid_nuevo, _proceso, _pid_viejo), do: pid_nuevo
end
