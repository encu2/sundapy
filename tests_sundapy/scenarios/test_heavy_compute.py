#strict
import matplotlib.pyplot as plt
import numpy.random as np_random
import numpy as np
import time
import _thread

WIDTH: int = 1200
HEIGHT: int = 720
FRAMES: int = 120

print("Memulai simulasi Kiamat Komputasi Angin (10-bit color, 120 frames) dengan Multithreading...")

SKY: int = 200
GROUND: int = 800
TRUNK: int = 500
LEAVES: int = 600

y: Dynamic = np.arange(HEIGHT)
x: Dynamic = np.arange(WIDTH)
y2: Dynamic = np.reshape(y, [HEIGHT, 1])
x2: Dynamic = np.reshape(x, [1, WIDTH])

ground_cond: Dynamic = np.greater_equal(y2, 600)

cond_x_1: Dynamic = np.greater_equal(x2, 570)
cond_x_2: Dynamic = np.less_equal(x2, 630)
cond_x: Dynamic = np.logical_and(cond_x_1, cond_x_2)

cond_y_1: Dynamic = np.greater_equal(y2, 350)
cond_y_2: Dynamic = np.less_equal(y2, 600)
cond_y: Dynamic = np.logical_and(cond_y_1, cond_y_2)
trunk_cond: Dynamic = np.logical_and(cond_x, cond_y)

def compute_chunk(start_f: int, end_f: int, thread_idx: int) -> void:
    for f in range(start_f, end_f):
        time_factor: Dynamic = np.multiply([f], 0.1)
        wind_shift: Dynamic = np.sin(time_factor)
        wind_shift_scaled: Dynamic = np.multiply(wind_shift, 80.0)
        
        center_x: Dynamic = np.add(600.0, wind_shift_scaled)
        
        dx: Dynamic = np.subtract(x2, center_x)
        dy: Dynamic = np.subtract(y2, 250)
        dx2: Dynamic = np.power(dx, 2)
        dy2: Dynamic = np.power(dy, 2)
        dist2: Dynamic = np.add(dx2, dy2)
        leaves_cond: Dynamic = np.less_equal(dist2, 60000)
        
        frame: Dynamic = np.full([HEIGHT, WIDTH], SKY)
        
        frame = np.where(ground_cond, GROUND, frame)
        frame = np.where(trunk_cond, TRUNK, frame)
        frame = np.where(leaves_cond, LEAVES, frame)
        
        noise: Dynamic = np_random.normal(0, 10, [HEIGHT, WIDTH])
        frame_noisy: Dynamic = np.add(frame, noise)
        frame_clipped: Dynamic = np.clip(frame_noisy, 0, 1023)
        
        _thread.set_frame(f, frame_clipped)
        
        if (f % 10) == 0:
            print("Merender frame:", f)

    print("Thread", thread_idx, "Selesai!")

start_time: Dynamic = time.time_ns()

_thread.start_new_thread(compute_chunk, [0, 30, 0])
_thread.start_new_thread(compute_chunk, [30, 60, 1])
_thread.start_new_thread(compute_chunk, [60, 90, 2])
_thread.start_new_thread(compute_chunk, [90, 120, 3])

sleep_time: int = 5
time.sleep(sleep_time)

end_time: Dynamic = time.time_ns()
durasi: Dynamic = np.subtract(end_time, start_time)
fps: Dynamic = np.divide(120000000000.0, durasi)
print("Rata-rata FPS komputasi murni:", fps)

print("Memulai playback animasi di Main Thread...")

plt.ion()
for f in range(0, 120):
    frame: Dynamic = _thread.get_frame(f)
    plt.imshow(frame)
    plt.title("Simulasi Kiamat Komputasi Angin")
    plt.pause(0.016)

print("Menampilkan frame terakhir selama 3 detik...")
plt.pause(3.0)
plt.ioff()
print("Selesai!")
