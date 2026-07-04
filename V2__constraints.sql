-- ============================================================
-- V2__constraints.sql
-- Reglas de negocio que van más allá de PK/FK simples:
-- UNIQUE compuestos, índices únicos parciales y EXCLUDE.
-- ============================================================

-- Evitar nombres de torre duplicados dentro del mismo condominio
ALTER TABLE torre ADD CONSTRAINT uq_torre_condominio_nombre UNIQUE (id_condominio, nombre);

-- Evitar numeración de parqueadero duplicada dentro de la misma unidad
ALTER TABLE parqueadero ADD CONSTRAINT uq_parqueadero_unidad_numero UNIQUE (id_unidad, numero);

-- Evitar nombres de área común duplicados dentro del mismo condominio
ALTER TABLE area_comun ADD CONSTRAINT uq_area_condominio_nombre UNIQUE (id_condominio, nombre);

-- Placa única solo cuando existe (bicicletas/scooters pueden no tener placa)
CREATE UNIQUE INDEX uq_vehiculo_placa ON vehiculo(placa) WHERE placa IS NOT NULL;

-- Evitar cuotas duplicadas del mismo tipo/unidad/periodo
ALTER TABLE cuota ADD CONSTRAINT uq_cuota_unidad_periodo_tipo UNIQUE (id_unidad, mes, anio, tipo);

-- Impedir dos titulares ACTIVOS simultáneos del mismo tipo en la misma unidad.
-- RESIDENTE se excluye a propósito: puede haber varios residentes activos
-- (ej. una familia completa viviendo en la misma unidad).
CREATE UNIQUE INDEX uq_personaunidad_titular_activo
    ON persona_unidad(id_unidad, tipo)
    WHERE estado = 'ACTIVO' AND tipo IN ('PROPIETARIO', 'ARRENDATARIO');

-- ------------------------------------------------------------
-- Reserva: impedir doble reserva del mismo área en horario solapado.
-- Un UNIQUE no alcanza porque "solapado" no es "igual". Se usa un
-- EXCLUDE sobre el rango de tiempo (columna `periodo`, generada
-- en V1 a partir de fecha + hora_inicio/hora_fin).
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE reserva ADD CONSTRAINT reserva_no_solape
    EXCLUDE USING gist (id_area WITH =, periodo WITH &&)
    WHERE (bloquea_horario);
