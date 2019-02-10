#version 450

// this ReShade Shader was ported from Bapho - https://github.com/Bapho 

layout(push_constant) uniform Push
{
	float sharp_strength;
	float sharp_clamp;
	float pattern;
	float offset_bias;
	float show_sharpen;
	vec4 SourceSize;
	vec4 OriginalSize;
	vec4 OutputSize;
	uint FrameCount;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;

#pragma parameter sharp_strength "Shapening strength" 1.0 0.0 16.0 0.1
#pragma parameter sharp_clamp "Sharpening limit" 0.5 0.00 10.0 0.01
#pragma parameter pattern "Sample pattern" 3.0 0.0 3.0 1.0
#pragma parameter offset_bias "Offset bias" 0.0 0.0 6.0	0.05
#pragma parameter show_sharpen "Show sharpening pattern" 0.0 0.0 1.0 1.0
#define CoefLuma vec3(0.2126, 0.7152, 0.0722)

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

void main()
{
	float sharp_clamp = params.sharp_clamp * 0.1;
	
	// -- Get the original pixel --
	vec3 ori = texture(Source, vTexCoord).rgb; // ori = original pixel

	// -- Combining the strength and luma multipliers --
	vec3 sharp_strength_luma = (CoefLuma * params.sharp_strength); //I'll be combining even more multipliers with it later on

	  //------------------------------------------------------------//
	 //                       Sampling patterns                    //
	//------------------------------------------------------------//
	vec3 blur_ori;

	//   [ NW,   , NE ] Each texture lookup (except ori)
	//   [   ,ori,    ] samples 4 pixels
	//   [ SW,   , SE ]

	// -- Pattern 1 -- A (fast) 7 tap gaussian using only 2+1 texture fetches.
	if (params.pattern < 1.0)
	{
		// -- Gaussian filter --
		//   [ 1/9, 2/9,    ]     [ 1 , 2 ,   ]
		//   [ 2/9, 8/9, 2/9]  =  [ 2 , 8 , 2 ]
		//   [    , 2/9, 1/9]     [   , 2 , 1 ]

		blur_ori  = texture(Source, vTexCoord + (params.SourceSize.zw / 3.0) * params.offset_bias).rgb;  // North West
		blur_ori += texture(Source, vTexCoord + (-params.SourceSize.zw / 3.0) * params.offset_bias).rgb; // South East

		//blur_ori += texture(Source, vTexCoord + (params.SourceSize.zw / 3.0) * offset_bias); // North East
		//blur_ori += texture(Source, vTexCoord + (-params.SourceSize.zw / 3.0) * offset_bias); // South West

		blur_ori /= 2;  //Divide by the number of texture fetches

		sharp_strength_luma *= 1.5; // Adjust strength to aproximate the strength of pattern 2
	}

	// -- Pattern 2 -- A 9 tap gaussian using 4+1 texture fetches.
	if (params.pattern < 2.0)
	{
		// -- Gaussian filter --
		//   [ .25, .50, .25]     [ 1 , 2 , 1 ]
		//   [ .50,   1, .50]  =  [ 2 , 4 , 2 ]
		//   [ .25, .50, .25]     [ 1 , 2 , 1 ]

		blur_ori  = texture(Source, vTexCoord + vec2(params.SourceSize.zw.x, -params.SourceSize.zw.y) * 0.5 * params.offset_bias).rgb; // South East
		blur_ori += texture(Source, vTexCoord - params.SourceSize.zw * 0.5 * params.offset_bias).rgb;  // South West
		blur_ori += texture(Source, vTexCoord + params.SourceSize.zw * 0.5 * params.offset_bias).rgb; // North East
		blur_ori += texture(Source, vTexCoord - vec2(params.SourceSize.zw.x, -params.SourceSize.zw.y) * 0.5 * params.offset_bias).rgb; // North West

		blur_ori *= 0.25;  // ( /= 4) Divide by the number of texture fetches
	}

	// -- Pattern 3 -- An experimental 17 tap gaussian using 4+1 texture fetches.
	if (params.pattern < 3.0)
	{
		// -- Gaussian filter --
		//   [   , 4 , 6 ,   ,   ]
		//   [   ,16 ,24 ,16 , 4 ]
		//   [ 6 ,24 ,   ,24 , 6 ]
		//   [ 4 ,16 ,24 ,16 ,   ]
		//   [   ,   , 6 , 4 ,   ]

		blur_ori  = texture(Source, vTexCoord + params.SourceSize.zw * vec2(0.4, -1.2) * params.offset_bias).rgb;  // South South East
		blur_ori += texture(Source, vTexCoord - params.SourceSize.zw * vec2(1.2, 0.4) * params.offset_bias).rgb; // West South West
		blur_ori += texture(Source, vTexCoord + params.SourceSize.zw * vec2(1.2, 0.4) * params.offset_bias).rgb; // East North East
		blur_ori += texture(Source, vTexCoord - params.SourceSize.zw * vec2(0.4, -1.2) * params.offset_bias).rgb; // North North West

		blur_ori *= 0.25;  // ( /= 4) Divide by the number of texture fetches

		sharp_strength_luma *= 0.51;
	}

	// -- Pattern 4 -- A 9 tap high pass (pyramid filter) using 4+1 texture fetches.
	if (params.pattern < 4.0)
	{
		// -- Gaussian filter --
		//   [ .50, .50, .50]     [ 1 , 1 , 1 ]
		//   [ .50,    , .50]  =  [ 1 ,   , 1 ]
		//   [ .50, .50, .50]     [ 1 , 1 , 1 ]

		blur_ori  = texture(Source, vTexCoord + vec2(0.5 * params.SourceSize.zw.x, -params.SourceSize.zw.y * params.offset_bias)).rgb;  // South South East
		blur_ori += texture(Source, vTexCoord + vec2(params.offset_bias * -params.SourceSize.zw.x, 0.5 * -params.SourceSize.zw.y)).rgb; // West South West
		blur_ori += texture(Source, vTexCoord + vec2(params.offset_bias * params.SourceSize.zw.x, 0.5 * params.SourceSize.zw.y)).rgb; // East North East
		blur_ori += texture(Source, vTexCoord + vec2(0.5 * -params.SourceSize.zw.x, params.SourceSize.zw.y * params.offset_bias)).rgb; // North North West

		//blur_ori += (2 * ori); // Probably not needed. Only serves to lessen the effect.

		blur_ori /= 4.0;  //Divide by the number of texture fetches

		sharp_strength_luma *= 0.666; // Adjust strength to aproximate the strength of pattern 2
	}

	  //------------------------------------------------------------//
	 //                          Sharpen                           //
	//------------------------------------------------------------//

	// -- Calculate the sharpening --
	vec3 sharp = ori - blur_ori;  //Subtracting the blurred image from the original image

	// older CeeJay 1.4 code (included here because the new code while faster can be difficult to understand)
	//float sharp_luma = dot(sharp, sharp_strength_luma); //Calculate the luma and adjust the strength
	//sharp_luma = clamp(sharp_luma, -sharp_clamp, sharp_clamp);  //TODO Try a curve function instead of a clamp
	
	// new code
	// -- Adjust strength of the sharpening and clamp it--
	vec4 sharp_strength_luma_clamp = vec4(sharp_strength_luma * (0.5 / sharp_clamp),0.5); //Roll part of the clamp into the dot

	//sharp_luma = clamp((0.5 / sharp_clamp) * sharp_luma + 0.5, 0.0, 1.0); //scale up and clamp
	float sharp_luma = clamp(dot(vec4(sharp,1.0), sharp_strength_luma_clamp), 0.0, 1.0); //Calculate the luma, adjust the strength, scale up and clamp
	sharp_luma = (sharp_clamp * 2.0) * sharp_luma - sharp_clamp; //scale down

	// -- Combining the values to get the final sharpened pixel	--
	vec3 outputcolor = ori + sharp_luma;    // Add the sharpening to the the original.

	  //------------------------------------------------------------//
	 //                   Returning the output                     //
	//------------------------------------------------------------//

	if (params.show_sharpen > 0.0)
	{
		//outputcolor = abs(sharp * 4.0);
		outputcolor = clamp(0.5 + (sharp_luma * 4.0), 0.0, 1.0).rrr;
	}

	FragColor = vec4(clamp(outputcolor, 0.0, 1.0).rgb, 1.0);
}
