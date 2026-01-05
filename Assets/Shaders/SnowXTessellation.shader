Shader "Custom/TessellatedSnowTerrain"
{
    Properties
    {
        // Tessellation properties
        _TessellationFactor ("Tessellation Factor", Float) = 1.0
        _TessellationBias ("Tessellation Bias", Float) = 1.0
        _TessellationDeformThreshold ("Tessellation Deform Threshold", Float) = 1.0
        _TessellationSmoothing ("Tessellation Smoothing", Float) = 1.0
        
        // Snow terrain properties
        _NoiseScale ("Noise Scale", Float) = 1.0
        _HeightMin ("Height Min", Float) = 0.0
        _HeightMax ("Height Max", Float) = 1.0
        _ColorTex ("Color Texture", 2D) = "white" {}
        _BottomColor ("Bottom Color", Color) = (0.2, 0.3, 0.4, 1)
        _TopColor ("Top Color", Color) = (0.9, 0.95, 1.0, 1)
    }
    
    SubShader
    {
        Tags { 
            "RenderType"="Opaque"
            "RenderPipeline"="UniversalPipeline" 
        }
        LOD 200
        
        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            
            HLSLPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma hull hull
            #pragma domain dom
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            // ============================================================================
            // PROPERTIES
            // ============================================================================
            float _TessellationFactor;
            float _TessellationBias;
            float _TessellationDeformThreshold;
            float _TessellationSmoothing;
            
            float _NoiseScale;
            float _HeightMin;
            float _HeightMax;
            TEXTURE2D(_ColorTex);
            SAMPLER(sampler_ColorTex);
            float4 _ColorTex_ST;
            float4 _BottomColor;
            float4 _TopColor;
            
            // ============================================================================
            // STRUCTS
            // ============================================================================
            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct TessellationControl
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : INTERNALTESSPOS;
                float3 positionOS : TEXCOORD0;
                float3 normalWS : NORMAL;
                float4 tangentWS : TANGENT;
                float2 uv : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
                float3 bezierPoints[10] : BEZIERPOS;
            };
            
            struct Interpolators
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 positionOS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float2 uv : TEXCOORD3;
                float height : TEXCOORD4;
            };
            
            // ============================================================================
            // NOISE FUNCTIONS (from Snow Terrain shader)
            // ============================================================================
            float hash(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.x + p3.y) * p3.z);
            }
            
            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);
                
                float a = hash(i);
                float b = hash(i + float2(1.0, 0.0));
                float c = hash(i + float2(0.0, 1.0));
                float d = hash(i + float2(1.0, 1.0));
                
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }
            
            float remap(float value, float2 inMinMax, float2 outMinMax)
            {
                return outMinMax.x + (value - inMinMax.x) * (outMinMax.y - outMinMax.x) / (inMinMax.y - inMinMax.x);
            }
            
            // ============================================================================
            // SNOW DISPLACEMENT FUNCTION
            // ============================================================================
            float CalculateSnowDisplacement(float3 worldPos, float3 objPos, float2 uv)
            {
                // Triplanar noise sampling
                float2 xy = worldPos.xy;
                float2 xz = worldPos.xz;
                float2 yz = worldPos.yz;
                float2 triplanarUV = (xy + xz + yz) * _NoiseScale;
                
                float noiseValue = noise(triplanarUV);
                float remappedHeight = remap(noiseValue, float2(0, 1), float2(_HeightMin, _HeightMax));
                float clampedHeight = clamp(remappedHeight, _HeightMin, _HeightMax);
                
                // Sample and process color texture
                float4 colorSample = SAMPLE_TEXTURE2D_LOD(_ColorTex, sampler_ColorTex, uv, 0);
                float invertedRed = 1.0 - colorSample.r;
                float processedColor = invertedRed * 0.5;
                float heightY = _HeightMax * 2.0;
                float colorMultiplied = heightY * processedColor;
                
                float subtractResult = clampedHeight - colorMultiplied;
                return subtractResult;
            }
            
            // ============================================================================
            // UTILITY FUNCTIONS
            // ============================================================================
            float3 BarycentricInterpolate(float3 bary, float3 a, float3 b, float3 c)
            {
                return bary.x * a + bary.y * b + bary.z * c;
            }
            
            float2 BarycentricInterpolate2(float3 bary, float2 a, float2 b, float2 c)
            {
                return bary.x * a + bary.y * b + bary.z * c;
            }
            
            bool IsOutOfBounds(float3 p, float3 lower, float3 higher)
            {
                return p.x < lower.x || p.x > higher.x || 
                       p.y < lower.y || p.y > higher.y || 
                       p.z < lower.z || p.z > higher.z;
            }
            
            bool IsPointOutOfFrustum(float4 positionCS, float tolerance = 0)
            {
                float3 culling = positionCS.xyz;
                float w = positionCS.w;
                float3 lowerBounds = float3(-w - tolerance, -w - tolerance, -w * UNITY_RAW_FAR_CLIP_VALUE - tolerance);
                float3 higherBounds = float3(w + tolerance, w + tolerance, w + tolerance);
                return IsOutOfBounds(culling, lowerBounds, higherBounds);
            }
            
            bool ShouldBackFaceCull(float4 p0PositionCS, float4 p1PositionCS, float4 p2PositionCS, float tolerance = 0)
            {
                float3 point0 = p0PositionCS.xyz / p0PositionCS.w;
                float3 point1 = p1PositionCS.xyz / p1PositionCS.w;
                float3 point2 = p2PositionCS.xyz / p2PositionCS.w;
                
                #if UNITY_REVERSED_Z
                    return cross(point1 - point0, point2 - point0).z < -tolerance;
                #else
                    return cross(point1 - point0, point2 - point0).z > tolerance;
                #endif
            }
            
            bool ShouldClipPatch(float4 p0PositionCS, float4 p1PositionCS, float4 p2PositionCS)
            {
                bool allOutside = IsPointOutOfFrustum(p0PositionCS) &&
                                  IsPointOutOfFrustum(p1PositionCS) &&
                                  IsPointOutOfFrustum(p2PositionCS);
                return allOutside || ShouldBackFaceCull(p0PositionCS, p1PositionCS, p2PositionCS);
            }
            
            // ============================================================================
            // BEZIER SURFACE CALCULATIONS
            // ============================================================================
            float3 CalculateBezierControlPoint(float3 p0PositionWS, float3 aNormalWS, float3 p1PositionWS, float3 bNormalWS)
            {
                float w = dot(p1PositionWS - p0PositionWS, aNormalWS);
                return (p0PositionWS * 2 + p1PositionWS - w * aNormalWS) / 3.0;
            }
            
            void CalculateBezierControlPoints(inout float3 bezierPoints[10],
                float3 p0PositionWS, float3 p0NormalWS, 
                float3 p1PositionWS, float3 p1NormalWS, 
                float3 p2PositionWS, float3 p2NormalWS)
            {
                bezierPoints[0] = CalculateBezierControlPoint(p0PositionWS, p0NormalWS, p1PositionWS, p1NormalWS);
                bezierPoints[1] = CalculateBezierControlPoint(p1PositionWS, p1NormalWS, p0PositionWS, p0NormalWS);
                bezierPoints[2] = CalculateBezierControlPoint(p1PositionWS, p1NormalWS, p2PositionWS, p2NormalWS);
                bezierPoints[3] = CalculateBezierControlPoint(p2PositionWS, p2NormalWS, p1PositionWS, p1NormalWS);
                bezierPoints[4] = CalculateBezierControlPoint(p2PositionWS, p2NormalWS, p0PositionWS, p0NormalWS);
                bezierPoints[5] = CalculateBezierControlPoint(p0PositionWS, p0NormalWS, p2PositionWS, p2NormalWS);
                
                float3 avgBezier = 0;
                [unroll] for (int i = 0; i < 6; i++)
                {
                    avgBezier += bezierPoints[i];
                }
                avgBezier /= 6.0;
                float3 avgControl = (p0PositionWS + p1PositionWS + p2PositionWS) / 3.0;
                bezierPoints[6] = avgBezier + (avgBezier - avgControl) / 2.0;
            }
            
            float3 CalculateBezierPosition(float3 bary, float smoothing, float3 bezierPoints[10],
                float3 p0PositionWS, float3 p1PositionWS, float3 p2PositionWS)
            {
                float3 flatPositionWS = BarycentricInterpolate(bary, p0PositionWS, p1PositionWS, p2PositionWS);
                float3 smoothedPositionWS =
                    p0PositionWS * (bary.x * bary.x * bary.x) +
                    p1PositionWS * (bary.y * bary.y * bary.y) +
                    p2PositionWS * (bary.z * bary.z * bary.z) +
                    bezierPoints[0] * (3 * bary.x * bary.x * bary.y) +
                    bezierPoints[1] * (3 * bary.y * bary.y * bary.x) +
                    bezierPoints[2] * (3 * bary.y * bary.y * bary.z) +
                    bezierPoints[3] * (3 * bary.z * bary.z * bary.y) +
                    bezierPoints[4] * (3 * bary.z * bary.z * bary.x) +
                    bezierPoints[5] * (3 * bary.x * bary.x * bary.z) +
                    bezierPoints[6] * (6 * bary.x * bary.y * bary.z);
                return lerp(flatPositionWS, smoothedPositionWS, smoothing);
            }
            
            float3 CalculateBezierControlNormal(float3 p0PositionWS, float3 aNormalWS, float3 p1PositionWS, float3 bNormalWS)
            {
                float3 d = p1PositionWS - p0PositionWS;
                float v = 2 * dot(d, aNormalWS + bNormalWS) / dot(d, d);
                return normalize(aNormalWS + bNormalWS - v * d);
            }
            
            void CalculateBezierNormalPoints(inout float3 bezierPoints[10],
                float3 p0PositionWS, float3 p0NormalWS, 
                float3 p1PositionWS, float3 p1NormalWS, 
                float3 p2PositionWS, float3 p2NormalWS)
            {
                bezierPoints[7] = CalculateBezierControlNormal(p0PositionWS, p0NormalWS, p1PositionWS, p1NormalWS);
                bezierPoints[8] = CalculateBezierControlNormal(p1PositionWS, p1NormalWS, p2PositionWS, p2NormalWS);
                bezierPoints[9] = CalculateBezierControlNormal(p2PositionWS, p2NormalWS, p0PositionWS, p0NormalWS);
            }
            
            float3 CalculateBezierNormal(float3 bary, float3 bezierPoints[10],
                float3 p0NormalWS, float3 p1NormalWS, float3 p2NormalWS)
            {
                return p0NormalWS * (bary.x * bary.x) +
                       p1NormalWS * (bary.y * bary.y) +
                       p2NormalWS * (bary.z * bary.z) +
                       bezierPoints[7] * (2 * bary.x * bary.y) +
                       bezierPoints[8] * (2 * bary.y * bary.z) +
                       bezierPoints[9] * (2 * bary.z * bary.x);
            }
            
            float3 CalculateBezierNormalWithSmoothFactor(float3 bary, float smoothing, float3 bezierPoints[10],
                float3 p0NormalWS, float3 p1NormalWS, float3 p2NormalWS)
            {
                float3 flatNormalWS = BarycentricInterpolate(bary, p0NormalWS, p1NormalWS, p2NormalWS);
                float3 smoothedNormalWS = CalculateBezierNormal(bary, bezierPoints, p0NormalWS, p1NormalWS, p2NormalWS);
                return normalize(lerp(flatNormalWS, smoothedNormalWS, smoothing));
            }
            
            // ============================================================================
            // TESSELLATION FACTOR CALCULATION
            // ============================================================================
            float EdgeTessellationFactor(float scale, float bias, float multiplier, 
                float3 p0PositionWS, float4 p0PositionCS, 
                float3 p1PositionWS, float4 p1PositionCS)
            {
                float length = distance(p0PositionWS, p1PositionWS);
                float distanceToCamera = distance(GetCameraPositionWS(), (p0PositionWS + p1PositionWS) * 0.5);
                float factor = length / (scale * distanceToCamera * distanceToCamera);
                return max(1, (factor + bias) * multiplier);
            }
            
            float CalculateDeformationAmount(float3 worldPos, float3 objPos, float2 uv)
            {
                // Sample the color texture to determine deformation
                // This checks the texture that the compute shader is modifying
                float4 colorSample = SAMPLE_TEXTURE2D_LOD(_ColorTex, sampler_ColorTex, uv, 0);
                float invertedRed = 1.0 - colorSample.r;
                
                // If invertedRed is high, it means the texture is dark (deformed area)
                // Return how much this area should be deformed down
                return invertedRed;
            }
            
            // ============================================================================
            // VERTEX SHADER
            // ============================================================================
            TessellationControl vert(Attributes input)
            {
                TessellationControl output;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                
                VertexPositionInputs posnInputs = GetVertexPositionInputs(input.positionOS);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                
                output.positionWS = posnInputs.positionWS;
                output.positionOS = input.positionOS;
                output.normalWS = normalInputs.normalWS;
                output.positionCS = posnInputs.positionCS;
                output.uv = TRANSFORM_TEX(input.uv, _ColorTex);
                
                float3 tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
                output.tangentWS = float4(tangentWS, input.tangentOS.w);
                
                return output;
            }
            
            // ============================================================================
            // HULL SHADER
            // ============================================================================
            [domain("tri")]
            [outputcontrolpoints(3)]
            [outputtopology("triangle_cw")]
            [patchconstantfunc("PatchConstantFunction")]
            [partitioning("integer")]
            TessellationControl hull(InputPatch<TessellationControl, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }
            
            TessellationFactors PatchConstantFunction(InputPatch<TessellationControl, 3> patch)
            {
                UNITY_SETUP_INSTANCE_ID(patch[0]);
                
                TessellationFactors f = (TessellationFactors)0;
                
                if (ShouldClipPatch(patch[0].positionCS, patch[1].positionCS, patch[2].positionCS))
                {
                    f.edge[0] = f.edge[1] = f.edge[2] = f.inside = 0;
                }
                else
                {
                    // Calculate deformation amount for each vertex
                    float deform0 = CalculateDeformationAmount(patch[0].positionWS, patch[0].positionOS, patch[0].uv);
                    float deform1 = CalculateDeformationAmount(patch[1].positionWS, patch[1].positionOS, patch[1].uv);
                    float deform2 = CalculateDeformationAmount(patch[2].positionWS, patch[2].positionOS, patch[2].uv);
                    
                    // Calculate multipliers based on whether deformation exceeds threshold
                    float mult0 = deform0 > _TessellationDeformThreshold ? 1.0 : 0.0;
                    float mult1 = deform1 > _TessellationDeformThreshold ? 1.0 : 0.0;
                    float mult2 = deform2 > _TessellationDeformThreshold ? 1.0 : 0.0;
                    
                    // Apply multipliers to edges (edge tessellates if either vertex is deformed)
                    float edgeMult0 = max(mult1, mult2); // Edge between vertex 1 and 2
                    float edgeMult1 = max(mult2, mult0); // Edge between vertex 2 and 0
                    float edgeMult2 = max(mult0, mult1); // Edge between vertex 0 and 1
                    
                    // Calculate tessellation factors, multiplied by deformation
                    f.edge[0] = EdgeTessellationFactor(_TessellationFactor, _TessellationBias, edgeMult0,
                        patch[1].positionWS, patch[1].positionCS, patch[2].positionWS, patch[2].positionCS);
                    f.edge[1] = EdgeTessellationFactor(_TessellationFactor, _TessellationBias, edgeMult1,
                        patch[2].positionWS, patch[2].positionCS, patch[0].positionWS, patch[0].positionCS);
                    f.edge[2] = EdgeTessellationFactor(_TessellationFactor, _TessellationBias, edgeMult2,
                        patch[0].positionWS, patch[0].positionCS, patch[1].positionWS, patch[1].positionCS);
                    f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) / 3.0;
                    
                    // Only calculate Bezier points if tessellation is happening
                    if (f.inside > 1.0)
                    {
                        CalculateBezierControlPoints(f.bezierPoints, 
                            patch[0].positionWS, patch[0].normalWS, 
                            patch[1].positionWS, patch[1].normalWS, 
                            patch[2].positionWS, patch[2].normalWS);
                        CalculateBezierNormalPoints(f.bezierPoints, 
                            patch[0].positionWS, patch[0].normalWS, 
                            patch[1].positionWS, patch[1].normalWS, 
                            patch[2].positionWS, patch[2].normalWS);
                    }
                }
                
                return f;
            }
            
            // ============================================================================
            // DOMAIN SHADER
            // ============================================================================
            [domain("tri")]
            Interpolators dom(
                TessellationFactors factors, 
                OutputPatch<TessellationControl, 3> patch,
                float3 barycentricCoordinates : SV_DomainLocation)
            {
                Interpolators output = (Interpolators)0;
                
                UNITY_SETUP_INSTANCE_ID(patch[0]);
                
                float smoothing = _TessellationSmoothing;
                
                // Interpolate base attributes
                float3 positionOS = BarycentricInterpolate(barycentricCoordinates, 
                    patch[0].positionOS, patch[1].positionOS, patch[2].positionOS);
                float2 uv = BarycentricInterpolate2(barycentricCoordinates,
                    patch[0].uv, patch[1].uv, patch[2].uv);
                
                // Calculate smoothed position using Bezier surface
                float3 positionWS = CalculateBezierPosition(
                    barycentricCoordinates, smoothing, factors.bezierPoints, 
                    patch[0].positionWS, patch[1].positionWS, patch[2].positionWS);
                
                // Apply snow displacement
                float displacement = CalculateSnowDisplacement(positionWS, positionOS, uv);
                positionWS.y += displacement;
                
                // Calculate smoothed normal
                float3 normalWS = CalculateBezierNormalWithSmoothFactor(
                    barycentricCoordinates, smoothing, factors.bezierPoints,
                    patch[0].normalWS, patch[1].normalWS, patch[2].normalWS);
                
                output.positionWS = positionWS;
                output.positionOS = positionOS;
                output.normalWS = normalWS;
                output.positionCS = TransformWorldToHClip(positionWS);
                output.uv = uv;
                output.height = positionOS.y + displacement;
                
                return output;
            }
            
            // ============================================================================
            // FRAGMENT SHADER
            // ============================================================================
            half4 frag(Interpolators input) : SV_Target
            {
                float3 normalWS = normalize(input.normalWS);
                
                // Calculate lerp factor for color gradient based on height
                float lerpT = remap(input.height, float2(_HeightMin, _HeightMax), float2(0, 1));
                lerpT = saturate(lerpT);
                
                // Lerp between bottom and top color
                half4 baseColor = lerp(_BottomColor, _TopColor, lerpT);
                
                // Simple lighting
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float NdotL = saturate(dot(normalWS, lightDir));
                
                half3 diffuse = baseColor.rgb * (NdotL * 0.8 + 0.2);
                
                return half4(diffuse, 1.0);
            }
            
            ENDHLSL
        }
    }
    
    FallBack "Diffuse"
}