//! Logging-related utilities.
#[cfg(any(test, feature = "cli"))]
use tracing::level_filters::LevelFilter;

#[cfg(any(test, feature = "cli"))]
/// Initialise basic stderr logging with the provided level filter.
///
/// # Panics
///
/// Panics if called more than once.
pub fn init_stderr_logging<TFilter>(filter: TFilter)
where
    TFilter: Into<LevelFilter>,
{
    let subscriber = tracing_subscriber::FmtSubscriber::builder()
        .with_max_level(filter)
        .with_target(false)
        .finish();
    tracing::subscriber::set_global_default(subscriber).expect("Could not initialize tracing subscriber");
}
