Shader "Custom/TessellationTerrain"
{
    Properties
    {
        _TessellationFactor ("Tessellation Factor", Float) = 1.0
        _TessellationBias ("Tessellation Bias", Float) = 1.0
        _TessellationDeformThreshold ("Tessellation Deform Threshold", Float) = 1.0
        _TessellationSmoothing ("Tessellation Smoothing", Float) = 1.0
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
            
            // ============================================================================
            // PROPERTIES
            // ============================================================================
            float _TessellationFactor;
            float _TessellationBias;
            float _TessellationDeformThreshold;
            float _TessellationSmoothing;
            
            // ============================================================================
            // STRUCTS
            // ============================================================================
            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct TessellationControl
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : INTERNALTESSPOS;
                float3 normalWS : NORMAL;
                float4 tangentWS : TANGENT;
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
                float3 normalWS : TEXCOORD1;
            };
            
            // ============================================================================
            // UTILITY FUNCTIONS
            // ============================================================================
            float3 BarycentricInterpolate(float3 bary, float3 a, float3 b, float3 c)
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
            // DEFORMATION
            // ============================================================================
            float DeformationLength(float3 vertexPositionWS, float3 movementDirectionWS, float offset)
            {
                // Simple noise-like deformation
                float height = sin(vertexPositionWS.x * 0.1) * cos(vertexPositionWS.z * 0.1) * 5.0;
                float3 displacedPos = vertexPositionWS + movementDirectionWS * height;
                return distance(vertexPositionWS, displacedPos);
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
            
            void CalculateBezierNormalAndTangent(
                float3 bary, float smoothing, float3 bezierPoints[10],
                float3 p0NormalWS, float3 p0TangentWS, 
                float3 p1NormalWS, float3 p1TangentWS, 
                float3 p2NormalWS, float3 p2TangentWS,
                out float3 normalWS, out float3 tangentWS)
            {
                float3 flatNormalWS = BarycentricInterpolate(bary, p0NormalWS, p1NormalWS, p2NormalWS);
                float3 smoothedNormalWS = CalculateBezierNormal(bary, bezierPoints, p0NormalWS, p1NormalWS, p2NormalWS);
                normalWS = normalize(lerp(flatNormalWS, smoothedNormalWS, smoothing));
                
                float3 flatTangentWS = BarycentricInterpolate(bary, p0TangentWS, p1TangentWS, p2TangentWS);
                float3 flatBitangentWS = cross(flatNormalWS, flatTangentWS);
                tangentWS = normalize(cross(flatBitangentWS, normalWS));
            }
            
            float3 CalculateBezierNormalWithSmoothFactor(float3 bary, float smoothing, float3 bezierPoints[10],
                float3 p0NormalWS, float3 p1NormalWS, float3 p2NormalWS)
            {
                float3 flatNormalWS = BarycentricInterpolate(bary, p0NormalWS, p1NormalWS, p2NormalWS);
                float3 smoothedNormalWS = CalculateBezierNormal(bary, bezierPoints, p0NormalWS, p1NormalWS, p2NormalWS);
                return normalize(lerp(flatNormalWS, smoothedNormalWS, smoothing));
            }
            
            // ============================================================================
            // PHONG TESSELLATION (Alternative smoothing method - currently unused)
            // ============================================================================
            float3 PhongProjectedPosition(float3 flatPositionWS, float3 cornerPositionWS, float3 normalWS)
            {
                return flatPositionWS - dot(flatPositionWS - cornerPositionWS, normalWS) * normalWS;
            }
            
            float3 CalculatePhongPosition(float3 bary, float smoothing, 
                float3 p0PositionWS, float3 p0NormalWS,
                float3 p1PositionWS, float3 p1NormalWS, 
                float3 p2PositionWS, float3 p2NormalWS)
            {
                float3 flatPositionWS = BarycentricInterpolate(bary, p0PositionWS, p1PositionWS, p2PositionWS);
                float3 smoothedPositionWS =
                    bary.x * PhongProjectedPosition(flatPositionWS, p0PositionWS, p0NormalWS) +
                    bary.y * PhongProjectedPosition(flatPositionWS, p1PositionWS, p1NormalWS) +
                    bary.z * PhongProjectedPosition(flatPositionWS, p2PositionWS, p2NormalWS);
                return lerp(flatPositionWS, smoothedPositionWS, smoothing);
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
                output.normalWS = normalInputs.normalWS;
                output.positionCS = posnInputs.positionCS;
                
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
                
                // Frustum and backface culling
                if (ShouldClipPatch(patch[0].positionCS, patch[1].positionCS, patch[2].positionCS))
                {
                    f.edge[0] = f.edge[1] = f.edge[2] = f.inside = 0;
                }
                else
                {
                    // Calculate deformation multipliers (currently unused but can be applied to edges)
                    float multipliers[3];
                    [unroll] for (int i = 0; i < 3; i++)
                    {
                        float length = DeformationLength(patch[i].positionWS, -patch[i].normalWS, _TessellationDeformThreshold);
                        multipliers[i] = length > _TessellationDeformThreshold ? 1 : 0;
                    }
                    
                    // Calculate edge tessellation factors
                    f.edge[0] = EdgeTessellationFactor(_TessellationFactor, _TessellationBias, 1,
                        patch[1].positionWS, patch[1].positionCS, patch[2].positionWS, patch[2].positionCS);
                    f.edge[1] = EdgeTessellationFactor(_TessellationFactor, _TessellationBias, 1,
                        patch[2].positionWS, patch[2].positionCS, patch[0].positionWS, patch[0].positionCS);
                    f.edge[2] = EdgeTessellationFactor(_TessellationFactor, _TessellationBias, 1,
                        patch[0].positionWS, patch[0].positionCS, patch[1].positionWS, patch[1].positionCS);
                    f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) / 3.0;
                    
                    // Calculate Bezier control points for smooth tessellation
                    CalculateBezierControlPoints(f.bezierPoints, 
                        patch[0].positionWS, patch[0].normalWS, 
                        patch[1].positionWS, patch[1].normalWS, 
                        patch[2].positionWS, patch[2].normalWS);
                    CalculateBezierNormalPoints(f.bezierPoints, 
                        patch[0].positionWS, patch[0].normalWS, 
                        patch[1].positionWS, patch[1].normalWS, 
                        patch[2].positionWS, patch[2].normalWS);
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
                
                // Calculate smoothed position using Bezier surface
                float3 positionWS = CalculateBezierPosition(
                    barycentricCoordinates, smoothing, factors.bezierPoints, 
                    patch[0].positionWS, patch[1].positionWS, patch[2].positionWS);
                
                // Calculate smoothed normal and tangent
                float3 normalWS, tangentWS;
                CalculateBezierNormalAndTangent(
                    barycentricCoordinates, smoothing, factors.bezierPoints,
                    patch[0].normalWS, patch[0].tangentWS.xyz, 
                    patch[1].normalWS, patch[1].tangentWS.xyz, 
                    patch[2].normalWS, patch[2].tangentWS.xyz,
                    normalWS, tangentWS);
                
                output.positionWS = positionWS;
                output.normalWS = normalWS;
                output.positionCS = TransformWorldToHClip(positionWS);
                
                return output;
            }
            
            // ============================================================================
            // FRAGMENT SHADER
            // ============================================================================
            half4 frag(Interpolators input) : SV_Target
            {
                float3 normalWS = normalize(input.normalWS);
                float3 lightDir = normalize(_MainLightPosition.xyz);
                float NdotL = saturate(dot(normalWS, lightDir));
                
                // Basic diffuse lighting with ambient
                half3 color = NdotL * 0.8 + 0.2;
                
                return half4(color, 1.0);
            }
            
            ENDHLSL
        }
    }
    
    FallBack "Diffuse"
}