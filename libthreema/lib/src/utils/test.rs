//! Utilities for tests.

/// Allows to unwrap an error within a [`Result`] without having to implement [`Debug`].
pub(crate) trait ResultUnwrapErrorQuiet<E> {
    fn unwrap_err_quiet(self) -> E;
}
impl<T, E> ResultUnwrapErrorQuiet<E> for Result<T, E> {
    #[track_caller]
    fn unwrap_err_quiet(self) -> E {
        match self {
            Ok(_) => panic!("called `Result::unwrap_err_quiet()` on an `Ok` value"),
            Err(error) => error,
        }
    }
}
