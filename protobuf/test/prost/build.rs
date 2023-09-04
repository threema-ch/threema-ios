use anyhow::Context;
use prost_build::Config;

fn main() -> anyhow::Result<()> {
    const PATH: &str = "../../";
    let entries = std::fs::read_dir(PATH)
        .context("Could not open directory with proto files")?
        .filter(|maybe_entry| {
            maybe_entry
                .as_ref()
                .map(|entry| entry.file_name().to_string_lossy().ends_with(".proto"))
                .unwrap_or(false)
        })
        .map(|entry| entry.map(|entry| entry.path()))
        .collect::<Result<Vec<_>, _>>()
        .context("Failed to read directory")?;
    Config::new()
        .include_file("threema_protocols.rs")
        .compile_protos(entries.as_ref(), &[PATH])
        .context("Could not compile proto files")?;
    Ok(())
}
