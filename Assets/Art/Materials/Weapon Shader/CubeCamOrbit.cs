using UnityEngine;

public class CubeCamOrbit : MonoBehaviour
{
    [SerializeField] private Transform center;
    [SerializeField] private float rotationSpeed = 30f;
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetMouseButton(0))
        {
            transform.RotateAround(center.position, Vector3.up, rotationSpeed * Time.deltaTime);
        }
        if (Input.GetMouseButton(1))
        {
            transform.RotateAround(center.position, Vector3.up, -rotationSpeed * Time.deltaTime);
        }
    }
}
