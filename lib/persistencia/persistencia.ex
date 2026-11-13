defmodule Persistencia do
  @moduledoc """
  Formato de cada archivo de texto plano (separador `;`) y funciones para
  guardar y cargar los datos de cada GenServer. Solo este módulo y `Archivo`
  tocan archivos.

  - `a_linea/1`: convierte un dato en una línea de texto.
  - `desde_linea/2`: convierte una línea de texto en un dato (`{:ok, dato}` o `{:error, :linea_invalida}`).
  - Si un archivo no existe, se empieza vacío. Si una línea está dañada, se avisa
    su número de línea por la salida de error y se ignora (el sistema sigue).
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  @archivo_usuarios "usuarios.csv"
  @archivo_zonas "zonas.txt"
  @archivo_centros "centros.csv"
  @archivo_necesidades "necesidades.csv"
  @archivo_recursos "recursos.csv"
  @archivo_movimientos "movimientos.csv"
  @archivo_personas "personas.csv"
  @archivo_historial "historial_personas.csv"
  @archivo_mensajes "mensajes.csv"
  @archivo_mascotas "mascotas.csv"
  @archivo_albergues "albergues.csv"
  @archivo_actividad "actividad.log"

  @encabezado_usuarios "# usuario;hash_contrasena;nombre_completo;tipo;zona;fecha_registro"
  @encabezado_zonas "# codigo;nombre;tipo;nivel;personas_afectadas;codigo_padre"
  @encabezado_centros "# codigo;nombre;tipo;zona"
  @encabezado_necesidades "# id;tipo;descripcion;requerida;asignada;zona;prioridad;responsable;estado;fecha;asignaciones"
  @encabezado_recursos "# codigo;nombre;categoria;cantidad;unidad;ubicacion"
  @encabezado_movimientos "# id;fecha;tipo;codigo_recurso;cantidad;origen;destino;usuario;referencia"
  @encabezado_personas "# id;documento;nombre;edad;zona;estado"
  @encabezado_historial "# documento;fecha;estado_anterior;estado_nuevo;usuario"
  @encabezado_mensajes "# id;fecha;remitente;destinatario;contenido;estado"
  @encabezado_mascotas "# id;tipo_reporte;especie;nombre;caracteristicas;color;tamano;zona;contacto;estado;coincidencia_con"
  @encabezado_albergues "# codigo;nombre;zona;capacidad;ocupantes"
  @encabezado_actividad "# fecha;usuario;comando;resultado"

  # ---------------------------------------------------------------
  # Carpeta de datos
  # ---------------------------------------------------------------

  @doc """
  Crea la carpeta de datos si no existe.
  """
  def preparar_directorio(directorio), do: Archivo.crear_carpeta(directorio)

  # ---------------------------------------------------------------
  # Guardar y cargar (una pareja de funciones por archivo)
  # ---------------------------------------------------------------

  @doc "Reescribe usuarios.csv con la lista de usuarios."
  def guardar_usuarios(usuarios, directorio), do: reescribir(directorio, @archivo_usuarios, @encabezado_usuarios, usuarios)
  @doc "Carga la lista de usuarios."
  def cargar_usuarios(directorio), do: cargar(directorio, @archivo_usuarios, :usuario)

  @doc "Reescribe zonas.txt. Recibe la lista plana `{nodo, codigo_padre}` (ver `ArbolZonas.aplanar/1`)."
  def guardar_zonas(entradas, directorio), do: reescribir(directorio, @archivo_zonas, @encabezado_zonas, entradas)
  @doc "Carga la lista plana `{nodo, codigo_padre}` (ver `ArbolZonas.construir/1`)."
  def cargar_zonas(directorio), do: cargar(directorio, @archivo_zonas, :zona)

  @doc "Reescribe centros.csv."
  def guardar_centros(centros, directorio), do: reescribir(directorio, @archivo_centros, @encabezado_centros, centros)
  @doc "Carga los centros de apoyo."
  def cargar_centros(directorio), do: cargar(directorio, @archivo_centros, :centro)

  @doc "Reescribe necesidades.csv."
  def guardar_necesidades(necesidades, directorio),
    do: reescribir(directorio, @archivo_necesidades, @encabezado_necesidades, necesidades)

  @doc "Carga las necesidades."
  def cargar_necesidades(directorio), do: cargar(directorio, @archivo_necesidades, :necesidad)

  @doc "Reescribe recursos.csv."
  def guardar_recursos(recursos, directorio), do: reescribir(directorio, @archivo_recursos, @encabezado_recursos, recursos)
  @doc "Carga los recursos."
  def cargar_recursos(directorio), do: cargar(directorio, @archivo_recursos, :recurso)

  @doc "Agrega UN movimiento al final de movimientos.csv (el historial nunca se reescribe)."
  def agregar_movimiento(movimiento, directorio),
    do: agregar(directorio, @archivo_movimientos, @encabezado_movimientos, movimiento)

  @doc "Carga el historial de movimientos."
  def cargar_movimientos(directorio), do: cargar(directorio, @archivo_movimientos, :movimiento)

  @doc "Reescribe personas.csv (sin el historial, que va en otro archivo)."
  def guardar_personas(personas, directorio), do: reescribir(directorio, @archivo_personas, @encabezado_personas, personas)
  @doc "Carga las personas (con historial vacío; el historial se carga aparte)."
  def cargar_personas(directorio), do: cargar(directorio, @archivo_personas, :persona)

  @doc "Agrega un cambio de estado de una persona: `{documento, {fecha, anterior, nuevo, usuario}}`."
  def agregar_historial(cambio, directorio), do: agregar(directorio, @archivo_historial, @encabezado_historial, cambio)
  @doc "Carga todos los cambios de estado como tuplas `{documento, {fecha, anterior, nuevo, usuario}}`."
  def cargar_historial(directorio), do: cargar(directorio, @archivo_historial, :historial)

  @doc "Reescribe mensajes.csv."
  def guardar_mensajes(mensajes, directorio), do: reescribir(directorio, @archivo_mensajes, @encabezado_mensajes, mensajes)
  @doc "Carga los mensajes."
  def cargar_mensajes(directorio), do: cargar(directorio, @archivo_mensajes, :mensaje)

  @doc "Reescribe mascotas.csv."
  def guardar_mascotas(mascotas, directorio), do: reescribir(directorio, @archivo_mascotas, @encabezado_mascotas, mascotas)
  @doc "Carga los reportes de mascotas."
  def cargar_mascotas(directorio), do: cargar(directorio, @archivo_mascotas, :mascota)

  @doc "Reescribe albergues.csv."
  def guardar_albergues(albergues, directorio), do: reescribir(directorio, @archivo_albergues, @encabezado_albergues, albergues)
  @doc "Carga los albergues."
  def cargar_albergues(directorio), do: cargar(directorio, @archivo_albergues, :albergue)

  @doc "Agrega una línea de actividad `{fecha, usuario, comando, resultado}` a actividad.log."
  def agregar_actividad(registro, directorio), do: agregar(directorio, @archivo_actividad, @encabezado_actividad, registro)
  @doc "Carga la actividad registrada."
  def cargar_actividad(directorio), do: cargar(directorio, @archivo_actividad, :actividad)

  # ---------------------------------------------------------------
  # Funciones genéricas (el CÓMO)
  # ---------------------------------------------------------------

  defp reescribir(directorio, archivo, encabezado, datos) do
    lineas = Enum.map(datos, &a_linea/1)

    directorio
    |> Path.join(archivo)
    |> Archivo.reescribir(encabezado, lineas)
  end

  defp agregar(directorio, archivo, encabezado, dato) do
    ruta = Path.join(directorio, archivo)

    ruta
    |> Archivo.existe?()
    |> asegurar_encabezado(ruta, encabezado)

    Archivo.agregar(ruta, a_linea(dato) <> "\n")
  end

  # Si el archivo todavía no existe, primero se escribe el encabezado.
  defp asegurar_encabezado(true, _ruta, _encabezado), do: :ok
  defp asegurar_encabezado(false, ruta, encabezado), do: Archivo.crear(ruta, encabezado <> "\n")

  defp cargar(directorio, archivo, tipo) do
    ruta = Path.join(directorio, archivo)

    ruta
    |> Archivo.existe?()
    |> cargar_si_existe(ruta, tipo)
  end

  defp cargar_si_existe(false, _ruta, _tipo), do: []

  defp cargar_si_existe(true, ruta, tipo) do
    # Carga perezosa, como en el parcial 2: cada línea útil se convierte con desde_linea.
    resultados =
      ruta
      |> Archivo.leer_lineas_utiles()
      |> Stream.map(fn {texto, numero} -> {desde_linea(tipo, texto), numero} end)
      |> Enum.to_list()

    resultados
    |> Enum.filter(&linea_con_error?/1)
    |> Enum.each(fn {_error, numero} -> reportar_linea_invalida(ruta, numero) end)

    resultados
    |> Enum.reject(&linea_con_error?/1)
    |> Enum.map(fn {{:ok, dato}, _numero} -> dato end)
  end

  defp linea_con_error?({{:ok, _dato}, _numero}), do: false
  defp linea_con_error?(_resultado), do: true

  defp reportar_linea_invalida(ruta, numero) do
    "Aviso: #{ruta}, línea #{numero} dañada; se ignora."
    |> Util2.mostrar(:error)
  end

  # ---------------------------------------------------------------
  # Formato: dato → línea
  # ---------------------------------------------------------------

  @doc """
  Convierte un dato en una línea de texto separada por `;`.
  """
  def a_linea(%Usuario{} = u),
    do: unir([u.usuario, u.hash_contrasena, u.nombre_completo, u.tipo, u.zona, u.fecha_registro])

  def a_linea({%NodoZona{} = n, codigo_padre}),
    do: unir([n.codigo, n.nombre, Atom.to_string(n.tipo), n.nivel, "#{n.personas_afectadas}", codigo_padre])

  def a_linea(%Centro{} = c), do: unir([c.codigo, c.nombre, c.tipo, c.zona])

  def a_linea(%Necesidad{} = n) do
    unir([
      n.id,
      n.tipo,
      n.descripcion,
      "#{n.cantidad_requerida}",
      "#{n.cantidad_asignada}",
      n.zona,
      n.prioridad,
      n.responsable,
      n.estado,
      n.fecha,
      asignaciones_a_texto(n.asignaciones)
    ])
  end

  def a_linea(%Recurso{} = r), do: unir([r.codigo, r.nombre, r.categoria, "#{r.cantidad}", r.unidad, r.ubicacion])

  def a_linea(%Movimiento{} = m) do
    unir([m.id, m.fecha, m.tipo, m.codigo_recurso, "#{m.cantidad}", m.origen, m.destino, m.usuario, m.referencia])
  end

  def a_linea(%Persona{} = p), do: unir([p.id, p.documento, p.nombre, "#{p.edad}", p.zona, p.estado])

  def a_linea({documento, {fecha, anterior, nuevo, usuario}}), do: unir([documento, fecha, anterior, nuevo, usuario])

  def a_linea(%Mensaje{} = m), do: unir([m.id, m.fecha, m.remitente, m.destinatario, m.contenido, m.estado])

  def a_linea(%Mascota{} = m) do
    unir([
      m.id,
      m.tipo_reporte,
      m.especie,
      m.nombre,
      m.caracteristicas,
      m.color,
      m.tamano,
      m.zona,
      m.contacto,
      m.estado,
      m.coincidencia_con
    ])
  end

  def a_linea(%Albergue{} = a) do
    ocupantes =
      a.ocupantes
      |> MapSet.to_list()
      |> Enum.sort()
      |> Enum.join("|")

    unir([a.codigo, a.nombre, a.zona, "#{a.capacidad}", ocupantes])
  end

  def a_linea({fecha, usuario, comando, resultado}), do: unir([fecha, usuario, comando, resultado])

  defp unir(campos) do
    campos
    |> Enum.map(&limpiar_campo/1)
    |> Enum.join(";")
  end

  # Defensa extra: un `;` o un salto de línea dentro de un campo dañaría el archivo.
  defp limpiar_campo(texto) do
    texto
    |> String.replace(";", ",")
    |> String.replace("\n", " ")
    |> String.replace("\r", " ")
  end

  # [{"R001", 30}, {"R002", 10}] → "R001:30|R002:10"
  defp asignaciones_a_texto(asignaciones) do
    asignaciones
    |> Enum.map(fn {codigo, cantidad} -> "#{codigo}:#{cantidad}" end)
    |> Enum.join("|")
  end

  # ---------------------------------------------------------------
  # Formato: línea → dato
  # ---------------------------------------------------------------

  @doc """
  Convierte una línea de texto en un dato del tipo indicado.

  ## Retorna
    - `{:ok, dato}` o `{:error, :linea_invalida}`
  """
  def desde_linea(tipo, texto) do
    texto
    |> String.split(";")
    |> convertir(tipo)
  end

  defp convertir([usuario, hash, nombre, tipo, zona, fecha], :usuario) do
    {:ok,
     %Usuario{usuario: usuario, hash_contrasena: hash, nombre_completo: nombre, tipo: tipo, zona: zona, fecha_registro: fecha}}
  end

  defp convertir([codigo, nombre, tipo, nivel, personas, codigo_padre], :zona) do
    construir_nodo(tipo_nodo(tipo), convertir_enteros([personas]), [codigo, nombre, nivel, codigo_padre])
  end

  defp convertir([codigo, nombre, tipo, zona], :centro), do: {:ok, Centro.crear(codigo, nombre, tipo, zona)}

  defp convertir([id, tipo, descripcion, requerida, asignada, zona, prioridad, responsable, estado, fecha, asignaciones], :necesidad) do
    construir_necesidad(
      convertir_enteros([requerida, asignada]),
      texto_a_asignaciones(asignaciones),
      [id, tipo, descripcion, zona, prioridad, responsable, estado, fecha]
    )
  end

  defp convertir([codigo, nombre, categoria, cantidad, unidad, ubicacion], :recurso) do
    [cantidad]
    |> convertir_enteros()
    |> construir_con_enteros(fn [numero] -> Recurso.crear(codigo, nombre, categoria, numero, unidad, ubicacion) end)
  end

  defp convertir([id, fecha, tipo, codigo, cantidad, origen, destino, usuario, referencia], :movimiento) do
    [cantidad]
    |> convertir_enteros()
    |> construir_con_enteros(fn [numero] ->
      Movimiento.crear(id, fecha, tipo, codigo, numero, origen, destino, usuario, referencia)
    end)
  end

  defp convertir([id, documento, nombre, edad, zona, estado], :persona) do
    [edad]
    |> convertir_enteros()
    |> construir_con_enteros(fn [numero] ->
      %Persona{id: id, documento: documento, nombre: nombre, edad: numero, zona: zona, estado: estado, historial: []}
    end)
  end

  defp convertir([documento, fecha, anterior, nuevo, usuario], :historial) do
    {:ok, {documento, {fecha, anterior, nuevo, usuario}}}
  end

  defp convertir([id, fecha, remitente, destinatario, contenido, estado], :mensaje) do
    {:ok, %Mensaje{id: id, fecha: fecha, remitente: remitente, destinatario: destinatario, contenido: contenido, estado: estado}}
  end

  defp convertir([id, tipo_reporte, especie, nombre, caracteristicas, color, tamano, zona, contacto, estado, coincidencia], :mascota) do
    mascota = Mascota.crear(id, tipo_reporte, especie, nombre, caracteristicas, color, tamano, zona, contacto)
    {:ok, %{mascota | estado: estado, coincidencia_con: coincidencia}}
  end

  defp convertir([codigo, nombre, zona, capacidad, ocupantes], :albergue) do
    [capacidad]
    |> convertir_enteros()
    |> construir_con_enteros(fn [numero] ->
      documentos = ocupantes |> String.split("|", trim: true) |> MapSet.new()
      %{Albergue.crear(codigo, nombre, zona, numero) | ocupantes: documentos}
    end)
  end

  defp convertir([fecha, usuario, comando, resultado], :actividad), do: {:ok, {fecha, usuario, comando, resultado}}

  # Cualquier otra cantidad de campos: la línea está dañada.
  defp convertir(_campos, _tipo), do: {:error, :linea_invalida}

  defp construir_con_enteros({:ok, numeros}, funcion), do: {:ok, funcion.(numeros)}
  defp construir_con_enteros(:error, _funcion), do: {:error, :linea_invalida}

  defp construir_nodo({:ok, tipo}, {:ok, [personas]}, [codigo, nombre, nivel, codigo_padre]) do
    {:ok, {NodoZona.crear(codigo, nombre, tipo, nivel, personas), codigo_padre}}
  end

  defp construir_nodo(_tipo, _enteros, _campos), do: {:error, :linea_invalida}

  defp construir_necesidad({:ok, [requerida, asignada]}, {:ok, asignaciones}, campos) do
    [id, tipo, descripcion, zona, prioridad, responsable, estado, fecha] = campos

    {:ok,
     %Necesidad{
       id: id,
       tipo: tipo,
       descripcion: descripcion,
       cantidad_requerida: requerida,
       cantidad_asignada: asignada,
       zona: zona,
       prioridad: prioridad,
       responsable: responsable,
       estado: estado,
       fecha: fecha,
       asignaciones: asignaciones
     }}
  end

  defp construir_necesidad(_enteros, _asignaciones, _campos), do: {:error, :linea_invalida}

  # Convierte "zona" / "sector" / "punto" en átomo sin usar String.to_atom.
  defp tipo_nodo("zona"), do: {:ok, :zona}
  defp tipo_nodo("sector"), do: {:ok, :sector}
  defp tipo_nodo("punto"), do: {:ok, :punto}
  defp tipo_nodo(_texto), do: :error

  # RECURSIVA: convierte una lista de textos en enteros.
  # Caso base: lista vacía. Caso recursivo: convierte el primero y luego el resto.
  defp convertir_enteros([]), do: {:ok, []}

  defp convertir_enteros([texto | resto]) do
    juntar_enteros(entero(texto), convertir_enteros(resto))
  end

  defp juntar_enteros({:ok, numero}, {:ok, numeros}), do: {:ok, [numero | numeros]}
  defp juntar_enteros(_primero, _resto), do: :error

  defp entero(texto) do
    try do
      {:ok, String.to_integer(texto)}
    rescue
      ArgumentError -> :error
    end
  end

  # "R001:30|R002:10" → {:ok, [{"R001", 30}, {"R002", 10}]}
  defp texto_a_asignaciones(texto) do
    texto
    |> String.split("|", trim: true)
    |> convertir_asignaciones([])
  end

  # RECURSIVA: convierte cada "codigo:cantidad" en tupla.
  defp convertir_asignaciones([], acumulado), do: {:ok, acumulado}

  defp convertir_asignaciones([parte | resto], acumulado) do
    parte
    |> String.split(":")
    |> asignacion_desde_partes()
    |> continuar_asignaciones(resto, acumulado)
  end

  defp asignacion_desde_partes([codigo, cantidad]) do
    cantidad
    |> entero()
    |> tupla_asignacion(codigo)
  end

  defp asignacion_desde_partes(_partes), do: :error

  defp tupla_asignacion({:ok, numero}, codigo), do: {:ok, {codigo, numero}}
  defp tupla_asignacion(:error, _codigo), do: :error

  defp continuar_asignaciones({:ok, asignacion}, resto, acumulado),
    do: convertir_asignaciones(resto, acumulado ++ [asignacion])

  defp continuar_asignaciones(:error, _resto, _acumulado), do: :error
end
