Shader "WinCNT/UI/TriangleMosaicGlintHSV"
{
    Properties
    {
        // =========================================================
        // Base
        // =========================================================
        [PerRendererData] _MainTex ("Main Texture", 2D) = "white" {}
        _Tint ("Tint", Color) = (1,1,1,1)

        // =========================================================
        // Triangle Mosaic
        // =========================================================
        [Header(Triangle Mosaic)]
        _TriMosaic_Size ("Triangle Size", Range(0.001, 10)) = 0.1
        _TriMosaic_RotationDeg ("Rotation (Degrees)", Range(0, 360)) = 0

        // =========================================================
        // Glint HSV (Grouped & Unified)
        // =========================================================
        [Header(Glint HSV)]
        _GlintHSV_Strength ("Strength", Range(0, 1)) = 1.0
        _GlintHSV_Speed ("Speed", Float) = 1.0

        _GlintHSV_HueRange ("Hue Range", Range(0, 1)) = 0.2

        _GlintHSV_SatRange ("Saturation Range", Range(0, 1)) = 0.2
        _GlintHSV_SatStrength ("Saturation Strength", Range(0, 1)) = 1.0

        _GlintHSV_ValRange ("Value Range", Range(0, 1)) = 0.2
        _GlintHSV_ValStrength ("Value Strength", Range(0, 1)) = 1.0

        // =========================================================
        // UI Render State
        // =========================================================
        [Header(Blend)]
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc ("Blend Src", int) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", int) = 10

        [Header(Color Write)]
        [Enum(RGB,14,RGBA,15)] _WriteColorMask ("Write Color Mask", Float) = 15

        [Header(Stencil)]
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilCompare ("Stencil Compare", Float) = 8
        _StencilRef ("Stencil Ref", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPassOp ("Stencil Pass Op", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }

        Stencil
        {
            Ref [_StencilRef]
            Comp [_StencilCompare]
            Pass [_StencilPassOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Pass
        {
            Blend [_BlendSrc][_BlendDst]
            ColorMask [_WriteColorMask]

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #pragma multi_compile_local _ UNITY_UI_CLIP_RECT
            #pragma multi_compile_local _ UNITY_UI_ALPHACLIP

            // =========================================================
            // Constants (Magic Numbers)
            // =========================================================
            static const float kEpsilon = 1e-10;
            static const float kClipHuge = 2e10;

            // Keep original behavior: triSize = _TriMosaic_Size / 10
            static const float kTriSizeScale = 0.1;

            // =========================================================
            // Vertex / Fragment IO
            // =========================================================
            struct Attributes
            {
                float4 positionOS : POSITION;
                half4 color : COLOR;
                float4 uv0 : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half4 color : COLOR;
                float2 uv : TEXCOORD0;
                float4 uiMask : TEXCOORD1;
                float2 mosaicUV : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // UI-related (Unity UI)
            float4 _ClipRect;
            float _UIMaskSoftnessX;
            float _UIMaskSoftnessY;

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _MainTex_TexelSize;
                half4 _Tint;

                // Triangle Mosaic
                half _TriMosaic_Size;
                half _TriMosaic_RotationDeg;

                // Glint HSV (Unified)
                half _GlintHSV_Strength;
                half _GlintHSV_Speed;

                half _GlintHSV_HueRange;

                half _GlintHSV_SatRange;
                half _GlintHSV_SatStrength;

                half _GlintHSV_ValRange;
                half _GlintHSV_ValStrength;
            CBUFFER_END

            // =========================================================
            // Helpers
            // =========================================================
            float2 RotateUvAroundPivot(float2 uv, float2 pivot, float angleRad)
            {
                float s = sin(angleRad);
                float c = cos(angleRad);

                float2 local = uv - pivot;
                float2x2 rot = float2x2(c, -s, s, c);

                local = mul(rot, local);
                return local + pivot;
            }

            // RGB -> HSV
            half3 RgbToHsv(half3 rgb)
            {
                half4 K = half4(0., -1. / 3., 2. / 3., -1.);
                half4 p = rgb.g < rgb.b ? half4(rgb.bg, K.wz) : half4(rgb.gb, K.xy);
                half4 q = rgb.r < p.x ? half4(p.xyw, rgb.r) : half4(rgb.r, p.yzx);
                half d = q.x - min(q.w, q.y);
                return half3(abs(q.z + (q.w - q.y) / (6. * d + (half)kEpsilon)),
                                 d / (q.x + (half)kEpsilon),
                                 q.x);
            }

            // HSV -> RGB
            half3 HsvToRgb(half3 hsv)
            {
                half4 K = half4(1., 2. / 3., 1. / 3., 3.);
                half3 p = abs(frac(hsv.xxx + K.xyz) * 6. - K.www);
                return hsv.z * lerp(K.xxx, saturate(p - K.xxx), hsv.y);
            }

            float Hash1To1(float x)
            {
                x = frac(x * 123.34);
                x += x * x + 23.45;
                return frac(x * x);
            }

            float Hash3To1(float3 p)
            {
                p = frac(p * 0.1031);
                p += dot(p, p.yzx + 33.33);
                return frac((p.x + p.y) * p.z);
            }

            float GetTriangleCellRandom01(float2 uv, float triSize)
            {
                static const float kSqrt3 = 1.7320508075688772;

                float2 scaled = uv / triSize;

                // Convert to an oblique coordinate system aligned to an equilateral triangle grid
                float cx = scaled.x - scaled.y / kSqrt3;
                float cy = (2.0 * scaled.y) / kSqrt3;

                float2 coord = float2(cx, cy);
                float2 cell = floor(coord);
                float2 f = frac(coord);

                // Select which of the two triangles inside the rhombus cell
                float triParity = step(1.0, f.x + f.y);

                float3 triId = float3(cell, triParity);
                return Hash3To1(triId);
            }

            // =========================================================
            // Vertex
            // =========================================================
            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = posInputs.positionCS;
                output.uv = TRANSFORM_TEX(input.uv0, _MainTex);

                // Compute screen-space UV for the triangle mosaic
                float4 screenPos = ComputeScreenPos(output.positionCS);
                float2 screenUV = screenPos.xy / screenPos.w;

                // Aspect compensation (treat screenUV as "square-ish" space)
                screenUV.y *= _ScreenParams.y / _ScreenParams.x;

                // Apply rotation around screen center
                float angleRad = radians(_TriMosaic_RotationDeg);
                output.mosaicUV = RotateUvAroundPivot(screenUV, float2(0.5, 0.5), angleRad);

                // UI clip rect mask setup
                float2 pixelSize = posInputs.positionCS.w;
                pixelSize /= float2(1, 1) * abs(mul((float2x2)UNITY_MATRIX_P, _ScreenParams.xy));

                float4 clampedRect = clamp(_ClipRect, -kClipHuge, kClipHuge);
                output.uiMask = float4(
                    input.positionOS.xy * 2 - clampedRect.xy - clampedRect.zw,
                    0.25 / (0.25 * half2(_UIMaskSoftnessX, _UIMaskSoftnessY) + abs(pixelSize.xy))
                );

                output.color = input.color * _Tint;
                return output;
            }

            // =========================================================
            // Fragment
            // =========================================================
            half4 frag(Varyings input) : COLOR
            {
                half4 outColor = 1;

                half4 mainSample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                outColor = mainSample * input.color;

                // Triangle mosaic cell random
                float triSize = (float)_TriMosaic_Size * kTriSizeScale; // == _TriMosaic_Size / 10
                float cellRand01 = GetTriangleCellRandom01(input.mosaicUV, triSize);

                // Convert to HSV (based on main texture color)
                float3 hsv = RgbToHsv(mainSample.rgb);

                // Offset wave phase using per-cell random (shared across HSV for performance)
                float timeSec = _Time.y;
                float phaseRad = Hash1To1(cellRand01) * TWO_PI;
                float wave = sin(timeSec * _GlintHSV_Speed + phaseRad);

                // Hue shift
                hsv.x = frac(hsv.x + wave * _GlintHSV_HueRange);

                // Saturation shift
                float deltaS = wave * _GlintHSV_SatRange;
                hsv.y = lerp(hsv.y, saturate(hsv.y + deltaS), _GlintHSV_SatStrength);

                // Value shift
                float deltaV = wave * _GlintHSV_ValRange;
                hsv.z = lerp(hsv.z, saturate(hsv.z + deltaV), _GlintHSV_ValStrength);

                // Back to RGB & blend
                float3 shiftedRgb = HsvToRgb(hsv);
                half4 shiftedCol = half4(shiftedRgb, mainSample.a);
                outColor = lerp(outColor, shiftedCol, _GlintHSV_Strength);

                #ifdef UNITY_UI_CLIP_RECT
                half2 m = saturate((_ClipRect.zw - _ClipRect.xy - abs(input.uiMask.xy)) * input.uiMask.zw);
                outColor.a *= m.x * m.y;
                #endif

                #ifdef UNITY_UI_ALPHACLIP
                clip(outColor.a - kAlphaClipThreshold);
                #endif

                return outColor;
            }
            ENDHLSL
        }
    }
}