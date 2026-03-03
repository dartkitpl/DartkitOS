use std::time::Duration;

use gpiocdev::line::Bias;
use gpiocdev::line::EdgeDetection;
use gpiocdev::line::EdgeKind::{Falling, Rising};
use gpiocdev::Request;
use gpiocdev::tokio::AsyncRequest;
use tokio::task::JoinHandle;

/// Trait bound for a callback function that can be sent across threads and shared.
pub trait CallbackFn: Fn() + Send + Sync + 'static {}
impl<F: Fn() + Send + Sync + 'static> CallbackFn for F {}

/// A type-erased callback that can be sent across threads and shared.
pub type Callback = Box<dyn CallbackFn>;

/// A GPIO button listener that supports press, release, and hold callbacks.
pub struct Button {
    chip_path: String,
    line: u32,
    hold_duration: Duration,
    on_press: Option<Callback>,
    on_release: Option<Callback>,
    on_hold: Option<Callback>,
}

impl Button {
    pub fn new(chip_path: impl Into<String>, line: u32) -> Self {
        Self {
            chip_path: chip_path.into(),
            line,
            hold_duration: Duration::from_secs(3),
            on_press: None,
            on_release: None,
            on_hold: None,
        }
    }

    /// Set the duration the button must be held before the `on_hold` callback fires.
    pub fn hold_duration(mut self, duration: Duration) -> Self {
        self.hold_duration = duration;
        self
    }

    /// Callback invoked when the button is pressed (rising edge).
    pub fn on_press(mut self, f: impl CallbackFn) -> Self {
        self.on_press = Some(Box::new(f));
        self
    }

    /// Callback invoked when the button is released (falling edge).
    pub fn on_release(mut self, f: impl CallbackFn) -> Self {
        self.on_release = Some(Box::new(f));
        self
    }

    /// Callback invoked when the button is held for at least `hold_duration`.
    pub fn on_hold(mut self, f: impl CallbackFn) -> Self {
        self.on_hold = Some(Box::new(f));
        self
    }

    /// Start listening for button events. This runs indefinitely.
    pub async fn listen(self) -> anyhow::Result<()> {
        let req = self.build_request()?;
        let on_press = self.on_press;
        let on_release = self.on_release;
        let on_hold: Option<std::sync::Arc<dyn CallbackFn>> =
            self.on_hold.map(|cb| std::sync::Arc::from(cb));
        let hold_duration = self.hold_duration;
        let mut hold_task: Option<JoinHandle<()>> = None;

        println!("Listening on GPIO {}...", self.line);

        loop {
            match req.read_edge_event().await {
                Ok(event) => match event.kind {
                    Rising => handle_press(&on_press, &on_hold, hold_duration, &mut hold_task),
                    Falling => handle_release(&on_release, &mut hold_task),
                },
                Err(e) => eprintln!("Error reading edge event: {}", e),
            }
        }
    }

    fn build_request(&self) -> anyhow::Result<AsyncRequest> {
        Ok(AsyncRequest::new(
            Request::builder()
                .on_chip(&self.chip_path)
                .with_line(self.line)
                .as_active_low()
                .with_bias(Bias::PullUp)
                .with_edge_detection(EdgeDetection::BothEdges)
                .with_consumer("gpio-button")
                .with_debounce_period(Duration::from_millis(50))
                .request()?,
        ))
    }
}

fn handle_press(
    on_press: &Option<Callback>,
    on_hold: &Option<std::sync::Arc<dyn CallbackFn>>,
    hold_duration: Duration,
    hold_task: &mut Option<JoinHandle<()>>,
) {
    if let Some(cb) = on_press {
        cb();
    }

    if let Some(cb) = on_hold {
        let cb = cb.clone();
        *hold_task = Some(tokio::spawn(async move {
            tokio::time::sleep(hold_duration).await;
            cb();
        }));
    }
}

fn handle_release(on_release: &Option<Callback>, hold_task: &mut Option<JoinHandle<()>>) {
    if let Some(task) = hold_task.take() {
        task.abort();
    }

    if let Some(cb) = on_release {
        cb();
    }
}
