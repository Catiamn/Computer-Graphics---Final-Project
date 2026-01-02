Shader "Custom/GPUDeformation"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        
        // Add a toggle to switch between CPU and GPU deformation
        [Toggle]_UseGPUBuffer ("Use GPU Deformation", Float) = 1
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 4.5
            
            #include "UnityCG.cginc"
            #include "UnityStandardUtils.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 tangent : TANGENT;
                uint vertexID : SV_VertexID;
            };
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };
            
            // Buffer with deformed vertices (optional)
            StructuredBuffer<float3> _DeformedVerticesBuffer;
            
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;
            float _Glossiness;
            float _Metallic;
            float _UseGPUBuffer;
            
            v2f vert (appdata v)
            {
                v2f o;
                
                // Check if we should use GPU buffer (via keyword check)
                #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
                    // Alternative method using procedural instancing
                    float3 deformedPos = v.vertex.xyz;
                #else
                    // Method 1: Use _UseGPUBuffer flag
                    float3 deformedPos = v.vertex.xyz;
                    
                    // Method 2: Check if buffer is actually bound (safer approach)
                    // We'll use a uniform to control this
                    if (_UseGPUBuffer > 0.5)
                    {
                        // Use deformed vertex position from buffer
                        deformedPos = _DeformedVerticesBuffer[v.vertexID];
                    }
                    else
                    {
                        // Use original vertex position
                        deformedPos = v.vertex.xyz;
                    }
                #endif
                
                o.vertex = UnityObjectToClipPos(float4(deformedPos, 1));
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, float4(deformedPos, 1)).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                // Basic lighting calculation
                float3 worldNormal = normalize(i.worldNormal);
                float3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                
                // Diffuse lighting
                float diffuse = max(0, dot(worldNormal, worldLightDir));
                
                // Sample texture
                fixed4 col = tex2D(_MainTex, i.uv) * _Color;
                col.rgb *= diffuse * 0.7 + 0.3; // Add some ambient
                
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}