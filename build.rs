use rustc_version::{Channel, Version};

fn main() {
    if Version::parse("1.75.0").unwrap() <= rustc_version::version().unwrap() ||
        rustc_version::version_meta().unwrap().channel == Channel::Dev {
        println!("cargo:rustc-cfg=compiler_has_send_sgx_types");
    }
}
