## Notes

### Why not use `symlinkJoin` for `esp-rustc-with-src`?

- Rust for ESP utilizes the unstable Cargo `build-std` feature (to compile the Rust standard library for the their special target):
  ```toml
  # .cargo/config.toml
  [unstable]
  build-std = ["core"]
  ```
- This feature requires that `rust-src` resides within the same output directory as `rustc`.
- [Currently, Cargo requires adding the `rust-src` component via rustup](https://doc.rust-lang.org/cargo/reference/unstable.html#build-std) for this to work correctly.
- Cargo locates the source by executing `rustc --print sysroot`:
  - However, `rustc` returns its specific derivation path.
  - If `symlinkJoin` is used for `esp-rustc-with-src`, the returned path points to the inner `esp-rustc` instead, missing the `rust-src` component.
- Bonus: by having the `rust-src` and `rustc` in the same output, it also simplifies IDE configurations, as they can point to a single path for both.
  - So we don't need to set `RUST_SRC_PATH` for `rust-analyzer` explicitly.
