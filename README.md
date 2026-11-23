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
tests/self_test.gd      Autoprueba de física sin ventana
```

## Autoprueba de física

Mide los golpes de los flippers, los bumpers, los slingshots y el lanzador, dispara la bola a máxima velocidad en 60 direcciones para verificar que no atraviese paredes, y juega 40 segundos al azar:

```
godot --headless --path . --fixed-fps 60 -- --selftest
```

## Decisiones técnicas

- **Física a 240 Hz** con interpolación para que se vea suave en cualquier monitor.
- **La bola usa CCD** (detección continua) y **las paredes son bloques gruesos**, así no las atraviesa a alta velocidad.
- **Los flippers se mueven por código**, no por física: el golpe es instantáneo y siempre igual.
- **La bola no se teletransporta**: cuando hay que ponerla en otro lugar se crea una nueva. Mover un cuerpo rígido en Godot arrastra contactos del lugar viejo y puede dejarla del otro lado de una pared.

## Pendientes conocidos

- El arco superior siempre manda la bola por el lado izquierdo; más adelante conviene sumar un deflector o una compuerta.
- Si la bola vuelve a caer por el carril del lanzador, se relanza (no hay compuerta de un solo sentido).
- La resolución de pixel art y el arte definitivo se deciden en la fase siguiente.
