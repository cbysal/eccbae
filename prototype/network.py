import heapq
import json
import os
import shutil
import sys

from ecdsa import SigningKey, SECP256k1
import networkx as nx

machine_num = int(sys.argv[1])
node_num = int(sys.argv[2])
conn_num = int(sys.argv[3])
bandwidth = int(sys.argv[4])
conn_num = min(conn_num, machine_num * node_num)
beta = 0.2

G = nx.watts_strogatz_graph(machine_num * node_num, conn_num, beta, seed=0)

positions = {i: i for i in G.nodes}

dists = []
for u, v in G.edges:
    pos_u = positions[u]
    pos_v = positions[v]
    dist = abs(positions[u] - positions[v])
    dist = min(dist, machine_num * node_num - dist)
    dists.append(dist)

bound = heapq.nsmallest(int(len(dists) * (1 - beta)), dists)[-1]

for u, v in G.edges:
    dist = abs(positions[u] - positions[v])
    dist = min(dist, machine_num * node_num - dist)
    G.edges[u, v]["latency"] = 50 if dist <= bound else 1200


def id_to_key(id):
    hex_private_key = f"{id:064x}"
    private_key_bytes = bytes.fromhex(hex_private_key)
    signing_key = SigningKey.from_string(private_key_bytes, curve=SECP256k1)
    verifying_key = signing_key.verifying_key
    public_key_bytes = verifying_key.to_string()
    public_key_hex = public_key_bytes.hex()
    return public_key_hex


if os.path.exists("network"):
    shutil.rmtree("network")
os.makedirs("network")

for node in G.nodes:
    result = {
        "address": f"192.168.1.{101 + node // node_num}:{23000 + node % node_num}",
        "bandwidth": bandwidth * 1024 * 1024 // 8,
        "peers": {},
    }
    for neighbor in G.neighbors(node):
        key = id_to_key(neighbor + 1)
        result["peers"][
            f"192.168.1.{101 + neighbor // node_num}:{23000 + neighbor % node_num}"
        ] = {
            "enode": f"enode://{key}@192.168.1.{101 + neighbor // node_num}:{23000 + neighbor % node_num}",
            "latency": G.edges[node, neighbor]["latency"],
        }
    with open(f"network/node{node}.json", "w") as file:
        json.dump(result, file, indent=4)
