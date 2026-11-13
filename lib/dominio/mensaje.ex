defmodule Mensaje do
  @moduledoc """
  Mensaje dejado por un familiar para una persona (documento) o una familia (id libre).
  - estado: "pendiente" o "entregado"
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  defstruct id: "", fecha: "", remitente: "", destinatario: "", contenido: "", estado: "pendiente"

  @doc """
  Crea un mensaje nuevo en estado "pendiente".
  """
  def crear(id, fecha, remitente, destinatario, contenido) do
    %Mensaje{
      id: id,
      fecha: fecha,
      remitente: remitente,
      destinatario: destinatario,
      contenido: contenido,
      estado: "pendiente"
    }
  end

  defimpl String.Chars, for: Mensaje do
    def to_string(m) do
      "#{m.id} [#{m.estado}] #{m.fecha} de #{m.remitente} para #{m.destinatario}: \"#{m.contenido}\""
    end
  end
end
