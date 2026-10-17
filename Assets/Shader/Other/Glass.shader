Shader "Unlit/Glass"
{
    Properties
    {
        [Header(reflection)]
        _Matcap ("Matcap", 2D) = "white" {}
        _SpecularrColor("Specular Color",Color)=(1,1,1,1)

        [Header(refraction)]
        _RefractionPower("Refraction Power",Float)=1
        _ThicknessMap("thickness Map",2D)="white"{}
        _ThickOffset("Thick Offset",Range(0,1))=0
        _ThickHight("Thick Hight",Float)=1
        _RefractionMatcap("Refraction Matcap",2D)="white"{}
        _RefractionColor("Refraction Color",Color)=(1,1,1,1)

        [Header(Logo)]
        _DecalTexture("Decal Texture",2D)="black"{}

        [Header(Dirty)]
        _DirtyTexture("Dirty Texture",2D)="black"{}

    }
    SubShader
    {
        Tags { "RenderType"="Transparent"  "Queue"="Transparent" }
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

           #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

           CBUFFER_START(UnityPerMaterial)
           float _RefractionPower;
           float4 _SpecularrColor;
           float _ThickOffset;
           float _ThickHight;
           float4 _RefractionColor;
           CBUFFER_END
           
           TEXTURE2D(_Matcap);
           SAMPLER(sampler_Matcap);

           TEXTURE2D(_ThicknessMap);
           SAMPLER(sampler_ThicknessMap);

           TEXTURE2D(_RefractionMatcap);
           SAMPLER(sampler_RefractionMatcap);

           TEXTURE2D(_DecalTexture);
           SAMPLER(sampler_DecalTexture);

           TEXTURE2D(_DirtyTexture);
           SAMPLER(sampler_DirtyTexture);

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal:NORMAL;
                float2 uv:TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex :SV_POSITION;
                float2 uv:TEXCOORD0;
                float3 viewNormal:TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldNormal:TEXCOORD3;
            };


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv=v.uv;
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.viewNormal=TransformWorldToViewNormal(o.worldNormal);
                o.viewNormal=normalize(o.viewNormal);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                //specular

                //方法一:
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
                //float3 viewDir = normalize(TransformWorldToView(i.worldPos.xyz));
                float3 viewDirVS = normalize(TransformWorldToViewDir(viewDir));
                float3 crossRes = cross(viewDirVS,i.viewNormal);
                float2 matcap_uv = float2(crossRes.x, -crossRes.y);
                matcap_uv = matcap_uv * 0.5 + 0.5;

                //方法二：基于球面映射
                // float3 reflectDirWS = reflect(-viewDir,i.worldNormal);
                // float3 reflectDirVS = normalize(TransformWorldToViewDir(reflectDirWS));
                // float3 reflect = reflectDirVS+float3(0,0,1);
                // float m = sqrt(dot(reflect,reflect));
                // float2 matcap_uv = float2(reflect.x/m,reflect.y/m)*0.5+0.5;

                //方法三:不推荐
               // float2 matcap_uv=i.viewNormal.xy*0.5+0.5;
                float4 matcap_color=SAMPLE_TEXTURE2D(_Matcap,sampler_Matcap,matcap_uv);
                matcap_color*=_SpecularrColor;
                matcap_color.a=matcap_color.r;
               
               //thickness

               //fresneal
               float NdotV=dot(i.viewNormal,viewDirVS);
               NdotV=1-saturate(NdotV);
               float fresneal=pow(NdotV,_RefractionPower);

               //thicknessMap
               float3 objectPos = UNITY_MATRIX_M._m03_m13_m23;
               float3 o_vector=i.worldPos-objectPos;
               o_vector.y-=_ThickOffset;
               o_vector=1-o_vector/_ThickHight;

               float2 thickness_uv=float2(0.5,o_vector.y);
               float thickness=SAMPLE_TEXTURE2D(_ThicknessMap,sampler_ThicknessMap, thickness_uv).r;
               thickness=thickness+fresneal;

               //Dirty
               float dirty=SAMPLE_TEXTURE2D(_DirtyTexture,sampler_DecalTexture,i.uv).a;

               //refraction
               float2 refraction_uv=thickness+matcap_uv+dirty;
               float4 refraction_matcap=SAMPLE_TEXTURE2D(_RefractionMatcap,sampler_RefractionMatcap,refraction_uv);
              
               //Logo
               float4 decal=SAMPLE_TEXTURE2D(_DecalTexture,sampler_DecalTexture,i.uv);

               float4 final_color;
               final_color.rgb = refraction_matcap.rgb + matcap_color.rgb;
               final_color.rgb = lerp(final_color.rgb,decal.rgb,decal.a);
               final_color.a=clamp(matcap_color.r+thickness+decal.a+dirty,0,1);

               return final_color;
            }
            ENDHLSL
        }
    }
}
