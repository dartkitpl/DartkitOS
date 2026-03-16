use clap::{Parser, Subcommand};
use gpio_handlers::led::Led;
use std::time::Duration;
use tokio::signal;
use tokio::signal::unix::{SignalKind, signal};

/// Character device path for the GPIO chip (e.g. `"/dev/gpiochip0"`).
const CHIP_PATH: &str = "/dev/gpiochip0";

/// BCM GPIO line offset to control (not physical pin number!).
const GPIO_LINE: u32 = 17;

#[derive(Parser)]
#[command(version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Turn the LED on
    On,
    /// Turn the LED off
    Off,
    /// Blink the LED
    Blink {
        /// Blink duration in milliseconds
        #[arg(short = 'd', long = "duration", default_value_t = 500)]
        duration: u64,
        /// Number of times to blink (omit for infinite)
        #[arg(short = 'n', long = "count")]
        count: Option<usize>,
    },
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    // Default active_low to false (Active High = LED On)
    let led = Led::new(CHIP_PATH, GPIO_LINE, false)?;

    match cli.command {
        Commands::On => {
            led.on()?;
            println!("LED turned ON (Active High).");
        }
        Commands::Off => {
            led.off()?;
            println!("LED turned OFF.");
        }
        Commands::Blink { duration, count } => {
            println!(
                "Blinking LED every {}ms ({})",
                duration,
                count.map_or("until ctrl-c".to_string(), |c| format!("{} times", c))
            );

            let mut sigterm = signal(SignalKind::terminate())?;

            tokio::select! {
                res = led.blink(Duration::from_millis(duration), Duration::from_millis(duration), count) => {
                    res?;
                }
                _ = signal::ctrl_c() => {
                    println!("Binking stop requested (SIGINT).");
                }
                _ = sigterm.recv() => {
                    println!("Binking stop requested (SIGTERM).");
                }
            }
            // Explicitly turn off before exiting
            led.off()?;
        }
    }

    Ok(())
}
