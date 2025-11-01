---

# 🧭 Context.md — Multi-Mode Real-Time Visualizer for Single-Axis Ultrasonic Scanner

## 📖 Overview

This project visualizes real-time distance measurements from a **1-axis ultrasonic scanner** built with an **Arduino Uno**, an **HC-SR04 sensor**, and an **SG90 servo**.
The Arduino sweeps the sensor between **0–180°**, sending distance data via serial to a **Processing 4.x** sketch, which displays and logs the readings in various visualization modes.

The goal is to create an interactive, real-time, multi-view visualizer that can display, record, and replay the scanner data efficiently and intuitively.

---

## ⚙️ Hardware Setup

| Component       | Description                                  |
| --------------- | -------------------------------------------- |
| **Arduino Uno** | Controls servo and sensor; sends serial data |
| **HC-SR04**     | Ultrasonic distance sensor                   |
| **SG90 Servo**  | Rotates the sensor across 0–180°             |
| **PC / Laptop** | Runs the Processing visualization            |
| **Connection**  | USB Serial @ 115200 baud                     |

---

## 🧾 Serial Data Format

Each line from the Arduino represents a single reading:

```
angle,distance,timestamp\n
```

Example:

```
45,123,1678912345
```

| Field       | Type  | Description                                                 |
| ----------- | ----- | ----------------------------------------------------------- |
| `angle`     | int   | Servo position in degrees (0–180)                           |
| `distance`  | float | Measured distance in centimeters (`999` or `nan` = invalid) |
| `timestamp` | long  | Time from Arduino `millis()` or system epoch (ms)           |

---

## 🖥️ Visualization Modes (Processing)

The Processing app supports several **visualization tabs**, switchable by keys (`1–5`) or GUI buttons:

| Mode | Name                        | Description                                       |
| ---- | --------------------------- | ------------------------------------------------- |
| `1`  | **Polar / Radar View**      | Sweeping arm display of distance points           |
| `2`  | **Cartesian 2D**            | (x = d·cosθ, y = d·sinθ) top-down scatter plot    |
| `3`  | **Angle vs Distance Graph** | Line graph (angle on X-axis, distance on Y-axis)  |
| `4`  | **Replay / Heatmap**        | Temporal visualization, fading trails or timeline |
| `5`  | **3D Fan Sweep (P3D)**      | Extruded 3D representation of scanned area        |

---

## 🧮 Data Processing Features

* **Real-time plotting** with rolling buffer of N sweeps
* **Logging & Replay** (save/load CSV data)
* **Smoothing / Filters:**

  * Exponential Moving Average (EMA)
  * Median filter per-angle
  * Optional outlier rejection
* **Color mapping** by distance (hue/brightness gradient)
* **Performance target:** 30+ FPS with standard Arduino refresh rate

---

## 🎛️ Interactive Controls

* Connect/disconnect serial port
* Pause/resume visualization
* Clear buffer
* Adjust smoothing / max radius
* Toggle grid, labels, color maps
* Save CSV / replay from CSV
* Optional: Export PNG snapshot

---

## 📦 Deliverables

1. **Processing Sketch (.pde)** — modular, documented, multi-tab capable
2. **Arduino Test Sketch** — generates simulated sweep data for testing
3. **README.md** — wiring instructions + usage guide
4. **Context.md** *(this file)* — overview and project reference

---

## 🧩 Development Notes

* Use `ControlP5` or `G4P` for GUI controls
* Use `PGraphics` layers for efficient drawing
* Polar → Cartesian conversion:

  ```java
  x = distance * cos(radians(angle));
  y = distance * sin(radians(angle));
  ```
* Keep the origin at the canvas center
* For replay, interpolate data points based on timestamp
* Modularize code into logical sections:

  * `SerialHandler`
  * `Visualizer` (with submodes)
  * `Filter` (EMA, median)
  * `UIController`
  * `ReplayManager`

---

## 🧱 Project Intent

This context file ensures developers or AI assistants understand the project structure and expected behavior before generating code or documentation.
It defines *what the system should achieve* — not the step-by-step implementation — and should be used alongside `Prompt.md` or `README.md` for development.

---
