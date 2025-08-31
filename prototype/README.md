# ECCB Prototyping Experiment

This folder contains the components for ECCB prototyping experiments.

## Project Structure
| Folder / File | Description |
| :-: | - |
| ethex | an Ethereum transaction extractor to extract workloads from a standard database synchronized from Geth |
| go-ethereum | an ECCB prototyping implementation modified from Geth |
| txs | an example workload extracted from ethex |
| multinodes.sh | script to run prototyping experiments |
| network.py | script to generate the network topology, which is used by multinodes.sh |
| prototype_scalability.py, prototype_similarity.py, prototype_overhead.py | scripts to plot figures for each experiment |

## Hardware Dependencies
101 servers, each with the following specifications:
- CPU: 32 cores
- RAM: 64 GB
- SSD: 64 GB

The servers' IPs should range from 192.168.1.100 to 192.168.1.200. The server with IP 192.168.1.100 is the manager node. All operations are performed on the manager node.

All servers should be connected to a local area network, and the manager node should have Internet access.

It is recommended to run the prototyping experiment on [AliCloud](https://www.aliyun.com) servers of type **ecs.sn1ne.8xlarge**, so that you can configure IPs when creating server instances.

## Software Dependencies
### Operating System
Ubuntu 24.04 is tested and recommended.

### APT Packages
- build-essential
- git-lfs
- golang (v1.22)
- python-is-python3
- python3
- python3-venv
- sshpass

### Python Packages
Listed in [requirements.txt](../requirements.txt).

## Setup
It is highly recommended to set up as the root user.

Install the APT packages:

```bash
cd ~ && apt update
apt install build-essential git-lfs golang python-is-python3 python3 python3-venv sshpass
```

Clone this repository and initialize its submodules:

```bash
git clone https://github.com/cbysal/eccbae.git
cd eccbae && git submodule update --init
```

Set up a Python virtual environment and install the Python packages:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Build
Create a directory and copy everything necessary:

```bash
mkdir /geth
cp -r ~/eccbae/prototype/* /geth
```

Change the working directory and build the ECCB prototyping implementation:

```bash
cd /geth
make -C go-ethereum
cp go-ethereum/build/bin/geth .
```

## Run
It is highly recommended to run experiments as the root user.

### Preparation
```bash
./multinodes.sh config 100 [user password]
```

Note: Please replace [user password] with the password of the current user.

This command configures password-free access for the server at 192.168.1.100 to access 192.168.1.[101-200]. If you have another method to configure password-free access, it is acceptable, but ensure the manager node can maintain at least 3200 connections with other servers and 32 connections with each server.

### Network Scale
```bash
./multinodes.sh scalability [scale] [protocol]
```

This command performs the network scale prototyping experiment in ECCB [1]. **scale** is the network scale and **protocol** is the propagation protocol. Please replace [scale] and [protocol] with the following 20 combinations:
| scale | protocol |
| :-: | :-: |
| 400 | native |
| 400 | alias |
| 400 | bcb |
| 400 | eccb |
| 400 | aeccb |
| 800 | native |
| 800 | alias |
| 800 | bcb |
| 800 | eccb |
| 800 | aeccb |
| 1600 | native |
| 1600 | alias |
| 1600 | bcb |
| 1600 | eccb |
| 1600 | aeccb |
| 3200 | native |
| 3200 | alias |
| 3200 | bcb |
| 3200 | eccb |
| 3200 | aeccb |

Each combination will generate logs in the folder **logs/scalability-[scale]-[protocol]**. Each file in this folder is a log recorded from a node. After running all combinations, you can run the following command to get parsed results and figures:

```bash
python prototype_scalability.py
```

You can find parsed data in **result/prototype-scalability-[scale]-[protocol].csv** and figures in **images/prototype-scalability-[scale]-[protocol].pdf**.

### Hitting Transaction Ratio
```bash
./multinodes.sh similarity [ratio] [protocol]
```

This command performs the hitting transaction ratio prototyping experiment in ECCB [1]. **ratio** is the hitting transaction ratio and **protocol** is the propagation protocol. Please replace [ratio] and [protocol] with the following 10 combinations:
| ratio | protocol |
| :-: | :-: |
| 90 | native |
| 90 | alias |
| 90 | bcb |
| 90 | eccb |
| 90 | aeccb |
| 60 | native |
| 60 | alias |
| 60 | bcb |
| 60 | eccb |
| 60 | aeccb |

Each combination will generate logs in the folder **logs/similarity-[ratio]-[protocol]**. Each file in this folder is a log recorded from a node. After running all combinations, you can run the following command to get parsed results and figures:

```bash
python prototype_similarity.py
```

You can find parsed data in **result/prototype-similarity-[ratio]-[protocol].csv** and figures in **images/prototype-similarity-[ratio]-[protocol].pdf**.

### Overhead
```bash
./multinodes.sh overhead
```

This command performs the overhead prototyping experiment in ECCB [1]. The logs will be saved in the folder **logs/overhead**. Each file in this folder is a log recorded from a node. After running this command, you can run the following command to get parsed results and figures:

```bash
python prototype_overhead.py
```

You can find parsed data in **result/prototype-overhead.csv** and figures in **images/prototype-overhead.pdf**.

## Other Usages
All the commands presented in [Run](#run) are actually combinations of the following commands.

Note that the Ethereum nodes described below are our ECCB prototyping implementation.

### Config
```bash
./multinodes.sh config [servers]
```

This command configures password-free access from 192.168.1.100 to 192.168.1.[101-$((param1 + 1))]. You can change **servers** if you have a different number of servers. But make sure the IPs range from 192.168.1.101 onward.

### Run
```bash
./multinodes.sh run [name] [servers] [nodes_per_server] [protocol] [txs] [matchblock] [matchtxs]
```
This command runs a total of **servers * nodes_per_server** Ethereum nodes in propagation protocol **protocol**, $$nodes_per_server$$ per server, on servers with IPs 192.168.1.[101-$((100+servers))], using transactions from **txs** with block matching ratio **matchblock** and hitting transaction ratio **matchtxs**, and saves logs to **logs/$name**. The parameters are described as follows:
| Parameter | Description |
| :-: | - |
| name | the folder to save logs, located in **logs/**, e.g., if it is **abc**, then the logs' folder is **logs/abc** |
| servers | number of servers to run Ethereum nodes |
| nodes_per_server | number of Ethereum nodes to run on each server |
| protocol | 68 stands for Native, 69 stands for BCB, 70 stands for ECCB |
| txs | path of the transaction database to generate blocks |
| matchblock | block matching ratio, which is the complement of the recommunication ratio |
| matchtxs | hitting transaction ratio |

### Stop
```bash
./multinodes.sh stop [servers]
```

This command stops all Ethereum nodes on servers 192.168.1.[101-$((servers + 1))].

### Clean
```bash
./multinodes.sh clean [servers]
```

This command cleans the last performed experiment on servers 192.168.1.[101-$((servers + 1))].

## Troubleshooting
1. Why do I fail to build BN-Sim?

Please install the [software dependencies](#software-dependencies) and check if the Go version is 1.22.

2. Why do I fail to run the subcommands (scalability, similarity, or overhead) or plot figures?

Please ensure the Python virtual environment is activated. If not, run the following command:
```bash
source ~/eccbae/.venv/bin/activate
```

3. Why are there so many "permission denied" messages?

You may not have configured password-free access. See [Preparation](#preparation).

4. Why do I find a very long tail in the output figure?

Some nodes may have lost connections. Please rerun the corresponding command to obtain a normal result.

## License
This project is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).

## References
[1] Bingyi Cai, Shenggang Wan, and Hong Jiang. *ECCB: Boosting Block Propagation of Blockchain with Erasure-Coded Compact Block*. EuroSys '26, ACM, 2026.
