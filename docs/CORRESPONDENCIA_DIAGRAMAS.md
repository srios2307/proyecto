# Correspondencia entre los diagramas y el código

Revisión hecha con `grep` sobre el código final (2026-11-09). Las rutas son relativas a `proyecto_final/`.
Los diagramas de `docs/diagramas/` **no se modificaron**.

- ✔ = el elemento existe con ese nombre exacto y hace lo que muestra el diagrama.
- ✔* = existe y coincide, con una diferencia menor explicada en la sección "Diferencias".

## 1_arquitectura.png — capas y dependencias

| Diagrama | Elemento | Archivo:línea | Estado |
|---|---|---|---|
| 1 | Capa Interfaz: `Consola` (`ciclo/1` recursivo) | lib/interfaz/consola.ex:82 | ✔ |
| 1 | Capa Interfaz: `Comandos` (`ejecutar/2`) | lib/interfaz/comandos.ex:48 | ✔ |
| 1 | Capa Interfaz: `Util2` (`ingresar` / `mostrar`) | lib/util2.ex:7, lib/util2.ex:12 | ✔ |
| 1 | Consola → AnalizadorComandos `analizar(linea)` | lib/interfaz/consola.ex:86 | ✔ |
| 1 | Consola → Comandos | lib/interfaz/consola.ex:99 | ✔ |
| 1 | Consola → Util2 | lib/interfaz/consola.ex:85, :112, :113 | ✔ |
| 1 | Comandos → Permisos `permitido?(tipo, comando)` | lib/interfaz/comandos.ex:148 → lib/logica/permisos.ex:77 | ✔ |
| 1 | Comandos → Servidores (API del cliente → `GenServer.call`) | lib/interfaz/comandos.ex:171-375 | ✔ |
| 1 | Capa Supervisión: `SupervisorPrincipal` → `SupervisorSesiones` | lib/supervision/supervisor_principal.ex:54 | ✔ |
| 1 | Supervisión "inicia y vigila" Servidores | lib/supervision/supervisor_principal.ex:45-57 | ✔ |
| 1 | Usuarios → SupervisorSesiones `iniciar_sesion` | lib/servidores/usuarios.ex:150 | ✔ |
| 1 | Necesidades → Inventario | lib/servidores/necesidades.ex:212 | ✔ |
| 1 | Albergues → Personas | lib/servidores/albergues.ex:152 | ✔ |
| 1 | Inventario NO llama a Necesidades | `grep Necesidades lib/servidores/inventario.ex` solo aparece en comentarios | ✔ |
| 1 | Servidores: Usuarios, Sesion, Zonas, Centros, Bitacora | lib/servidores/usuarios.ex:1, sesion.ex:1, zonas.ex:1, centros.ex:1, lib/procesos/bitacora.ex:1 | ✔ |
| 1 | Servidores: Necesidades, Inventario, Albergues, Personas, Mascotas | lib/servidores/necesidades.ex:1, inventario.ex:1, albergues.ex:1, personas.ex:1, mascotas.ex:1 | ✔ |
| 1 | Lógica: AnalizadorComandos, Permisos, Transiciones, Validaciones | lib/logica/analizador_comandos.ex:1, permisos.ex:1, transiciones.ex:1, validaciones.ex:1 | ✔ |
| 1 | Lógica: ArbolZonas, Prioridades, Coincidencias | lib/logica/arbol_zonas.ex:1, prioridades.ex:1, coincidencias.ex:1 | ✔ |
| 1 | Lógica → Dominio (crea y usa structs) | lib/logica/arbol_zonas.ex:24, lib/logica/coincidencias.ex:61 | ✔ |
| 1 | Dominio: los 10 structs | lib/dominio/*.ex (ver diagrama 2) | ✔ |
| 1 | Persistencia `a_linea` / `desde_linea` | lib/persistencia/persistencia.ex:187, :282 | ✔* (ver D2) |
| 1 | Persistencia → Archivo (`File.stream!` · `File.write`) | lib/persistencia/persistencia.ex:123-178 → lib/persistencia/archivo.ex:34, :58, :63 | ✔ |
| 1 | Archivo → datos/ (texto plano) | datos/*.csv, datos/zonas.txt, datos/actividad.log | ✔ |
| 1 | Única capa con pantalla: Interfaz (+ Util2) | `grep IO\.` solo aparece en lib/util2.ex | ✔* (ver D3) |
| 1 | Única capa con archivos: Persistencia (+ Archivo) | `grep File\.` solo aparece en lib/persistencia/archivo.ex | ✔ |

## 2_modelo_datos.png — structs, campos y relaciones

| Diagrama | Elemento | Archivo:línea | Estado |
|---|---|---|---|
| 2 | `Usuario{usuario, hash_contrasena, nombre_completo, tipo, zona, fecha_registro}` | lib/dominio/usuario.ex:10 | ✔ |
| 2 | `NodoZona{codigo, nombre, tipo (:zona \| :sector \| :punto), nivel, personas_afectadas, hijos}` | lib/dominio/nodo_zona.ex:13 | ✔ |
| 2 | `Centro{codigo, nombre, tipo, zona}` | lib/dominio/centro.ex:11 | ✔ |
| 2 | `Necesidad{id, tipo, descripcion, cantidad_requerida, cantidad_asignada, zona, prioridad, responsable, estado, fecha, asignaciones}` | lib/dominio/necesidad.ex:11 | ✔ |
| 2 | `Recurso{codigo, nombre, categoria, cantidad, unidad, ubicacion}` | lib/dominio/recurso.ex:11 | ✔ |
| 2 | `Movimiento{id, fecha, tipo, codigo_recurso, cantidad, origen, destino, usuario, referencia}` | lib/dominio/movimiento.ex:11 | ✔ |
| 2 | `Persona{id, documento, nombre, edad, zona, estado, historial}` | lib/dominio/persona.ex:11 | ✔ |
| 2 | `Mensaje{id, fecha, remitente, destinatario, contenido, estado}` | lib/dominio/mensaje.ex:10 | ✔ |
| 2 | `Mascota{id, tipo_reporte, especie, nombre, caracteristicas, color, tamano, zona, contacto, estado, coincidencia_con}` | lib/dominio/mascota.ex:15 | ✔ |
| 2 | `Albergue{codigo, nombre, zona, capacidad, ocupantes}` (MapSet de documentos) | lib/dominio/albergue.ex:14 | ✔ |
| 2 | Ids `N001`, `P001`, `MS001`, `MA001`, `MV0001` | lib/servidores/necesidades.ex:152, personas.ex:188, personas.ex:223, mascotas.ex:155, inventario.ex:436 | ✔ |
| 2 | NodoZona *-- NodoZona `hijos` (zona→sector→punto) | lib/logica/arbol_zonas.ex:24-40, lib/servidores/zonas.ex:149-150 | ✔ |
| 2 | Centro / Necesidad / Albergue / Persona / Mascota → NodoZona `zona` | lib/interfaz/comandos.ex:461 (`validar_lugar`) | ✔* (ver D4) |
| 2 | Recurso → Centro `ubicacion` | lib/servidores/inventario.ex:248 (`validar_ubicacion`) | ✔ |
| 2 | Movimiento → Recurso `codigo_recurso` | lib/servidores/inventario.ex:435-437 (`nuevo_movimiento`) | ✔ |
| 2 | Necesidad → Recurso `asignaciones` (lista de `{codigo, cantidad}`) | lib/dominio/necesidad.ex:60-71 | ✔ |
| 2 | Movimiento → Necesidad `referencia` | lib/servidores/inventario.ex:400 (`referencia` = id de la necesidad) | ✔ |
| 2 | Usuario ← Necesidad `responsable`, ← Mensaje `remitente`, ← Movimiento `usuario` | lib/interfaz/comandos.ex:223, :305, :251 | ✔ |
| 2 | Persona ← Mensaje `destinatario` | lib/servidores/personas.ex:150 (`mensajes_para`) | ✔ |
| 2 | Albergue o-- Persona `ocupantes (documento)` | lib/dominio/albergue.ex:52-57, lib/servidores/albergues.ex:89, :98 | ✔ |
| 2 | Mascota -- Mascota `coincidencia_con` | lib/servidores/mascotas.ex:210-211 | ✔ |

## 3a_secuencia_connect.png — connect

| Diagrama | Elemento | Archivo:línea | Estado |
|---|---|---|---|
| 3a | `CON->>CON: AnalizadorComandos.analizar(linea)` | lib/interfaz/consola.ex:86 → lib/logica/analizador_comandos.ex:84 | ✔ |
| 3a | `CON->>COM: ejecutar({:connect, args}, estado)` | lib/interfaz/comandos.ex:52 | ✔ |
| 3a | `COM->>USR: Usuarios.conectar("laura","1234","coordinador","centro")` | lib/interfaz/comandos.ex:89 → lib/servidores/usuarios.ex:44 | ✔ |
| 3a | `Validaciones + Usuario.crear(...) con hash` | lib/servidores/usuarios.ex:105-124, lib/dominio/usuario.ex:45 | ✔ |
| 3a | `Persistencia.guardar_usuarios(usuarios)` | lib/servidores/usuarios.ex:130 → lib/persistencia/persistencia.ex:56 | ✔* (ver D1) |
| 3a | `USR->>SS: iniciar_sesion(usuario)` | lib/servidores/usuarios.ex:150 → lib/supervision/supervisor_sesiones.ex:33 | ✔ |
| 3a | `SS->>SES: DynamicSupervisor.start_child(Sesion)` → `{:ok, pid}` | lib/supervision/supervisor_sesiones.ex:35 | ✔ |
| 3a | `{:ok, usuario, :registrado}` | lib/servidores/usuarios.ex:132, :161 | ✔ |
| 3a | `{:ok, usuario, :autenticado}` | lib/servidores/usuarios.ex:138 | ✔ |
| 3a | `{:error, :credenciales_invalidas}` | lib/servidores/usuarios.ex:137 | ✔ |
| 3a | `COM-)BIT: Bitacora.registrar("laura", "connect", resultado)` (asíncrono) | lib/interfaz/comandos.ex:84, :160 → lib/procesos/bitacora.ex:36 (`send`) | ✔ |
| 3a | `COM-->>CON: {resultado, nuevo_estado (sesión activa)}` | lib/interfaz/comandos.ex:85, :100-102 | ✔ |
| 3a | `CON->>U: Util2.mostrar(generar_mensaje(resultado))` | lib/interfaz/consola.ex:101-103, :112-113 | ✔ |

## 3b_secuencia_conflicto.png — conflicto concurrente

| Diagrama | Elemento | Archivo:línea | Estado |
|---|---|---|---|
| 3b | Task A / Task B al mismo tiempo | demo_concurrencia.exs:72-73, pruebas/concurrencia_prueba.exs:28-33 | ✔ |
| 3b | `Necesidades.asignar_recurso("N001", "agua", 30, "laura")` | lib/servidores/necesidades.ex:56 | ✔ |
| 3b | `NEC->>NEC: N001 pendiente y 30 ≤ faltante` | lib/servidores/necesidades.ex:188-205 | ✔ |
| 3b | `NEC->>INV: asignar("agua", 30, "centro", "N001")` | lib/servidores/necesidades.ex:212 → lib/servidores/inventario.ex:69 | ✔* (ver D1) |
| 3b | `INV->>INV: elegir_recurso(...)` | lib/servidores/inventario.ex:228-242, :382 | ✔ |
| 3b | `INV->>F: guardar recursos + agregar movimiento` | lib/servidores/inventario.ex:453, :455 | ✔ |
| 3b | `INV-->>NEC: {:ok, "R001", 20}` | lib/servidores/inventario.ex:401 | ✔ |
| 3b | `NEC->>F: guardar necesidades (N001 asignada)` | lib/servidores/necesidades.ex:219-221, :260 | ✔ |
| 3b | `{:error, {:inventario_insuficiente, disponible: 20}}` | lib/servidores/inventario.ex:395, :413 | ✔ |
| 3b | "N002 no cambia" | lib/servidores/necesidades.ex:225 | ✔ |
| 3b | `A-)BIT / B-)BIT: registrar(...)` | demo_concurrencia.exs:77-78 | ✔ |
| 3b | Resultado: se asignan 30, nunca 55; inventario final 20 | docs/salida_flujo_ejemplo.txt:43-47, demo ejecutada 5 veces | ✔ |

## 3c_secuencia_mascotas.png — coincidencias de mascotas

| Diagrama | Elemento | Archivo:línea | Estado |
|---|---|---|---|
| 3c | `match_pets` → `Mascotas.buscar_coincidencias()` | lib/interfaz/comandos.ex:322 → lib/servidores/mascotas.ex:42 | ✔ |
| 3c | `Coincidencias.pares_candidatos(perdidas, encontradas)` | lib/servidores/mascotas.ex:119 → lib/logica/coincidencias.ex:120 | ✔ |
| 3c | `calcular_puntaje(perdida, encontrada)` por cada par | lib/logica/coincidencias.ex:41, :145 | ✔ |
| 3c | Pesos zona +30, color +25, tamaño +20, nombre +15, palabras ≤ +10 | lib/logica/coincidencias.ex:19-25 | ✔ |
| 3c | Pares con puntaje ≥ 50, ordenados | lib/logica/coincidencias.ex:120-124, :148 | ✔ |
| 3c | `ambos reportes → posible_coincidencia` | lib/servidores/mascotas.ex:122, :164-181 | ✔ |
| 3c | `MAS->>F: guardar mascotas` | lib/servidores/mascotas.ex:124, :258 | ✔ |
| 3c | `{:ok, [{"MA001","MA002",75}, ...]}` | lib/servidores/mascotas.ex:126-127; prueba en pruebas/servidores_prueba.exs | ✔ |
| 3c | `Mascotas.confirmar_coincidencia("MA001","MA002", usuario)` | lib/servidores/mascotas.ex:48 | ✔ |
| 3c | `Transiciones: ambos → resuelta, coincidencia_con cruzada` | lib/servidores/mascotas.ex:199-207, :210-211 | ✔ |
| 3c | `{:ok, perdida, encontrada}` | lib/servidores/mascotas.ex:220 | ✔ |
| 3c | `{:error, :ya_resuelta}` sin modificar nada | lib/logica/transiciones.ex:108, lib/servidores/mascotas.ex:223 | ✔ |

## 4_arbol_otp.png — árbol de supervisión

| Diagrama | Elemento | Archivo:línea | Estado |
|---|---|---|---|
| 4 | `iniciar.exs`: `SupervisorPrincipal.start_link(directorio: ruta_datos)` | iniciar.exs:21 | ✔ |
| 4 | `SupervisorPrincipal` · Supervisor · `:one_for_one` | lib/supervision/supervisor_principal.ex:18, :57 | ✔ |
| 4 | `Bitacora` proceso simple, `spawn_link` + `receive`, nombre `:bitacora` | lib/procesos/bitacora.ex:28, :29, :68 | ✔ |
| 4 | Hijo Bitacora `%{id: Bitacora, start: {Bitacora, :iniciar, [directorio]}}` | lib/supervision/supervisor_principal.ex:45 | ✔ |
| 4 | Hijos GenServer: Usuarios, Zonas, Centros, Inventario, Necesidades, Personas, Mascotas, Albergues (en ese orden) | lib/supervision/supervisor_principal.ex:46-53 | ✔ |
| 4 | `SupervisorSesiones` · DynamicSupervisor · `:one_for_one` | lib/supervision/supervisor_principal.ex:54, lib/supervision/supervisor_sesiones.ex:14, :22 | ✔ |
| 4 | `Sesion` GenServer, una por usuario conectado | lib/servidores/sesion.ex:14, lib/supervision/supervisor_sesiones.ex:34 | ✔ |
| 4 | Task temporales (Task.async): summary · zone_status · demo_concurrencia | lib/interfaz/comandos.ex:385, :391, :417; demo_concurrencia.exs:72 | ✔ |

## 5_estructura.txt / .png — carpetas y archivos

| Diagrama | Elemento | Archivo | Estado |
|---|---|---|---|
| 5 | README.md, compilar.sh, compilar.bat, iniciar.exs, demo_concurrencia.exs | raíz | ✔ |
| 5 | lib/util2.ex | lib/util2.ex | ✔ |
| 5 | lib/interfaz/consola.ex, comandos.ex | lib/interfaz/ | ✔ |
| 5 | lib/supervision/supervisor_principal.ex, supervisor_sesiones.ex | lib/supervision/ | ✔ |
| 5 | lib/servidores/ usuarios, sesion, zonas, centros, necesidades, inventario, personas, mascotas, albergues | lib/servidores/ (9 archivos) | ✔ |
| 5 | lib/procesos/bitacora.ex | lib/procesos/ | ✔ |
| 5 | lib/logica/ analizador_comandos, permisos, transiciones, validaciones, arbol_zonas, prioridades, coincidencias | lib/logica/ (7 archivos) | ✔ |
| 5 | lib/dominio/ usuario, nodo_zona, centro, necesidad, recurso, movimiento, persona, mensaje, mascota, albergue | lib/dominio/ (10 archivos) | ✔ |
| 5 | lib/persistencia/persistencia.ex, archivo.ex | lib/persistencia/ | ✔ |
| 5 | ebin/ (.beam generados) | ebin/ | ✔ |
| 5 | datos/ con los 12 archivos (usuarios.csv … actividad.log) | datos/ | ✔ |
| 5 | pruebas/*_prueba.exs y todas.exs | pruebas/ (11 pruebas + todas.exs) | ✔ |
| 5 | docs/diagramas/, docs/SUSTENTACION.md, docs/GUION_VIDEO.md | docs/ | ✔* (ver D5) |

## 6_estados.png — transiciones de estado

| Diagrama | Elemento | Archivo:línea | Estado |
|---|---|---|---|
| 6 | Necesidad: pendiente → asignada \| cancelada; asignada → en_atencion \| cancelada; en_atencion → atendida | lib/logica/transiciones.ex:13-19 | ✔ |
| 6 | "pendiente → asignada: assign_resource cubre la cantidad" | lib/dominio/necesidad.ex:60-71, lib/servidores/necesidades.ex:170 | ✔ |
| 6 | Persona: las 11 transiciones del diagrama | lib/logica/transiciones.ex:20-27 | ✔ |
| 6 | Mascota: activa ↔ posible_coincidencia, ambos → resuelta | lib/logica/transiciones.ex:28-32 | ✔ |
| 6 | Estados finales (atendida, cancelada, reunificada, resuelta) | lib/logica/transiciones.ex:74-76, :107-110 | ✔ |
| 6 | Cualquier otra → `{:error, {:transicion_invalida, desde, hacia}}` | lib/logica/transiciones.ex:102 | ✔ |
| 6 | "match_pets (puntaje ≥ 50)" | lib/servidores/mascotas.ex:172-181 | ✔ |
| 6 | "se descarta" (posible_coincidencia → activa) | lib/servidores/mascotas.ex:56, comando `discard_pet_match` | ✔ |

## Diferencias (para que el grupo decida si actualiza el diagrama)

- **D1. Parámetros extra con valor por defecto.** `Persistencia.guardar_usuarios(usuarios)` en el código es
  `guardar_usuarios(usuarios, directorio)`: la carpeta de datos se pasa porque es configurable (las pruebas usan
  una carpeta temporal). Igual pasa con todas las funciones `guardar_*`. `Inventario.asignar/4` tiene un quinto
  parámetro opcional `usuario \\ "sistema"` para guardarlo en el movimiento; la llamada del diagrama con 4
  argumentos funciona tal cual. No cambia la secuencia. *Sugerencia: dejar el diagrama como está o agregar
  `directorio` en la nota de 3a.*
- **D2. Dónde viven `a_linea` / `desde_linea`.** El prompt de trabajo sugería ponerlas en cada struct, pero los
  diagramas 1 y 5 las ponen en `Persistencia`. Se siguió el diagrama: `Persistencia.a_linea/1` tiene una cláusula
  por struct y `Persistencia.desde_linea/2` una por tipo de archivo. Para esto `Persistencia` conoce los structs
  del dominio (dependencia implícita que el diagrama no dibuja).
- **D3. Avisos de líneas dañadas.** `Persistencia` usa `Util2.mostrar(..., :error)` para avisar el número de una
  línea dañada al cargar (lib/persistencia/persistencia.ex:177). Es una flecha Persistencia → Util2 que el
  diagrama 1 no dibuja. La alternativa sería devolver los avisos hasta la consola, lo que complica todos los
  `init/1`. *Sugerencia: agregar una flecha punteada "avisos" de Persistencia a Util2.*
  Además, `Consola` pattern-matchea `%NodoZona{}` y usa el `to_string` de los structs para mostrarlos
  (Interfaz → Dominio solo para presentar datos).
- **D4. Zona de una necesidad.** El enunciado dice que una necesidad puede estar asociada a una zona *o a un
  albergue*. Por eso `validar_lugar/1` acepta un código del árbol de zonas o el código de un centro
  (un albergue también se registra como centro). En el diagrama 2 la relación es solo con `NodoZona`.
  También: `Inventario` conoce la zona de cada centro leyendo `centros.csv` en `init/1` y con
  `Inventario.registrar_ubicacion/2` (lo llama `Comandos` al registrar un centro o albergue); así no hay
  una flecha Inventario → Centros.
- **D5. Archivos extra en `docs/` y en la raíz.** Además de lo que muestra `5_estructura.txt` existen
  `docs/CORRESPONDENCIA_DIAGRAMAS.md` (este archivo), `docs/flujo_ejemplo_comandos.txt`,
  `docs/salida_flujo_ejemplo.txt`, `docs/datos_ejemplo_comandos.txt` y `ProyectoFinal.pdf` (el enunciado).
  *Sugerencia: agregarlos al diagrama 5 o mencionarlos en el informe.*
- **D6. Comandos agregados.** Para completar requisitos se agregaron comandos que no están en el enunciado:
  `list_zones`, `list_centers`, `discard_pet_match` (transición "se descarta" del diagrama 6) y
  `crash_server` (demostración de supervisión, solo administrador). No cambian ningún diagrama.
