-- ============================================================
-- test_data.sql (dev-scripts/, NO es una migración Flyway)
-- Datos ficticios para desarrollo local y pruebas de la API.
-- Requiere que V1..V7 ya se hayan aplicado.
-- NUNCA correr contra una base de datos de producción.
-- ============================================================

-- ---------- Condominio con 2 torres ----------
INSERT INTO condominio (nombre, direccion, telefono, email) VALUES
    ('Condominio Los Ceibos', 'Av. Amazonas N34-120, Quito', '022345678', 'admin@losceibos.ec');

INSERT INTO torre (id_condominio, nombre) VALUES
    (1, 'Torre A'), (1, 'Torre B');

-- ---------- 24 unidades (12 por torre) ----------
INSERT INTO unidad (id_condominio, id_torre, id_estado, numero, piso, tipo, alicuota)
SELECT
    1,
    CASE WHEN g <= 12 THEN 1 ELSE 2 END,
    (SELECT id_estado FROM estado_unidad WHERE nombre = 'OCUPADA'),
    (CASE WHEN g <= 12 THEN 'A-' ELSE 'B-' END) || (100 + g)::TEXT,
    ((g - 1) % 12) / 3 + 1,
    'DEPARTAMENTO',
    ROUND((1.0 / 24)::NUMERIC, 6)
FROM generate_series(1, 24) AS g;

INSERT INTO area_comun (id_condominio, nombre, descripcion, capacidad) VALUES
    (1, 'Piscina', 'Piscina climatizada', 30),
    (1, 'Salón Comunal', 'Salón de eventos', 60),
    (1, 'Gimnasio', 'Área de cardio y pesas', 15),
    (1, 'BBQ', 'Zona de asados', 20);

-- ---------- 30 personas (nombres/apellidos combinados) ----------
WITH nombres AS (
    SELECT unnest(ARRAY['Xavier','Maria','Carlos','Ana','Luis','Sofia','Pedro','Valentina',
        'Diego','Camila','Andres','Gabriela','Juan','Isabella','Fernando','Paula',
        'Ricardo','Daniela','Miguel','Lucia','Jorge','Alejandra','Santiago','Martina',
        'Pablo','Renata','Esteban','Carolina','Ivan','Sara']) AS nombre
),
apellidos AS (
    SELECT unnest(ARRAY['Altamirano','Perez','Gomez','Torres','Vasquez','Chavez','Rojas',
        'Suarez','Castro','Mendez','Flores','Ortiz','Ramos','Herrera','Silva',
        'Aguirre','Cordova','Nunez','Salazar','Paredes','Espinoza','Vargas',
        'Molina','Cabrera','Reyes','Jimenez','Guerrero','Vera','Andrade','Cueva']) AS apellido
),
personas AS (
    SELECT ROW_NUMBER() OVER () AS n, nombre, apellido
    FROM (SELECT nombre, ROW_NUMBER() OVER () AS rn FROM nombres) n
    JOIN (SELECT apellido, ROW_NUMBER() OVER () AS rn FROM apellidos) a USING (rn)
)
INSERT INTO persona (tipo_identificacion, numero_identificacion, nombres, apellidos, telefono, correo, fecha_nacimiento, direccion, estado)
SELECT
    'CEDULA',
    LPAD((1700000000 + n)::TEXT, 10, '0'),
    nombre,
    apellido,
    '09' || LPAD((10000000 + n)::TEXT, 8, '0'),
    LOWER(nombre) || '.' || LOWER(apellido) || n || '@mail.com',
    DATE '1970-01-01' + (n * 400)::INT,
    'Calle ' || n || ' y Av. Principal, Quito',
    'ACTIVO'
FROM personas;

-- ---------- Asignación persona-unidad: 1 propietario por unidad,
--            y algunas unidades con 2 residentes adicionales ----------
INSERT INTO persona_unidad (id_persona, id_unidad, tipo, fecha_inicio)
SELECT n, n, 'PROPIETARIO', DATE '2024-01-01'
FROM generate_series(1, 24) AS n;

INSERT INTO persona_unidad (id_persona, id_unidad, tipo, fecha_inicio)
SELECT 24 + s, s * 3, 'RESIDENTE', DATE '2025-06-01'
FROM generate_series(1, 6) AS s;

-- ---------- Usuarios para los primeros 10 propietarios + 1 admin ----------
-- Hash de ejemplo, NO representa un password real: la API es quien
-- debe generar el hash verdadero (bcrypt/argon2) al crear usuarios.
INSERT INTO usuario (id_persona, username, password_hash)
SELECT id_persona, 'user' || id_persona, 'HASH_EJEMPLO_NO_USAR_EN_PROD_' || id_persona
FROM persona WHERE id_persona <= 10;

INSERT INTO usuario_rol (id_usuario, id_rol)
SELECT id_usuario, (SELECT id_rol FROM rol WHERE nombre = 'PROPIETARIO')
FROM usuario;

-- Un admin de ejemplo sobre la persona 30
INSERT INTO usuario (id_persona, username, password_hash)
VALUES (30, 'admin', 'HASH_EJEMPLO_NO_USAR_EN_PROD_ADMIN');
INSERT INTO usuario_rol (id_usuario, id_rol)
VALUES ((SELECT id_usuario FROM usuario WHERE username = 'admin'), (SELECT id_rol FROM rol WHERE nombre = 'ADMIN'));

-- ---------- Vehículos (algunos con placa, algunos sin) ----------
INSERT INTO vehiculo (id_unidad, id_persona_actual, tipo, placa, marca, modelo, color)
SELECT n, n, 'AUTO', 'PBX-' || LPAD(n::TEXT, 4, '0'), 'Chevrolet', 'Sail', 'Blanco'
FROM generate_series(1, 15) AS n;

INSERT INTO vehiculo (id_unidad, id_persona_actual, tipo)
SELECT n, n, 'BICICLETA'
FROM generate_series(16, 24) AS n;

-- ---------- Cuotas: últimos 3 meses, ordinaria, para las 24 unidades ----------
SELECT generar_cuotas_mes(5, 2026, 'ORDINARIA', 90);
SELECT generar_cuotas_mes(6, 2026, 'ORDINARIA', 90);
SELECT generar_cuotas_mes(7, 2026, 'ORDINARIA', 90);

-- Pagos: la mitad de las cuotas de mayo y junio quedan pagadas
INSERT INTO pago (id_cuota, id_estado, valor, metodo, referencia)
SELECT id_cuota, (SELECT id_estado FROM estado_pago WHERE nombre = 'CONFIRMADO'), valor, 'TRANSFERENCIA', 'REF-' || id_cuota
FROM cuota
WHERE mes IN (5, 6) AND id_unidad % 2 = 0;

UPDATE cuota SET estado = 'PAGADA'
WHERE id_cuota IN (SELECT id_cuota FROM pago);

-- Recibos para esos pagos
INSERT INTO recibo (numero, id_pago)
SELECT 'REC-2026-' || LPAD(id_pago::TEXT, 5, '0'), id_pago FROM pago;

-- Cuotas de mayo sin pagar -> marcarlas VENCIDA (para probar mora)
UPDATE cuota SET estado = 'VENCIDA' WHERE mes = 5 AND estado = 'PENDIENTE';

-- ---------- Tickets de mantenimiento (8 ejemplos, con historial) ----------
INSERT INTO ticket (id_persona, id_unidad, id_categoria, titulo, descripcion, prioridad)
SELECT n, n, ((n - 1) % 8) + 1, 'Ticket de prueba ' || n, 'Descripción de la incidencia número ' || n, 'MEDIA'
FROM generate_series(1, 8) AS n;

INSERT INTO historial_ticket (id_ticket, id_estado, id_usuario, comentario)
SELECT id_ticket, (SELECT id_estado FROM estado_ticket WHERE nombre = 'ABIERTO'),
       (SELECT id_usuario FROM usuario WHERE username = 'admin'), 'Ticket creado'
FROM ticket;

INSERT INTO historial_ticket (id_ticket, id_estado, id_usuario, comentario)
SELECT id_ticket, (SELECT id_estado FROM estado_ticket WHERE nombre = 'EN_PROCESO'),
       (SELECT id_usuario FROM usuario WHERE username = 'admin'), 'Asignado a técnico'
FROM ticket WHERE id_ticket <= 5;

-- ---------- Visitantes y accesos ----------
INSERT INTO visitante (nombre, cedula, telefono)
SELECT 'Visitante ' || n, LPAD((900000 + n)::TEXT, 10, '0'), '099' || LPAD(n::TEXT, 7, '0')
FROM generate_series(1, 10) AS n;

INSERT INTO acceso (id_visitante, id_unidad, id_guardia, id_estado, hora_ingreso, hora_salida)
SELECT n, n, 30, (SELECT id_estado FROM estado_acceso WHERE nombre = 'FINALIZADO'),
       now() - (n || ' hours')::INTERVAL, now() - ((n - 1) || ' hours')::INTERVAL
FROM generate_series(1, 8) AS n;

-- 2 visitantes que siguen dentro (sin hora_salida)
INSERT INTO acceso (id_visitante, id_unidad, id_guardia, id_estado, hora_ingreso)
SELECT n, n, 30, (SELECT id_estado FROM estado_acceso WHERE nombre = 'EN_CURSO'), now() - INTERVAL '30 minutes'
FROM generate_series(9, 10) AS n;

-- ---------- Reservas de áreas comunes (hoy y próximos días) ----------
INSERT INTO reserva (id_area, id_persona, id_estado, fecha, hora_inicio, hora_fin, motivo)
SELECT
    ((n - 1) % 4) + 1,
    n,
    (SELECT id_estado FROM estado_reserva WHERE nombre = 'APROBADA'),
    CURRENT_DATE + (n % 5),
    ('09:00'::TIME + (n || ' hours')::INTERVAL)::TIME,
    ('10:00'::TIME + (n || ' hours')::INTERVAL)::TIME,
    'Reserva de prueba ' || n
FROM generate_series(1, 12) AS n;

-- ---------- Comunicado general + algunas lecturas ----------
INSERT INTO comunicado (titulo, mensaje, id_autor, destinatario_tipo)
VALUES ('Mantenimiento de ascensores', 'Se realizará mantenimiento preventivo el próximo lunes.', 30, 'TODOS');

INSERT INTO comunicado_lectura (id_comunicado, id_persona)
SELECT 1, n FROM generate_series(1, 15) AS n;

-- ---------- Asamblea con votación y acta ----------
INSERT INTO asamblea (id_condominio, fecha, tipo, quorum_requerido, estado)
VALUES (1, now() - INTERVAL '10 days', 'ORDINARIA', 60.00, 'FINALIZADA');

INSERT INTO votacion (id_asamblea, id_persona, opcion)
SELECT 1, n, (ARRAY['A_FAVOR','A_FAVOR','A_FAVOR','EN_CONTRA','ABSTENCION'])[1 + (n % 5)]::opcion_votacion_enum
FROM generate_series(1, 20) AS n;

INSERT INTO acta (id_asamblea, contenido)
VALUES (1, 'Acta de la asamblea ordinaria. Se aprobó el presupuesto anual con mayoría de votos a favor.');
