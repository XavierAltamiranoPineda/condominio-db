-- ============================================================
-- drop_all.sql (dev-scripts/, NO es una migración Flyway)
-- Elimina TODO el esquema para reconstruir desde cero durante
-- el desarrollo. Después de correr esto, vuelvan a aplicar
-- V1..V7 (y test_data.sql si quieren datos de prueba).
--
-- ADVERTENCIA: esto borra TODOS los datos sin posibilidad de
-- deshacer. NUNCA correr contra una base de datos de producción
-- o de staging compartido.
-- ============================================================

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO public;

-- Si usan Flyway, también limpien su tabla de historial para que
-- vuelva a aplicar las migraciones desde V1:
-- DROP TABLE IF EXISTS flyway_schema_history;
