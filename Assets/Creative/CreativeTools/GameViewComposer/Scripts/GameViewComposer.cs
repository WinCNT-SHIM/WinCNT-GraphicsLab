using System.Collections.Generic;
using UnityEngine;

namespace WinCNT.GraphicsLab
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Canvas))]
    public class GameViewComposer : MonoBehaviour
    {
        public enum GameViewCompositionType
        {
            RuleOfThirds,
            Diagonal,
            GoldenRatio,
            GoldenSpiral,
        }

        private Dictionary<GameViewCompositionType, GameViewComposition> gameViewCompositions = new();

        private void OnEnable()
        {
            gameViewCompositions.Clear();

            var compositions = GetComponentsInChildren<GameViewComposition>(true);
            foreach (var comp in compositions)
            {
                var type = comp.gameViewCompositionType;
                if (!gameViewCompositions.TryAdd(type, comp))
                    Debug.LogWarning($"Duplicate GameViewCompositionType detected: {type} ({comp.name})", comp);
            }
        }

        public void OnToggleComposition(GameViewCompositionType compositionType, bool active) =>
            GetGameViewComposition(compositionType).Activate(active);

        public void OnRotateComposition(GameViewCompositionType compositionType, Quaternion rotation) =>
            GetGameViewComposition(compositionType).SetRotation(GetGameViewComposition(compositionType).transform.rotation * rotation);

        public void OnChangeCompositionsColor(Color color) =>
            GetAllGameViewCompositions().ForEach(e => e.SetColor(color));

        private GameViewComposition GetGameViewComposition(GameViewCompositionType type) =>
            gameViewCompositions.GetValueOrDefault(type);

        private List<GameViewComposition> GetAllGameViewCompositions() => new(gameViewCompositions.Values);

#if UNITY_EDITOR
        private void OnValidate()
        {
            if (!Application.isPlaying) OnEnable();
        }
#endif
    }
}