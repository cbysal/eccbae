import csv
from datetime import datetime
import os
import re

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.interpolate import PchipInterpolator

os.makedirs("images", exist_ok=True)
os.makedirs("result", exist_ok=True)

pattern = re.compile(r"(\d{2}-\d{2}\|\d{2}:\d{2}:\d{2}\.\d{3}).*number=(\d+)")
methods = ["native", "alias", "bcb", "eccb", "aeccb"]
dirs = []
for type in methods:
    for ratio in [90, 60]:
        dirs.append(f"{ratio}-{type}")

for dir in dirs:
    timestamps = [[] for _ in range(100)]
    for filename in os.listdir(f"logs/similarity-{dir}"):
        with open(os.path.join(f"logs/similarity-{dir}", filename), "r") as file:
            for line in file:
                if "WriteBlock" not in line:
                    continue
                match = pattern.search(line)
                time_str = match.group(1)
                number = int(match.group(2)) - 10
                if number < 0 or number >= 100:
                    continue
                timestamp = datetime.strptime(time_str, "%m-%d|%H:%M:%S.%f")
                timestamps[number].append(timestamp)

    durations = []
    for tss in timestamps:
        min_ts = min(tss)
        durations.append(
            sorted(
                (ts - min_ts).seconds * 1000 + (ts - min_ts).microseconds // 1000
                for ts in tss
            )
        )

    csvdata = list(zip(*durations))
    with open(f"result/prototype-similarity-{dir}.csv", mode="w") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerows(csvdata)

labels = ["Native", "Alias", "BCB", "ECCB", "AECCB"]

for ratio in [90, 60]:
    result = pd.DataFrame(np.zeros((3200, len(methods))))
    plt.rcParams["font.family"] = "Times New Roman"
    plt.figure(figsize=(2.5, 1.5))
    for i, method in enumerate(methods):
        df = pd.read_csv(
            f"result/prototype-similarity-{ratio}-{method}.csv", header=None
        )
        sorted_times = df.mean(axis=1).sort_values().reset_index(drop=True)
        result[i] = sorted_times
        reachability = np.arange(1, len(sorted_times) + 1) / len(sorted_times) * 100
        sampled_times = (
            [sorted_times.iloc[0]]
            + sorted_times.iloc[1:-1:100].tolist()
            + [sorted_times.iloc[-1]]
        )
        sampled_reachability = (
            [reachability[0]] + reachability[1:-1:100].tolist() + [reachability[-1]]
        )
        time_smooth = np.linspace(min(sampled_times), max(sampled_times), 300)
        reachability_pchip = PchipInterpolator(sampled_times, sampled_reachability)
        reachability_smooth = reachability_pchip(time_smooth)
        plt.plot(time_smooth, reachability_smooth, label=labels[i])
    result.to_csv(f"result/prototype-similarity-{ratio}.csv", header=None, index=False)
    plt.xlabel("Time/ms")
    plt.ylabel("Reachability/%")
    plt.xlim(0, 6250)
    plt.ylim(0, 100)
    plt.legend(loc="lower right")
    plt.grid(True)
    plt.savefig(f"images/prototype-similarity-{ratio}.pdf", bbox_inches="tight")
    plt.close()
