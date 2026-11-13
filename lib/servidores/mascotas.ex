defmodule Mascotas do
  @moduledoc """
  GenServer de los reportes de mascotas perdidas y encontradas
  (diagrama `3c_secuencia_mascotas.png`).

  - `buscar_coincidencias/0` usa las funciones puras de `Coincidencias`.
  - `confirmar_coincidencia/3` cierra los DOS reportes dentro de un solo `handle_call`:
    si dos coordinadores confirman al mismo tiempo, el segundo recibe
    `{:error, :ya_resuelta}` y no se modifica nada (un reporte no se resuelve dos veces).

  Estado: `%{directorio, mascotas: %{id => %Mascota{}}, siguiente: n}`
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
  Registra un reporte ("perdida" o "encontrada"). Retorna `{:ok, mascota}`.
  """
  def reportar(tipo_reporte, especie, nombre, color, tamano, zona, contacto, caracteristicas \\ "") do
    GenServer.call(__MODULE__, {:reportar, tipo_reporte, especie, nombre, color, tamano, zona, contacto, caracteristicas})
  end

  @doc "Reportes que cumplen los filtros (especie, zona, estado, tipo)."
  def listar(filtros \\ %{}), do: GenServer.call(__MODULE__, {:listar, filtros})

  @doc "`{:ok, mascota}` o `{:error, {:mascota_no_encontrada, id}}`."
  def obtener(id), do: GenServer.call(__MODULE__, {:obtener, id})

  @doc """
  Calcula las posibles coincidencias (puntaje >= 50), pasa los reportes a
  "posible_coincidencia" y retorna `{:ok, [{id_perdida, id_encontrada, puntaje}, ...]}`.
  """
  def buscar_coincidencias(), do: GenServer.call(__MODULE__, :buscar_coincidencias)

  @doc """
  Confirma la coincidencia y cierra ambos reportes.
  Retorna `{:ok, perdida, encontrada}` o `{:error, :ya_resuelta}` (sin modificar nada).
  """
  def confirmar_coincidencia(id_perdida, id_encontrada, usuario \\ "sistema") do
    GenServer.call(__MODULE__, {:confirmar, id_perdida, id_encontrada, usuario})
  end

  @doc """
  Descarta una posible coincidencia: ambos reportes vuelven a "activa".
  Retorna `{:ok, perdida, encontrada}` o `{:error, motivo}`.
  """
  def descartar_coincidencia(id_perdida, id_encontrada) do
    GenServer.call(__MODULE__, {:descartar, id_perdida, id_encontrada})
  end

  # ---------------------------------------------------------------
  # Servidor
  # ---------------------------------------------------------------

  @doc false
  def init(directorio) do
    lista = Persistencia.cargar_mascotas(directorio)
    mascotas = lista |> Enum.map(fn m -> {m.id, m} end) |> Enum.into(%{})
    {:ok, %{directorio: directorio, mascotas: mascotas, siguiente: lista |> Enum.map(& &1.id) |> Validaciones.siguiente_numero("MA")}}
  end

  @doc false
  def handle_call({:reportar, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas}, _de, estado) do
    datos = {
      Validaciones.normalizar(tipo),
      Validaciones.normalizar(especie),
      nombre,
      Validaciones.normalizar(color),
      Validaciones.normalizar(tamano),
      zona,
      contacto,
      caracteristicas
    }

    {tipo, especie, _nombre, color, tamano, _zona, _contacto, _caracteristicas} = datos

    [
      Validaciones.validar_opcion(tipo, Validaciones.tipos_reporte_mascota(), :tipo_reporte),
      Validaciones.validar_texto(especie, :especie),
      Validaciones.validar_texto(nombre, :nombre),
      Validaciones.validar_texto(color, :color),
      Validaciones.validar_texto(tamano, :tamano),
      Validaciones.validar_texto(zona, :zona),
      Validaciones.validar_texto(contacto, :contacto),
      Validaciones.validar_texto_opcional(caracteristicas, :caracteristicas)
    ]
    |> Validaciones.primer_error()
    |> reportar_si_valido(datos, estado)
  end

  def handle_call({:listar, filtros}, _de, estado) do
    lista =
      estado.mascotas
      |> Map.values()
      |> Enum.filter(fn mascota -> cumple_filtros?(mascota, filtros) end)
      |> Enum.sort_by(& &1.id)

    {:reply, lista, estado}
  end

  def handle_call({:obtener, id}, _de, estado) do
    {:reply, estado.mascotas |> Map.get(id) |> resultado_busqueda(id), estado}
  end

  def handle_call(:buscar_coincidencias, _de, estado) do
    todas = estado.mascotas |> Map.values() |> Enum.sort_by(& &1.id)
    perdidas = Enum.filter(todas, fn m -> m.tipo_reporte == "perdida" end)
    encontradas = Enum.filter(todas, fn m -> m.tipo_reporte == "encontrada" end)

    pares = Coincidencias.pares_candidatos(perdidas, encontradas)

    # Ambos reportes de cada par pasan a "posible_coincidencia" (si estaban activos).
    mascotas = marcar_posibles(pares, estado.mascotas)
    nuevo_estado = %{estado | mascotas: mascotas}
    guardar(nuevo_estado)

    respuesta = Enum.map(pares, fn {perdida, encontrada, puntaje} -> {perdida.id, encontrada.id, puntaje} end)
    {:reply, {:ok, respuesta}, nuevo_estado}
  end

  def handle_call({:confirmar, id_perdida, id_encontrada, _usuario}, _de, estado) do
    perdida = Map.get(estado.mascotas, id_perdida)
    encontrada = Map.get(estado.mascotas, id_encontrada)

    perdida
    |> validar_par(encontrada, id_perdida, id_encontrada)
    |> validar_cambio(perdida, encontrada, "resuelta")
    |> confirmar_si_valido(perdida, encontrada, estado)
  end

  def handle_call({:descartar, id_perdida, id_encontrada}, _de, estado) do
    perdida = Map.get(estado.mascotas, id_perdida)
    encontrada = Map.get(estado.mascotas, id_encontrada)

    perdida
    |> validar_par(encontrada, id_perdida, id_encontrada)
    |> validar_cambio(perdida, encontrada, "activa")
    |> descartar_si_valido(perdida, encontrada, estado)
  end

  # ---------------------------------------------------------------
  # Funciones privadas
  # ---------------------------------------------------------------

  defp reportar_si_valido(:ok, {tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas}, estado) do
    id = Validaciones.generar_id("MA", estado.siguiente)
    mascota = Mascota.crear(id, tipo, especie, nombre, caracteristicas, color, tamano, zona, contacto)
    nuevo_estado = %{estado | mascotas: Map.put(estado.mascotas, id, mascota), siguiente: estado.siguiente + 1}
    guardar(nuevo_estado)
    {:reply, {:ok, mascota}, nuevo_estado}
  end

  defp reportar_si_valido(error, _datos, estado), do: {:reply, error, estado}

  # RECURSIVA: marca cada par como posible coincidencia (caso base: no quedan pares).
  defp marcar_posibles([], mascotas), do: mascotas

  defp marcar_posibles([{perdida, encontrada, _puntaje} | resto], mascotas) do
    mascotas = mascotas |> marcar_posible(perdida.id) |> marcar_posible(encontrada.id)
    marcar_posibles(resto, mascotas)
  end

  # Solo un reporte "activa" pasa a "posible_coincidencia" (transición válida del diagrama).
  defp marcar_posible(mascotas, id) do
    mascota = Map.get(mascotas, id)

    :mascota
    |> Transiciones.validar(mascota.estado, "posible_coincidencia")
    |> poner_posible(mascota, mascotas)
  end

  defp poner_posible(:ok, mascota, mascotas), do: Map.put(mascotas, mascota.id, %{mascota | estado: "posible_coincidencia"})
  defp poner_posible(_error, _mascota, mascotas), do: mascotas

  # Validaciones comunes de un par (existen, tipos correctos y misma especie).
  defp validar_par(nil, _encontrada, id_perdida, _id_encontrada), do: {:error, {:mascota_no_encontrada, id_perdida}}
  defp validar_par(_perdida, nil, _id_perdida, id_encontrada), do: {:error, {:mascota_no_encontrada, id_encontrada}}

  defp validar_par(%Mascota{tipo_reporte: "perdida"} = perdida, %Mascota{tipo_reporte: "encontrada"} = encontrada, _, _) do
    misma_especie(perdida.especie == encontrada.especie)
  end

  defp validar_par(_perdida, _encontrada, _id_perdida, _id_encontrada), do: {:error, :tipos_de_reporte_invalidos}

  defp misma_especie(true), do: :ok
  defp misma_especie(false), do: {:error, :especies_distintas}

  # Transiciones decide si AMBOS reportes pueden pasar al estado nuevo.
  # Si alguno ya está "resuelta" (estado final) retorna {:error, :ya_resuelta}.
  defp validar_cambio(:ok, perdida, encontrada, estado_nuevo) do
    [
      Transiciones.validar(:mascota, perdida.estado, estado_nuevo),
      Transiciones.validar(:mascota, encontrada.estado, estado_nuevo)
    ]
    |> Validaciones.primer_error()
  end

  defp validar_cambio(error, _perdida, _encontrada, _estado_nuevo), do: error

  defp confirmar_si_valido(:ok, perdida, encontrada, estado) do
    perdida_resuelta = %{perdida | estado: "resuelta", coincidencia_con: encontrada.id}
    encontrada_resuelta = %{encontrada | estado: "resuelta", coincidencia_con: perdida.id}

    mascotas =
      estado.mascotas
      |> Map.put(perdida.id, perdida_resuelta)
      |> Map.put(encontrada.id, encontrada_resuelta)

    nuevo_estado = %{estado | mascotas: mascotas}
    guardar(nuevo_estado)
    {:reply, {:ok, perdida_resuelta, encontrada_resuelta}, nuevo_estado}
  end

  defp confirmar_si_valido(error, _perdida, _encontrada, estado), do: {:reply, error, estado}

  defp descartar_si_valido(:ok, perdida, encontrada, estado) do
    perdida_activa = %{perdida | estado: "activa"}
    encontrada_activa = %{encontrada | estado: "activa"}

    mascotas =
      estado.mascotas
      |> Map.put(perdida.id, perdida_activa)
      |> Map.put(encontrada.id, encontrada_activa)

    nuevo_estado = %{estado | mascotas: mascotas}
    guardar(nuevo_estado)
    {:reply, {:ok, perdida_activa, encontrada_activa}, nuevo_estado}
  end

  defp descartar_si_valido(error, _perdida, _encontrada, estado), do: {:reply, error, estado}

  defp resultado_busqueda(nil, id), do: {:error, {:mascota_no_encontrada, id}}
  defp resultado_busqueda(mascota, _id), do: {:ok, mascota}

  defp cumple_filtros?(mascota, filtros) do
    Validaciones.cumple_filtros?(filtros, fn clave, valor -> cumple_filtro?(clave, valor, mascota) end)
  end

  defp cumple_filtro?("especie", valor, mascota), do: mascota.especie == Validaciones.normalizar(valor)
  defp cumple_filtro?("zona", valor, mascota), do: mascota.zona == valor
  defp cumple_filtro?("estado", valor, mascota), do: mascota.estado == Validaciones.normalizar(valor)
  defp cumple_filtro?("tipo", valor, mascota), do: mascota.tipo_reporte == Validaciones.normalizar(valor)
  defp cumple_filtro?(_clave, _valor, _mascota), do: false

  defp guardar(estado) do
    estado.mascotas
    |> Map.values()
    |> Enum.sort_by(& &1.id)
    |> Persistencia.guardar_mascotas(estado.directorio)
  end
end
