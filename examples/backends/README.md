# backends

This child directory is the only entry in this parent directory that is *not* an example.
Rather, these are the backends powering all the examples.

An example backend must provide *at least* the following public declarations to the examples:

* ```
  /// The Cell struct of this Grid must be either packed or extern in order to allow @bitCast
  /// (or for compatibility, anyway).
  pub const Grid
  ```
* `pub var grid`
* `pub const allocator: std.mem.Allocator`
* ```
  /// A value that is supposed to be useable for achieving non-deterministic behavior.
  /// Useful for seeding random number generators.
  /// For a random number generator to work, really only a single random-ish value is needed after which
  /// the RNG can function on its own and produce more seemingly-random values.
  pub var seed: u64
  ```

An example backend must never allow its identity to be revealed; examples should never have to include backend-specific patches to accustom themselves to faults of certain backends.

An example backend must run examples at a reasonable pace, such as for example 60 FPS.
