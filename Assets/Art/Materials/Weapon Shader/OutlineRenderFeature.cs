using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

public class OutlineRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public Material maskMaterial;

        // Rendering Layer 1 = bit 1
        public uint renderingLayerMask = 1u << 1;
    }

    public Settings settings = new();

    private OutlineMaskPass maskPass;

    public override void Create()
    {
        maskPass = new OutlineMaskPass(settings);

        maskPass.renderPassEvent =
            RenderPassEvent.AfterRenderingOpaques;
    }

    public override void AddRenderPasses(
        ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        renderer.EnqueuePass(maskPass);
    }

    private class OutlineMaskPass : ScriptableRenderPass
    {
        private Settings settings;

        private static readonly int OutlineMaskID =
            Shader.PropertyToID("_OutlineMaskTexture");

        public OutlineMaskPass(Settings settings)
        {
            this.settings = settings;
        }

        private class PassData
        {
            public RendererListHandle rendererList;
        }

        public override void RecordRenderGraph(
            RenderGraph renderGraph,
            ContextContainer frameData)
        {
            UniversalRenderingData renderingData =
                frameData.Get<UniversalRenderingData>();

            UniversalCameraData cameraData =
                frameData.Get<UniversalCameraData>();

            UniversalLightData lightData =
                frameData.Get<UniversalLightData>();

            // Create our mask texture.
            RenderTextureDescriptor descriptor =
                cameraData.cameraTargetDescriptor;

            descriptor.depthBufferBits = 0;
            descriptor.msaaSamples = 1;
            descriptor.graphicsFormat =
                UnityEngine.Experimental.Rendering.GraphicsFormat.R8G8B8A8_UNorm;

            TextureHandle maskTexture =
                UniversalRenderer.CreateRenderGraphTexture(
                    renderGraph,
                    descriptor,
                    "_OutlineMaskTexture",
                    true);

            // Resolve overlapping outlined renderers by depth so the visible
            // surface supplies the outline color.
            TextureDesc depthDescriptor = renderGraph.GetTextureDesc(maskTexture);
            depthDescriptor.format =
                UnityEngine.Experimental.Rendering.GraphicsFormatUtility.GetDepthStencilFormat(24);
            depthDescriptor.name = "_OutlineMaskDepth";
            depthDescriptor.clearBuffer = true;
            TextureHandle maskDepth = renderGraph.CreateTexture(depthDescriptor);

            // Which shader passes we're willing to render.
            List<ShaderTagId> shaderTags = new()
            {
                new ShaderTagId("UniversalForward"),
                new ShaderTagId("UniversalForwardOnly"),
                new ShaderTagId("SRPDefaultUnlit")
            };

            // Draw normal opaque objects...
            DrawingSettings drawingSettings =
                RenderingUtils.CreateDrawingSettings(
                    shaderTags,
                    renderingData,
                    cameraData,
                    lightData,
                    SortingCriteria.CommonOpaque);

            // ...but replace their material with the per-renderer outline color material.
            drawingSettings.overrideMaterial =
                settings.maskMaterial;

            // Only include objects whose Renderer has our Rendering Layer.
            FilteringSettings filteringSettings =
                new FilteringSettings(
                    RenderQueueRange.opaque,
                    -1,
                    settings.renderingLayerMask);

            RendererListParams rendererListParams =
                new RendererListParams(
                    renderingData.cullResults,
                    drawingSettings,
                    filteringSettings);

            RendererListHandle rendererList =
                renderGraph.CreateRendererList(
                    rendererListParams);

            using (
                var builder =
                    renderGraph.AddRasterRenderPass<PassData>(
                        "Outline Mask",
                        out var passData))
            {
                passData.rendererList = rendererList;

                builder.UseRendererList(rendererList);

                builder.SetRenderAttachment(
                    maskTexture,
                    0,
                    AccessFlags.Write);

                builder.SetRenderAttachmentDepth(maskDepth, AccessFlags.Write);

                builder.SetGlobalTextureAfterPass(
                    maskTexture,
                    OutlineMaskID);

                builder.SetRenderFunc(
                    static (PassData data, RasterGraphContext context) =>
                    {
                        context.cmd.DrawRendererList(
                            data.rendererList);
                    });
            }

            // Subsequent shaders can sample TEXTURE2D(_OutlineMaskTexture).
        }
    }
}
