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
        private Button resetButton;
        private VisualElement captureSettings;
        private VisualElement curveEdit;
        private VisualElement pasteSettings;
        private TextField selectedClipTextField;
        private RadioButtonGroup captureTargetRadioButtonGroup;
        private Button captureButton;
        private CurveField workingCurveField;
        private TextField clipToPasteTextField;
        private RadioButtonGroup pasteTargetRadioButtonGroup;
        private Button pasteButton;

        // ツール用
        private bool isCaptured = false;
        private string selectedClipNameToCapture = "";
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
            resetButton = root.Q<Button>("ResetButton");
            captureSettings = root.Q<VisualElement>("CaptureSettings");
            curveEdit = root.Q<VisualElement>("CurveEdit");
            pasteSettings = root.Q<VisualElement>("PasteSettings");
            selectedClipTextField = root.Q<TextField>("SelectedClipTextField");
            captureTargetRadioButtonGroup = root.Q<RadioButtonGroup>("CaptureTargetRadioButtonGroup");
            captureButton = root.Q<Button>("CaptureButton");
            workingCurveField = root.Q<CurveField>("WorkingCurveField");
            clipToPasteTextField = root.Q<TextField>("ClipToPasteTextField");
            pasteTargetRadioButtonGroup = root.Q<RadioButtonGroup>("PasteTargetRadioButtonGroup");
            pasteButton = root.Q<Button>("PasteButton");

            // リセット
            Reset();

            // UIに初期値を設定
            InitializeUI();
        }

        private void Reset()
        {
            if (resetButton != null) resetButton.clicked -= OnClickResetButton;
            if (captureButton != null) captureButton.clicked -= OnClickCaptureButton;
            if (pasteButton != null) pasteButton.clicked -= OnClickPasteButton;

            // 変数のリセット
            isCaptured = false;
            selectedClipNameToCapture = "";
            selectedClipNameToPaste = "";
            captureTargetBlendCurveSlot = BlendCurveSlot.MixInCurve;
            pasteTargetBlendCurveSlot = BlendCurveSlot.MixInCurve;

            // Curve EditとPaste Settingsを非活性にする
            SetUIActiveByCapture(isCaptured);
        }

        private void InitializeUI()
        {
            SetVisualElementEnabled(selectedClipTextField, false);
            SetVisualElementEnabled(clipToPasteTextField, false);
            resetButton.clicked += OnClickResetButton;
            selectedClipTextField.SetValueWithoutNotify(selectedClipNameToCapture);
            captureTargetRadioButtonGroup.SetValueWithoutNotify((int)pasteTargetBlendCurveSlot);
            captureTargetRadioButtonGroup.RegisterValueChangedCallback(e => OnChangeTargetRadioButton(
                    (BlendCurveSlot)e.newValue,
                    out captureTargetBlendCurveSlot
                )
            );
            captureButton.clicked += OnClickCaptureButton;
            workingCurveField.value = null;
            clipToPasteTextField.SetValueWithoutNotify(selectedClipNameToCapture);
            pasteTargetRadioButtonGroup.SetValueWithoutNotify((int)pasteTargetBlendCurveSlot);
            pasteTargetRadioButtonGroup.RegisterValueChangedCallback(e => OnChangeTargetRadioButton(
                    (BlendCurveSlot)e.newValue,
                    out pasteTargetBlendCurveSlot
                )
            );
            pasteButton.clicked += OnClickPasteButton;
        }

        void OnChangeTargetRadioButton(BlendCurveSlot selectedBlendCurveSlot, out BlendCurveSlot targetBlendCurveSlot)
            => targetBlendCurveSlot = selectedBlendCurveSlot;

        private void OnClickResetButton()
        {
            // リセット
            Reset();
            // UIに初期値を設定
            InitializeUI();
        }

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
            workingCurveField.value = null;

            // 選択しているクリック名を表示
            SetClipName(selectedClipTextField, selectedClip.displayName);

            // CurveFieldにカーブを表示
            SetClipBlendCurveField(workingCurveField, selectedClip, captureTargetBlendCurveSlot);

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
            PasteClipBlendCurve(workingCurveField, ref selectedClip, pasteTargetBlendCurveSlot);

            // ブランディングしているカーブがあれば、Manual -> Autoにする
            var clipDir = pasteTargetBlendCurveSlot == BlendCurveSlot.MixInCurve ? ClipDirection.Prev : ClipDirection.Next;
            var adjacentClip = FindClipByBlendingCurve(selectedClip, clipDir);
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

        private void SetClipBlendCurveField(CurveField curveField, TimelineClip clip, BlendCurveSlot blendCurveSlot)
        {
            if (clip == null) return;
            if (blendCurveSlot == BlendCurveSlot.MixInCurve)
                curveField.value = clip.mixInCurve != null ? new AnimationCurve(clip.mixInCurve.keys) : null;
            else
                curveField.value = clip.mixOutCurve != null ? new AnimationCurve(clip.mixOutCurve.keys) : null;
        }

        private void PasteClipBlendCurve(CurveField curveField, ref TimelineClip clip, BlendCurveSlot blendCurveSlot)
        {
            if (curveField?.value == null) return;
            if (clip == null) return;
            var track = clip.GetParentTrack();
            if (track == null) return;

            var clipAsset = clip.asset as UnityEngine.Object;
            Undo.IncrementCurrentGroup();
            int undoGroup = Undo.GetCurrentGroup();
            Undo.SetCurrentGroupName("Paste Timeline Blend Curve");

            Undo.RegisterCompleteObjectUndo(track, "Paste Timeline Blend Curve");
            if (clipAsset != null)
                Undo.RecordObject(clipAsset, "Paste Timeline Blend Curve");

            // Paste
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

            Undo.CollapseUndoOperations(undoGroup);
        }

        /// <summary>
        /// CaptureボタンのクリックによってOn/OffされるUIの制御メソッド
        /// </summary>
        private void SetUIActiveByCapture(bool active)
        {
            // Capture前
            SetVisualElementEnabled(captureSettings, !active);
            // Capture後
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

        private static TimelineClip FindClipByBlendingCurve(TimelineClip clip, ClipDirection clipDirection)
        {
            var track = clip.GetParentTrack();
            if (track == null) return null;

            if (clipDirection == ClipDirection.Prev)
            {
                if (!clip.hasBlendIn || clip.blendInDuration <= 0.0) return null;
            }
            else
            {
                if (!clip.hasBlendOut || clip.blendOutDuration <= 0.0) return null;
            }

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