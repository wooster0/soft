pub usingnamespace @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {}); // don't include any OpenGL or OpenGL ES header
    @cDefine("GLFW_INCLUDE_VULKAN", {}); // include everything we need to use Vulkan
    @cInclude("GLFW/glfw3.h");
});
