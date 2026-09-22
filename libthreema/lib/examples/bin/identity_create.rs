//! Example for creating a new Threema ID.
#![expect(unused_crate_dependencies, reason = "Example triggered false positive")]
#![expect(clippy::print_stdout, reason = "Examples are allowed to print")]

use clap::{ArgAction, Parser};
use libthreema::{
    cli::config::{CommonConfig, CommonConfigOptions},
    common::ClientInfo,
    csp_e2e::identity::create::{
        CreateIdentityContext, CreateIdentityLoop, CreateIdentityResponse, CreateIdentityResult,
        CreateIdentityTask,
    },
    https::cli::https_client_builder,
    utils::logging::init_stderr_logging,
};
use libthreema_dependencies::data_encoding::HEXLOWER_PERMISSIVE;
use tracing::Level;

#[derive(Parser)]
#[command()]
struct CreateIdentityCommand {
    #[command(flatten)]
    config: CommonConfigOptions,

    /// Turn on debugging information.
    /// Use -v -vv to control log level.
    #[arg(short, action = ArgAction::Count)]
    verbose: u8,
}

async fn run_create_identity(
    http_client: reqwest::Client,
    context: CreateIdentityContext,
) -> anyhow::Result<CreateIdentityResult> {
    let mut task = CreateIdentityTask::new(context);
    loop {
        match task.poll()? {
            CreateIdentityLoop::Instruction(instruction) => {
                let result = instruction.request.send(&http_client).await;
                task.response(CreateIdentityResponse { result })?;
            },

            CreateIdentityLoop::Done(result) => return Ok(result),
        }
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Parse arguments for command
    let arguments = CreateIdentityCommand::parse();

    // Configure logging
    let log_level = match arguments.verbose {
        1 => Level::DEBUG,
        2 => Level::TRACE,
        _ => Level::INFO,
    };
    init_stderr_logging(log_level);

    // Create HTTP client
    let http_client = https_client_builder().build()?;
    let config = CommonConfig::from_options(&http_client, arguments.config).await?;

    // Create identity
    let CreateIdentityResult {
        identity,
        client_key,
        server_group,
    } = run_create_identity(
        http_client,
        CreateIdentityContext {
            client_info: ClientInfo::Libthreema,
            config: config.config,
            flavor: config.flavor,
        },
    )
    .await?;
    println!("--threema-id {identity}");
    println!(
        "--client-key {}",
        HEXLOWER_PERMISSIVE.encode(client_key.as_bytes())
    );
    println!("--csp-server-group {}", server_group.as_str());
    Ok(())
}

#[test]
fn verify_cli() {
    use clap::CommandFactory;
    CreateIdentityCommand::command().debug_assert();
}
