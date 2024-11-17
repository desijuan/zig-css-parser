# Simple CSS parser written in Zig

Small project inspired in this one:
[Metaprogramming in Zig and parsing a bit of CSS](https://github.com/eatonphil/zig-metaprogramming-css-parser).

This is a small project that I used to learn some things about parsing and to have fun writing Zig code.
I watched Phil Eaton's
[video](https://www.youtube.com/watch?v=WWtZ6oog7PY)
on Youtube, read his
[blog post](https://notes.eatonphil.com/2023-06-19-metaprogramming-in-zig-and-parsing-css.html)
and read the source code at
[Metaprogramming in Zig and parsing a bit of CSS](https://github.com/eatonphil/zig-metaprogramming-css-parser).
Thank you very much for sharing your knowledge Phil! I learned a lot!

```console
$ zig build --summary all
$ ./zig-out/bin/css-parser tests/more-complete-2.css

selectors: "h1"
  text-align: "center"

selectors: ".container"
  background-color: "rgb(255, 255, 255)"
  padding: "10px 0"

selectors: ".marker"
  width: "200px"
  height: "25px"
  margin: "10px auto"

selectors: ".cap"
  width: "60px"
  height: "25px"

selectors: ".sleeve"
  width: "110px"
  height: "25px"
  background-color: "rgba(255, 255, 255, 0.5)"
  border-left: "10px double rgba(0, 0, 0, 0.75)"

selectors: ".cap", ".sleeve"
  display: "inline-block"

selectors: ".red"
  background: "linear-gradient(rgb(122, 74, 14), rgb(245, 62, 113), rgb(162, 27, 27))"
  box-shadow: "0 0 20px 0 rgba(83, 14, 14, 0.8)"

selectors: ".green"
  background: "linear-gradient(#55680D, #71F53E, #116C31)"
  box-shadow: "0 0 20px 0 #3B7E20CC"

selectors: ".blue"
  background: "linear-gradient(hsl(186, 76%, 16%), hsl(223, 90%, 60%), hsl(240, 56%, 42%))"
  box-shadow: "0 0 20px 0 blue"
```

## Some thoughts about Zig's metaprogramming capabilities

I think Zig's metaprogramming capabilities are quite interesting. As Phil mentions in it blog post,
you can do things like the following:
```zig
const Declaration = struct {
    property: Property,
    value: []const u8,

    fn print(self: Declaration) void {
        std.debug.print("{s}: \"{s}\"\n", .{ @tagName(self.property), self.value });
    }
};

const Property = enum {
    width,
    height,
    margin,
    padding,
};

fn match_decl(key: []const u8, value: []const u8) ?Declaration {
    inline for (@typeInfo(Property).Enum.fields) |field|
        if (std.mem.eql(u8, key, field.name)) {
            return Declaration{
                .property = @enumFromInt(field.value),
                .value = value,
            };
        };

    return null;
}
```

The code in the inline for inside the match_decl function will be unrolled at compile-time,
so at the end it will look something like this:
```zig
fn match_decl(key: []const u8, value: []const u8) ?Declaration {
    if (std.mem.eql(u8, key, "width")) {
        return Declaration{
            .property = .width,
            .value = value,
        };
    }

    if (std.mem.eql(u8, key, "height")) {
        return Declaration{
            .property = .height,
            .value = value,
        };
    }

    if (std.mem.eql(u8, key, "margin")) {
        return Declaration{
            .property = .margin,
            .value = value,
        };
    }

    if (std.mem.eql(u8, .padding, "padding")) {
        return Declaration{
            .property = .width,
            .value = value,
        };
    }

    return null;
}
```

I think that this is very nice. I can add or remove properties and I don't have to worry about
having to update the match_propary function. It will always return the correct declaration
with the property matching the given key, if the key is one of the properties, or null otherwise.

For this project, I found an overkill, so I didn't include this option, but we could have
handlers. Consider the following for example:
```zig
const Property = enum {
    width,
    height,
    margin,
    padding,

    fn handleValue(self: Property, value: []const u8) Declaration {
        switch (self) {
            else => return Declaration{
                .property = self,
                .value = value,
            },
        }
    }
};

fn match_decl(key: []const u8, value: []const u8) ?Declaration {
    inline for (@typeInfo(Property).Enum.fields) |field|
        if (std.mem.eql(u8, key, field.name))
            return @as(Property, @enumFromInt(field.value)).handleValue(value);

    return null;
}
```

Right now, this does the same as the previous version, since I only implemented the default handler.
But soppouse that we needed to handle the property value part. As a simple example let's changhe the
value of all color tags to the string `"COLOR"`.

We could do this by changing the handleValue function, like so:
```zig
    fn handleValue(self: Property, value: []const u8) Declaration {
        switch (self) {
            .color => {
                const new_value = "COLOR";

                return Declaration{
                    .property = self,
                    .value = new_value,
                };
            },

            else => return Declaration{
                .property = self,
                .value = value,
            },
        }
    }
```

If we run process `tests/more-complete-1.css`, we get the following output:
```console
$ zig build --summary all
$ ./zig-out/bin/css-parser tests/more-complete-1.css

...

selectors: "footer"
  font-size: "14px"

selectors: ".address"
  margin-bottom: "5px"

selectors: "a"
  color: "COLOR"

selectors: "a:visited"
  color: "COLOR"

selectors: "a:hover"
  color: "COLOR"

selectors: "a:active"
  color: "COLOR"
```

## Extras

### Defining expected arguments declaratively

I noticed that metaprogramming can be used to specify the desired arguments and the types I expected,
in a clear and concise (declarative) way.

Let's look at an example.

Zig works differently that C when getting arguments that were passed to the program when the process was launched.
In C I would normally do:
```c
int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s <mode> <input_file_path> <output_file_path>");
        return 1;
    }
}
```
and in Zig, to get the same behaviour (working only in Linux, I know, but I don't care about non-Unix-systems)
I manage to do:
```zig
pub fn main() !u8 {
    // ...

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const bin: []const u8 = args.next().?;
    const mode_str, const input_fp, const output_fp = args: {
        const err = error.InvalidArguments;

        const mode_str = args.next() orelse break :args err;
        const source = args.next() orelse break :args err;
        const dest = args.next() orelse break :args err;
        if (args.skip()) break :args err;

        break :args [3][]const u8{ mode_str, source, dest };
    } catch {
        std.debug.print("Usage: {s} <mode> <source> <dest>\n", .{bin});
        return 1;
    };

    const mode = try std.fmt.parseInt(c_char, mode_str, 10);

    // ...
}
```

This time I wanted to see if I could do better, so I came out with the following:
```zig
const Args = struct {
    mode: u8,
    input_file_path: [:0]const u8,
    output_file_path: [:0]const u8,
};

pub fn main() !u8 {
    const args: Args = utils.readArgs(Args) catch |err| {
        switch (err) {
            error.InvalidArguments => {},
            else => std.debug.print("error: {s}\n", .{@errorName(err)}),
        }

        return 1;
    };

    // ...
}
```

Note that this is much cleaner. I declared in order all the arguments that I expect,
together with the type of each argument, in the Args struct. And this is done in a
declarative way.

The implementation of the readArgs function is the following:
```zig
pub fn readArgs(comptime ArgsStruct: type) !ArgsStruct {
    const typeInfo = @typeInfo(ArgsStruct);
    if (typeInfo != .Struct) @compileError("Struct expected!");

    var args = std.process.args();
    const bin: []const u8 = args.next().?;

    var argsStruct: ArgsStruct = undefined;

    (read_args: {
        inline for (typeInfo.Struct.fields) |field| {
            const arg_str = args.next() orelse break :read_args error.InvalidArguments;

            @field(argsStruct, field.name) = switch (@typeInfo(field.type)) {
                .Pointer => arg_str,
                .Int => try std.fmt.parseInt(field.type, arg_str, 10),
                .Float => try std.fmt.parseFloat(field.type, arg_str),
                else => |t| @compileError("Type " ++ @tagName(t) ++ " not supported"),
            };
        }

        if (args.skip()) break :read_args error.InvalidArguments;
    } catch |err| {
        std.debug.print("Usage: {s}", .{bin});
        inline for (typeInfo.Struct.fields) |field|
            std.debug.print(" <{s}>", .{field.name})
        else
            std.debug.print("\n", .{});

        return err;
    });

    return argsStruct;
}
```

With some metaprogramming wizardry, I manage to get a way to specify in the ArgsStruct type,
the information about the intended arguments and its types (and order). If the user fail
to provide the required number of arguments, in this case 3, we get the following string printed
to the console:
```colnsole
Usage: ./zig-out/bin/css-parser <mode> <input_file_path> <output_file_path>
```

And the parsing also gets done. For example, for the first argument `mode: u8`, it gets parsed
as an integer. So, if we run:
```console
$ ./zig-out/bin/css-parser 7.2 tests/more-complete-2.css some-other-file.txt
```
we get `error: InvalidCharacter`, that comes from the branch
```zig
.Int => try std.fmt.parseInt(field.type, arg_str, 10),
```
inside the `read_args` block in the readArgs function.

I think that this is very nice. I can reuse the readArgs function in other projects and specify
the expected arguments in a more declarative way.

Note that actual parser code, we only have one argument, so, the
beginning of the main function is simpler.

### Printing structs

The following code can be used to print the name and all the fields of a struct:
```zig
pub fn printStruct(value: anytype) !void {
    const T = @TypeOf(value);
    const typeInfo = @typeInfo(T);
    if (typeInfo != .Struct) @compileError("Struct expected!");

    std.debug.print("{s} {{\n", .{@typeName(T)});
    inline for (typeInfo.Struct.fields) |field| switch (@typeInfo(field.type)) {
        .Pointer => std.debug.print("   {s}: {s},\n", .{ field.name, @field(value, field.name) }),
        .Int, .Float => std.debug.print("   {s}: {},\n", .{ field.name, @field(value, field.name) }),
        else => |t| @compileError("Type " ++ @tagName(t) ++ " not supported"),
    };

    std.debug.print("}}\n", .{});
}
```

### Working with ASCII strings

Although even in its infancy steps, Zig's string handling capabilities offer some interesting tricks.
Look how we can split a string separating int by commas and trim each result:
```zig
    // ...

    // read selector part
    const selectors_str = try parse_string_up_to('{');

    // parse selectors list
    var selectors_it = std.mem.tokenizeScalar(u8, selectors_str, ',');
    while (selectors_it.next()) |item| {
        try selectors.append(trim(item));
    }

    // ...

inline fn trim(str: []const u8) []const u8 {
    return std.mem.trim(u8, str, &std.ascii.whitespace);
}
```

Note that this works only with ASCII charsets.
