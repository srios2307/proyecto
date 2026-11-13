defmodule Archivo do
  @moduledoc """
  Módulo de bajo nivel para leer y escribir archivos de texto plano.
  Es el mismo módulo `Archivo` del parcial 2 (reconocimiento de patrones),
  con una función nueva: `reescribir/3`.

  Junto con `Persistencia`, es el ÚNICO lugar del proyecto que toca archivos.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  @doc """
  Indica si existe un archivo.

  ## Parámetro
    - ruta: ruta del archivo

  ## Retorna
    - true si existe, false si no
  """
  def existe?(ruta), do: File.exists?(ruta)

  @doc """
  Retorna un Stream perezoso con las líneas útiles de un archivo.
  Una línea útil no está vacía y no empieza por `#` (los encabezados empiezan por `#`).

  ## Parámetro
    - ruta: ruta del archivo de entrada

  ## Retorna
    - Stream de tuplas `{texto_limpio, numero_linea}`, con la línea física desde 1
  """
  def leer_lineas_utiles(ruta) do
    # Stream.with_index(1) le pega a cada línea su número ANTES de quitar
    # comentarios, así el número que queda es la línea física del archivo.
    # String.trim también elimina el \r de los archivos de Windows.
    ruta
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.map(fn {linea, numero} -> {String.trim(linea), numero} end)
    |> Stream.reject(fn {texto, _numero} -> linea_ignorable?(texto) end)
  end

  # Recibe un texto ya limpio y retorna true si es una línea vacía o un comentario.
  defp linea_ignorable?(""), do: true
  defp linea_ignorable?(texto), do: String.starts_with?(texto, "#")

  @doc """
  Crea la carpeta indicada, con sus carpetas padre, si todavía no existe.
  """
  def crear_carpeta(ruta), do: File.mkdir_p!(ruta)

  @doc """
  Crea el archivo o lo reemplaza si ya existe, dejando en él solo el texto dado.
  Retorna `:ok` o `{:error, razon}` (Guía 11).
  """
  def crear(ruta, texto), do: File.write(ruta, texto)

  @doc """
  Agrega un texto al final de un archivo (si no existe, lo crea).
  """
  def agregar(ruta, texto), do: File.write(ruta, texto, [:append])

  @doc """
  Agrega varias líneas al final de un archivo, una por una.
  Cada línea viaja por el Stream y se escribe por separado (escritura progresiva).

  ## Parámetros
    - ruta: ruta del archivo de salida
    - lineas: colección de textos, sin salto de línea al final
  """
  def agregar_lineas(ruta, lineas) do
    lineas
    |> Stream.map(&(&1 <> "\n"))
    |> Enum.into(File.stream!(ruta, [:append]))

    :ok
  end

  @doc """
  Reemplaza todo el contenido de un archivo: primero lo crea solo con el
  encabezado y luego agrega las líneas una por una.

  ## Parámetros
    - ruta: ruta del archivo
    - encabezado: primera línea (empieza por `#` para que al leer se ignore)
    - lineas: lista de textos sin salto de línea
  """
  def reescribir(ruta, encabezado, lineas) do
    ruta
    |> crear(encabezado <> "\n")

    ruta
    |> agregar_lineas(lineas)
  end
end
