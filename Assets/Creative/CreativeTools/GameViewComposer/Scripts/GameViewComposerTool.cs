using UnityEditor;
using UnityEditor.UIElements;
using UnityEngine;
using UnityEngine.UIElements;
using GameViewCompositionType = WinCNT.GraphicsLab.GameViewComposer.GameViewCompositionType;

namespace WinCNT.GraphicsLab
{
    public class GameViewComposerTool : EditorWindow
    {
        [SerializeField] private GameViewComposer gameViewComposerAsset;
        [SerializeField] private VisualTreeAsset m_VisualTreeAsset = default;

        private GameViewComposer gameViewComposer;

        [MenuItem("Tool/GameViewComposerTool")]
        public static void ShowExample()
        {
            GameViewComposerTool wnd = GetWindow<GameViewComposerTool>();
            wnd.titleContent = new GUIContent("GameViewComposerTool");
        }

        private void OnDisable()
        {
            if (gameViewComposer)
                DestroyImmediate(gameViewComposer.gameObject);
        }

        public void CreateGUI()
        {
            // Each editor window contains a root VisualElement object
            var root = rootVisualElement;

            // Instantiate UXML
            var labelFromUXML = m_VisualTreeAsset.Instantiate();
            root.Add(labelFromUXML);

            if (gameViewComposerAsset == null)
            {
                var label = new Label("No GameViewComposer prefab selected!");
                root.Add(label);
                return;
            }

            if (gameViewComposer)
                DestroyImmediate(gameViewComposer.gameObject);
            gameViewComposer = Instantiate(gameViewComposerAsset);
            // var prefabInstantiate = PrefabUtility.InstantiatePrefab(gameViewComposerAsset.gameObject) as GameObject;
            // gameViewComposer = prefabInstantiate?.GetComponent<GameViewComposer>();

            var ruleOfThirdsToggle = root.Q<Toggle>("RuleOfThirdsToggle");
            var crossToggle = root.Q<Toggle>("CrossToggle");
            var diagonalToggle = root.Q<Toggle>("DiagonalToggle");
            var goldenRatioToggle = root.Q<Toggle>("GoldenRatioToggle");
            var goldenSpiralToggle = root.Q<Toggle>("GoldenSpiralToggle");

            ruleOfThirdsToggle.RegisterValueChangedCallback(evt =>
                OnToggleComposition(evt, GameViewCompositionType.RuleOfThirds)
            );
            crossToggle.RegisterValueChangedCallback(evt =>
                OnToggleComposition(evt, GameViewCompositionType.Cross)
            );
            diagonalToggle.RegisterValueChangedCallback(evt =>
                OnToggleComposition(evt, GameViewCompositionType.Diagonal)
            );
            goldenRatioToggle.RegisterValueChangedCallback(evt =>
                OnToggleComposition(evt, GameViewCompositionType.GoldenRatio)
            );
            goldenSpiralToggle.RegisterValueChangedCallback(evt =>
                OnToggleComposition(evt, GameViewCompositionType.GoldenSpiral)
            );

            var buttonIcon = EditorGUIUtility.IconContent("d_Refresh").image as Texture2D;
            var rotateLeftGoldenSpiralButton = root.Q<Button>("RotateLeftGoldenSpiralButton");
            rotateLeftGoldenSpiralButton.style.backgroundImage = new StyleBackground(buttonIcon);
            rotateLeftGoldenSpiralButton.style.rotate = new Rotate(90);
            rotateLeftGoldenSpiralButton.clicked
                += () => OnRotateCompositionButton(GameViewCompositionType.GoldenSpiral, Quaternion.Euler(0, 180, 0));
            var rotateRightGoldenSpiralButton = root.Q<Button>("RotateRightGoldenSpiralButton");
            rotateRightGoldenSpiralButton.style.backgroundImage = new StyleBackground(buttonIcon);
            rotateRightGoldenSpiralButton.clicked += () => OnRotateCompositionButton(
                GameViewCompositionType.GoldenSpiral,
                Quaternion.Euler(180, 0, 0)
            );

            var compositionsColorField = root.Q<ColorField>("CompositionsColorField");
            compositionsColorField.RegisterValueChangedCallback(OnChangeCompositionsColor);
        }

        private void OnToggleComposition(ChangeEvent<bool> evt, GameViewCompositionType compositionType) =>
            gameViewComposer.OnToggleComposition(compositionType, evt.newValue);

        private void OnRotateCompositionButton(GameViewCompositionType compositionType, Quaternion rotation) =>
            gameViewComposer.OnRotateComposition(compositionType, rotation);

        private void OnChangeCompositionsColor(ChangeEvent<Color> evt) =>
            gameViewComposer.OnChangeCompositionsColor(evt.newValue);
    }
}