shader_type canvas_item;
// 스킨: 보라색 로브 부분만 색상(hue)을 돌리고 채도·밝기를 바꾼다 (얼굴·지팡이는 그대로). 마법사 그림에만 쓴다.
uniform float hue = 0.0;
uniform float target = 0.74;  // 바꿀 색 (로브 보라)
uniform float width = 0.12;  // 이 범위 안의 색만
uniform float sat = 1.0;
uniform float val = 1.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec3 h = rgb2hsv(c.rgb);
	float d = abs(fract(h.x - target + 0.5) - 0.5);
	float w = (1.0 - smoothstep(width * 0.6, width, d)) * smoothstep(0.08, 0.18, h.y);
	vec3 o = h;
	o.x = fract(h.x + hue);
	o.y = clamp(h.y * sat, 0.0, 1.0);
	o.z = clamp(h.z * val, 0.0, 1.0);
	COLOR = vec4(mix(c.rgb, hsv2rgb(o), w), c.a);
}
