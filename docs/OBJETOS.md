# Cómo agregar, quitar y modificar objetos

Cada objeto es **un archivo** en `scripts/items/catalog/`. El juego los carga solos al arrancar:

- **Agregar un objeto:** crear un archivo `.gd` nuevo en esa carpeta.
- **Quitarlo:** borrar el archivo, o poner `enabled = false` en su `_init()` para que no aparezca en la tienda.
- **Balancearlo:** cambiar `price`, `rarity` o los números dentro del archivo.

No hay que registrar nada en otro lado.

## Plantilla mínima

```gdscript
extends Item


func _init() -> void:
	id = &"mi_objeto"                  # único, en minúsculas, sin espacios
	display_name = "Mi objeto"
	description = "Qué hace, en una línea."
	price = 4                          # en fichas
	kind = Kind.PASSIVE                # PASSIVE, BALL o CONSUMABLE
	rarity = Rarity.COMMON             # COMMON, UNCOMMON, RARE, LEGENDARY
	color = Color(1, 0.8, 0.3)         # color del ícono provisorio


func on_hit(_session, hit: HitEvent) -> void:
	if hit.source == &"bumper":
		hit.base += 50.0
```

## Tipos de objeto

| Tipo | Cómo funciona | Límite |
| --- | --- | --- |
| `PASSIVE` | Efecto permanente durante la run | 5 espacios |
| `BALL` | Tipo de bola; comprar otra reemplaza la actual | 1 |
| `CONSUMABLE` | Se usa una vez con E/Q (Círculo/Cuadrado), o se activa solo | 2 espacios |

## Cómo se calcula el puntaje

Cada golpe que da puntos es un `HitEvent` que pasa por todos los objetos antes de sumarse:

```
puntos = base × (multiplicador de la bola + mult_add) × xmult
```

- `hit.base`: puntos base del golpe (bumper 100, slingshot 10, diana 250, banco 2000, poste 5).
- `hit.mult_add`: suma al multiplicador (+1, +2...).
- `hit.xmult`: multiplica el total (×1,5, ×2...).
- El **multiplicador de la bola** empieza en 1, sube +1 con cada banco de dianas completo y vuelve a 1 al perder la bola.
- `hit.source` dice qué se golpeó: `&"bumper"`, `&"sling"`, `&"target"`, `&"bank"`, `&"post"`.

## Ganchos disponibles

Todos son opcionales: se sobrescriben solo los que el objeto necesita. `session` es la partida actual (`GameSession`).

| Gancho | Cuándo se llama |
| --- | --- |
| `modify_stat(stat, value) -> float` | Cada vez que el juego consulta una estadística (ver abajo) |
| `on_acquire()` / `on_remove()` | Al comprarlo / venderlo o gastarlo |
| `on_game_start(session)` / `on_game_end(session, won)` | Al empezar / terminar una partida o duelo |
| `on_hit(session, hit)` | Antes de sumar un golpe (se puede modificar `hit`) |
| `after_hit(session, hit, points)` | Después de sumarlo, con los puntos finales |
| `on_flipper(session, left, up)` | Al mover un flipper |
| `on_ball_launched(session, power)` | Al lanzar la bola (power de 0 a 1) |
| `on_ball_lost(session)` | Al perder una bola |
| `on_bank_completed(session)` | Al completar el banco de dianas |
| `on_tick(session, delta)` | Cada frame de la partida |
| `configure_ball(ball)` | Cada bola nueva (color, etc.) |
| `on_table_built(session, table)` | Al armar la mesa (para agregar elementos) |
| `try_save_ball(session) -> bool` | Al perder una bola: `true` la salva |
| `use(session) -> bool` | Consumibles: al usarlo; `true` = se gastó |
| `get_description() -> String` | Texto de la tienda (puede mostrar contadores) |

## Estadísticas que se pueden modificar

Con `modify_stat` se cambian los valores base. Varios objetos se aplican uno tras otro.

**Física** (sus valores base están en el panel de ajuste, Tab): `gravity`, `ball_bounce`, `ball_friction`, `wall_bounce`, `flipper_up_speed`, `flipper_down_speed`, `flipper_bounce`, `bumper_kick`, `sling_kick`, `plunger_max`, `plunger_charge_time`, `nudge_force`, `max_ball_speed`.

**Juego:** `balls_per_game` (3), `shop_slots` (4), `reroll_base_cost` (1), `coins_per_ball_left` (1), `game_reward` (3), `duel_reward` (5), `bank_bonus` (2000), `price_multiplier` (1).

Para agregar una estadística nueva, sumarla a `BASE_STATS` en `scripts/run.gd` y leerla con `Run.stat(&"nombre")` donde corresponda.

## Herramientas útiles dentro de un objeto

| Qué | Cómo |
| --- | --- |
| Dar fichas | `Run.add_coins(1)` |
| Mostrar un mensaje | `session.message("¡Texto!")` |
| Texto flotante en la mesa | `session.popup("+1 ficha", hit.position, Color.GOLD)` |
| Puntos ×N por un tiempo | `session.add_buff("Nombre", 2.0, 10.0)` |
| Cámara lenta | `session.table.set_effect_slowmo(0.5, 6.0)` |
| Línea extra en el resumen de la partida | `session.extra_rewards.append("Texto")` |
| Datos de la partida | `session.score`, `session.target`, `session.multiplier`, `session.balls_left`, `session.elapsed` |
| Datos de la run | `Run.night`, `Run.coins`, `Run.passives` |

Un objeto puede guardar su propio estado en variables (ver `racha.gd` y `bola_dorada.gd`).

## Objetos de prueba incluidos

| Archivo | Tipo | Qué demuestra |
| --- | --- | --- |
| `iman_de_bumpers.gd` | Pasivo | Sumar puntos base |
| `goma_nueva.gd` | Pasivo | Puntos + estadística de física |
| `ficha_de_la_suerte.gd` | Pasivo | Sumar al multiplicador |
| `flippers_aceitados.gd` | Pasivo | Estadística de física |
| `mesa_inclinada.gd` | Pasivo | Estadística de física (gravedad) |
| `banco_doble.gd` | Pasivo | Estadística de juego |
| `racha.gd` | Pasivo | Estado propio + gancho de flipper |
| `ahorrista.gd` | Pasivo | Economía al terminar la partida |
| `bola_extra.gd` | Pasivo | Más bolas por partida |
| `bola_de_plomo.gd` | Bola | Color + física + puntos |
| `bola_dorada.gd` | Bola | Contador que da fichas |
| `camara_lenta.gd` | Consumible | Uso activo |
| `doble_o_nada.gd` | Consumible | Potenciador temporal |
| `salvavidas.gd` | Consumible | Se activa solo al perder la bola |

## Rivales

Funcionan igual, en `scripts/rivals/catalog/`, extendiendo `Rival`. Definen sus frases, su trampa (`sabotage(session)`) y cada cuánto la usan. La mesa ofrece `shove_ball()`, `blackout()` y `jam_flipper()` para las trampas. El rival con `boss = true` aparece en la última noche.
