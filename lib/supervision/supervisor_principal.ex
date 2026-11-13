defmodule SupervisorPrincipal do
  @moduledoc """
  Raíz del árbol de supervisión (diagrama `4_arbol_otp.png`).

  ¿Qué es un Supervisor? (NO visto en clase; lo pide el enunciado)
  Es un proceso cuyo único trabajo es iniciar otros procesos (sus HIJOS) y vigilarlos.
  Si un hijo se cae, el supervisor lo vuelve a iniciar. Con la estrategia
  `:one_for_one` solo se reinicia el hijo que falló; los demás siguen igual.
  Como cada GenServer carga su archivo en `init/1`, al reiniciarse recupera sus datos.

  Hijos (en este orden): Bitacora, Usuarios, Zonas, Centros, Inventario, Necesidades,
  Personas, Mascotas, Albergues y SupervisorSesiones.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  use Supervisor

  @directorio_por_defecto "datos"

  @doc """
  Inicia todo el sistema.

  ## Parámetro
    - opciones: lista con la carpeta de datos, por ejemplo `[directorio: "datos"]`.
      Las pruebas usan una carpeta temporal para no tocar `datos/`.
  """
  def start_link(opciones \\ []) do
    directorio = opciones[:directorio] || @directorio_por_defecto
    Supervisor.start_link(__MODULE__, directorio, name: __MODULE__)
  end

  @doc """
  Detiene todo el sistema (lo usan las pruebas de persistencia).
  """
  def detener(), do: Supervisor.stop(__MODULE__)

  @doc false
  def init(directorio) do
    Persistencia.preparar_directorio(directorio)

    # Cada hijo se describe con un mapa: un id y la función que lo inicia {Modulo, :funcion, [argumentos]}.
    hijos = [
      %{id: Bitacora, start: {Bitacora, :iniciar, [directorio]}},
      %{id: Usuarios, start: {Usuarios, :start_link, [directorio]}},
      %{id: Zonas, start: {Zonas, :start_link, [directorio]}},
      %{id: Centros, start: {Centros, :start_link, [directorio]}},
      %{id: Inventario, start: {Inventario, :start_link, [directorio]}},
      %{id: Necesidades, start: {Necesidades, :start_link, [directorio]}},
      %{id: Personas, start: {Personas, :start_link, [directorio]}},
      %{id: Mascotas, start: {Mascotas, :start_link, [directorio]}},
      %{id: Albergues, start: {Albergues, :start_link, [directorio]}},
      %{id: SupervisorSesiones, start: {SupervisorSesiones, :start_link, [[]]}, type: :supervisor}
    ]

    Supervisor.init(hijos, strategy: :one_for_one)
  end
end
