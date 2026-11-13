@echo off
REM ---------------------------------------------------------------
REM Compila todos los modulos de lib\ hacia la carpeta ebin\ (Windows).
REM Uso: compilar.bat   (desde la carpeta proyecto_final)
REM Luego: elixir -pa ebin iniciar.exs
REM ---------------------------------------------------------------
cd /d "%~dp0"
if not exist ebin mkdir ebin
del /q ebin\*.beam 2>nul

REM "call" es necesario porque elixirc tambien es un .bat en Windows.
call elixirc -o ebin ^
  lib\util2.ex ^
  lib\persistencia\archivo.ex ^
  lib\dominio\usuario.ex ^
  lib\dominio\nodo_zona.ex ^
  lib\dominio\centro.ex ^
  lib\dominio\necesidad.ex ^
  lib\dominio\recurso.ex ^
  lib\dominio\movimiento.ex ^
  lib\dominio\persona.ex ^
  lib\dominio\mensaje.ex ^
  lib\dominio\mascota.ex ^
  lib\dominio\albergue.ex ^
  lib\logica\validaciones.ex ^
  lib\logica\transiciones.ex ^
  lib\logica\permisos.ex ^
  lib\logica\analizador_comandos.ex ^
  lib\logica\arbol_zonas.ex ^
  lib\logica\prioridades.ex ^
  lib\logica\coincidencias.ex ^
  lib\persistencia\persistencia.ex ^
  lib\procesos\bitacora.ex ^
  lib\servidores\sesion.ex ^
  lib\supervision\supervisor_sesiones.ex ^
  lib\servidores\usuarios.ex ^
  lib\servidores\zonas.ex ^
  lib\servidores\centros.ex ^
  lib\servidores\inventario.ex ^
  lib\servidores\necesidades.ex ^
  lib\servidores\personas.ex ^
  lib\servidores\mascotas.ex ^
  lib\servidores\albergues.ex ^
  lib\supervision\supervisor_principal.ex ^
  lib\interfaz\comandos.ex ^
  lib\interfaz\consola.ex

if %errorlevel% neq 0 (
  echo Error de compilacion.
  exit /b %errorlevel%
)
echo Compilacion terminada: los .beam estan en ebin\
