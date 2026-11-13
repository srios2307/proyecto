defmodule Consola do
  @moduledoc """
  Interfaz de texto del sistema. Es, junto con `Util2`, el ÚNICO lugar con pantalla.

  `ciclo/1` es recursivo: leer → analizar → ejecutar → mostrar → volver a empezar.
  Todos los textos se arman con `generar_mensaje/1` (función pura) y se muestran con
  `Util2.mostrar/2`.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  # Forma de uso de cada comando (para `help` y para los errores de uso).
  @ayuda %{
    connect: "connect usuario contraseña [tipo zona [\"nombre completo\"]]",
    disconnect: "disconnect",
    use: "use usuario                          (cambia la sesión activa)",
    sessions: "sessions                             (sesiones abiertas)",
    help: "help",
    exit: "exit",
    register_zone: "register_zone codigo \"nombre\" nivel [personas]",
    register_sector: "register_sector zona codigo \"nombre\" nivel [personas]",
    register_point: "register_point sector codigo \"nombre\" [nivel personas]",
    list_zones: "list_zones",
    zone_status: "zone_status codigo",
    zone_stats: "zone_stats codigo",
    register_center: "register_center codigo \"nombre\" (centro_acopio|albergue|punto_atencion) zona",
    list_centers: "list_centers",
    register_need: "register_need tipo cantidad prioridad zona \"descripcion\"",
    list_needs: "list_needs [zona=.. tipo=.. prioridad=.. estado=..]",
    update_need: "update_need id estado",
    pending_needs: "pending_needs",
    next_need: "next_need [zona]",
    assign_resource: "assign_resource id_necesidad (categoria|codigo_recurso) cantidad",
    register_resource: "register_resource codigo categoria cantidad unidad ubicacion [\"nombre\"]",
    list_resources: "list_resources [categoria=.. zona=.. ubicacion=..]",
    resource_in: "resource_in codigo cantidad",
    resource_out: "resource_out codigo cantidad",
    transfer_resource: "transfer_resource codigo origen destino cantidad",
    resource_history: "resource_history codigo",
    critical_resources: "critical_resources",
    report_person: "report_person documento \"nombre\" [edad] zona estado",
    update_person: "update_person documento estado",
    find_person: "find_person (documento | nombre=.. | zona=.. | estado=..)",
    person_history: "person_history documento",
    send_family_message: "send_family_message destinatario \"contenido\"",
    list_family_messages: "list_family_messages destinatario",
    mark_message: "mark_message id (entregado|pendiente)",
    report_pet: "report_pet (lost|found) especie \"nombre|desconocido\" color tamano zona contacto [\"caracteristicas\"]",
    list_pets: "list_pets [especie=.. zona=.. estado=.. tipo=..]",
    match_pets: "match_pets",
    confirm_pet_match: "confirm_pet_match id_perdida id_encontrada",
    discard_pet_match: "discard_pet_match id_perdida id_encontrada",
    register_shelter: "register_shelter codigo \"nombre\" zona capacidad",
    check_shelter: "check_shelter codigo",
    register_entry: "register_entry codigo_albergue documento",
    register_exit: "register_exit codigo_albergue documento [trasladada|reunificada]",
    shelter_report: "shelter_report",
    summary: "summary",
    list_users: "list_users",
    activity: "activity [usuario]",
    crash_server: "crash_server (inventario|necesidades|zonas|centros|personas|mascotas|albergues|bitacora)"
  }

  @doc """
  Muestra la bienvenida y empieza el ciclo de comandos.
  """
  def iniciar() do
    generar_mensaje_bienvenida()
    |> Util2.mostrar(:mensaje)

    Comandos.estado_inicial()
    |> ciclo()
  end

  @doc """
  Ciclo principal de la consola.
  """
  # RECURSIVA: ciclo
  # Caso recursivo: lee una línea, la analiza, la ejecuta, muestra el resultado y se
  # llama otra vez con el NUEVO estado. Caso base: el comando `exit` (ver `procesar/2`).
  def ciclo(estado) do
    estado
    |> generar_prompt()
    |> Util2.ingresar(:texto)
    |> AnalizadorComandos.analizar()
    |> procesar(estado)
  end

  # Caso base: exit → se cierran las sesiones y NO se vuelve a llamar a ciclo.
  defp procesar({:exit, _argumentos}, estado) do
    Comandos.cerrar_sesiones(estado)

    "Sesiones cerradas. Hasta pronto."
    |> Util2.mostrar(:mensaje)
  end

  defp procesar(analizado, estado) do
    {respuesta, nuevo_estado} = Comandos.ejecutar(analizado, estado)

    {comando_de(analizado), respuesta}
    |> generar_mensaje()
    |> mostrar(respuesta)

    ciclo(nuevo_estado)
  end

  defp comando_de({comando, _argumentos}), do: comando

  # Los errores van a la salida de error; las líneas vacías no se muestran.
  defp mostrar("", _respuesta), do: :ok
  defp mostrar(texto, {:error, _motivo}), do: Util2.mostrar(texto, :error)
  defp mostrar(texto, _respuesta), do: Util2.mostrar(texto, :mensaje)

  defp generar_prompt(%{activa: nil}), do: "emergencias> "
  defp generar_prompt(%{activa: usuario}), do: "emergencias(#{usuario})> "

  defp generar_mensaje_bienvenida() do
    """
    ==============================================================
     Sistema de Coordinación y Gestión de Emergencias (terremoto)
    ==============================================================
    Escriba 'help' para ver los comandos. Para empezar:
      connect usuario contraseña [tipo zona]
    """
  end

  # ---------------------------------------------------------------
  # generar_mensaje: una cláusula por comando (funciones puras)
  # ---------------------------------------------------------------

  @doc """
  Arma el texto que se muestra para `{comando, respuesta}`.
  """
  def generar_mensaje({_comando, {:error, motivo}}), do: "ERROR: " <> describir_error(motivo)
  def generar_mensaje({_comando, {:ok, :nada}}), do: ""

  def generar_mensaje({:connect, {:ok, usuario, :registrado}}) do
    "Usuario #{usuario.usuario} registrado como #{usuario.tipo} (zona #{usuario.zona}) y conectado. " <>
      "Sesión activa: #{usuario.usuario}."
  end

  def generar_mensaje({:connect, {:ok, usuario, :autenticado}}) do
    "Bienvenido de nuevo, #{usuario.nombre_completo} (#{usuario.tipo}). Sesión activa: #{usuario.usuario}."
  end

  def generar_mensaje({:disconnect, {:ok, usuario}}), do: "#{usuario} se desconectó. Use 'sessions' y 'use usuario' para cambiar de sesión."
  def generar_mensaje({:use, {:ok, usuario}}), do: "Sesión activa: #{usuario}."

  def generar_mensaje({:sessions, {:ok, {[], _activa}}}), do: "No hay sesiones abiertas."

  def generar_mensaje({:sessions, {:ok, {sesiones, activa}}}) do
    "Sesiones abiertas (un proceso Sesion por usuario):\n" <>
      Util2.convertir_coleccion_mensaje(sesiones, fn sesion ->
        "  #{sesion.usuario} (#{sesion.tipo}, zona #{sesion.zona}) desde #{sesion.hora_conexion}#{marca_activa(sesion.usuario, activa)}\n"
      end)
  end

  def generar_mensaje({:help, {:ok, {nil, comandos}}}) do
    "Comandos sin sesión:\n" <> texto_ayuda(comandos) <> "Conéctese para ver los comandos de su rol."
  end

  def generar_mensaje({:help, {:ok, {tipo, comandos}}}), do: "Comandos para #{tipo}:\n" <> texto_ayuda(comandos)

  # --- Zonas ---
  def generar_mensaje({comando, {:ok, %NodoZona{} = nodo}}) when comando in [:register_zone, :register_sector, :register_point],
    do: "Registrado: #{nodo}"

  def generar_mensaje({:list_zones, {:ok, []}}), do: "No hay zonas registradas."
  def generar_mensaje({:list_zones, {:ok, zonas}}), do: "Zonas → sectores → puntos:\n" <> dibujar_arbol(zonas, 1)

  def generar_mensaje({:zone_stats, {:ok, consulta}}) do
    dibujar_arbol([consulta.nodo], 0) <> texto_estadisticas(consulta.estadisticas)
  end

  def generar_mensaje({:zone_status, {:ok, info}}) do
    "ESTADO GENERAL DE #{info.nodo}\n" <>
      texto_estadisticas(info.estadisticas) <>
      listar("Necesidades (por prioridad)", info.necesidades) <>
      listar("Albergues", info.albergues) <>
      listar("Personas", info.personas) <>
      listar("Centros", info.centros) <>
      listar("Recursos", info.recursos)
  end

  def generar_mensaje({:register_center, {:ok, centro}}), do: "Centro registrado: #{centro}"
  def generar_mensaje({:list_centers, {:ok, lista}}), do: listar("Centros de apoyo", lista)

  # --- Necesidades ---
  def generar_mensaje({:register_need, {:ok, necesidad}}), do: "Necesidad registrada: #{necesidad}"
  def generar_mensaje({:list_needs, {:ok, lista}}), do: listar("Necesidades (ordenadas por prioridad)", lista)
  def generar_mensaje({:pending_needs, {:ok, lista}}), do: listar("Necesidades pendientes (ordenadas por prioridad)", lista)
  def generar_mensaje({:update_need, {:ok, necesidad}}), do: "Necesidad actualizada: #{necesidad}"
  def generar_mensaje({:next_need, {:ok, necesidad}}), do: "Siguiente necesidad a atender: #{necesidad}"
  def generar_mensaje({:assign_resource, {:ok, necesidad}}), do: "Asignación confirmada: #{necesidad}"

  # --- Recursos ---
  def generar_mensaje({:register_resource, {:ok, recurso}}), do: "Recurso registrado: #{recurso}"
  def generar_mensaje({:list_resources, {:ok, lista}}), do: listar("Recursos", lista)

  def generar_mensaje({comando, {:ok, recurso}}) when comando in [:resource_in, :resource_out],
    do: "Inventario actualizado: #{recurso}"

  def generar_mensaje({:transfer_resource, {:ok, origen, destino}}) do
    "Transferencia realizada.\n  Origen:  #{origen}\n  Destino: #{destino}"
  end

  def generar_mensaje({:resource_history, {:ok, {recurso, movimientos}}}), do: "#{recurso}\n" <> listar("Movimientos", movimientos)

  def generar_mensaje({:critical_resources, {:ok, {_umbral, []}}}), do: "No hay recursos críticos."

  def generar_mensaje({:critical_resources, {:ok, {umbral, criticos}}}) do
    "Recursos críticos (menos de #{umbral} o menos de lo que falta en su zona):\n" <>
      Util2.convertir_coleccion_mensaje(criticos, fn {recurso, faltante} -> "  #{recurso}#{texto_faltante(faltante)}\n" end)
  end

  # --- Personas y mensajes ---
  def generar_mensaje({:report_person, {:ok, persona}}), do: "Persona registrada: #{persona}"
  def generar_mensaje({:update_person, {:ok, persona}}), do: "Estado actualizado: #{persona}"
  def generar_mensaje({:find_person, {:ok, lista}}), do: listar("Personas encontradas", lista)

  def generar_mensaje({:person_history, {:ok, persona}}) do
    "#{persona}\nHistorial de estados:\n" <>
      Util2.convertir_coleccion_mensaje(persona.historial, fn {fecha, anterior, nuevo, usuario} ->
        "  #{fecha}  #{anterior} -> #{nuevo}  (por #{usuario})\n"
      end)
  end

  def generar_mensaje({:send_family_message, {:ok, mensaje}}), do: "Mensaje guardado: #{mensaje}"
  def generar_mensaje({:list_family_messages, {:ok, lista}}), do: listar("Mensajes", lista)
  def generar_mensaje({:mark_message, {:ok, mensaje}}), do: "Mensaje actualizado: #{mensaje}"

  # --- Mascotas ---
  def generar_mensaje({:report_pet, {:ok, mascota}}), do: "Reporte registrado: #{mascota}"
  def generar_mensaje({:list_pets, {:ok, lista}}), do: listar("Reportes de mascotas", lista)
  def generar_mensaje({:match_pets, {:ok, []}}), do: "No hay posibles coincidencias (puntaje >= 50)."

  def generar_mensaje({:match_pets, {:ok, pares}}) do
    "Posibles coincidencias (puntaje >= 50), de mayor a menor:\n" <>
      Util2.convertir_coleccion_mensaje(pares, fn {id_perdida, id_encontrada, puntaje} ->
        "  #{id_perdida} (perdida) <-> #{id_encontrada} (encontrada): #{puntaje} puntos\n"
      end)
  end

  def generar_mensaje({:confirm_pet_match, {:ok, perdida, encontrada}}),
    do: "Coincidencia confirmada: #{perdida.id} y #{encontrada.id} quedaron resueltas."

  def generar_mensaje({:discard_pet_match, {:ok, perdida, encontrada}}),
    do: "Coincidencia descartada: #{perdida.id} y #{encontrada.id} vuelven a estar activas."

  # --- Albergues ---
  def generar_mensaje({:register_shelter, {:ok, albergue}}), do: "Albergue registrado: #{albergue}"

  def generar_mensaje({:check_shelter, {:ok, info}}) do
    "#{info.albergue}\n  Ocupantes: #{texto_ocupantes(info.albergue)}\n" <>
      listar("Recursos en el albergue", info.recursos) <>
      listar("Necesidades del albergue", info.necesidades)
  end

  def generar_mensaje({comando, {:ok, albergue}}) when comando in [:register_entry, :register_exit],
    do: "Albergue actualizado: #{albergue}"

  def generar_mensaje({:shelter_report, {:ok, lista}}), do: listar("Albergues del más ocupado al menos ocupado", lista)

  # --- Reportes y administración ---
  def generar_mensaje({:summary, {:ok, resumen}}) do
    """
    ===================== RESUMEN GLOBAL =====================
    Recursos restantes por categoría: #{texto_mapa(resumen.recursos_por_categoria)}
    Necesidades por estado: #{texto_mapa(resumen.necesidades_por_estado)}
    Necesidades pendientes por prioridad: #{texto_mapa(resumen.pendientes_por_prioridad)}
    Personas por estado: #{texto_mapa(resumen.personas_por_estado)}
    Mensajes: #{texto_mapa(resumen.mensajes_por_estado)}
    Mascotas por estado: #{texto_mapa(resumen.mascotas_por_estado)}
    """ <>
      listar("Primeras necesidades pendientes", resumen.pendientes) <>
      listar("Albergues (más ocupados primero)", resumen.albergues) <>
      "=========================================================="
  end

  def generar_mensaje({:list_users, {:ok, lista}}), do: listar("Usuarios", lista)
  def generar_mensaje({:activity, {:ok, []}}), do: "No hay actividad registrada."

  def generar_mensaje({:activity, {:ok, registros}}) do
    "Actividad (#{length(registros)} registros):\n" <>
      Util2.convertir_coleccion_mensaje(registros, fn {fecha, usuario, comando, resultado} ->
        "  #{fecha}  #{usuario}  #{comando}  #{resultado}\n"
      end)
  end

  def generar_mensaje({:crash_server, {:ok, {nombre, pid_viejo, pid_nuevo}}}) do
    "#{nombre} se detuvo a la fuerza (#{inspect(pid_viejo)}) y el supervisor lo reinició (#{inspect(pid_nuevo)}). " <>
      "Sus datos se recuperaron del archivo."
  end

  def generar_mensaje({_comando, _respuesta}), do: "Operación realizada."

  # ---------------------------------------------------------------
  # Ayudantes de formato
  # ---------------------------------------------------------------

  defp listar(titulo, []), do: "#{titulo}: (ninguno)\n"

  defp listar(titulo, lista) do
    "#{titulo} (#{length(lista)}):\n" <> Util2.convertir_coleccion_mensaje(lista, &"  #{&1}\n")
  end

  defp texto_ayuda(comandos), do: Util2.convertir_coleccion_mensaje(comandos, fn comando -> "  #{Map.get(@ayuda, comando)}\n" end)

  defp texto_faltante(0), do: ""
  defp texto_faltante(faltante), do: " | faltan #{faltante} en su zona"

  defp marca_activa(usuario, usuario), do: "  <- activa"
  defp marca_activa(_usuario, _activa), do: ""

  defp texto_mapa(mapa) when mapa == %{}, do: "(sin datos)"

  defp texto_mapa(mapa) do
    mapa
    |> Enum.map(fn {clave, valor} -> "#{clave}=#{valor}" end)
    |> Enum.join(", ")
  end

  defp texto_estadisticas(e) do
    "Estadísticas acumuladas: #{e.personas_afectadas} personas afectadas, #{e.sectores} sectores, " <>
      "#{e.puntos} puntos, nivel más crítico: #{e.nivel_mas_critico}\n"
  end

  defp texto_ocupantes(albergue) do
    albergue.ocupantes
    |> MapSet.to_list()
    |> Enum.sort()
    |> Enum.join(", ")
  end

  # RECURSIVA: dibuja el árbol de zonas con sangría según el nivel.
  # Caso base: lista vacía. Caso recursivo: el nodo, luego sus hijos (un nivel más adentro) y luego sus hermanos.
  defp dibujar_arbol([], _nivel), do: ""

  defp dibujar_arbol([nodo | resto], nivel) do
    sangria(nivel) <> "- #{nodo}\n" <> dibujar_arbol(nodo.hijos, nivel + 1) <> dibujar_arbol(resto, nivel)
  end

  # RECURSIVA: tres espacios por nivel.
  defp sangria(0), do: ""
  defp sangria(nivel), do: "   " <> sangria(nivel - 1)

  # ---------------------------------------------------------------
  # Mensajes de error claros (una cláusula por motivo)
  # ---------------------------------------------------------------

  @doc """
  Traduce el motivo de un error a un texto claro para el usuario.
  """
  def describir_error(:sin_sesion), do: "No hay sesión activa. Conéctese con: connect usuario contraseña [tipo zona]"

  def describir_error({:sin_permiso, tipo, comando}),
    do: "Un usuario de tipo '#{tipo}' no tiene permiso para '#{comando}'."

  def describir_error(:credenciales_invalidas), do: "Usuario o contraseña incorrectos."
  def describir_error(:ya_conectado), do: "Ese usuario ya tiene una sesión abierta (use 'use usuario')."
  def describir_error(:no_conectado), do: "Ese usuario no está conectado."
  def describir_error({:sesion_no_encontrada, usuario}), do: "No hay sesión abierta para #{usuario}. Vea 'sessions'."
  def describir_error({:comando_desconocido, nombre}), do: "Comando desconocido: '#{nombre}'. Escriba 'help'."
  def describir_error(:comillas_sin_cerrar), do: "Faltan unas comillas de cierre."
  def describir_error({:uso_incorrecto, comando}), do: "Uso: #{Map.get(@ayuda, comando, comando)}"
  def describir_error({:numero_invalido, texto}), do: "'#{texto}' no es un número entero."
  def describir_error({:campo_vacio, campo}), do: "El campo '#{campo}' no puede estar vacío."
  def describir_error({:caracter_no_permitido, campo}), do: "El campo '#{campo}' no puede contener ';', '|' ni saltos de línea."
  def describir_error({:opcion_invalida, campo, valor}), do: "Valor inválido para '#{campo}': '#{valor}'."
  def describir_error({:cantidad_negativa, campo}), do: "'#{campo}' no puede ser negativo."
  def describir_error({:cantidad_invalida, campo}), do: "'#{campo}' debe ser un entero mayor que cero."
  def describir_error({:id_repetido, id}), do: "El identificador '#{id}' ya existe."

  def describir_error({:inventario_insuficiente, [disponible: disponible]}),
    do: "Inventario insuficiente: solo hay #{disponible} disponibles en un mismo recurso. No se hizo ningún cambio."

  def describir_error({:supera_faltante, falta}), do: "La cantidad supera lo que falta por cubrir (#{falta})."
  def describir_error(:ya_cerrada), do: "La necesidad ya está cerrada (atendida o cancelada): no consume más recursos."
  def describir_error({:estado_no_permite_asignar, estado}), do: "Una necesidad en estado '#{estado}' no recibe asignaciones."
  def describir_error(:asignada_solo_con_recursos), do: "Una necesidad pasa a 'asignada' solo con assign_resource."
  def describir_error({:transicion_invalida, desde, hacia}), do: "No se puede pasar de '#{desde}' a '#{hacia}'."
  def describir_error({:estado_invalido, estado}), do: "Estado desconocido: '#{estado}'."
  def describir_error(:ya_resuelta), do: "El reporte ya estaba resuelto: no se resuelve dos veces."
  def describir_error(:ya_reunificada), do: "La persona ya fue reunificada (estado final)."
  def describir_error(:albergue_lleno), do: "El albergue está lleno: no hay cupos."
  def describir_error({:ya_esta_en_albergue, documento}), do: "La persona #{documento} ya está en ese albergue."
  def describir_error({:no_esta_en_albergue, documento}), do: "La persona #{documento} no está en ese albergue."
  def describir_error({:albergue_no_encontrado, codigo}), do: "No existe el albergue '#{codigo}'."
  def describir_error({:persona_no_encontrada, documento}), do: "No hay una persona registrada con documento '#{documento}'."
  def describir_error({:necesidad_no_encontrada, id}), do: "No existe la necesidad '#{id}'."
  def describir_error({:recurso_no_encontrado, codigo}), do: "No existe el recurso '#{codigo}'."
  def describir_error({:mascota_no_encontrada, id}), do: "No existe el reporte de mascota '#{id}'."
  def describir_error({:mensaje_no_encontrado, id}), do: "No existe el mensaje '#{id}'."
  def describir_error({:centro_no_encontrado, codigo}), do: "No existe el centro '#{codigo}'."
  def describir_error(:zona_no_encontrada), do: "La zona no existe."
  def describir_error({:zona_no_encontrada, codigo}), do: "La zona o sector '#{codigo}' no existe."
  def describir_error({:zona_no_registrada, codigo}), do: "El lugar '#{codigo}' no está registrado (zona, sector, punto o centro)."
  def describir_error({:padre_invalido, tipo_padre, tipo}),
    do: "No se puede poner un '#{tipo}' dentro de un '#{tipo_padre}': un sector va en una zona y un punto en un sector."
  def describir_error({:ubicacion_no_registrada, ubicacion}), do: "'#{ubicacion}' no es un centro de apoyo registrado."
  def describir_error({:origen_incorrecto, real}), do: "El recurso está en '#{real}', no en el origen indicado."
  def describir_error(:mismo_origen_y_destino), do: "El origen y el destino son el mismo centro."
  def describir_error(:sin_pendientes), do: "No hay necesidades pendientes."
  def describir_error(:especies_distintas), do: "Las dos mascotas son de especies distintas."
  def describir_error(:tipos_de_reporte_invalidos), do: "El primero debe ser un reporte 'perdida' y el segundo 'encontrada'."
  def describir_error({:servidor_desconocido, nombre}), do: "No hay un proceso llamado '#{nombre}'."
  def describir_error(otro), do: inspect(otro)
end
