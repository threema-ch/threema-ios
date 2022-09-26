extern crate byteorder;
extern crate clap;
extern crate data_encoding;
extern crate env_logger;
#[macro_use] extern crate log;
extern crate qrcodegen;
extern crate saltyrtc_client;
extern crate saltyrtc_task_relayed_data;
extern crate tokio_core;

use std::env;
use std::io::Write;
use std::process;
use std::sync::{Arc, RwLock};
use std::time::Duration;

use byteorder::{BigEndian, WriteBytesExt};
use clap::{Arg, App, SubCommand};
use data_encoding::{HEXLOWER, HEXLOWER_PERMISSIVE, BASE64};
use qrcodegen::{QrCode, QrCodeEcc};
use saltyrtc_client::{SaltyClient, Role, BoxedFuture};
use saltyrtc_client::crypto::{KeyPair, AuthToken, public_key_from_hex_str};
use saltyrtc_client::dep::futures::{future, Future, Stream};
use saltyrtc_client::dep::futures::sync::mpsc;
use saltyrtc_client::dep::native_tls::{TlsConnector, Protocol};
use saltyrtc_client::tasks::Task;
use saltyrtc_task_relayed_data::{RelayedDataTask, RelayedDataError, MessageEvent};
use tokio_core::reactor::Core;

const ARG_PING_INTERVAL: &str = "ping_interval";
const ARG_SRV_HOST: &str = "host";
const ARG_SRV_PORT: &str = "port";
const ARG_SRV_PUBKEY: &str = "pubkey";
const ARG_PATH: &str = "path";
const ARG_AUTHTOKEN: &str = "auth_token";
const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Wrap future in a box with type erasure.
macro_rules! boxed {
    ($future:expr) => {{
        Box::new($future) as BoxedFuture<_, _>
    }}
}

/// Create the QR code payload
fn make_qrcode_payload(version: u16, permanent: bool, host: &str, port: u16, pubkey: &[u8], auth_token: &[u8], server_pubkey: &[u8]) -> Vec<u8> {
    let mut data: Vec<u8> = Vec::with_capacity(101 + host.as_bytes().len());

    data.write_u16::<BigEndian>(version).unwrap();
    data.push(if permanent { 0x02 } else { 0x00 });
    data.write_all(pubkey).unwrap();
    data.write_all(auth_token).unwrap();
    data.write_all(server_pubkey).unwrap();
    data.write_u16::<BigEndian>(port).unwrap();
    data.write_all(host.as_bytes()).unwrap();

    data
}

/// Print the QR code payload to the terminal
fn print_qrcode(payload: &[u8]) {
    let base64 = BASE64.encode(payload);
    let qr = QrCode::encode_text(&base64, QrCodeEcc::Low).unwrap();
    let border = 1;
    for y in -border .. qr.size() + border {
        for x in -border .. qr.size() + border {
            let c: char = if qr.get_module(x, y) { '█' } else { ' ' };
            print!("{0}{0}", c);
        }
        println!();
    }
    println!();
}

fn main() {

    // Set up CLI arguments
    let arg_srv_host = Arg::with_name(ARG_SRV_HOST)
        .short("h")
        .takes_value(true)
        .value_name("SRV_HOST")
        .required(true)
        .default_value("server.saltyrtc.org")
        .help("The SaltyRTC server hostname");
    let arg_srv_port = Arg::with_name(ARG_SRV_PORT)
        .short("p")
        .takes_value(true)
        .value_name("SRV_PORT")
        .required(true)
        .default_value("443")
        .help("The SaltyRTC server port");
    let arg_srv_pubkey = Arg::with_name(ARG_SRV_PUBKEY)
        .short("s")
        .takes_value(true)
        .value_name("SRV_PUBKEY")
        .required(true)
        .default_value("f77fe623b6977d470ac8c7bf7011c4ad08a1d126896795db9d2b4b7a49ae1045")
        .help("The SaltyRTC server public permanent key");
    let arg_ping_interval = Arg::with_name(ARG_PING_INTERVAL)
        .short("i")
        .takes_value(true)
        .value_name("SECONDS")
        .required(false)
        .default_value("60")
        .help("The WebSocket ping interval (set to 0 to disable pings)");
    let app = App::new("SaltyRTC Relayed Data Test Initiator")
        .version(VERSION)
        .author("Danilo Bargen <mail@dbrgn.ch>")
        .about("Test client for SaltyRTC Relayed Data Task.")
        .subcommand(SubCommand::with_name("initiator")
            .about("Start client as initiator")
            .arg(arg_srv_host.clone())
            .arg(arg_srv_port.clone())
            .arg(arg_srv_pubkey.clone())
            .arg(arg_ping_interval.clone()))
        .subcommand(SubCommand::with_name("responder")
            .about("Start client as responder")
            .arg(Arg::with_name(ARG_PATH)
                .short("k")
                .takes_value(true)
                .value_name("INITIATOR_PUBKEY")
                .required(true)
                .help("The hex encoded public key of the initiator"))
            .arg(Arg::with_name(ARG_AUTHTOKEN)
                .short("a")
                .alias("token")
                .alias("authtoken")
                .takes_value(true)
                .value_name("AUTHTOKEN")
                .required(true)
                .help("The auth token (hex encoded)"))
            .arg(arg_srv_host)
            .arg(arg_srv_port)
            .arg(arg_srv_pubkey)
            .arg(arg_ping_interval));

    // Parse arguments
    let subcommand = app.get_matches().subcommand.unwrap_or_else(|| {
        println!("Missing subcommand.");
        println!("Use -h or --help to see usage.");
        process::exit(1);
    });
    let args = &subcommand.matches;

    // Determine role
    let role = match &*subcommand.name {
        "initiator" => Role::Initiator,
        "responder" => Role::Responder,
        other => {
            println!("Invalid subcommand: {}", other);
            process::exit(1);
        },
    };

    // Set up logging
    env::set_var("RUST_LOG", "saltyrtc_client=debug,saltyrtc_task_relayed_data=debug,testclient=trace");
    env_logger::init();

    // Tokio reactor core
    let mut core = Core::new().unwrap();

    // Create TLS connector instance
    let tls_connector = TlsConnector::builder()
        .min_protocol_version(Some(Protocol::Tlsv11))
        .build()
        .unwrap_or_else(|e| panic!("Could not initialize TlsConnector: {}", e));

    // Create new public permanent keypair
    let keypair = KeyPair::new();
    let pubkey = keypair.public_key().clone();

    // Determine websocket path
    let path: String = match role {
        Role::Initiator => keypair.public_key_hex(),
        Role::Responder => args.value_of(ARG_PATH).expect("Initiator pubkey not supplied").to_lowercase(),
    };

    // Determine ping interval
    let ping_interval = {
        let seconds: u64 = args.value_of(ARG_PING_INTERVAL).expect("Ping interval not supplied")
                               .parse().expect("Could not parse interval seconds to a number");
        Duration::from_secs(seconds)
    };

    // Determine server info
    let server_host: &str = args.value_of(ARG_SRV_HOST).expect("Server hostname not supplied");
    let server_port: u16 = args.value_of(ARG_SRV_PORT).expect("Server port not supplied").parse().expect("Could not parse port to a number");
    let server_pubkey: Vec<u8> = HEXLOWER_PERMISSIVE.decode(
        args.value_of(ARG_SRV_PUBKEY).expect("Server pubkey not supplied").as_bytes()
    ).unwrap();

    // Set up task instance
    let (incoming_tx, incoming_rx) = mpsc::unbounded();
    let task = RelayedDataTask::new(core.remote(), incoming_tx);

    // Set up client instance
    let client = Arc::new(RwLock::new({
        let builder = SaltyClient::build(keypair)
            .add_task(Box::new(task))
            .with_ping_interval(Some(ping_interval));
        match role {
            Role::Initiator => builder
                .initiator()
                .expect("Could not create SaltyClient instance"),
            Role::Responder => {
                let auth_token_hex = args.value_of(ARG_AUTHTOKEN).expect("Auth token not supplied").to_string();
                let auth_token = AuthToken::from_hex_str(&auth_token_hex).expect("Invalid auth token hex string");
                let initiator_pubkey = public_key_from_hex_str(&path).unwrap();
                builder
                    .responder(initiator_pubkey, auth_token)
                    .expect("Could not create SaltyClient instance")
            }
        }
    }));

    // Connect future
    let (connect_future, event_channel) = saltyrtc_client::connect(
        server_host,
        server_port,
        Some(tls_connector),
        &core.handle(),
        client.clone(),
    )
    .unwrap();

    // Handshake future
    let event_tx = event_channel.clone_tx();
    let handshake_future = connect_future
        .and_then(|ws_client| saltyrtc_client::do_handshake(ws_client, client.clone(), event_tx, None));

    // Determine QR code payload
    let payload = make_qrcode_payload(
        1,
        false,
        server_host,
        server_port,
        pubkey.as_bytes(),
        client.read().unwrap().auth_token().unwrap().secret_key_bytes(),
        &server_pubkey,
    );

    // Print connection info
    println!("\n#====================#");
    println!("Host: {}:{}", server_host, server_port);
    match role {
        Role::Initiator => {
            println!("Pubkey: {}", HEXLOWER.encode(pubkey.as_bytes()));
            println!("Auth token: {}", HEXLOWER.encode(client.read().unwrap().auth_token().unwrap().secret_key_bytes()));
            println!();
            println!("QR Code:");
            print_qrcode(&payload);
            println!("{}", BASE64.encode(&payload));
            println!("\n#====================#\n");
        }
        Role::Responder => {
            println!("Pubkey: {}", args.value_of(ARG_AUTHTOKEN).expect("Auth token not supplied").to_string());
            println!("#====================#\n");
        }
    }

    // Run connect future to completion
    let ws_client = core.run(handshake_future).expect("Could not connect");

    // Setup task loop
    let event_tx = event_channel.clone_tx();
    let (task, task_loop) = saltyrtc_client::task_loop(ws_client, client.clone(), event_tx).unwrap();

    // Get access to outgoing channel
    let _outgoing_tx = {
        // Get reference to task and downcast it to `RelayedDataTask`.
        // We can be sure that it's a `RelayedDataTask` since that's the only one we proposed.
        let mut t = task.lock().expect("Could not lock task mutex");
        let rd_task: &mut RelayedDataTask = (&mut **t as &mut dyn Task)
            .downcast_mut::<RelayedDataTask>()
            .expect("Chosen task is not a RelayedDataTask");

        // Get unbounded senders for outgoing messages
        rd_task.get_sender().unwrap()
    };

    // Print all incoming events to stdout
    let recv_loop = incoming_rx
        .map_err(|_| Err(RelayedDataError::Channel(("Could not read from rx_responder").into())))
        .for_each(move |ev: MessageEvent| match ev {
            MessageEvent::Data(data) => {
                println!("Incoming data message: {}", data);
                boxed!(future::ok(()))
            },
            MessageEvent::Application(data) => {
                println!("Incoming application message: {}", data);
                boxed!(future::ok(()))
            },
            MessageEvent::Close(reason) => {
                println!("Connection was closed: {}", reason);
                boxed!(future::err(Ok(())))
            }
        })
        .or_else(|e| e)
        .then(|f| { debug!("† recv_loop done"); f });

    match core.run(
        task_loop
            .map_err(|e| e.to_string())
            .then(|f| { debug!("† task_loop done"); f })
            .join(recv_loop.map_err(|e| e.to_string()))
    ) {
        Ok(_) => info!("Done."),
        Err(e) => panic!("Error: {}", e),
    };
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_make_qrcode_data() {
        let pubkey = HEXLOWER.decode(b"4242424242424242424242424242424242424242424242424242424242424242").unwrap();
        let auth_token = HEXLOWER.decode(b"2323232323232323232323232323232323232323232323232323232323232323").unwrap();
        let server_pubkey = HEXLOWER.decode(b"1337133713371337133713371337133713371337133713371337133713371337").unwrap();
        let data = make_qrcode_payload(1337, true, "saltyrtc.example.org", 1234, &pubkey, &auth_token, &server_pubkey);
        let expected = BASE64.decode(b"BTkCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkIjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIxM3EzcTNxM3EzcTNxM3EzcTNxM3EzcTNxM3EzcTNxM3BNJzYWx0eXJ0Yy5leGFtcGxlLm9yZw==").unwrap();
        assert_eq!(data, expected);
    }
}
