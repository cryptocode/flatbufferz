const std = @import("std");
const mem = std.mem;
const Builder = @import("Builder.zig");
const size_prefix_length = Builder.size_prefix_length;

pub const vtable_metadata_fields = 2;

pub const FlatBuffer = struct {
    buf: []const u8,
    i: u32,

    pub fn init(buf: []const u8, i: u32) FlatBuffer {
        return .{ .buf = buf, .i = i };
    }
};

/// GetRootAs is a generic helper to initialize a FlatBuffer with the provided
/// buffer bytes and its data offset.
pub fn getRootAs(buf: []u8, offset: u32) !FlatBuffer {
    const n = try mem.readIntLittle(u32, buf[offset..]);
    return FlatBuffer.init(buf, n + offset);
}

/// GetSizePrefixedRootAs is a generic helper to initialize a FlatBuffer with
/// the provided size-prefixed buffer
/// bytes and its data offset
pub fn getSizePrefixedRootAs(buf: []u8, offset: u32) !FlatBuffer {
    const n = try mem.readIntLittle(u32, buf[offset + size_prefix_length ..]);
    return FlatBuffer.init(buf, n + offset + size_prefix_length);
}

/// GetSizePrefix reads the size from a size-prefixed flatbuffer
pub fn getSizePrefix(buf: []u8, offset: u32) u32 {
    return mem.readIntLittle(u32, buf[offset..]);
}

/// GetIndirectOffset retrives the relative offset in the provided buffer stored
///  at `offset`.
pub fn getIndirectOffset(buf: []u8, offset: u32) u32 {
    return offset + mem.readIntLittle(u32, buf[offset..]);
}

/// read a little-endian T from buf.
pub fn read(comptime T: type, buf: []const u8) T {
    const info = @typeInfo(T);
    if (info == .Float) {
        const I = @Type(.{ .Int = .{
            .signedness = .unsigned,
            .bits = info.Float.bits,
        } });
        return @bitCast(T, mem.readIntLittle(I, buf[0..@sizeOf(T)]));
    } else if (info == .Bool)
        return buf[0] == 1
    else if (info == .Enum) {
        const Tag = info.Enum.tag_type;
        const taginfo = @typeInfo(Tag);
        const I = @Type(.{
            .Int = .{
                .signedness = taginfo.Int.signedness,
                .bits = comptime std.math.ceilPowerOfTwo(u16, taginfo.Int.bits) catch
                    unreachable,
            },
        });
        // return @intToEnum(T, mem.readIntLittle(I, buf[0..@sizeOf(I)]));
        const i = mem.readIntLittle(I, buf[0..@sizeOf(I)]);
        return std.meta.intToEnum(T, i) catch
            std.debug.panic(
            "invalid enum value '{}' for '{s}' with Tag '{s}' and I '{s}'",
            .{ i, @typeName(T), @typeName(Tag), @typeName(I) },
        );
    }
    return mem.readIntLittle(T, buf[0..@sizeOf(T)]);
}

/// write a little-endian T from a byte slice.
pub fn write(comptime T: type, buf: []u8, t: T) void {
    const info = @typeInfo(T);
    if (info == .Float) {
        const I = @Type(.{ .Int = .{
            .signedness = .unsigned,
            .bits = info.Float.bits,
        } });
        mem.writeIntLittle(I, buf[0..@sizeOf(T)], @bitCast(I, t));
    } else mem.writeIntLittle(T, buf[0..@sizeOf(T)], t);
}