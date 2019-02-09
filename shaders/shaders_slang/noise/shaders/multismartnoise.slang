#version 450

layout(push_constant) uniform Push
{
	float noise;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

#pragma parameter noise "Smart Noise Amount" 1.5 0.0 3.0 0.1
float maxDark = 2.0;
float minDark = 0.8;
float mdiff = 0.2;

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

float pseudoNoise(vec2 co)
{
	return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453)*2.0-0.5;
}

// interleaved gradient noise function from: http://www.iryoku.com/next-generation-post-processing-in-call-of-duty-advanced-warfare
float interleavedGradientNoise(vec2 uv, vec2 screen)
{
    uv = floor(uv * screen.xy);
    float f = dot(vec2(0.06711056, 0.00583715), uv);
    return fract(52.9829189 * fract(f));
	return 0.5;
}

void main()
{
	vec3 color = texture(Source, vTexCoord).rgb;
	
	float colorSum1 = color.r + color.g + color.b;
	float uniquePos = (params.OutputSize.x * (vTexCoord.y - 1.0)) + vTexCoord.x;
	
	if (colorSum1 > minDark && colorSum1 < maxDark){
		
		float igNoise = interleavedGradientNoise(vTexCoord, params.OutputSize.xy);
		float n = colorSum1 > maxDark - 0.6 ? 0.01 : 0.02;//0.02
		color += (igNoise - 0.5) * n * params.noise; 
		igNoise = (pseudoNoise( vec2(uniquePos, igNoise * colorSum1) ) - 0.5) * 0.0075 * params.noise; //0.0075
		////float igNoise = (((interleavedGradientNoise(vTexCoord, params.OutputSize.xy) - 0.0) * 0.8) + ((pseudoNoise( vec2(uniquePos, colorSum1) ) - 0.0) * 0.2) - 0.5) * 0.8;
		color += igNoise;
		
		if ((colorSum1 > minDark && colorSum1 < maxDark) && color.r - mdiff >= color.g 
			|| color.r + mdiff <= color.g || color.r - mdiff >= color.b || color.r + mdiff <= color.b 
				|| color.g - mdiff >= color.b || color.g + mdiff <= color.b){
				
			vec2 texcoord2;
			vec2 split = params.OutputSize.xy / 2.0;
			if (vTexCoord.x > split.x){
				if (vTexCoord.y > split.y){
					texcoord2 = vec2(vTexCoord.x - split.x, vTexCoord.y - split.y);
				} else {
					texcoord2 = vec2(vTexCoord.x - split.x, vTexCoord.y + split.y);
				}
			} else {
				if (vTexCoord.y > split.y){
					texcoord2 = vec2(vTexCoord.x + split.x, vTexCoord.y - split.y);
				} else {
					texcoord2 = vec2(vTexCoord.x + split.x, vTexCoord.y + split.y);
				}
			}
			float uniquePos2 = (params.OutputSize.x * (texcoord2.y - 1)) + texcoord2.x;
			vec3 colorTwo = texture(Source, texcoord2).rgb;
			float colorSum2 = colorTwo.r + colorTwo.g + colorTwo.b;
			
			float ran = pseudoNoise( vec2(colorSum1 * uniquePos, colorSum2) );
			
			// saturation
			n = colorSum1 > maxDark - 0.6 ? 0.03 : 0.06; //0.06
			
			ran *= n * params.noise;
			ran = (0 - (n * params.noise / 2)) + ran;
			if (color.r > 0.5 && color.g < 0.5 && color.b < 0.5){
				ran /= 2;
			} else if (color.r > 0.4 && color.g < 0.6 && color.b < 0.6){
				ran /= 1.5;
			}
			
			// saturate is called clamp in slang
			color = clamp(color * (1+ran), 0.0, 1.0);	 
			
			
			// brightness
			float ran2 = pseudoNoise( vec2(vTexCoord.x + vTexCoord.y + ran + uniquePos - colorSum2 - 0.00137, vTexCoord.y + vTexCoord.x - ran + colorSum1 + colorSum2 + 0.00784) );
			
			n = colorSum1 > maxDark - 0.6 ? 0.006 : 0.012; //0.012
			ran2 *= n * params.noise;
			ran2 = (0.0 - (n * params.noise / 2)) + ran2;
			color += ran2;
		}
	}
	
	FragColor = vec4(color, 1.0);
	//FragColor = vec4(1.0, 0.0, 0.0, 1.0);
	//FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
}
