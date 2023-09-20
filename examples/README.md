# examples

These are the examples showcasing Soft and how it integrates into all kinds of environments.
This also serves as a playground.

You are encouraged to hack on the examples and play around with them.

An example must provide *at least* the following public declarations to the example backends:
* ```
  /// Initializes the program; may be empty.
  pub fn init() !void
  ```
* ```
  /// Runs every frame.
  pub fn tick(time: anytype) !void
  ```

An example can *optionally* provide the following public declarations to the example backends:
* ```
  /// If this is not provided, the example backend will use black to clear the grid.
  /// If this is `null`, the example backend will not clear the grid.
  /// If this is a color, the example backend will use that color to clear the grid.
  pub const clear_color: ?Color`
  ```
* `pub fn handlePointerMovement(x: isize, y: isize) void`
* `pub fn handlePointerPressed(x: isize, y: isize) void`
* `pub fn handlePointerReleased(x: isize, y: isize) void`

# Contributing

Please make sure your example provides

* Educational value
* Documentation where reasonable
* A top-level doc comment
* Configurability (through decls at file top with explanations) where deemed worthy
* The ability to run with all currently existing example backends

If you come up with something cool that conforms to these points, make a PR!
