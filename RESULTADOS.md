# Resultados: revisión de la base de datos con SQL

Cada consulta está en `03_consultas_auditoria.sql`. Aquí se documenta qué busca, la consulta, su resultado y qué se concluye. Los datos son ficticios y las alertas son **preliminares**: una alerta no demuestra por sí sola una deficiencia, hay que verificar con evidencia antes de reportarla.

- Motor: SQLite 3. Fecha de corte de las consultas con fechas: `2026-10-28`.

## Consulta 1: Conteo de registros por tabla

**Objetivo:** Verificar que la carga de datos de prueba quedó completa en las cuatro tablas.  
**Técnicas:** SELECT, COUNT, UNION ALL

```sql
SELECT 'usuarios' AS tabla, COUNT(*) AS registros FROM usuarios
UNION ALL
SELECT 'equipos', COUNT(*) FROM equipos
UNION ALL
SELECT 'permisos', COUNT(*) FROM permisos
UNION ALL
SELECT 'asignacion_permisos', COUNT(*) FROM asignacion_permisos;
```

**Resultado** (4 filas):

| tabla | registros |
|---|---|
| usuarios | 40 |
| equipos | 42 |
| permisos | 8 |
| asignacion_permisos | 116 |

**Lectura:** Se cargaron 40 usuarios, 42 equipos, 8 permisos y 116 asignaciones de permisos.

![Consulta 1](capturas/01_conteo_registros.png)

## Consulta 2: Usuarios por área y estado

**Objetivo:** Conocer cómo se distribuyen los usuarios activos e inactivos por área.  
**Técnicas:** GROUP BY, SUM + CASE

```sql
SELECT area,
       COUNT(*) AS total,
       SUM(CASE WHEN estado = 'Activo'   THEN 1 ELSE 0 END) AS activos,
       SUM(CASE WHEN estado = 'Inactivo' THEN 1 ELSE 0 END) AS inactivos
FROM usuarios
GROUP BY area
ORDER BY total DESC, area;
```

**Resultado** (8 filas):

| area | total | activos | inactivos |
|---|---|---|---|
| Ventas | 9 | 8 | 1 |
| Finanzas | 8 | 7 | 1 |
| Tecnología | 6 | 5 | 1 |
| Logística | 5 | 5 | 0 |
| Operaciones | 4 | 3 | 1 |
| Soporte | 4 | 3 | 1 |
| Administración | 2 | 2 | 0 |
| Recursos Humanos | 2 | 2 | 0 |

**Lectura:** Ventas y Finanzas son las áreas con más usuarios. Hay 5 usuarios inactivos repartidos entre las áreas; esos son los que importan para las consultas 7 y 8.

![Consulta 2](capturas/02_usuarios_por_area.png)

## Consulta 3: Equipos con su responsable

**Objetivo:** Listar cada equipo con la persona a la que está asignado, incluyendo los que no tienen responsable.  
**Técnicas:** LEFT JOIN, COALESCE

```sql
SELECT e.id_equipo,
       e.nombre_equipo,
       e.tipo,
       e.estado,
       COALESCE(u.nombre, 'SIN RESPONSABLE') AS responsable,
       u.estado AS estado_usuario
FROM equipos e
LEFT JOIN usuarios u ON u.id_usuario = e.id_usuario
ORDER BY e.id_equipo;
```

**Resultado** (42 filas):

| id_equipo | nombre_equipo | tipo | estado | responsable | estado_usuario |
|---|---|---|---|---|---|
| 1 | SRV-TEC-006 | Servidor | En uso | Carolina Fuentes | Activo |
| 2 | NB-TEC-039 | Notebook | En uso | Carolina Fuentes | Activo |
| 3 | SRV-TEC-052 | Servidor | En uso | Valentina González | Activo |
| 4 | NB-TEC-024 | Notebook | En uso | Valentina González | Activo |
| 5 | NB-TEC-018 | Notebook | En uso | Antonia Araya | Activo |
| 6 | NB-TEC-097 | Notebook | En uso | Valentina López | Inactivo |
| 7 | NB-TEC-041 | Notebook | En uso | Felipe Núñez | Activo |
| 8 | NB-FIN-037 | Notebook | En uso | Valentina Soto | Activo |
| 9 | NB-SOP-020 | Notebook | En uso | Benjamín Vera | Activo |
| 10 | NB-SOP-008 | Notebook | En uso | Rodrigo Torres | Activo |

_Se muestran 10 de 42 filas. Resultado completo en `auditoria_ti.db`._

**Lectura:** 10 de 42 equipos aparecen sin responsable. No todos son un problema: un equipo 'En bodega' o 'Baja' no debería tener dueño. La consulta 6 separa los que sí requieren revisión.

![Consulta 3](capturas/03_equipos_responsable.png)

## Consulta 4: Usuarios duplicados por correo

**Objetivo:** Detectar personas registradas más de una vez con el mismo correo, ignorando mayúsculas y espacios.  
**Técnicas:** GROUP BY, HAVING, LOWER/TRIM, GROUP_CONCAT

```sql
SELECT LOWER(TRIM(correo))        AS correo_normalizado,
       COUNT(*)                   AS registros,
       GROUP_CONCAT(id_usuario, ', ') AS ids_usuario
FROM usuarios
GROUP BY LOWER(TRIM(correo))
HAVING COUNT(*) > 1;
```

**Resultado** (2 filas):

| correo_normalizado | registros | ids_usuario |
|---|---|---|
| camila.rojas@empresa.test | 2 | 12, 38 |
| diego.munoz@empresa.test | 2 | 18, 39 |

**Lectura:** Dos personas están registradas dos veces con el mismo correo: ids 12 y 38; ids 18 y 39. En el segundo caso el correo difiere solo en mayúsculas; sin `LOWER` y `TRIM` esa duplicidad no se habría detectado.

![Consulta 4](capturas/04_usuarios_duplicados_correo.png)

## Consulta 5: Posibles duplicados por nombre

**Objetivo:** Encontrar personas con el mismo nombre pero correos distintos: pueden ser duplicados o simples homónimos.  
**Técnicas:** GROUP BY, HAVING, COUNT(DISTINCT)

```sql
SELECT nombre,
       COUNT(*)                        AS registros,
       GROUP_CONCAT(id_usuario, ', ')  AS ids_usuario,
       GROUP_CONCAT(correo, ' | ')     AS correos
FROM usuarios
GROUP BY LOWER(TRIM(nombre))
HAVING COUNT(*) > 1
   AND COUNT(DISTINCT LOWER(TRIM(correo))) > 1;
```

**Resultado** (1 fila):

| nombre | registros | ids_usuario | correos |
|---|---|---|---|
| Valentina Soto | 2 | 7, 40 | valentina.soto@empresa.test \| v.soto@empresa.test |

**Lectura:** Hay un nombre con dos registros y correos distintos: Valentina Soto (ids 7 y 40). Puede ser un duplicado o dos personas con el mismo nombre; la consulta no lo resuelve, se valida con RR.HH.

![Consulta 5](capturas/05_posibles_duplicados_nombre.png)

## Consulta 6: Equipos en uso sin responsable

**Objetivo:** Identificar equipos marcados 'En uso' que no tienen un usuario asignado válido.  
**Técnicas:** LEFT JOIN + IS NULL (anti-join)

```sql
SELECT e.id_equipo,
       e.nombre_equipo,
       e.tipo,
       e.sistema_operativo,
       e.estado
FROM equipos e
LEFT JOIN usuarios u ON u.id_usuario = e.id_usuario
WHERE u.id_usuario IS NULL
  AND e.estado = 'En uso'
ORDER BY e.id_equipo;
```

**Resultado** (4 filas):

| id_equipo | nombre_equipo | tipo | sistema_operativo | estado |
|---|---|---|---|---|
| 33 | DT-LOG-086 | Escritorio | Windows 11 | En uso |
| 34 | DT-FIN-041 | Escritorio | Windows 10 | En uso |
| 35 | DT-LOG-054 | Escritorio | Windows 11 | En uso |
| 36 | DT-OPS-064 | Escritorio | Windows 11 | En uso |

**Lectura:** 4 equipos marcados 'En uso' no tienen responsable: DT-LOG-086, DT-FIN-041, DT-LOG-054, DT-OPS-064. Conviene ubicarlos físicamente y asignarlos o darlos de baja.

![Consulta 6](capturas/06_equipos_sin_responsable.png)

## Consulta 7: Equipos asignados a usuarios inactivos

**Objetivo:** Detectar equipos en uso cuyo responsable ya fue dado de baja.  
**Técnicas:** JOIN, WHERE, julianday

```sql
SELECT e.nombre_equipo,
       e.tipo,
       u.nombre,
       u.area,
       u.fecha_baja,
       CAST(julianday('2026-10-28') - julianday(u.fecha_baja) AS INTEGER) AS dias_desde_baja
FROM equipos e
JOIN usuarios u ON u.id_usuario = e.id_usuario
WHERE u.estado = 'Inactivo'
  AND e.estado = 'En uso'
ORDER BY dias_desde_baja DESC;
```

**Resultado** (3 filas):

| nombre_equipo | tipo | nombre | area | fecha_baja | dias_desde_baja |
|---|---|---|---|---|---|
| NB-VEN-038 | Notebook | Diego Contreras | Ventas | 2025-11-30 | 332 |
| NB-FIN-068 | Notebook | Macarena Díaz | Finanzas | 2025-12-08 | 324 |
| NB-TEC-097 | Notebook | Valentina López | Tecnología | 2026-06-23 | 127 |

**Lectura:** 3 equipos siguen a nombre de usuarios dados de baja hace entre 127 y 332 días: NB-VEN-038 (Diego Contreras), NB-FIN-068 (Macarena Díaz), NB-TEC-097 (Valentina López).

![Consulta 7](capturas/07_equipos_usuarios_inactivos.png)

## Consulta 8: Permisos de riesgo en usuarios inactivos

**Objetivo:** Encontrar permisos Alto o Crítico que siguen vigentes en usuarios dados de baja.  
**Técnicas:** JOIN de tres tablas, IN

```sql
SELECT u.nombre,
       u.area,
       u.fecha_baja,
       p.nombre_permiso,
       p.nivel_riesgo
FROM asignacion_permisos ap
JOIN usuarios u ON u.id_usuario = ap.id_usuario
JOIN permisos p ON p.id_permiso = ap.id_permiso
WHERE u.estado = 'Inactivo'
  AND p.nivel_riesgo IN ('Alto', 'Crítico')
ORDER BY p.nivel_riesgo DESC, u.nombre;
```

**Resultado** (3 filas):

| nombre | area | fecha_baja | nombre_permiso | nivel_riesgo |
|---|---|---|---|---|
| Paula Vera | Operaciones | 2025-11-04 | Acceso a base de datos de producción | Crítico |
| Valentina López | Tecnología | 2026-06-23 | Administrador de dominio | Crítico |
| Macarena Díaz | Finanzas | 2025-12-08 | Aprobación de pagos | Alto |

**Lectura:** 3 permisos de riesgo siguen vigentes en usuarios dados de baja: Paula Vera (Acceso a base de datos de producción); Valentina López (Administrador de dominio); Macarena Díaz (Aprobación de pagos). Es el control de mayor prioridad: se revocan primero.

![Consulta 8](capturas/08_permisos_riesgo_inactivos.png)

## Consulta 9: Permisos críticos fuera del área Tecnología

**Objetivo:** Revisar usuarios activos con permisos Críticos que no pertenecen al área que normalmente los necesita.  
**Técnicas:** JOIN de tres tablas, filtros múltiples

```sql
SELECT u.nombre,
       u.area,
       u.cargo,
       p.nombre_permiso,
       ap.fecha_otorgado,
       ap.otorgado_por
FROM asignacion_permisos ap
JOIN usuarios u ON u.id_usuario = ap.id_usuario
JOIN permisos p ON p.id_permiso = ap.id_permiso
WHERE p.nivel_riesgo = 'Crítico'
  AND u.area <> 'Tecnología'
  AND u.estado = 'Activo'
ORDER BY u.area, u.nombre;
```

**Resultado** (2 filas):

| nombre | area | cargo | nombre_permiso | fecha_otorgado | otorgado_por |
|---|---|---|---|---|---|
| Cristóbal Torres | Finanzas | Contador | Administrador de dominio | 2024-09-26 | Jefatura TI |
| Gabriel Bravo | Operaciones | Operador | Acceso a base de datos de producción | 2025-11-08 | Jefatura TI |

**Lectura:** 2 usuarios activos fuera de Tecnología tienen permisos críticos: Cristóbal Torres (Finanzas, Administrador de dominio); Gabriel Bravo (Operaciones, Acceso a base de datos de producción). Puede haber una razón válida, pero hay que pedir la justificación.

![Consulta 9](capturas/09_permisos_criticos_fuera_tecnologia.png)

## Consulta 10: Usuarios con más permisos

**Objetivo:** Identificar usuarios con acumulación de permisos (5 o más permisos distintos) y cuántos son de riesgo.  
**Técnicas:** JOIN, GROUP BY, HAVING, COUNT(DISTINCT)

```sql
SELECT u.id_usuario,
       u.nombre,
       u.area,
       COUNT(DISTINCT ap.id_permiso) AS permisos_distintos,
       COUNT(DISTINCT CASE WHEN p.nivel_riesgo IN ('Alto', 'Crítico')
                           THEN ap.id_permiso END) AS permisos_de_riesgo
FROM usuarios u
JOIN asignacion_permisos ap ON ap.id_usuario = u.id_usuario
JOIN permisos p ON p.id_permiso = ap.id_permiso
GROUP BY u.id_usuario, u.nombre, u.area
HAVING COUNT(DISTINCT ap.id_permiso) >= 5
ORDER BY permisos_distintos DESC, u.nombre;
```

**Resultado** (3 filas):

| id_usuario | nombre | area | permisos_distintos | permisos_de_riesgo |
|---|---|---|---|---|
| 1 | Carolina Fuentes | Tecnología | 8 | 5 |
| 3 | Antonia Araya | Tecnología | 5 | 3 |
| 11 | Cristóbal Torres | Finanzas | 5 | 2 |

**Lectura:** 3 usuarios acumulan 5 o más permisos distintos: Carolina Fuentes (8 permisos, 5 de riesgo); Antonia Araya (5 permisos, 3 de riesgo); Cristóbal Torres (5 permisos, 2 de riesgo).

![Consulta 10](capturas/10_usuarios_mas_permisos.png)

## Consulta 11: Asignaciones de permiso duplicadas

**Objetivo:** Detectar el mismo permiso asignado más de una vez al mismo usuario.  
**Técnicas:** JOIN, GROUP BY de dos columnas, HAVING

```sql
SELECT u.nombre,
       p.nombre_permiso,
       COUNT(*)                          AS veces,
       GROUP_CONCAT(ap.id_asignacion, ', ') AS ids_asignacion
FROM asignacion_permisos ap
JOIN usuarios u ON u.id_usuario = ap.id_usuario
JOIN permisos p ON p.id_permiso = ap.id_permiso
GROUP BY ap.id_usuario, ap.id_permiso
HAVING COUNT(*) > 1
ORDER BY u.nombre;
```

**Resultado** (3 filas):

| nombre | nombre_permiso | veces | ids_asignacion |
|---|---|---|---|
| Antonia Araya | Escritura en carpetas compartidas | 2 | 14, 15 |
| Felipe González | Acceso VPN | 2 | 36, 37 |
| Gabriel Bravo | Lectura general | 2 | 70, 71 |

**Lectura:** 3 asignaciones están repetidas: Antonia Araya / Escritura en carpetas compartidas; Felipe González / Acceso VPN; Gabriel Bravo / Lectura general. Es un problema de calidad de datos: no cambia el acceso, pero ensucia el control.

![Consulta 11](capturas/11_asignaciones_duplicadas.png)

## Consulta 12: Permisos de riesgo sin revisión reciente

**Objetivo:** Listar permisos Alto o Crítico de usuarios activos que nunca se revisaron o cuya última revisión supera 365 días.  
**Técnicas:** JOIN, CASE, fechas con julianday

```sql
SELECT u.nombre,
       p.nombre_permiso,
       p.nivel_riesgo,
       ap.ultima_revision,
       CASE WHEN ap.ultima_revision IS NULL THEN 'Nunca revisado'
            ELSE CAST(julianday('2026-10-28') - julianday(ap.ultima_revision) AS INTEGER) || ' días'
       END AS antiguedad_revision
FROM asignacion_permisos ap
JOIN usuarios u ON u.id_usuario = ap.id_usuario
JOIN permisos p ON p.id_permiso = ap.id_permiso
WHERE u.estado = 'Activo'
  AND p.nivel_riesgo IN ('Alto', 'Crítico')
  AND (ap.ultima_revision IS NULL
       OR julianday('2026-10-28') - julianday(ap.ultima_revision) > 365)
ORDER BY p.nivel_riesgo DESC, u.nombre;
```

**Resultado** (8 filas):

| nombre | nombre_permiso | nivel_riesgo | ultima_revision | antiguedad_revision |
|---|---|---|---|---|
| Carolina Fuentes | Administrador de dominio | Crítico | NULL | Nunca revisado |
| Cristóbal Torres | Administrador de dominio | Crítico | NULL | Nunca revisado |
| Carolina Fuentes | Administrador local | Alto | 2025-10-10 | 383 días |
| Carolina Fuentes | Gestión de usuarios | Alto | 2025-07-21 | 464 días |
| Cristóbal Torres | Aprobación de pagos | Alto | NULL | Nunca revisado |
| Felipe González | Administrador local | Alto | 2025-04-20 | 556 días |
| Nicolás Valenzuela | Gestión de usuarios | Alto | NULL | Nunca revisado |
| Valentina Soto | Aprobación de pagos | Alto | NULL | Nunca revisado |

**Lectura:** 8 permisos de riesgo de usuarios activos no tienen revisión vigente; 5 de ellos nunca se revisaron.

![Consulta 12](capturas/12_permisos_sin_revision.png)

## Consulta 13: Resumen de hallazgos

**Objetivo:** Consolidar en una sola tabla la cantidad de casos que dejó cada control.  
**Técnicas:** UNION ALL, subconsultas

```sql
SELECT 'Usuarios duplicados por correo (grupos)' AS hallazgo, COUNT(*) AS casos
FROM (SELECT 1 FROM usuarios GROUP BY LOWER(TRIM(correo)) HAVING COUNT(*) > 1)
UNION ALL
SELECT 'Posibles duplicados por nombre (grupos)', COUNT(*)
FROM (SELECT 1 FROM usuarios GROUP BY LOWER(TRIM(nombre))
      HAVING COUNT(*) > 1 AND COUNT(DISTINCT LOWER(TRIM(correo))) > 1)
UNION ALL
SELECT 'Equipos en uso sin responsable', COUNT(*)
FROM equipos e LEFT JOIN usuarios u ON u.id_usuario = e.id_usuario
WHERE u.id_usuario IS NULL AND e.estado = 'En uso'
UNION ALL
SELECT 'Equipos en uso asignados a usuarios inactivos', COUNT(*)
FROM equipos e JOIN usuarios u ON u.id_usuario = e.id_usuario
WHERE u.estado = 'Inactivo' AND e.estado = 'En uso'
UNION ALL
SELECT 'Permisos de riesgo en usuarios inactivos', COUNT(*)
FROM asignacion_permisos ap
JOIN usuarios u ON u.id_usuario = ap.id_usuario
JOIN permisos p ON p.id_permiso = ap.id_permiso
WHERE u.estado = 'Inactivo' AND p.nivel_riesgo IN ('Alto', 'Crítico')
UNION ALL
SELECT 'Permisos críticos fuera de Tecnología', COUNT(*)
FROM asignacion_permisos ap
JOIN usuarios u ON u.id_usuario = ap.id_usuario
JOIN permisos p ON p.id_permiso = ap.id_permiso
WHERE p.nivel_riesgo = 'Crítico' AND u.area <> 'Tecnología' AND u.estado = 'Activo'
UNION ALL
SELECT 'Usuarios con 5 o más permisos distintos', COUNT(*)
FROM (SELECT 1 FROM asignacion_permisos GROUP BY id_usuario
      HAVING COUNT(DISTINCT id_permiso) >= 5)
UNION ALL
SELECT 'Asignaciones de permiso duplicadas (grupos)', COUNT(*)
FROM (SELECT 1 FROM asignacion_permisos GROUP BY id_usuario, id_permiso HAVING COUNT(*) > 1)
UNION ALL
SELECT 'Permisos de riesgo sin revisión > 365 días', COUNT(*)
FROM asignacion_permisos ap
JOIN usuarios u ON u.id_usuario = ap.id_usuario
JOIN permisos p ON p.id_permiso = ap.id_permiso
WHERE u.estado = 'Activo' AND p.nivel_riesgo IN ('Alto', 'Crítico')
  AND (ap.ultima_revision IS NULL
       OR julianday('2026-10-28') - julianday(ap.ultima_revision) > 365);
```

**Resultado** (9 filas):

| hallazgo | casos |
|---|---|
| Usuarios duplicados por correo (grupos) | 2 |
| Posibles duplicados por nombre (grupos) | 1 |
| Equipos en uso sin responsable | 4 |
| Equipos en uso asignados a usuarios inactivos | 3 |
| Permisos de riesgo en usuarios inactivos | 3 |
| Permisos críticos fuera de Tecnología | 2 |
| Usuarios con 5 o más permisos distintos | 3 |
| Asignaciones de permiso duplicadas (grupos) | 3 |
| Permisos de riesgo sin revisión > 365 días | 8 |

**Lectura:** Resumen de los controles. Prioridad sugerida: primero revocar permisos de riesgo en usuarios inactivos, luego justificar los críticos fuera de Tecnología y revisar los permisos pendientes; después limpiar duplicados y regularizar los equipos.

![Consulta 13](capturas/13_resumen_hallazgos.png)

## Hallazgos y recomendaciones (preliminares)

| Hallazgo | Casos | Prioridad | Recomendación |
|---|---|---|---|
| Usuarios duplicados por correo (grupos) | 2 | Media | Unificar los registros y agregar una restricción UNIQUE sobre el correo normalizado. |
| Posibles duplicados por nombre (grupos) | 1 | Baja | Validar con RR.HH. si es la misma persona o un homónimo. |
| Equipos en uso sin responsable | 4 | Media | Ubicar los equipos y asignarlos formalmente o darlos de baja. |
| Equipos en uso asignados a usuarios inactivos | 3 | Media | Recuperar los equipos y reasignarlos; incluirlo en el proceso de desvinculación. |
| Permisos de riesgo en usuarios inactivos | 3 | Alta | Revocar de inmediato y revisar si hubo uso posterior a la baja. |
| Permisos críticos fuera de Tecnología | 2 | Alta | Pedir justificación y aprobación formal; retirar si no se justifica. |
| Usuarios con 5 o más permisos distintos | 3 | Media | Revisar el principio de mínimo privilegio y depurar permisos no necesarios. |
| Asignaciones de permiso duplicadas (grupos) | 3 | Baja | Eliminar los registros repetidos y agregar UNIQUE (id_usuario, id_permiso). |
| Permisos de riesgo sin revisión > 365 días | 8 | Media | Hacer la recertificación de accesos y definir un ciclo de revisión. |

## Limitaciones

- Datos ficticios con errores sembrados a propósito; las cantidades no representan una organización real.
- Las prioridades son un criterio preliminar. Antes de reportar un hallazgo habría que confirmarlo con evidencia (actas, directorio, registros de acceso).
- Los criterios (por ejemplo, que los permisos críticos son propios del área Tecnología) son supuestos del ejercicio.
