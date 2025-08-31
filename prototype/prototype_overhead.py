from collections import defaultdict
import csv
import os
import re

import matplotlib.pyplot as plt
import numpy as np

os.makedirs("images", exist_ok=True)
os.makedirs("result", exist_ok=True)

pattern = re.compile(r".*height=(\d+)\s+elapsed=(\d+)")

encoding_count = defaultdict(int)
encoding_result = defaultdict(int)
decoding_count = defaultdict(int)
decoding_result = defaultdict(int)

for filename in os.listdir("logs/overhead"):
    with open(os.path.join("logs/overhead", filename), "r") as file:
        for line in file:
            if "Encoding" in line:
                match = pattern.search(line)
                if match:
                    height = int(match.group(1))
                    elapsed = int(match.group(2))
                    encoding_count[height] += 1
                    encoding_result[height] += elapsed
            elif "Decoding" in line:
                match = pattern.search(line)
                if match:
                    height = int(match.group(1))
                    elapsed = int(match.group(2))
                    decoding_count[height] += 1
                    decoding_result[height] += elapsed

for height, count in encoding_count.items():
    encoding_result[height] /= count
for height, count in decoding_count.items():
    decoding_result[height] /= count

encoding_values = list(encoding_result.values())
decoding_values = list(decoding_result.values())

print(min(encoding_values), max(encoding_values), np.mean(encoding_values))
print(min(decoding_values), max(decoding_values), np.mean(decoding_values))

with open("result/prototype-overhead.csv", "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["height", "encoding", "decoding"])
    for h in sorted(set(encoding_result.keys()) | set(decoding_result.keys())):
        writer.writerow([h, encoding_result.get(h, ""), decoding_result.get(h, "")])

bins = np.arange(
    int(min(encoding_values + decoding_values) // 100) * 100,
    int(max(encoding_values + decoding_values) // 100 + 2) * 100,
    100,
)
labels = [f"[{bins[i]},{bins[i+1]})" for i in range(len(bins) - 1)]

encoding_hist, _ = np.histogram(encoding_values, bins=bins)
decoding_hist, _ = np.histogram(decoding_values, bins=bins)

x = np.arange(len(labels))
bar_width = 0.35

plt.rcParams["font.family"] = "Times New Roman"
plt.figure(figsize=(6, 3.6))
plt.bar(
    x - bar_width / 2,
    encoding_hist,
    width=bar_width,
    label="Encoding",
    edgecolor="black",
    linewidth=0.8,
)
plt.bar(
    x + bar_width / 2,
    decoding_hist,
    width=bar_width,
    label="Decoding",
    edgecolor="black",
    linewidth=0.8,
)
plt.xlabel("Elapsed Time/μs")
plt.ylabel("Frequency/%")
plt.xticks(x, labels)
plt.legend()
plt.tight_layout()
plt.savefig("images/prototype-overhead.pdf", bbox_inches="tight")
plt.close()
