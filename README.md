# Pinball Roguelike — Prototipo de física

Primer prototipo del roguelike de pinball ambientado en un arcade. El objetivo de esta etapa es uno solo: **que pegarle a la bola se sienta bien**. No hay arte, tienda ni rivales todavía; solo una mesa gris para afinar la física.

## Cómo abrirlo

1. Abrí Godot **4.7** (edición estándar).
2. En el administrador de proyectos: **Importar** → elegí el archivo `project.godot` de esta carpeta.
3. Apretá **F5** (o el botón ▶) para jugar.

## Controles

| Acción | Teclado | Joystick PS4 |
| --- | --- | --- |
| Flipper izquierdo | Z / Shift izquierdo | L1 o L2 |
| Flipper derecho | M / Shift derecho | R1 o R2 |
| Lanzar (mantener y soltar) | Espacio | Cruz |
| Sacudir la mesa | Flechas ← → ↑ | Cruceta o stick derecho |
| Soltar una bola de prueba en el centro | B | Triángulo |
| Cámara lenta (x0.25) | T | Cuadrado |
| Mostrar/ocultar panel de ajuste | Tab | Share |
| Reiniciar | R | Options |

Sacudir más de 3 veces en 3 segundos provoca **TILT**: los flippers se apagan hasta que perdés la bola.

## Panel de ajuste (Tab)

Todos los valores de física se cambian en vivo con los sliders, mientras jugás. Se guardan solos y se recuerdan la próxima vez que abras el juego.

- **Restaurar valores por defecto**: vuelve a los valores originales.
- **Copiar valores al portapapeles**: copia los valores en JSON para compartirlos.

Para probar el tacto de los flippers rápido, usá **B** (suelta una bola en el centro) y **T** (cámara lenta).

El panel también controla el **volumen de los efectos**, la **intensidad de la vibración** del joystick y el **congelamiento en los impactos** (0 lo desactiva).

## La mesa

- **Bumpers** (100 puntos) y **slingshots** (10 puntos).
- **Banco de 3 dianas** arriba (250 cada una). Tirar las tres da **2000 de bonus** y vuelven a subir.
- **Inlanes y outlanes**: a cada lado, un poste separa el carril que lleva al flipper (inlane) del que se lleva la bola (outlane). Ahí es donde el sacudón salva bolas.
- **Deflectores laterales** que despegan la bola de la pared para que no baje directo al outlane.

## Juice

- Sonidos retro provisorios en `assets/sfx/`, generados con `python tools/gen_sfx.py`. Se reemplazan por los definitivos sin tocar el código, manteniendo los nombres.
- Vibración del joystick en flippers, golpes, lanzamiento, sacudón, tilt y bola perdida.
- Puntos flotantes en cada impacto.
- Congelamiento breve (hitstop) en los golpes fuertes.

## Estructura

```
scenes/main.tscn        Escena principal (la mesa se arma por código)
scripts/main.gd         Mesa, lanzador, puntaje, bolas, sacudón/tilt
scripts/ball.gd         Bola (cuerpo rígido con CCD y gravedad propia)
scripts/flipper.gd      Flippers cinemáticos controlados por código
scripts/bumper.gd       Bumpers redondos
scripts/slingshot.gd    Slingshots triangulares
scripts/tuning.gd       Parámetros ajustables (autoload "Tuning")
scripts/tuning_panel.gd Panel de sliders
scripts/game_input.gd   Acciones de teclado y joystick (autoload "GameInput")
scripts/hud.gd          Puntaje, mensajes y ayuda
scripts/shapes.gd       Utilidad para formas de colisión
scripts/post.gd         Postes de goma (separan inlane y outlane)
scripts/drop_target.gd  Dianas abatibles
scripts/floating_text.gd Puntos flotantes
scripts/sfx.gd          Efectos de sonido (autoload "Sfx")
assets/sfx/             Sonidos .wav
tools/gen_sfx.py        Generador de los sonidos provisorios
tests/self_test.gd      Autoprueba de física sin ventana
```

## Autoprueba de física

Mide los golpes de los flippers, los bumpers, los slingshots y el lanzador; dispara la bola a máxima velocidad en 60 direcciones para verificar que no atraviese paredes; prueba outlanes, inlanes, deflectores y el banco de dianas; y juega 40 segundos al azar:

```
godot --headless --path . --fixed-fps 60 -- --selftest
```

## Decisiones técnicas

- **Física a 240 Hz** con interpolación para que se vea suave en cualquier monitor.
- **La bola usa CCD** (detección continua) y **las paredes son bloques gruesos**, así no las atraviesa a alta velocidad.
- **Los flippers se mueven por código**, no por física: el golpe es instantáneo y siempre igual.
- **La bola no se teletransporta**: cuando hay que ponerla en otro lugar se crea una nueva. Mover un cuerpo rígido en Godot arrastra contactos del lugar viejo y puede dejarla del otro lado de una pared.

## Pendientes conocidos

- El arco superior siempre manda la bola por el lado izquierdo (ahora el deflector la despega de la pared).
- Falta una rampa: en 2D necesita capas de colisión que cambian, y conviene hacerla junto con el arte.
- Si la bola vuelve a caer por el carril del lanzador, se relanza (no hay compuerta de un solo sentido).
- La resolución de pixel art y el arte definitivo se deciden en la fase siguiente.
