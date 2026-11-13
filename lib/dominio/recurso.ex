defmodule Recurso do
  @moduledoc """
  Recurso del inventario (agua, alimentos, medicamentos...).
  - categoria: usa los mismos tipos de las necesidades, así se pueden asignar por categoría
  - ubicacion: código del centro de apoyo donde está
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  defstruct codigo: "", nombre: "", categoria: "", cantidad: 0, unidad: "", ubicacion: ""

  @doc """
  Crea un recurso.
  """
  def crear(codigo, nombre, categoria, cantidad, unidad, ubicacion) do
    %Recurso{
      codigo: codigo,
      nombre: nombre,
      categoria: categoria,
      cantidad: cantidad,
      unidad: unidad,
      ubicacion: ubicacion
    }
  end

  @doc """
  Retorna true si hay al menos `cantidad` unidades disponibles.
  """
  def alcanza?(%Recurso{cantidad: disponible}, cantidad), do: disponible >= cantidad

  @doc """
  Retorna un NUEVO recurso con la cantidad sumada (no se modifica el original).
  """
  def sumar(recurso, cantidad), do: %{recurso | cantidad: recurso.cantidad + cantidad}

  @doc """
  Retorna un NUEVO recurso con la cantidad restada. Quien llama debe verificar
  antes con `alcanza?/2` para que nunca quede negativo.
  """
  def restar(recurso, cantidad), do: %{recurso | cantidad: recurso.cantidad - cantidad}

  defimpl String.Chars, for: Recurso do
    def to_string(r) do
      "#{r.codigo} - #{r.nombre} (#{r.categoria}): #{r.cantidad} #{r.unidad} en #{r.ubicacion}"
    end
  end
end
