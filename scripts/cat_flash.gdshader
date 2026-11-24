shader_type canvas_item;
// 피격 하얀 번쩍임 (카툰): 털·목도리는 흰색으로 덮고 짙은 고동 선(#331806, 밝기 약 0.12)은 그대로 둔다.
// 곱하는 색(modulate)으로는 하얗게 만들 수 없고 빨간 칠은 색만 바꾼 그림처럼 보여서
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(1.0), flash * smoothstep(0.18, 0.32, lum));
	COLOR = c;
}
