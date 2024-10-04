# ethpandaops.general.traffic_control


Uses [`tc` (traffic control)](https://man7.org/linux/man-pages/man8/tc.8.html) to add bandwith limitations and latency to existing network interfaces.

## Requirements

- `tc` is required. Normally it's installed via `iproute/iproute2` . The role will try to install it for you.
- Systemd for service management

## Role Variables
Available variables are listed below, along with default values (see `defaults/main.yml`).

The `traffic_control_rules: []` variable defines the existing rules. Each rule can be configured with:

- `interface` - This refers to the network interface on which you are applying traffic control rules. For example, eth0, wlan0.
- `rate` - The rate controls the speed (bandwidth) at which traffic is allowed to pass through the interface. In tc, the rate parameter defines the maximum allowed transmission rate for a queue. You can specify this in kilobits per second (kbit), megabits per second (mbit). For example: `10mbit`.
- `rate_download` - Same as rate, but for download speed only. If this is not defined and `rate` is defined, it will default to the value of `rate`.
- `rate_upload` - Same as rate, but for upload speed only. If this is not defined and `rate` is defined, it will default to the value of `rate`.
- `latency` - Latency is the time delay between the sending of a packet and its receipt at the destination. In tc, you can use queuing disciplines like netem to introduce artificial latency (delay) into the traffic flow. This is useful for simulating real-world network delays. For example: `50ms`.
- `jitter` - Jitter refers to the variation in packet latency over time. Inconsistent delay can affect applications, so jitter is useful to simulate fluctuating network conditions. For example: `10ms`.
- `loss` - Loss refers to the dropping of packets, which can occur in real-world networks due to congestion, corruption, or other issues. This is given in percentage, for example: `0.1%`.
- `state` - This allows you to clean up any rules for a specific interface by stating the `state=absent`.




## Dependencies

None.

## Example Playbook

Your playbook could look like this:

```yaml
- hosts: localhost
  become: true
  roles:
    - role: ethpandaops.general.traffic_control
  vars:
    traffic_control_rules:
      # Limit traffic on eth0 to:
      # - 100Mbps Down 50Mbps Up,
      # - 100ms latency + 10ms jitter
      # -  0.1% package loss
      - interface: eth0
        rate_download: 50mbit
        rate_upload: 10mbit
        latency: 100ms
        jitter: 10ms
        loss: 0.1%

      # Limit traffic on eth1 to:
      # - 10Mbps up/download.
      - interface: eth1
        rate: 10mbit

      # Limit traffic on eth2 to:
      # - 100Mbps up/download
      # - 50ms latency
      - interface: eth2
        rate: 100mbit
        latency: 50ms

      # Remove traffic restrictions from eth3
      - interface: eth3
        state: absent
```
