use anyhow::Result;
use tracing::Level;

pub fn enable_debug_logging() -> Result<()> {
    // Only initialize if not already set
    if tracing_subscriber::fmt()
        .with_max_level(Level::DEBUG)
        .try_init()
        .is_err()
    {
        // Subscriber already initialized, that's ok
        tracing::debug!("Debug logging already initialized");
    }

    Ok(())
}
