// Fondo del menú: escala el pixel art nítido (igual que sharp_pixels) y anima
// sus propios píxeles según la máscara arcade_fx.png (ver tools/gen_menu_fx.py):
// pantallas que "juegan", neón que parpadea, luces que titilan y lámparas.
shader_type canvas_item;

uniform sampler2D fx : filter_nearest;
uniform vec2 tex_size = vec2(480.0, 270.0);
uniform float time = 0.0;
uniform vec3 neon = vec3(1.0);  // encendido del neón: rosa, celeste, azul

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 texel = UV * tex_size;
	vec2 scale = max(1.0 / max(fwidth(texel), vec2(1e-5)), vec2(1.0));
	vec2 base = floor(texel);
	vec2 d = fract(texel) - 0.5;
	vec2 r = 0.5 - 0.5 / scale;
	vec2 f = (d - clamp(d, -r, r)) * scale + 0.5;
	vec4 col = texture(TEXTURE, (base + f) / tex_size);

	vec4 m = texelFetch(fx, ivec2(clamp(base, vec2(0.0), tex_size - 1.0)), 0);
	float screen = m.r;
	float neon_id = floor(m.g * 255.0 / 60.0 + 0.5);
	float light = m.b * 255.0;

	if (screen > 0.0) {
		// Cada pantalla tiene su propio "juego": bloques que cambian, brillo
		// que respira y una franja que recorre la pantalla de arriba abajo.
		float p = screen * 255.0;
		float cell = hash(floor(base / vec2(3.0, 2.0)) + floor(time * 3.0 + p) * 1.37);
		float breathe = 0.92 + 0.08 * sin(time * 2.0 + p);
		float bar = smoothstep(0.85, 1.0, fract(base.y / 8.0 - time * 0.5 + p * 0.13));
		col.rgb *= breathe * (0.85 + 0.3 * cell);
		col.rgb += vec3(0.1) * bar;
	}
	if (neon_id > 0.5) {
		float k = neon_id < 1.5 ? neon.x : (neon_id < 2.5 ? neon.y : neon.z);
		col.rgb *= mix(0.3, 1.15, k);
	}
	if (light > 0.5 && light < 127.5) {
		// Luces de los flippers y marquesinas: titilan cada una a su ritmo.
		// Se encienden por grupos (fase redondeada) para que parezcan luces
		// de verdad y no estática.
		float ph = floor(hash(floor(base / 4.0)) * 6.0) / 6.0;
		float on = step(0.5, fract(time * 0.8 + ph));
		col.rgb *= 0.85 + 0.25 * on;
	} else if (light >= 127.5) {
		col.rgb *= 0.94 + 0.08 * sin(time * 6.0 + light);
	}
	COLOR = col * tint;
}
