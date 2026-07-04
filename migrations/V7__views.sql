-- ============================================================
-- V7__views.sql
-- Vistas que simplifican los endpoints más comunes de la API.
-- ============================================================

-- Estado de cuenta por unidad, con propietario activo y saldo.
CREATE VIEW vw_estado_cuenta AS
SELECT
    u.id_unidad,
    u.numero AS unidad,
    p.nombres || ' ' || p.apellidos AS propietario,
    saldo_unidad(u.id_unidad) AS saldo_pendiente
FROM unidad u
LEFT JOIN persona_unidad pu
    ON pu.id_unidad = u.id_unidad AND pu.tipo = 'PROPIETARIO' AND pu.estado = 'ACTIVO'
LEFT JOIN persona p ON p.id_persona = pu.id_persona;

-- Unidades marcadas como OCUPADA.
CREATE VIEW vw_unidades_ocupadas AS
SELECT u.id_unidad, u.numero, eu.nombre AS estado, c.nombre AS condominio
FROM unidad u
JOIN estado_unidad eu ON eu.id_estado = u.id_estado
JOIN condominio c ON c.id_condominio = u.id_condominio
WHERE eu.nombre = 'OCUPADA';

-- Reservas del día actual, ordenadas por hora.
CREATE VIEW vw_reservas_hoy AS
SELECT
    r.id_reserva,
    ac.nombre AS area,
    p.nombres || ' ' || p.apellidos AS solicitante,
    r.hora_inicio, r.hora_fin,
    er.nombre AS estado
FROM reserva r
JOIN area_comun ac ON ac.id_area = r.id_area
JOIN persona p ON p.id_persona = r.id_persona
JOIN estado_reserva er ON er.id_estado = r.id_estado
WHERE r.fecha = CURRENT_DATE
ORDER BY r.hora_inicio;

-- Resumen de tickets con estado actual (usa la columna
-- denormalizada, sin JOIN contra historial_ticket).
CREATE VIEW vw_ticket_resumen AS
SELECT
    t.id_ticket, t.titulo, t.prioridad,
    et.nombre AS estado_actual,
    p.nombres || ' ' || p.apellidos AS reportante,
    tec.nombres || ' ' || tec.apellidos AS tecnico,
    t.fecha_creacion, t.fecha_cierre
FROM ticket t
LEFT JOIN estado_ticket et ON et.id_estado = t.id_estado_actual
JOIN persona p ON p.id_persona = t.id_persona
LEFT JOIN persona tec ON tec.id_persona = t.id_tecnico;

-- Cuotas pendientes/vencidas con la mora ya calculada.
CREATE VIEW vw_pagos_pendientes AS
SELECT
    c.id_cuota, u.numero AS unidad, c.tipo, c.valor, c.fecha_vencimiento,
    calcular_mora(c.id_cuota) AS mora_calculada
FROM cuota c
JOIN unidad u ON u.id_unidad = c.id_unidad
WHERE c.estado IN ('PENDIENTE', 'VENCIDA');

-- Visitantes actualmente dentro del condominio (sin salida registrada).
CREATE VIEW vw_visitantes_dentro AS
SELECT a.id_acceso, v.nombre AS visitante, u.numero AS unidad, a.hora_ingreso
FROM acceso a
JOIN visitante v ON v.id_visitante = a.id_visitante
JOIN unidad u ON u.id_unidad = a.id_unidad
JOIN estado_acceso ea ON ea.id_estado = a.id_estado
WHERE ea.nombre = 'EN_CURSO';
