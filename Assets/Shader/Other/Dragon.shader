Shader "Unity/Dragon"
{
	Properties
	{
		[Header(Base Color)]
		_DiffuseColor("Diffuse Color",Color)=(1.0,1.0,1.0,1.0)
		_AddColor("Add Color",Color)=(1,1,1,1)
		_Opacity("Opacity",Range(0,1))=0
		
		[Header(Translucency)]
		_BackLightColor("Back Light Color",Color)=(1,1,1,1)
		_ThincknessMap("Thinckness Map",2D)="white"{}
		_Distart("Distart",Range(0.0,1.0))=0.3
		_Power("Power",Float)=2.0 //对比度
		_Scale("Scale",Float)=1.0//亮度
		
		[Header(Reflection)]
		_CubeMap("Cube Map",Cube)="white"{}
		_CubeStrength("Cube Strength",Range(0,1))=1
		_Rotate("Rotate",Range(0,360))=0
    }
	SubShader
	{
	Tags{"RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Geometry"}

	HLSLINCLUDE
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

	struct appdata
	{
		float4 vertex:POSITION;
		float2 uv:TEXCOORD0;
		float3 normal:NORMAL;
	};

	struct v2f
	{
		float4 pos:SV_POSITION;
		float2 uv:TEXCOORD0;
		float3 worldNormal:TEXCOORD1;
		float3 worldPos:TEXCOORD2;
	};

	CBUFFER_START(UnityPerMaterial)
	float _Distart;
	float _Power;
	float _Scale;
	float4 _CubeMap_HDR;
	float _Rotate;
	float4 _DiffuseColor;
	float4 _AddColor;
	float _Opacity;
	float _CubeStrength;
	float4 _BackLightColor;
	CBUFFER_END

	TEXTURE2D(_ThincknessMap);
	SAMPLER(sampler_ThincknessMap);

	TEXTURECUBE(_CubeMap);
	SAMPLER(sampler_CubeMap);

	    float3 RotateAround(float degree,float3 target)
		{
			float rad=degree*PI/180;
			float2x2 m_rotate=float2x2(cos(rad),-sin(rad),sin(rad),cos(rad));
			float2 reflectDir=mul(m_rotate,target.xz);//绕着y轴旋转
			target=float3(reflectDir.x,target.y,reflectDir.y);
			return target;
		}
	ENDHLSL
	  Pass
	 {
		 Name "ForwardLit"
		 Tags{"LightMode"="UniversalForward"}

		 HLSLPROGRAM
		 #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS

		 #pragma vertex vert 
		 #pragma fragment frag 

		 v2f vert(appdata v)
		 {
			 v2f o;
			 o.pos=TransformObjectToHClip(v.vertex.xyz);
			 o.uv=v.uv;
			 o.worldNormal=TransformObjectToWorldNormal(v.normal.xyz);
			 o.worldPos=TransformObjectToWorld(v.vertex.xyz);
			 return o;
		  }

		  float4 frag(v2f i):SV_TARGET
		  {
			  float3 worldNormal=normalize(i.worldNormal);
			  float3 worldViewDir=normalize(_WorldSpaceCameraPos.xyz-i.worldPos.xyz);
			  Light light=GetMainLight();

			   //漫反射
			  float diffuse_dot=saturate(dot(worldNormal,light.direction.xyz));
			  float3 diffuse_color=_DiffuseColor.xyz*diffuse_dot*light.color.xyz;
			  float3 ambient=SampleSH(worldNormal);
			  float3 final_diffuse=diffuse_color+_AddColor.xyz+ambient*_Opacity;//_AddColor.xyz：一个常量颜色偏移，类似于最基础的 Ambient（环境光），让物体的阴影处不至于全黑。

			  //透射光
			  float Thinckness=1.0-SAMPLE_TEXTURE2D(_ThincknessMap,sampler_ThincknessMap,i.uv).r;
			  //伪造一个从物体内部“透射”出来的光源方向。
			  float3 back_dir=-normalize(light.direction+worldNormal*_Distart);
			  float VdotL=saturate(dot(worldViewDir,back_dir));
			  float backlight_term=saturate(pow(VdotL,_Power))*_Scale;
			  float3 color=backlight_term*light.color.xyz*Thinckness*_BackLightColor.rgb;

			  //光泽反射
			  float3 reflectview=reflect(-worldViewDir,worldNormal);
			  reflectview=RotateAround(_Rotate,reflectview);
			  float4 cube_color=SAMPLE_TEXTURECUBE(_CubeMap,sampler_CubeMap,reflectview);
			  //菲尼尔效果
			  float fresnel=pow(1.0-saturate(dot(worldNormal,worldViewDir)),4.0);
			  float3 env_color=DecodeHDREnvironment(cube_color,_CubeMap_HDR)*_CubeStrength+fresnel;
			  
			  uint lightsCount=GetAdditionalLightsCount();
			  for(int lightIndex=0;lightIndex<lightsCount;lightIndex++)
			  {
				 Light light=GetAdditionalLight(lightIndex,i.worldPos);
				 float3 add_back_dir=-normalize(light.direction+worldNormal*_Distart);
				 float add_VdotL=saturate(dot(add_back_dir,worldViewDir));
				 float add_backlight_term=saturate(pow(add_VdotL,_Power))*_Scale;
				 color+=add_backlight_term*light.color.xyz*Thinckness*_BackLightColor.rgb;
			   }
			   float3 final_color=env_color+color+final_diffuse;
			   // float3 final_color=color;
			   final_color=AcesTonemap(final_color);
			   return float4(final_color,1);
		   }
		 ENDHLSL
	  }
	}
}