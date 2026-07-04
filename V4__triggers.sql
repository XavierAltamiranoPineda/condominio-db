-- ============================================================
-- V4__triggers.sql
-- Solo los usos que se acordó son legítimos para triggers:
-- auditoría, validaciones críticas de integridad, y generación
-- de historial/estado derivado. Nada de lógica de negocio de
-- cálculo (eso vive en V5__functions.sql y en la API).
-- ============================================================

-- ------------------------------------------------------------
-- Validación crítica: si una unidad tiene torre, esa torre debe
-- pertenecer al mismo condominio que la unidad.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_chk_unidad_torre_condominio()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id_torre IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM torre
            WHERE id_torre = NEW.id_torre AND id_condominio = NEW.id_condominio
        ) THEN
            RAISE EXCEPTION 'La torre % no pertenece al condominio %', NEW.id_torre, NEW.id_condominio;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_unidad_torre_condominio
BEFORE INSERT OR UPDATE ON unidad
FOR EACH ROW EXECUTE FUNCTION fn_chk_unidad_torre_condominio();

-- ------------------------------------------------------------
-- Reserva: una reserva CANCELADA/RECHAZADA deja de bloquear
-- el horario para otras personas (usado por el EXCLUDE de V2).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_reserva_bloqueo()
RETURNS TRIGGER AS $$
DECLARE
    v_estado VARCHAR;
BEGIN
    SELECT nombre INTO v_estado FROM estado_reserva WHERE id_estado = NEW.id_estado;
    NEW.bloquea_horario := (v_estado NOT IN ('CANCELADA', 'RECHAZADA'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reserva_bloqueo
BEFORE INSERT OR UPDATE OF id_estado ON reserva
FOR EACH ROW EXECUTE FUNCTION fn_reserva_bloqueo();

-- ------------------------------------------------------------
-- Ticket: mantener id_estado_actual sincronizado con el último
-- registro de historial_ticket (evita un JOIN en cada listado).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_estado_actual_ticket()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE ticket SET id_estado_actual = NEW.id_estado WHERE id_ticket = NEW.id_ticket;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_estado_ticket
AFTER INSERT ON historial_ticket
FOR EACH ROW EXECUTE FUNCTION fn_sync_estado_actual_ticket();

-- ------------------------------------------------------------
-- Auditoría genérica. Busca dinámicamente la PK de la tabla
-- (asume PK simple de una columna) y registra antes/después.
-- La API debe hacer `SET LOCAL app.usuario_actual = '<id>'`
-- al inicio de cada transacción para que quede el autor real;
-- si no se setea, id_usuario queda NULL.
-- Aplicada aquí a un subconjunto de tablas sensibles a modo de
-- ejemplo: se puede replicar el mismo patrón a otras tablas.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_auditoria()
RETURNS TRIGGER AS $$
DECLARE
    v_usuario     BIGINT;
    v_pk_column   TEXT;
    v_id_registro BIGINT;
    v_row         JSONB;
BEGIN
    BEGIN
        v_usuario := NULLIF(current_setting('app.usuario_actual', true), '')::BIGINT;
    EXCEPTION WHEN OTHERS THEN
        v_usuario := NULL;
    END;

    SELECT kcu.column_name INTO v_pk_column
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
    WHERE tc.table_name = TG_TABLE_NAME
      AND tc.constraint_type = 'PRIMARY KEY'
    LIMIT 1;

    v_row := to_jsonb(COALESCE(NEW, OLD));
    v_id_registro := NULLIF(v_row ->> v_pk_column, '')::BIGINT;

    INSERT INTO auditoria (tabla_afectada, id_registro, accion, id_usuario, valores_anteriores, valores_nuevos, fecha)
    VALUES (
        TG_TABLE_NAME,
        v_id_registro,
        TG_OP::accion_auditoria_enum,
        v_usuario,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('UPDATE', 'INSERT') THEN to_jsonb(NEW) ELSE NULL END,
        now()
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_cuota
AFTER INSERT OR UPDATE OR DELETE ON cuota
FOR EACH ROW EXECUTE FUNCTION fn_auditoria();

CREATE TRIGGER trg_auditoria_pago
AFTER INSERT OR UPDATE OR DELETE ON pago
FOR EACH ROW EXECUTE FUNCTION fn_auditoria();

CREATE TRIGGER trg_auditoria_unidad
AFTER INSERT OR UPDATE OR DELETE ON unidad
FOR EACH ROW EXECUTE FUNCTION fn_auditoria();

CREATE TRIGGER trg_auditoria_persona_unidad
AFTER INSERT OR UPDATE OR DELETE ON persona_unidad
FOR EACH ROW EXECUTE FUNCTION fn_auditoria();

CREATE TRIGGER trg_auditoria_multa
AFTER INSERT OR UPDATE OR DELETE ON multa
FOR EACH ROW EXECUTE FUNCTION fn_auditoria();

-- Nota: NO se aplicó a `usuario` porque el row completo (con
-- password_hash) quedaría duplicado en auditoria.valores_*.
-- Si se necesita auditar usuario, hacerlo con una versión de
-- fn_auditoria() que excluya esa columna del JSONB.
