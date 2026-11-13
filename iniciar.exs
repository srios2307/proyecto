# Arranca el sistema: el árbol de supervisión y la consola.
# Uso (desde la carpeta proyecto_final, después de compilar):
#   elixir -pa ebin iniciar.exs              (usa la carpeta datos/)
#   elixir -pa ebin iniciar.exs otra_carpeta (usa otra carpeta, por ejemplo para empezar limpio)
# La opción -pa ebin le dice a Elixir dónde están los .beam compilados.
defmodule Iniciar do
  @moduledoc """
  Script de inicio del sistema de gestión de emergencias.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  # Carpeta por defecto de los archivos de texto plano (al lado de este script).
  @carpeta_por_defecto "datos"

  def main do
    carpeta = System.argv() |> elegir_carpeta()
    ruta_datos = Path.join(__DIR__, carpeta)

    {:ok, _pid} = SupervisorPrincipal.start_link(directorio: ruta_datos)
    Consola.iniciar()
  end

  # System.argv() trae lo que se escribe después del nombre del script.
  defp elegir_carpeta([carpeta | _resto]), do: carpeta
  defp elegir_carpeta([]), do: @carpeta_por_defecto
end

Iniciar.main()
