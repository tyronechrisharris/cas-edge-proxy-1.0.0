# Networking and Platform Deployment

Choose the least-privileged mode that satisfies the site topology.

## Mode 1: Portable published ports

Use [`compose.yaml`](../compose.yaml) on Raspberry Pi, Linux, Windows Docker Desktop, or another Docker host when every upstream device has an address that the host can route uniquely.

```bash
docker compose up -d --build
```

The container listens on high internal ports and Docker publishes the same ports on the host. This mode does not need special capabilities or host-network access.

Best for:

- quick bench tests
- Windows deployments
- RPMs and cameras with unique reachable IP addresses
- CAS software that accepts nonstandard destination ports

## Mode 2: Alias IPs with standard device ports

Use [`compose.alias-ips.yaml`](../compose.alias-ips.yaml) when CAS software expects a unique IP per device but should continue using standard ports such as 1600, 80, 443, and 554.

The host must own every left-side IP in the compose `ports` entries before Docker starts. For example, on a native Linux host:

```bash
sudo ip address add 192.168.2.2/24 dev eth2
sudo ip address add 10.3.11.71/24 dev eth3
sudo ip address add 10.3.11.135/24 dev eth3
sudo ip address add 10.3.11.136/24 dev eth3
```

Those commands are temporary and intentionally not automated. Use NetworkManager, systemd-networkd, Netplan, or the site's approved Windows network configuration to make addresses persistent.

Start the alias deployment:

```bash
docker compose -f compose.alias-ips.yaml up -d --build
```

Best for:

- direct replacement of the document's VM/NAT topology
- preserving existing OSCAR/CAS device addresses
- unprivileged containers

## Mode 3: Native Linux host networking

Use [`compose.host-network.yaml`](../compose.host-network.yaml) only on Raspberry Pi OS or native Linux when the proxy must select a specific physical adapter for an upstream device.

1. List stable interface names:

   ```bash
   ip -brief link
   ip -brief address
   ```

2. Give each upstream interface a static source address.
3. Edit `upstream.interface`, `upstream.source_ip`, and every listener in [`config/config.host-network.json`](../config/config.host-network.json).
4. Confirm the host owns every listener IP.
5. Start:

   ```bash
   docker compose -f compose.host-network.yaml up -d --build
   ```

This deployment runs the process as root with only `NET_RAW` added after all other capabilities are dropped. Root is needed for standard camera ports and interface-bound sockets. Host networking shares the host network namespace, so a configuration error can collide with an existing host service.

## Multiple devices with identical factory IPs

If several RPMs all use `192.168.1.1`, or several isolated cameras all use `192.168.5.50`, an ordinary routing table cannot tell them apart.

Preferred solutions, in order:

1. Assign unique device IP addresses when the vendor permits it.
2. Use one inexpensive Raspberry Pi proxy per physically isolated duplicate subnet.
3. On native Linux, use a separate physical adapter and `upstream.interface` for each service, then validate ARP and routing behavior under disconnect/reconnect conditions.
4. For advanced deployments, place one proxy container in each dedicated Linux network namespace.

Windows Docker Desktop provides Layer-4 host networking through its Linux VM. It can proxy devices reachable through Windows, but it does not expose native-Linux interface binding or Layer-2 network isolation to the container. Use unique upstream addresses or separate edge proxies for repeated factory subnets.

## Raspberry Pi adapter naming

Do not assume USB adapters will always remain `eth1`, `eth2`, and `eth3`. Prefer predictable names based on adapter MAC address or USB path. Record the mapping in site documentation and validate it after power loss and OS updates.

The supplied Word procedure contains both `192.168.5.2` and `192.168.2.2` for the second RPM-facing network. The container examples use `192.168.2.2`, matching the later commands and NAT rules. Confirm the intended subnet at the site before deployment.

## RTSP transport

An RTSP session always uses TCP for control, but video can use UDP, multicast UDP, or TCP interleaving. Through this Layer-4 proxy, select TCP interleaving in the client:

- FFmpeg: `-rtsp_transport tcp`
- VLC: `--rtsp-tcp`
- GStreamer: `protocols=tcp`
- MediaMTX: configure the source to use TCP transport

If a camera embeds its private address in application data or redirects browsers to a private hostname, use an application-aware reverse proxy or change the camera configuration.

## Firewall rules

Allow only the CAS networks that need each published endpoint. Typical inbound rules are:

- RPM TCP 1600, 11601, or the selected published port
- camera HTTP/HTTPS only when administrators require the camera UI
- RTSP TCP 554 or the selected published port
- status TCP 9090 only from localhost or the management network

Outbound access should be limited to the configured RPM and camera addresses and ports. The proxy does not require internet access at runtime.
