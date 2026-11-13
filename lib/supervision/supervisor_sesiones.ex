defmodule SupervisorSesiones do
  @moduledoc """
  DynamicSupervisor de las sesiones de usuario.

  ¿Qué es un DynamicSupervisor? (NO visto en clase; lo pide el enunciado)
  Un supervisor normal conoce a sus hijos desde que arranca. Uno DINÁMICO empieza
  sin hijos y los va creando mientras el programa corre: aquí, un proceso `Sesion`
  por cada `connect`, que se termina con `disconnect`.
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  use DynamicSupervisor

  @doc """
  Inicia el supervisor de sesiones con el nombre `SupervisorSesiones`.
  """
  def start_link(_opciones), do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc false
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  @doc """
  Crea un proceso `Sesion` para el usuario.

  `restart: :temporary` significa que si una sesión se cae NO se reinicia: el usuario
  simplemente vuelve a hacer `connect`.

  ## Retorna
    - `{:ok, pid}` o `{:error, motivo}`
  """
  def iniciar_sesion(usuario) do
    hijo = %{id: Sesion, start: {Sesion, :start_link, [usuario]}, restart: :temporary}
    DynamicSupervisor.start_child(__MODULE__, hijo)
  end

  @doc """
  Termina el proceso `Sesion` indicado.
  """
  def terminar_sesion(nil), do: {:error, :not_found}
  def terminar_sesion(pid), do: DynamicSupervisor.terminate_child(__MODULE__, pid)

  @doc """
  Cantidad de sesiones activas.
  """
  def cantidad(), do: DynamicSupervisor.count_children(__MODULE__).active
end
