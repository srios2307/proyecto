defmodule Albergue do
  @moduledoc """
  Albergue temporal.
  - ocupantes: `MapSet` con los documentos de las personas que están adentro.

  MapSet (NO visto en clase, lo pide el enunciado) es un CONJUNTO: una colección
  sin elementos repetidos. Si se agrega dos veces el mismo documento, queda una
  sola vez; por eso la ocupación actual es simplemente `MapSet.size(ocupantes)`.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  defstruct codigo: "", nombre: "", zona: "", capacidad: 0, ocupantes: MapSet.new()

  @doc """
  Crea un albergue vacío.
  """
  def crear(codigo, nombre, zona, capacidad) do
    %Albergue{codigo: codigo, nombre: nombre, zona: zona, capacidad: capacidad, ocupantes: MapSet.new()}
  end

  @doc """
  Ocupación actual (cantidad de personas adentro).
  """
  def ocupacion(%Albergue{ocupantes: ocupantes}), do: MapSet.size(ocupantes)

  @doc """
  Cupos disponibles.
  """
  def cupos_disponibles(albergue), do: albergue.capacidad - ocupacion(albergue)

  @doc """
  Retorna true si ya no hay cupos.
  """
  def lleno?(albergue), do: cupos_disponibles(albergue) <= 0

  @doc """
  Retorna true si la persona (documento) está en el albergue.
  """
  def presente?(%Albergue{ocupantes: ocupantes}, documento), do: MapSet.member?(ocupantes, documento)

  @doc """
  Porcentaje de ocupación (entero de 0 a 100).
  """
  def porcentaje_ocupacion(%Albergue{capacidad: 0}), do: 0
  def porcentaje_ocupacion(albergue), do: round(ocupacion(albergue) * 100 / albergue.capacidad)

  @doc """
  Retorna un NUEVO albergue con el documento adentro.
  """
  def ingresar(albergue, documento), do: %{albergue | ocupantes: MapSet.put(albergue.ocupantes, documento)}

  @doc """
  Retorna un NUEVO albergue sin el documento.
  """
  def retirar(albergue, documento), do: %{albergue | ocupantes: MapSet.delete(albergue.ocupantes, documento)}

  defimpl String.Chars, for: Albergue do
    def to_string(a) do
      "#{a.codigo} - #{a.nombre} (zona #{a.zona}): #{Albergue.ocupacion(a)}/#{a.capacidad} ocupado " <>
        "(#{Albergue.porcentaje_ocupacion(a)}%), #{Albergue.cupos_disponibles(a)} cupos libres"
    end
  end
end
