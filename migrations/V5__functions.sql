-- ============================================================
-- V5__functions.sql
-- Funciones almacenadas de lógica de dominio reutilizable
-- entre reportes, vistas y la API.
-- ============================================================

-- Calcula la mora de una cuota específica según DIAS_MORA y
-- PORCENTAJE_INTERES configurados en la tabla `configuracion`.
CREATE OR REPLACE FUNCTION calcular_mora(p_id_cuota BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    v_cuota        RECORD;
    v_dias_mora    INT;
    v_dias_vencido INT;
    v_porcentaje   NUMERIC;
    v_mora         NUMERIC := 0;
BEGIN
    SELECT * INTO v_cuota FROM cuota WHERE id_cuota = p_id_cuota;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuota % no existe', p_id_cuota;
    END IF;

    IF v_cuota.estado NOT IN ('PENDIENTE', 'VENCIDA') THEN
        RETURN 0;
    END IF;

    v_dias_vencido := GREATEST(0, CURRENT_DATE - v_cuota.fecha_vencimiento);

    SELECT valor::INT INTO v_dias_mora FROM configuracion WHERE clave = 'DIAS_MORA';
    SELECT valor::NUMERIC INTO v_porcentaje FROM configuracion WHERE clave = 'PORCENTAJE_INTERES';

    IF v_dias_vencido > COALESCE(v_dias_mora, 30) THEN
        v_mora := ROUND(v_cuota.valor * COALESCE(v_porcentaje, 0) / 100, 2);
    END IF;

    RETURN v_mora;
END;
$$ LANGUAGE plpgsql;

-- Genera las cuotas del mes/año/tipo para todas las unidades,
-- prorrateadas por alícuota sobre un valor base (parámetro o
-- tomado de configuracion.VALOR_CUOTA_BASE). Omite silenciosamente
-- las unidades que ya tienen cuota de ese tipo/periodo (UNIQUE
-- de V2 lo impide). Retorna cuántas se crearon.
CREATE OR REPLACE FUNCTION generar_cuotas_mes(
    p_mes INTEGER,
    p_anio INTEGER,
    p_tipo tipo_cuota_enum DEFAULT 'ORDINARIA',
    p_valor_base NUMERIC DEFAULT NULL
) RETURNS INT AS $$
DECLARE
    v_unidad          RECORD;
    v_valor           NUMERIC;
    v_creadas         INT := 0;
    v_valor_base_cfg  NUMERIC;
    v_base            NUMERIC;
BEGIN
    v_base := p_valor_base;
    IF v_base IS NULL THEN
        SELECT valor::NUMERIC INTO v_valor_base_cfg FROM configuracion WHERE clave = 'VALOR_CUOTA_BASE';
        v_base := COALESCE(v_valor_base_cfg, 0);
    END IF;

    FOR v_unidad IN SELECT id_unidad, alicuota FROM unidad LOOP
        v_valor := ROUND(v_base * COALESCE(v_unidad.alicuota, 1), 2);
        BEGIN
            INSERT INTO cuota (id_unidad, mes, anio, valor, tipo, fecha_vencimiento, estado)
            VALUES (
                v_unidad.id_unidad, p_mes, p_anio, v_valor, p_tipo,
                (make_date(p_anio, p_mes, 1) + INTERVAL '1 month' - INTERVAL '1 day')::DATE,
                'PENDIENTE'
            );
            v_creadas := v_creadas + 1;
        EXCEPTION WHEN unique_violation THEN
            CONTINUE;
        END;
    END LOOP;

    RETURN v_creadas;
END;
$$ LANGUAGE plpgsql;

-- Cierra automáticamente accesos abiertos (visitas sin salida
-- registrada) más allá de un límite de horas. Pensado para un
-- job programado, no para uso interactivo desde la API.
CREATE OR REPLACE FUNCTION cerrar_visitas(p_horas_limite INT DEFAULT 24)
RETURNS INT AS $$
DECLARE
    v_id_finalizado BIGINT;
    v_cerradas      INT;
BEGIN
    SELECT id_estado INTO v_id_finalizado FROM estado_acceso WHERE nombre = 'FINALIZADO';

    UPDATE acceso
    SET hora_salida = now(), id_estado = v_id_finalizado
    WHERE hora_salida IS NULL
      AND hora_ingreso < now() - (p_horas_limite || ' hours')::INTERVAL;

    GET DIAGNOSTICS v_cerradas = ROW_COUNT;
    RETURN v_cerradas;
END;
$$ LANGUAGE plpgsql;

-- Verifica si un área común está libre en un rango de fecha/hora,
-- usando el mismo criterio de solape que el EXCLUDE de reserva.
CREATE OR REPLACE FUNCTION disponibilidad_area(
    p_area BIGINT, p_fecha DATE, p_hora_inicio TIME, p_hora_fin TIME
) RETURNS BOOLEAN AS $$
DECLARE
    v_conflictos INT;
BEGIN
    SELECT COUNT(*) INTO v_conflictos
    FROM reserva
    WHERE id_area = p_area
      AND bloquea_horario
      AND periodo && tsrange(p_fecha + p_hora_inicio, p_fecha + p_hora_fin);

    RETURN v_conflictos = 0;
END;
$$ LANGUAGE plpgsql;

-- Saldo pendiente de una unidad: suma de cuotas PENDIENTE/VENCIDA
-- menos pagos ya CONFIRMADOs sobre esas mismas cuotas.
CREATE OR REPLACE FUNCTION saldo_unidad(p_id_unidad BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    v_deuda  NUMERIC;
    v_pagado NUMERIC;
BEGIN
    SELECT COALESCE(SUM(valor), 0) INTO v_deuda
    FROM cuota WHERE id_unidad = p_id_unidad AND estado IN ('PENDIENTE', 'VENCIDA');

    SELECT COALESCE(SUM(p.valor), 0) INTO v_pagado
    FROM pago p
    JOIN cuota c ON c.id_cuota = p.id_cuota
    JOIN estado_pago ep ON ep.id_estado = p.id_estado
    WHERE c.id_unidad = p_id_unidad
      AND ep.nombre = 'CONFIRMADO'
      AND c.estado IN ('PENDIENTE', 'VENCIDA');

    RETURN v_deuda - v_pagado;
END;
$$ LANGUAGE plpgsql;

-- Historial completo de unidades por las que ha pasado una persona.
CREATE OR REPLACE FUNCTION historial_residente(p_id_persona BIGINT)
RETURNS TABLE (
    id_unidad     BIGINT,
    numero_unidad VARCHAR,
    tipo          tipo_persona_unidad_enum,
    estado        estado_persona_unidad_enum,
    fecha_inicio  DATE,
    fecha_fin     DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT u.id_unidad, u.numero, pu.tipo, pu.estado, pu.fecha_inicio, pu.fecha_fin
    FROM persona_unidad pu
    JOIN unidad u ON u.id_unidad = pu.id_unidad
    WHERE pu.id_persona = p_id_persona
    ORDER BY pu.fecha_inicio DESC;
END;
$$ LANGUAGE plpgsql;
