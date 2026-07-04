-- ============================================================
-- V6__seed.sql
-- Datos iniciales: catálogos, roles, permisos, configuración.
-- Nada de esto debería crearse a mano desde la aplicación.
-- ============================================================

-- ---------- Catálogos de estado ----------
INSERT INTO estado_unidad (nombre) VALUES ('DISPONIBLE'), ('OCUPADA'), ('EN_VENTA'), ('EN_ARRIENDO');
INSERT INTO estado_reserva (nombre) VALUES ('PENDIENTE'), ('APROBADA'), ('RECHAZADA'), ('CANCELADA');
INSERT INTO estado_pago (nombre) VALUES ('PENDIENTE'), ('CONFIRMADO'), ('RECHAZADO'), ('ANULADO');
INSERT INTO estado_acceso (nombre) VALUES ('EN_CURSO'), ('FINALIZADO'), ('CANCELADO');
INSERT INTO estado_ticket (nombre) VALUES ('ABIERTO'), ('EN_PROCESO'), ('RESUELTO'), ('CERRADO');

-- ---------- Categorías de mantenimiento ----------
INSERT INTO categoria (nombre) VALUES
    ('Plomería'), ('Electricidad'), ('Cerrajería'), ('Jardinería'),
    ('Ascensores'), ('Limpieza'), ('Áreas comunes'), ('Otro');

-- ---------- Configuración del sistema ----------
INSERT INTO configuracion (clave, valor) VALUES
    ('DIAS_MORA', '30'),
    ('PORCENTAJE_INTERES', '5'),
    ('VALOR_CUOTA_BASE', '100'),
    ('SMTP_HOST', 'smtp.condominio.com'),
    ('SMTP_PUERTO', '587'),
    ('HORAS_LIMITE_VISITA', '24');

-- ---------- Roles (según los 10 tipos de usuario definidos) ----------
INSERT INTO rol (nombre, descripcion) VALUES
    ('ADMIN',        'Administrador del sistema con acceso total'),
    ('SINDICO',      'Síndico o presidente de junta directiva'),
    ('CONTADOR',     'Contador responsable de finanzas'),
    ('TESORERO',     'Responsable de cobranza y tesorería'),
    ('PROPIETARIO',  'Dueño de unidad inmobiliaria'),
    ('ARRENDATARIO', 'Inquilino registrado'),
    ('RESIDENTE',    'Persona viviendo en la propiedad'),
    ('SEGURIDAD',    'Personal de seguridad/portería'),
    ('TECNICO',      'Técnico de mantenimiento'),
    ('PROVEEDOR',    'Empresa proveedora de servicios (acceso limitado)');

-- ---------- Permisos: CRUD por módulo ----------
DO $$
DECLARE
    v_modulos TEXT[] := ARRAY[
        'RESIDENTES', 'UNIDADES', 'CUOTAS', 'PAGOS', 'TICKETS',
        'RESERVAS', 'VISITAS', 'COMUNICADOS', 'ASAMBLEAS',
        'REPORTES', 'USUARIOS', 'CONFIGURACION'
    ];
    v_acciones TEXT[] := ARRAY['CREAR', 'LEER', 'EDITAR', 'ELIMINAR'];
    v_modulo TEXT;
    v_accion TEXT;
BEGIN
    FOREACH v_modulo IN ARRAY v_modulos LOOP
        FOREACH v_accion IN ARRAY v_acciones LOOP
            INSERT INTO permiso (nombre, modulo, accion)
            VALUES (v_modulo || '_' || v_accion, v_modulo, v_accion)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- ADMIN recibe todos los permisos generados
INSERT INTO rol_permiso (id_rol, id_permiso)
SELECT (SELECT id_rol FROM rol WHERE nombre = 'ADMIN'), id_permiso FROM permiso;

-- SINDICO: todo menos USUARIOS_ELIMINAR y CONFIGURACION
INSERT INTO rol_permiso (id_rol, id_permiso)
SELECT (SELECT id_rol FROM rol WHERE nombre = 'SINDICO'), id_permiso
FROM permiso
WHERE modulo NOT IN ('CONFIGURACION')
  AND NOT (modulo = 'USUARIOS' AND accion = 'ELIMINAR');

-- TESORERO: cuotas y pagos
INSERT INTO rol_permiso (id_rol, id_permiso)
SELECT (SELECT id_rol FROM rol WHERE nombre = 'TESORERO'), id_permiso
FROM permiso
WHERE modulo IN ('CUOTAS', 'PAGOS', 'REPORTES');

-- RESIDENTE: solo lectura de lo propio + crear tickets/reservas
INSERT INTO rol_permiso (id_rol, id_permiso)
SELECT (SELECT id_rol FROM rol WHERE nombre = 'RESIDENTE'), id_permiso
FROM permiso
WHERE (modulo IN ('TICKETS', 'RESERVAS') AND accion IN ('CREAR', 'LEER'))
   OR (modulo = 'COMUNICADOS' AND accion = 'LEER');
