# FICHINLIKE

*A pinball roguelike.* Roguelike de pinball ambientado en un torneo en un arcade de barrio de los 80/90 (los "fichines").

**Estado:** Fase 2 en curso. Ya están el loop del roguelike, el menú de inicio animado en pixel art, el guardado y el manejo completo con joystick.

## Cómo abrirlo

1. Abrí Godot **4.7** (edición estándar).
2. Importá el archivo `project.godot` de esta carpeta.
3. Apretá **F5**.

## Menú de inicio

- **Nueva partida**: empieza una run (si había una guardada, pregunta antes de borrarla).
- **Continuar**: retoma la partida guardada. Debajo se ve en qué noche y etapa quedó.
- **Salir**.

**Guardado automático:** al empezar cada partida o duelo y al entrar a la tienda (en `user://partida.json`). Si salís en medio de una partida, al continuar empezás esa etapa de nuevo. La partida guardada se borra al perder la run.

**Pausa:** Options / Esc durante la partida → Seguir jugando o Salir al menú.

Todo el juego (menús, carteles, tienda, pausa) se maneja con el joystick: cruceta o stick para moverse, Cruz para aceptar, Círculo para volver.

## Cómo se juega

Una run son **7 noches**. **Cada noche es una máquina distinta**: la mesa se arma sola a partir de la semilla de la run (forma, piezas y objetivos cambian), así que ninguna run es igual a otra. Ver [docs/MESAS.md](docs/MESAS.md). Cada noche:

1. **Partida 1** y **Partida 2**: llegá al puntaje objetivo antes de quedarte sin bolas.
2. **Duelo**: un rival suma su puntaje en vivo y te hace trampas. Superá su puntaje final antes de quedarte sin bolas.

Al alcanzar el objetivo ya ganaste, pero **seguís jugando la bola actual** hasta perderla (los flippers siguen andando). Cada bola que no llegaste a usar da **+1 ficha**. En los duelos, el rival te sigue saboteando hasta que pierdas esa bola.
3. **Tienda**: comprá objetos con las fichas que ganaste. Podés renovar la oferta o vender lo que tengas.

Si perdés una partida, termina la run. Si ganás la noche 7, sos campeón y podés seguir en el **modo infinito**.

- **Puntaje** = puntos base × (multiplicador de la bola + bonus) × multiplicadores de objetos.
- **Multiplicador de la bola**: +1 cada vez que completás el banco de dianas o rompés el muro de ladrillos; vuelve a ×1 al perder la bola.
- **Objetivos extra**: cada partida tiene 2 (por ejemplo "Cruzá portales 0/6" o "Combo: 3 piezas distintas en 5 s"). La partida se gana igual con el puntaje; los objetivos dan fichas, multiplicador para toda la partida o puntos.
- **Fichas**: 3 por ganar una partida, 5 por ganar un duelo, +1 por cada bola que no llegaste a usar.

## Controles

| Acción | Teclado | Joystick PS4 |
| --- | --- | --- |
| Flipper izquierdo | Z / Shift izquierdo | L1 o L2 |
| Flipper derecho | M / Shift derecho | R1 o R2 |
| Lanzar (mantener y soltar) | Espacio | Cruz |
| Sacudir la mesa | Flechas ← → ↑ | Cruceta o stick derecho |
| Usar consumible 1 / 2 | E / Q | Círculo / Cuadrado |
| Pausa | Esc / P | Options |
| Moverse en menús | Flechas | Cruceta o stick izquierdo |
| Aceptar en menús | Espacio / Enter | Cruz |
| Volver / cerrar | Esc | Círculo |

Sacudir más de 3 veces en 3 segundos provoca **TILT**: los flippers se apagan hasta que perdés la bola.

**Solo en desarrollo** (al correr desde Godot; no existen en el juego exportado):

| Acción | Tecla |
| --- | --- |
| Panel de depuración (objetos, fichas, ganar, bolas infinitas) | F2 |
| Panel de ajuste de física (incluye la velocidad del juego) | Tab / Share |
| Soltar una bola de prueba en el centro | B / Triángulo |
| Cámara lenta (x0,25) | T |

### Panel de depuración (F2)

- **Objetos del catálogo:** botón **Dar** para recibir cualquier objeto al instante, sin fichas ni límite de espacios, para probar combinaciones. Se puede filtrar por tipo. Pasá el mouse por el nombre para ver la descripción.
- **Tus objetos:** botón **Quitar**.
- **+10 fichas**, **Ganar partida**, **Perder bola**, **Bolas infinitas**.
- **Noche −1 / +1** e **Ir al duelo**: para probar objetivos y rivales de otras noches.
- Muestra el estado de la partida y la velocidad de la bola en vivo.

Los objetos se pueden dar con una run en curso (después de tocar **Empezar**).

### Velocidad del juego

En el panel de ajuste (Tab), **Velocidad del juego** ralentiza o acelera todo por igual (bola, flippers, rivales) sin cambiar cómo rebota la bola. Por defecto está en **0,8**. Para que la bola sea menos caótica sin hacer todo más lento, también sirven **Gravedad**, **Velocidad máxima de la bola** y las fuerzas de **bumper** y **slingshot**.

## Arte

- **Estilo:** arcade de barrio de los 80/90 de noche, con neón rosa y celeste y luz cálida de lámparas. La paleta de la interfaz está en `scripts/game/ui_theme.gd`.
- **Fondo del menú:** `assets/art/menu/arcade_bg.png` (480 × 270), hecho con **Retro Diffusion** (modelo RD Core). Se anima con sus propios píxeles: el shader `assets/shaders/arcade_bg.gdshader` usa la máscara `arcade_fx.png`, que marca pantallas, tubos de neón, luces y lámparas. Si se cambia el fondo, ajustar las zonas en `tools/gen_menu_fx.py` y correrlo (numpy, scipy, Pillow). Encima, `scripts/menu/title_screen.gd` dibuja los halos del neón, el polvo en la luz y el logo.
- **Logo:** `python tools/gen_logo.py` genera las capas del cartel de neón (`assets/art/menu/logo_*.png`).
- **IA y Steam:** el arte hecho con IA hay que declararlo en el formulario de contenido de Steam ("contenido generado previamente").
- **Fuentes:** Jersey 15 (textos y botones), Jersey 10 (títulos) y Micro 5 (puntos sobre la mesa), con licencia SIL OFL (`assets/fonts/OFL-*.txt`): libres para usar en un juego comercial. Cada fuente tiene una grilla de píxeles propia y solo se ve nítida en múltiplos exactos: usar siempre las constantes de `scripts/game/game_fonts.gd` (27, 56, 54, 11, 22).

## Resolución

La pantalla mide **1920 × 1080** y Godot la escala a la ventana (`canvas_items`, sin deformar). Mezcla tres tamaños de pixel, como los juegos de pixel art modernos:

| Capa | Resolución | Cada pixel ocupa |
|---|---|---|
| Fondos ilustrados | 480 × 270 | 4 × 4 de pantalla |
| Mesa de pinball | 640 × 360 | 3 × 3 |
| Interfaz y textos | 960 × 540 | 2 × 2 |

En 1080p y 4K todo cae justo; en otras resoluciones el shader `sharp_pixels.gdshader` mantiene los píxeles nítidos. El juego arranca en pantalla completa; **F11** (o Alt + Enter) cambia a ventana. La mesa se diseñó en unidades de 400 × 640 y se dibuja a la mitad (`Geom.S = 0,5`).

## Objetos y rivales

Cada objeto es un archivo en `scripts/items/catalog/` y cada rival, uno en `scripts/rivals/catalog/`. Se cargan solos: para agregar uno se crea un archivo, para quitarlo se borra. **Guía completa: [docs/OBJETOS.md](docs/OBJETOS.md).**

## Mesas

Cada mesa = un **chasis** (forma de la parte de arriba, paredes, flippers extra y encastres) + **módulos** en los encastres. La parte de abajo (flippers, slingshots, carriles, lanzador) es igual en todas. Hoy hay 3 chasis (Clásica, Embudo, Altillo con tercer flipper), cada uno con encastres también en la cúpula de arriba, y 12 módulos (trío de bumpers, bumpers en órbita, mini bumpers, banco de dianas, muro de ladrillos, carriles de luz, barrera móvil, molinete, riel guiado, portales, catapulta y vórtice). Los flippers extra se mueven con el botón de su lado. Agregar uno = agregar un archivo. **Guía, reglas del generador y robot de prueba: [docs/MESAS.md](docs/MESAS.md).**

Para probar: panel **F2** → "Mesa al azar" (podés elegir el chasis) y "Robot juega". Prueba masiva:

```
godot --headless --path . --fixed-fps 60 -- --robot 60 60
```

## Estructura

```
scenes/main.tscn            Escena principal
scripts/main.gd             Capas de pantalla, flujo del juego y pausa
scripts/menu/title_screen.gd  Menú de inicio animado
scripts/save_game.gd        Guardar / cargar partida
scripts/game/pause_menu.gd  Menú de pausa
scripts/game/focus_keeper.gd  Recupera el foco para el joystick
scripts/game/game_fonts.gd  Fuentes pixel
scripts/game/art.gd         Carga de imágenes
scripts/run.gd              Estado de la run, estadísticas, objetivos (autoload "Run")
scripts/table.gd            La mesa: parte fija, física, lanzador, sacudón, sabotajes, juice
scripts/tables/table_generator.gd  Arma mesas y objetivos a partir de una semilla
scripts/tables/chassis/     Un archivo por chasis
scripts/tables/modules/     Un archivo por módulo (pieza de la mesa)
scripts/tables/table_objective.gd  Objetivos secundarios
scripts/tables/table_robot.gd      Robot que juega solo; robot_runner.gd prueba muchas mesas
scripts/tables/table_fx.gd  Chispas, ondas y la bola "en el aire"
scripts/game/session.gd     Una partida o duelo: puntaje, bolas, victoria/derrota
scripts/game/hit_event.gd   Un golpe que da puntos
scripts/game/shop_screen.gd Tienda
scripts/game/card_screen.gd Carteles (intro, resultados, fin de run)
scripts/game/ui_theme.gd    Tema visual provisorio
scripts/game/fmt.gd         Formato de números grandes
scripts/hud.gd              HUD de la partida
scripts/items/item.gd       Clase base de los objetos (ganchos)
scripts/items/item_registry.gd  Carga el catálogo (autoload "Items")
scripts/items/catalog/      Un archivo por objeto
scripts/rivals/rival.gd     Clase base de los rivales
scripts/rivals/catalog/     Un archivo por rival
scripts/ball.gd, flipper.gd, bumper.gd, slingshot.gd, post.gd, drop_target.gd
                            Elementos de la mesa
scripts/tuning.gd           Valores base de física (autoload "Tuning")
scripts/tuning_panel.gd     Panel de ajuste (solo en desarrollo)
scripts/debug_panel.gd      Panel de depuración F2 (solo en desarrollo)
scripts/sfx.gd              Sonidos (autoload "Sfx")
scripts/game_input.gd       Teclado y joystick (autoload "GameInput")
assets/sfx/                 Sonidos .wav provisorios
tools/gen_sfx.py            Generador de los sonidos provisorios
tools/gen_logo.py           Generador del logo de neón
tools/gen_menu_fx.py        Máscara de animación del fondo del menú
assets/art/menu/            Fondo, máscara y logo del menú
assets/shaders/             Shaders de pixel nítido y del fondo animado
assets/fonts/               Fuentes pixel (OFL)
tests/self_test.gd          Autoprueba
docs/OBJETOS.md             Guía de objetos y rivales
docs/MESAS.md               Guía de mesas: chasis, módulos, objetivos y robot
```

## Autoprueba

59 pruebas de física (flippers, bumpers, lanzador, paredes, outlanes, dianas), de juego (catálogo, puntaje, estadísticas, tienda, partidas, duelos, consumibles), de mesas generadas (reglas del generador, cada módulo, objetivos y el robot jugando 3 mesas) y de guardado, menús y tamaños de fuente:

```
godot --headless --path . --fixed-fps 60 -- --selftest
```

## Decisiones técnicas

- **Física a 240 Hz** con interpolación para que se vea suave en cualquier monitor.
- **La bola usa CCD** y **las paredes son bloques gruesos** (30 px) que se superponen en el arco, así no las atraviesa.
- **Los flippers se mueven por código**, no por física: el golpe es instantáneo y siempre igual.
- **La bola no se teletransporta**: cuando hay que ponerla en otro lugar se crea una nueva, porque mover un cuerpo rígido en Godot arrastra contactos del lugar viejo.
- **Los valores del panel se guardan en `user://tuning_v2.cfg`**. Los de la versión anterior no se cargan, porque eran para la mesa a escala 1.

## Pendientes

- Arte pixel art de la mesa, los rivales y la tienda con Retro Diffusion; música (Fase 2).
- Afiches del fondo del menú: tienen letras sin sentido (típico de la IA); retocarlos.
- Temas de máquina por ubicación (nombre, colores, piezas favoritas, regla propia) y más chasis y módulos.
- Variantes de la parte de abajo (carriles anchos, poste salvador) y multibola.
- Reputación, mejoras permanentes y mapa de arcades (después del MVP).
