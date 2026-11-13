defmodule Centro do
  @moduledoc """
  Centro de apoyo: es la ubicación donde están los recursos.
  - tipo: "centro_acopio", "albergue" o "punto_atencion"
  - zona: código de la zona (o sector) donde está el centro
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  defstruct codigo: "", nombre: "", tipo: "centro_acopio", zona: ""

  @doc """
  Crea un centro de apoyo.
  """
  def crear(codigo, nombre, tipo, zona) do
    %Centro{codigo: codigo, nombre: nombre, tipo: tipo, zona: zona}
  end

  defimpl String.Chars, for: Centro do
    def to_string(c), do: "#{c.codigo} - #{c.nombre} (#{c.tipo}, zona #{c.zona})"
  end
end
