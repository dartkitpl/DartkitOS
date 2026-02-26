use std::time::Duration;

use gpiocdev::line::EdgeKind::{Falling, Rising};
use gpiocdev::line::{Bias, EdgeDetection};
use gpiocdev::Request;
use gpiocdev::tokio::AsyncRequest;

#[tokio::main(flavor = "current_thread")]
async fn main() -> anyhow::Result<()> {
    // BCM GPIO number (not physical pin number!)
    // GPIO 4
    let gpio_line: u32 = 4;

    let req = AsyncRequest::new(Request::builder()
        .on_chip("/dev/gpiochip0")
        .with_line(gpio_line)
        .as_active_low()
        .with_bias(Bias::PullUp)
        .with_edge_detection(EdgeDetection::BothEdges)
        .with_consumer("gpio-button")
        .with_debounce_period(Duration::from_millis(50))
        .request()?);

    println!("Listening on GPIO {}...", gpio_line);

    loop {
        let event = match req.read_edge_event().await {
            Ok(event) => event,
            Err(e) => {
                eprintln!("Error reading edge event: {}", e);
                continue;
            }
        };

        match event.kind {
            Rising => println!("Rising edge detected!"),
            Falling => println!("Falling edge detected!"),
        }
    }
}
