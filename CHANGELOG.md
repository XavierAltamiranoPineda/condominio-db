# Changelog — condominio-db

Todas las decisiones de diseño relevantes de este esquema quedan
registradas aquí, además del historial de migraciones de Flyway.

## [Sin publicar]

### Agregado
- `V1__schema.sql`: 21 tipos ENUM, 44 tablas cubriendo autenticación,
  personas, condominio/unidades, finanzas, mantenimiento, seguridad,
  reservas, comunicación, asambleas, archivos y auditoría.
- `V2__constraints.sql`: UNIQUE compuestos (torre, parqueadero,
  área común, cuota), índice único parcial para placa de vehículo,
  índice único parcial para evitar dos titulares (`PROPIETARIO`/
  `ARRENDATARIO`) activos simultáneos en una misma unidad, y
  `EXCLUDE USING gist` para impedir reservas solapadas por área.
- `V3__indexes.sql`: índices de performance sobre las columnas de
  consulta más frecuente.
- `V4__triggers.sql`: integridad torre↔unidad↔condominio, bloqueo
  automático de horario en reservas canceladas/rechazadas,
  sincronización de `ticket.id_estado_actual`, y auditoría genérica
  (aplicada a `cuota`, `pago`, `unidad`, `persona_unidad`, `multa`).
- `V5__functions.sql`: `calcular_mora`, `generar_cuotas_mes`,
  `cerrar_visitas`, `disponibilidad_area`, `saldo_unidad`,
  `historial_residente`.
- `V6__seed.sql`: catálogos de estado, categorías de mantenimiento,
  configuración inicial, 10 roles, permisos CRUD por módulo.
- `V7__views.sql`: `vw_estado_cuenta`, `vw_unidades_ocupadas`,
  `vw_reservas_hoy`, `vw_ticket_resumen`, `vw_pagos_pendientes`,
  `vw_visitantes_dentro`.
- `dev-scripts/test_data.sql`: datos ficticios (30 personas,
  24 unidades, cuotas de 3 meses, tickets, visitas, reservas,
  asamblea) para desarrollo local.
- `dev-scripts/drop_all.sql`: reset completo del esquema para
  desarrollo local.

### Decisiones de diseño notables
- `Comunicado.destinatario_id` es una FK polimórfica (según
  `destinatario_tipo`), validada en la API, no en la BD — trade-off
  aceptado para el alcance del proyecto.
- `Unidad.id_condominio` se mantiene como fuente de verdad aunque
  exista `Unidad.id_torre`, para soportar condominios de casas sin
  torres y edificios con torres en el mismo modelo. Integridad
  garantizada por trigger, no por FK compuesta.
- Auditoría genérica (`fn_auditoria`) deliberadamente NO se aplicó a
  `usuario` para evitar duplicar `password_hash` en el log.

### Bugs encontrados y corregidos durante el desarrollo
- `generar_cuotas_mes(p_mes SMALLINT, p_anio SMALLINT, ...)` fallaba
  al invocarse con literales enteros comunes, porque
  `INTEGER → SMALLINT` no es un cast implícito válido para
  resolución de sobrecarga de funciones en Postgres (sí lo es para
  columnas de tabla vía INSERT/UPDATE). Corregido usando `INTEGER`
  en la firma de la función.
