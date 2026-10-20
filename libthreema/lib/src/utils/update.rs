//! Update utilities for modification of types.
use core::ops::Deref;

/// Modify self by applying a provided value.
pub(crate) trait Apply<T>: Sized {
    /// Apply the provided value, modifying self.
    fn apply(&mut self, value: T);

    /// Apply the provided value, modifying and returning self.
    #[inline]
    fn chain_apply(mut self, value: T) -> Self {
        self.apply(value);
        self
    }
}

/// Try modifying self by applying a provided value.
pub(crate) trait TryApply<T>: Sized {
    /// The type returned in the event of an error. If this is returned, self must not have been modified.
    type Error;

    /// Try applying the provided value, modifying self.
    ///
    /// IMPORTANT: In case of an error, self must not be modified!
    fn try_apply(&mut self, value: T) -> Result<(), Self::Error>;

    /// Try applying the provided value, modifying and returning self.
    #[expect(dead_code, reason = "May use later")]
    #[inline]
    fn try_chain_apply(mut self, value: T) -> Result<Self, Self::Error> {
        self.try_apply(value)?;
        Ok(self)
    }
}

/// Update self with the provided value if the provided value is [`Some`].
pub(crate) trait ApplySome<T> {
    /// Update self with the provided value if the provided value is [`Some`].
    fn apply_some(&mut self, value: Option<T>);
}
impl<T> ApplySome<T> for T {
    fn apply_some(&mut self, value: Option<T>) {
        if let Some(value) = value {
            *self = value;
        }
    }
}

/// Compare a delta-style [`Option<T>`] against a value and return `Some(T)` if there is an update and the
/// update is different to the value.
pub(crate) trait DeltaOption<T> {
    /// Compare the delta-style self against `current` and return `Some(T)` if there is an update and the
    /// update is different to `current`.
    fn delta(self, current: &T) -> Option<T>;
}
impl<T: Eq> DeltaOption<T> for Option<T> {
    fn delta(self, current: &T) -> Self {
        if let Some(update) = self
            && *current != update
        {
            Some(update)
        } else {
            None
        }
    }
}

/// A delta update, where some value can be unchanged, updated or removed.
#[derive(Debug, Default, Clone, PartialEq)]
pub enum Delta<T> {
    /// Value remains unchanged.
    #[default]
    Unchanged,
    /// Value updated to inner `T`.
    Update(T),
    /// Value removed.
    Remove,
}
impl<T> Delta<T> {
    /// Maps a `Delta<T>` to `Delta<U>` by applying a function to a contained value (if `Update`) or returns
    /// `Unchanged` or `Remove` respectively.
    pub(crate) fn map<U, F>(self, transform_fn: F) -> Delta<U>
    where
        F: FnOnce(T) -> U,
    {
        match self {
            Self::Unchanged => Delta::Unchanged,
            Self::Update(value) => Delta::Update(transform_fn(value)),
            Self::Remove => Delta::Remove,
        }
    }

    /// Converts from [`&Delta<T>`](`Delta<T>`) to [`Delta<&T>`].
    #[inline]
    pub(crate) const fn as_ref(&self) -> Delta<&T> {
        match &self {
            Self::Unchanged => Delta::Unchanged,
            Self::Update(value) => Delta::Update(value),
            Self::Remove => Delta::Remove,
        }
    }

    /// Converts from [`Delta<T>`] (or [`&Delta<T>`](`Delta<T>`)) to `Delta<&T::Target>`.
    #[expect(dead_code, reason = "May use later")]
    #[inline]
    pub(crate) fn as_deref(&self) -> Delta<&T::Target>
    where
        T: Deref,
    {
        self.as_ref().map(Deref::deref)
    }
}
impl<T> Apply<Delta<T>> for Option<T> {
    /// Apply the delta update to self.
    ///
    /// - [`Delta::Unchanged`] does nothing,
    /// - [`Delta::Update`] replaces any value in self with `Some(T)`,
    /// - [`Delta::Remove`] replaces any value in self with `None`.
    #[inline]
    fn apply(&mut self, value: Delta<T>) {
        match value {
            Delta::Unchanged => {},
            Delta::Update(value) => {
                let _ = self.insert(value);
            },
            Delta::Remove => {
                let _ = self.take();
            },
        }
    }
}
impl<T: Eq> Delta<T> {
    /// Re-evaluate the delta update against a `current` value, ensuring that it reflects actual
    /// changes and otherwise reports [`Delta::Unchanged`] if there is no change.
    #[expect(dead_code, reason = "May use later")]
    pub(crate) fn delta(self, current: Option<&T>) -> Self {
        match (self, current) {
            (Self::Update(update), None) => Self::Update(update),
            (Self::Update(update), Some(current)) => {
                if current == &update {
                    Self::Unchanged
                } else {
                    Self::Update(update)
                }
            },
            (Self::Remove, None) | (Self::Unchanged, _) => Self::Unchanged,
            (Self::Remove, Some(_)) => Self::Remove,
        }
    }
}
