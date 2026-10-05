using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

public class FinalBloomRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class BloomSettings
    {
        [Range(0f, 10f)]
        public float threshold = 1f;

        [Range(0f, 10f)]
        public float intensity = 1f;

        [Range(0.25f, 5f)]
        public float blur = 1f;

        [ColorUsage(false, false)]
        public Color tint = Color.white;
    }

    [SerializeField]
    private Shader bloomShader;

    [SerializeField]
    private BloomSettings settings = new();

    private Material material;
    private FinalBloomPass bloomPass;


    public override void Create()
    {
        if (bloomShader == null)
            return;

        material = CoreUtils.CreateEngineMaterial(bloomShader);

        bloomPass = new FinalBloomPass(
            material,
            settings
        );

        bloomPass.renderPassEvent =
            RenderPassEvent.AfterRenderingPostProcessing;
    }


    public override void AddRenderPasses(
        ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (bloomPass == null)
            return;

        // Game cameras only
        if (renderingData.cameraData.cameraType != CameraType.Game)
            return;

        // THE IMPORTANT PART:
        // only execute after the final camera in the stack.
        if (!renderingData.cameraData.resolveFinalTarget)
            return;

        renderer.EnqueuePass(bloomPass);
    }


    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(material);
    }


    private class FinalBloomPass : ScriptableRenderPass
    {
        private readonly Material material;
        private readonly BloomSettings settings;

        private static readonly int ThresholdID =
            Shader.PropertyToID("_Threshold");

        private static readonly int IntensityID =
            Shader.PropertyToID("_Intensity");

        private static readonly int BlurID =
            Shader.PropertyToID("_Blur");
        
        private static readonly int TintID =
        Shader.PropertyToID("_Tint");

        public FinalBloomPass(
            Material material,
            BloomSettings settings)
        {
            this.material = material;
            this.settings = settings;

            // Ask URP for camera color.
            ConfigureInput(ScriptableRenderPassInput.Color);
        }


        public override void RecordRenderGraph(
            RenderGraph renderGraph,
            ContextContainer frameData)
        {
            UniversalResourceData resourceData =
                frameData.Get<UniversalResourceData>();

            UniversalCameraData cameraData =
                frameData.Get<UniversalCameraData>();


            // We need a readable intermediate color texture.
            if (resourceData.isActiveTargetBackBuffer)
                return;


            TextureHandle source =
                resourceData.activeColorTexture;


            if (!source.IsValid())
                return;


            material.SetFloat(
                ThresholdID,
                settings.threshold
            );

            material.SetFloat(
                IntensityID,
                settings.intensity
            );

            material.SetFloat(
                BlurID,
                settings.blur
            );

            material.SetColor(TintID, settings.tint);


            // ---------------------------------
            // Create half-resolution bloom RTs
            // ---------------------------------

            RenderTextureDescriptor desc =
                cameraData.cameraTargetDescriptor;

            desc.depthBufferBits = 0;

            desc.width =
                Mathf.Max(1, desc.width / 2);

            desc.height =
                Mathf.Max(1, desc.height / 2);


            TextureHandle bright =
                UniversalRenderer.CreateRenderGraphTexture(
                    renderGraph,
                    desc,
                    "_FinalBloomBright",
                    false,
                    FilterMode.Bilinear
                );


            TextureHandle blurTemp =
                UniversalRenderer.CreateRenderGraphTexture(
                    renderGraph,
                    desc,
                    "_FinalBloomTemp",
                    false,
                    FilterMode.Bilinear
                );


            TextureHandle blurred =
                UniversalRenderer.CreateRenderGraphTexture(
                    renderGraph,
                    desc,
                    "_FinalBloomBlurred",
                    false,
                    FilterMode.Bilinear
                );


            // ---------------------------------
            // PASS 0
            // Bright pixels only
            // ---------------------------------

            RenderGraphUtils.BlitMaterialParameters threshold =
                new(
                    source,
                    bright,
                    material,
                    0
                );

            renderGraph.AddBlitPass(
                threshold,
                "Final Bloom - Threshold"
            );


            // ---------------------------------
            // PASS 1
            // Vertical blur
            // ---------------------------------

            RenderGraphUtils.BlitMaterialParameters vertical =
                new(
                    bright,
                    blurTemp,
                    material,
                    1
                );

            renderGraph.AddBlitPass(
                vertical,
                "Final Bloom - Vertical"
            );


            // ---------------------------------
            // PASS 2
            // Horizontal blur
            // ---------------------------------

            RenderGraphUtils.BlitMaterialParameters horizontal =
                new(
                    blurTemp,
                    blurred,
                    material,
                    2
                );

            renderGraph.AddBlitPass(
                horizontal,
                "Final Bloom - Horizontal"
            );


            // ---------------------------------
            // PASS 3
            // Add bloom back to final image
            // ---------------------------------

            RenderGraphUtils.BlitMaterialParameters composite =
                new(
                    blurred,
                    source,
                    material,
                    3
                );

            renderGraph.AddBlitPass(
                composite,
                "Final Bloom - Composite"
            );
        }
    }
}