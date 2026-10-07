const std = @import("std");
const dynamic = @import("datatype/dynamic.zig");
const Dynamic = dynamic.Dynamic;

extern "c" fn dlopen(filename: ?[*:0]const u8, flag: c_int) ?*anyopaque;
extern "c" fn dlsym(handle: ?*anyopaque, symbol: [*:0]const u8) ?*anyopaque;
extern "c" fn dlclose(handle: ?*anyopaque) c_int;

const RTLD_NOW: c_int = 2;

// ============================================================================
// Vulkan C-ABI Types & Declarations
// ============================================================================

pub const VkResult = c_int;
pub const VK_SUCCESS: c_int = 0;

pub const VkStructureType = c_int;
pub const VK_STRUCTURE_TYPE_APPLICATION_INFO: c_int = 0;
pub const VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO: c_int = 1;

pub const VkInstance = ?*anyopaque;
pub const VkPhysicalDevice = ?*anyopaque;

pub const VkApplicationInfo = extern struct {
    sType: VkStructureType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
    pNext: ?*const anyopaque = null,
    pApplicationName: ?[*:0]const u8 = "SundaPy",
    applicationVersion: u32 = 1,
    pEngineName: ?[*:0]const u8 = "SundaPy Compute Engine",
    engineVersion: u32 = 1,
    apiVersion: u32 = (1 << 22) | (2 << 12), // Vulkan 1.2
};

pub const VkInstanceCreateInfo = extern struct {
    sType: VkStructureType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
    pNext: ?*const anyopaque = null,
    flags: u32 = 0,
    pApplicationInfo: ?*const VkApplicationInfo = null,
    enabledLayerCount: u32 = 0,
    ppEnabledLayerNames: ?[*]const [*:0]const u8 = null,
    enabledExtensionCount: u32 = 0,
    ppEnabledExtensionNames: ?[*]const [*:0]const u8 = null,
};

pub const VkPhysicalDeviceType = enum(u32) {
    other = 0,
    integrated_gpu = 1,
    discrete_gpu = 2,
    virtual_gpu = 3,
    cpu = 4,
};

pub const VkPhysicalDeviceProperties = extern struct {
    apiVersion: u32,
    driverVersion: u32,
    vendorID: u32,
    deviceID: u32,
    deviceType: u32,
    deviceName: [256]u8,
    pipelineCacheUUID: [16]u8,
    limits_data: [500]u8, // opaque limits buffer
    sparseProperties_data: [20]u8,
};

// ============================================================================
// Vulkan Driver State & Dynamic Symbols
// ============================================================================

pub var vk_handle: ?*anyopaque = null;
pub var vk_instance: VkInstance = null;
pub var is_vulkan_initialized: bool = false;
pub var vk_device_count: u32 = 0;
pub var vk_primary_device_name: [256]u8 = [_]u8{0} ** 256;
pub var vk_primary_device_name_len: usize = 0;
pub var vk_primary_device_type: []const u8 = "Unknown";
pub var vk_api_version_str: [32]u8 = [_]u8{0} ** 32;
pub var vk_api_version_len: usize = 0;

var vkCreateInstanceFn: ?*const fn (*const VkInstanceCreateInfo, ?*anyopaque, *VkInstance) callconv(.c) VkResult = null;
var vkDestroyInstanceFn: ?*const fn (VkInstance, ?*anyopaque) callconv(.c) void = null;
var vkEnumeratePhysicalDevicesFn: ?*const fn (VkInstance, *u32, ?[*]VkPhysicalDevice) callconv(.c) VkResult = null;
var vkGetPhysicalDevicePropertiesFn: ?*const fn (VkPhysicalDevice, *VkPhysicalDeviceProperties) callconv(.c) void = null;

const VULKAN_LIB_PATHS = [_][*:0]const u8{
    "/usr/lib/libvulkan.so.1",
    "/usr/lib/libvulkan.so",
    "/usr/lib/x86_64-linux-gnu/libvulkan.so.1",
    "/usr/lib/x86_64-linux-gnu/libvulkan.so",
    "/usr/lib64/libvulkan.so.1",
    "/usr/lib64/libvulkan.so",
    "libvulkan.so.1",
    "libvulkan.so",
};

pub fn initVulkanDriver() bool {
    if (is_vulkan_initialized) return vk_instance != null;
    is_vulkan_initialized = true;

    for (VULKAN_LIB_PATHS) |path| {
        const h = dlopen(path, RTLD_NOW);
        if (h) |handle| {
            const createInst = dlsym(handle, "vkCreateInstance");
            const destroyInst = dlsym(handle, "vkDestroyInstance");
            const enumDevices = dlsym(handle, "vkEnumeratePhysicalDevices");
            const getProps = dlsym(handle, "vkGetPhysicalDeviceProperties");

            if (createInst != null and enumDevices != null and getProps != null) {
                vkCreateInstanceFn = @ptrCast(createInst);
                vkDestroyInstanceFn = if (destroyInst != null) @ptrCast(destroyInst) else null;
                vkEnumeratePhysicalDevicesFn = @ptrCast(enumDevices);
                vkGetPhysicalDevicePropertiesFn = @ptrCast(getProps);

                const app_info = VkApplicationInfo{};
                const create_info = VkInstanceCreateInfo{
                    .pApplicationInfo = &app_info,
                };

                var inst: VkInstance = null;
                if (vkCreateInstanceFn.?(&create_info, null, &inst) == VK_SUCCESS and inst != null) {
                    vk_handle = handle;
                    vk_instance = inst;

                    var dev_count: u32 = 0;
                    if (vkEnumeratePhysicalDevicesFn.?(inst, &dev_count, null) == VK_SUCCESS and dev_count > 0) {
                        vk_device_count = dev_count;
                        var devices: [16]VkPhysicalDevice = undefined;
                        const fetch_count = @min(dev_count, 16);
                        if (vkEnumeratePhysicalDevicesFn.?(inst, &dev_count, &devices) == VK_SUCCESS) {
                            var best_props: VkPhysicalDeviceProperties = undefined;
                            var best_is_discrete = false;

                            for (0..fetch_count) |i| {
                                var props: VkPhysicalDeviceProperties = undefined;
                                vkGetPhysicalDevicePropertiesFn.?(devices[i], &props);
                                const is_discrete = (props.deviceType == @intFromEnum(VkPhysicalDeviceType.discrete_gpu));

                                if (i == 0 or (is_discrete and !best_is_discrete)) {
                                    best_props = props;
                                    best_is_discrete = is_discrete;
                                }
                            }

                            // Copy device name
                            const name_len = std.mem.indexOfScalar(u8, &best_props.deviceName, 0) orelse 255;
                            @memcpy(vk_primary_device_name[0..name_len], best_props.deviceName[0..name_len]);
                            vk_primary_device_name_len = name_len;

                            vk_primary_device_type = switch (best_props.deviceType) {
                                1 => "Integrated GPU",
                                2 => "Discrete GPU",
                                3 => "Virtual GPU",
                                4 => "CPU",
                                else => "Other",
                            };

                            const major = best_props.apiVersion >> 22;
                            const minor = (best_props.apiVersion >> 12) & 0x3FF;
                            const patch = best_props.apiVersion & 0xFFF;
                            const ver_slice = std.fmt.bufPrint(&vk_api_version_str, "{d}.{d}.{d}", .{ major, minor, patch }) catch "1.2.0";
                            vk_api_version_len = ver_slice.len;
                        }
                    }
                    return true;
                }
            }
            _ = dlclose(handle);
        }
    }
    return false;
}

pub fn get_vulkan_device_name() anyerror!Dynamic {
    _ = initVulkanDriver();
    if (vk_primary_device_name_len > 0) {
        return Dynamic.initStr(vk_primary_device_name[0..vk_primary_device_name_len]);
    }
    return Dynamic.initStr("Vulkan Device Unavailable");
}

pub fn get_vulkan_device_count() anyerror!Dynamic {
    _ = initVulkanDriver();
    return Dynamic.initInt(@intCast(vk_device_count));
}

pub fn get_vulkan_device_type() anyerror!Dynamic {
    _ = initVulkanDriver();
    return Dynamic.initStr(vk_primary_device_type);
}

pub fn get_vulkan_api_version() anyerror!Dynamic {
    _ = initVulkanDriver();
    if (vk_api_version_len > 0) {
        return Dynamic.initStr(vk_api_version_str[0..vk_api_version_len]);
    }
    return Dynamic.initStr("None");
}

pub fn is_vulkan_available() anyerror!Dynamic {
    return Dynamic.initBool(initVulkanDriver());
}
