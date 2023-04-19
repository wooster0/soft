//! The graphics pipeline.
//!
//! The order is as follows:
//! * Input assembler (fixed-function):   take in vertex/index buffer
//! * Vertex shader (programmable):       process every vertex
//! * Tessellation shader (programmable): subdivide geometry
//! * Geometry shader (programmable):     subdivide geometry
//! * Rasterization (fixed-function):     makes vertices into pixels
//! * Fragment shader (programmable):     applies color
//! * Color blending (fixed-function):    mix color
//!
//! The final result of all these stages goes to the framebuffer.

const std = @import("std");
const mem = std.mem;
const math = std.math;
const builtin = @import("builtin");

const c = @import("c.zig");

const GraphicsPipeline = @This();

pipeline: c.VkPipeline,
pipeline_layout: c.VkPipelineLayout,
render_pass: c.VkRenderPass,

pub fn init(logical_device: c.VkDevice, swap_chain_extent: c.VkExtent2D, swap_chain_image_format: c.VkFormat) GraphicsPipeline {
    //
    // programmable shaders
    //

    const vertex_shader_source = @embedFile("vertex_shader.vert");
    var aligned_vertex_shader_source: [vertex_shader_source.len]u8 align(4) = vertex_shader_source.*;
    const vertex_shader_module = createShaderModule(logical_device, &aligned_vertex_shader_source);
    defer c.vkDestroyShaderModule(logical_device, vertex_shader_module, null);
    const vertex_shader_stage_info = mem.zeroInit(c.VkPipelineShaderStageCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vertex_shader_module,
        .pName = "main", // the entry point
    });

    const fragment_shader_source = @embedFile("fragment_shader.frag");
    var aligned_fragment_shader_source: [fragment_shader_source.len]u8 align(4) = fragment_shader_source.*;
    const fragment_shader_module = createShaderModule(logical_device, &aligned_fragment_shader_source);
    defer c.vkDestroyShaderModule(logical_device, fragment_shader_module, null);
    const fragment_shader_stage_info = mem.zeroInit(c.VkPipelineShaderStageCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = fragment_shader_module,
        .pName = "main", // the entry point
    });

    const shader_stages = [_]c.VkPipelineShaderStageCreateInfo{ vertex_shader_stage_info, fragment_shader_stage_info };

    //
    // fixed-function stages
    //

    const vertex_input_state = mem.zeroInit(c.VkPipelineVertexInputStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .vertexBindingDescriptionCount = 0,
        .pVertexBindingDescriptions = null,
        .vertexAttributeDescriptionCount = 0,
        .pVertexAttributeDescriptions = null,
    });

    const input_assembly_state = mem.zeroInit(c.VkPipelineInputAssemblyStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
    });

    const dynamic_states = [_]c.VkDynamicState{
        c.VK_DYNAMIC_STATE_VIEWPORT,
        c.VK_DYNAMIC_STATE_SCISSOR,
    };

    const dynamic_state = mem.zeroInit(c.VkPipelineDynamicStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = dynamic_states.len,
        .pDynamicStates = &dynamic_states,
    });

    const viewport = c.VkViewport{
        .x = 0.0,
        .y = 0.0,
        .width = @intToFloat(f32, swap_chain_extent.width),
        .height = @intToFloat(f32, swap_chain_extent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };
    const scissor = c.VkRect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = swap_chain_extent,
    };
    const viewport_state = mem.zeroInit(c.VkPipelineViewportStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor,
    });

    const rasterizer_state = mem.zeroInit(c.VkPipelineRasterizationStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0,
        .cullMode = c.VK_CULL_MODE_BACK_BIT, // TODO: c.VK_CULL_MODE_NONE, // no face culling
        .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,
    });

    const multisample_state = mem.zeroInit(c.VkPipelineMultisampleStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .sampleShadingEnable = c.VK_FALSE,
        .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
    });

    const color_blend_attachment = mem.zeroInit(c.VkPipelineColorBlendAttachmentState, .{
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT |
            c.VK_COLOR_COMPONENT_G_BIT |
            c.VK_COLOR_COMPONENT_B_BIT |
            c.VK_COLOR_COMPONENT_A_BIT,
        .blendEnable = c.VK_FALSE,
    });

    // TODO: for reference, this is how you can implement color blending in Wool:
    // if (blendEnable) {
    //     finalColor.rgb = (srcColorBlendFactor * newColor.rgb) <colorBlendOp> (dstColorBlendFactor * oldColor.rgb);
    //     finalColor.a = (srcAlphaBlendFactor * newColor.a) <alphaBlendOp> (dstAlphaBlendFactor * oldColor.a);
    // } else {
    //     finalColor = newColor;
    // }
    // finalColor = finalColor & colorWriteMask;
    // TODO: and this for alpha (blending):
    // finalColor.rgb = newAlpha * newColor + (1 - newAlpha) * oldColor;
    // finalColor.a = newAlpha.a;

    const color_blend_state = mem.zeroInit(c.VkPipelineColorBlendStateCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &color_blend_attachment,
        .blendConstants = [_]f32{ 0, 0, 0, 0 },
    });

    const layout_create_info = mem.zeroInit(c.VkPipelineLayoutCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 0,
        .pSetLayouts = null,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
    });

    var pipeline_layout: c.VkPipelineLayout = undefined;
    if (c.vkCreatePipelineLayout(logical_device, &layout_create_info, null, &pipeline_layout) != c.VK_SUCCESS)
        @panic("failed creating Vulkan pipeline layout");

    std.debug.print("hello!\n", .{});
    const render_pass = createRenderPass(logical_device, swap_chain_image_format);
    std.debug.print("hello!\n", .{});

    var pipeline_info = mem.zeroInit(c.VkGraphicsPipelineCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2,
        .pStages = &shader_stages,
        .pVertexInputState = &vertex_input_state,
        .pInputAssemblyState = &input_assembly_state,
        .pViewportState = &viewport_state,
        .pRasterizationState = &rasterizer_state,
        .pMultisampleState = &multisample_state,
        .pColorBlendState = &color_blend_state,
        .pDynamicState = &dynamic_state,
        .layout = pipeline_layout,
        .renderPass = render_pass,
        .subpass = 0,
        // TODO: try removing the following two ONLY if not a segfault
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    });

    // TODO: https://vulkan-tutorial.com/en/Drawing_a_triangle/Graphics_pipeline_basics/Conclusion

    std.debug.print("hello!\n", .{});

    // std.debug.print("{any}\n",.{swap_chain_extent});

    var graphics_pipeline: c.VkPipeline = undefined;
    if (c.vkCreateGraphicsPipelines(logical_device, null, 1, &pipeline_info, null, &graphics_pipeline) != c.VK_SUCCESS)
        @panic("failed creating Vulkan graphics pipeline");
    std.debug.print("hello!\n", .{});

    return .{
        .pipeline = graphics_pipeline,
        .pipeline_layout = pipeline_layout,
        .render_pass = render_pass,
    };
}

fn deinit(graphics_pipeline: GraphicsPipeline, logical_device: c.VkDevice) void {
    c.vkDestroyPipeline(logical_device, graphics_pipeline.pipeline, null);
    c.vkDestroyPipelineLayout(logical_device, graphics_pipeline.pipeline_layout, null);
    c.vkDestroyRenderPass(logical_device, graphics_pipeline.render_pass, null);
}

fn createShaderModule(physical_device: c.VkDevice, bytes: []align(4) const u8) c.VkShaderModule {
    var create_info = mem.zeroInit(c.VkShaderModuleCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = bytes.len,
        .pCode = @ptrCast([*c]const u32, bytes),
    });
    var shader_module: c.VkShaderModule = undefined;
    if (c.vkCreateShaderModule(physical_device, &create_info, null, &shader_module) != c.VK_SUCCESS)
        @panic("failed creating Vulkan shader module");
    return shader_module;
}

fn createRenderPass(logical_device: c.VkDevice, swap_chain_image_format: c.VkFormat) c.VkRenderPass {
    const color_attachment = mem.zeroInit(c.VkAttachmentDescription, .{
        .format = swap_chain_image_format,
        .samples = c.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    });

    const color_attachment_ref = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };

    const subpass = mem.zeroInit(c.VkSubpassDescription, .{
        .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_attachment_ref,
    });

    const create_info = mem.zeroInit(c.VkRenderPassCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1,
        .pAttachments = &color_attachment,
        .subpassCount = 1,
        .pSubpasses = &subpass,
    });
    var render_pass: c.VkRenderPass = undefined;
    if (c.vkCreateRenderPass(logical_device, &create_info, null, &render_pass) != c.VK_SUCCESS)
        @panic("failed to create render pass!");
    return render_pass;
}
