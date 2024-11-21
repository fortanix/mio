use async_usercalls::RawApi;
use crate::sys::sgx::selector::{EventKind, Registration};
use crate::sys::Selector;
use crate::{Interest, Token};
use std::fmt;
use std::io;
use std::ptr;
use std::sync::Arc;

pub struct Waker(Arc<Registration>);

impl Waker {
    pub fn new(selector: &Selector, token: Token) -> io::Result<Waker> {
        Ok(Waker(Arc::new(Registration::new(
            selector,
            token,
            Interest::READABLE,
        ))))
    }

    pub fn wake(&self) -> io::Result<()> {
        let weak_ref = Arc::downgrade(&self.0);
        let f = move |()| {
            let inner = match weak_ref.upgrade() {
                Some(arc) => arc,
                None => return,
            };
            inner.push_event(EventKind::Readable);
        };
        // use `raw_free` (instead of `insecure_time`) here to avoid false positives in computing
        // number of `insecure_time` calls
        unsafe { self.0.provider().raw_free(ptr::null_mut(), 0, 2, Some(f.into())) };
        Ok(())
    }
}

impl fmt::Debug for Waker {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Waker")
            .field("token", &self.0.token())
            .finish()
    }
}
