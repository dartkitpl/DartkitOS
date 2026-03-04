use std::process::Command;
use std::time::Duration;

use button_handler::button::Button;

/// Character device path for the GPIO chip (e.g. `"/dev/gpiochip0"`).
const CHIP_PATH: &str = "/dev/gpiochip0";

/// BCM GPIO line offset to listen on (not physical pin number!).
const GPIO_LINE: u32 = 4;

/// Duration the button must be held before the on_hold callback fires.
const HOLD_DURATION: Duration = Duration::from_secs(5);

/// Runs the wifi-reset script to reset Wi-Fi configuration.
/// This stops dependent services, removes the setup marker, and restarts wifi-setup.
fn reset_wifi_config() {
    println!("Running wifi-reset script...");

    match Command::new("wifi-reset").status() {
        Ok(s) if s.success() => println!("wifi-reset completed successfully"),
        Ok(s) => eprintln!("wifi-reset exited with: {}", s),
        Err(e) => eprintln!("Failed to run wifi-reset: {}", e),
    }
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> anyhow::Result<()> {
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
