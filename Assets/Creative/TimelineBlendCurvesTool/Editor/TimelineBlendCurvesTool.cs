using System;
using System.Linq;
using UnityEditor;
using UnityEditor.Timeline;
using UnityEditor.UIElements;
using UnityEngine;
using UnityEngine.Timeline;
using UnityEngine.UIElements;

namespace WinCNT.GraphicsLab
{
    public class TimelineBlendCurvesTool : EditorWindow
    {
        private enum BlendCurveSlot
        {
            MixInCurve,
            MixOutCurve
        }

        private enum ClipDirection
        {
            Prev,
            Next,
        }

        [SerializeField] private VisualTreeAsset mVisualTreeAsset;
        [SerializeField] private StyleSheet styleSheet;

        // UI Toolkit
        private VisualElement curveEdit;
        private VisualElement pasteSettings;
        private TextField selectedClipTextField;
        private RadioButtonGroup captureTargetRadioButtonGroup;
        private Button captureButton;
        private CurveField workCurveField;
        private TextField clipToPasteTextField;
        private RadioButtonGroup pasteTargetRadioButtonGroup;
        private Button pasteButton;

        // ツール用
        private bool isCaptured = false;
        private string selectedClipNameToCapture = "";
        private AnimationCurve workCurve;
        private string selectedClipNameToPaste = "";
        private BlendCurveSlot captureTargetBlendCurveSlot = BlendCurveSlot.MixInCurve;
        private BlendCurveSlot pasteTargetBlendCurveSlot = BlendCurveSlot.MixInCurve;

        [MenuItem("Window/UI Toolkit/TimelineBlendCurvesTool %&#x")]
        public static void ShowTimelineBlendCurvesTool()
        {
            var wnd = GetWindow<TimelineBlendCurvesTool>();
            wnd.titleContent = new GUIContent("Timeline Blend Curves");
        }

        public void CreateGUI()
        {
            // Each editor window contains a root VisualElement object
            var root = rootVisualElement;

            // Instantiate UXML
            var labelFromUxml = mVisualTreeAsset.Instantiate();
            root.Add(labelFromUxml);
            if (styleSheet) rootVisualElement.styleSheets.Add(styleSheet);

            // UI Toolkitの初期化
            InitializeTool(root);
        }

        private void InitializeTool(VisualElement root)
        {
            // UIバインド
            curveEdit = root.Q<VisualElement>("CurveEdit");
            pasteSettings = root.Q<VisualElement>("PasteSettings");
            selectedClipTextField = root.Q<TextField>("SelectedClipTextField");
            captureTargetRadioButtonGroup = root.Q<RadioButtonGroup>("CaptureTargetRadioButtonGroup");
            captureButton = root.Q<Button>("CaptureButton");
            workCurveField = root.Q<CurveField>("CapturedCurveField");
            clipToPasteTextField = root.Q<TextField>("ClipToPasteTextField");
            pasteTargetRadioButtonGroup = root.Q<RadioButtonGroup>("PasteTargetRadioButtonGroup");
            pasteButton = root.Q<Button>("PasteButton");

            // リセット
            Reset();

            // UIに初期値を設定
            SetVisualElementEnabled(selectedClipTextField, false);
            SetVisualElementEnabled(clipToPasteTextField, false);
            selectedClipTextField.SetValueWithoutNotify(selectedClipNameToCapture);
            captureTargetRadioButtonGroup.SetValueWithoutNotify((int)pasteTargetBlendCurveSlot);
            captureTargetRadioButtonGroup.RegisterValueChangedCallback(e => OnChangeTargetRadioButton(
                    (BlendCurveSlot)e.newValue,
                    out captureTargetBlendCurveSlot
                )
            );
            captureButton.clicked += OnClickCaptureButton;
            workCurveField.value = null;
            clipToPasteTextField.SetValueWithoutNotify(selectedClipNameToCapture);
            pasteTargetRadioButtonGroup.SetValueWithoutNotify((int)pasteTargetBlendCurveSlot);
            pasteTargetRadioButtonGroup.RegisterValueChangedCallback(e => OnChangeTargetRadioButton(
                    (BlendCurveSlot)e.newValue,
                    out pasteTargetBlendCurveSlot
                )
            );
            pasteButton.clicked += OnClickPasteButton;
        }

        private void Reset()
        {
            if (captureButton != null) captureButton.clicked -= OnClickCaptureButton;
            if (pasteButton != null) pasteButton.clicked -= OnClickPasteButton;

            // 変数のリセット
            isCaptured = false;
            selectedClipNameToCapture = "";
            workCurve = null;
            selectedClipNameToPaste = "";
            captureTargetBlendCurveSlot = BlendCurveSlot.MixInCurve;
            pasteTargetBlendCurveSlot = BlendCurveSlot.MixInCurve;

            // Curve EditとPaste Settingsを非活性にする
            SetUIActiveByCapture(isCaptured);
        }

        void OnChangeTargetRadioButton(BlendCurveSlot selectedBlendCurveSlot, out BlendCurveSlot targetBlendCurveSlot)
            => targetBlendCurveSlot = selectedBlendCurveSlot;

        private void OnClickCaptureButton()
        {
            var selectedClip = GetSelectedClip();
            if (selectedClip == null)
            {
                EditorUtility.DisplayDialog("Error", "クリップを選択して下さい", "OK");
                return;
            }

            // 初期化
            SetVisualElementEnabled(selectedClipTextField, false);
            SetVisualElementEnabled(clipToPasteTextField, false);
            workCurveField.value = null;

            // 選択しているクリック名を表示
            SetClipName(selectedClipTextField, selectedClip.displayName);

            // カーブを表示
            workCurve = GetClipBlendCurve(workCurveField, selectedClip, captureTargetBlendCurveSlot);

            // Captureフラグ
            isCaptured = true;
            // UIの解放
            SetUIActiveByCapture(isCaptured);
        }

        private void OnClickPasteButton()
        {
            var selectedClip = GetSelectedClip();
            if (selectedClip == null) return;

            // 選択しているクリック名を表示
            SetClipName(clipToPasteTextField, selectedClip.displayName);

            // Paste
            SetClipBlendCurve(workCurveField, ref selectedClip, pasteTargetBlendCurveSlot);

            // 近接のクリップ
            var clipDir = pasteTargetBlendCurveSlot == BlendCurveSlot.MixInCurve ? ClipDirection.Prev : ClipDirection.Next;
            var adjacentClip = FindAdjacentClipOnTrack(selectedClip, clipDir);
            if (adjacentClip == null) return;

            if (pasteTargetBlendCurveSlot == BlendCurveSlot.MixInCurve)
            {
                adjacentClip.blendOutCurveMode = TimelineClip.BlendCurveMode.Manual;
                TimelineEditor.Refresh(RefreshReason.ContentsModified);

                EditorApplication.delayCall += () =>
                {
                    adjacentClip.blendOutCurveMode = TimelineClip.BlendCurveMode.Auto;
                    TimelineEditor.Refresh(RefreshReason.ContentsModified);
                };
            }
            else
            {
                adjacentClip.blendInCurveMode = TimelineClip.BlendCurveMode.Manual;
                TimelineEditor.Refresh(RefreshReason.ContentsModified);

                EditorApplication.delayCall += () =>
                {
                    adjacentClip.blendInCurveMode = TimelineClip.BlendCurveMode.Auto;
                    TimelineEditor.Refresh(RefreshReason.ContentsModified);
                };
            }
        }

        private void SetClipName(TextField textField, string clipName)
        {
            selectedClipNameToCapture = clipName;
            if (textField != null) textField.value = clipName;
        }

        private AnimationCurve GetClipBlendCurve(CurveField curveField, TimelineClip clip, BlendCurveSlot blendCurveSlot)
        {
            if (clip == null) return null;

            AnimationCurve result = null;
            if (blendCurveSlot == BlendCurveSlot.MixInCurve)
                result = clip.mixInCurve != null ? new AnimationCurve(clip.mixInCurve.keys) : null;
            else
                result = clip.mixOutCurve != null ? new AnimationCurve(clip.mixOutCurve.keys) : null;

            // CurveFieldに設定
            curveField.value = result;
            return result;
        }

        private void SetClipBlendCurve(CurveField curveField, ref TimelineClip clip, BlendCurveSlot blendCurveSlot)
        {
            if (curveField?.value == null) return;
            if (clip == null) return;
            var track = clip.GetParentTrack();
            if (track == null) return;

            // ターゲットクリップをManualに変更
            clip.blendInCurveMode = TimelineClip.BlendCurveMode.Manual;
            TimelineEditor.Refresh(RefreshReason.ContentsModified);

            var curve = curveField.value;
            if (blendCurveSlot == BlendCurveSlot.MixInCurve)
            {
                clip.blendInCurveMode = TimelineClip.BlendCurveMode.Manual;
                clip.mixInCurve = new AnimationCurve(curve.keys);
            }
            else
            {
                clip.blendOutCurveMode = TimelineClip.BlendCurveMode.Manual;
                clip.mixOutCurve = new AnimationCurve(curve.keys);
            }
            TimelineEditor.Refresh(RefreshReason.ContentsModified);

            EditorUtility.SetDirty(track);
        }

        /// <summary>
        /// CaptureボタンのクリックによってOn/OffされるUIの制御メソッド
        /// </summary>
        private void SetUIActiveByCapture(bool active)
        {
            SetVisualElementEnabled(curveEdit, active);
            SetVisualElementEnabled(pasteSettings, active);
        }

        // ------------------------
        // Helper
        // ------------------------
        private void SetVisualElementEnabled(VisualElement visualElement, bool enabled) => visualElement?.SetEnabled(enabled);

        private static TimelineClip GetSelectedClip()
        {
            var clips = TimelineEditor.selectedClips;
            return clips is { Length: > 0 } ? clips[0] : null;
        }

        private static TimelineClip FindAdjacentClipOnTrack(TimelineClip clip, ClipDirection clipDirection)
        {
            var track = clip.GetParentTrack();
            if (track == null) return null;

            var clips = track.GetClips().OrderBy(c => c.start).ToArray();
            var clipIndex = Array.IndexOf(clips, clip);
            if (clipIndex < 0) return null;

            if (clipDirection == ClipDirection.Prev)
                return (clipIndex > 0) ? clips[clipIndex - 1] : null;
            else
                return (clipIndex < clips.Length - 1) ? clips[clipIndex + 1] : null;
        }
    }
}