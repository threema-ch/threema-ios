use saltyrtc_client::dep::futures::{Async, Future, Poll};

/// A nonblocking future wrapper that allows to poll the inner future without blocking.
///
/// The future borrows the inner future mutably. If the inner future is ready,
/// then it resolves to `Some(T)`. Otherwise, it resolves to `None`.
#[must_use = "futures do nothing unless polled"]
#[derive(Debug)]
pub struct NonBlocking<'a, T: 'a> {
    inner: &'a mut T,
}

pub fn new<'a, T>(inner: &'a mut T) -> NonBlocking<'a, T> {
    NonBlocking { inner }
}

impl<'a, T> Future for NonBlocking<'a, T> where T: Future {
    type Item = Option<T::Item>;
    type Error = T::Error;

    fn poll(&mut self) -> Poll<Self::Item, Self::Error> {
        match self.inner.poll()? {
            Async::Ready(v) => Ok(Async::Ready(Some(v))),
            Async::NotReady => Ok(Async::Ready(None)),
        }
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use saltyrtc_client::dep::futures::future::{self, FutureResult};
    use tokio_core::reactor::Core;
    use tokio_timer::Timer;

    /// Test the case where the value is not yet available when polling.
    #[test]
    fn test_poll_not_available() {
        let mut core = Core::new().unwrap();
        let timer = Timer::default();
        let mut timeout = timer.sleep(Duration::from_secs(5));
        let future = super::new(&mut timeout);
        let res = core.run(future);
        assert_eq!(res, Ok(None));
    }

    /// Test the case where the value is available when polling.
    #[test]
    fn test_poll_available() {
        let mut core = Core::new().unwrap();
        let mut inner: FutureResult<u8, ()> = future::ok(42u8);
        let future = super::new(&mut inner);
        let res = core.run(future);
        assert_eq!(res, Ok(Some(42)));
    }

    /// Test the case where the value is only available after a short while.
    #[test]
    fn test_poll_multiple_times() {
        let mut core = Core::new().unwrap();
        let timer = Timer::default();
        let mut timeout = timer.sleep(Duration::from_millis(400));

        {
            let future1 = super::new(&mut timeout);
            let res1 = core.run(future1);
            assert_eq!(res1, Ok(None));
        }

        ::std::thread::sleep(Duration::from_millis(500));

        {
            let future2 = super::new(&mut timeout);
            let res2 = core.run(future2);
            assert_eq!(res2, Ok(Some(())));
        }
    }
}
