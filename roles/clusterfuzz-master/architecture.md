Great, I'll research how to deploy ClusterFuzz using Ansible across two Debian 12 physical hosts with Docker. One host will serve as the master (including web UI and controller), and the other will act as a worker/bot. I'll focus on a setup that minimizes reliance on cloud services, but will note where optional integration with services like DigitalOcean Spaces (S3-compatible) might help, particularly for storing reports and corpus data. I'll also highlight potential problems to anticipate during deployment and future-proof the setup for possible GitHub integration.

I'll get back to you with a deployment strategy, Ansible playbook structure, and gotchas to watch out for.

# Deploying ClusterFuzz on Two Debian 12 Hosts (with Ansible & Docker)

## Architecture Overview

In this deployment, ClusterFuzz is split across two physical Debian 12 servers, using Docker containers for isolation. One server will host the **ClusterFuzz master** components, and the other will run a **fuzzing bot worker**. This setup mimics ClusterFuzz's cloud architecture in an on-premises environment:

- **Host 1 – Master:** Runs the ClusterFuzz web UI and scheduler (the App Engine-like service) along with required backend services. In Google Cloud, these would be App Engine, Cloud Datastore, Cloud Storage, etc. ([Architecture | ClusterFuzz](https://google.github.io/clusterfuzz/architecture/#:~:text=ClusterFuzz%20runs%20on%20the%20Google,on%20a%20number%20of%20services)) ([Architecture | ClusterFuzz](https://google.github.io/clusterfuzz/architecture/#:~:text=App%20Engine)). Here, we simulate those using local services:
  - A web interface for managing fuzzing jobs and viewing crashes.
  - Cron/scheduler processes for periodic tasks (normally App Engine cron jobs).
  - **Emulated storage and databases:** Local instances of Google Cloud services – a Datastore emulator for metadata, a Pub/Sub emulator for task queues, and a Cloud Storage emulator for corpus/crash files ([clusterfuzz/src/local/butler/run_server.py at master · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/blob/master/src/local/butler/run_server.py#:~:text=)) ([clusterfuzz/src/local/butler/run_server.py at master · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/blob/master/src/local/butler/run_server.py#:~:text=,emulator)). These run as processes on the master host (within the Docker container) to replace cloud services. By default they bind to localhost on specific ports (e.g. Datastore on 9004, Pub/Sub on 9006, Storage on 9008) ([clusterfuzz/src/local/butler/constants.py at master · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/blob/master/src/local/butler/constants.py#:~:text=LOCAL_GCS_SERVER_PORT%20%3D%209008)) ([clusterfuzz/src/local/butler/constants.py at master · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/blob/master/src/local/butler/constants.py#:~:text=PUBSUB_EMULATOR_PORT%20%3D%209006)) ([clusterfuzz/src/local/butler/constants.py at master · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/blob/master/src/local/butler/constants.py#:~:text=LOCAL_GCS_SERVER_PORT%20%3D%209008)).
  
- **Host 2 – Bot Worker:** Runs one (or more) ClusterFuzz **bot** instances inside a container. Bots fetch fuzzing tasks from the master and execute them to find crashes ([Architecture | ClusterFuzz](https://google.github.io/clusterfuzz/architecture/#:~:text=Fuzzing%20bots%20are%20machines%20that,tasks%20that%20bots%20run%20are)). Normally, bots can run on any machine (not necessarily Google Compute Engine) as long as they can reach the master's services ([ClusterFuzz | Documentation for ClusterFuzz](https://google.github.io/clusterfuzz/production-setup/clusterfuzz/#:~:text=Note%20that%20bots%20do%20not,Cloud%20Datastore%20and%20Cloud%20Storage)). In this setup, the bot container will connect to the master's scheduler and storage via the network or shared storage.

**Communication & Storage:** The bot needs to communicate with the master for task scheduling and to upload results. In our on-prem setup, this can be handled in two ways: 

- **Network communication:** Configure the bot to talk to the master's service APIs (the emulated Pub/Sub queues and HTTP endpoints) over the network. This requires making the master's emulator services accessible to the bot (e.g. by listening on the master's LAN IP instead of only localhost).
- **Shared storage:** Alternatively, use a shared filesystem for crash reports and corpora. ClusterFuzz's local mode can use a filesystem path to simulate Cloud Storage ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=Local%20Google%20Cloud%20Storage)). By sharing this directory between master and bot (e.g. NFS or a mounted object storage bucket), the bot can read/write files as if it were interacting with Cloud Storage. In either case, the master and bot must reference the same storage location (either via network API or a common file path).

Below is a high-level breakdown of the roles and components on each host:

| **Host**      | **Role**      | **Components/Services**                                         | **Ports**         |
|---------------|---------------|-----------------------------------------------------------------|-------------------|
| **Host 1**    | ClusterFuzz Master (Controller) | - ClusterFuzz App Engine service (web UI & scheduler) ** ([Architecture | ClusterFuzz](https://google.github.io/clusterfuzz/architecture/#:~:text=App%20Engine))**<br>- Cloud Datastore emulator (metadata database)<br>- Cloud Pub/Sub emulator (task queue)<br>- Cloud Storage emulator (for corpus & crash files) ** ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=We%20simulate%20Google%20Cloud%20Storage,in%20your%20ClusterFuzz%20checkout))**<br>- Cron job threads for scheduling tasks | Web UI: 9000 (HTTP)** ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=python%20butler))**<br>Emulators: 9004 (Datastore), 9006 (Pub/Sub), 9008 (Storage) (bound locally by default) |
| **Host 2**    | ClusterFuzz Bot (Worker)       | - ClusterFuzz bot agent process (runs fuzzing tasks) ** ([Architecture | ClusterFuzz](https://google.github.io/clusterfuzz/architecture/#:~:text=Fuzzing%20bots%20are%20machines%20that,tasks%20that%20bots%20run%20are))**<br>- Fuzzer runtime environment (sanitizers, engines, etc., inside container)<br>- Local artifacts (log files, temp corpora, etc. stored in the container or mounted volume) | N/A (outbound connections to Master's services) |

**Note:** In a typical Google Cloud deployment, the master runs on App Engine and data is stored in Cloud Storage/Datastore/BigQuery, while bots run on GCE VMs ([Architecture | ClusterFuzz](https://google.github.io/clusterfuzz/architecture/#:~:text=ClusterFuzz%20runs%20on%20the%20Google,on%20a%20number%20of%20services)). Here we replace those with local services. Some advanced features (e.g. detailed crash stats using BigQuery) will be unavailable in this on-premises setup ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=You%20can%20run%20a%20local,lack%20of%20Google%20Cloud%20emulators)) ([what is lost when running clusterfuzz locally? · Issue #1667 · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/issues/1667#:~:text=Cloud%20provides%20all%20the%20scalability%2C,When%20develop%20write%20fuzzer)).

## Deployment Plan and Ansible Setup

We will use Ansible to automate the installation and configuration of both hosts. The deployment is organized into roles and playbooks for clarity and modularity. The goal is to make the setup reproducible and easy to extend (for example, adding CI/GitHub integration later).

### Preparation and Inventory

Start by defining an Ansible inventory with two groups: `clusterfuzz_master` and `clusterfuzz_bots`. For example, in `hosts.ini`:

```ini
[clusterfuzz_master]
master1 ansible_host=<MasterHostIP> ansible_user=<your_user>

[clusterfuzz_bots]
worker1 ansible_host=<WorkerHostIP> ansible_user=<your_user>
```

Both hosts should have Docker installed and accessible by Ansible (this can be automated as a preliminary step).

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
- Install system dependencies (e.g. ensure Docker is installed, Python if needed for Ansible, etc.).
- (Optional) Create a dedicated user or ensure correct permissions for Docker if not running as root.
- Ensure the host has necessary base tools (could include Git if building images from source, and possibly NFS client if using NFS for storage, etc.).

**Role: clusterfuzz-master** (applied to the master host):
- **Pull or Build ClusterFuzz Master Docker Image**: Since Google does not provide an "App Engine" container for ClusterFuzz, you will likely build a custom image. This image needs:
  - Python (the version supported by ClusterFuzz, e.g. 3.11).
  - Google Cloud SDK (to get the Datastore and Pub/Sub emulators that `butler.py` will invoke) ([Install google fuzzy tool clusterfuzz on Kali Linux | by Aster Lin | Medium](https://huiicat.medium.com/install-google-fuzzy-tool-clusterfuzz-on-kali-linux-d5529ff1ad4c#:~:text=2)) ([Install google fuzzy tool clusterfuzz on Kali Linux | by Aster Lin | Medium](https://huiicat.medium.com/install-google-fuzzy-tool-clusterfuzz-on-kali-linux-d5529ff1ad4c#:~:text=%24%20python%20butler.py%20run_server%20,will%20init%20data%20from%20server)).
  - ClusterFuzz codebase (cloned from Google's GitHub and checked out to a stable release tag).
  - All Python dependencies installed (the ClusterFuzz repo provides a Pipfile/Pipenv or requirements; these include things like Flask, etc., and Google Cloud libraries).
  - Entry point command to run the server: e.g. `butler.py run_server`. For first-time setup, `--bootstrap` flag should be used to initialize the environment ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=You%20can%20start%20a%20local,by%20running%20the%20following%20command)).
- **Launch the Master Container**: Use Ansible's Docker modules (or `docker_compose` module) to run the container. Key configuration:
  - **Ports**: Expose port 9000 for the web UI (and ensure it's accessible in your network). Also, consider exposing the emulator ports (9004, 9006, 9008) to the worker. If the master container runs with `network=host`, it will bind these ports on the host. Otherwise, you may need to publish them and possibly adjust emulator binding (see **Storage & Networking** below).
  - **Volumes**: Mount a persistent volume for ClusterFuzz storage. For example, map `/opt/clusterfuzz/storage` on the host to `/clusterfuzz/local/storage` inside the container. This directory will hold the *local Google Cloud Storage* simulation data and emulator state (Datastore data, etc.) ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=Local%20Google%20Cloud%20Storage)). Persisting it ensures that crashes, corpora, and metadata are retained across restarts.
  - **Environment**: In local mode, authentication is disabled (no Firebase) and the app runs in dev mode by default ([what is lost when running clusterfuzz locally? · Issue #1667 · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/issues/1667#:~:text=Cloud%20provides%20all%20the%20scalability%2C,When%20develop%20write%20fuzzer)). You typically don't need special env variables for basic functionality. However, if you plan to allow the bot to connect from another machine, you might set environment variables to point the emulators to the right addresses (e.g., `LOCAL_GCS_SERVER_HOST`, `DATASTORE_EMULATOR_HOST`, `PUBSUB_EMULATOR_HOST`) – more on this in **Storage & Networking**. Additionally, set `LOCAL_DEVELOPMENT=True` inside the container to ensure it uses local emulators and doesn't expect real cloud services (the `run_server` script usually sets this for you ([clusterfuzz/src/local/butler/run_server.py at master · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/blob/master/src/local/butler/run_server.py#:~:text=os.environ))).
  - **Restart policy**: Configure the container to restart on failure or at boot (so that the master comes up automatically).

- **Firewall/Networking**: Ensure that port 9000 is open to your network (or at least to your users' machines) so you can access the web UI. Also open emulator ports **to the worker host** if using direct network access (you may restrict these ports in the firewall to only the worker's IP, since they're internal RPC channels).

**Role: clusterfuzz-bot** (applied to the worker host):
- **Pull or Build Bot Docker Image**: Google provides a base Docker image for ClusterFuzz bots ([ClusterFuzz | Documentation for ClusterFuzz](https://google.github.io/clusterfuzz/production-setup/clusterfuzz/#:~:text=Note%20that%20bots%20do%20not,Cloud%20Datastore%20and%20Cloud%20Storage)). You can use the official image if available (e.g., from GCR or Docker Hub) or build your own from the ClusterFuzz source. The bot image should contain:
  - The ClusterFuzz bot code and dependencies (this could be the same codebase as the master, but the entry point will differ).
  - Any runtime dependencies for fuzzers (e.g., it should have libFuzzer, AFL++, etc., or the ability to run targets built with sanitizers). The official image likely includes these in a base Linux environment.
- **Launch the Bot Container**: For each bot, run a container with the following:
  - **Command**: `butler.py run_bot --name <bot-name> --server-storage-path=<path> /clusterfuzz/bot-instance` (with appropriate flags). The `--name` can be any identifier for the bot. The `--server-storage-path` should match the master's storage path if you are sharing a filesystem ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=You%20can%20override%20the%20default,location%20by%20doing%20the%20following)). If not using a direct shared path, you can omit `--server-storage-path` and instead rely on network access to the master's storage emulator (see below).
  - **Volumes**: You may mount the same storage volume as the master if using an NFS/shared directory approach (so that `/clusterfuzz/local/storage` in the bot container points to the master's storage). Additionally, the bot will maintain its own working files (in the command above, `/clusterfuzz/bot-instance` will be created to hold the bot's copy of the code and its local outputs ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=You%20can%20run%20a%20ClusterFuzz,by%20running%20the%20following%20command))). You can mount a volume for this path as well if you want to persist bot logs or crashes locally on the worker.
  - **Environment**: If not using shared storage, configure environment variables to point the bot to the master's emulator endpoints:
    - `DATASTORE_EMULATOR_HOST=http://<MasterHostIP>:9004`  
    - `PUBSUB_EMULATOR_HOST=http://<MasterHostIP>:9006`  
    - `LOCAL_GCS_SERVER_HOST=http://<MasterHostIP>:9008`  
    - `APPLICATION_ID=test-clusterfuzz` (the same application ID the master uses in local dev mode ([clusterfuzz/src/local/butler/constants.py at master · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/blob/master/src/local/butler/constants.py#:~:text=TEST_APP_ID%20%3D%20%27test)))  
    These will override the default of localhost and allow the bot to connect to the master's services over the network. (Ensure the master's container/host is configured to allow connections on these ports as noted.) If you are using a direct shared filesystem, the GCS emulator host may not need to be exposed – the bot can read/write files directly – but **Pub/Sub and Datastore must either be accessible or not needed**. (ClusterFuzz's local bots usually communicate tasks via the emulator; without network access, tasks might not be received.)
  - **Restart policy**: Set the bot container to restart on failure or boot so that fuzzing resumes if interrupted.

- **Verification**: After deployment, the bot should register with the master. You can check the ClusterFuzz web UI on Host 1 (e.g., `http://<MasterHostIP>:9000`) and see the bot listed under the Bots section. The bot's logs (accessible in the container or via mounted volume) should show it connecting. Initially, if no fuzzing jobs are configured, the bot log will show "Failed to get any fuzzing tasks" (harmless until jobs are added) ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=You%20can%20see%20logs%20on,by%20running%20the%20following%20command)).

### Ansible Playbook Execution

Bring it together in an Ansible playbook (e.g., `site.yml`):

```yaml
- hosts: all
  roles:
    - common

- hosts: clusterfuzz_master
  roles:
    - clusterfuzz-master

- hosts: clusterfuzz_bots
  roles:
    - clusterfuzz-bot
```

This structure ensures common setup is done first, then master, then bots. The roles should handle coordination such that the master is up before bots attempt to start (you might add a short wait or a handler to pause the bot startup until the master's container is running).

## Docker Configuration for Master and Bot Containers

To summarize the container settings, here's an outline of how each container should be configured:

| **Container**      | **Image Base**        | **Processes**                 | **Ports**                     | **Volumes (Mounts)**                          | **Environment / Flags**                          |
|--------------------|-----------------------|-------------------------------|-------------------------------|-----------------------------------------------|--------------------------------------------------|
| **clusterfuzz-master** | Custom image (e.g. Debian base + Python + gcloud SDK + ClusterFuzz code). | - `python butler.py run_server --bootstrap` (on first run, then without `--bootstrap` subsequently) ** ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=You%20can%20start%20a%20local,by%20running%20the%20following%20command))**. This launches the web UI and internal emulator services. | - `9000/tcp`: Web UI (ClusterFuzz interface) ** ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=It%20may%20take%20a%20few,interface%20by%20navigating%20to%20http%3A%2F%2Flocalhost%3A9000))**<br>- (Optional) `9004, 9006, 9008/tcp`: Datastore, Pub/Sub, GCS emulator ports. If using network access for the bot, map these to host as well. *If using `network_mode: host`, these are on the host by default.* | - `/clusterfuzz/local/storage` (inside container) mounted to `/opt/clusterfuzz/storage` (host path) – persistent storage for emulated Cloud Storage and emulator state ** ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=We%20simulate%20Google%20Cloud%20Storage,in%20your%20ClusterFuzz%20checkout))**.<br>- (Optional) Config files or SSL certs if needed (generally not, unless securing UI). | - `LOCAL_DEVELOPMENT=True` (usually set by the tool automatically) ** ([clusterfuzz/src/local/butler/run_server.py at master · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/blob/master/src/local/butler/run_server.py#:~:text=os.environ))**.<br>- If needed: adjust emulator host binding. For example, to let bots connect, you might run the GCS emulator on `0.0.0.0`. This could involve patching the startup command (not typically exposed as a simple env variable). Alternatively, run container in host network mode. |
| **clusterfuzz-bot**    | ClusterFuzz bot image (Google's provided image or custom build from source). Likely based on Ubuntu with fuzzing dependencies. | - `python butler.py run_bot --name bot1 --server-storage-path=/clusterfuzz/storage` (if using shared FS) or without `--server-storage-path` if not needed. This command will continuously poll for tasks and run them. ** ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=You%20can%20run%20a%20ClusterFuzz,by%20running%20the%20following%20command)) ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=You%20can%20override%20the%20default,location%20by%20doing%20the%20following))** | *(No ports exposed)* – the bot only makes outbound connections. | - If sharing storage via filesystem: mount the same `/opt/clusterfuzz/storage` (host or NFS) to `/clusterfuzz/storage` inside the bot container (and use `--server-storage-path` flag to point to it) ** ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=You%20can%20override%20the%20default,location%20by%20doing%20the%20following))**.<br>- Mount a local directory for `/clusterfuzz/bot-instance` if you want to persist logs or keep the bot's state outside the container (optional). | - If using networked emulators: `DATASTORE_EMULATOR_HOST=http://master1:9004`, `PUBSUB_EMULATOR_HOST=http://master1:9006`, `LOCAL_GCS_SERVER_HOST=http://master1:9008`, `APPLICATION_ID=test-clusterfuzz` (match master's app ID) to direct the bot to use master's services. Without these, the bot will assume those services on localhost (inside its container) which is incorrect in a split setup.<br>- If using shared FS: the `--server-storage-path` flag already tells the bot where to find the "Cloud Storage" files; you still may need the emulator host vars for Datastore/PubSub if they are not using shared memory (they are not files, so likely require network). |

**Gotchas & Tips:**

- **Python and GCloud SDK versions:** Ensure the Python version in images matches ClusterFuzz's requirements (the latest ClusterFuzz supports Python 3.11 as of recent updates, so use that unless documentation says otherwise). The Google Cloud SDK in the master image should have the components for Datastore and Pub/Sub emulators installed. The `butler.py run_server` script will attempt to start those emulators – if they're missing, it may fail or hang. You can pre-install them by running `gcloud components install cloud-datastore-emulator pubsub-emulator` in the Docker build stage ([Install google fuzzy tool clusterfuzz on Kali Linux | by Aster Lin | Medium](https://huiicat.medium.com/install-google-fuzzy-tool-clusterfuzz-on-kali-linux-d5529ff1ad4c#:~:text=%24%20python%20butler.py%20run_server%20,will%20init%20data%20from%20server)).
- **Bootstrapping Data:** The first time the master runs (`--bootstrap`), it will initialize default configurations (like creating default buckets in the local storage, seeding the Datastore with default entities). This should be done once. In Ansible, you might run the master container with `--bootstrap`, then subsequently (on re-deploys) run it without that flag. One way to handle this is to check for an indicator file in the storage volume (for example, a created folder) and only include `--bootstrap` on first deployment.
- **Accessing the Web UI:** By default, the local instance has no authentication (no OAuth/Firebase) ([what is lost when running clusterfuzz locally? · Issue #1667 · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/issues/1667#:~:text=Cloud%20provides%20all%20the%20scalability%2C,When%20develop%20write%20fuzzer)), which means **anyone who can reach the web UI can use it**. Ensure you restrict access appropriately (e.g., run it in an internal network or behind a VPN, or enable some reverse proxy with auth if needed). In the future, you could integrate Firebase or another auth mechanism, but that is non-trivial outside Google Cloud. At minimum, consider firewalling port 9000 to trusted IPs.
- **Number of Bots:** This design uses one bot on the worker host. You can scale by adding more bot containers (even on the same host or additional hosts) as long as they point to the same master. Each bot will show up in the UI. Keep in mind the local setup isn't tested for very large numbers of bots ([what is lost when running clusterfuzz locally? · Issue #1667 · google/clusterfuzz · GitHub](https://github.com/google/clusterfuzz/issues/1667#:~:text=Cloud%20provides%20all%20the%20scalability%2C,When%20develop%20write%20fuzzer)) – a few bots should work, but don't expect to scale to dozens easily in this configuration.

## Storage Setup: Local Disk vs. S3 (DigitalOcean Spaces)

Storage configuration is a crucial part of this deployment. ClusterFuzz needs a place to store fuzzing inputs/outputs: corpora, crash files, logs, builds, etc. In Google Cloud, this is handled by **Cloud Storage buckets**. In our on-prem setup, we have two main options:

### 1. Use Local Disk (Filesystem) Storage

Using a local or network disk to simulate Cloud Storage is the default for a local ClusterFuzz instance ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=Local%20Google%20Cloud%20Storage)). The master process will treat a directory on disk as if it were a Cloud Storage bucket, thanks to the local GCS emulator. By default, this path is `local/storage/local_gcs` in the ClusterFuzz directory ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=We%20simulate%20Google%20Cloud%20Storage,in%20your%20ClusterFuzz%20checkout)), but we can override it via `--storage-path`. 

**Implementation:**
- Decide on a directory (e.g., `/opt/clusterfuzz/storage` on the master host). This can be on a large volume to accommodate potentially many crashes or large corpora.
- If the bot runs on a separate host and you prefer direct file sharing to transferring over network, set up a shared volume:
  - **Option A:** Use NFS or another network filesystem. Mount the master's storage directory on the worker host at the same path. This way, both the master container and bot container can access the same files. In Ansible, you can automate the installation of an NFS server on the master and NFS client on the worker, or use a SAMBA share, etc., depending on your environment.
  - **Option B:** Use Docker Volumes with a volume plugin that supports multi-host (less common in simple setups), or manually sync the data (not real-time).
- When launching `run_server`, include `--storage-path=/clusterfuzz/local/storage` (inside container path). When launching `run_bot`, include `--server-storage-path=/clusterfuzz/storage` (assuming you mounted the master's storage to `/clusterfuzz/storage` inside the bot container). This matching path signals the bot to use the given location as the authoritative storage ([Running a local instance | ClusterFuzz](https://google.github.io/clusterfuzz/getting-started/local-instance/#:~:text=You%20can%20override%20the%20default,location%20by%20doing%20the%20following)).
- The master's GCS emulator will write files to this directory (under subfolders per "bucket"). The bot, if correctly pointed, will read/write to the same directory when it needs to fetch or upload files. This bypasses the need for the bot to talk to the master's HTTP storage API – it assumes shared disk access. 

**Pros:** Simple to set up, fast local I/O, no external dependencies.  
**Cons:** Requires network file sharing which can be complex or introduce performance issues over LAN. Also, both master and bot need consistent file paths and permissions. 

### 2. Use S3-Compatible Storage (DigitalOcean Spaces)

DigitalOcean Spaces is an S3-compatible object storage service. We can integrate it to store crash reports and corpora, reducing the storage burden on the local disk and leveraging Spaces for durability. However, **ClusterFuzz does not natively support S3** – it expects Google Cloud Storage APIs. There are a few workarounds to consider:

- **Mounting Spaces via Filesystem:** The simplest approach is to mount the DO Spaces bucket as if it were a local folder. This can be done with tools like **s3fs-fuse** or **rclone**. For example, using s3fs, you can mount a bucket to a path on the master host (e.g., mount `do-clusterfuzz-space` bucket to `/opt/clusterfuzz/storage`). The ClusterFuzz master will then read/write files to this mount, and s3fs will behind-the-scenes push them to Spaces over HTTPS. In Ansible, you'd:
  - Install `s3fs` on the master.
  - Create an access key for your Space and store the credentials (e.g., in `/etc/passwd-s3fs`).
  - Mount the bucket at the desired path (ensure to mount with options for eventual consistency handling, etc. if needed).
  - Then proceed with ClusterFuzz using that path as storage. From ClusterFuzz's perspective, it's just a local directory, but in reality it's backed by object storage.
  - **Gotcha:** Performance might be slower, especially for many small files (common in fuzzing corpora). Also, ensure the mount is configured to reconnect on reboot (Ansible can place an entry in fstab or a systemd mount unit).
  
- **MinIO Gateway or Custom API translation:** A more advanced approach is to run a service that translates GCS API calls to S3. For instance, MinIO can act as a gateway for Google Cloud Storage or vice versa. In theory, one could run a MinIO server that listens for GCS-style requests (JSON API) and stores data in an S3 bucket (Spaces). This would require configuring ClusterFuzz to use that gateway's address as the Cloud Storage endpoint. However, this is non-trivial and may require code changes or heavy configuration, since ClusterFuzz's local mode is hard-coded to talk to its built-in emulator. This approach is probably overkill for most deployments.

- **Periodic Sync/Bucket Upload:** Another simple method is to use local disk during fuzzing (fast writes), but periodically sync the storage directory to an external Space for backup or long-term storage. This could be done with an Ansible scheduled job or a cron container. For example, run `rclone sync /opt/clusterfuzz/storage spaces:my-clusterfuzz` every hour. This doesn't make ClusterFuzz aware of S3, but ensures you have off-site copies of the findings and corpora. You would then manually or via script retrieve files from Spaces if needed.

**Pros:** Offloads data storage to a managed service (potentially more reliable storage of artifacts, and saves space on local disk). Spaces can be scaled as needed.  
**Cons:** Added complexity – ClusterFuzz isn't built to directly use S3, so we're either introducing a fuse layer (which can be error-prone under high load) or an external sync. Also, network latency when accessing Spaces might slow down fuzzing tasks that need to fetch corpora or upload crashes.

### Choosing Between Local vs S3

For an initial deployment, you might start with **local disk storage** to simplify things. This will prove out the ClusterFuzz setup. Once fuzzing is running, you can integrate Spaces if needed (the storage path could be switched to a mounted Space, or sync enabled, without altering the core ClusterFuzz setup). Keep in mind that if the local filesystem is used exclusively, you should implement backups – a nightly sync to Spaces or other backup solution – to avoid losing crash data if the disk fails.

**Important:** Whichever storage method you use, ensure **sufficient disk space** and monitor it. Fuzzing can generate a lot of data (large corpora, many crash files). If using Spaces, monitor your API usage and storage costs.

