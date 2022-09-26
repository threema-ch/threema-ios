use saltyrtc_client::dep::futures::{Future, Poll, Async};

/// Combines three different futures yielding the same item and error
/// types into a single type.
#[derive(Debug)]
pub enum Either3<A, B, C> {
    /// First branch of the type
    A(A),
    /// Second branch of the type
    B(B),
    /// Third branch of the type
    C(C),
}


/// Future that waits for one of multiple futures (all relevant to a connection)
/// to complete. The futures are polled in order.
#[must_use = "futures do nothing unless polled"]
#[derive(Debug)]
pub struct Connection<A, B, C> {
    inner: Option<(A, B, C)>,
}

pub fn new<A, B, C>(a: A, b: B, c: C) -> Connection<A, B, C> {
    Connection { inner: Some((a, b, c)) }
}

impl<A, B, C> Future for Connection<A, B, C> where A: Future, B: Future, C: Future {
    type Item = Either3<A::Item, B::Item, C::Item>;
    type Error = Either3<A::Error, B::Error, C::Error>;

    fn poll(&mut self) -> Poll<Self::Item, Self::Error> {
        let (mut a, mut b, mut c) = self.inner.take().expect("cannot poll Connection twice");
        match a.poll() {
            // Poll future A
            Err(e) => Err(Either3::A(e)),
            Ok(Async::Ready(aok)) => Ok(Async::Ready(Either3::A(aok))),
            Ok(Async::NotReady) => match b.poll() {
                // Future A is not ready, poll future B
                Err(e) => Err(Either3::B(e)),
                Ok(Async::Ready(bok)) => Ok(Async::Ready(Either3::B(bok))),
                Ok(Async::NotReady) => match c.poll() {
                    // Future C is not ready, poll future C
                    Err(e) => Err(Either3::C(e)),
                    Ok(Async::Ready(cok)) => Ok(Async::Ready(Either3::C(cok))),
                    Ok(Async::NotReady) => {
                        // No future is ready
                        self.inner = Some((a, b, c));
                        Ok(Async::NotReady)
                    }
                }
            }
        }
    }
}
