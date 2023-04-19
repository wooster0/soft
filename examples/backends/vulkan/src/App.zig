//! The Vulkan application containing all of Vulkan's state.
//!
//! This and GraphicsPipeline.zig and others are heavily inspired by https://vulkan-tutorial.com/

const std = @import("std");
const mem = std.mem;
const math = std.math;
const builtin = @import("builtin");

const GraphicsPipeline = @import("GraphicsPipeline.zig");
const c = @import("c.zig");

const App = @This();

instance: c.VkInstance,
/// This is what we present rendered images to (the window).
surface: c.VkSurfaceKHR,
logical_device: c.VkDevice,
graphics_queue: c.VkQueue,
presentation_queue: c.VkQueue,
swap_chain: c.VkSwapchainKHR,
swap_chain_images: []c.VkImage,
// TODO: probably don't need to store this: remove it
// swap_chain_image_format: c.VkFormat,
// swap_chain_extent: c.VkExtent2D,
image_views: []c.VkImageView,
graphics_pipeline: GraphicsPipeline,

const required_logical_device_extensions = [_][*c]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};

/// Sets up Vulkan state and binds it to the given window.
pub fn init(allocator: mem.Allocator, window: *c.GLFWwindow) !App {
    // whether to use global validation layers:
    // validation layers hook into Vulkan function calls to perform additional checks in order to catch mistakes
    // and print helpful information to the terminal.
    const use_validation_layers = builtin.mode == .Debug and try checkValidationLayerSupport(allocator);

    const instance = try createInstance(use_validation_layers);
    const surface = createSurface(instance, window);
    const suitable_physical_device = try pickSuitablePhysicalDevice(allocator, instance, surface);
    const logical_device_and_queues = try createLogicalDeviceAndQueues(allocator, suitable_physical_device, surface, use_validation_layers);
    const swap_chain = try createSwapChain(allocator, suitable_physical_device, logical_device_and_queues.logical_device, surface, window);
    const image_views = try createImageViews(allocator, logical_device_and_queues.logical_device, swap_chain.image_format, swap_chain.images);
    return .{
        .instance = instance,
        .surface = surface,
        .logical_device = logical_device_and_queues.logical_device,
        .graphics_queue = logical_device_and_queues.graphics_queue,
        .presentation_queue = logical_device_and_queues.presentation_queue,
        .swap_chain = swap_chain.swap_chain,
        .swap_chain_images = swap_chain.images,
        .image_views = image_views,
        .graphics_pipeline = GraphicsPipeline.init(logical_device_and_queues.logical_device, swap_chain.extent, swap_chain.image_format),
    };
}

pub fn deinit(app: App) void {
    c.vkDestroySwapchainKHR(app.logical_device, app.swap_chain, null);
    c.vkDestroyDevice(app.logical_device, null);
    c.vkDestroySurfaceKHR(app.instance, app.surface, null);
    c.vkDestroyInstance(app.instance, null);
}

const VK_LAYER_KHRONOS_validation = "VK_LAYER_KHRONOS_validation";

fn checkValidationLayerSupport(allocator: mem.Allocator) !bool {
    var layer_count: u32 = undefined;
    if (c.vkEnumerateInstanceLayerProperties(&layer_count, null) != c.VK_SUCCESS)
        @panic("failed enumerating Vulkan instance layer properties");

    var available_layers = try allocator.alloc(c.VkLayerProperties, layer_count);
    if (c.vkEnumerateInstanceLayerProperties(&layer_count, available_layers.ptr) != c.VK_SUCCESS)
        @panic("failed enumerating Vulkan instance layer properties");

    for (available_layers) |available_layer|
        if (mem.eql(
            u8,
            available_layer.layerName[0..mem.indexOfScalar(u8, &available_layer.layerName, 0).?],
            mem.span(VK_LAYER_KHRONOS_validation),
        )) return true;

    return false;
}

fn createInstance(use_validation_layers: bool) !c.VkInstance {
    // this includes extensions we need to interface with the window system
    var glfw_extension_count: u32 = undefined;
    const glfw_extensions = c.glfwGetRequiredInstanceExtensions(&glfw_extension_count);

    const create_info = mem.zeroInit(c.VkInstanceCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        // these specify the global extensions
        .enabledExtensionCount = glfw_extension_count,
        .ppEnabledExtensionNames = glfw_extensions,
        .enabledLayerCount = @boolToInt(use_validation_layers),
        .ppEnabledLayerNames = @as(
            [*c]const [*c]const u8,
            if (use_validation_layers) &[_][*c]const u8{VK_LAYER_KHRONOS_validation} else null,
        ),
    });

    // TODO: prevent a possible VK_ERROR_INCOMPATIBLE_DRIVER error on Apple systems
    // TODO: add VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME to the enabled extensions above
    // if (builtin.os.tag.isDarwin()) {
    //     // TODO: do we need isDarwin or is checking only for .macos enough?
    //     // TODO: test if this works with the MoltenVK SDK
    //     instanceCreateInfo.flags |= c.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;
    // }

    var instance: c.VkInstance = undefined;
    if (c.vkCreateInstance(&create_info, null, &instance) != c.VK_SUCCESS)
        @panic("failed creating Vulkan instance");
    return instance;
}

fn createSurface(instance: c.VkInstance, window: *c.GLFWwindow) c.VkSurfaceKHR {
    var surface: c.VkSurfaceKHR = undefined;
    if (c.glfwCreateWindowSurface(instance, window, null, &surface) != c.VK_SUCCESS)
        @panic("failed creating GLFW window surface");
    return surface;
}

fn pickSuitablePhysicalDevice(
    allocator: mem.Allocator,
    instance: c.VkInstance,
    surface: c.VkSurfaceKHR,
) !c.VkPhysicalDevice {
    var physical_device_count: u32 = undefined;
    if (c.vkEnumeratePhysicalDevices(instance, &physical_device_count, null) != c.VK_SUCCESS)
        @panic("failed enumerating Vulkan physical devices");

    if (physical_device_count == 0)
        // return error.NoVulkanPhysicalDevices;
        @panic("no Vulkan physical devices on board");

    const physical_devices = try allocator.alloc(c.VkPhysicalDevice, physical_device_count);
    // defer allocator.free(physical_devices);
    if (c.vkEnumeratePhysicalDevices(instance, &physical_device_count, physical_devices.ptr) != c.VK_SUCCESS)
        @panic("failed enumerating Vulkan physical devices");

    return for (physical_devices) |physical_device| {
        if (try isPhysicalDeviceSuitable(allocator, physical_device, surface))
            break physical_device;
    } else @panic("failed finding a suitable Vulkan physical device");
}

fn isPhysicalDeviceSuitable(
    allocator: mem.Allocator,
    physical_device: c.VkPhysicalDevice,
    surface: c.VkSurfaceKHR,
) !bool {
    const queue_family_indices = try QueueFamilyIndices.findQueueFamilies(allocator, physical_device, surface);
    if (!queue_family_indices.isComplete())
        return false;

    const extensions_supported = try checkPhysicalDeviceExtensionSupport(allocator, physical_device);
    if (!extensions_supported)
        return false;

    const swap_chain_support = try SwapChainSupportDetails.querySwapChainSupport(allocator, physical_device, surface);
    const swap_chain_adequate = swap_chain_support.formats.len != 0 and swap_chain_support.present_modes.len != 0;
    if (!swap_chain_adequate)
        return false;

    return true;
}

fn checkPhysicalDeviceExtensionSupport(allocator: mem.Allocator, physical_device: c.VkPhysicalDevice) !bool {
    var extension_count: u32 = undefined;
    if (c.vkEnumerateDeviceExtensionProperties(physical_device, null, &extension_count, null) != c.VK_SUCCESS)
        @panic("failed enumerating Vulkan device extension properties");

    var extensions = try allocator.alloc(c.VkExtensionProperties, extension_count);
    if (c.vkEnumerateDeviceExtensionProperties(physical_device, null, &extension_count, extensions.ptr) != c.VK_SUCCESS)
        @panic("failed enumerating Vulkan device extension properties");

    const required_extensions = required_logical_device_extensions;

    var extension_checklist = [1]bool{false} ** required_extensions.len;
    for (required_extensions, 0..) |required_extension, index| {
        for (extensions) |extension| {
            if (mem.eql(
                u8,
                extension.extensionName[0..mem.indexOfScalar(u8, &extension.extensionName, 0).?],
                mem.span(required_extension),
            )) {
                extension_checklist[index] = true;
            }
        }
    }
    return @reduce(.And, @as(@Vector(extension_checklist.len, bool), extension_checklist));
}

const QueueFamilyIndices = struct {
    /// Graphics support.
    graphics_family: ?u32,
    /// Presentation support.
    presentation_family: ?u32,

    /// Anything from drawing to uploading textures requires commands to be submitted in a queue.
    /// There are different types of queues that originate from different queue families
    /// and each family of queues allows only a subset of commands.
    /// We need check if the queue families support the commands we need to use.
    fn findQueueFamilies(
        allocator: mem.Allocator,
        physical_device: c.VkPhysicalDevice,
        surface: c.VkSurfaceKHR,
    ) !QueueFamilyIndices {
        var queue_family_count: u32 = undefined;
        c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, null);

        std.debug.print("queue_family_count: {}\n", .{queue_family_count});

        const queue_families = try allocator.alloc(c.VkQueueFamilyProperties, queue_family_count);
        // defer allocator.free(queue_families);
        c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families.ptr);

        var queue_family_indices = QueueFamilyIndices{
            .graphics_family = null,
            .presentation_family = null,
        };

        for (queue_families, 0..) |queue_family, index| {
            // std.debug.print("index: {d} 2: {d}\n", .{index, index2});
            if (queue_family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT == 1)
                queue_family_indices.graphics_family = @intCast(u32, index);

            var presentation_support: c.VkBool32 = undefined;
            if (c.vkGetPhysicalDeviceSurfaceSupportKHR(physical_device, @intCast(u32, index), surface, &presentation_support) != c.VK_SUCCESS)
                @panic("failed getting Vulkan physical device surface support");
            if (presentation_support == 1)
                queue_family_indices.presentation_family = @intCast(u32, index);

            std.debug.print("complete? {}\n", .{queue_family_indices.isComplete()});

            if (queue_family_indices.isComplete())
                break;
        }

        std.debug.print("{}\n", .{queue_family_indices});

        return queue_family_indices;
    }

    fn isComplete(queue_family_indices: QueueFamilyIndices) bool {
        return queue_family_indices.graphics_family != null and
            queue_family_indices.presentation_family != null;
    }
};

const LogicalDeviceAndQueues = struct {
    logical_device: c.VkDevice,
    graphics_queue: c.VkQueue,
    presentation_queue: c.VkQueue,
};

fn createLogicalDeviceAndQueues(
    allocator: mem.Allocator,
    physical_device: c.VkPhysicalDevice,
    surface: c.VkSurfaceKHR,
    use_validation_layers: bool,
) !LogicalDeviceAndQueues {
    const queue_family_indices = try QueueFamilyIndices.findQueueFamilies(allocator, physical_device, surface);

    // this affects command buffer execution scheduling
    const queue_priority: f32 = 1.0;

    const unique_queue_families = [_]u32{
        queue_family_indices.graphics_family.?,
        queue_family_indices.presentation_family.?,
    };
    std.debug.print("{any}\n", .{unique_queue_families});
    var device_queue_create_infos: [unique_queue_families.len]c.VkDeviceQueueCreateInfo = undefined;
    for (unique_queue_families, 0..) |queue_family, index|
        device_queue_create_infos[index] = mem.zeroInit(c.VkDeviceQueueCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = queue_family,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        });

    const device_create_info = mem.zeroInit(c.VkDeviceCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pQueueCreateInfos = &device_queue_create_infos,
        .queueCreateInfoCount = device_queue_create_infos.len,
        .pEnabledFeatures = &mem.zeroes(c.VkPhysicalDeviceFeatures),
        .ppEnabledExtensionNames = &required_logical_device_extensions,
        .enabledExtensionCount = required_logical_device_extensions.len,
        // a previous version of the Vulkan spec made a distinction of instance-specific
        // and device-specific validation layers. while this is no longer the case, to be compatible with
        // older implementations of Vulkan, we'll explicitly set validation layers for this device, anyway.
        .enabledLayerCount = @boolToInt(use_validation_layers),
        .ppEnabledLayerNames = @as(
            [*c]const [*c]const u8,
            if (use_validation_layers) &[_][*c]const u8{VK_LAYER_KHRONOS_validation} else null,
        ),
    });

    var logical_device: c.VkDevice = undefined;
    if (c.vkCreateDevice(physical_device, &device_create_info, null, &logical_device) != c.VK_SUCCESS)
        @panic("failed creating Vulkan logical device");

    var graphics_queue: c.VkQueue = undefined;
    c.vkGetDeviceQueue(logical_device, queue_family_indices.graphics_family.?, 0, &graphics_queue);

    var presentation_queue: c.VkQueue = undefined;
    c.vkGetDeviceQueue(logical_device, queue_family_indices.presentation_family.?, 0, &presentation_queue);

    return .{
        .logical_device = logical_device,
        .graphics_queue = graphics_queue,
        .presentation_queue = presentation_queue,
    };
}

const SwapChainSupportDetails = struct {
    capabilities: c.VkSurfaceCapabilitiesKHR,
    formats: []c.VkSurfaceFormatKHR,
    present_modes: []c.VkPresentModeKHR,

    fn querySwapChainSupport(allocator: mem.Allocator, physical_device: c.VkPhysicalDevice, surface: c.VkSurfaceKHR) !SwapChainSupportDetails {
        var details: SwapChainSupportDetails = undefined;

        if (c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &details.capabilities) != c.VK_SUCCESS)
            @panic("failed getting Vulkan physical device surface capabilities");

        {
            var format_count: u32 = undefined;
            if (c.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, null) != c.VK_SUCCESS)
                @panic("failed getting Vulkan physical device surface formats");

            details.formats = try allocator.alloc(c.VkSurfaceFormatKHR, format_count);
            if (c.vkGetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, details.formats.ptr) != c.VK_SUCCESS)
                @panic("failed getting Vulkan physical device surface formats");
        }

        {
            var present_mode_count: u32 = undefined;
            if (c.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, null) != c.VK_SUCCESS)
                @panic("failed getting Vulkan physical device surface present modes");

            details.present_modes = try allocator.alloc(c.VkPresentModeKHR, present_mode_count);
            if (c.vkGetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, details.present_modes.ptr) != c.VK_SUCCESS)
                @panic("failed getting Vulkan physical device surface present modes");
        }

        return details;
    }

    fn deinit(details: SwapChainSupportDetails, allocator: mem.Allocator) void {
        allocator.free(details.formats);
        allocator.free(details.present_modes);
    }

    fn chooseSwapSurfaceFormat(details: SwapChainSupportDetails) c.VkSurfaceFormatKHR {
        for (details.formats) |format| {
            if (format.format == c.VK_FORMAT_B8G8R8A8_SRGB and
                format.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
            {
                return format;
            }
        }
        return details.formats[0];
    }

    fn chooseSwapPresentMode(details: SwapChainSupportDetails) c.VkPresentModeKHR {
        for (details.present_modes) |present_mode| {
            if (present_mode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
                return present_mode;
            }
        }

        // TODO: read this and try other present modes:
        // I personally think that VK_PRESENT_MODE_MAILBOX_KHR is a very nice trade-off if energy usage is not a concern. It allows us to avoid tearing while still maintaining a fairly low latency by rendering new images that are as up-to-date as possible right until the vertical blank. On mobile devices, where energy usage is more important, you will probably want to use VK_PRESENT_MODE_FIFO_KHR instead. Now, let's look through the list to see if VK_PRESENT_MODE_MAILBOX_KHR is available:

        return c.VK_PRESENT_MODE_FIFO_KHR; // only this is guaranteed to be available
    }

    fn chooseSwapExtent(details: SwapChainSupportDetails, window: *c.GLFWwindow) c.VkExtent2D {
        if (details.capabilities.currentExtent.width != math.maxInt(u32)) {
            return details.capabilities.currentExtent;
        } else {
            var width: c_int = undefined;
            var height: c_int = undefined;
            c.glfwGetFramebufferSize(window, &width, &height);

            const actual_extent = c.VkExtent2D{
                .width = math.clamp(
                    @intCast(u32, width),
                    details.capabilities.minImageExtent.width,
                    details.capabilities.maxImageExtent.width,
                ),
                .height = math.clamp(
                    @intCast(u32, height),
                    details.capabilities.minImageExtent.height,
                    details.capabilities.maxImageExtent.height,
                ),
            };
            return actual_extent;
        }
    }
};

const SwapChain = struct {
    swap_chain: c.VkSwapchainKHR,
    images: []c.VkImage,
    image_format: c.VkFormat,
    extent: c.VkExtent2D,
};

fn createSwapChain(
    allocator: mem.Allocator,
    physical_device: c.VkPhysicalDevice,
    logical_device: c.VkDevice,
    surface: c.VkSurfaceKHR,
    window: *c.GLFWwindow,
) !SwapChain {
    const swap_chain_support = try SwapChainSupportDetails.querySwapChainSupport(allocator, physical_device, surface);

    const surface_format = swap_chain_support.chooseSwapSurfaceFormat();
    const present_mode = swap_chain_support.chooseSwapPresentMode();
    const extent = swap_chain_support.chooseSwapExtent(window);

    // TODO: report this formatting (should be indented)
    //       this incident will be reported
    var image_count = swap_chain_support.capabilities.minImageCount
    // sticking to this minimum means that sometimes we may have to wait for the driver to
    // complete internal operations before we can acquire another image to render to.
    // therefore we'll request one more image than the minimum.
    + 1;

    if (swap_chain_support.capabilities.maxImageCount > 0 and
        image_count > swap_chain_support.capabilities.maxImageCount)
    {
        image_count = swap_chain_support.capabilities.maxImageCount;
    }

    var create_info: c.VkSwapchainCreateInfoKHR = undefined;
    create_info.sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    create_info.surface = surface;

    create_info.minImageCount = image_count;
    create_info.imageFormat = surface_format.format;
    create_info.imageColorSpace = surface_format.colorSpace;
    create_info.imageExtent = extent;
    create_info.imageArrayLayers = 1;
    create_info.imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

    const queue_family_indices = try QueueFamilyIndices.findQueueFamilies(allocator, physical_device, surface);
    const queue_family_indices_array = [_]u32{ queue_family_indices.graphics_family.?, queue_family_indices.presentation_family.? };

    if (queue_family_indices.graphics_family.? != queue_family_indices.presentation_family) {
        create_info.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
        create_info.queueFamilyIndexCount = 2;
        create_info.pQueueFamilyIndices = &queue_family_indices_array;
    } else {
        create_info.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
        create_info.queueFamilyIndexCount = 0;
        create_info.pQueueFamilyIndices = null;
    }

    create_info.preTransform = swap_chain_support.capabilities.currentTransform;
    create_info.compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    create_info.presentMode = present_mode;
    create_info.clipped = c.VK_TRUE; // for obscured pixels
    create_info.oldSwapchain = null;

    var swap_chain: c.VkSwapchainKHR = undefined;
    if (c.vkCreateSwapchainKHR(logical_device, &create_info, null, &swap_chain) != c.VK_SUCCESS)
        @panic("failed creating Vulkan swap chain");

    var swap_chain_image_count: u32 = undefined;
    if (c.vkGetSwapchainImagesKHR(logical_device, swap_chain, &swap_chain_image_count, null) != c.VK_SUCCESS)
        @panic("failed getting Vulkan swap chain images");
    const swap_chain_images = try allocator.alloc(c.VkImage, swap_chain_image_count);
    if (c.vkGetSwapchainImagesKHR(logical_device, swap_chain, &swap_chain_image_count, swap_chain_images.ptr) != c.VK_SUCCESS)
        @panic("failed getting Vulkan swap chain images");

    return .{
        .swap_chain = swap_chain,
        .images = swap_chain_images,
        .image_format = surface_format.format,
        .extent = extent,
    };
}

fn createImageViews(
    allocator: mem.Allocator,
    logical_device: c.VkDevice,
    image_format: c.VkFormat,
    images: []c.VkImage,
) ![]c.VkImageView {
    var image_views = try allocator.alloc(c.VkImageView, images.len);
    for (image_views, 0..) |*image_view, index| {
        const create_info = mem.zeroInit(c.VkImageViewCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = images[index],
            .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
            .format = image_format,
            .components = .{
                .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = .{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
        });
        if (c.vkCreateImageView(logical_device, &create_info, null, image_view) != c.VK_SUCCESS)
            @panic("failed creating Vulkan swap chain image views");
    }
    return image_views;
}
