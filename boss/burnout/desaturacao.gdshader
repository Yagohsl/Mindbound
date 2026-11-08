shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float desaturation : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);
	
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(color.rgb, vec3(gray), desaturation), color.a);
}
