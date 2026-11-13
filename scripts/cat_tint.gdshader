shader_type canvas_item;
// 줄줄이 시험판 길고양이 색 바꾸기: 주황 털(줄무늬 포함)을 dark~light 색으로, 초록 목도리를 light(가슴 흰 털)로.
// 진한 갈색 테두리(밝기 낮음)와 흰 발·볼(채도 낮음)은 그대로 둔다. 초록 목도리는 주인공만.
uniform vec3 dark : source_color;
uniform vec3 light : source_color;

vec3 hsv(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float h = 0.0;
	if (d > 0.0001) {
		if (mx == c.r) { h = mod((c.g - c.b) / d, 6.0); }
		else if (mx == c.g) { h = (c.b - c.r) / d + 2.0; }
		else { h = (c.r - c.g) / d + 4.0; }
	}
	return vec3(h / 6.0, mx > 0.0 ? d / mx : 0.0, mx);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 p = hsv(c.rgb);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float keep_line = smoothstep(0.30, 0.42, lum);  // 테두리는 그대로
	float fur = smoothstep(0.14, 0.28, p.y) * (1.0 - smoothstep(0.15, 0.19, p.x) * step(p.x, 0.9)) * keep_line;
	float scarf = smoothstep(0.08, 0.18, p.y) * smoothstep(0.2, 0.25, p.x) * (1.0 - smoothstep(0.5, 0.55, p.x));
	vec3 fur_color = mix(dark, light, smoothstep(0.35, 0.85, lum));
	vec3 rgb = mix(c.rgb, fur_color, fur);
	rgb = mix(rgb, light * (0.85 + 0.15 * lum), scarf);
	COLOR = vec4(rgb, COLOR.a);  // COLOR는 이미 그림 색 x 모듈레이트라 다시 곱하지 않음 (알파만: 도망갈 때 흐려짐)
}
