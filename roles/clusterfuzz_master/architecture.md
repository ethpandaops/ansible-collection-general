Great, I'll research how to deploy ClusterFuzz using Ansible across two Debian 12 physical hosts with Docker. One host will serve as the master (including web UI and controller), and the other will act as a worker/bot. I'll focus on a setup that minimizes reliance on cloud services, but will note where optional integration with services like DigitalOcean Spaces (S3-compatible) might help, particularly for storing reports and corpus data. I'll also highlight potential problems to anticipate during deployment and future-proof the setup for possible GitHub integration.

I'll get back to you with a deployment strategy, Ansible playbook structure, and gotchas to watch out for.

# Deploying ClusterFuzz on Two Debian 12 Hosts (with Ansible & Systemd)

## Architecture Overview

In this deployment, ClusterFuzz is split across two physical Debian 12 servers. One server will host the **ClusterFuzz master** components, and the other will run a **fuzzing bot worker**. This setup mimics ClusterFuzz's cloud architecture in an on-premises environment:

- **Host 1 – Master:** Runs the ClusterFuzz web UI and scheduler along with required backend services. These services run directly on the host using systemd for process management:
  - A web interface for managing fuzzing jobs and viewing crashes.
  - Cron/scheduler processes for periodic tasks.
  - **Emulated storage and databases:** Local instances of Google Cloud services – a Datastore emulator for metadata, a Pub/Sub emulator for task queues, and a Cloud Storage emulator for corpus/crash files. These run as processes on the master host to replace cloud services. By default they bind to localhost on specific ports (e.g. Datastore on 9004, Pub/Sub on 9006, Storage on 9008).
  
- **Host 2 – Bot Worker:** Runs one (or more) ClusterFuzz **bot** instances. Bots fetch fuzzing tasks from the master and execute them to find crashes. In this setup, the bot will connect to the master's scheduler and storage via the network.

**Communication & Storage:** The bot needs to communicate with the master for task scheduling and to upload results. In our on-prem setup, this can be handled in two ways: 

- **Network communication:** Configure the bot to talk to the master's service APIs (the emulated Pub/Sub queues and HTTP endpoints) over the network. This requires making the master's emulator services accessible to the bot (e.g. by listening on the master's LAN IP instead of only localhost).
- **Shared storage:** Alternatively, use a shared filesystem for crash reports and corpora. ClusterFuzz's local mode can use a filesystem path to simulate Cloud Storage. By sharing this directory between master and bot (e.g. NFS or a mounted object storage bucket), the bot can read/write files as if it were interacting with Cloud Storage.

Below is a high-level breakdown of the roles and components on each host:

| **Host**      | **Role**      | **Components/Services**                                         | **Ports**         |
|---------------|---------------|-----------------------------------------------------------------|-------------------|
| **Host 1**    | ClusterFuzz Master (Controller) | - ClusterFuzz web UI & scheduler service (systemd)<br>- Cloud Datastore emulator (metadata database)<br>- Cloud Pub/Sub emulator (task queue)<br>- Cloud Storage emulator (for corpus & crash files)<br>- Cron job threads for scheduling tasks | Web UI: 9000 (HTTP)<br>Emulators: 9004 (Datastore), 9006 (Pub/Sub), 9008 (Storage) |
| **Host 2**    | ClusterFuzz Bot (Worker)       | - ClusterFuzz bot agent process (runs fuzzing tasks)<br>- Fuzzer runtime environment<br>- Local artifacts (log files, temp corpora, etc.) | N/A (outbound connections to Master's services) |

## Deployment Plan and Ansible Setup

We will use Ansible to automate the installation and configuration of both hosts. The deployment is organized into roles and playbooks for clarity and modularity.

### Preparation and Inventory

Start by defining an Ansible inventory with two groups: `clusterfuzz_master` and `clusterfuzz_bots`. For example, in `hosts.ini`:

```ini
[clusterfuzz_master]
master1 ansible_host=<MasterHostIP> ansible_user=<your_user>

[clusterfuzz_bots]
worker1 ansible_host=<WorkerHostIP> ansible_user=<your_user>
```

### Ansible Role Structure

Organize the playbook into three roles: a common role for both hosts, and separate roles for the master and bot. A possible directory layout:

```
ansible/
  roles/
    common/
      tasks/main.yml
    clusterfuzz-master/
      tasks/main.yml
      files/ (optional configs)
    clusterfuzz-bot/
      tasks/main.yml
      files/ (optional configs)
  site.yml
```

**Role: common** (applied to all hosts):
- Install system dependencies (Python, Git, etc.)
- Create a dedicated user or ensure correct permissions
- Ensure the host has necessary base tools

**Role: clusterfuzz-master** (applied to the master host):
- **Clone ClusterFuzz Repository**: Clone the ethpandaops/clusterfuzz repository
- **Install Dependencies**: Run the local/install_deps.bash script to install required dependencies
- **Configure Systemd Service**: Create and enable a systemd service to manage the ClusterFuzz master process
- **Storage Setup**: Configure local storage for emulated Cloud Storage and emulator state
- **Service Management**: Start and enable the ClusterFuzz service

**Role: clusterfuzz-bot** (applied to the worker host):
- **Clone ClusterFuzz Repository**: Clone the same repository as the master
- **Install Dependencies**: Run the local/install_deps.bash script
- **Configure Bot**: Set up bot configuration to connect to master
- **Service Management**: Start and enable the bot service

### Systemd Service Configuration

The master service is configured via a systemd unit file that:
- Runs as the devops user
- Sets the working directory to the repository path
- Executes the run_clusterfuzz.bash script
- Automatically restarts on failure
- Starts after network is available

Example systemd service file:
```ini
[Unit]
Description=ClusterFuzz Master Service
After=network.target

[Service]
Type=simple
User=devops
Group=devops
WorkingDirectory=/data/clusterfuzz/clusterfuzz
ExecStart=/data/clusterfuzz/clusterfuzz/local/run_clusterfuzz.bash
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Storage Setup: Local Disk vs. S3 (DigitalOcean Spaces)

Storage configuration is a crucial part of this deployment. ClusterFuzz needs a place to store fuzzing inputs/outputs: corpora, crash files, logs, builds, etc. In Google Cloud, this is handled by **Cloud Storage buckets**. In our on-prem setup, we have two main options:

### 1. Use Local Disk (Filesystem) Storage

Using a local or network disk to simulate Cloud Storage is the default for a local ClusterFuzz instance. The master process will treat a directory on disk as if it were a Cloud Storage bucket, thanks to the local GCS emulator. By default, this path is `local/storage/local_gcs` in the ClusterFuzz directory.

**Implementation:**
- Decide on a directory (e.g., `/data/clusterfuzz` on the master host)
- If the bot runs on a separate host and you prefer direct file sharing to transferring over network, set up a shared volume:
  - **Option A:** Use NFS or another network filesystem
  - **Option B:** Use a SAMBA share, etc., depending on your environment

### 2. Use S3-Compatible Storage (DigitalOcean Spaces)

DigitalOcean Spaces is an S3-compatible object storage service. We can integrate it to store crash reports and corpora, reducing the storage burden on the local disk and leveraging Spaces for durability. However, **ClusterFuzz does not natively support S3** – it expects Google Cloud Storage APIs. There are a few workarounds to consider:

- **Mounting Spaces via Filesystem:** The simplest approach is to mount the DO Spaces bucket as if it were a local folder. This can be done with tools like **s3fs-fuse** or **rclone**.
- **Periodic Sync/Bucket Upload:** Another simple method is to use local disk during fuzzing (fast writes), but periodically sync the storage directory to an external Space for backup or long-term storage.

### Choosing Between Local vs S3

For an initial deployment, you might start with **local disk storage** to simplify things. This will prove out the ClusterFuzz setup. Once fuzzing is running, you can integrate Spaces if needed (the storage path could be switched to a mounted Space, or sync enabled, without altering the core ClusterFuzz setup).

**Important:** Whichever storage method you use, ensure **sufficient disk space** and monitor it. Fuzzing can generate a lot of data (large corpora, many crash files). If using Spaces, monitor your API usage and storage costs.

