# Artifact Evaluation for ECCB

This repository shows how to reproduce the simulation and prototyping experiments in the paper **ECCB: Boosting Block Propagation of Blockchain with Erasure-Coded Compact Block (to appear in EuroSys ’26, Edinburgh, UK)**.

```BibTeX
@inproceedings{cai2026eccb,
  author    = {Bingyi Cai, Shenggang Wan and Hong Jiang},
  title     = {ECCB: Boosting Block Propagation of Blockchain with Erasure-Coded Compact Block},
  booktitle = {Proceedings of the 21st ACM European Conference on Computer Systems (EuroSys '26)},
  year      = {2026},
  publisher = {ACM},
  address   = {Edinburgh, United Kingdom},
  note      = {To appear},
}
```

## Project Structure
| Folder / File | Description |
| :-: | - |
| bnsim | All code and data for the simulation are contained in this folder. It includes BN-Sim (a blockchain network simulator for ECCB) and datasets, including hitting transactions in two neighboring nodes and the blocks at the corresponding heights. |
| prototype | All code and data for the prototyping experiment are contained in this folder. It includes a prototyping implementation (prototype/go-ethereum), ethex (an Ethereum transaction extractor, in prototype/ethex), scripts for the prototyping experiments, and example transactions (prototype/txs) extracted by ethex. |
| requirements.txt | A file listing all required Python dependencies. |

## Hardware Dependencies
### Simulation
- CPU: 16 cores
- RAM: 32 GB
- SSD: 64 GB
- Network access to the Internet

It is recommended to run the simulation on an [AliCloud](https://www.aliyun.com) server of type **ecs.sn1.3xlarge**.

### Prototyping Experiment
101 servers, each with the following specifications:
- CPU: 32 cores
- RAM: 64 GB
- SSD: 64 GB

The servers' IPs should range from 192.168.1.100 to 192.168.1.200. The server with IP 192.168.1.100 is the manager node. All operations are performed on the manager node.

All servers should be connected to a local area network, and the manager node should have Internet access.

It is recommended to run the prototyping experiment on [AliCloud](https://www.aliyun.com) servers of type **ecs.sn1ne.8xlarge**, so that you can configure IPs when creating server instances.

## Software Dependencies
### Operating System
Debian sid and Ubuntu 24.04 are tested and recommended.

### APT Packages
- build-essential
- git-lfs
- golang (v1.22)
- python-is-python3
- python3
- python3-venv
- sshpass

### Python Packages
Listed in [requirements.txt](requirements.txt).

## Setup
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

## Simulation
Please refer to [bnsim/README.md](bnsim/README.md) for detailed steps.

A short version is as follows. The working directory for the simulation is **~/eccbae/bnsim**. Run the following commands:

```bash
# activate Python virtual environment
source ~/eccbae/.venv/bin/activate

# preparation
./bnsim preprocess blocks.rlp.zst eccb1.log.zst eccb2.log.zst

# experiment 1
./bnsim simulate-correction-factor

# experiment 2
./bnsim simulate-scalability

# experiment 3
./bnsim simulate-block-size

# experiment 4
./bnsim simulate-bandwidth

# experiment 5
./bnsim simulate-similarity
```

The results can be found in **bnsim/result** and **bnsim/images**.

## Prototyping Experiment
Please refer to [prototype/README.md](prototype/README.md) for detailed steps.

A short version is as follows. The working directory for the prototyping experiments is **/geth**. Run the following commands:

```bash
# activate Python virtual environment
source ~/eccbae/.venv/bin/activate

# preparation
./multinodes.sh config 100 [user password] # replace [user password] with your current user's login password

# experiment 6
./multinodes.sh scalability 400 native
./multinodes.sh scalability 400 alias
./multinodes.sh scalability 400 bcb
./multinodes.sh scalability 400 eccb
./multinodes.sh scalability 400 aeccb
./multinodes.sh scalability 800 native
./multinodes.sh scalability 800 alias
./multinodes.sh scalability 800 bcb
./multinodes.sh scalability 800 eccb
./multinodes.sh scalability 800 aeccb
./multinodes.sh scalability 1600 native
./multinodes.sh scalability 1600 alias
./multinodes.sh scalability 1600 bcb
./multinodes.sh scalability 1600 eccb
./multinodes.sh scalability 1600 aeccb
./multinodes.sh scalability 3200 native
./multinodes.sh scalability 3200 alias
./multinodes.sh scalability 3200 bcb
./multinodes.sh scalability 3200 eccb
./multinodes.sh scalability 3200 aeccb
python prototype_scalability.py

# experiment 7
./multinodes.sh similarity 90 native
./multinodes.sh similarity 90 alias
./multinodes.sh similarity 90 bcb
./multinodes.sh similarity 90 eccb
./multinodes.sh similarity 90 aeccb
./multinodes.sh similarity 60 native
./multinodes.sh similarity 60 alias
./multinodes.sh similarity 60 bcb
./multinodes.sh similarity 60 eccb
./multinodes.sh similarity 60 aeccb
python prototype_similarity.py

# experiment 8
./multinodes.sh overhead
python prototype_overhead.py
```

The results can be found in **bnsim/result** and **bnsim/images**.

## Troubleshooting
Please refer to [bnsim/README.md](bnsim/README.md) and [prototype/README.md](prototype/README.md).

## License
This project is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).
