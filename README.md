---

# 🧭 README.md — Multi-Mode Real-Time Visualizer for Single-Axis Ultrasonic Scanner

## 📖 Overview

This project creates a **real-time visualizer** for a **single-axis ultrasonic scanner** using **Arduino + Processing 4.x**.
It displays live angle and distance data, supports multiple visualization modes (2D, 3D, graph, radar), allows CSV logging/replay, and includes smoothing filters.

---

## ⚙️ Hardware Requirements

| Component       | Description                                 |
| --------------- | ------------------------------------------- |
| **Arduino Uno** | Controls the servo and reads distance data  |
| **HC-SR04**     | Ultrasonic distance sensor                  |
| **SG90 Servo**  | Rotates the sensor from 0° to 180°          |
| **USB Cable**   | For serial connection (default 115200 baud) |
| **Computer**    | Runs Processing 4.x for visualization       |

---

## 🧩 Wiring Guide

| HC-SR04 | Arduino Pin |
| ------- | ----------- |
| VCC     | 5V          |
| GND     | GND         |
| TRIG    | pin10       |
| ECHO    | pin11       |

| SG90 Servo      | Arduino Pin |
| --------------- | ----------- |
| Orange (Signal) | pin12       |
| Red (VCC)       | 5V          |
| Brown (GND)     | GND         |

Make sure the servo and sensor share a **common ground** with the Arduino.

---

## 🔌 Serial Data Format

Each data line sent by the Arduino must follow this **CSV format**:

```
angle,distance,timestamp\n
```

Example:

```
45,123,1678912345
```

| Field       | Description                               |
| ----------- | ----------------------------------------- |
| `angle`     | Servo angle (0–180°)                      |
| `distance`  | Distance in cm (`999` or `nan` = invalid) |
| `timestamp` | Arduino `millis()` or epoch seconds       |

---

## 🧠 Software Requirements

| Tool                     | Version | Purpose                               |
| ------------------------ | ------- | ------------------------------------- |
| **Arduino IDE**          | ≥ 2.0   | Upload sketch to Arduino              |
| **Processing**           | ≥ 4.0   | Run visualization program             |
| **ControlP5** or **G4P** | Latest  | For UI elements (tabs, sliders, etc.) |

---

## 🖥️ Features Summary

✅ **Core:**

* Real-time visualization of distance data
* Multiple visualization modes
* CSV logging and replay
* Adjustable smoothing (EMA, median)
* Distance-based color mapping
* GUI for serial, filters, and controls

✨ **Optional:**

* Auto-detect serial ports
* Motion detection between sweeps
* Fade trails or time-based animation
* 3D orbit control (mouse drag)
* Export current view as PNG

---

## 🧮 Visualization Modes

| Key | Mode                   | Description                   |
| --- | ---------------------- | ----------------------------- |
| `1` | **Radar / Polar**      | Sweeping arm radar view       |
| `2` | **Cartesian 2D**       | X = d·cosθ, Y = d·sinθ        |
| `3` | **Angle vs Distance**  | Line graph view               |
| `4` | **Replay / Heatmap**   | Time-based visualization      |
| `5` | **3D Fan Sweep (P3D)** | Extruded depth representation |

Switch modes using number keys or GUI tabs.

---

## 🎛️ Controls

| Key / Button | Action                       |
| ------------ | ---------------------------- |
| `C`          | Connect / Disconnect Serial  |
| `P`          | Pause / Resume data stream   |
| `R`          | Start / Stop recording (CSV) |
| `L`          | Load CSV for replay          |
| `← / →`      | Change smoothing parameters  |
| `Space`      | Clear current buffer         |
| `S`          | Save PNG snapshot            |
| `1–5`        | Switch visualization mode    |

(Controls can be adapted if using a GUI library like ControlP5.)

---

## 💾 Logging & Replay

1. Press **Record (R)** to start saving data to a `.csv` file.
2. Press **Stop (R)** again to finish logging.
3. Use **Load (L)** to replay a previously saved dataset.

Replay mode visualizes the scan history using fading trails or heatmaps.

---

## 🧩 Arduino Test Snippet (Simulation Mode)

Use this sketch if you want to test the Processing app **without hardware**:

```cpp
// Arduino test data simulator
void setup() {
  Serial.begin(115200);
}

void loop() {
  static int angle = 0;
  static int dir = 1;
  float distance = 50 + 30 * sin(radians(angle)); // pseudo-distance pattern
  unsigned long ts = millis();
  
  Serial.print(angle);
  Serial.print(",");
  Serial.print(distance, 1);
  Serial.print(",");
  Serial.println(ts);

  angle += dir;
  if (angle >= 180 || angle <= 0) dir *= -1;
  delay(30);
}
```

---

## 🧱 Project Folder Structure

```
📂 ultrasonic-visualizer/
├── 📄 README.md
├── 📄 Context.md
├── 📄 Prompt.md               # (optional) detailed LLM prompt
├── 📄 Visualizer.pde          # main Processing file
├── 📂 /data                   # optional CSVs, color maps
└── 📂 /arduino_test           # contains Arduino simulation sketch
```

---

## 🚀 Running the Project

### Step 1 — Arduino

1. Open the provided Arduino sketch.
2. Upload it to the Uno.
3. Confirm data output in Serial Monitor (115200 baud).

### Step 2 — Processing

1. Open `Visualizer.pde` in Processing 4.x.
2. Install required library (`Sketch → Import Library → Add Library → ControlP5`).
3. Run the sketch (`▶ Run`).
4. Select the correct serial port.
5. Watch live data appear!

---

## 🧩 Tips & Notes

* Use **EMA smoothing** (α = 0.2–0.5) for stable visuals.
* Keep your Processing canvas size proportional to max range (e.g., 800×600 for ≤200 cm).
* Make sure servo wiring doesn’t draw too much current from the Arduino — consider an external 5V supply if necessary.

---

## 🧠 License

This project is open for educational and research purposes.
Feel free to modify or redistribute with proper attribution.

---

## 💬 Authors / Contributors

**Project Owner:** Nitin Swarnkar 
**Date:** 2025-11-01

---

