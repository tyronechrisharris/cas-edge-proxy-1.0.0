# CAS Edge Proxy

CAS Edge Proxy packages the RPM and camera networking described in the supplied **Dual CAS Hardware Configuration** into a single, configuration-driven Docker image. The same Linux image runs on:

- Raspberry Pi 4/5 with a 64-bit operating system (`linux/arm64`)
- Intel/AMD Linux hosts (`linux/amd64`)
- Windows 10/11 or Windows Server through Docker Desktop running Linux containers (`linux/amd64`)
- Other ARM64 or AMD64 Docker hosts

It replaces a separate Python service, iptables scripts, and one Ubuntu VM per camera with reusable TCP/UDP proxy definitions. It does not change the RPM or camera protocol payload.

## What it proxies

| Service kind | Intended use | Behavior |
| --- | --- | --- |
| `rpm_broadcast` | SC-770-style read-only RPM feed shared by two or more CAS clients | Maintains one upstream RPM connection and fans RPM bytes to every connected CAS client. Client writes are discarded by default, matching the supplied procedure. |
| `tcp` | Bidirectional RPM sessions, camera HTTP/HTTPS, and RTSP-over-TCP | Creates one independent upstream connection for each client connection. TLS is passed through without decryption. |
| `udp` | Fixed-port UDP device protocols | Maintains a per-client UDP session with automatic expiration. |

The supplied example defines two RPM endpoints and two cameras. Add as many services as the host can route and the hardware can sustain.

## Quick start

1. Edit [`config/config.json`](config/config.json) so every `upstream.address` matches the real RPM or camera.
2. Review the published ports in [`compose.yaml`](compose.yaml).
3. Build and start:

   ```bash
   docker compose up -d --build
   ```

4. Validate operation:

   ```bash
   docker compose ps
   curl http://127.0.0.1:9090/status
   ```

With the included portable configuration, clients use the Docker host's IP plus these ports:

| Device | Protocol | Client endpoint | Real upstream |
| --- | --- | --- | --- |
| RPM 1 | TCP broadcast | `<docker-host>:11601` | `192.168.1.1:1600` |
| RPM 2 | TCP bidirectional | `<docker-host>:11602` | `192.168.1.2:1600` |
| Camera 1 | HTTP / HTTPS / RTSP | `:18001` / `:18443` / `:18554` | `192.168.5.50` ports 80 / 443 / 554 |
| Camera 2 | HTTP / HTTPS / RTSP | `:28001` / `:28443` / `:28554` | `192.168.5.51` ports 80 / 443 / 554 |

Use `docker compose logs -f proxy` to watch connections and upstream reconnects.

## Preserve the original IPs and ports

The supplied document expects:

- SC-770 `192.168.1.1:1600` to appear at both `192.168.2.2:1600` and `10.3.11.71:1600`
- Camera `192.168.5.50` to appear as `10.3.11.135` on ports 80, 443, and 554
- Camera `192.168.5.51` to appear as `10.3.11.136` on ports 80, 443, and 554

If those alias IPs are already assigned to host interfaces, use:

```bash
docker compose -f compose.alias-ips.yaml up -d --build
```

Docker publishes the standard ports on the specified host IPs and sends them to the container's high ports. This is the safest cross-platform arrangement because the container remains unprivileged.

Native Linux and Raspberry Pi can instead use direct host networking, including a named physical interface for each upstream:

```bash
docker compose -f compose.host-network.yaml up -d --build
```

Edit interface names and source addresses in [`config/config.host-network.json`](config/config.host-network.json) first. Read [`docs/NETWORKING.md`](docs/NETWORKING.md) before using host mode; it intentionally has broader network access than the default deployment.

## Load on an offline machine

On a connected build computer with Docker Buildx:

```bash
./scripts/build-offline-bundles.sh 1.0.0
```

This creates separate AMD64 and ARM64 image archives plus SHA-256 checksums under `dist/`. Copy the project folder and the archive for the destination architecture to the offline machine.

On Raspberry Pi or Linux:

```bash
./scripts/load-and-run.sh 1.0.0
```

On Windows PowerShell:

```powershell
.\scripts\Build-OfflineBundle.ps1 -Version 1.0.0 -Architecture amd64
.\scripts\Load-And-Run.ps1 -Version 1.0.0 -Architecture amd64
```

To load manually:

```bash
docker load -i dist/cas-edge-proxy-1.0.0-linux-arm64.tar.gz
docker compose up -d --no-build
```

## Configuration

Configuration is strict JSON. Unknown keys, duplicate listeners, invalid ports, and malformed CIDRs cause a startup failure instead of being silently ignored.

```json
{
  "version": 1,
  "log_level": "INFO",
  "status": { "listen": "0.0.0.0:9090" },
  "services": [
    {
      "name": "sc770-dual-cas",
      "kind": "rpm_broadcast",
      "listen": ["0.0.0.0:11601"],
      "upstream": { "address": "192.168.1.1:1600" },
      "client_writes": "discard",
      "required": true
    }
  ]
}
```

### Service fields

| Field | Meaning | Default |
| --- | --- | --- |
| `name` | Unique log and metric name; letters, numbers, `_`, `-`, and `.` | Required |
| `kind` | `tcp`, `udp`, or `rpm_broadcast` | Required |
| `listen` | One or more container/host `IP:port` listeners | Required |
| `upstream.address` | Real device `IP:port` | Required |
| `upstream.interface` | Native-Linux interface used for the upstream socket | None |
| `upstream.source_ip` | Source address bound before connecting upstream | None |
| `enabled` | Enables the service | `true` |
| `required` | Makes `/readyz` fail while a persistent RPM upstream is disconnected | `false` |
| `allowed_clients` | Optional CIDR allowlist, such as `["10.3.11.0/24"]` | Allow all |
| `connect_timeout_seconds` | Upstream TCP/UDP connection timeout | `5` |
| `reconnect_delay_seconds` | Delay between RPM broadcast reconnect attempts | `5` |
| `idle_timeout_seconds` | TCP connection idle timeout; `0` disables it | `0` |
| `udp_session_timeout_seconds` | UDP client-session expiration | `60` |
| `client_writes` | RPM broadcast client traffic policy: `discard` or `forward` | `discard` |
| `disconnect_clients_on_upstream_loss` | Forces CAS clients to reconnect after RPM loss | `true` |
| `queue_packets` | Per-client broadcast queue; slow clients are dropped when full | `256` |

`client_writes: "forward"` serializes writes from every CAS client onto the one RPM connection. Enable it only after confirming the RPM protocol safely supports commands from multiple controllers.

Validate a mounted configuration without starting listeners:

```bash
docker run --rm -v "$(pwd)/config/config.json:/config/config.json:ro" \
  cas-edge-proxy:1.0.0 --config /config/config.json --validate
```

## Camera behavior

HTTP, HTTPS, and RTSP control connections pass through unchanged. For video, configure OSCAR, MediaMTX, VLC, FFmpeg, or the other RTSP client to request **RTSP interleaved over TCP**. A fixed port-554 proxy cannot transparently carry RTP/RTCP streams negotiated on arbitrary UDP ports.

If UDP camera transport is mandatory, place MediaMTX next to this proxy or explicitly map the camera's configured RTP/RTCP port range. RTSP-over-TCP is normally simpler and more reliable through NAT, Docker Desktop, and firewalls.

## Status and monitoring

The status listener exposes:

- `/healthz` - process/liveness check used by Docker
- `/readyz` - readiness; returns HTTP 503 when a required RPM broadcast upstream is down
- `/status` - JSON connection state and byte counters
- `/metrics` - Prometheus text metrics

The default compose file publishes status only on `127.0.0.1`. Do not expose it to an untrusted network without an authenticated reverse proxy.

## Security defaults

The portable compose deployment:

- runs as an unprivileged user
- drops every Linux capability
- uses a read-only root filesystem
- prevents privilege escalation
- mounts configuration read-only
- does not terminate TLS or store camera passwords

Restrict published proxy ports with the host firewall and populate `allowed_clients` when Docker preserves the original client address. See [`SECURITY.md`](SECURITY.md) for the deployment checklist.

## Test locally

No third-party Python packages are required:

```bash
python -m unittest discover -s tests -v
python -m cas_proxy --config config/config.json --validate
```

## Operational limits

- The image is a Layer-4 proxy, not a router-management tool. It does not assign host IP addresses, rename adapters, or install host routes.
- Multiple physical devices with the same factory IP require separate routing contexts. Native Linux can use named interfaces in host mode; Windows Docker Desktop cannot provide the same interface-level isolation.
- `rpm_broadcast` reproduces the original read-only fan-out. It is not equivalent to two fully independent bidirectional RPM sessions.
- ICMP is reported through `/status` and `/readyz`; the container does not forge ping replies or modify host firewall/NAT rules.
- The image contains no web configuration editor. Configuration changes are deliberate file edits followed by `docker compose restart proxy`.

The detailed platform choices and duplicate-subnet guidance are in [`docs/NETWORKING.md`](docs/NETWORKING.md).
