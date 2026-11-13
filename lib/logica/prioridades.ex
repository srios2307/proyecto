defmodule Prioridades do
  @moduledoc """
  La prioridad de una necesidad NO es solo informativa: se usa para ORDENAR las
  necesidades (list_needs, pending_needs) y para SELECCIONAR la siguiente a atender
  (next_need). Funciones puras y recursivas.

  Orden: primero la prioridad más alta; si empatan, la más antigua (fecha menor);
  si también empatan, el id menor.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  @prioridades %{"critica" => 4, "alta" => 3, "media" => 2, "baja" => 1}
  @lista_prioridades ["critica", "alta", "media", "baja"]

  @doc """
  Prioridades válidas, de la más alta a la más baja.
  """
  def prioridades(), do: @lista_prioridades

  @doc """
  Valor numérico de una prioridad (critica = 4 ... baja = 1, desconocida = 0).
  """
  def valor(prioridad), do: Map.get(@prioridades, prioridad, 0)

  @doc """
  Retorna true si la necesidad `a` debe atenderse antes que `b`.
  """
  def antes?(a, b) do
    cond do
      valor(a.prioridad) > valor(b.prioridad) -> true
      valor(a.prioridad) < valor(b.prioridad) -> false
      a.fecha < b.fecha -> true
      a.fecha > b.fecha -> false
      true -> a.id <= b.id
    end
  end

  @doc """
  Inserta una necesidad en una lista YA ordenada, en la posición correcta.

  ## Ejemplo
      insertar_ordenado(media, [critica, baja])  # [critica, media, baja]
  """
  # RECURSIVA: insertar_ordenado
  # Caso base: lista vacía → la necesidad queda sola.
  def insertar_ordenado(necesidad, []), do: [necesidad]

  # Caso recursivo: si va antes que la primera, se pone adelante; si no, se inserta en el resto.
  def insertar_ordenado(necesidad, [primera | resto]) do
    necesidad
    |> antes?(primera)
    |> insertar_segun(necesidad, primera, resto)
  end

  defp insertar_segun(true, necesidad, primera, resto), do: [necesidad, primera | resto]
  defp insertar_segun(false, necesidad, primera, resto), do: [primera | insertar_ordenado(necesidad, resto)]

  @doc """
  Ordena una lista de necesidades por prioridad (ordenamiento por inserción propio).
  """
  # RECURSIVA: ordenar
  # Caso base: lista vacía. Caso recursivo: se ordena el resto y se inserta la primera.
  def ordenar([]), do: []
  def ordenar([primera | resto]), do: insertar_ordenado(primera, ordenar(resto))

  @doc """
  Selecciona la necesidad que debe atenderse primero.

  ## Retorna
    - `{:ok, necesidad}` o `{:error, :sin_pendientes}` si la lista está vacía
  """
  # RECURSIVA: seleccionar_mayor
  # Casos base: lista vacía o de un elemento.
  # Caso recursivo: compara las dos primeras y sigue con la mejor y el resto.
  def seleccionar_mayor([]), do: {:error, :sin_pendientes}
  def seleccionar_mayor([unica]), do: {:ok, unica}

  def seleccionar_mayor([a, b | resto]) do
    seleccionar_mayor([mejor(antes?(a, b), a, b) | resto])
  end

  defp mejor(true, a, _b), do: a
  defp mejor(false, _a, b), do: b
end
