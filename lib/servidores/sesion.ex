defmodule Sesion do
  @moduledoc """
  GenServer con los datos de UNA sesión abierta: quién está conectado, su rol,
  su zona y desde qué hora. Hay un proceso `Sesion` por usuario conectado; los crea
  y termina `SupervisorSesiones` (un DynamicSupervisor) cuando el usuario hace
  `connect` y `disconnect`.

  Estado: `%{usuario, tipo, zona, hora_conexion}`
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  use GenServer

  @doc """
  Inicia una sesión para el usuario. No se registra con nombre porque hay varias.
  """
  def start_link(%Usuario{} = usuario), do: GenServer.start_link(__MODULE__, usuario)

  @doc """
  Retorna los datos de la sesión.
  """
  def consultar(pid), do: GenServer.call(pid, :consultar)

  @doc false
  def init(%Usuario{} = usuario) do
    {:ok,
     %{
       usuario: usuario.usuario,
       tipo: usuario.tipo,
       zona: usuario.zona,
       hora_conexion: Validaciones.fecha_actual()
     }}
  end

  @doc false
  def handle_call(:consultar, _de, estado), do: {:reply, estado, estado}
end
