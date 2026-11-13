defmodule NodoZona do
  @moduledoc """
  Un nodo de la jerarquía de la emergencia: zona → sector → punto de atención.
  El campo `hijos` es una lista de `NodoZona`, por eso la estructura es un árbol
  y se recorre con recursión (ver `ArbolZonas`).
  - tipo: `:zona`, `:sector` o `:punto`
  - nivel: "critico", "alto", "medio" o "bajo"
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  defstruct codigo: "",
            nombre: "",
            tipo: :zona,
            nivel: "bajo",
            personas_afectadas: 0,
            hijos: []

  @doc """
  Crea un nodo sin hijos.
  """
  def crear(codigo, nombre, tipo, nivel, personas_afectadas) do
    %NodoZona{
      codigo: codigo,
      nombre: nombre,
      tipo: tipo,
      nivel: nivel,
      personas_afectadas: personas_afectadas,
      hijos: []
    }
  end

  defimpl String.Chars, for: NodoZona do
    def to_string(n) do
      "#{n.codigo} - #{n.nombre} [#{n.tipo}] nivel #{n.nivel}, #{n.personas_afectadas} personas afectadas"
    end
  end
end
