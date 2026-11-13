defmodule Util2 do
  @moduledoc """
  Módulo con funciones que se reutilizan (versión usada en las diapositivas 2-06 y 2-07)
  - licencia: GNU GPL v3
  """

  def mostrar(mensaje, :mensaje), do: mensaje |> IO.puts()
  def mostrar(mensaje, :error), do: IO.puts(:standard_error, mensaje)

  def mostrar_mensaje(mensaje), do: mostrar(mensaje, :mensaje)

  def ingresar(mensaje, :texto) do
    mensaje
    |> IO.gets()
    |> String.trim()
  end

  def ingresar(mensaje, :entero), do: ingresar(mensaje, &String.to_integer/1, :entero)
  def ingresar(mensaje, :real), do: ingresar(mensaje, &String.to_float/1, :real)
  def ingresar(funcion_ingresar, :coleccion), do: ingresar(funcion_ingresar, :coleccion, [])

  defp ingresar(mensaje, parser, tipo_dato) when is_function(parser) do
    try do
      mensaje
      |> ingresar(:texto)
      |> parser.()
    rescue
      ArgumentError ->
        "Error, se espera que ingrese un número #{tipo_dato}\n"
        |> mostrar(:error)

        mensaje
        |> ingresar(parser, tipo_dato)
    end
  end

  defp ingresar(funcion_ingresar, :coleccion, coleccion) do
    elemento = funcion_ingresar.()
    coleccion = coleccion ++ [elemento]

    "¿Desea ingresar otro? (s/n): "
    |> ingresar(:texto)
    |> continuar_ingresando(funcion_ingresar, coleccion)
  end

  defp continuar_ingresando("s", funcion_ingresar, coleccion),
    do: ingresar(funcion_ingresar, :coleccion, coleccion)

  defp continuar_ingresando(_, _funcion_ingresar, coleccion), do: coleccion

  def convertir_coleccion_mensaje(coleccion) do
    coleccion
    |> convertir_coleccion_mensaje(&"#{&1}\n")
  end

  def convertir_coleccion_mensaje(coleccion, convertir) do
    coleccion
    |> Enum.map(convertir)
    |> Enum.join()
  end

  def aplicar_filtro(coleccion, condicion), do: Enum.filter(coleccion, condicion)

  def calcular_permitaciones_circulares(n), do: (n - 1) |> calcular_factorial()

  def calcular_factorial(0), do: 1
  def calcular_factorial(m), do: m * calcular_factorial(m - 1)
end
