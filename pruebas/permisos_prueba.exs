# Pruebas de Permisos por rol (funciones puras).
# Ejecutar: elixir -pa ebin pruebas/permisos_prueba.exs
ExUnit.start()

defmodule PermisosPrueba do
  use ExUnit.Case

  test "ciudadano: consultas y reportes sí; inventario no" do
    assert Permisos.permitido?("ciudadano", :report_person)
    assert Permisos.permitido?("ciudadano", :send_family_message)
    assert Permisos.permitido?("ciudadano", :list_needs)
    refute Permisos.permitido?("ciudadano", :register_need)
    refute Permisos.permitido?("ciudadano", :assign_resource)
  end

  test "voluntario: hereda del ciudadano y registra necesidades" do
    assert Permisos.permitido?("voluntario", :report_pet)
    assert Permisos.permitido?("voluntario", :register_need)
    assert Permisos.permitido?("voluntario", :match_pets)
    refute Permisos.permitido?("voluntario", :confirm_pet_match)
  end

  test "coordinador: administra inventario pero no ve usuarios" do
    assert Permisos.permitido?("coordinador", :assign_resource)
    assert Permisos.permitido?("coordinador", :summary)
    refute Permisos.permitido?("coordinador", :list_users)
    refute Permisos.permitido?("coordinador", :activity)
  end

  test "administrador: puede todo" do
    assert Permisos.permitido?("administrador", :list_users)
    assert Permisos.permitido?("administrador", :activity)
    assert Permisos.permitido?("administrador", :assign_resource)
  end

  test "verificar retorna la tupla de error" do
    assert Permisos.verificar("coordinador", :summary) == :ok

    assert Permisos.verificar("ciudadano", :summary) ==
             {:error, {:sin_permiso, "ciudadano", :summary}}

    assert Permisos.verificar("pirata", :help) == {:error, {:sin_permiso, "pirata", :help}}
  end
end
