//! Bindings for the _Connection Rendezvous Protocol_.
use std::sync::Mutex;

use crate::{
    d2d_rendezvous::{self, RendezvousProtocolError},
    utils::sync::MutexIgnorePoison as _,
};

/// Binding version of [`d2d_rendezvous::RendezvousPathStateUpdate`].
#[derive(uniffi::Enum)]
pub enum RendezvousPathStateUpdate {
    #[expect(missing_docs, reason = "Binding version")]
    AwaitingNominate { measured_rtt_ms: u32 },

    #[expect(missing_docs, reason = "Binding version")]
    Nominated { rph: Vec<u8> },
}

impl From<d2d_rendezvous::RendezvousPathStateUpdate> for RendezvousPathStateUpdate {
    fn from(update: d2d_rendezvous::RendezvousPathStateUpdate) -> Self {
        match update {
            d2d_rendezvous::RendezvousPathStateUpdate::AwaitingNominate { measured_rtt } => {
                Self::AwaitingNominate {
                    measured_rtt_ms: measured_rtt
                        .as_millis()
                        .try_into()
                        .expect("measured_rtt should not exceed a u32"),
                }
            },
            d2d_rendezvous::RendezvousPathStateUpdate::Nominated { rph } => {
                Self::Nominated { rph: rph.0.to_vec() }
            },
        }
    }
}

/// Binding version of [`d2d_rendezvous::RendezvousPathProcessResult`].
#[derive(uniffi::Record)]
pub struct RendezvousPathProcessResult {
    #[expect(missing_docs, reason = "Binding version")]
    pub state_update: Option<RendezvousPathStateUpdate>,

    #[expect(missing_docs, reason = "Binding version")]
    pub outgoing_frame: Option<Vec<u8>>,

    #[expect(missing_docs, reason = "Binding version")]
    pub incoming_ulp_data: Option<Vec<u8>>,
}

impl From<d2d_rendezvous::RendezvousPathProcessResult> for RendezvousPathProcessResult {
    fn from(result: d2d_rendezvous::RendezvousPathProcessResult) -> Self {
        Self {
            state_update: result.state_update.map(RendezvousPathStateUpdate::from),
            outgoing_frame: result.outgoing_frame.map(Into::into),
            incoming_ulp_data: result.incoming_ulp_data,
        }
    }
}

/// An outgoing frame for an explicit path PID.
#[derive(Clone, uniffi::Record)]
pub struct RendezvousOutgoingFrame {
    /// The path's PID the outgoing frame should be sent on.
    pub pid: u32,

    /// The outgoing frame.
    pub frame: Vec<u8>,
}

impl From<(u32, d2d_rendezvous::RendezvousOutgoingFrame)> for RendezvousOutgoingFrame {
    fn from((pid, frame): (u32, d2d_rendezvous::RendezvousOutgoingFrame)) -> Self {
        Self {
            pid,
            frame: frame.into(),
        }
    }
}

/// Binding version of [`d2d_rendezvous::RendezvousProtocol`].
#[derive(uniffi::Object)]
pub struct RendezvousProtocol {
    inner: Mutex<d2d_rendezvous::RendezvousProtocol>,
    initial_outgoing_frames: Mutex<Option<Vec<RendezvousOutgoingFrame>>>,
}

#[uniffi::export]
impl RendezvousProtocol {
    /// Binding version of [`d2d_rendezvous::RendezvousProtocol::new_as_rid`].
    ///
    /// # Errors
    ///
    /// Returns [`RendezvousProtocolError::InvalidParameter`] if `ak` is not exactly 32 bytes.
    #[uniffi::constructor]
    pub fn new_as_rid(
        is_nominator: bool,
        ak: Vec<u8>,
        pids: &[u32],
    ) -> Result<Self, RendezvousProtocolError> {
        let ak: [u8; 32] = ak
            .try_into()
            .map_err(|_| RendezvousProtocolError::InvalidParameter("'ak' must be 32 bytes"))?;
        Ok(Self {
            inner: Mutex::new(d2d_rendezvous::RendezvousProtocol::new_as_rid(
                is_nominator,
                d2d_rendezvous::RendezvousAuthenticationKey(ak),
                pids,
            )),
            initial_outgoing_frames: Mutex::new(None),
        })
    }

    /// Binding version of [`d2d_rendezvous::RendezvousProtocol::new_as_rrd`].
    ///
    /// # Deviations
    ///
    /// Only returns the protocol state machine instance. The initial outgoing frames must be
    /// fetched from [`RendezvousProtocol::initial_outgoing_frames`] to be enqueued on the
    /// respective paths immediately.
    ///
    /// # Errors
    ///
    /// Returns [`RendezvousProtocolError::InvalidParameter`] if `ak` is not exactly 32 bytes.
    #[uniffi::constructor]
    pub fn new_as_rrd(
        is_nominator: bool,
        ak: Vec<u8>,
        pids: &[u32],
    ) -> Result<Self, RendezvousProtocolError> {
        let ak: [u8; 32] = ak
            .try_into()
            .map_err(|_| RendezvousProtocolError::InvalidParameter("'ak' must be 32 bytes"))?;
        let (inner, initial_outgoing_frames) = d2d_rendezvous::RendezvousProtocol::new_as_rrd(
            is_nominator,
            d2d_rendezvous::RendezvousAuthenticationKey(ak),
            pids,
        );
        Ok(Self {
            inner: Mutex::new(inner),
            initial_outgoing_frames: Mutex::new(Some(
                initial_outgoing_frames
                    .into_iter()
                    .map(RendezvousOutgoingFrame::from)
                    .collect(),
            )),
        })
    }

    /// The initial outgoing frames to be enqueued on the respective paths.
    ///
    /// Only relevant when constructing the protocol with the RRD role.
    pub fn initial_outgoing_frames(&self) -> Option<Vec<RendezvousOutgoingFrame>> {
        self.initial_outgoing_frames.lock_ignore_poison().take()
    }

    /// See [`d2d_rendezvous::RendezvousProtocol::is_nominator`].
    #[must_use]
    fn is_nominator(&self) -> bool {
        self.inner.lock_ignore_poison().is_nominator()
    }

    /// See [`d2d_rendezvous::RendezvousProtocol::nominated_path`].
    #[must_use]
    pub fn nominated_path(&self) -> Option<u32> {
        self.inner.lock_ignore_poison().nominated_path()
    }

    /// Binding version of [`d2d_rendezvous::RendezvousProtocol::add_chunks`].
    #[expect(
        clippy::missing_errors_doc,
        clippy::needless_pass_by_value,
        reason = "Binding version"
    )]
    pub fn add_chunks(&self, pid: u32, chunks: Vec<Vec<u8>>) -> Result<(), RendezvousProtocolError> {
        let chunks: Vec<&[u8]> = chunks.iter().map(Vec::as_slice).collect();
        self.inner.lock_ignore_poison().add_chunks(pid, &chunks)
    }

    /// Binding version of [`RendezvousProtocol::process_frame`].
    #[expect(clippy::missing_errors_doc, reason = "Binding version")]
    pub fn process_frame(
        &self,
        pid: u32,
    ) -> Result<Option<RendezvousPathProcessResult>, RendezvousProtocolError> {
        self.inner
            .lock_ignore_poison()
            .process_frame(pid)
            .map(|result| result.map(RendezvousPathProcessResult::from))
    }

    /// Binding version of [`RendezvousProtocol::nominate_path`].
    #[expect(clippy::missing_errors_doc, reason = "Binding version")]
    pub fn nominate_path(&self, pid: u32) -> Result<RendezvousPathProcessResult, RendezvousProtocolError> {
        self.inner
            .lock_ignore_poison()
            .nominate_path(pid)
            .map(RendezvousPathProcessResult::from)
    }

    /// Binding version of [`RendezvousProtocol::create_ulp_frame`].
    #[expect(clippy::missing_errors_doc, reason = "Binding version")]
    pub fn create_ulp_frame(
        &self,
        outgoing_data: Vec<u8>,
    ) -> Result<RendezvousPathProcessResult, RendezvousProtocolError> {
        self.inner
            .lock_ignore_poison()
            .create_ulp_frame(outgoing_data)
            .map(RendezvousPathProcessResult::from)
    }
}
