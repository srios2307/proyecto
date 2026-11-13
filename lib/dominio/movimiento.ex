defmodule Movimiento do
  @moduledoc """
  Un movimiento del historial de inventario.
  - tipo: "entrada", "salida", "asignacion" o "transferencia"
  - referencia: id de la necesidad (asignación) o código del recurso destino (transferencia)
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  defstruct id: "",
            fecha: "",
            tipo: "",
            codigo_recurso: "",
            cantidad: 0,
            origen: "",
            destino: "",
            usuario: "",
            referencia: ""

  @doc """
  Crea un movimiento.
  """
  def crear(id, fecha, tipo, codigo_recurso, cantidad, origen, destino, usuario, referencia) do
    %Movimiento{
      id: id,
      fecha: fecha,
      tipo: tipo,
      codigo_recurso: codigo_recurso,
      cantidad: cantidad,
      origen: origen,
      destino: destino,
      usuario: usuario,
      referencia: referencia
    }
  end

  defimpl String.Chars, for: Movimiento do
    def to_string(m) do
      "#{m.id} #{m.fecha} #{m.tipo} #{m.codigo_recurso} x#{m.cantidad} " <>
        "(#{m.origen} -> #{m.destino}) por #{m.usuario} ref #{m.referencia}"
    end
  end
end
