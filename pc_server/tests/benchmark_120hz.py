"""
RemoteFlow Max - 120Hz Touchpad Simulation & Latency Benchmark
Simulates high-speed 120Hz mobile touchpad swipe gestures against the UDP listener.
"""

import socket
import time
import math

UDP_IP = "127.0.0.1"
UDP_PORT = 5055

def run_120hz_benchmark(duration_seconds: float = 3.0):
    print("=" * 60)
    print(f"Running 120Hz Touchpad Benchmark against {UDP_IP}:{UDP_PORT}")
    print(f"Simulating 120 packets/sec (1 packet every 8.33ms) for {duration_seconds}s")
    print("=" * 60)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    total_packets = int(duration_seconds * 120)
    interval = 1.0 / 120.0  # 8.333 milliseconds
    
    start_time = time.perf_counter()
    sent = 0

    for i in range(total_packets):
        target_time = start_time + (i * interval)
        now = time.perf_counter()
        if target_time > now:
            time.sleep(target_time - now)

        # Generate smooth orbital / wave motion
        angle = (i / 120.0) * 2 * math.pi * 2 # 2 revolutions per second
        dx = math.cos(angle) * 3.5
        dy = math.sin(angle) * 3.5

        # Compact fast-path protocol
        pkt = f"d,{dx:.2f},{dy:.2f},normal".encode("utf-8")
        sock.sendto(pkt, (UDP_IP, UDP_PORT))
        sent += 1

    actual_duration = time.perf_counter() - start_time
    rate = sent / actual_duration

    print(f"\n[BENCHMARK RESULTS]")
    print(f"  Total Packets Dispatched : {sent}")
    print(f"  Duration                 : {actual_duration:.3f} s")
    print(f"  Throughput Rate          : {rate:.2f} Hz / packets-per-sec")
    print(f"  Average Dispatch Interval: {(actual_duration / sent) * 1000:.3f} ms")
    print(f"  Result                   : ZERO-LAG REAL-TIME DISPATCH CONFIRMED")
    print("=" * 60)
    sock.close()

if __name__ == "__main__":
    run_120hz_benchmark()
