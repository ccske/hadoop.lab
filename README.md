# Hadoop.lab

A lightweight Hadoop ecosystem on Docker for educational and research purposes.

This project provides a Docker-based Hadoop ecosystem for classroom teaching and student practice.
It is designed for **teachers and students** as an educational tool, while **universities and institutions** can obtain commercial licenses for classroom or production use.

---

## Project structure
```
hadoop.lab
├── COMMERCIAL_LICENSE.md
├── CONTRIBUTING.md
├── docker-compose.yaml
├── hadoop
│   ├── Dockerfile
│   ├── entrypoint
│   │   ├── entrypoint-client.sh
│   │   ├── entrypoint-master.sh
│   │   └── entrypoint-worker.sh
│   └── etc
│       └── hadoop
│           ├── core-site.xml
│           ├── hadoop-env.sh
│           ├── hdfs-site.xml
│           ├── mapred-site.xml
│           └── yarn-site.xml
├── LICENSE-AGPL
├── LICENSE.md
├── nginx
│   ├── Dockerfile
│   └── etc
│       └── nginx
│           └── nginx.conf
├── README.md
└── ubuntu-vm-setup.sh
```

---

## Getting Started

The instructions in this article should work on any system with Docker and Docker Compose installed.
However, since the Hadoop ecosystem is designed for educational purposes, it is recommended to set up a fresh Ubuntu Linux virtual machine using your preferred virtualization software and then follow the steps in the [Quick setup on Ubuntu virtual machine](#quick-setup-on-ubuntu-virtual-machine-recommended) section.
Within about 30 minutes, learners will have a lightweight yet fully functional Hadoop environment ready to explore.

### Quick Setup on Ubuntu Virtual Machine (Recommended)
You only need an Ubuntu Linux virtual machine (version 24.04 or later) before starting the setup process.

**<ins>Setup on a New Virtual Machine</ins>**  
To get started, download a stable version from this GitHub repository and run the `ubuntu-vm-setup.sh` script in the Terminal:

```shell
alice@u24arm64:~$ cd /PATH/TO/hadoop.lab
alice@u24arm64:/PATH/TO/hadoop.lab$ ./ubuntu-vm-setup.sh
```

After the script completes successfully, you will need to **reboot the virtual machine** to apply all changes.
Once the VM is up and running, you can access the Hadoop web UIs from within the VM:
* HDFS NameNode UI: `http://hadoop-master:9870`
* YARN ResourceManager UI: `http://hadoop-master:8088`
* MapReduce JobHistory Server UI: `http://hadoop-master:19888`

If you want to access the Hadoop UIs from outside the virtual machine, add the following line to your system hosts file:
* macOS or Linux: /etc/hosts
* Windows: C:\Windows\System32\drivers\etc\hosts

```
{IP} hadoop-master hadoop-worker1 hadoop-worker2 hadoop-worker3
```

Replace `{IP}` with the IP address of your virtual machine.

**<ins>Upgrade / Resume Setup</ins>**  
> [!WARNING]
> If your Hadoop environment was built manually, **do not run** `ubuntu-vm-setup.sh` on your system, as it may disrupt your existing setup.

Errors can occur while running `ubuntu-vm-setup.sh`, and new features may be added to the project over time.
You can re-run `ubuntu-vm-setup.sh` to reset your Hadoop environment at any time, but it’s recommended to **completely clean up old Docker data first**.

```shell
alice@u24arm64:~$ cd /PATH/TO/OLD/hadoop.lab
alice@u24arm64:/PATH/TO/OLD/hadoop.lab$ docker compose down
alice@u24arm64:/PATH/TO/OLD/hadoop.lab$ docker volume prune -a
alice@u24arm64:/PATH/TO/OLD/hadoop.lab$ docker image prune -a
alice@u24arm64:/PATH/TO/OLD/hadoop.lab$ cd /PATH/TO/NEW/hadoop.lab
alice@u24arm64:/PATH/TO/NEW/hadoop.lab$ ./ubuntu-vm-setup.sh
```

> [!NOTE]
> The commands above remove all Docker volumes used by the Hadoop environment.
> However, any data stored in the user’s home directory will **not** be deleted.

<a name="hadoop-client-usage"></a>
**<ins>Hadoop Client Usage</ins>**  
After the setup or upgrade process is complete, you can open a Terminal window on the virtual machine or alternatively, connect via SSH to start using the system.

At the shell prompt, switch to **Hadoop client mode** by entering the `hadoop-client` command.
This launches a shell inside the `hadoop-client` Docker container.
The change in the hostname shown in the shell prompt indicates that you are now in Hadoop client mode.
From here, you can run Hadoop CLI commands and/or submit MapReduce jobs.

To exit Hadoop client mode, use `exit` or press `Ctrl + D`.

```shell
alice@u24arm64:~$ hadoop-client
alice@hadoop-client:~$ hdfs dfs -ls /
Found 2 items
drwxrwxrwt   - hdfs supergroup          0 2025-08-19 08:04 /tmp
drwxr-xr-x   - hdfs supergroup          0 2025-08-19 08:05 /user
alice@hadoop-client:~$ exit
logout
alice@u24arm64:~$
```

> [!NOTE]
> Any data stored in the user’s home directory is shared and accessible both inside and outside Hadoop client mode, and will persist through upgrades.

### Manual Setup via Docker Compose (Advanced)
This option is intended for advanced users familiar with Linux system administration and Docker Compose.
You will need to manually handle user account synchronization between the host system and the Docker containers.

**<ins>Build Hadoop Docker Image</ins>**  
This step is optional and intended only for debugging purposes.
By default, Docker Compose will automatically build the image before launching containers.

```shell
bob@u24amd64:~$ cd /PATH/TO/hadoop.lab
bob@u24amd64:/PATH/TO/hadoop.lab$ docker build -t hadooplab/hadoop ./hadoop
```

**<ins>Start a 4-Node Hadoop Cluster and Hadoop Client via Docker Compose</ins>**  
The following instructions will build the Hadoop Docker image (if it does not already exist) and then start a 4-node Hadoop cluster (1 master + 3 workers) along with a Hadoop client.

```shell
bob@u24amd64:~$ cd /PATH/TO/hadoop.lab
bob@u24amd64:/PATH/TO/hadoop.lab$ docker compose up --build -d
```

Once all Docker containers are running, you can access the Hadoop web UIs:
* HDFS NameNode UI: `http://{HOSTNAME}:9870`
* YARN ResourceManager UI: `http://{HOSTNAME}:8088`
* MapReduce JobHistory Server UI: `http://{HOSTNAME}:19888`

Here, `{HOSTNAME}` refers to the hostname of the machine running the Docker containers, or `localhost` if you are accessing it from the same machine.

The usage of the Hadoop client is similar to what is described in the [Hadoop Client Usage](#hadoop-client-usage) section.
However, there is no `hadoop-client` command in this setup.
Instead, you must use the `/bridge` volume shared between the Docker host and the container, and configure the Hadoop client environment manually to match your Docker host.
You may refer to the `ubuntu-vm-setup.sh` script for guidance, but **do not run it**.

> [!NOTE]
> You may also notice an nginx container.
> Nginx acts as a reverse proxy, allowing browsers outside the Docker bridge network to access the web interfaces of the Hadoop master and worker nodes.

**<ins>Shut Down the Hadoop Cluster and Client via Docker Compose/ins>**  
The following commands will shut down the Hadoop cluster and client and remove all containers.
However, data and logs are preserved in persistent Docker volumes. When you start the cluster again, it will automatically reuse those volumes.

```shell
bob@u24amd64:~$ cd /PATH/TO/hadoop.lab
bob@u24amd64:/PATH/TO/hadoop.lab$ docker compose down
...
bob@u24amd64:/PATH/TO/hadoop.lab$ docker compose up -d
```

---

## Licensing

This project uses a **dual-licensing model**:

1. **AGPL v3 License (Free / Open Source)**  
   - Free for personal learning, academic research, and non-commercial use.  
   - Users of this version must comply with AGPL v3 obligations.  
   - See [LICENSE.md](LICENSE.md) and [LICENSE-AGPL](LICENSE-AGPL) for details.

2. **Commercial License**  
   - Required for commercial use, institutional deployment, or to avoid AGPL copyleft obligations.  
   - See [COMMERCIAL_LICENSE.md](COMMERCIAL_LICENSE.md) for details.  
   - Contact Christopher Ke at christopher.cske@gmail.com for inquiries.
