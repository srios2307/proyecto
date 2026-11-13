defmodule Coincidencias do
  @moduledoc """
  Puntaje de similitud entre un reporte de mascota PERDIDA y uno ENCONTRADA.
  Funciones puras y recursivas (diagrama `3c_secuencia_mascotas.png`).

  Puntaje de 0 a 100:
    - misma zona: +30 (lo más probable es que el animal no se aleje mucho)
    - mismo color: +25 (se ve a simple vista, casi nunca se confunde)
    - mismo tamaño: +20 (útil, pero "mediano" o "grande" es subjetivo)
    - mismo nombre, solo si ambos lo conocen: +15 (el que encuentra casi nunca lo sabe)
    - características en común: +5 por palabra, máximo +10 (descripciones libres)
  Solo se comparan reportes de la MISMA especie y que no estén resueltos.
  Un par con puntaje >= 50 (`@umbral_coincidencia`) es una posible coincidencia.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  @umbral_coincidencia 50
  @puntos_zona 30
  @puntos_color 25
  @puntos_tamano 20
  @puntos_nombre 15
  @puntos_por_palabra 5
  @maximo_puntos_caracteristicas 10
  # Palabras que no describen al animal y no deben contar como "en común".
  @palabras_ignoradas ["de", "la", "el", "los", "las", "y", "con", "en", "un", "una", "muy"]

  @doc """
  Umbral mínimo para considerar una posible coincidencia.
  """
  def umbral(), do: @umbral_coincidencia

  @doc """
  Calcula el puntaje entre una mascota perdida y una encontrada.

  ## Ejemplo
  Perdida: perro "Luna" negra mediana zona_norte. Encontrada: perro desconocido negra
  mediana zona_norte → 30 + 25 + 20 + 0 + 0 = 75.
  """
  def calcular_puntaje(perdida, encontrada) do
    [
      puntos_si(iguales?(perdida.zona, encontrada.zona), @puntos_zona),
      puntos_si(iguales?(perdida.color, encontrada.color), @puntos_color),
      puntos_si(iguales?(perdida.tamano, encontrada.tamano), @puntos_tamano),
      puntos_si(mismo_nombre?(perdida, encontrada), @puntos_nombre),
      puntos_caracteristicas(perdida.caracteristicas, encontrada.caracteristicas)
    ]
    |> Enum.sum()
  end

  defp puntos_si(true, puntos), do: puntos
  defp puntos_si(false, _puntos), do: 0

  # Compara dos textos sin importar mayúsculas ni espacios en los extremos.
  defp iguales?(texto1, texto2), do: normalizar(texto1) == normalizar(texto2)

  defp normalizar(texto), do: texto |> String.trim() |> String.downcase()

  defp mismo_nombre?(perdida, encontrada) do
    Mascota.nombre_conocido?(perdida) and Mascota.nombre_conocido?(encontrada) and
      iguales?(perdida.nombre, encontrada.nombre)
  end

  defp puntos_caracteristicas(texto1, texto2) do
    texto1
    |> palabras()
    |> palabras_en_comun(palabras(texto2))
    |> Kernel.*(@puntos_por_palabra)
    |> min(@maximo_puntos_caracteristicas)
  end

  @doc """
  Convierte un texto en una lista de palabras en minúscula, sin repetidas y sin
  palabras vacías como "de" o "la".
  """
  def palabras(texto) do
    texto
    |> String.downcase()
    |> String.replace(",", " ")
    |> String.replace(".", " ")
    |> String.split()
    |> Enum.reject(fn palabra -> Enum.member?(@palabras_ignoradas, palabra) end)
    |> MapSet.new()
    |> MapSet.to_list()
  end

  @doc """
  Cuenta cuántas palabras de `lista1` también están en `lista2`.

  ## Ejemplo
      palabras_en_comun(["collar", "rojo", "cojea"], ["rojo", "collar"])  # 2
  """
  # RECURSIVA: palabras_en_comun
  # Caso base: lista1 vacía → 0. Caso recursivo: 1 si la primera está en lista2, + el resto.
  def palabras_en_comun([], _lista2), do: 0

  def palabras_en_comun([palabra | resto], lista2) do
    contar_si(Enum.member?(lista2, palabra)) + palabras_en_comun(resto, lista2)
  end

  defp contar_si(true), do: 1
  defp contar_si(false), do: 0

  @doc """
  Retorna true si las dos mascotas se pueden comparar: misma especie y ninguna resuelta.
  """
  def comparables?(perdida, encontrada) do
    iguales?(perdida.especie, encontrada.especie) and perdida.estado != "resuelta" and
      encontrada.estado != "resuelta"
  end

  @doc """
  Recorre TODOS los pares perdida–encontrada y retorna los que superan el umbral,
  ordenados de mayor a menor puntaje.

  ## Retorna
    - lista de tuplas `{perdida, encontrada, puntaje}`
  """
  def pares_candidatos(perdidas, encontradas) do
    perdidas
    |> recorrer_perdidas(encontradas, [])
    |> Enum.sort_by(fn {_perdida, _encontrada, puntaje} -> puntaje end, :desc)
  end

  # RECURSIVA: recorre la lista de perdidas (caso base: no quedan perdidas).
  defp recorrer_perdidas([], _encontradas, acumulado), do: acumulado

  defp recorrer_perdidas([perdida | resto], encontradas, acumulado) do
    recorrer_perdidas(resto, encontradas, comparar_con(perdida, encontradas, acumulado))
  end

  # RECURSIVA: compara UNA perdida con cada encontrada (caso base: no quedan encontradas).
  defp comparar_con(_perdida, [], acumulado), do: acumulado

  defp comparar_con(perdida, [encontrada | resto], acumulado) do
    comparar_con(perdida, resto, agregar_si_supera(perdida, encontrada, acumulado))
  end

  defp agregar_si_supera(perdida, encontrada, acumulado) do
    puntaje_si_comparable(comparables?(perdida, encontrada), perdida, encontrada)
    |> agregar_par(perdida, encontrada, acumulado)
  end

  defp puntaje_si_comparable(true, perdida, encontrada), do: calcular_puntaje(perdida, encontrada)
  defp puntaje_si_comparable(false, _perdida, _encontrada), do: 0

  defp agregar_par(puntaje, perdida, encontrada, acumulado) when puntaje >= @umbral_coincidencia do
    acumulado ++ [{perdida, encontrada, puntaje}]
  end

  defp agregar_par(_puntaje, _perdida, _encontrada, acumulado), do: acumulado
end
