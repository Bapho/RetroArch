#version 450

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// SmartNoise by Bapho - https://github.com/Bapho https://www.shadertoy.com/user/Bapho
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// I created this shader because i did not liked the the noise 
// behaviour of most shaders. Time based noise shaders, which are 
// changing the noise pattern every frame, are very noticeable when the 
// "image isn't moving". "Static shaders", which are never changing 
// the noise pattern, are very noticeable when the "image is moving". 
// So i was searching a way to bypass those disadvantages. I used the 
// unique position of the current texture in combination with the color
// to get a unique seed for the noise function. The result is a noise 
// pattern that is only changing if the color of the position is changing.
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

layout(push_constant) uniform Push
{
	float noise;
	vec4 OutputSize;
} params;

#pragma parameter noise "Smart Noise Amount" 1.5 0.0 30.0 0.1

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

#define PHI 1.61803398874989484820459 * 00000.1 // Golden Ratio   
#define PI  3.14159265358979323846264 * 00000.1 // PI
#define SQ2 1.41421356237309504880169 * 10000.0 // Square Root of Two

float gold_noise(vec2 coordinate, float seed){
    return fract(tan(distance(coordinate*(seed+PHI), vec2(PHI, PI)))*SQ2);
}

vec3 applyNoise(vec3 color, vec2 uv, float uq, float colorSum, float amount){
    colorSum /= 3.0;
    amount *= colorSum > 0.5 ? (0.5 / colorSum) : (colorSum / 0.5);
    float sub = (0.5 * amount);
    
	if (colorSum - sub < 0.0){
	   amount *= (colorSum / sub);
	   sub *= (colorSum / sub);
	} else if (colorSum + sub > 1.0){
		if (colorSum > sub){
			amount *= (sub / colorSum);
			sub *= (sub / colorSum);
		} else {
			amount *= (colorSum / sub);
			sub *= (colorSum / sub);
        }
    }
    
    float ran = gold_noise(uv, uq);
    float add = ran * amount;
    return color + (add - sub);
}

void main()
{
	vec3 color = texture(Source, vTexCoord).rgb;
	float colorSum1 = color.r + color.g + color.b;
	float uniquePos1 = (params.OutputSize.x * 32.0) +
				(params.OutputSize.x * (vTexCoord.y - 1.0)) + vTexCoord.x;
	
	// black or white pixels will get less noise than colored ones
	float amount;
	if (colorSum1 < 1.5){
		amount = params.noise * (colorSum1 / 1.5);
	} else {
		amount = params.noise * ((3.0 - colorSum1) / 1.5);
	}
	// red pixels will get less noise 
	amount *= (1.0 - (color.r * 0.5));
	
	if (amount > 0.0){
		float unique = (colorSum1 + uniquePos1) * 0.000001;
		color = applyNoise(color, vTexCoord * 65535.0, unique, colorSum1, amount * 0.15);
	}
	
	FragColor = vec4(color, 1.0);
}
