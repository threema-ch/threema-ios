//! WASM (FFI) bindings.
use wasm_bindgen::prelude::*;

use crate::bindings::wasm::utils::logging::{
    LogDispatcher, LogLevel, PanicDispatcher, init_logging, init_panic_dispatcher,
};

// The crypto dependencies require getrandom and we need to explicitly list it as a dependency
// when compiling for WASM since it requires the feature 'js'. If we don't declare this here,
// the linter will pick it up as an unused dependency.
mod external_crate_false_positives {
    use getrandom as _;
}

pub mod common;
pub mod crypto;
pub mod csp_e2e;
pub mod d2d_rendezvous;
pub mod https;
pub mod remote_secret;
pub mod utils;
pub mod work;

/// Initialise libthreema.
///
/// IMPORTANT: This must be called **once** before making any other calls to libthreema in order to
/// set up the panic and log dispatcher.
#[wasm_bindgen(js_name = init)]
pub fn init(panic_dispatcher: PanicDispatcher, logger: &LogDispatcher, min_log_level: LogLevel) {
    init_panic_dispatcher(panic_dispatcher);
    init_logging(logger, min_log_level);
}
