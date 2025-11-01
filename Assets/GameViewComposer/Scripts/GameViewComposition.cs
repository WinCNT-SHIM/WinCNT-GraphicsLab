using UnityEngine;
using UnityEngine.UI;
using GameViewCompositionType = WinCNT.GraphicsLab.GameViewComposer.GameViewCompositionType;

namespace WinCNT.GraphicsLab
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Image))]
    public class GameViewComposition : MonoBehaviour
    {
        public GameViewCompositionType gameViewCompositionType;
        private Image compositionImage;

        public void Activate(bool active) => compositionImage.enabled = active;

        private void OnEnable()
        {
            compositionImage = GetComponent<Image>();
        }

        public void SetColor(Color color)
        {
            compositionImage.color = color;

#if UNITY_EDITOR
            UnityEditor.EditorApplication.QueuePlayerLoopUpdate();
            UnityEditor.SceneView.RepaintAll();
#endif
        }

        public void SetRotation(Quaternion rotation)
        {
            compositionImage.transform.rotation = rotation;
        }
    }
}