using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;

public class InteractiveManager : MonoBehaviour
{
    private static readonly int VignetteId = Shader.PropertyToID("_Vignette");
    public static bool isParty;
    [SerializeField] private GameObject[] cubes;
    [SerializeField] private Light plight;
    [SerializeField] private MeshRenderer centerMesh;
    [SerializeField] private PerObjectOutlineColor perObjectOutlineColor;
    [SerializeField] private HypostasisMaterialSetUp[] hypostasisMaterialSetUp;
    [SerializeField] private GameObject threeHypostasisContainer;
    [SerializeField] private GameObject singleHypostasis;
    [SerializeField] private Material fullScreen;
    private int currInd;
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        threeHypostasisContainer.SetActive(false);
        singleHypostasis.SetActive(true);
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyDown(KeyCode.V))
        {
            float vignette = fullScreen.GetFloat(VignetteId);
            fullScreen.SetFloat(VignetteId, vignette > 0.5f ? 0f : 1f);
        }
        if (Input.GetKeyDown(KeyCode.P))
        {
            isParty = !isParty;
            CubeHover.height = isParty ? 0.1f : 0.03f;
            CubeHover.interval = isParty ? 1f : 0.5f;
        }
        if (Input.GetKeyDown(KeyCode.Space))
        {
            currInd = (currInd + 1) % 4;
            if (currInd == 3)
            {
                threeHypostasisContainer.SetActive(true);
                singleHypostasis.SetActive(false);
            }
            else
            {
                singleHypostasis.SetActive(true);
                threeHypostasisContainer.SetActive(false);
                HypostasisMaterialSetUp setup = hypostasisMaterialSetUp[currInd];
                foreach (GameObject cube in cubes)
                {
                    Renderer renderer = cube.GetComponent<Renderer>();
                    if (renderer != null)
                    {
                        renderer.materials = setup.materials;
                    }
                }
                plight.color = setup.lightColor;
                perObjectOutlineColor.SetOutlineColor(setup.outlineColor);
                centerMesh.material = hypostasisMaterialSetUp[currInd].EmssiveCenter;
            }
        }
    }
}


[System.Serializable]
public struct HypostasisMaterialSetUp
{
    public Material[] materials;
    public Material EmssiveCenter;
    public Color outlineColor;
    public Color lightColor;
}
