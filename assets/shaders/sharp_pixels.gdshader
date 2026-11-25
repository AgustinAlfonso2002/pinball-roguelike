// Escala pixel art a cualquier tamaño sin que se deforme ni se vea borroso
// ("sharp bilinear"): cada pixel queda nítido y solo el borde entre dos
// píxeles se suaviza cuando la escala no es entera. Con escala entera
// (por ejemplo 1080p) el resultado es idéntico a "nearest".
// El nodo tiene que usar filtro LINEAR.
shader_type canvas_item;

uniform vec2 tex_size = vec2(640.0, 360.0);

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 texel = UV * tex_size;
	vec2 scale = max(1.0 / max(fwidth(texel), vec2(1e-5)), vec2(1.0));
	vec2 base = floor(texel);
	vec2 d = fract(texel) - 0.5;
	vec2 r = 0.5 - 0.5 / scale;
	vec2 f = (d - clamp(d, -r, r)) * scale + 0.5;
	COLOR = texture(TEXTURE, (base + f) / tex_size) * tint;
}
