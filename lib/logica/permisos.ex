defmodule Permisos do
  @moduledoc """
  Qué comandos puede ejecutar cada tipo de usuario. Funciones puras y declarativas:
  una cláusula por tipo de usuario.

  Los comandos `connect`, `use`, `sessions`, `help` y `exit` no pasan por aquí porque
  se pueden usar sin sesión (los maneja directamente `Comandos`).
  - autores: grupo del proyecto final, Programación III
  - fecha: 2026-11-09
  - licencia: GNU GPL v3
  """

  # Consultas y reportes básicos.
  @comandos_ciudadano [
    :disconnect,
    :list_zones,
    :list_centers,
    :zone_status,
    :zone_stats,
    :list_needs,
    :list_resources,
    :find_person,
    :person_history,
    :report_person,
    :send_family_message,
    :list_family_messages,
    :report_pet,
    :list_pets,
    :check_shelter
  ]

  # Lo del ciudadano + registrar necesidades, mover personas en albergues, coincidencias.
  @comandos_voluntario @comandos_ciudadano ++
                         [
                           :register_need,
                           :update_person,
                           :register_entry,
                           :register_exit,
                           :match_pets,
                           :mark_message,
                           :resource_history
                         ]

  # Lo del voluntario + administrar zonas, inventario, necesidades y albergues.
  @comandos_coordinador @comandos_voluntario ++
                          [
                            :register_zone,
                            :register_sector,
                            :register_point,
                            :register_center,
                            :register_resource,
                            :resource_in,
                            :resource_out,
                            :assign_resource,
                            :transfer_resource,
                            :update_need,
                            :register_shelter,
                            :confirm_pet_match,
                            :discard_pet_match,
                            :summary,
                            :critical_resources,
                            :pending_needs,
                            :next_need,
                            :shelter_report
                          ]

  # Todo, más usuarios, bitácora y la simulación de fallos.
  @comandos_administrador @comandos_coordinador ++ [:list_users, :activity, :crash_server]

  @doc """
  Retorna true si el tipo de usuario puede ejecutar el comando.

  ## Ejemplo
      Permisos.permitido?("ciudadano", :assign_resource)   # false
      Permisos.permitido?("coordinador", :assign_resource) # true
  """
  def permitido?("administrador", comando) when comando in @comandos_administrador, do: true
  def permitido?("coordinador", comando) when comando in @comandos_coordinador, do: true
  def permitido?("voluntario", comando) when comando in @comandos_voluntario, do: true
  def permitido?("ciudadano", comando) when comando in @comandos_ciudadano, do: true
  def permitido?(_tipo, _comando), do: false

  @doc """
  Igual que `permitido?/2` pero con tupla de resultado.

  ## Retorna
    - `:ok` o `{:error, {:sin_permiso, tipo, comando}}`
  """
  def verificar(tipo, comando) do
    tipo
    |> permitido?(comando)
    |> resultado_permiso(tipo, comando)
  end

  defp resultado_permiso(true, _tipo, _comando), do: :ok
  defp resultado_permiso(false, tipo, comando), do: {:error, {:sin_permiso, tipo, comando}}

  @doc """
  Lista de comandos que puede usar un tipo de usuario (para `help`).
  """
  def comandos_permitidos("administrador"), do: @comandos_administrador
  def comandos_permitidos("coordinador"), do: @comandos_coordinador
  def comandos_permitidos("voluntario"), do: @comandos_voluntario
  def comandos_permitidos("ciudadano"), do: @comandos_ciudadano
  def comandos_permitidos(_tipo), do: []
end
