Shader "Unlit/Blending"
{
    Properties
    {
        _TexTop("TexTop", 2D) = "white" {}
        _TexBottom("TexBottom", 2D) = "white" {}
    }
    SubShader
    {

        HLSLINCLUDE
        #ifdef UNITY_COLORSPACE_GAMMA
             #define ColorLinearToGamma(c) c
             #define ColorGammaToLinear(c) c
        #else
             #define ColorLinearToGamma(c) pow(c,0.455)
             #define ColorGammaToLinear(c) pow(c,2.2)
        #endif     

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
        //正常
        float3 NormalColor(float3 srcColor,float3 dstColor)
        {
            float3 col=srcColor;
            return col;
        }

        //Dark变暗组

        //变暗
        float3 DarkenColor(float3 srcColor,float3 dstColor)
        {
            float3 col=min(srcColor,dstColor);
            return col;
        }

        //正片叠底:A*B
        float3 MultiplyColor(float3 srcColor,float3 dstColor)
        {
            float3 col=srcColor*dstColor;
            return col;
        }

        //颜色加深:疯狂提高对比度
        float3 ColorBurn(float3 srcColor,float3 dstColor)
        {
            float3 col=1-(1-dstColor)/srcColor;
            col=saturate(col);
            return col;
        }
        
        //线性加深
        float3 LinearBurn(float3 srcColor,float3 dstColor)
        {
            float3 col=srcColor+dstColor-1;
            col=saturate(col);
            return col;
        }

        //深色
        float3 DarkerColor(float3 srcColor,float3 dstColor)
        {
            //去灰度
            float src=dot(srcColor,float3(0.2126, 0.7152, 0.0722));
            float dst=dot(dstColor,float3(0.2126, 0.7152, 0.0722));

            float flag=step(src,dst);
            float3 col=lerp(dstColor,srcColor,flag);
            return col;
        }

        //Lighten变亮组

        //变亮
        float3 LightenColor(float3 srcColor,float3 dstColor)
        {
            float3 col=max(srcColor,dstColor);
            return col;
        }

        //滤色:浅色出现深色不出现1-(1-A)*(1-B),screen是multiply的相反值
        float3 Screen(float3 srcColor,float3 dstColor)
        {
            //float3 col=srcColor+dstColor-srcColor*dstColor;
            float3 col=1-(1-srcColor)*(1-dstColor);
            col=saturate(col);
            return col;
        }

        //颜色减淡（Color Dodge） 是一种强烈变亮的混合模式,与ColorBurn正好相反
        float3 DodgeColor(float3 srcColor,float3 dstColor)
        {
            float3 col=dstColor/(1-srcColor);
            return col;
        }

        //线性减淡:它比滤色和颜色减淡更亮、更直接，会产生强烈的发光和过曝效果
        float3 LinearDodge(float3 srcColor,float3 dstColor)
        {
            float3 col=srcColor+dstColor;
            return col;
        }

        //浅色
        float3 LighterColor(float3 srcColor,float3 dstColor)
        {
            float src=dot(srcColor,float3(0.2126, 0.7152, 0.0722));
            float dst=dot(dstColor,float3(0.2126, 0.7152, 0.0722));

            float flag=step(src,dst);
            float3 col=lerp(srcColor,dstColor,flag);
            return col;
        }

        //对比融合组
        //叠加
        float3 Overlay(float3 srcColor,float3 dstColor)
        {
            float3 mask=step(dstColor,0.5);
            float3 multiply=2*srcColor*dstColor;//暗部:正片叠底
            float3 screen=1-2*(1-srcColor)*(1-dstColor);//亮部：滤色
            float3 col=lerp(screen,multiply,mask);
            return col;
        }

        //柔光
        float3 SoftLighting(float3 srcColor,float3 dstColor)
        { 
            float3 mask=step(srcColor,0.5);
            //暗部
            float3 dark=dstColor-(1-2*srcColor)*dstColor*(1-dstColor);
            //亮部
            float3 light=dstColor+(2*srcColor-1)*(sqrt(dstColor)-dstColor);
            float3 col=lerp(light,dark,mask);
            return col;
        }

        //强光
        float3 HardLight(float3 srcColor,float3 dstColor)
        {
            float3 mask=step(srcColor,0.5);

            float3 multiply=2*srcColor*dstColor;
            float3 screen=1-2*(1-srcColor)*(1-dstColor);

            float3 col=lerp(screen,multiply,mask);
            return col;
        }

        //亮光
        float3 VividColor(float3 srcColor,float3 dstColor)
        {
            float3 mask=step(srcColor,0.5);

            //暗部
            float3 burn=1-(1-dstColor)/(2*srcColor);
            //亮部
            float3 dodge=dstColor/(2*(1-srcColor));

            float3 col=lerp(dodge,burn,mask);
            col=saturate(col);
            return col;
        }

        //线性光
        float3 LinearLight(float3 srcColor,float3 dstColor)
        {
            float3 col=dstColor+2*srcColor-1;
            col=saturate(col);
            return col;
        }

        //点光
        float3 PointLight(float3 srcColor,float3 dstColor)
        {
            float3 mask=step(srcColor,0.5);
            float3 light=max(dstColor,2*(srcColor-0.5));
            float3 dark=min(dstColor,2*srcColor);
            float3 col=lerp(light,dark,mask);
            return col;
        }

        //实色混和
        float3 HardMix(float3 srcColor,float3 dstColor)
        {
            float3 flag = step(1 - dstColor, srcColor);
            float3 col = flag;
            return col;
        }

        //差集组
        //差值
        float3 Difference(float3 srcColor,float3 dstColor)
        {
            float3 col=abs(dstColor-srcColor);
            return col;
        }

        //排除
        float3 Exclusion(float3 srcColor,float3 dstColor)
        {
            float3 col=dstColor+srcColor-2*dstColor*srcColor;
            return col;
        }

        //减去
        float3 Subtract(float3 srcColor,float3 dstColor)
        {
            float3  col=dstColor-srcColor;
            col=saturate(col);
            return col;
        }

        //划分
        float3 Divide(float3 srcColor,float3 dstColor)
        {
            float3 col=dstColor/srcColor;
            return col;
        }

        //色彩组
        //色相
        float3 Hue(float3 srcColor,float3 dstColor)
        {
             float3 col =RgbToHsv(dstColor);
                    col.x = RgbToHsv(srcColor).x;
                    col = HsvToRgb(col);
                    col = saturate(col);
             return col;
        }

        //饱和度
        float3 Saturation(float3 srcColor,float3 dstColor)
        {
            float dstLum = Luminance(dstColor);
            float3 dstHsv = RgbToHsv(dstColor);
            float  srcSat = RgbToHsv(srcColor).y;

            dstHsv.y = srcSat;
            float3 result = HsvToRgb(dstHsv);

            float resultLum = Luminance(result);
            if (resultLum > 0.0001)
                result *= dstLum / resultLum;

            return saturate(result);
        }

        //颜色
        float3 Color(float3 srcColor,float3 dstColor)
        {
            float3 col = RgbToHsv(dstColor);
            col.x = RgbToHsv(srcColor).x;
            col.y = RgbToHsv(srcColor).y;
            col = HsvToRgb(col);
            col = saturate(col);
            return col;
        }

        //明度
        float3 Luminosity(float3 srcColor,float3 dstColor)
        {
            float3 col = RgbToHsv(dstColor);
            col.z = RgbToHsv(srcColor).z;
            col = HsvToRgb(col);
            col = saturate(col);
            return col;
        }

        ENDHLSL

        Pass
        {

            Tags { "RenderType"="Transparent" "Queue"="Transparent"}
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            TEXTURE2D(_TexTop);
            SAMPLER(sampler_TexTop);

            TEXTURE2D(_TexBottom);
            SAMPLER(sampler_TexBottom);

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv=v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 topColor=SAMPLE_TEXTURE2D(_TexTop,sampler_TexTop,i.uv);
                float4 bottomColor=SAMPLE_TEXTURE2D(_TexBottom,sampler_TexBottom,i.uv);

                float3 srcColor=ColorLinearToGamma(topColor.rgb);
                float3 dstColor=ColorLinearToGamma(bottomColor.rgb);

                //loat3 blend=NormalColor(srcColor,dstColor);
                //float3 blend=DarkenColor(srcColor,dstColor);
                //float3 blend=MultiplyColor(srcColor,dstColor);
                //float3 blend=ColorBurn(srcColor,dstColor);
                //float3 blend=LinearBurn(srcColor,dstColor);
                float3 blend=DarkerColor(srcColor,dstColor);

                //float3 blend=LightenColor(srcColor,dstColor);
                //float3 blend=Screen(srcColor,dstColor);
                //float3 blend=DodgeColor(srcColor,dstColor);
                //float3 blend=LinearDodge(srcColor,dstColor);
                //float3 blend=LighterColor(srcColor,dstColor);

                //float3 blend=Overlay(srcColor,dstColor);
                //float3 blend=SoftLighting(srcColor,dstColor);
                //float3 blend=HardLight(srcColor,dstColor);
                //float3 blend=VividColor(srcColor,dstColor);
                //float3 blend=LinearLight(srcColor,dstColor);
                //float3 blend=PointLight(srcColor,dstColor);
                //float3 blend=HardMix(srcColor,dstColor);
                //float3 blend=Difference(srcColor,dstColor);
                //float3 blend=Exclusion(srcColor,dstColor);
                //float3 blend=Subtract(srcColor,dstColor);

                //float3 blend=Divide(srcColor,dstColor);
                //float3 blend=Hue(srcColor,dstColor);
                //float3 blend=Saturation(srcColor,dstColor);
                //float3 blend=Color(srcColor,dstColor);
                //float3 blend=Luminosity(srcColor,dstColor);
                blend=ColorGammaToLinear(blend);
                float blendPart=min(topColor.a,bottomColor.a);

                float4 finalColor=1;
                finalColor.rgb=topColor.rgb*(topColor.a-blendPart)+bottomColor.rgb*(bottomColor.a-blendPart)+blend*blendPart;
                finalColor.a=max(topColor.a,bottomColor.a);
                return finalColor;
            }
            ENDHLSL
        }
    }
}
