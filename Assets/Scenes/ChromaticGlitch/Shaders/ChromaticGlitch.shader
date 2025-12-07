Shader "ChromaticGlitch"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _GrayscaleProgress ("Grayscale Progress", Range(0, 1)) = 0.0
        _FilterColor ("Filter Color", Color) = (1.0, 1.0, 1.0, 1)
        _FilterProgress ("Filter Progress", Range(0, 1)) = 0.0
        _GlitchNoiseTex ("Glitch Noise", 2D) = "gray" {}
        _GlitchPow("Glitch Power", Range(-1, 1)) = 0
        _GlitchBands("Glitch Bands", Range(1, 32)) = 2
        _GlitchBandScale("Line Noise Scale", Range(0.1, 10)) = 0.5

        [Toggle] _GlitchAutoOn("Glitch Auto On", Float) = 0
        _GlitchAutoCalmSpeed("Auto Calm Speed", Range(0, 2)) = 0.05
        _GlitchAutoSpikeSpeed("Auto Spike Speed", Range(0, 20)) = 5.0
        _GlitchAutoSpikeInterval("Auto Spike Interval", Range(0.1, 5)) = 1.5
        _GlitchAutoSpikeProb("Auto Spike Probability", Range(0, 1)) = 0.35
        _ChromaticSpikeAmount("Chromatic Spike Amount", Range(0, 2)) = 1.0

        [Enum(Red,0, Green,1, Blue,2, Cyan,3, Magenta,4, Yellow,5)] _ChromaticColor1("Chromatic Color 1", Float) = 3
        [Enum(Red,0, Green,1, Blue,2, Cyan,3, Magenta,4, Yellow,5)] _ChromaticColor2("Chromatic Color 2", Float) = 4
        _ChromaticAmount("Chromatic Amount", Range(0, 1)) = 0
        _AberrationX("Aberration X", Range(-1, 1)) = 0
        _AberrationY("Aberration Y", Range(-1, 1)) = 0

        [Toggle] _UseAlphaClip("Use Alpha Clipping", Float) = 0
        _Cutoff("Alpha Clipping Cutoff", Range(0,1)) = 0.5

        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Culling", Float) = 2
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Blend Source", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Blend Destination", Float) = 10
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("ZTest", Float) = 8
        [Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "PreviewType"="Plane"
        }

        LOD 100

        Cull [_Cull]
        Blend [_SrcBlend] [_DstBlend]
        ZTest [_ZTest]
        ZWrite [_ZWrite]

        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #pragma vertex Vert
            #pragma fragment Frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D_X(_GlitchNoiseTex);
            SAMPLER(sampler_GlitchNoiseTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _GrayscaleProgress;
                float4 _FilterColor;
                float _FilterProgress;

                float4 _GlitchNoiseTex_ST;
                float4 _GlitchTex_TexelSize;
                half _GlitchPow;
                half _GlitchBands;
                half _GlitchBandScale;

                half _GlitchAutoOn;
                float _GlitchAutoCalmSpeed;
                float _GlitchAutoSpikeSpeed;
                float _GlitchAutoSpikeInterval;
                float _GlitchAutoSpikeProb;
                float _ChromaticSpikeAmount;

                half _ChromaticColor1;
                half _ChromaticColor2;
                half _ChromaticAmount;
                half _AberrationX;
                half _AberrationY;

                half _UseAlphaClip;
                float _Cutoff;
            CBUFFER_END

            // 색수차의 색을 정하기 위한 마스크
            float3 GetChannelMask(int id)
            {
                // id: 0=R, 1=G, 2=B, 3=C, 4=M, 5=Y
                const float3 masks[6] = {
                    float3(1, 0, 0), // R
                    float3(0, 1, 0), // G
                    float3(0, 0, 1), // B
                    float3(0, 1, 1), // C
                    float3(1, 0, 1), // M
                    float3(1, 1, 0), // Y
                };
                return masks[id];
            }

            float2 UVMirroring(float2 uv)
            {
                return 1 - abs((2 * frac(uv * 0.5)) - 1);
            }

            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                return OUT;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                half4 color = half4(1, 1, 1, 1);

                float glitchLine = saturate(input.uv.y);
                // Auto 글리치
                float autoOn = step(0.5, _GlitchAutoOn);
                float autoScrollX = 0.0f;
                float spikeFactor = 0.0f;
                // Auto 글리치가 On일 경우
                if (autoOn > 0.5)
                {
                    // 글리치 스파이크 발생 블록의 길이
                    float t = _Time.y;
                    float blockIndex = floor(t / _GlitchAutoSpikeInterval);
                    // 스파이크 블록을 난수화 (숫자는 난수화에 관용적으로 사용되는 매직 넘버)
                    float blockRand = frac(sin(blockIndex * 12.9898) * 43758.5453);
                    // 스파이크 발생 난수가 설정 값을 넘길 경우, 글리치 스파이크를 발생시킴 
                    float isSpike = step(1.0 - _GlitchAutoSpikeProb, blockRand);

                    // 스파이크 발생
                    float localT = frac(t / _GlitchAutoSpikeInterval);
                    float spikeShape = 4.0 * localT * (1.0 - localT);
                    spikeFactor = isSpike * spikeShape;

                    // 평상시랑 스파이크시을 인터폴레이션
                    float autoSpeed = lerp(_GlitchAutoCalmSpeed, _GlitchAutoSpikeSpeed, spikeFactor);
                    // 노이즈 텍스처를 X방향만큼 스크롤
                    autoScrollX = t * autoSpeed;
                }
                float rawNoise = SAMPLE_TEXTURE2D_X(_GlitchNoiseTex, sampler_GlitchNoiseTex, float2(autoScrollX, glitchLine * _GlitchBandScale)).r;

                // 노이즈를 양자화
                float bands = _GlitchBands;
                float bandId = floor(rawNoise * bands);
                // 해시
                float bandRand = frac(sin(bandId * 12.9898) * 43758.5453);
                half glitch = bandRand - 0.5;
                // 글리치 UV
                float2 glitchUv = float2(glitch, glitch);
                glitchUv = TRANSFORM_TEX(glitchUv, _GlitchNoiseTex) * _GlitchPow;

                // 色収差の外れ度合
                float2 aberration = float2(_AberrationX, _AberrationY);
                float spikeAmp = 1.0 + _ChromaticSpikeAmount * spikeFactor;
                aberration = aberration * spikeAmp;

                float2 baseUV = input.uv + glitchUv;
                float2 chromaticCol1UV = UVMirroring(baseUV + aberration);
                float2 chromaticCol2UV = UVMirroring(baseUV - aberration);
                float2 centerUV = UVMirroring(baseUV);

                // 色収差に使う色を設定する
                float3 chromaticMask1 = GetChannelMask(_ChromaticColor1);
                float3 chromaticMask2 = GetChannelMask(_ChromaticColor2);

                half3 chromaticCol1 = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, chromaticCol1UV).rgb * chromaticMask1;
                half3 chromaticCol2 = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, chromaticCol2UV).rgb * chromaticMask2;
                half4 baseCol = SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, centerUV);
                half3 chromaFringe = (chromaticCol1 + chromaticCol2) - baseCol.rgb;

                color.rgb = baseCol.rgb + chromaFringe * _ChromaticAmount;
                color.a = baseCol.a;

                half useClip = step(0.5, _UseAlphaClip);
                if (useClip > 0.5) clip(baseCol.a - _Cutoff);

                // Graysacel
                color.rgb = lerp(color.rgb, dot(color.rgb, float3(0.299, 0.587, 0.114)), _GrayscaleProgress);
                // Filter
                color.rgb = lerp(color.rgb, color.rgb * _FilterColor.rgb, _FilterProgress);

                return color;
            }
            ENDHLSL
        }
    }
}