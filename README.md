# ⚔️ Dungeon Quiz

TP Integrador "Una base de datos que se juega" · Informática II · UNNE · Proyecto C

**Equipo:** Los DELETE sin WHERE 
**Integrantes:** Axel Fernán Aguirre, Guillermo Ruben Vallejos, Alberto Eduardo Leiva 

Un héroe avanza por una mazmorra y se enfrenta a un monstruo. Para atacarlo tiene que
responder preguntas que le propone la base de datos: si acierta, el monstruo pierde vida
y el héroe suma puntos; si falla, el héroe pierde vida. La partida termina cuando el
monstruo llega a 0 (victoria) o cuando el héroe llega a 0 (derrota). El resultado queda
guardado en la base y alimenta el leaderboard.

## Qué incluye este proyecto

| Archivo | Para qué sirve |
|---|---|
| `dungeon_quiz.sql` | Script único: crea la base, las tablas, los datos de prueba, las 10 consultas, la transacción y la vista |
| `app_dungeon_quiz.py` | La aplicación del juego (Python + Streamlit) |
| `requirements.txt` | Dependencias de Python con sus versiones |
| `README.md` | Este archivo |

## Requisitos

- **XAMPP** (incluye MariaDB y phpMyAdmin): https://www.apachefriends.org
- **Python 3.10 o superior**. Para ver la versión instalada: `python --version`
- Conexión a internet (para instalar las dependencias)

## Instalación paso a paso

### 1. Iniciar la base de datos

1. Abrí el **Panel de control de XAMPP**.
2. Apretá **Start** en el módulo **MySQL** (no hace falta iniciar Apache).
3. Cuando el módulo aparezca en verde, la base de datos está lista.

### 2. Crear la base con el script

1. Abrí http://localhost/phpmyadmin en el navegador.
2. Entrá a la pestaña **SQL**.
3. Abrí `dungeon_quiz.sql` con un editor de texto, copiá **todo** el contenido, pegalo
   en phpMyAdmin y apretá **Continuar**.
4. Tiene que ejecutarse sin errores. Al terminar vas a ver la base `dungeon_quiz` en
   la lista de la izquierda, con 7 tablas y la vista `v_ranking`.

> ⚠️ El script borra y vuelve a crear las tablas del juego. Si lo ejecutás de nuevo, se
> pierden las partidas guardadas y la base vuelve a los datos de prueba originales.

### 3. Instalar las dependencias de Python

Abrí una terminal en la carpeta del proyecto y ejecutá:

```
pip install -r requirements.txt
```

### 4. Ejecutar el juego

En la misma terminal:

```
streamlit run app_dungeon_quiz.py
```

Se abre el navegador en http://localhost:8501. Si no se abre solo, copiá esa dirección
en el navegador.

## Cómo se juega

1. En la pestaña **Mazmorra (Jugar)** elegí un héroe registrado o creá uno nuevo.
2. Apretá **Entrar a la Mazmorra**: el juego te asigna un monstruo según tu nivel.
3. Respondé la pregunta y apretá **Atacar con respuesta**.
   - Acierto: el monstruo pierde 20 de vida y ganás 30 puntos.
   - Error: perdés 35 de vida.
4. Ganás si el monstruo llega a 0. Perdés si tu vida llega a 0. Ganar suma experiencia
   (+50 EXP) y, al juntar 100, subís de nivel.
5. En la pestaña **Leaderboard y Estadísticas** ves el top 5 de puntajes y el
   rendimiento por categoría.

## Jugar a distancia (para que otras personas jueguen desde su navegador)

La app corre en tu computadora y la base también. Para que otros puedan entrar desde
internet se usa un **túnel**, que te da un link público. Los jugadores solo abren el
link: no instalan nada.

Con la app ya corriendo (paso 4), abrí **otra terminal** y publicala con
**Cloudflare Tunnel**:

1. Instalá `cloudflared` (en Windows: `winget install Cloudflare.cloudflared`, o desde
   la página oficial de Cloudflare).
2. Ejecutá:
   ```
   cloudflared tunnel --url http://localhost:8501
   ```
3. En la salida aparece una dirección parecida a `https://algo.trycloudflare.com`.
   Ese es el link para compartir.

Para que funcione, tu computadora tiene que estar encendida y con conexión, y XAMPP
(MySQL), la app y el túnel tienen que estar corriendo durante toda la partida. Cuando
termines, cerrá el túnel (`Ctrl + C`), porque cualquiera con el link puede jugar.

Todos los jugadores usan la misma base de datos, así que el leaderboard se actualiza en
vivo con los resultados de todos.

## Configuración de la conexión

La app se conecta a la base con estos datos, definidos al principio de
`app_dungeon_quiz.py` en `DB_CONFIG`:

| Parámetro | Valor |
|---|---|
| host | `localhost` |
| usuario | `root` |
| contraseña | vacía (la configuración por defecto de XAMPP) |
| base de datos | `dungeon_quiz` |

Si tu MySQL tiene contraseña, cambiá el valor de `password` en ese bloque.

## Reglas del juego que impone la base de datos

La aplicación no repite estas reglas en el código: las hace cumplir la base.

1. **Una sola respuesta correcta por pregunta.** Dos triggers sobre la tabla `respuesta`
   (`trg_respuesta_una_correcta_ins` y `trg_respuesta_una_correcta_upd`) rechazan una
   segunda respuesta correcta.
2. **La respuesta elegida pertenece a la pregunta respondida.** La clave foránea
   compuesta `fk_pp_respuesta` en `partida_pregunta`.
3. **Responder una pregunta es una operación atómica.** La app ejecuta una transacción
   que registra la respuesta y actualiza el puntaje, la vida del héroe y la vida del
   monstruo. Si algo falla, hace `ROLLBACK`.

Además, los `CHECK`, `UNIQUE`, `NOT NULL` y las políticas `ON DELETE / ON UPDATE` del
modelo se aplican directamente en la base.

## Solución de problemas

- **`Can't connect to MySQL server`**: el módulo MySQL de XAMPP no está iniciado.
  Iniciarlo desde el panel de control.
- **`Unknown database 'dungeon_quiz'`**: falta ejecutar el script del paso 2.
- **`Table ... doesn't exist` o `View 'v_ranking' ...`**: el script se cortó a la mitad.
  Borrá la base `dungeon_quiz` desde phpMyAdmin y volvé a ejecutar el script completo.
- **`pip` o `streamlit` no se reconocen**: Python no está en el PATH. Probá con
  `python -m pip install -r requirements.txt` y `python -m streamlit run app_dungeon_quiz.py`.
- **`cloudflared` no se reconoce como comando** (recién instalado): la terminal se abrió
  antes de la instalación y no conoce el comando. Cerrala, abrí una terminal nueva y
  volvé a ejecutar `cloudflared tunnel --url http://localhost:8501`.
- **El puerto 3306 está ocupado** (otra instalación de MySQL): cerrala o cambiá el
  puerto de MySQL en XAMPP.

## Tecnología elegida

- **MariaDB (XAMPP):** es uno de los motores vistos en clase y permite aplicar las reglas
  con restricciones, triggers y transacciones.
- **Python + Streamlit:** permite construir la interfaz web en un único archivo y
  conectarse directamente a la base, sin un servidor intermedio. Los jugadores acceden
  desde el navegador.
- **Túnel (Cloudflare Tunnel):** publica la app de forma temporal para jugar a
  distancia sin instalar nada en cada computadora.

## Mejoras futuras

- Que las partidas abandonadas se cierren solas, para que no cuenten en el leaderboard.
- Más monstruos por partida y más preguntas por categoría.
- Publicar la app y la base en un servidor en internet, para no depender de una
  computadora local.
