defmodule Transiciones do
  @moduledoc """
  Reglas de cambio de estado (diagrama `6_estados.png`). Funciones puras.

  Cada entidad tiene un mapa `estado_actual => [estados a los que puede pasar]`.
  Un estado con lista vacía es FINAL: ya no puede cambiar.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  @transiciones %{
    necesidad: %{
      "pendiente" => ["asignada", "cancelada"],
      "asignada" => ["en_atencion", "cancelada"],
      "en_atencion" => ["atendida"],
      "atendida" => [],
      "cancelada" => []
    },
    persona: %{
      "sin_informacion" => ["reportada", "localizada"],
      "reportada" => ["localizada", "trasladada", "en_albergue"],
      "localizada" => ["trasladada", "en_albergue", "reunificada"],
      "trasladada" => ["en_albergue", "reunificada"],
      "en_albergue" => ["trasladada", "reunificada"],
      "reunificada" => []
    },
    mascota: %{
      "activa" => ["posible_coincidencia", "resuelta"],
      "posible_coincidencia" => ["activa", "resuelta"],
      "resuelta" => []
    },
    mensaje: %{
      "pendiente" => ["entregado"],
      "entregado" => ["pendiente"]
    }
  }

  @doc """
  Lista de estados posibles de una entidad (:necesidad, :persona, :mascota o :mensaje).
  """
  def estados(entidad) do
    @transiciones
    |> Map.get(entidad, %{})
    |> Map.keys()
  end

  @doc """
  Retorna true si `estado` existe para la entidad.
  """
  def estado_valido?(entidad, estado) do
    entidad
    |> estados()
    |> Enum.member?(estado)
  end

  @doc """
  Retorna true si la entidad puede pasar de `desde` a `hacia`.

  ## Ejemplo
      Transiciones.transicion_valida?(:necesidad, "pendiente", "asignada")  # true
      Transiciones.transicion_valida?(:necesidad, "atendida", "pendiente")  # false
  """
  def transicion_valida?(entidad, desde, hacia) do
    @transiciones
    |> Map.get(entidad, %{})
    |> Map.get(desde, [])
    |> Enum.member?(hacia)
  end

  @doc """
  Retorna true si `estado` es final (no tiene salidas).
  """
  def estado_final?(entidad, estado) do
    estado_valido?(entidad, estado) and siguientes(entidad, estado) == []
  end

  @doc """
  Estados a los que se puede pasar desde `estado`.
  """
  def siguientes(entidad, estado) do
    @transiciones
    |> Map.get(entidad, %{})
    |> Map.get(estado, [])
  end

  @doc """
  Valida un cambio de estado.

  ## Retorna
    - `:ok` si se permite
    - `{:error, {:estado_invalido, hacia}}` si el estado destino no existe
    - `{:error, :ya_cerrada}` (necesidad), `{:error, :ya_resuelta}` (mascota) o
      `{:error, :ya_reunificada}` (persona) si el estado actual es final
    - `{:error, {:transicion_invalida, desde, hacia}}` en cualquier otro caso
  """
  def validar(entidad, desde, hacia) do
    cond do
      not estado_valido?(entidad, hacia) -> {:error, {:estado_invalido, hacia}}
      estado_final?(entidad, desde) -> {:error, error_de_cierre(entidad)}
      transicion_valida?(entidad, desde, hacia) -> :ok
      true -> {:error, {:transicion_invalida, desde, hacia}}
    end
  end

  # Error que se retorna cuando se intenta cambiar un estado final ("cerrar dos veces").
  defp error_de_cierre(:necesidad), do: :ya_cerrada
  defp error_de_cierre(:mascota), do: :ya_resuelta
  defp error_de_cierre(:persona), do: :ya_reunificada
  defp error_de_cierre(_entidad), do: :estado_final
end
