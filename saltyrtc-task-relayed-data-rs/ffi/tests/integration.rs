#[macro_use]
extern crate lazy_static;
extern crate saltyrtc_client;
extern crate tokio_core;
extern crate tokio_process;
extern crate tokio_timer;

use std::fs::copy;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::sync::{Mutex, MutexGuard};
use std::time::Duration;

use saltyrtc_client::dep::futures::Future;
use saltyrtc_client::dep::futures::future::Either;
use tokio_core::reactor::Core;
use tokio_process::CommandExt;
use tokio_timer::Timer;

lazy_static! {
    static ref C_TEST_MUTEX: Mutex<()> = Mutex::new(());
}

fn assert_output_success(output: Output) {
    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        println!("Stdout:\n{}\nStderr:\n{}\n", stdout, stderr);
        panic!("Running C tests failed with non-zero return code");
    }
}

fn build_tests() -> (MutexGuard<'static, ()>, PathBuf) {
    let guard = match C_TEST_MUTEX.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    };

    let out_dir = env!("OUT_DIR");
    let build_dir = Path::new(out_dir).join("build");

    println!("Running meson...");
    Command::new("meson")
        .arg(build_dir.to_str().unwrap())
        .env("CC", "clang")
        .output()
        .expect("Could not run meson to build C tests");

    println!("Running ninja...");
    let output = Command::new("ninja")
        .current_dir(&build_dir)
        .output()
        .expect("Could not run ninja to build C tests");
    assert_output_success(output);

    println!("Copying test certificate...");
    copy("../saltyrtc.der", build_dir.join("saltyrtc.der"))
        .expect("Could not copy test certificate (saltyrtc.der)");

    (guard, build_dir)
}

fn c_tests_run(bin: &str, logger: Option<&str>) {
    let (_guard, build_dir) = build_tests();

    // Event loop
    let mut core = Core::new().unwrap();

    // Timer
    let timer = Timer::default();

    // Create a command future
    let mut cmd = Command::new(bin);
    if let Some(l) = logger {
        cmd.arg("-l").arg(l);
    }
    let c_tests = cmd
        .current_dir(&build_dir)
        .output_async(&core.handle());

    // Run command with timeout
    let timeout_seconds = 3;
    let either = core.run(c_tests.select2(timer.sleep(Duration::from_secs(timeout_seconds))))
        .expect("Failed to run C tests and collect output");
    let output = match either {
        Either::A((output, _)) => output,
        Either::B(_) => panic!("Timeout reached when running C tests"),
    };

    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        println!("Stdout:\n{}\nStderr:\n{}\n", stdout, stderr);
        panic!("Running C tests failed with non-zero return code");
    }
}

#[test]
fn c_tests_integration_run_console_logger() {
    c_tests_run("./integration", Some("console"));
}

#[test]
fn c_tests_integration_run_callback_logger() {
    c_tests_run("./integration", Some("callback"));
}

#[test]
fn c_tests_disconnect_run() {
    c_tests_run("./disconnect", None);
}

// #[test] Disabled for now due to false errors, see
// https://bugs.kde.org/show_bug.cgi?id=381289 and
// https://bugzilla.redhat.com/show_bug.cgi?id=1462258
// Additionally, the log4rs logger initializes global memory that cannot
// currently be freed.
fn c_tests_no_memory_leaks() {
    let (_guard, build_dir) = build_tests();

    let output = Command::new("valgrind")
        .arg("--error-exitcode=23")
        .arg("--leak-check=full")
        .arg("--track-fds=yes")
        .arg("./integration")
        .current_dir(&build_dir)
        .output()
        .expect("Could not run valgrind");
    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        println!("Stdout:\n{}\nStderr:\n{}\n", stdout, stderr);
        panic!("Running valgrind failed with non-zero return code");
    }
}
