defmodule Validaciones do
  @moduledoc """
  Validaciones de las entradas del usuario y formato de identificadores y fechas.
  Funciones puras (salvo `fecha_actual/0`, que lee el reloj).

  Todas retornan `:ok` o `{:error, motivo}`: nunca lanzan errores en situaciones
  esperadas. Para revisar varias validaciones juntas se usa `primer_error/1`.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  @tipos_usuario ["ciudadano", "voluntario", "coordinador", "administrador"]
  @niveles_afectacion ["critico", "alto", "medio", "bajo"]
  @tipos_necesidad ["agua", "alimentos", "medicamentos", "primeros_auxilios", "refugio", "transporte", "rescate", "otra"]
  @tipos_centro ["centro_acopio", "albergue", "punto_atencion"]
  @tipos_reporte_mascota ["perdida", "encontrada"]
  # Caracteres que rompen el formato de los archivos (separadores y saltos de línea).
  @caracteres_prohibidos [";", "|", "\n", "\r", "\r\n"]

  def tipos_usuario(), do: @tipos_usuario
  def niveles_afectacion(), do: @niveles_afectacion
  def tipos_necesidad(), do: @tipos_necesidad
  def tipos_centro(), do: @tipos_centro
  def tipos_reporte_mascota(), do: @tipos_reporte_mascota

  @doc """
  Valida un texto escrito por el usuario: no puede estar vacío ni tener `;`, `|` o saltos de línea.

  ## Retorna
    - `:ok`, `{:error, {:campo_vacio, campo}}` o `{:error, {:caracter_no_permitido, campo}}`
  """
  def validar_texto(texto, campo) when is_binary(texto) do
    cond do
      String.trim(texto) == "" -> {:error, {:campo_vacio, campo}}
      texto |> String.graphemes() |> contiene_prohibido?() -> {:error, {:caracter_no_permitido, campo}}
      true -> :ok
    end
  end

  def validar_texto(_texto, campo), do: {:error, {:campo_vacio, campo}}

  @doc """
  Igual que `validar_texto/2` pero acepta el texto vacío (campos opcionales).
  """
  def validar_texto_opcional("", _campo), do: :ok
  def validar_texto_opcional(texto, campo), do: validar_texto(texto, campo)

  # RECURSIVA: revisa carácter por carácter si hay alguno prohibido.
  # Caso base: lista vacía → no hay prohibidos.
  # Caso recursivo: si el primero es prohibido → true; si no, revisa el resto.
  defp contiene_prohibido?([]), do: false
  defp contiene_prohibido?([caracter | _resto]) when caracter in @caracteres_prohibidos, do: true
  defp contiene_prohibido?([_caracter | resto]), do: contiene_prohibido?(resto)

  @doc """
  Valida que una cantidad sea un entero mayor o igual a cero.
  """
  def validar_no_negativo(numero, _campo) when is_integer(numero) and numero >= 0, do: :ok
  def validar_no_negativo(_numero, campo), do: {:error, {:cantidad_negativa, campo}}

  @doc """
  Valida que una cantidad sea un entero mayor que cero.
  """
  def validar_positivo(numero, _campo) when is_integer(numero) and numero > 0, do: :ok
  def validar_positivo(_numero, campo), do: {:error, {:cantidad_invalida, campo}}

  @doc """
  Valida que `valor` sea una de las `opciones`.
  """
  def validar_opcion(valor, opciones, campo) do
    opciones
    |> Enum.member?(valor)
    |> resultado_opcion(valor, campo)
  end

  defp resultado_opcion(true, _valor, _campo), do: :ok
  defp resultado_opcion(false, valor, campo), do: {:error, {:opcion_invalida, campo, valor}}

  @doc """
  Valida que una clave (id o código) NO exista todavía en el mapa.
  """
  def validar_no_repetido(mapa, clave) do
    mapa
    |> Map.has_key?(clave)
    |> resultado_repetido(clave)
  end

  defp resultado_repetido(true, clave), do: {:error, {:id_repetido, clave}}
  defp resultado_repetido(false, _clave), do: :ok

  @doc """
  Convierte un texto a entero sin lanzar errores.

  ## Retorna
    - `{:ok, numero}` o `{:error, {:numero_invalido, texto}}`
  """
  def convertir_entero(texto) when is_integer(texto), do: {:ok, texto}

  def convertir_entero(texto) do
    try do
      {:ok, texto |> String.trim() |> String.to_integer()}
    rescue
      ArgumentError -> {:error, {:numero_invalido, texto}}
    end
  end

  @doc """
  Recibe una lista de resultados de validación y retorna el primer error, o `:ok`
  si todas pasaron. Reemplaza a `with` (no visto en clase).

  ## Ejemplo
      [:ok, {:error, :x}, :ok] |> Validaciones.primer_error()  # {:error, :x}
  """
  # RECURSIVA: caso base lista vacía → :ok; caso recursivo: si es :ok sigue con el resto,
  # si no, ese es el error.
  def primer_error([]), do: :ok
  def primer_error([:ok | resto]), do: primer_error(resto)
  def primer_error([error | _resto]), do: error

  @doc """
  Retorna true si un dato cumple TODOS los filtros de una consulta (`zona=centro estado=pendiente`).
  `condicion.(clave, valor)` dice si el dato cumple UN filtro.
  """
  def cumple_filtros?(filtros, condicion) do
    filtros
    |> Enum.to_list()
    |> cumple_todos?(condicion)
  end

  # RECURSIVA: caso base sin filtros → cumple; caso recursivo: cumple el primero Y el resto.
  defp cumple_todos?([], _condicion), do: true

  defp cumple_todos?([{clave, valor} | resto], condicion) do
    condicion.(clave, valor) and cumple_todos?(resto, condicion)
  end

  @doc """
  Arma un identificador con prefijo y ceros a la izquierda.

  ## Ejemplo
      Validaciones.generar_id("N", 7)       # "N007"
      Validaciones.generar_id("MV", 12, 4)  # "MV0012"
  """
  def generar_id(prefijo, numero, digitos \\ 3) do
    prefijo <> rellenar_con_ceros("#{numero}", digitos)
  end

  # RECURSIVA: agrega un "0" a la izquierda hasta tener los dígitos pedidos.
  # Caso base: el texto ya tiene suficientes dígitos.
  defp rellenar_con_ceros(texto, digitos) do
    texto
    |> String.graphemes()
    |> length()
    |> Kernel.>=(digitos)
    |> completar_ceros(texto, digitos)
  end

  defp completar_ceros(true, texto, _digitos), do: texto
  defp completar_ceros(false, texto, digitos), do: rellenar_con_ceros("0" <> texto, digitos)

  @doc """
  Obtiene el número de un identificador ("N012" con prefijo "N" → 12). Si no se puede, retorna 0.
  """
  def numero_de_id(id, prefijo) do
    id
    |> String.replace(prefijo, "")
    |> convertir_entero()
    |> numero_o_cero()
  end

  defp numero_o_cero({:ok, numero}), do: numero
  defp numero_o_cero(_error), do: 0

  @doc """
  Calcula el siguiente número de id a partir de los ids existentes (el mayor + 1).
  Se usa al cargar los archivos para que los ids no se repitan.
  """
  def siguiente_numero(ids, prefijo) do
    numeros = Enum.map(ids, &numero_de_id(&1, prefijo))

    ([0] ++ numeros)
    |> Enum.max()
    |> Kernel.+(1)
  end

  @doc """
  Fecha y hora actual de Colombia (UTC-5) como texto (Guía 11).
  """
  def fecha_actual() do
    DateTime.utc_now()
    |> DateTime.add(-5 * 60 * 60, :second)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end

  @doc """
  Normaliza un texto de opción: sin espacios en los extremos y en minúscula.
  """
  def normalizar(texto) when is_binary(texto), do: texto |> String.trim() |> String.downcase()
  def normalizar(otro), do: otro
end
