Shader "Hidden/ShowVertexColor" {
	Properties {
		_MainTex ("Texture", 2D) = "white" { }
		_OutlineWidth("OutlineWidth",FLOAT)=1
        _OutlineColor("OutlineColor",COLOR)=(1,1,1,1)
	}
	SubShader {
		Pass {
			Tags { "LightMode" = "UniversalForward" }

			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct Attrubute {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 color : COLOR;
			};
			struct Varying {
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 col : TEXCOORD1;
			};
			
			TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

			Varying vert(Attrubute v) {
				Varying o;
				o.position = TransformObjectToHClip(v.vertex.xyz);
				o.uv = v.uv;
				o.col = v.color;
				return o;
			}
			half4 frag(Varying i) : SV_TARGET {
				half4 col = i.col;
				return col;
			}

			ENDHLSL

		}
		Pass {
			Name "Outline"
			Cull Front

			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct Attrubute {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 color : COLOR;
				float3 nor : NORMAL;
				float4 tangent: TANGENT;
			};
			struct Varying {
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normalDir : TEXCOORD1;
				float3 tangentDir:TEXCOORD2;
				float3 bitangentDir:TEXCOORD3;
				float4 col:TEXCOORD4;
			};
			CBUFFER_START(UnityPerMaterial)
			float _OutlineWidth;
            float4 _OutlineColor;
			CBUFFER_END
			
			TEXTURE2D(_MainTex);SAMPLER(sampler_MainTex);

			float3 UnpackNormalCol(real3 rgb){
				float3 normal;
				normal.x=(rgb.x-0.5)*2;
				normal.y=(rgb.y-0.5)*2;
				normal.z=(rgb.z-0.5)*2;
				normal=normalize(normal);
				return normal;
			}
			Varying vert(Attrubute v) {
				Varying o;

				o.uv = v.uv;
				o.col = half4(1, 0, 0, 1);

				o.normalDir = TransformObjectToWorldNormal(v.nor);
				o.tangentDir = normalize(mul(UNITY_MATRIX_M, float4(v.tangent.xyz, 0.0)).xyz);
				o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
				float3x3 tangentTransform = float3x3(o.tangentDir, o.bitangentDir, o.normalDir);

				float3 bakedNormal = normalize(UnpackNormalCol(v.color.rgb));
				float3 outlineNormal = normalize(mul(bakedNormal, tangentTransform));

				o.position = TransformWorldToHClip(TransformObjectToWorld(v.vertex.xyz) + outlineNormal * _OutlineWidth);
				return o;
			}
			half4 frag(Varying i) : SV_TARGET {
				float4 col=_OutlineColor;
				return col;
			}

			ENDHLSL

		}
	}
}
