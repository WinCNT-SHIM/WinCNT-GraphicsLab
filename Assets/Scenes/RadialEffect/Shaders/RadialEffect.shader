Shader "RadialEffect"
{
    Properties
    {
        // =========================
        // Main Texture
        // =========================
        _MainTex ("Main Tex", 2D) = "white" {}
        [Enum(UV, 0, Polar, 1)] _MainTexUVType("Main Tex UV Type", int) = 0
        _RotationSpeed ("Rotation Speed", Range(-5, 5)) = 0.0
        _ScrollSpeedX ("Scroll X", Float) = 0
        _ScrollSpeedY ("Scroll Y", Float) = 0

        // =========================
        // Mask
        // =========================
        _MaskTex ("Mask Tex", 2D) = "white" {}
        [Enum(UV, 0, Polar, 1)] _MaskTexUVType("Mask Tex UV Type", int) = 0
        _MaskScrollX ("Mask Scroll X", Float) = 0
        _MaskScrollY ("Mask Scroll Y", Float) = 0
        _MaskContrast ("Mask Contrast", Range(1, 3)) = 0
        _MaskIntensity ("Mask Intensity", Range(0, 1)) = 0
        _InnerRadius ("Inner Radius", Range(0, 1)) = 0.5
        _OuterRadius ("Outer Radius", Range(0, 1)) = 0.9
        _RadiusScaleX ("Radius Scale X", Range(0.001, 5)) = 1
        _RadiusScaleY ("Radius Scale Y", Range(0.001, 5)) = 1
        _EdgeSoftness ("Edge Softness", Range(0.001, 0.2)) = 0.05

        [Header(ColorMask)]
        [Enum(RGB,14,RGBA,15)] _ColorMask("ColorMask", Float) = 15

        [Header(BlendMode)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src", int) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst", int) = 10

        [Header(Rendering Opation)]
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Culling Face", Float) = 0
        [Enum(Off, 0, On, 1)] _ZWrite("_ZWrite", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("_ZTest", Float) = 4

        [Header(Stencil)]
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comparison", Float) = 8
        _Stencil("Stencil ID", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilOp("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255

        [Header(Debug)]
        [KeywordEnum(None, RingMask, MaskTex, MaskIntensity, FinalAlpha)] _DebugView("Debug View", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Pass
        {
            Name "RadialEffect"

            Lighting Off
            Blend [_SrcBlend][_DstBlend]
            Cull [_Cull]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            ColorMask [_ColorMask]

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #pragma shader_feature_local_fragment _DEBUGVIEW_NONE _DEBUGVIEW_RINGMASK _DEBUGVIEW_MASKTEX _DEBUGVIEW_MASKINTENSITY _DEBUGVIEW_FINALALPHA

            struct Attributes
            {
                float4 vertex : POSITION;
                half4 color : COLOR;
                float4 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 pos : SV_POSITION;
                half4 color : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_MaskTex);
            SAMPLER(sampler_MaskTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _MainTex_TexelSize;
                half _MainTexUVType;
                float _RotationSpeed;
                float _ScrollSpeedX;
                float _ScrollSpeedY;

                float4 _MaskTex_ST;
                float4 _MaskTex_TexelSize;
                half _MaskTexUVType;
                float _MaskScrollX;
                float _MaskScrollY;
                float _MaskContrast;
                float _MaskIntensity;
                float _InnerRadius;
                float _OuterRadius;
                float _RadiusScaleX;
                float _RadiusScaleY;
                float _EdgeSoftness;
            CBUFFER_END

            float2 GetRotateUV(float2 uv, float2 pivot, float angleRad)
            {
                float s = sin(angleRad);
                float c = cos(angleRad);
                float2 p = uv - pivot;
                float2x2 rot = float2x2(
                    c, -s,
                    s, c
                );
                p = mul(rot, p);
                p += pivot;
                return p;
            }

            float2 GetPolarUV(float2 uv, float2 center)
            {
                float2 p = uv - center;

                float r = length(p);
                // float a = atan2(p.y, p.x);
                float a = FastAtan2(p.y, p.x);

                float angle01 = a * (1.0 / (2.0 * PI)) + 0.5;

                return float2(angle01, r);
            }

            float2 GetUVByType(float2 uv, float2 center, half uvType)
            {
                return (uvType > 0.5) ? GetPolarUV(uv, center) : uv;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.vertex.xyz);
                OUT.pos = vertexInput.positionCS;
                OUT.texcoord = IN.texcoord.xy;
                OUT.color = IN.color;
                return OUT;
            }

            half4 frag(Varyings IN) : COLOR
            {
                half4 outputColor = 1;

                float2 center = float2(0.5, 0.5);
                float2 UV = IN.texcoord;
                float2 polarUV = IN.texcoord;
                // 極座標が必要な場合は取得する
                if ((_MainTexUVType + _MaskTexUVType > 0.5))
                {
                    polarUV = GetPolarUV(UV, center);
                }

                // 中央からのベクトル
                float2 p = (UV - center) / float2(_RadiusScaleX, _RadiusScaleY);
                // 半径
                float r = length(p);
                // リングマスク
                float inner = smoothstep(_InnerRadius, _InnerRadius + _EdgeSoftness, r);
                float outer = 1.0 - smoothstep(_OuterRadius - _EdgeSoftness, _OuterRadius, r);
                float mask = inner * outer;

                // UV - タイプによって一般UVや極座標を取得
                float2 mainTexUV = (_MainTexUVType > 0.5) ? polarUV : UV;
                float2 maskTexUV = (_MaskTexUVType > 0.5) ? polarUV : UV;

                float2 mainUV = TRANSFORM_TEX(mainTexUV, _MainTex);
                mainUV += float2(_ScrollSpeedX, _ScrollSpeedY) * _Time.y;

                if (_RotationSpeed != 0)
                    mainUV = GetRotateUV(mainUV, center, _RotationSpeed * _Time.y);

                half4 mainCol = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                outputColor = mainCol * IN.color;
                outputColor.a *= mask;

                // マスク
                float2 maskUV = TRANSFORM_TEX(maskTexUV, _MaskTex);
                maskUV += float2(_MaskScrollX, _MaskScrollY) * _Time.y;
                half maskTex = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, maskUV).r;
                // マスクの対比補正
                maskTex = smoothstep(0.0, 1.0, saturate((maskTex - 0.5) * _MaskContrast + 0.5));
                float maskIntensity = lerp(1.0, maskTex, _MaskIntensity);
                outputColor.a *= maskIntensity;

                // Debug View
                #if defined(_DEBUGVIEW_RINGMASK)
                return mask;
                #elif defined(_DEBUGVIEW_MASKTEX)
                return maskTex;
                #elif defined(_DEBUGVIEW_MASKINTENSITY)
                return maskIntensity;
                #elif defined(_DEBUGVIEW_FINALALPHA)
                return outputColor.a;
                #endif

                return outputColor;
            }
            ENDHLSL
        }
    }
}