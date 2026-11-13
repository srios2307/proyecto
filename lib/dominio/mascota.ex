defmodule Mascota do
  @moduledoc """
  Reporte de una mascota perdida o encontrada.
  - tipo_reporte: "perdida" o "encontrada"
  - estado: "activa", "posible_coincidencia" o "resuelta"
  - coincidencia_con: id de la otra mascota cuando se confirma la coincidencia ("" si no hay)
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  # Nombres que significan "no se conoce el nombre".
  @nombres_desconocidos ["", "desconocido", "desconocida", "sin_nombre"]

  defstruct id: "",
            tipo_reporte: "",
            especie: "",
            nombre: "",
            caracteristicas: "",
            color: "",
            tamano: "",
            zona: "",
            contacto: "",
            estado: "activa",
            coincidencia_con: ""

  @doc """
  Crea un reporte nuevo en estado "activa".
  """
  def crear(id, tipo_reporte, especie, nombre, caracteristicas, color, tamano, zona, contacto) do
    %Mascota{
      id: id,
      tipo_reporte: tipo_reporte,
      especie: especie,
      nombre: nombre,
      caracteristicas: caracteristicas,
      color: color,
      tamano: tamano,
      zona: zona,
      contacto: contacto,
      estado: "activa",
      coincidencia_con: ""
    }
  end

  @doc """
  Retorna true si se conoce el nombre de la mascota.
  """
  def nombre_conocido?(%Mascota{nombre: nombre}) do
    nombre_normalizado = nombre |> String.trim() |> String.downcase()
    not Enum.member?(@nombres_desconocidos, nombre_normalizado)
  end

  defimpl String.Chars, for: Mascota do
    def to_string(m) do
      "#{m.id} [#{m.tipo_reporte} - #{m.estado}] #{m.especie} \"#{m.nombre}\" #{m.color}, #{m.tamano}, " <>
        "zona #{m.zona}, contacto #{m.contacto}" <>
        texto_caracteristicas(m.caracteristicas) <> texto_coincidencia(m.coincidencia_con)
    end

    defp texto_caracteristicas(""), do: ""
    defp texto_caracteristicas(texto), do: " (#{texto})"

    defp texto_coincidencia(""), do: ""
    defp texto_coincidencia(id), do: " -> coincide con #{id}"
  end
end
