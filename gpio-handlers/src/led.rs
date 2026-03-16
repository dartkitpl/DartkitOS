use std::time::Duration;

use gpiocdev::line::Value;
use gpiocdev::Request;

/// A GPIO LED controller.
pub struct Led {
    req: Request,
    line: u32,
}

impl Led {
    /// Initialize the LED.
    ///
    /// `active_low`: If true, `Value::Active` (logic 1) drives the physical line low (0V).
    pub fn new(chip_path: impl Into<String>, line: u32, active_low: bool) -> anyhow::Result<Self> {
        let chip_path: String = chip_path.into();
        let mut builder = Request::builder();
        builder
            .on_chip(chip_path)
            .with_line(line)
            .with_consumer("gpio-led")
            .as_output(Value::Inactive); // Start OFF

        if active_low {
            builder.as_active_low();
        }

        let req = builder.request()?;
        Ok(Self { req, line })
    }

    /// Turn the LED on.
    pub fn on(&self) -> anyhow::Result<()> {
        self.req.set_value(self.line, Value::Active)?;
        Ok(())
    }

    /// Turn the LED off.
    pub fn off(&self) -> anyhow::Result<()> {
        self.req.set_value(self.line, Value::Inactive)?;
        Ok(())
    }

    /// Toggle the LED state.
    pub fn toggle(&self) -> anyhow::Result<()> {
        let val = self.req.value(self.line)?;
        if val == Value::Inactive {
            self.on()
        } else {
            self.off()
        }
    }

    /// Blink the LED.
    pub async fn blink(
        &self,
        on_duration: Duration,
        off_duration: Duration,
        count: Option<usize>,
    ) -> anyhow::Result<()> {
        let mut loops = 0;
        loop {
            if let Some(c) = count {
                if loops >= c {
                    break;
                }
            }
            self.on()?;
            tokio::time::sleep(on_duration).await;
            self.off()?;
            tokio::time::sleep(off_duration).await;
            loops += 1;
        }
        Ok(())
    }
}
