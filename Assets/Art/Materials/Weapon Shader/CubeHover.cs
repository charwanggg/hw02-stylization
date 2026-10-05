using UnityEngine;

public class CubeHover : MonoBehaviour
{
    private static readonly int ManualOffsetId = Shader.PropertyToID("_ManualOffset");
    private const int EnchantmentMaterialIndex = 1;

    [SerializeField] private float height;
    [SerializeField] private float interval;
    float randomOffset;
    Vector3 initialPosition;
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        randomOffset = Random.Range(0f, 2f * Mathf.PI);
        initialPosition = transform.position;

        Renderer cubeRenderer = GetComponent<Renderer>();
        MaterialPropertyBlock properties = new MaterialPropertyBlock();
        cubeRenderer.GetPropertyBlock(properties, EnchantmentMaterialIndex);
        Vector2 manualOffset = new Vector2(Random.value, Random.value);
        properties.SetVector(ManualOffsetId, new Vector4(manualOffset.x, manualOffset.y, 0f, 0f));
        cubeRenderer.SetPropertyBlock(properties, EnchantmentMaterialIndex);
    }

    // Update is called once per frame
    void Update()
    {
        transform.position = new Vector3(initialPosition.x, initialPosition.y + Mathf.Sin(Time.time / interval + randomOffset) * height, initialPosition.z);
    }
}
