# ethpandaops.general.traffic_control


Uses [`tc` (traffic control)](https://man7.org/linux/man-pages/man8/tc.8.html) to add bandwith limitations and latency to existing network interfaces.

## Requirements

- `tc` is required. Normally it's installed via `iproute/iproute2` . The role will try to install it for you.
- Systemd for service management

## Role Variables
Available variables are listed below, along with default values (see `defaults/main.yml`).

The `traffic_control_rules: []` variable defines the existing rules. Each rule can be configured with:

- `interface` - This refers to the network interface on which you are applying traffic control rules. For example, eth0, wlan0.
- `rate_download/rate_upload` - The rate controls the speed (bandwidth) at which traffic is allowed to pass through the interface. In tc, the rate parameter defines the maximum allowed transmission rate for a queue. You can specify this in kilobits per second (kbit), megabits per second (mbit). For example: `10mbit`.
- `latency` - Latency is the time delay between the sending of a packet and its receipt at the destination. In tc, you can use queuing disciplines like netem to introduce artificial latency (delay) into the traffic flow. This is useful for simulating real-world network delays.
- `jitter` - Jitter refers to the variation in packet latency over time. Inconsistent delay can affect applications, so jitter is useful to simulate fluctuating network conditions.
- `loss` - Loss refers to the dropping of packets, which can occur in real-world networks due to congestion, corruption, or other issues
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
      - interface: eth0
        rate: 1mbit
        latency: 100ms
        jitter: 10ms
        loss: 0.1%
      - interface: eth1
        rate: 10mbit
      - interface: eth2
        rate: 100mbit
        latency: 50ms
      - interface: eth3
        state: absent
```
