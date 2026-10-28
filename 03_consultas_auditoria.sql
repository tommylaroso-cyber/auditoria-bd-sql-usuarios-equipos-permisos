-- =====================================================================
-- 03_consultas_auditoria.sql
-- Consultas de revisión sobre usuarios, equipos y permisos (SQLite 3).
-- Ejecutar DESPUÉS de 01_esquema.sql y 02_datos_prueba.sql.
-- Fecha de corte usada en las consultas con fechas: '2026-10-28'
-- (cámbiala por otra fecha si quieres repetir el análisis).
-- Funciones propias de SQLite: julianday() y GROUP_CONCAT().
-- =====================================================================


-- ---------------------------------------------------------------------
-- Consulta 1: Conteo de registros por tabla
-- Objetivo: Verificar que la carga de datos de prueba quedó completa en las cuatro tablas.
-- Técnicas: SELECT, COUNT, UNION ALL
-- ---------------------------------------------------------------------
SELECT 'usuarios' AS tabla, COUNT(*) AS registros FROM usuarios
UNION ALL
SELECT 'equipos', COUNT(*) FROM equipos
UNION ALL
SELECT 'permisos', COUNT(*) FROM permisos
UNION ALL
SELECT 'asignacion_permisos', COUNT(*) FROM asignacion_permisos;

-- ---------------------------------------------------------------------
-- Consulta 2: Usuarios por área y estado
-- Objetivo: Conocer cómo se distribuyen los usuarios activos e inactivos por área.
-- Técnicas: GROUP BY, SUM + CASE
-- ---------------------------------------------------------------------
SELECT area,
       COUNT(*) AS total,
       SUM(CASE WHEN estado = 'Activo'   THEN 1 ELSE 0 END) AS activos,
       SUM(CASE WHEN estado = 'Inactivo' THEN 1 ELSE 0 END) AS inactivos
FROM usuarios
GROUP BY area
ORDER BY total DESC, area;

-- ---------------------------------------------------------------------
-- Consulta 3: Equipos con su responsable
-- Objetivo: Listar cada equipo con la persona a la que está asignado, incluyendo los que no tienen responsable.
-- Técnicas: LEFT JOIN, COALESCE
-- ---------------------------------------------------------------------
SELECT e.id_equipo,
       e.nombre_equipo,
       e.tipo,
       e.estado,
       COALESCE(u.nombre, 'SIN RESPONSABLE') AS responsable,
       u.estado AS estado_usuario
FROM equipos e
LEFT JOIN usuarios u ON u.id_usuario = e.id_usuario
ORDER BY e.id_equipo;

-- ---------------------------------------------------------------------
-- Consulta 4: Usuarios duplicados por correo
-- Objetivo: Detectar personas registradas más de una vez con el mismo correo, ignorando mayúsculas y espacios.
-- Técnicas: GROUP BY, HAVING, LOWER/TRIM, GROUP_CONCAT
-- ---------------------------------------------------------------------
SELECT LOWER(TRIM(correo))        AS correo_normalizado,
       COUNT(*)                   AS registros,
       GROUP_CONCAT(id_usuario, ', ') AS ids_usuario
FROM usuarios
GROUP BY LOWER(TRIM(correo))
HAVING COUNT(*) > 1;

-- ---------------------------------------------------------------------
-- Consulta 5: Posibles duplicados por nombre
-- Objetivo: Encontrar personas con el mismo nombre pero correos distintos: pueden ser duplicados o simples homónimos.
-- Técnicas: GROUP BY, HAVING, COUNT(DISTINCT)
-- ---------------------------------------------------------------------
SELECT nombre,
       COUNT(*)                        AS registros,
       GROUP_CONCAT(id_usuario, ', ')  AS ids_usuario,
       GROUP_CONCAT(correo, ' | ')     AS correos
FROM usuarios
GROUP BY LOWER(TRIM(nombre))
HAVING COUNT(*) > 1
   AND COUNT(DISTINCT LOWER(TRIM(correo))) > 1;

-- ---------------------------------------------------------------------
-- Consulta 6: Equipos en uso sin responsable
-- Objetivo: Identificar equipos marcados 'En uso' que no tienen un usuario asignado válido.
-- Técnicas: LEFT JOIN + IS NULL (anti-join)
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Consulta 7: Equipos asignados a usuarios inactivos
-- Objetivo: Detectar equipos en uso cuyo responsable ya fue dado de baja.
-- Técnicas: JOIN, WHERE, julianday
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Consulta 8: Permisos de riesgo en usuarios inactivos
-- Objetivo: Encontrar permisos Alto o Crítico que siguen vigentes en usuarios dados de baja.
-- Técnicas: JOIN de tres tablas, IN
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Consulta 9: Permisos críticos fuera del área Tecnología
-- Objetivo: Revisar usuarios activos con permisos Críticos que no pertenecen al área que normalmente los necesita.
-- Técnicas: JOIN de tres tablas, filtros múltiples
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Consulta 10: Usuarios con más permisos
-- Objetivo: Identificar usuarios con acumulación de permisos (5 o más permisos distintos) y cuántos son de riesgo.
-- Técnicas: JOIN, GROUP BY, HAVING, COUNT(DISTINCT)
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Consulta 11: Asignaciones de permiso duplicadas
-- Objetivo: Detectar el mismo permiso asignado más de una vez al mismo usuario.
-- Técnicas: JOIN, GROUP BY de dos columnas, HAVING
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Consulta 12: Permisos de riesgo sin revisión reciente
-- Objetivo: Listar permisos Alto o Crítico de usuarios activos que nunca se revisaron o cuya última revisión supera 365 días.
-- Técnicas: JOIN, CASE, fechas con julianday
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Consulta 13: Resumen de hallazgos
-- Objetivo: Consolidar en una sola tabla la cantidad de casos que dejó cada control.
-- Técnicas: UNION ALL, subconsultas
-- ---------------------------------------------------------------------
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
