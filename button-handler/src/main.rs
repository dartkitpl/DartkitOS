use std::process::Command;
use std::time::Duration;

use button_handler::button::Button;

/// Character device path for the GPIO chip (e.g. `"/dev/gpiochip0"`).
const CHIP_PATH: &str = "/dev/gpiochip0";

/// BCM GPIO line offset to listen on (not physical pin number!).
const GPIO_LINE: u32 = 4;

/// Duration the button must be held before the on_hold callback fires.
const HOLD_DURATION: Duration = Duration::from_secs(5);

const RESET_CMD: &str = "wifi-reset";

/// Checks if the wifi-reset command exists and is executable.
fn check_cmd_runnable() -> anyhow::Result<()> {
    match Command::new(RESET_CMD).arg("--help").status() {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => anyhow::bail!("{} --help exited with: {}", RESET_CMD, s),
        Err(e) => anyhow::bail!("Failed to run {} --help: {}", RESET_CMD, e),
    }
}

/// Runs the wifi-reset script to reset Wi-Fi configuration.
/// This stops dependent services, removes the setup marker, and restarts wifi-setup.
fn reset_wifi_config() {
    println!("Running {} command...", RESET_CMD);

    match Command::new(RESET_CMD).status() {
        Ok(s) if s.success() => println!("{} completed successfully", RESET_CMD),
        Ok(s) => eprintln!("{} exited with: {}", RESET_CMD, s),
        Err(e) => eprintln!("Failed to run {}: {}", RESET_CMD, e),
    }
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> anyhow::Result<()> {
    check_cmd_runnable()?;

    Button::new(CHIP_PATH, GPIO_LINE)
        .hold_duration(HOLD_DURATION)
        .on_press(|| {
            println!("Button pressed!");
        })
        .on_release(|| {
            println!("Button released!");
        })
        .on_hold(|| {
            println!("Button held for {} seconds! Triggering Wi-Fi reset...", HOLD_DURATION.as_secs());
            reset_wifi_config();
        })
        .listen()
        .await
}
