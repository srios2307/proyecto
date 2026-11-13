# Guía de sustentación: funciones repartidas en 3 bloques

Cada integrante explica las funciones de su bloque: qué hacen, su caso base y su caso recursivo (o, si es un
GenServer, el mensaje que atiende) y un ejemplo pequeño paso a paso. Las líneas exactas están en
`docs/CORRESPONDENCIA_DIAGRAMAS.md`.

Idea común para los tres: un **GenServer** es un proceso con estado que atiende **un mensaje a la vez**
(como la "caja registradora" de la Guía 12). La API del cliente (`Inventario.asignar(...)`) hace
`GenServer.call`, que envía el mensaje y espera la respuesta; el servidor lo atiende en `handle_call/3` y
responde `{:reply, respuesta, nuevo_estado}`. El estado nunca se modifica: se crea uno nuevo con
`%{estado | campo: valor}`.

---

## Bloque 1 — Zonas, recursión del árbol y tokenizador (Integrante 1)

### `ArbolZonas.insertar_hijo/3` e `insertar_en_lista/3` (`lib/logica/arbol_zonas.ex`)
- **Qué hace**: pone un sector dentro de su zona, o un punto dentro de su sector, en cualquier nivel. Retorna
  un árbol NUEVO.
- **Caso base**: el nodo actual es el padre (`%NodoZona{codigo: codigo} = nodo, codigo`: el patrón repite
  `codigo`, así solo coincide si son iguales) → se agrega el hijo al final de `hijos`.
- **Caso recursivo**: el padre no es este nodo → se aplica la misma función a cada hijo con
  `insertar_en_lista/3`, que a su vez llama a `insertar_hijo/3` (recursión indirecta, como `determinar_par?` y
  `determinar_impar?`). La lista vacía es el caso base de `insertar_en_lista`.
- **Ejemplo**: árbol `[centro[S1]]`, insertar `P1` bajo `S1`:
  1. `insertar_en_lista([centro], "S1", P1)` → `insertar_hijo(centro, "S1", P1)`; centro ≠ S1 →
  2. `insertar_en_lista([S1], "S1", P1)` → `insertar_hijo(S1, "S1", P1)`; ¡coincide! → `S1` con `hijos: [P1]`
  3. `insertar_en_lista([], ...)` → `[]` (caso base). Resultado: `[centro[S1[P1]]]`.

### `ArbolZonas.buscar/2` y `buscar_en_lista/2`
- **Qué hace**: encuentra un nodo por código en cualquier nivel: `{:ok, nodo}` o `{:error, :zona_no_encontrada}`.
- **Caso base**: el nodo es el buscado → `{:ok, nodo}`; o la lista está vacía → error.
- **Caso recursivo**: buscar en los hijos; si en el primero no está (`continuar_busqueda({:error, _}, ...)`),
  seguir con el resto de la lista.
- **Ejemplo**: buscar `P3` en `[centro[S1[P1, P2], S2[P3]]]`: centro no → hijos S1 → P1 no, P2 no, lista
  vacía (error) → seguir con S2 → P3 sí → `{:ok, P3}`.

### `ArbolZonas.estadisticas/1` (estadísticas acumuladas de una zona y sus sectores)
- **Qué hace**: suma personas afectadas, cuenta sectores y puntos y elige el nivel más crítico de TODO el subárbol.
- **Caso base**: un nodo sin hijos → solo sus propios datos (`estadisticas_propias`).
- **Caso recursivo**: sus datos combinados con `estadisticas(hijo)` de cada hijo (`sumar_estadisticas_hijos`
  recorre la lista acumulando, como Fibonacci con acumuladores).
- **Ejemplo** (prueba `arbol_zonas_prueba.exs`): centro (100, medio) con S1 (40, alto: P1 5 bajo, P2 5 crítico)
  y S2 (20, bajo: P3 0) → 100 + 40 + 5 + 5 + 20 + 0 = **170 personas, 2 sectores, 3 puntos, nivel "critico"**.

### `ArbolZonas.construir/1` y `aplanar/1`
- **aplanar**: convierte el árbol en lista `{nodo_sin_hijos, codigo_padre}` en preorden (padre antes que
  hijos) para escribir `zonas.txt`. Caso base: lista vacía → `[]`.
- **construir**: lee esas entradas y rearma el árbol. Caso base: no quedan entradas → el árbol está listo.
  Caso recursivo: si `codigo_padre` es `""` es una zona (se agrega al final); si no, se inserta bajo su padre
  con `insertar_en_lista`.
- **Ejemplo**: `[{centro, ""}, {S1, "centro"}, {P1, "S1"}]` → `[centro]` → `[centro[S1]]` → `[centro[S1[P1]]]`.

### `AnalizadorComandos.separar/4` (tokenizador propio, `lib/logica/analizador_comandos.ex`)
- **Qué hace**: recorre la línea carácter por carácter y la separa en palabras respetando las comillas.
  Parámetros: caracteres que faltan, palabra `actual`, `dentro_de_comillas` (true/false) y `acumulado`.
- **Casos base** (no quedan caracteres): palabra actual vacía → `{:ok, acumulado}`; con palabra → se agrega;
  si quedaron comillas abiertas → `{:error, :comillas_sin_cerrar}`.
- **Casos recursivos**: `"` cambia `dentro_de_comillas`; un espacio fuera de comillas cierra la palabra; cualquier
  otro carácter se pega a `actual`.
- **Ejemplo**: `send 1 "a b"`:
  `s,e,n,d` → actual "send"; espacio → acumulado ["send"]; `1` → "1"; espacio → ["send","1"]; `"` → dentro =
  true; `a`, espacio (dentro, se pega), `b` → "a b"; `"` → dentro = false; fin → `{:ok, ["send","1","a b"]}`.
- `analizar/1` convierte el nombre en átomo con un mapa fijo (`"connect" => :connect`) y en los comandos de
  consulta junta los `clave=valor` en un mapa (`convertir_filtros/3`, también recursiva).

### `Consola.ciclo/1` (`lib/interfaz/consola.ex`)
- **Qué hace**: leer → analizar → ejecutar → mostrar → volver a empezar con el NUEVO estado.
- **Caso base**: el comando `exit` (`procesar({:exit, _}, estado)`): cierra las sesiones y no vuelve a llamarse.
- **Caso recursivo**: cualquier otro comando → `ciclo(nuevo_estado)`.
- `dibujar_arbol/2` (recursiva) muestra el árbol con sangría: el nodo, luego sus hijos un nivel más adentro
  y luego sus hermanos.

### `Zonas` (GenServer) — mensaje `{:registrar, padre, tipo, codigo, nombre, nivel, personas}`
- Junta todas las validaciones en una lista y usa `Validaciones.primer_error/1` (recursiva: caso base lista
  vacía → `:ok`; si el primero es `:ok` sigue con el resto; si no, ese es el error). Reemplaza a `with`.
- `validar_padre`: una zona no tiene padre; un sector solo va en una zona; un punto solo en un sector
  (cláusulas `padre_compatible(:zona, :sector)` y `(:sector, :punto)`).
- Si todo está bien inserta el nodo y guarda `zonas.txt` aplanando el árbol.

---

## Bloque 2 — Inventario, necesidades, prioridad y conflicto concurrente (Integrante 2)

### `Prioridades.insertar_ordenado/2`, `ordenar/1` y `seleccionar_mayor/1` (`lib/logica/prioridades.ex`)
- **antes?(a, b)**: `a` va primero si tiene mayor prioridad (crítica 4 … baja 1); si empatan, la más antigua;
  si también, el id menor.
- **insertar_ordenado** — caso base: lista vacía → `[necesidad]`. Caso recursivo: si va antes que la primera,
  se pone adelante; si no, se deja la primera y se inserta en el resto.
- **ordenar** (ordenamiento por inserción) — caso base `[]`; caso recursivo: se ordena el resto y se inserta la
  primera.
- **seleccionar_mayor** — casos base: `[]` → `{:error, :sin_pendientes}`, `[una]` → `{:ok, una}`. Caso recursivo:
  compara las dos primeras y sigue con la mejor y el resto. Lo usa `next_need`.
- **Ejemplo**: ordenar `[baja, crítica, media]` → ordenar `[crítica, media]` → ordenar `[media]` → `[media]`;
  insertar crítica → `[crítica, media]`; insertar baja → no va antes de crítica, ni de media → `[crítica, media, baja]`.

### `Inventario.elegir_recurso/4` (`lib/servidores/inventario.ex`)
- **Qué hace**: busca el PRIMER recurso de la categoría que alcance. Recibe tuplas `{zona_del_recurso, recurso}`.
- **Caso base 1**: lista vacía → `:ninguno`.
- **Caso base 2**: el primero sirve. El patrón repite `categoria` (así exige la misma categoría) y la guarda
  revisa `disponible >= cantidad` y que la zona coincida (o `:cualquiera`).
- **Caso recursivo**: el primero no sirve → buscar en el resto.
- **Ejemplo**: pedir 30 de agua en "centro" con `[{"centro", R001 agua 20}, {"norte", R005 agua 60}]`:
  R001 no alcanza → R005 es de otra zona → `:ninguno`; segunda pasada con `:cualquiera` → R001 no, R005 sí → `{:ok, R005}`.

### `Inventario` — mensaje `{:asignar, categoria_o_codigo, cantidad, zona, referencia, usuario}`
- Valida cantidad > 0 → si `categoria_o_codigo` es un código de recurso usa ese; si es una categoría usa
  `elegir_recurso` (primero en la zona, luego en cualquiera) → resta, crea el movimiento `MV####`, guarda
  `recursos.csv` y AGREGA a `movimientos.csv` → responde `{:ok, codigo, cantidad_restante}`.
- Si nada alcanza: `{:error, {:inventario_insuficiente, disponible: n}}` y **no cambia nada** (todo o nada).
- Otros mensajes: `{:entrada, ...}`, `{:salida, ...}` (nunca deja negativo), `{:transferir, ...}` (resta en el
  origen y suma en el destino dentro del MISMO mensaje; `buscar_equivalente` es recursiva).

### `Necesidades` — mensaje `{:asignar_recurso, id, categoria_o_codigo, cantidad, usuario}` (diagrama 3b)
1. `validar_asignacion`: existe; si está `atendida` o `cancelada` → `{:error, :ya_cerrada}` (una necesidad
   atendida nunca vuelve a consumir recursos); debe estar `pendiente` y la cantidad no puede superar lo que falta.
2. `pedir_a_inventario`: `Inventario.asignar(categoria, cantidad, zona, id)`.
3. `aplicar_asignacion`: solo si Inventario respondió `{:ok, codigo, _}` se agrega `{codigo, cantidad}` a
   `asignaciones` y, si ya se cubrió todo, el estado pasa a `asignada`; se guarda `necesidades.csv`.
   Si Inventario respondió error, la necesidad NO cambia.
- `Inventario` nunca llama a `Necesidades`: no hay ciclos ni bloqueos mutuos.

### El conflicto concurrente (`demo_concurrencia.exs`, `pruebas/concurrencia_prueba.exs`)
- Laura (Task A) pide 30 para N001 y Pedro (Task B) pide 25 para N002 **al mismo tiempo**; R001 tiene 50.
- Los dos mensajes llegan al buzón de `Necesidades`, que atiende uno a la vez; y `Inventario` también.
- Paso a paso: A llega primero → 30 ≤ 50 → R001 queda en 20 → N001 `asignada`. B → 25 > 20 →
  `{:error, {:inventario_insuficiente, disponible: 20}}` → N002 sigue `pendiente`.
- Resultado: se asignan 30, **nunca 55**, el inventario nunca queda negativo. (Si B llega primero, se asignan
  25 y A recibe el error con disponible 25: el orden puede cambiar, la regla nunca.)
- También: 20 tareas × 10 sobre 100 → exactamente 10 confirmadas e inventario 0.

### `Transiciones.validar/3` y `Permisos.permitido?/2`
- `Transiciones` guarda un mapa `estado => [estados siguientes]` por entidad. `validar` retorna `:ok`,
  `{:error, :ya_cerrada}` (si el estado actual es final) o `{:error, {:transicion_invalida, desde, hacia}}`.
- `Permisos.permitido?` tiene una cláusula por rol con una guarda `comando in @comandos_del_rol`; la última
  cláusula retorna `false`. `Comandos` lo consulta antes de ejecutar y responde `{:error, {:sin_permiso, tipo, comando}}`.

---

## Bloque 3 — Personas, mensajes, mascotas, albergues, supervisión y bitácora (Integrante 3)

### `Personas` — mensajes `{:registrar, ...}` y `{:actualizar_estado, documento, estado, usuario}`
- Registrar: el estado inicial debe ser `sin_informacion` o uno alcanzable desde él (`reportada`, `localizada`);
  id `P###`; el documento no se repite. El primer registro del historial es `{fecha, "-", estado, usuario}`.
- Actualizar: valida con `Transiciones.validar(:persona, actual, nuevo)`, crea la persona nueva con
  `Persona.cambiar_estado` (agrega `{fecha, anterior, nuevo, usuario}` al historial), reescribe `personas.csv`
  y AGREGA una línea a `historial_personas.csv`.
- **Ejemplo**: Andrés `localizada` → `register_entry A01 1001` → `en_albergue` → `register_exit A01 1001` →
  `trasladada`. `person_history 1001` muestra los tres cambios.
- Mensajes: `{:enviar_mensaje, ...}` crea `MS###` en estado `pendiente`; `{:marcar_mensaje, id, estado}` solo
  permite `pendiente ↔ entregado`.

### `Coincidencias.calcular_puntaje/2`, `palabras_en_comun/2` y `pares_candidatos/2` (`lib/logica/coincidencias.ex`)
- **calcular_puntaje**: suma zona +30, color +25, tamaño +20, nombre +15 (solo si ambos lo conocen) y +5 por
  palabra en común en las características (máximo +10).
- **palabras_en_comun** — caso base: primera lista vacía → 0. Caso recursivo: 1 si la primera palabra está en la
  otra lista (0 si no) + `palabras_en_comun(resto, lista2)`.
- **pares_candidatos**: recorre recursivamente cada perdida (`recorrer_perdidas`) y la compara con cada
  encontrada (`comparar_con`); solo misma especie y no resueltas; guarda los pares con puntaje ≥ 50 y los ordena.
- **Ejemplo** (enunciado): perdida "Luna" perro negra mediana zona_norte "collar rojo" vs encontrada perro
  desconocido negra mediana zona_norte "collar rojo, asustada": 30 + 25 + 20 + 0 + 2×5 = **85** ≥ 50 →
  ambos pasan a `posible_coincidencia`.

### `Mascotas` — mensaje `{:confirmar, id_perdida, id_encontrada, usuario}` (diagrama 3c)
- Todo ocurre en UN `handle_call`: valida que existan, que sea perdida + encontrada de la misma especie y que
  `Transiciones` permita pasar AMBOS a `resuelta`. Si alguno ya estaba resuelto → `{:error, :ya_resuelta}` y no
  se toca ninguno. Si no, ambos quedan `resuelta` con `coincidencia_con` cruzado.
- Dos coordinadores que confirman al mismo tiempo: el primer mensaje cierra los dos reportes; el segundo ya
  los encuentra resueltos → `:ya_resuelta`. Un reporte nunca se resuelve dos veces.

### `Albergues` — mensaje `{:ingreso, codigo, documento, usuario}`
- `validar_ingreso` (con `cond`): si la persona ya está → error; si no hay cupos → `{:error, :albergue_lleno}`.
- Si hay cupo, pide a `Personas` el cambio a `en_albergue`; solo si responde `{:ok, _}` agrega el documento al
  `MapSet` de ocupantes y guarda. El `MapSet` no admite repetidos y la ocupación es `MapSet.size`.
- **Ejemplo**: 5 ingresos simultáneos con 2 cupos → los dos primeros mensajes entran, los otros tres encuentran
  el albergue lleno. Ocupación final 2/2.
- `reporte_ocupacion` ordena por porcentaje de ocupación (de mayor a menor).

### `Bitacora` (proceso simple, `lib/procesos/bitacora.ex`)
- `iniciar/1` carga `actividad.log`, crea el proceso con `spawn_link`, lo registra como `:bitacora` y retorna
  `{:ok, pid}`, que es lo que espera el supervisor.
- `loop/1` (recursiva, como la caja registradora): `{:registrar, usuario, comando, resultado}` → agrega una línea
  al archivo y se llama con el estado nuevo; `{:consultar, usuario, remitente}` → responde con `send` y se llama
  igual. No tiene caso base: vive hasta que el supervisor la detenga.
- `registrar/3` usa `send` (asíncrono, no espera); `consultar/1` usa `send` + `receive ... after 5000`.

### Supervisión (`lib/supervision/`)
- `SupervisorPrincipal.init/1` describe 10 hijos con mapas `%{id: ..., start: {Modulo, :funcion, [args]}}` y
  estrategia `:one_for_one`: si un hijo se cae, solo ese se reinicia, y como su `init/1` carga su archivo,
  recupera los datos (comando `crash_server inventario`).
- `SupervisorSesiones` (DynamicSupervisor) empieza sin hijos; `Usuarios` le pide `iniciar_sesion(usuario)` en
  cada `connect` (`DynamicSupervisor.start_child`) y `terminar_sesion(pid)` en cada `disconnect`.
- `Usuarios.conectar/5` (diagrama 3a): si el usuario no existe → valida, crea el `Usuario` con el **hash**
  SHA-256 de la contraseña, guarda y abre sesión (`:registrado`); si existe → compara el hash (`:autenticado`
  o `:credenciales_invalidas`).

### `Persistencia` (`lib/persistencia/persistencia.ex`)
- `a_linea/1`: una cláusula por struct (pattern matching) que arma la línea separada por `;`.
- `desde_linea/2`: separa con `String.split(";")` y una cláusula por tipo exige la cantidad exacta de campos;
  cualquier otra forma → `{:error, :linea_invalida}`. `convertir_enteros/1` es recursiva (caso base `[]`).
- `cargar`: `Archivo.leer_lineas_utiles` (Stream perezoso del parcial 2) → `Stream.map(desde_linea)` →
  `Enum.to_list`; las líneas dañadas se avisan con su número y se ignoran.
