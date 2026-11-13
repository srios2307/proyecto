# Pruebas del tokenizador y analizador de comandos (funciones puras).
# Ejecutar: elixir -pa ebin pruebas/analizador_comandos_prueba.exs
ExUnit.start()

defmodule AnalizadorComandosPrueba do
  use ExUnit.Case

  test "separa por espacios" do
    assert AnalizadorComandos.separar("connect laura 1234") == {:ok, ["connect", "laura", "1234"]}
  end

  test "respeta los textos entre comillas" do
    assert AnalizadorComandos.separar(~s(send_family_message 123 "Estoy bien, en el albergue norte")) ==
             {:ok, ["send_family_message", "123", "Estoy bien, en el albergue norte"]}
  end

  test "línea vacía y espacios repetidos" do
    assert AnalizadorComandos.separar("") == {:ok, []}
    assert AnalizadorComandos.separar("   ") == {:ok, []}
    assert AnalizadorComandos.separar("  list_needs    zona=centro  ") == {:ok, ["list_needs", "zona=centro"]}
    assert AnalizadorComandos.analizar("") == {:vacio, []}
  end

  test "comillas sin cerrar" do
    assert AnalizadorComandos.separar(~s(register_need agua 30 "sin cerrar)) == {:error, :comillas_sin_cerrar}
    assert AnalizadorComandos.analizar(~s(x "a)) == {:error, :comillas_sin_cerrar}
  end

  test "analizar convierte el nombre del comando en átomo" do
    assert AnalizadorComandos.analizar(~s(register_need agua 30 critica centro "Punto 3")) ==
             {:register_need, ["agua", "30", "critica", "centro", "Punto 3"]}

    assert AnalizadorComandos.analizar("CONNECT laura 1234") == {:connect, ["laura", "1234"]}
    assert AnalizadorComandos.analizar("volar alto") == {:desconocido, ["volar"]}
  end

  test "los filtros clave=valor quedan en un mapa al final" do
    assert AnalizadorComandos.analizar("list_needs zona=centro prioridad=critica") ==
             {:list_needs, [%{"zona" => "centro", "prioridad" => "critica"}]}

    assert AnalizadorComandos.analizar("list_needs") == {:list_needs, []}
    assert AnalizadorComandos.analizar("find_person 123") == {:find_person, ["123"]}

    assert AnalizadorComandos.analizar(~s(find_person nombre="Andres Perez")) ==
             {:find_person, [%{"nombre" => "Andres Perez"}]}
  end

  test "en comandos sin filtros el = se conserva como texto" do
    assert AnalizadorComandos.analizar(~s(send_family_message 1 "a=b")) ==
             {:send_family_message, ["1", "a=b"]}
  end
end
