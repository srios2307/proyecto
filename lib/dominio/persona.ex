defmodule Persona do
  @moduledoc """
  Persona afectada que buscan sus familiares.
  - estado: "sin_informacion", "reportada", "localizada", "trasladada", "en_albergue" o "reunificada"
  - historial: lista de tuplas `{fecha, estado_anterior, estado_nuevo, usuario}`
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  defstruct id: "",
            documento: "",
            nombre: "",
            edad: 0,
            zona: "",
            estado: "sin_informacion",
            historial: []

  @doc """
  Crea una persona con su estado inicial. El primer registro del historial usa "-"
  como estado anterior (no tenía estado antes de registrarse).
  """
  def crear(id, documento, nombre, edad, zona, estado, fecha, usuario) do
    %Persona{
      id: id,
      documento: documento,
      nombre: nombre,
      edad: edad,
      zona: zona,
      estado: estado,
      historial: [{fecha, "-", estado, usuario}]
    }
  end

  @doc """
  Retorna una NUEVA persona con el estado cambiado y el cambio agregado al historial.
  La validación de la transición la hace antes `Transiciones`.
  """
  def cambiar_estado(persona, estado_nuevo, fecha, usuario) do
    %{
      persona
      | estado: estado_nuevo,
        historial: persona.historial ++ [{fecha, persona.estado, estado_nuevo, usuario}]
    }
  end

  defimpl String.Chars, for: Persona do
    def to_string(p) do
      "#{p.id} - #{p.nombre} (doc #{p.documento}, #{p.edad} años) zona #{p.zona} - #{p.estado}"
    end
  end
end
