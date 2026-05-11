//! Bindings for the _Connection Rendezvous Protocol_.
use js_sys::Error;
use serde::Serialize;
use serde_bytes::ByteBuf;
use tsify::Tsify;
use wasm_bindgen::prelude::*;

use crate::d2d_rendezvous::{self, RendezvousAuthenticationKey};

/// Binding version of [`d2d_rendezvous::RendezvousPathStateUpdate`].
#[derive(Tsify, Serialize)]
#[serde(tag = "state", rename_all = "kebab-case", rename_all_fields = "camelCase")]
#[tsify(into_wasm_abi)]
pub enum RendezvousPathStateUpdate {
    #[expect(missing_docs, reason = "Binding version")]
    AwaitingNominate { measured_rtt_ms: u32 },

    #[expect(missing_docs, reason = "Binding version")]
    Nominated { rph: ByteBuf },
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
            d2d_rendezvous::RendezvousPathStateUpdate::Nominated { rph } => Self::Nominated {
                rph: ByteBuf::from(rph.0.to_vec()),
            },
        }
    }
}

/// Binding version of [`d2d_rendezvous::RendezvousPathProcessResult`].
#[derive(Tsify, Serialize)]
#[serde(rename_all = "camelCase")]
#[tsify(into_wasm_abi)]
pub struct RendezvousPathProcessResult {
    /// Binding version of [`d2d_rendezvous::RendezvousPathProcessResult::state_update`].
    pub state_update: Option<RendezvousPathStateUpdate>,

    /// Binding version of [`d2d_rendezvous::RendezvousPathProcessResult::outgoing_frame`].
    pub outgoing_frame: Option<ByteBuf>,

    /// Binding version of [`d2d_rendezvous::RendezvousPathProcessResult::incoming_ulp_data`].
    pub incoming_ulp_data: Option<ByteBuf>,
}

impl From<d2d_rendezvous::RendezvousPathProcessResult> for RendezvousPathProcessResult {
    fn from(result: d2d_rendezvous::RendezvousPathProcessResult) -> Self {
        Self {
            state_update: result.state_update.map(RendezvousPathStateUpdate::from),
            outgoing_frame: result
                .outgoing_frame
                .map(|outgoing_frame| Vec::<u8>::from(outgoing_frame).into()),
            incoming_ulp_data: result.incoming_ulp_data.map(Into::into),
        }
    }
}

/// A list of outgoing frames to be enqueued on the respective paths.
#[derive(Clone, Tsify, Serialize)]
#[tsify(into_wasm_abi)]
pub struct RendezvousOutgoingFrames(Vec<RendezvousOutgoingFrame>);

impl From<Vec<(u32, d2d_rendezvous::RendezvousOutgoingFrame)>> for RendezvousOutgoingFrames {
    fn from(frames: Vec<(u32, d2d_rendezvous::RendezvousOutgoingFrame)>) -> Self {
        Self(frames.into_iter().map(RendezvousOutgoingFrame::from).collect())
    }
}

/// An outgoing frame for an explicit path PID.
#[derive(Clone, Tsify, Serialize)]
#[serde(rename_all = "camelCase")]
#[tsify(into_wasm_abi)]
pub struct RendezvousOutgoingFrame {
    /// The path's PID the outgoing frame should be sent on.
    pub pid: u32,

    /// The outgoing frame.
    pub frame: ByteBuf,
}

impl From<(u32, d2d_rendezvous::RendezvousOutgoingFrame)> for RendezvousOutgoingFrame {
    fn from((pid, frame): (u32, d2d_rendezvous::RendezvousOutgoingFrame)) -> Self {
        Self {
            pid,
            frame: Vec::<u8>::from(frame).into(),
        }
    }
}

/// Binding version of [`d2d_rendezvous::RendezvousProtocol`].
#[wasm_bindgen]
pub struct RendezvousProtocol {
    inner: d2d_rendezvous::RendezvousProtocol,
    initial_outgoing_frames: Option<RendezvousOutgoingFrames>,
}

#[wasm_bindgen]
impl RendezvousProtocol {
    /// Binding version of [`d2d_rendezvous::RendezvousProtocol::new_as_rid`].
    ///
    /// # Errors
    ///
    /// Returns an error if `ak` is not exactly 32 bytes.
    #[wasm_bindgen(js_name = newAsRid)]
    pub fn new_as_rid(is_nominator: bool, ak: &[u8], pids: &[u32]) -> Result<RendezvousProtocol, Error> {
        let ak: [u8; 32] = ak.try_into().map_err(|_| Error::new("AK must be 32 bytes"))?;
        Ok(Self {
            inner: d2d_rendezvous::RendezvousProtocol::new_as_rid(
                is_nominator,
                RendezvousAuthenticationKey(ak),
                pids,
            ),
            initial_outgoing_frames: None,
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
    /// Returns an error if `ak` is not exactly 32 bytes.
    #[wasm_bindgen(js_name = newAsRrd)]
    pub fn new_as_rrd(is_nominator: bool, ak: &[u8], pids: &[u32]) -> Result<RendezvousProtocol, Error> {
        let ak: [u8; 32] = ak.try_into().map_err(|_| Error::new("AK must be 32 bytes"))?;
        let (inner, initial_outgoing_frames) = d2d_rendezvous::RendezvousProtocol::new_as_rrd(
            is_nominator,
            RendezvousAuthenticationKey(ak),
            pids,
        );
        Ok(Self {
            inner,
            initial_outgoing_frames: Some(RendezvousOutgoingFrames::from(initial_outgoing_frames)),
        })
    }

    /// The initial outgoing frames to be enqueued on the respective paths.
    ///
    /// Only relevant when constructing the protocol with the RRD role.
    #[wasm_bindgen(js_name = initialOutgoingFrames)]
    pub fn initial_outgoing_frames(&mut self) -> Option<RendezvousOutgoingFrames> {
        self.initial_outgoing_frames.take()
    }

    /// See [`d2d_rendezvous::RendezvousProtocol::is_nominator`].
    #[wasm_bindgen(js_name = isNominator)]
    #[must_use]
    pub fn is_nominator(&self) -> bool {
        self.inner.is_nominator()
    }

    /// See [`d2d_rendezvous::RendezvousProtocol::nominated_path`].
    #[wasm_bindgen(js_name = nominatedPath)]
    #[must_use]
    pub fn nominated_path(&self) -> Option<u32> {
        self.inner.nominated_path()
    }

    /// Binding version of [`d2d_rendezvous::RendezvousProtocol::add_chunks`].
    #[expect(clippy::missing_errors_doc, reason = "Binding version")]
    #[wasm_bindgen(js_name = addChunk)]
    pub fn add_chunk(&mut self, pid: u32, chunk: &[u8]) -> Result<(), Error> {
        self.inner
            .add_chunks(pid, &[chunk])
            .map_err(|error| Error::new(format!("Could not add chunks: {error}").as_ref()))
    }

    /// Binding version of [`d2d_rendezvous::RendezvousProtocol::process_frame`].
    #[expect(clippy::missing_errors_doc, reason = "Binding version")]
    #[wasm_bindgen(js_name = processFrame)]
    pub fn process_frame(&mut self, pid: u32) -> Result<Option<RendezvousPathProcessResult>, Error> {
        self.inner
            .process_frame(pid)
            .map(|result| result.map(RendezvousPathProcessResult::from))
            .map_err(|error| Error::new(format!("Could not process frame: {error}").as_ref()))
    }

    /// Binding version of [`d2d_rendezvous::RendezvousProtocol::nominate_path`].
    #[expect(clippy::missing_errors_doc, reason = "Binding version")]
    #[wasm_bindgen(js_name = nominatePath)]
    pub fn nominate_path(&mut self, pid: u32) -> Result<RendezvousPathProcessResult, Error> {
        self.inner
            .nominate_path(pid)
            .map(RendezvousPathProcessResult::from)
            .map_err(|error| Error::new(format!("Could not nominate path: {error}").as_ref()))
    }

    /// Binding version of [`d2d_rendezvous::RendezvousProtocol::create_ulp_frame`].
    #[expect(clippy::missing_errors_doc, reason = "Binding version")]
    #[wasm_bindgen(js_name = createUlpFrame)]
    pub fn create_ulp_frame(&mut self, outgoing_data: Vec<u8>) -> Result<RendezvousPathProcessResult, Error> {
        self.inner
            .create_ulp_frame(outgoing_data)
            .map(RendezvousPathProcessResult::from)
            .map_err(|error| Error::new(format!("Could not create ULP frame: {error}").as_ref()))
    }
}
