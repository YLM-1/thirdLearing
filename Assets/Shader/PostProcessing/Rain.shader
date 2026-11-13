Shader "Hidden/Rain"
{
    Properties
    {
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            struct appdata
            {
                uint vertexID : SV_VertexID;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv = GetFullScreenTriangleTexCoord(v.vertexID);
                return o;
            }

            CBUFFER_START(UnityPerMaterial)
            float _RainSpeed;
            float _TraiLength;
            float _RainAmount;
            float _RainHeight;
            float2 _RainShape;
            CBUFFER_END

            float3 noiseGrid(float2 uv)
            {
                float pt = uv.x * 0.12345 + uv.y * 0.54321;
                float3 pt3= frac(float3(pt * 0.98765,  pt * 0.87654, pt * 0.76543));
                pt3+=dot(pt3,pt3.yzx);
                pt3 = frac(float3((pt3.x + pt3.y) * pt3.z, (pt3.y + pt3.z) * pt3.x, (pt3.z + pt3.x) * pt3.y));
                return pt3;
            }

            float pingpong(float m,float n)
            {
                return smoothstep(0,m,n)*smoothstep(1,m,n);
            }

            float noise(float a)
            {
                return frac(sin(dot(a,123.456))*987.654);
            }

            float staticDrop(float2 uv,float t)
            {
                //1.划分网格
                uv *= 20;

                //2.获取当前网格编号和随机数
                float2 id = floor(uv);
                float3 n3 = noiseGrid(id); 
                //3. 获取网格内部的局部坐标
                uv = frac(uv) - 0.5;
                //4.给每个雨滴生辰随机中心
                float2 p = (n3.xy - 0.5)*0.7;
                //5.计算当前像素到水滴中心的距离
                float radius = length(uv - p);
                //6.控制雨滴的时间变化
                float fade = pingpong(0.25,frac(10*t+n3.z));
                //7.根据距离生成水滴形状
                radius = smoothstep(0.3,0,radius)*fade; 
                return radius;
            }

            float2 dynamicDrop(float2 uv,float t)
            {
                float2 orignalUV = uv;
                uv.y += t;

                float2 scale = float2(6,1);
                float2 scale2 = 2*scale;

                float columnID = floor(uv.x * scale2.x);
                float2 columnPhase = noiseGrid(float2(columnID,0));  

                //1.划分网格
                uv *= scale2;
                uv.y += columnPhase.y + t*columnPhase.x;

                //2.获取当前网格的编号和随机数
                float2 id = floor(uv);
                float3 n3 = noiseGrid(id);

                //3.获取当前网格内部的局部坐标
                float2 st = frac(uv)-0.5;
                //4.给每个雨滴生辰随机中心
                float x = n3.x - 0.5;

                //x方向添加扭曲
                float weight = sin(orignalUV.y*20 + sin(orignalUV.y*20));
                x += weight*(n3.z-0.5);
                x *= 0.6;
                float y = pingpong(0.85, frac(n3.z+t)) - 0.5;
                float2 p = float2(x,y)*0.7;
                //5.计算当前像素到水滴中心的距离
                float d = length((st - p)*scale.yx*_RainShape);

                //绘制mainDrops
                float mainDrops = smoothstep(0.4,0,d);

                //6.绘制拖尾 = 横向遮罩*纵向遮罩
                float dx = abs(st.x - p.x);
                float dy = st.y - p.y;

                float trailLength = max(min(_TraiLength,0.5-p.y),0.05);//长度不超出格子上边界
                float trailWidth = min(0.2*(1-saturate(dy/trailLength)),0.5 - abs(p.x));// 宽度不超出格子左右边界

                //float trailHeight = step(0, dy) * (1 - smoothstep(0, trailLength, dy));
                float trailSoftness = 0.15;
                float trailHeight = smoothstep(0,trailSoftness,dy) * (1 - smoothstep(0, trailLength, dy));
                float trail = 1-smoothstep(0.5*trailWidth,trailWidth,dx);
                trail *= trailHeight;
                // return trail;

                //7.绘制拖尾小水珠
                float beadY = p.y +  (0.2 + 0.6*n3.y);
                // 乘 scale.yx：把格子空间的各向异性抵消掉，屏幕上才是正圆
                float dd = length((st - float2(p.x,beadY))*scale.yx*_RainShape);
                float droplets = smoothstep(0.35,0,dd)*trailHeight;

                return float2(mainDrops+droplets,trail);
            }

            float2 drops(float2 uv,float t,float layer0,float layer1,float layer2)
            {
                //静态水滴
                float sd = staticDrop(uv,t)*layer0;
                //动态水滴
                float2 dd0 = dynamicDrop(uv,t)*layer1;
                float2 dd1 = dynamicDrop(uv*1.85,t)*layer2;

                float c = sd +dd0.x +dd1.x;
                c = smoothstep(0.15,0.6,c);
                float trail = max(dd0.y,dd1.y);
                return float2(c,trail);
            }

            float4 frag (v2f i) : SV_Target
            {
                i.uv.x *= _ScreenParams.x/_ScreenParams.y;
                float t = _Time.x*_RainSpeed;

                float layer0 = smoothstep(0,2,_RainAmount);
                float layer1 = smoothstep(0,0.75,_RainAmount);
                float layer2 = smoothstep(0,0.5,_RainAmount);

                float2 c=drops(i.uv,t,layer0,layer1,layer2);

                float2 e = float2(_RainHeight,0);
                float cx = drops(i.uv+e,t,layer0,layer1,layer2).x;
                float cy = drops(i.uv+e.yx,t,layer0,layer1,layer2).x;

                float2 normal = float2(cx - c.x,cy - c.x);

                float lod = lerp(6,0,c.y*_RainAmount);
                float4 col = SAMPLE_TEXTURE2D_X_LOD(_BlitTexture,sampler_LinearClamp,saturate(i.uv + normal),lod);

                return col;
            }
            ENDHLSL
        }
    }
}
