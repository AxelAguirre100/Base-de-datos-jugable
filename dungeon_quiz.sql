-- ============================================================
-- Dungeon Quiz - Script único
-- TP Integrador "Una base de datos que se juega" - Informática II, UNNE
-- Proyecto C: Dungeon Quiz (rol y trivia)
-- Motor: MySQL 8.0.16+ / MariaDB 10.2.1+ (XAMPP)
--
-- Ejecutado sobre una base vacía, deja todo listo para jugar:
--   Parte 1: DDL (tablas, restricciones y triggers de la regla 1)
--   Parte 2: datos semilla (3 jugadores, 5 monstruos, 15 preguntas)
--   Parte 3: diez consultas con su enunciado
--   Parte 4: transacción (COMMIT y ROLLBACK)
--   Parte 5: vista v_ranking
--
-- Reglas impuestas por la base:
--   Regla 1: una sola respuesta correcta por pregunta
--            (triggers trg_respuesta_una_correcta_ins / _upd)
--   Regla 2: la respuesta elegida pertenece a la pregunta respondida
--            (FK compuesta fk_pp_respuesta)
--   Regla 3: responder una pregunta es una operación atómica
--            (transacción de la parte 4)
-- ============================================================

-- ============================================================
-- PARTE 1: ESTRUCTURA (DDL) Y TRIGGERS
-- ============================================================

CREATE DATABASE IF NOT EXISTS dungeon_quiz
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;

USE dungeon_quiz;
SET NAMES utf8mb4;

-- Para poder volver a correr el script sobre una base ya usada
-- (primero las tablas hijas, después las padres)
DROP VIEW  IF EXISTS v_ranking;
DROP TABLE IF EXISTS partida_pregunta;
DROP TABLE IF EXISTS partida_monstruo;
DROP TABLE IF EXISTS respuesta;
DROP TABLE IF EXISTS pregunta;
DROP TABLE IF EXISTS partida;
DROP TABLE IF EXISTS monstruo;
DROP TABLE IF EXISTS jugador;

-- ------------------------------------------------------------
-- Tablas que no dependen de otras
-- ------------------------------------------------------------

CREATE TABLE jugador (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  nombre      VARCHAR(50) NOT NULL UNIQUE,
  nivel       INT NOT NULL DEFAULT 1,
  experiencia INT NOT NULL DEFAULT 0,
  CONSTRAINT chk_jugador_nivel CHECK (nivel >= 1),
  CONSTRAINT chk_jugador_exp   CHECK (experiencia BETWEEN 0 AND 99)
) ENGINE=InnoDB;

CREATE TABLE monstruo (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  nombre     VARCHAR(50) NOT NULL UNIQUE,
  dificultad TINYINT NOT NULL,
  vida_base  INT NOT NULL,
  CONSTRAINT chk_monstruo_dificultad CHECK (dificultad BETWEEN 1 AND 3),
  CONSTRAINT chk_monstruo_vida       CHECK (vida_base > 0)
) ENGINE=InnoDB;

CREATE TABLE pregunta (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  enunciado  VARCHAR(255) NOT NULL,
  categoria  VARCHAR(50) NOT NULL,
  dificultad TINYINT NOT NULL,
  CONSTRAINT chk_pregunta_dificultad CHECK (dificultad BETWEEN 1 AND 3)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Tablas con claves foráneas
-- ------------------------------------------------------------

CREATE TABLE partida (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  fecha       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  puntaje     INT NOT NULL DEFAULT 0,
  resultado   VARCHAR(10) NOT NULL DEFAULT 'en_curso',
  vida_actual INT NOT NULL,
  id_jugador  INT NOT NULL,
  CONSTRAINT chk_partida_puntaje   CHECK (puntaje >= 0),
  CONSTRAINT chk_partida_resultado CHECK (resultado IN ('en_curso','victoria','derrota')),
  CONSTRAINT chk_partida_vida      CHECK (vida_actual >= 0),
  CONSTRAINT fk_partida_jugador FOREIGN KEY (id_jugador)
    REFERENCES jugador (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE respuesta (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  texto       VARCHAR(255) NOT NULL,
  es_correcta BOOLEAN NOT NULL DEFAULT FALSE,
  id_pregunta INT NOT NULL,
  -- Necesaria para la FK compuesta de partida_pregunta (regla 2)
  CONSTRAINT uq_respuesta_id_pregunta UNIQUE (id, id_pregunta),
  CONSTRAINT fk_respuesta_pregunta FOREIGN KEY (id_pregunta)
    REFERENCES pregunta (id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- N:M partida - monstruo (atributo propio: vida_restante)
CREATE TABLE partida_monstruo (
  id_partida    INT NOT NULL,
  id_monstruo   INT NOT NULL,
  vida_restante INT NOT NULL,
  PRIMARY KEY (id_partida, id_monstruo),
  CONSTRAINT chk_pm_vida CHECK (vida_restante >= 0),
  CONSTRAINT fk_pm_partida FOREIGN KEY (id_partida)
    REFERENCES partida (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pm_monstruo FOREIGN KEY (id_monstruo)
    REFERENCES monstruo (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- N:M partida - pregunta (atributo propio: id_respuesta_elegida)
CREATE TABLE partida_pregunta (
  id_partida           INT NOT NULL,
  id_pregunta          INT NOT NULL,
  id_respuesta_elegida INT NULL,   -- NULL hasta que el jugador contesta
  PRIMARY KEY (id_partida, id_pregunta),
  CONSTRAINT fk_pp_partida FOREIGN KEY (id_partida)
    REFERENCES partida (id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pp_pregunta FOREIGN KEY (id_pregunta)
    REFERENCES pregunta (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  -- Regla 2: la respuesta elegida pertenece a la pregunta respondida
  CONSTRAINT fk_pp_respuesta FOREIGN KEY (id_respuesta_elegida, id_pregunta)
    REFERENCES respuesta (id, id_pregunta)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- Regla 1: cada pregunta tiene a lo sumo UNA respuesta correcta
-- (si lo corrés desde la consola de MySQL/phpMyAdmin, el
--  DELIMITER es necesario porque el trigger tiene ';' adentro)
-- ------------------------------------------------------------

DELIMITER $$

CREATE TRIGGER trg_respuesta_una_correcta_ins
BEFORE INSERT ON respuesta
FOR EACH ROW
BEGIN
  IF NEW.es_correcta = 1 AND EXISTS (
       SELECT 1 FROM respuesta
       WHERE id_pregunta = NEW.id_pregunta AND es_correcta = 1
     ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La pregunta ya tiene una respuesta correcta';
  END IF;
END$$

CREATE TRIGGER trg_respuesta_una_correcta_upd
BEFORE UPDATE ON respuesta
FOR EACH ROW
BEGIN
  IF NEW.es_correcta = 1 AND EXISTS (
       SELECT 1 FROM respuesta
       WHERE id_pregunta = NEW.id_pregunta
         AND es_correcta = 1
         AND id <> NEW.id
     ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La pregunta ya tiene una respuesta correcta';
  END IF;
END$$

DELIMITER ;

-- ============================================================
-- PARTE 2: DATOS SEMILLA
-- ============================================================

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
-- PARTE 3: DIEZ CONSULTAS
-- Los resultados esperados corresponden a los datos semilla
-- originales, ANTES de correr la transacción de la parte 4.
-- ============================================================

-- ------------------------------------------------------------
-- OBLIGATORIAS DEL PROYECTO C
-- ------------------------------------------------------------

-- Q1) Tabla de clasificación (leaderboard): los 5 jugadores con mayor puntaje,
--     tomando el mejor puntaje de cada uno.
--     Técnicas: JOIN, GROUP BY, MAX, ORDER BY, LIMIT.
--     Esperado con los datos semilla: Ana 120, Beto 40, Carla 20.
SELECT j.nombre, MAX(p.puntaje) AS mejor_puntaje
FROM jugador j
JOIN partida p ON p.id_jugador = j.id
GROUP BY j.id, j.nombre
ORDER BY mejor_puntaje DESC
LIMIT 5;

-- Q2) Rendimiento por categoría: porcentaje de aciertos.
--     Técnicas: JOIN, GROUP BY, agregaciones.
--     Solo cuenta preguntas ya contestadas (el JOIN con respuesta descarta los NULL).
--     Esperado: Bases de datos 6 / 4 / 66.7 ; Programación 1 / 1 / 100.0
SELECT pr.categoria,
       COUNT(*)           AS respondidas,
       SUM(r.es_correcta) AS aciertos,
       ROUND(100 * SUM(r.es_correcta) / COUNT(*), 1) AS porcentaje_aciertos
FROM partida_pregunta pp
JOIN pregunta  pr ON pr.id = pp.id_pregunta
JOIN respuesta r  ON r.id  = pp.id_respuesta_elegida
GROUP BY pr.categoria
ORDER BY porcentaje_aciertos DESC;

-- Q3) Selección aleatoria de preguntas según dificultad.
--     Cambiar el 1 por 2 o 3 según el nivel del jugador.
--     En la app, el 1 y el 3 son parámetros.
SELECT id, enunciado, categoria
FROM pregunta
WHERE dificultad = 1
ORDER BY RAND()
LIMIT 3;

-- ------------------------------------------------------------
-- REQUISITOS DE TÉCNICA
-- ------------------------------------------------------------

-- Q4) JOIN de 5 tablas: detalle de cada pregunta respondida en cada partida.
--     Muestra quién jugó, qué se le preguntó, qué eligió y si acertó.
SELECT j.nombre AS jugador,
       pa.id    AS partida,
       pr.enunciado,
       r.texto  AS respuesta_elegida,
       CASE WHEN r.es_correcta = 1 THEN 'Acierto' ELSE 'Error' END AS resultado
FROM jugador j
JOIN partida          pa ON pa.id_jugador = j.id
JOIN partida_pregunta pp ON pp.id_partida = pa.id
JOIN pregunta         pr ON pr.id = pp.id_pregunta
JOIN respuesta        r  ON r.id  = pp.id_respuesta_elegida
ORDER BY pa.id, pr.id;

-- Q5) Anti-join (LEFT JOIN ... IS NULL): preguntas que nunca se usaron en
--     ninguna partida. Sirve para detectar preguntas sin rotación del banco.
--     Esperado: las preguntas 8 a 15 (solo se usaron 1 a 7).
SELECT pr.id, pr.enunciado, pr.categoria
FROM pregunta pr
LEFT JOIN partida_pregunta pp ON pp.id_pregunta = pr.id
WHERE pp.id_pregunta IS NULL
ORDER BY pr.id;

-- Q6) Subconsulta escalar: partidas con puntaje mayor al promedio general.
--     Esperado: Ana (120). El promedio es (120+40+20+60)/4 = 60, y 60 no es > 60.
SELECT j.nombre, pa.puntaje, pa.resultado
FROM partida pa
JOIN jugador j ON j.id = pa.id_jugador
WHERE pa.puntaje > (SELECT AVG(puntaje) FROM partida)
ORDER BY pa.puntaje DESC;

-- Q7) GROUP BY + HAVING: jugadores con 2 o más partidas jugadas,
--     con su puntaje total y el mejor.
--     Esperado: solo Ana (2 partidas, total 180, mejor 120).
SELECT j.nombre,
       COUNT(pa.id)    AS partidas,
       SUM(pa.puntaje) AS puntaje_total,
       MAX(pa.puntaje) AS mejor_puntaje
FROM jugador j
JOIN partida pa ON pa.id_jugador = j.id
GROUP BY j.id, j.nombre
HAVING COUNT(pa.id) >= 2;

-- ------------------------------------------------------------
-- 3 CONSULTAS A ELECCIÓN
-- ------------------------------------------------------------

-- Q8) Monstruos derrotados por jugador (vida_restante = 0 significa derrotado).
--     Incluye a los jugadores que todavía no derrotaron ninguno (LEFT JOIN).
--     Esperado: Ana 2, Beto 0, Carla 0.
SELECT j.nombre,
       COUNT(pm.id_monstruo) AS monstruos_derrotados
FROM jugador j
LEFT JOIN partida pa          ON pa.id_jugador = j.id
LEFT JOIN partida_monstruo pm ON pm.id_partida = pa.id AND pm.vida_restante = 0
GROUP BY j.id, j.nombre
ORDER BY monstruos_derrotados DESC, j.nombre;

-- Q9) Tasa de aciertos por jugador (de las preguntas que contestó).
--     Esperado: Ana 3/3 = 100.0 ; Beto 1/3 = 33.3 ; Carla 1/1 = 100.0
SELECT j.nombre,
       COUNT(*)           AS respondidas,
       SUM(r.es_correcta) AS aciertos,
       ROUND(100 * SUM(r.es_correcta) / COUNT(*), 1) AS porcentaje_aciertos
FROM jugador j
JOIN partida          pa ON pa.id_jugador = j.id
JOIN partida_pregunta pp ON pp.id_partida = pa.id
JOIN respuesta        r  ON r.id = pp.id_respuesta_elegida
GROUP BY j.id, j.nombre
ORDER BY porcentaje_aciertos DESC;

-- Q10) Subconsulta con IN: preguntas que algún jugador contestó mal,
--      para revisarlas o reforzar ese tema.
--      Esperado: las preguntas 4 y 5.
SELECT pr.id, pr.enunciado, pr.categoria, pr.dificultad
FROM pregunta pr
WHERE pr.id IN (
        SELECT pp.id_pregunta
        FROM partida_pregunta pp
        JOIN respuesta r ON r.id = pp.id_respuesta_elegida
        WHERE r.es_correcta = 0
      )
ORDER BY pr.dificultad DESC, pr.id;

-- ============================================================
-- PARTE 4: TRANSACCIÓN (regla 3: responder una pregunta es atómico)
-- Son tres operaciones que tienen que ocurrir juntas:
--   1) registrar la respuesta elegida
--   2) sumar puntaje a la partida
--   3) bajarle vida al monstruo
-- Como sentencias sueltas, si fallara una quedaría la respuesta
-- registrada sin puntaje, o el monstruo herido sin respuesta.
-- ============================================================

-- Caso A: COMMIT. Carla contesta bien la pregunta 7 ('#')
-- y le saca 10 de vida al Slime (10 -> 0, queda derrotado).
START TRANSACTION;

UPDATE partida_pregunta
SET id_respuesta_elegida = (SELECT id FROM respuesta
                            WHERE id_pregunta = 7 AND es_correcta = 1)
WHERE id_partida = 3 AND id_pregunta = 7;

UPDATE partida
SET puntaje = puntaje + 10
WHERE id = 3;

UPDATE partida_monstruo
SET vida_restante = GREATEST(vida_restante - 10, 0)
WHERE id_partida = 3 AND id_monstruo = 1;

COMMIT;

-- Comprobación del caso A.
-- Esperado: puntaje 30 en la partida 3, Slime con vida_restante 0
-- y la pregunta 7 con respuesta elegida.
SELECT id, puntaje, vida_actual FROM partida WHERE id = 3;
SELECT * FROM partida_monstruo WHERE id_partida = 3;
SELECT * FROM partida_pregunta WHERE id_partida = 3;

-- Caso B: ROLLBACK. Se le presenta la pregunta 8 a Carla y se le descuentan
-- 10 de vida, pero la operación se cancela y se deshace todo.
-- (En la app, el código ejecuta este ROLLBACK cuando la base devuelve un
-- error. Por ejemplo, descontar 1000 de vida viola chk_partida_vida con el
-- error #4025: la sentencia falla y el INSERT anterior también hay que
-- deshacerlo. Acá se usa un descuento válido para que el script corra limpio.)
START TRANSACTION;

INSERT INTO partida_pregunta (id_partida, id_pregunta, id_respuesta_elegida)
VALUES (3, 8, NULL);

UPDATE partida SET vida_actual = vida_actual - 10 WHERE id = 3;

-- Dentro de la transacción los cambios se ven. Esperado: vida_actual 70
SELECT vida_actual FROM partida WHERE id = 3;

ROLLBACK;

-- Comprobación del caso B. Esperado: vida_actual 80 (restaurada)
-- y 0 filas para la pregunta 8 (el INSERT se deshizo).
SELECT vida_actual FROM partida WHERE id = 3;
SELECT * FROM partida_pregunta WHERE id_partida = 3 AND id_pregunta = 8;

-- ============================================================
-- PARTE 5: VISTA que alimenta la pantalla del leaderboard
-- ============================================================

CREATE OR REPLACE VIEW v_ranking AS
SELECT j.id AS id_jugador,
       j.nombre,
       j.nivel,
       COALESCE(MAX(p.puntaje), 0)                AS mejor_puntaje,
       COUNT(p.id)                                AS partidas,
       COALESCE(SUM(p.resultado = 'victoria'), 0) AS victorias
FROM jugador j
LEFT JOIN partida p ON p.id_jugador = j.id
GROUP BY j.id, j.nombre, j.nivel;

-- La app la usa así. Esperado (con el caso A ya ejecutado):
-- Ana 120 / 2 partidas / 1 victoria ; Beto 40 / 1 / 0 ; Carla 30 / 1 / 0
SELECT * FROM v_ranking ORDER BY mejor_puntaje DESC LIMIT 5;
