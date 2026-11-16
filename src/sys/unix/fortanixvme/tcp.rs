use std::io;
use std::net::{self, SocketAddr};
use std::os::fd::AsRawFd;

pub(crate) fn bind(_socket: &net::TcpListener, _addr: SocketAddr) -> io::Result<()> {
    //set_nonblocking(socket.as_raw_fd())
    Ok(())
}

pub(crate) fn connect(socket: &net::TcpStream, _addr: SocketAddr) -> io::Result<()> {
    set_nonblocking(socket.as_raw_fd())
}

pub(crate) fn accept(listener: &net::TcpListener) -> io::Result<(net::TcpStream, SocketAddr)> {
    let (stream, addr) = listener.accept()?;
    set_nonblocking(stream.as_raw_fd())?;
    Ok((stream, addr))
}

fn set_nonblocking(fd: std::os::fd::RawFd) -> io::Result<()> {
    let flags = syscall!(fcntl(fd, libc::F_GETFL))?;
    if flags & libc::O_NONBLOCK == 0 {
        syscall!(fcntl(fd, libc::F_SETFL, flags | libc::O_NONBLOCK))?;
    }
    Ok(())
}