Shader "Unlit/Ocean"
{
    Properties
    {
        [Header(Reflection)]
        _ReflectionIntensity("ReflectionIntensity",Range(0,1))=0.5
        _ReflectionDistortion("ReflectionDistortion",Range(0,0.1))=0.05
        _FresnelF0("Fresnel F0",Range(0,1))=0.02
        _FresnelPower("Fresnel Power",Float)=5

        [Header(Refraction)]
        _DepthPower("_DepthPower",Float)=5
        _DepthLevel("_DepthLevel",Range(0,0.1))=0.02
        _ShallowColor("ShallowColor",Color)=(1,1,1,1)
        _DepthColor("DepthColor",Color)=(1,1,1,1)
        _RefractionDistortion("RefractionDistortion",Range(0,0.05))=0.02

        [Header(SSS)]
        _SSSDistort("SSS Distort",Range(0,1))=0.2
        _SSSPower("SSS Power",Float)=5
        _SSSIntensity("SSS Intensity",Range(0,2))=1
        _SSSColor("SSS Color",Color)=(1,1,1,1)

        [Header(Wave)]
        _WaveNormalMap("WaveNormalMap",2D) = "bump"{}
        _WaveNormalIntensity("WaveNormalIntensity",Range(0,1))=1
        _WaveSpeed("Wave Speed",Float) = 1
        _WaveDirection("Wave Direction",Float)=1

        [Header(Specular)]
        _SpecularPower("SpecularPower",Float)=5
        _SpecularIntensity("SpecularIntensity",Range(0,2))=1
        _WaterSpecularColor("WaterSpecularColor",Color)=(1,1,1,1)

        [Header(Flow)]
        [Toggle(_USE_FLOWMAP)] _UseFlowMap("Use Flow Map",Float)=0
        _FlowMap("Flow Map",2D)="black"{}
        _FlowIntensity("Flow Intensity",Range(0,1))=0.5
        _FlowSpeed("Flow Speed",Float)=1
        _NormalTex("Flow Normal Map",2D)="bump"{}
        _NormalScale("Flow Normal Scale",Range(0,2))=1
        _FlowNormalStrength("Flow Normal Strength",Range(0,1))=0.5

        [Header(Foam)]
        _FoamColor("Foam Color",Color)=(1,1,1,1)
        _FoamScope("Foam Scope",Float)=1.7
        _FoamPower("Foam Power",Float)=5
        _FoamIntensity("Foam Intensity",Range(0,2))=1
        _FoamInterval("Foam Interval",Float)=6
        _FoamWidth("Foam Width",Float)=0.1
        _FoamSpeed("Foam Speed",Float)=0.1

        [Header(Gerstner)]
        _WaveCount("Wave Count",Float)=10
        _WavelengthMax("Wavelength Max",Float)=160
        _WavelengthMin("Wavelength Min",Float)=45
        _WavesteepnessMax("Steepness Max",Range(0,1))=0.1
        _WavesteepnessMin("Steepness Min",Range(0,1))=0
        _RandomDirection("Random Direction",Range(0,1))=0.5
        _GerstnerSpeed("Gerstner Speed",Float)=1
        _Direction("Wave Direction",Vector)=(1,0,0,0)

    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent"}
        LOD 100

        Pass
        {
            Name "MainPass"
            Tags{"LightMode"="UniversalForward"}
            ZWrite Off
            Cull Back
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"


            // 阴影获取需要的关键字变体
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            //FlowMap 开关
            #pragma shader_feature_local _USE_FLOWMAP

            #include "OceanPro.hlsl"
            ENDHLSL
        }
    }
    CustomEditor "Scarecrow.SimpleShaderGUI"
}
