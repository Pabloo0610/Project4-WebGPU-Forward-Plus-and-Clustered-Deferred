import matplotlib.pyplot as plt
import numpy as np

# ===============================
# 数据部分（你可以改成真实测量值）
# ===============================

# 不同 light 数量
light_counts = np.array([250, 500, 1000, 2500, 5000])

# 三种方法的帧时间 (ms)
naive_times = np.array([27.7, 52.63, 111, 250, 500])
forward_times = np.array([5.9, 6.9, 8.69, 12.5, 20.83])
deferred_times = np.array([5.9, 6.9, 8.3, 8.47, 9.52])

# 不同 cluster 容量
lights_per_cluster = np.array([64, 128, 256, 512])
forward_cluster_times = np.array([8.84, 12.98, 20, 14.28])
deferred_cluster_times = np.array([3.8, 6.9, 9.25, 9.61])

# ===============================
# 图 1：Frame time vs Light count
# ===============================
plt.figure(figsize=(6,4))
plt.plot(light_counts, naive_times, marker='o', label='Naive Forward')
plt.plot(light_counts, forward_times, marker='o', label='Forward+')
plt.plot(light_counts, deferred_times, marker='o', label='Clustered Deferred')

plt.xlabel('Number of Lights')
plt.ylabel('Frame Time (ms)')
plt.title('Frame Time vs Light Count')
plt.legend()
plt.grid(True, linestyle='--', alpha=0.5)
plt.tight_layout()
plt.savefig('performance_vs_light_count.png', dpi=200)

# ===============================
# 图 2：Frame time vs Lights per cluster
# ===============================
plt.figure(figsize=(6,4))
plt.plot(lights_per_cluster, forward_cluster_times, marker='o', label='Forward+')
plt.plot(lights_per_cluster, deferred_cluster_times, marker='o', label='Clustered Deferred')

plt.xlabel('Lights per Cluster')
plt.ylabel('Frame Time (ms)')
plt.xticks(lights_per_cluster)
plt.title('Frame Time vs Lights per Cluster')
plt.legend()
plt.grid(True, linestyle='--', alpha=0.5)
plt.tight_layout()
plt.savefig('performance_vs_lights_per_cluster.png', dpi=200)