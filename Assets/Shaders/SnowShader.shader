Shader "Custom/SnowTerrain"
{
    Properties
    {
        _NoiseScale ("Noise Scale", Float) = 1.0
        _HeightMin ("Height Min", Float) = 0.0
        _HeightMax ("Height Max", Float) = 1.0
        _ColorTex ("Color Texture", 2D) = "white" {}
        _BottomColor ("Bottom Color", Color) = (0, 0, 0, 1)
        _TopColor ("Top Color", Color) = (1, 1, 1, 1)
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
            #include "UnityCG.cginc"
            
            struct Attributes
            {
                float4 vertexPOS : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                float3 objPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };
            
            sampler2D _ColorTex;
            float4 _ColorTex_ST;
            float _NoiseScale;
            float _HeightMin;
            float _HeightMax;
            float4 _BottomColor;
            float4 _TopColor;
            
            // Simple hash function for procedural noise
            float hash(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.x + p3.y) * p3.z);
            }
            
            // Smooth noise function
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
            
            // Remap function
            float remap(float value, float2 inMinMax, float2 outMinMax)
            {
                return outMinMax.x + (value - inMinMax.x) * (outMinMax.y - outMinMax.x) / (inMinMax.y - inMinMax.x);
            }
            
            v2f vert(Attributes v)
            {
                v2f o;
                
                // Get world position
                float3 worldPos = mul(unity_ObjectToWorld, v.vertexPOS).xyz;
                
                // Split world pos into xy, xz, yz and add them (triplanar approach)
                float2 xy = worldPos.xy;
                float2 xz = worldPos.xz;
                float2 yz = worldPos.yz;
                float2 triplanarUV = (xy + xz + yz) * _NoiseScale;
                
                // Generate procedural noise
                float noiseValue = noise(triplanarUV);
                
                // Remap noise (0-1) to height range
                float remappedHeight = remap(noiseValue, float2(0, 1), float2(_HeightMin, _HeightMax));
                
                // Clamp result between height range min and max
                float clampedHeight = clamp(remappedHeight, _HeightMin, _HeightMax);
                
                // Sample color texture and process
                float4 colorSample = tex2Dlod(_ColorTex, float4(v.uv, 0, 0));
                float invertedRed = 1.0 - colorSample.r;
                float processedColor = invertedRed * 0.5;
                
                // Height Y multiplied by 2, then by inverted color
                float heightY = _HeightMax * 2.0;
                float colorMultiplied = heightY * processedColor;
                
                // Subtract: clampedHeight - colorMultiplied
                float subtractResult = clampedHeight - colorMultiplied;
                
                // Get object position Y and add to subtract result
                float objPosY = v.vertexPOS.y;
                float newY = objPosY + subtractResult;
                
                // Combine new Y with original X and Z of object position
                float3 displacedPos = float3(v.vertexPOS.x, newY, v.vertexPOS.z);
                
                // Remap the new Y for lerp (using height range as bounds)
                float lerpT = remap(newY, float2(_HeightMin, _HeightMax), float2(0, 1));
                lerpT = saturate(lerpT);
                
                // Calculate final position
                o.pos = UnityObjectToClipPos(float4(displacedPos, 1.0));
                o.worldPos = worldPos;
                o.objPos = v.vertexPOS.xyz;
                o.uv = v.uv;
                
                return o;
            }
            
            float4 frag(v2f i) : SV_Target
            {
                // Recalculate the lerp T in fragment shader for proper interpolation
                float3 worldPos = i.worldPos;
                float2 xy = worldPos.xy;
                float2 xz = worldPos.xz;
                float2 yz = worldPos.yz;
                float2 triplanarUV = (xy + xz + yz) * _NoiseScale;
                
                float noiseValue = noise(triplanarUV);
                float remappedHeight = remap(noiseValue, float2(0, 1), float2(_HeightMin, _HeightMax));
                float clampedHeight = clamp(remappedHeight, _HeightMin, _HeightMax);
                
                float4 colorSample = tex2D(_ColorTex, i.uv);
                float invertedRed = 1.0 - colorSample.r;
                float processedColor = invertedRed * 0.5;
                float heightY = _HeightMax * 2.0;
                float colorMultiplied = heightY * processedColor;
                
                float subtractResult = clampedHeight - colorMultiplied;
                float newY = i.objPos.y + subtractResult;
                
                float lerpT = remap(newY, float2(_HeightMin, _HeightMax), float2(0, 1));
                lerpT = saturate(lerpT);
                
                // Lerp between bottom and top color
                float4 finalColor = lerp(_BottomColor, _TopColor, lerpT);
                
                return finalColor;
            }
            ENDCG
        }
    }
    
    FallBack "Diffuse"
}