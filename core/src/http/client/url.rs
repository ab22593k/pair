use crate::http::dto::ProtocolType;
use std::borrow::Cow;
use std::fmt;

pub struct TargetUrl {
    pub version: ApiVersion,
    pub protocol: ProtocolType,
    pub host: String,
    pub port: u16,
    pub path: &'static str,
}

pub enum ApiVersion {
    V3,
}

impl fmt::Display for TargetUrl {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}://{}:{}/api/localsend/{}{}",
            self.protocol.as_str(),
            match self.host.contains(':') {
                true => Cow::Owned(format!("[{}]", self.host)), // IPv6 addresses need to be enclosed in brackets
                false => Cow::Borrowed(&self.host),
            },
            self.port,
            match self.version {
                ApiVersion::V3 => "v3",
            },
            self.path
        )
    }
}
