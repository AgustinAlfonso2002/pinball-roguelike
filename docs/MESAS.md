# Mesas generadas: chasis, módulos, objetivos y robot

Cada noche se juega en una mesa distinta. El generador la arma con una
**semilla** que sale de la semilla de la run y del número de noche: la misma
run siempre tiene las mismas mesas, y una partida guardada vuelve a la misma
mesa. Las dos partidas y el duelo de una noche usan la misma mesa.

```
Mesa = chasis (forma + encastres) + módulos (piezas en los encastres)
```

- **Parte fija (todas las mesas):** flippers, slingshots, carriles de los
  costados, postes y lanzador. Así la mano no se desentrena.
- **Parte variable:** paredes internas del chasis, flippers extra y los
  módulos de arriba.

## Reglas del generador (`scripts/tables/table_generator.gd`)

1. Elige un chasis al azar (con peso y noche mínima).
2. El encastre grande (L) lleva una pieza central (`core = true`: bumpers).
3. Si hay un encastre mediano (M), lleva algo que sube el multiplicador
   (banco de dianas o muro de ladrillos).
4. Llena el resto al azar hasta `2 + noche/2` piezas (redondeado para arriba):
   3 la primera noche, la mesa llena hacia el final.
5. Cada módulo aparece una vez como máximo; los portales usan dos encastres;
   en los encastres `low` (cerca de los flippers) solo van módulos con
   `allow_low = true`.

## Agregar un chasis

Un archivo en `scripts/tables/chassis/` que extienda `Chassis`. Coordenadas en
unidades de diseño (mesa de 400 × 640; el carril del lanzador empieza en x = 368).

```gdscript
extends Chassis

func _init() -> void:
	id = &"mi_chasis"
	display_name = "Mi chasis"
	sockets = [
		{"pos": Vector2(184, 120), "size": "M"},          # 140 × 60
		{"pos": Vector2(185, 250), "size": "L"},          # 150 × 150 (uno por mesa)
		{"pos": Vector2(62, 150), "size": "S"},           # 64 × 64
		{"pos": Vector2(184, 362), "size": "S", "tags": ["low"]},
	]
	rail_exits = [  # por dónde sale la bola del riel guiado
		{"pos": Vector2(36, 420), "dir": Vector2(0.15, 1)},
		{"pos": Vector2(332, 420), "dir": Vector2(-0.15, 1)},
	]

func build(table: PinballTable) -> void:
	table.add_wall_poly([Vector2(0, 230), Vector2(44, 280), Vector2(0, 300)])  # pared convexa
	table.add_flipper(Vector2(338, 262), false)  # flipper extra (botón derecho)
```

## Agregar un módulo

Un archivo en `scripts/tables/modules/` que extienda `TableModule`:

```gdscript
extends TableModule

func _init() -> void:
	id = &"mi_pieza"
	display_name = "Mi pieza"
	sizes = ["S", "M"]      # en qué encastres entra
	weight = 1.0            # qué tan seguido aparece
	min_night = 1
	events = {&"mi_evento": {"text": "Activá mi pieza", "goal": 5}}  # para objetivos

func build() -> void:
	# center() = centro del encastre (en píxeles de mesa); rects = encastres.
	# Crear cuerpos/áreas, o usar table.add_bumper(...) / table.add_target(...).
	pass

# Al pasar algo:
#   score(&"mi_pieza", 300.0, posición)   suma puntos (pasa por objetos y multiplicadores)
#   event(&"mi_evento", posición)          cuenta para objetivos y combos
```

Herramientas que da la mesa a los módulos:

| Para | Usar |
|---|---|
| Un cuerpo que reaccione al tocar la bola | método `ball_hit(ball)` en el cuerpo |
| Que la onda de la catapulta lo afecte | método `shock()` en el nodo |
| Llevarse la bola (riel, vórtice, catapulta) | `table.capture_ball()` y después `table.release_ball(pos, vel)` |
| Dibujar la bola mientras la tiene | `TableFx.HeldBall` (con `height` para que "vuele") |
| Efectos | `TableFx.burst(...)` (chispas), `TableFx.ring(...)` (onda), `table.hitstop`, `table.rumble`, `table.start_shake` |

**Regla de física:** la bola no se teletransporta. Para moverla se la saca de
la mesa (`capture_ball`) y se crea una nueva (`release_ball`). Mover un cuerpo
rígido de golpe en Godot arrastra contactos y puede dejarlo del otro lado de
una pared.

## Módulos actuales

| Módulo | Tamaño | Qué hace |
|---|---|---|
| Trío de bumpers | L | Tres bumpers en triángulo (central). |
| Bumpers en órbita | L | Tres bumpers que giran; cada golpe los acelera y cada tanto cambian de sentido (central). |
| Banco de dianas | M | Tres dianas; al bajarlas, +1 al multiplicador de la bola. |
| Muro de ladrillos | M | Ocho ladrillos (los de arriba aguantan 2 golpes) que reaparecen; romper el muro = +1 multiplicador y se reconstruye en cascada. |
| Riel guiado | S | Si la bola entra yendo hacia arriba, recorre un riel elevado y sale por el carril de un flipper. |
| Portales | S + S | Entra por uno, sale por el otro con la misma velocidad. |
| Catapulta | S, M | Atrapa la bola y la lanza por el aire (con sombra); al aterrizar, una onda golpea lo que esté cerca. |
| Vórtice | S, M | Chupa la bola en espiral y la escupe hacia arriba en una dirección al azar. |

## Objetivos secundarios (`table_objective.gd`)

La partida **siempre se gana con el puntaje**. Cada partida tiene 2 objetivos
de tipos distintos, armados con los eventos de las piezas de la mesa:

| Tipo | Ejemplo | Premio |
|---|---|---|
| Contar | Cruzá portales 0/6 | Fichas |
| Hazaña | Completá el banco de dianas 0/2 | +1 al multiplicador por toda la partida |
| Combo | 3 piezas distintas en 5 s | Puntos (15 % del objetivo) |

## Robot de prueba

- **Panel F2 → "Robot juega":** el robot juega la mesa actual y en el panel
  se ve cuánto dura cada bola, si se trabó, etc. "Mesa al azar" genera otra
  mesa (se puede forzar el chasis).
- **Prueba masiva:** `godot --headless --path . --fixed-fps 60 -- --robot 60 60`
  (60 mesas, 60 segundos de juego cada una). Marca con `!!` las mesas donde la
  bola se trabó o se escapó (con la posición) y al final muestra qué piezas
  casi no se usan. El reporte queda en `user://robot_report.txt`.

Correrla siempre después de agregar un chasis o un módulo.
