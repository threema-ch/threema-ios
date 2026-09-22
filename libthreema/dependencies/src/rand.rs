//! Minimally required items of the `rand` crate.
#[cfg(feature = "seedable-rng")]
pub use rand::SeedableRng;
pub use rand::{Rng, RngCore, distributions, random, thread_rng};

pub mod seq {
    //! Wrapper for [`rand::seq`].
    pub use rand::seq::SliceRandom;
}

#[cfg(feature = "seedable-rng")]
pub mod rngs {
    //! Wrapper for [`rand::rngs`].
    pub use rand::rngs::StdRng;
}
