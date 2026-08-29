# Security Deployment Checklist

Before production use:

- Replace the sample IP addresses and remove unused services and published ports.
- Keep `client_writes` set to `discard` for RPM broadcast feeds unless the protocol owner approves multi-controller writes.
- Bind the status port to localhost or place it behind an authenticated management proxy.
- Restrict inbound device ports to the authorized CAS networks with the host firewall.
- Restrict outbound traffic to configured RPM and camera endpoints.
- Keep camera credentials in OSCAR, MediaMTX, or the camera client; do not put credentials in service names or logs.
- Prefer the default unprivileged bridge or alias-IP deployment.
- Treat host-network mode as privileged site infrastructure and review every listener before enabling it.
- Pin and scan the Python base-image digest before a controlled release.
- Verify the SHA-256 checksum before loading an offline image archive.
- Back up the validated configuration and record adapter-to-device cabling.
- Test RPM disconnect/reconnect, slow CAS clients, host reboot, and camera restart before making the proxy primary.

The image does not make outbound internet connections. It opens only configured proxy listeners and the local status listener.
