Shader "Custom/Gestener"
{
    Properties
    {
        _Smoothness("Light Smoothness",Range(8,256)) = 8
        _SpecularColor("Specular Color",Color) = (0.5,0.5,0.5,1)
        _WaveCount("Wave Count",int) = 16
        _RandomDirection("Random Direction",Range(0,1)) = 1
        _WavelengthMax("WaveLength Max",Range(0,5)) = 5
        _WavelengthMin("WaveLength Min",Range(0,5)) = 0
        _WavesteepnessMax("WaveSteepness Max",Range(0,10)) = 3
        _WavesteepnessMin("WaveSteepness Min",Range(0,1)) = 0
        _WaveSpeed("Wave Speed",Range(0,3)) = 1.0
        _Direction("Direction",Vector) = (1,1,0,0)
    }
    SubShader
    {
        Tags
        { 
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType"="Opaque" 
        }
        LOD 100
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                
            };

            CBUFFER_START(UnityPerMaterial)
            Vector _WaveParam;
            float _Smoothness;
            half4 _SpecularColor;
            int _WaveCount;

            float _RandomDirection;
            float _WavelengthMax;
            float _WavelengthMin;
            float _WavesteepnessMax;
            float _WavesteepnessMin;
            float _WaveSpeed;

            Vector _Direction;
            
            CBUFFER_END


            float Random(int seed)
            {
                            
                return frac(sin(dot(float2(seed,2), float2(12.9898, 78.233))) ) * 2 - 1;
            }

            struct Gerstner
            {
                float3 positionWS;
                float3 binormal;
                float3 tangent;
            };

            Gerstner GerstnerWave(Vector direction,float3 positionWS,int waveCount,float wavelengthMax,float wavelengthMin,float steepnessMax,float steepnessMin,float randomdirection)
            {
                Gerstner gerstner;

                float3 P;
                float3 B;
                float3 T;


                for (int i = 0; i < waveCount; i++)
                {
                    float step = (float) i / (float) waveCount;

                    float2 d = float2(Random(i),Random(2*i));
                    d = normalize(lerp(normalize(direction.xy), d, randomdirection));

                    float wavelength = lerp(wavelengthMax, wavelengthMin, step);
                    float steepness = lerp(steepnessMax, steepnessMin, step)/waveCount;

                    float k = 2 * PI / wavelength;
                    float g = 9.81f;
                    float w = sqrt(g * k);
                    float a = steepness / k;
                    float2 wavevector = k * d;
                    float value = dot(wavevector, positionWS.xz) - w * _Time.y * _WaveSpeed;

                    P.x += d.x * a * cos(value);
                    P.z += d.y * a * cos(value);
                    P.y += a * sin(value);

                    T.x += d.x * d.x * k * a * -sin(value);
                    T.y += d.x * k * a * cos(value);
                    T.z += d.x * d.y * k * a * -sin(value);

                    B.x += d.x * d.y * k * a * -sin(value);
                    B.y += d.y * k * a * cos(value);
                    B.z += d.y * d.y * k * a * -sin(value);
                }
                gerstner.positionWS.x = positionWS.x + P.x;
                gerstner.positionWS.y = positionWS.y + P.y;
                gerstner.positionWS.z = positionWS.z + P.z;
                gerstner.tangent = float3(1 + T.x, T.y, T.z);
                gerstner.binormal = float3(B.x,B.y,1 + B.z);

                return gerstner;
                
            }

            Varings vert (Attributes IN)
            {
                Varings OUT = (Varings)0;
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);

                Gerstner gerstner = GerstnerWave(_Direction,positionWS,_WaveCount,_WavelengthMax,_WavelengthMin,_WavesteepnessMax,_WavesteepnessMin,_RandomDirection);
                positionWS = gerstner.positionWS;
                float3 binormal = gerstner.binormal;
                float3 tangent = gerstner.tangent;

                normalWS = normalize(cross(binormal,tangent));
                OUT.normalWS = normalWS;
                OUT.positionCS = TransformWorldToHClip(positionWS);
                OUT.positionWS = positionWS;
                return OUT;
            }

            half4 frag (Varings IN) : SV_Target
            {
                //Light parameter
                Light light = GetMainLight();
                half3 lightDir = light.direction;
                half3 lightColor = light.color;

                //vector
                float3 normalWS = normalize(IN.normalWS);
                float3 viewDirWS = normalize(_WorldSpaceCameraPos - IN.positionWS);

                //Light
                half3 lambert = LightingLambert(lightColor,lightDir,normalWS);
                half3 blinnPhong = LightingSpecular(lightColor,lightDir,normalWS,viewDirWS,_SpecularColor,_Smoothness);
                return half4(lambert + blinnPhong,1);
            }
            ENDHLSL
        }
    }
}