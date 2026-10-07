using UnityEngine;

// Add this to an outlined object (or its parent) to color all child renderers.
[ExecuteAlways]
public sealed class PerObjectOutlineColor : MonoBehaviour
{
    private static readonly int OutlineColorId = Shader.PropertyToID("_OutlineColor");

    [ColorUsage(true, true)]
    [SerializeField] private Color outlineColor = new(0.91116875f, 0.047169685f, 1f, 1f);

    public Color OutlineColor
    {
        get => outlineColor;
        set
        {
            outlineColor = value;
            Apply();
        }
    }

    public void SetOutlineColor(Color color)
    {
        OutlineColor = color;
    }

    private void OnEnable() => Apply();

    private void OnValidate() => Apply();

    private void OnTransformChildrenChanged() => Apply();

    public void Apply()
    {
        var block = new MaterialPropertyBlock();

        foreach (Renderer target in GetComponentsInChildren<Renderer>(true))
        {
            target.GetPropertyBlock(block);
            block.SetColor(OutlineColorId, outlineColor);
            target.SetPropertyBlock(block);
            block.Clear();
        }
    }
}
