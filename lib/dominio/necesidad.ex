defmodule Necesidad do
  @moduledoc """
  Necesidad puntual (solicitud de ayuda) asociada a una zona, sector, punto o albergue.
  - estado: "pendiente", "asignada", "en_atencion", "atendida" o "cancelada"
  - asignaciones: lista de tuplas `{codigo_recurso, cantidad}` con lo que ya se entregó
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  defstruct id: "",
            tipo: "",
            descripcion: "",
            cantidad_requerida: 0,
            cantidad_asignada: 0,
            zona: "",
            prioridad: "media",
            responsable: "",
            estado: "pendiente",
            fecha: "",
            asignaciones: []

  @doc """
  Crea una necesidad nueva: empieza "pendiente", sin nada asignado.
  """
  def crear(id, tipo, descripcion, cantidad_requerida, zona, prioridad, responsable, fecha) do
    %Necesidad{
      id: id,
      tipo: tipo,
      descripcion: descripcion,
      cantidad_requerida: cantidad_requerida,
      cantidad_asignada: 0,
      zona: zona,
      prioridad: prioridad,
      responsable: responsable,
      estado: "pendiente",
      fecha: fecha,
      asignaciones: []
    }
  end

  @doc """
  Cantidad que todavía falta por asignar.
  """
  def faltante(%Necesidad{cantidad_requerida: requerida, cantidad_asignada: asignada}) do
    requerida - asignada
  end

  @doc """
  Retorna true si la necesidad ya está cerrada (atendida o cancelada).
  """
  def cerrada?(%Necesidad{estado: estado}) when estado in ["atendida", "cancelada"], do: true
  def cerrada?(_necesidad), do: false

  @doc """
  Retorna una NUEVA necesidad con una asignación más.
  Si con esta asignación se cubre toda la cantidad, el estado pasa de
  "pendiente" a "asignada" (transición del diagrama de estados).
  """
  def agregar_asignacion(necesidad, codigo_recurso, cantidad) do
    asignada = necesidad.cantidad_asignada + cantidad

    %{
      necesidad
      | cantidad_asignada: asignada,
        asignaciones: necesidad.asignaciones ++ [{codigo_recurso, cantidad}],
        estado: estado_tras_asignar(asignada, necesidad.cantidad_requerida)
    }
  end

  defp estado_tras_asignar(asignada, requerida) when asignada >= requerida, do: "asignada"
  defp estado_tras_asignar(_asignada, _requerida), do: "pendiente"

  defimpl String.Chars, for: Necesidad do
    def to_string(n) do
      "#{n.id} [#{n.prioridad}] #{n.tipo} #{n.cantidad_asignada}/#{n.cantidad_requerida} " <>
        "en #{n.zona} - #{n.estado} - \"#{n.descripcion}\" (#{n.responsable}, #{n.fecha})"
    end
  end
end
