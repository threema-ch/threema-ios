extern crate cbindgen;

use std::env;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    if env::var("SKIP_CBINDGEN").unwrap_or("0".to_string()) == "1" {
        return;
    }
    cbindgen::generate(&crate_dir)
        .expect("Unable to generate C bindings")
        .write_to_file("saltyrtc_task_relayed_data_ffi.h");
}
