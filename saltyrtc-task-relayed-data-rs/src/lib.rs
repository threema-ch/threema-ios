#[macro_use] extern crate failure;
#[macro_use] extern crate log;
extern crate saltyrtc_client;
extern crate tokio_core;

use std::borrow::Cow;
use std::collections::HashMap;
use std::mem;

use saltyrtc_client::{CloseCode, BoxedFuture};
use saltyrtc_client::dep::futures::future;
use saltyrtc_client::dep::futures::{Stream, Sink, Future};
use saltyrtc_client::dep::futures::sync::mpsc::{self, UnboundedSender, UnboundedReceiver};
use saltyrtc_client::dep::futures::sync::oneshot::Sender as OneshotSender;
use saltyrtc_client::dep::rmpv::Value;
use saltyrtc_client::errors::Error;
use saltyrtc_client::tasks::{Task, TaskMessage};
use tokio_core::reactor::Remote;

mod errors;

pub use errors::{RelayedDataError, RelayedDataResult};


static TASK_NAME: &'static str = "v0.relayed-data.tasks.saltyrtc.org";
const TYPE_DATA: &'static str = "data";
const KEY_TYPE: &'static str = "type";
const KEY_PAYLOAD: &'static str = "p";


/// Wrap future in a box with type erasure.
macro_rules! boxed {
    ($future:expr) => {{
        Box::new($future) as BoxedFuture<_, _>
    }}
}


/// An implementation of the
/// [Relayed Data Task](https://github.com/saltyrtc/saltyrtc-meta/blob/master/Task-RelayedData.md).
///
/// This task uses the end-to-end encrypted WebSocket connection set up by
/// the SaltyRTC protocol to send user defined messages.
#[derive(Debug)]
pub struct RelayedDataTask {
    /// A remote handle so that tasks can be enqueued in the reactor core.
    remote: Remote,

    /// The connection state, either started or stopped.
    /// The connection context is embedded in `State::Started`.
    state: State,

    /// The sending end of a channel to send incoming messages and events to
    /// the task user.
    incoming_tx: UnboundedSender<MessageEvent>,
}

#[derive(Debug)]
pub enum State {
    Stopped,
    Started(ConnectionContext),
}

#[derive(Debug)]
pub struct ConnectionContext {
    outgoing_tx: UnboundedSender<TaskMessage>,
    user_outgoing_tx: UnboundedSender<OutgoingMessage>,
    disconnect_tx: OneshotSender<Option<CloseCode>>,
}

/// An incoming message event.
#[derive(Debug, Clone, PartialEq)]
pub enum MessageEvent {
    Data(Value),
    Application(Value),
    Close(CloseCode),
}

/// Outgoing data.
#[derive(Debug, Clone, PartialEq)]
pub enum OutgoingMessage {
    Data(Value),
    Application(Value),
}

impl RelayedDataTask {
    pub fn new(remote: Remote, incoming_tx: UnboundedSender<MessageEvent>) -> Self {
        RelayedDataTask {
            remote,
            state: State::Stopped,
            incoming_tx,
        }
    }

    /// Return the sending end of a channel, to be able to send outgoing values.
    pub fn get_sender(&self) -> Result<UnboundedSender<OutgoingMessage>, String> {
        match self.state {
            State::Stopped => return Err("Cannot return Sender in `Stopped` state".into()),
            State::Started(ref cctx) => Ok(cctx.user_outgoing_tx.clone()),
        }
    }
}

impl Task for RelayedDataTask {

    /// Initialize the task with the task data from the peer, sent in the `Auth` message.
    ///
    /// The task should keep track internally whether it has been initialized or not.
    fn init(&mut self, data: &Option<HashMap<String, Value>>) -> Result<(), Error> {
        match data {
            Some(map) if !map.is_empty() => {
                warn!("Task was initialized with some data, even though it should be `None`: {:?}", map);
            },
			_ => trace!("Task initialization data: {:?}", data),
        }
        Ok(())
    }

    /// Used by the signaling class to notify task that the peer handshake is done.
    ///
    /// This is the point where the task can take over.
    fn start(&mut self,
             outgoing_tx: UnboundedSender<TaskMessage>,
             incoming_rx: UnboundedReceiver<TaskMessage>,
             disconnect_tx: OneshotSender<Option<CloseCode>>) {
        info!("Relayed data task is taking over");

        // Check for current state
        if let State::Started(_) = self.state {
            panic!("The `start` method was called in `Started` state! Ignoring.");
        };

        // Update state
        let (user_outgoing_tx, user_outgoing_rx) = mpsc::unbounded::<OutgoingMessage>();
        let cctx = ConnectionContext {
            outgoing_tx: outgoing_tx.clone(),
            disconnect_tx,
            user_outgoing_tx,
        };
        self.state = State::Started(cctx);


        // TODO: Better error handling
        let user_incoming_tx = self.incoming_tx.clone();
        self.remote.spawn(move |handle| {
            let handle = handle.clone();

            // Handle incoming messages
            let incoming = incoming_rx.for_each(move |msg: TaskMessage| {
                let map: HashMap<String, Value> = match msg {
                    TaskMessage::Value(map) => map,
                    TaskMessage::Application(data) => {
                        // Send application message through channel
                        debug!("Sending application message payload through channel");
                        return boxed!(
                            user_incoming_tx
                                .clone()
                                .send(MessageEvent::Application(data))
                                .map(|_| ()) // TODO
                                .map_err(|_| ()) // TODO
                        );
                    },
                    TaskMessage::Close(reason) => {
                        // Peer is closing the connection.
                        // Notify user about this.
                        return boxed!(
                            user_incoming_tx
                                .clone()
                                .send(MessageEvent::Close(reason))
                                .map(|_| ())
                                .map_err(|_| ())
                        );
                    },
                };

                let msg_type = map
                    .get(KEY_TYPE)
                    .and_then(|v| v.as_str())
                    .expect("Message type missing");
                if msg_type != TYPE_DATA {
                    panic!("Unknown message type: {}", msg_type);
                }

                // Extract payload
                match map.get(KEY_PAYLOAD) {
                    Some(payload) => {
                        // Send payload through channel
                        let user_incoming_tx = user_incoming_tx.clone();
                        debug!("Sending {} message payload through channel", TYPE_DATA);
                        handle.spawn(
                            user_incoming_tx
                                .send(MessageEvent::Data(payload.clone()))
                                .map(|_| ()) // TODO
                                .map_err(|_| ()) // TODO
                        )
                    },
                    None => warn!("Received {} message without payload field", TYPE_DATA),
                }

                boxed!(future::ok(()))
            });

            let outgoing = user_outgoing_rx.for_each(move |msg: OutgoingMessage| {
                let task_message = match msg {
                    OutgoingMessage::Data(val) => {
                        let mut map: HashMap<String, Value> = HashMap::new();
                        map.insert(KEY_TYPE.into(), Value::String(TYPE_DATA.into()));
                        map.insert(KEY_PAYLOAD.into(), val);
                        TaskMessage::Value(map)
                    },
                    OutgoingMessage::Application(val) => TaskMessage::Application(val),
                };

                // Send message through channel
                let future = outgoing_tx
                    .clone()
                    .send(task_message)
                    .map(|_sink| ())
                    .map_err(|_| ());

                debug!("Enqueuing outgoing message");
                boxed!(future)
            });

            incoming
                .select(outgoing)
                .map(|_| ())
                .map_err(|_| ())
                .then(|_| {
                    debug!("† Relayed task send/receive loops done");
                    Ok(())
                })
        });
    }

    /// Return supported message types.
    ///
    /// Incoming messages with accepted types will be passed to the task.
    /// Otherwise, the message is dropped.
    fn supported_types(&self) -> &'static [&'static str] {
        &[TYPE_DATA]
    }

    /// Send bytes through the task signaling channel.
    ///
    /// This method should only be called after the handover.
    ///
    /// Note that the data passed in to this method should *not* already be encrypted. Otherwise,
    /// data will be encrypted twice.
    fn send_signaling_message(&self, _payload: &[u8]) {
        panic!("send_signaling_message called even though task does not implement handover");
    }

    /// Return the task protocol name.
    fn name(&self) -> Cow<'static, str> {
        TASK_NAME.into()
    }

    /// Return the task data used for negotiation in the `auth` message.
    fn data(&self) -> Option<HashMap<String, Value>> {
        None
    }

    /// This method can be called by the user to close the connection.
    fn close(&mut self, reason: CloseCode) {
        debug!("Stopping relayed data task");

        // Extract and destructure connection context
        let state = mem::replace(&mut self.state, State::Stopped);
        let cctx: ConnectionContext = match state {
            State::Stopped => return,
            State::Started(cctx) => cctx,
        };
        let ConnectionContext { disconnect_tx, .. } = cctx;

        // Shut down task loop
        let _ = disconnect_tx.send(Some(reason));
    }
}

impl Drop for RelayedDataTask {
    fn drop(&mut self) {
        trace!("Dropping RelayedDataTask");
    }
}
