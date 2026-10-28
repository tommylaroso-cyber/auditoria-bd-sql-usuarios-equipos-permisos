-- =====================================================================
-- 01_esquema.sql
-- Laboratorio: Revisión de una base de datos con SQL
-- Motor: SQLite 3 (también compatible con DB Browser for SQLite)
-- Datos 100% ficticios. Fecha de corte de la revisión: 2026-10-28
-- =====================================================================
-- NOTA DE DISEÑO: 'usuarios.correo' y 'asignacion_permisos' NO tienen
-- restricciones UNIQUE a propósito, para poder practicar la detección de
-- duplicados. En un sistema real se agregarían para evitarlos.
-- =====================================================================

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS asignacion_permisos;
DROP TABLE IF EXISTS equipos;
DROP TABLE IF EXISTS permisos;
DROP TABLE IF EXISTS usuarios;

CREATE TABLE usuarios (
    id_usuario     INTEGER PRIMARY KEY,
    nombre         TEXT NOT NULL,
    correo         TEXT NOT NULL,
    area           TEXT NOT NULL,
    cargo          TEXT NOT NULL,
    estado         TEXT NOT NULL CHECK (estado IN ('Activo', 'Inactivo')),
    fecha_ingreso  TEXT NOT NULL,          -- formato AAAA-MM-DD
    fecha_baja     TEXT                    -- NULL si sigue activo
);

CREATE TABLE equipos (
    id_equipo          INTEGER PRIMARY KEY,
    nombre_equipo      TEXT NOT NULL UNIQUE,
    tipo               TEXT NOT NULL CHECK (tipo IN ('Notebook', 'Escritorio', 'Servidor')),
    sistema_operativo  TEXT NOT NULL,
    id_usuario         INTEGER REFERENCES usuarios (id_usuario),   -- NULL = sin responsable
    fecha_compra       TEXT NOT NULL,
    estado             TEXT NOT NULL CHECK (estado IN ('En uso', 'En bodega', 'Baja'))
);

CREATE TABLE permisos (
    id_permiso      INTEGER PRIMARY KEY,
    nombre_permiso  TEXT NOT NULL UNIQUE,
    descripcion     TEXT NOT NULL,
    nivel_riesgo    TEXT NOT NULL CHECK (nivel_riesgo IN ('Bajo', 'Medio', 'Alto', 'Crítico'))
);

CREATE TABLE asignacion_permisos (
    id_asignacion    INTEGER PRIMARY KEY,
    id_usuario       INTEGER NOT NULL REFERENCES usuarios (id_usuario),
    id_permiso       INTEGER NOT NULL REFERENCES permisos (id_permiso),
    fecha_otorgado   TEXT NOT NULL,
    otorgado_por     TEXT NOT NULL,
    ultima_revision  TEXT                  -- NULL = nunca revisado
);
