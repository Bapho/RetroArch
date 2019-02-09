#version 450

layout(push_constant) uniform Push
{
	float edgeStrength;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

#pragma parameter edgeStrength "Edge Detection" 50.0 0.0 100.0 0.01

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

float CLength(vec4 c)
{
	float rmean = c.x*0.5;
	c*= c;
	return sqrt((2.0+rmean)*c.x+4.0*c.y+(3.0-rmean)*c.z)/3.0;
}

vec3 rgb_to_hsv(vec3 RGB)
{
    float minVal = min(min(RGB.x,RGB.y),RGB.z);
    float maxVal = max(max(RGB.x,RGB.y),RGB.z);
    float delta = maxVal - minVal;             //Delta RGB value 
    vec3 HSV;
    HSV.z = maxVal;
    if (delta != 0.0) {                    // If gray, leave H & S at zero
       HSV.y = delta / maxVal;
       vec3 delRGB;
       delRGB = (((vec3(maxVal) - RGB)/6.0)+(delta/2.0))/delta;
       if      (RGB.x == maxVal) HSV.x = delRGB.z - delRGB.y;
       else if (RGB.y == maxVal) HSV.x = (1.0/3.0) + delRGB.x - delRGB.z;
       else if (RGB.z == maxVal) HSV.x = (2.0/3.0) + delRGB.y - delRGB.x;
       if (HSV.x < 0.0) { HSV.x += 1.0; }
       if (HSV.x > 1.0) { HSV.x -= 1.0; }
    }
    return HSV;
}

vec3 hsv_to_rgb(vec3 HSV)
{
    vec3 RGB = vec3(HSV.z);
    if ( HSV.y != 0.0 ) {
       float var_h = HSV.x * 6.0;
       float var_i = floor(var_h);  
       float var_1 = HSV.z * (1.0 - HSV.y);
       float var_2 = HSV.z * (1.0 - HSV.y * (var_h-var_i));
       float var_3 = HSV.z * (1.0 - HSV.y * (1.0-(var_h-var_i)));
       if      (var_i == 0.0) { RGB = vec3(HSV.z, var_3, var_1); }
       else if (var_i == 1.0) { RGB = vec3(var_2, HSV.z, var_1); }
       else if (var_i == 2.0) { RGB = vec3(var_1, HSV.z, var_3); }
       else if (var_i == 3.0) { RGB = vec3(var_1, var_2, HSV.z); }
       else if (var_i == 4.0) { RGB = vec3(var_3, var_1, HSV.z); }
       else                   { RGB = vec3(HSV.z, var_1, var_2); }
   }
   return RGB;
}

void main()
{
	vec4 c0 = texture(Source, vTexCoord);
	float edgeStrength = params.edgeStrength * 0.01;
	
	vec4 c1 = texture(Source, vTexCoord + params.SourceSize.zw * vec2( 0.0, edgeStrength));
	vec4 c2 = texture(Source, vTexCoord + params.SourceSize.zw * vec2(-edgeStrength, edgeStrength));
	vec4 c3 = texture(Source, vTexCoord + params.SourceSize.zw * vec2(-edgeStrength, 0.0));
	vec4 c4 = texture(Source, vTexCoord + params.SourceSize.zw * vec2(-edgeStrength,-edgeStrength));
	vec4 c5 = texture(Source, vTexCoord + params.SourceSize.zw * vec2( 0.0,-edgeStrength));
	vec4 c6 = texture(Source, vTexCoord + params.SourceSize.zw * vec2( edgeStrength,-edgeStrength));
	vec4 c7 = texture(Source, vTexCoord + params.SourceSize.zw * vec2( edgeStrength, 0.0));
	vec4 c8 = texture(Source, vTexCoord + params.SourceSize.zw * vec2( edgeStrength, edgeStrength));
		
	vec4 a0 = c8 - c4;
	vec4 a1 = a0 - c2 - 2.0 * c3 + c6 + 2.0 * c7;
	a0 = a0 + c2 + c1 * 2.0 - 2.0 * c5 - c6;

	a0 = a0 * a0 + a1 * a1;

	float toon = CLength(a0);

	//c0.rgb = rgb_to_hsv(c0.rgb);
	//c0.b = min(1.0,1.1*c0.b);
	//c0.rgb = hsv_to_rgb(c0.rgb);
		  
	FragColor = c0 - vec4(toon * (0.125 / c0.r), toon * (0.125 / c0.g), toon * (0.125 / c0.b), 1.0);
}
