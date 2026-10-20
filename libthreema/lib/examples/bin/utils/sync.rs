//! Sync-related utilities.
use std::sync::{Mutex, MutexGuard};

/// Extension for [`Mutex`] to lock and panic if the lock could not be obtained.
pub(crate) trait MutexPoisonPanic {
    type T;

    /// Acquires a mutex, blocking the current thread until it is able to do so, or panic if the lock is
    /// poisoned.
    fn lock_unwrap(&self) -> MutexGuard<'_, Self::T>;
}

impl<T> MutexPoisonPanic for Mutex<T> {
    type T = T;

    fn lock_unwrap(&self) -> MutexGuard<'_, Self::T> {
        self.lock().expect("lock should not be poisoned")
    }
}
