Shader "Myshader/Ocean"
{
    Properties
    {
      [Header(Wave)]
      _WaveNormalMap("WaveNormalMap", 2D)="bump"{}
      _WaveSpeed("WaveSpeed", Range(0,0.1))=0.05
      _WaveDirection("WaveDirection0", Range(0,1))=0.25

      [Header(Gerstner Wave)]
      _GerstnerWaveCount("Wave Count", Range(1,32))=16
      _GerstnerRandomDirection("Random Direction", Range(0,1))=1
      _GerstnerWavelengthMax("WaveLength Max", Range(0.1,5))=5
      _GerstnerWavelengthMin("WaveLength Min", Range(0.1,5))=1
      _GerstnerSteepnessMax("WaveSteepness Max", Range(0,1))=0.35
      _GerstnerSteepnessMin("WaveSteepness Min", Range(0,1))=0.05
      _GerstnerSpeed("Wave Speed", Range(0,3))=1
      _GerstnerDirection("Direction", Vector)=(1,1,0,0)

      [Header(Specular)]
      _SpecularPower("SpecularPower", Range(0,10))=5
      _SpecularIntensity("SpecularIntensity", Range(0,1))=0.5
      
      [Header(Refraction)]
      _RefractionDistortion("RefractionDistortion", Range(0,0.05))=0.01
      _DepthFactor("DepthFactor", Range(0,0.1))=0.01
      _ShallowColor("ShallowColor", Color)=(0,0,0,0)
      _DepthColor("DepthColor", Color)=(1,1,1,1)

      [Header(Reflection)]
      _ReflectionTex("ReflectionTex", 2D)="white"{}
      _Distortion("Distortion", Range(0,0.1))=0.01

       [Header(Combine)]
       _CombineFactor("Manual Reflection", Range(0,1))=0.5
       _FresnelInfluence("Fresnel Influence", Range(0,1))=1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"


            // 阴影获取需要的关键字变体
               #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
               #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
               #pragma multi_compile _ _IS_NEEDWAVEANIMATION_ON
               #pragma multi_compile _ _ISNEEDPERLINNOISENORMAL_ON
               #pragma multi_compile _ _ANIMATION_FLOWMAP _ANIMATION_PERLINNOISE _ANIMATION_GESTERSIN _ANIMATION_FFT

               #pragma shader_feature_local _USE_FLOWMAP

               #include "OceanMainPass.hlsl"

            ENDHLSL
        }
    }
    CustomEditor "Scarecrow.SimpleShaderGUI"
}
