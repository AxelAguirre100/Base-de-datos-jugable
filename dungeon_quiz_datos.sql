-- ============================================================
-- Dungeon Quiz - Datos semilla (DML) + pruebas de verificación
-- Correr DESPUÉS de dungeon_quiz_schema.sql
-- Cumple los mínimos: 3 jugadores, 5 monstruos, 15 preguntas
-- ============================================================

USE dungeon_quiz;
SET NAMES utf8mb4;

-- ------------------------------------------------------------
-- Jugadores
-- ------------------------------------------------------------
INSERT INTO jugador (id, nombre, nivel, experiencia) VALUES
  (1, 'Ana',   2, 40),
  (2, 'Beto',  1, 70),
  (3, 'Carla', 1, 0);

-- ------------------------------------------------------------
-- Monstruos (dificultad 1 fácil, 2 media, 3 difícil)
-- ------------------------------------------------------------
INSERT INTO monstruo (id, nombre, dificultad, vida_base) VALUES
  (1, 'Slime',      1, 30),
  (2, 'Goblin',     1, 40),
  (3, 'Esqueleto',  2, 60),
  (4, 'Orco',       2, 80),
  (5, 'Dragón',     3, 150);

-- ------------------------------------------------------------
-- Preguntas: 3 categorías x 5 preguntas
-- ------------------------------------------------------------
INSERT INTO pregunta (id, enunciado, categoria, dificultad) VALUES
  -- Bases de datos
  (1,  '¿Qué sentencia SQL se usa para consultar datos?',                                   'Bases de datos', 1),
  (2,  '¿Qué restricción identifica de forma única cada fila de una tabla?',                'Bases de datos', 1),
  (3,  '¿Qué cláusula filtra los grupos generados por un GROUP BY?',                        'Bases de datos', 2),
  (4,  '¿Qué JOIN devuelve todas las filas de la tabla izquierda, tengan o no coincidencia?', 'Bases de datos', 2),
  (5,  '¿Qué propiedad ACID asegura que una transacción se haga completa o no se haga?',    'Bases de datos', 3),
  -- Programación
  (6,  '¿Qué función de Python muestra texto en pantalla?',                                 'Programación', 1),
  (7,  '¿Qué símbolo inicia un comentario de una línea en Python?',                         'Programación', 1),
  (8,  '¿Qué estructura de Python guarda pares clave-valor?',                               'Programación', 2),
  (9,  '¿Qué devuelve len([1, 2, 3, 4]) en Python?',                                        'Programación', 2),
  (10, '¿Qué devuelve 7 // 2 en Python?',                                                   'Programación', 3),
  -- Redes
  (11, '¿Qué significan las siglas HTTP?',                                                  'Redes', 1),
  (12, '¿Qué dispositivo conecta una red local con internet?',                              'Redes', 1),
  (13, '¿Qué puerto usa HTTPS por defecto?',                                                'Redes', 2),
  (14, '¿Qué protocolo traduce nombres de dominio a direcciones IP?',                       'Redes', 2),
  (15, '¿Cuántos bits tiene una dirección IPv4?',                                           'Redes', 3);

-- ------------------------------------------------------------
-- Respuestas: 4 alternativas por pregunta, UNA sola correcta
-- (columnas: texto, es_correcta, id_pregunta)
-- ------------------------------------------------------------
INSERT INTO respuesta (texto, es_correcta, id_pregunta) VALUES
  -- 1
  ('SELECT', 1, 1), ('INSERT', 0, 1), ('DELETE', 0, 1), ('CREATE', 0, 1),
  -- 2
  ('FOREIGN KEY', 0, 2), ('PRIMARY KEY', 1, 2), ('CHECK', 0, 2), ('DEFAULT', 0, 2),
  -- 3
  ('WHERE', 0, 3), ('ORDER BY', 0, 3), ('HAVING', 1, 3), ('LIMIT', 0, 3),
  -- 4
  ('INNER JOIN', 0, 4), ('RIGHT JOIN', 0, 4), ('CROSS JOIN', 0, 4), ('LEFT JOIN', 1, 4),
  -- 5
  ('Atomicidad', 1, 5), ('Consistencia', 0, 5), ('Aislamiento', 0, 5), ('Durabilidad', 0, 5),
  -- 6
  ('echo()', 0, 6), ('print()', 1, 6), ('write()', 0, 6), ('show()', 0, 6),
  -- 7
  ('//', 0, 7), ('--', 0, 7), ('#', 1, 7), ('/*', 0, 7),
  -- 8
  ('Lista', 0, 8), ('Tupla', 0, 8), ('Diccionario', 1, 8), ('Conjunto', 0, 8),
  -- 9
  ('3', 0, 9), ('4', 1, 9), ('5', 0, 9), ('0', 0, 9),
  -- 10
  ('3.5', 0, 10), ('4', 0, 10), ('3', 1, 10), ('2', 0, 10),
  -- 11
  ('HyperText Transfer Protocol', 1, 11), ('High Transfer Text Protocol', 0, 11),
  ('Hyper Terminal Transfer Process', 0, 11), ('Host Text Transmission Protocol', 0, 11),
  -- 12
  ('Switch', 0, 12), ('Router', 1, 12), ('Hub', 0, 12), ('Repetidor', 0, 12),
  -- 13
  ('80', 0, 13), ('21', 0, 13), ('443', 1, 13), ('25', 0, 13),
  -- 14
  ('FTP', 0, 14), ('DHCP', 0, 14), ('DNS', 1, 14), ('SMTP', 0, 14),
  -- 15
  ('16', 0, 15), ('32', 1, 15), ('64', 0, 15), ('128', 0, 15);

-- ------------------------------------------------------------
-- Partidas de ejemplo (para probar leaderboard y estadísticas)
-- ------------------------------------------------------------
INSERT INTO partida (id, puntaje, resultado, vida_actual, id_jugador) VALUES
  (1, 120, 'victoria', 70, 1),   -- Ana gana
  (2,  40, 'derrota',   0, 2),   -- Beto pierde
  (3,  20, 'en_curso', 80, 3),   -- Carla sigue jugando
  (4,  60, 'derrota',   0, 1);   -- Ana pierde una

INSERT INTO partida_monstruo (id_partida, id_monstruo, vida_restante) VALUES
  (1, 1, 0), (1, 2, 0),          -- Ana derrotó a Slime y Goblin
  (2, 3, 25),                    -- Beto dejó al Esqueleto con 25
  (3, 1, 10);                    -- Carla le dejó 10 al Slime

-- Se toma el id de la respuesta correcta/incorrecta con subconsultas,
-- así no dependemos de los ids que asignó AUTO_INCREMENT.
INSERT INTO partida_pregunta (id_partida, id_pregunta, id_respuesta_elegida) VALUES
  (1, 1, (SELECT id FROM respuesta WHERE id_pregunta = 1 AND es_correcta = 1)),
  (1, 2, (SELECT id FROM respuesta WHERE id_pregunta = 2 AND es_correcta = 1)),
  (1, 3, (SELECT id FROM respuesta WHERE id_pregunta = 3 AND es_correcta = 1)),
  (2, 1, (SELECT id FROM respuesta WHERE id_pregunta = 1 AND es_correcta = 1)),
  (2, 4, (SELECT id FROM respuesta WHERE id_pregunta = 4 AND es_correcta = 0 LIMIT 1)),
  (2, 5, (SELECT id FROM respuesta WHERE id_pregunta = 5 AND es_correcta = 0 LIMIT 1)),
  (3, 6, (SELECT id FROM respuesta WHERE id_pregunta = 6 AND es_correcta = 1)),
  (3, 7, NULL);                  -- Carla todavía no contestó esta

-- ============================================================
-- PRUEBAS DE VERIFICACIÓN (correr de a una y comparar)
-- ============================================================

-- 1) Conteo de filas. Esperado: 3 jugadores, 5 monstruos, 15 preguntas,
--    60 respuestas, 4 partidas.
SELECT (SELECT COUNT(*) FROM jugador)   AS jugadores,
       (SELECT COUNT(*) FROM monstruo)  AS monstruos,
       (SELECT COUNT(*) FROM pregunta)  AS preguntas,
       (SELECT COUNT(*) FROM respuesta) AS respuestas,
       (SELECT COUNT(*) FROM partida)   AS partidas;

-- 2) Regla 1: toda pregunta debe tener exactamente 1 correcta.
--    Esperado: 0 filas.
SELECT id_pregunta, SUM(es_correcta) AS correctas
FROM respuesta
GROUP BY id_pregunta
HAVING SUM(es_correcta) <> 1;

-- 3) Leaderboard (consulta obligatoria 1).
--    Esperado: Ana 120, Ana 60, Beto 40, Carla 20.
SELECT j.nombre, p.puntaje, p.resultado
FROM partida p
JOIN jugador j ON j.id = p.id_jugador
ORDER BY p.puntaje DESC
LIMIT 5;

-- 4) Rendimiento por categoría (consulta obligatoria 2).
--    Esperado: Bases de datos 6 respondidas / 4 aciertos / 66.7 %;
--              Programación 1 / 1 / 100.0 %; Redes no aparece.
SELECT p.categoria,
       COUNT(*)            AS respondidas,
       SUM(r.es_correcta)  AS aciertos,
       ROUND(100 * SUM(r.es_correcta) / COUNT(*), 1) AS porcentaje
FROM partida_pregunta pp
JOIN pregunta  p ON p.id = pp.id_pregunta
JOIN respuesta r ON r.id = pp.id_respuesta_elegida
GROUP BY p.categoria;

-- 5) Preguntas aleatorias por dificultad (consulta obligatoria 3).
--    Esperado: 3 preguntas distintas de dificultad 1, en otro orden cada vez.
SELECT id, enunciado
FROM pregunta
WHERE dificultad = 1
ORDER BY RAND()
LIMIT 3;

-- ------------------------------------------------------------
-- PRUEBAS NEGATIVAS: cada una tiene que FALLAR con un error.
-- Correlas de a una (descomentá la línea) y comprobá el mensaje.
-- ------------------------------------------------------------

-- Regla 1 (trigger): segunda respuesta correcta para la pregunta 1
-- INSERT INTO respuesta (texto, es_correcta, id_pregunta) VALUES ('SELECT *', 1, 1);
--   -> ERROR 1644: La pregunta ya tiene una respuesta correcta

-- Regla 2 (FK compuesta): respuesta de la pregunta 2 elegida en la pregunta 1
-- INSERT INTO partida_pregunta (id_partida, id_pregunta, id_respuesta_elegida)
-- VALUES (3, 8, (SELECT id FROM respuesta WHERE id_pregunta = 1 AND es_correcta = 1));
--   -> ERROR 1452: falla la clave foránea

-- CHECK: vida negativa
-- UPDATE partida SET vida_actual = -5 WHERE id = 1;
--   -> ERROR 4025 (MariaDB) / 3819 (MySQL): CONSTRAINT violada

-- CHECK: experiencia fuera de rango
-- UPDATE jugador SET experiencia = 100 WHERE id = 1;
--   -> ERROR: CONSTRAINT chk_jugador_exp violada

-- RESTRICT: borrar un jugador con partidas
-- DELETE FROM jugador WHERE id = 1;
--   -> ERROR 1451: no se puede borrar, tiene filas hijas

-- CASCADE: borrar una partida borra su detalle (esta SÍ funciona)
-- DELETE FROM partida WHERE id = 3;
--   -> OK, y desaparecen sus filas de partida_monstruo y partida_pregunta
