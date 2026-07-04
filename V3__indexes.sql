-- ============================================================
-- V3__indexes.sql
-- Índices de performance (no de integridad).
-- ============================================================

CREATE INDEX idx_usuario_username         ON usuario(username);
CREATE INDEX idx_pago_fecha               ON pago(fecha);
CREATE INDEX idx_historial_ticket         ON historial_ticket(id_ticket);
CREATE INDEX idx_reserva_fecha            ON reserva(fecha);
CREATE INDEX idx_persona_identificacion   ON persona(numero_identificacion);
CREATE INDEX idx_vehiculo_placa_lookup    ON vehiculo(placa);
CREATE INDEX idx_cuota_unidad_periodo     ON cuota(id_unidad, anio, mes);
CREATE INDEX idx_login_usuario_fecha      ON login(id_usuario, fecha);
CREATE INDEX idx_ticket_unidad            ON ticket(id_unidad);
CREATE INDEX idx_ticket_persona           ON ticket(id_persona);
CREATE INDEX idx_acceso_unidad            ON acceso(id_unidad);
CREATE INDEX idx_acceso_hora_ingreso      ON acceso(hora_ingreso);
CREATE INDEX idx_auditoria_tabla_registro ON auditoria(tabla_afectada, id_registro);
CREATE INDEX idx_notificacion_persona     ON notificacion(id_persona, leido);
CREATE INDEX idx_persona_unidad_unidad    ON persona_unidad(id_unidad);
CREATE INDEX idx_persona_unidad_persona   ON persona_unidad(id_persona);
CREATE INDEX idx_cuota_estado             ON cuota(estado);
CREATE INDEX idx_multa_unidad             ON multa(id_unidad);
