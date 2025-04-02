import argparse
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime
import dateutil.parser
import os
import itertools
import re

# --- Parse Arguments ---
parser = argparse.ArgumentParser()
parser.add_argument('--prefix', default='')
args = parser.parse_args()

# --- Derived Paths ---
log_dir = os.path.join(os.path.dirname(__file__), f"{args.prefix}-logs")
plot_dir = os.path.join(os.path.dirname(__file__), f"{args.prefix}-plots")

# Ensure output directory exists and is clean
if not os.path.exists(plot_dir):
    os.makedirs(plot_dir)
else:
    for f in os.listdir(plot_dir):
        os.remove(os.path.join(plot_dir, f))

cpu_path = os.path.join(log_dir, "cpu.csv")
mem_path = os.path.join(log_dir, "mem.csv")
disk_path = os.path.join(log_dir, "disk.csv")

# --- Helpers ---
def read_marker(path):
    with open(path) as f:
        dt = dateutil.parser.parse(f.read().strip())
        return dt.replace(tzinfo=None)

def read_typeperf_csv(path):
    df = pd.read_csv(path, skiprows=1)
    df.columns = ['Timestamp', 'Value']
    df['Timestamp'] = pd.to_datetime(df['Timestamp'])
    df['Value'] = pd.to_numeric(df['Value'], errors='coerce')
    return df.dropna()

def format_label(name):
    match = re.match(r"(\d+)_([a-z_]+)_(start|end)", name, re.I)
    if match:
        bitrate, video, _ = match.groups()
        video = video.replace('_', ' ').title()
        return f"{bitrate}Mbps {video}"
    elif f"process_{args.prefix}_start" in name:
        return f"{args.prefix.upper()} Start"
    elif f"process_{args.prefix}_stop" in name:
        return f"{args.prefix.upper()} Stop"
    else:
        return name.replace('_', ' ').title()

# --- Load logs ---
cpu_df = read_typeperf_csv(cpu_path)
mem_df = read_typeperf_csv(mem_path)
disk_df = read_typeperf_csv(disk_path)

# --- Load markers dynamically ---
raw_markers = {}
for fname in os.listdir(log_dir):
    if fname.endswith('.marker'):
        name = fname.replace('.marker', '').lower()
        path = os.path.join(log_dir, fname)
        raw_markers[name] = read_marker(path)

# --- Group related markers for color pairing ---
grouped = {}
for raw_name in raw_markers.keys():
    group = re.sub(r'_(start|end)$', '', raw_name)
    if group not in grouped:
        grouped[group] = []
    grouped[group].append(raw_name)

# --- Plotting Function ---
def plot_with_markers(df, ylabel, title, basename):
    filename = f"{args.prefix}_{basename}.png" if args.prefix else f"{basename}.png"
    filepath = os.path.join(plot_dir, filename)

    plt.figure(figsize=(16, 6))
    plt.plot(df['Timestamp'], df['Value'], label=ylabel)

    color_cycle = itertools.cycle(['orange', 'blue', 'red', 'purple', 'brown', 'pink', 'cyan', 'magenta'])
    color_map = {}

    for group, events in grouped.items():
        color = next(color_cycle)
        for name in events:
            ts = raw_markers[name]
            label = format_label(name)
            if label not in color_map:
                plt.axvline(ts, linestyle='--', color=color, label=label)
                color_map[label] = color
            else:
                plt.axvline(ts, linestyle='--', color=color_map[label])

    plt.xlabel('Time')
    plt.ylabel(ylabel)
    plt.title(title)
    plt.legend(loc='center left', bbox_to_anchor=(1.02, 0.5), fontsize='small')
    plt.tight_layout(rect=[0, 0, 0.85, 1])
    plt.savefig(filepath)
    plt.close()

# --- Generate plots ---
plot_with_markers(cpu_df, 'CPU %', 'CPU Usage Over Time', 'cpu')
plot_with_markers(mem_df, 'Available Memory (MB)', 'Memory Usage Over Time', 'memory')
plot_with_markers(disk_df, 'Bytes/sec', 'Disk Write Bytes Over Time', 'disk')
