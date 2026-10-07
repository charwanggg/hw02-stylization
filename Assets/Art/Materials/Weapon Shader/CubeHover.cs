using System.Collections;
using UnityEngine;

public class CubeHover : MonoBehaviour
{
    private static readonly int ManualOffsetId = Shader.PropertyToID("_ManualOffset");
    private const int EnchantmentMaterialIndex = 1;

    public static float height = 0.03f;
    public static float interval = 2f;
    [SerializeField] private float orbitHeight;
    [SerializeField] private float orbitRadius;
    [SerializeField] private float orbitOffset;
    [SerializeField] private float orbitSpeed;
    [SerializeField] private float spinSpeed = 120f;
    [SerializeField] private float rotationTransitionDuration = 0.5f;
    [SerializeField] private float positionReturnDuration = 0.5f;
    float randomOffset;
    float spinAngle;
    Vector3 initialPosition;
    Vector3 parentPos;
    Quaternion initialRotation;
    Coroutine rotationTransition;
    Coroutine positionTransition;
    bool wasParty;
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        randomOffset = Random.Range(0f, 2f * Mathf.PI);
        initialPosition = transform.position;
        initialRotation = transform.rotation;
        parentPos = transform.parent != null ? transform.parent.position : Vector3.zero;
        spinAngle = orbitOffset;

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
        if (InteractiveManager.isParty != wasParty)
        {
            wasParty = InteractiveManager.isParty;
            if (rotationTransition != null)
                StopCoroutine(rotationTransition);
            rotationTransition = StartCoroutine(TransitionRotation(wasParty));

            if (positionTransition != null)
                StopCoroutine(positionTransition);
            positionTransition = wasParty ? null : StartCoroutine(ReturnToNonPartyPosition());
        }

        if (positionTransition == null)
        {
            float orbitAngle = Time.time * orbitSpeed + orbitOffset;
            Vector3 party = new Vector3(
                parentPos.x + Mathf.Cos(Mathf.Deg2Rad * orbitAngle) * orbitRadius,
                parentPos.y + orbitHeight,
                parentPos.z + Mathf.Sin(Mathf.Deg2Rad * orbitAngle) * orbitRadius);
            Vector3 destination = wasParty ? party : GetNonPartyPosition();
            transform.position = Vector3.Lerp(transform.position, destination, Time.deltaTime);
        }

        if (wasParty && rotationTransition == null)
        {
            spinAngle = Mathf.Repeat(spinAngle + spinSpeed * Time.deltaTime, 360f);
            Quaternion tipUp = Quaternion.FromToRotation(Vector3.one, Vector3.up);
            transform.rotation = Quaternion.AngleAxis(spinAngle, Vector3.up) * tipUp;
        }
    }

    Vector3 GetNonPartyPosition()
    {
        return new Vector3(initialPosition.x, initialPosition.y + Mathf.Sin(Time.time / interval + randomOffset) * height, initialPosition.z);
    }

    IEnumerator ReturnToNonPartyPosition()
    {
        Vector3 startPosition = transform.position;
        float duration = Mathf.Max(0.01f, positionReturnDuration);
        float elapsed = 0f;

        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            float progress = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(elapsed / duration));
            transform.position = Vector3.Lerp(startPosition, GetNonPartyPosition(), progress);
            yield return null;
        }

        transform.position = GetNonPartyPosition();
        positionTransition = null;
    }

    private IEnumerator TransitionRotation(bool toParty)
    {
        Quaternion startRotation = transform.rotation;
        Quaternion tipUp = Quaternion.FromToRotation(Vector3.one, Vector3.up);
        Quaternion targetRotation = toParty
            ? Quaternion.AngleAxis(spinAngle, Vector3.up) * tipUp
            : initialRotation;
        float duration = Mathf.Max(0.01f, rotationTransitionDuration);
        float elapsed = 0f;

        while (elapsed < duration)
        {
            elapsed += Time.deltaTime;
            float t = Mathf.Clamp01(elapsed / duration);
            t = 1 - (1 - t) * (1 - t);
            float progress = Mathf.SmoothStep(0f, 1f, t);
            transform.rotation = Quaternion.Slerp(startRotation, targetRotation, progress);
            yield return null;
        }

        transform.rotation = targetRotation;
        rotationTransition = null;
    }

    void OnDisable()
    {
        if (rotationTransition != null)
            StopCoroutine(rotationTransition);
        rotationTransition = null;
        if (positionTransition != null)
            StopCoroutine(positionTransition);
        positionTransition = null;
        wasParty = !InteractiveManager.isParty;
    }
}
