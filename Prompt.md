---

# ⚙️ Prompt.md — Multi-Mode Real-Time Visualizer for Single-Axis Ultrasonic Scanner

## 🎯 **Objective**

You are an **expert Processing and Arduino developer**.
Your task is to **generate or modify** a *fully functional, well-commented* **Processing 4.x sketch** that visualizes real-time angle–distance data from a single-axis ultrasonic scanner (Arduino + HC-SR04 + SG90).

The output must include:

1. Modular, runnable Processing code (`.pde`)
2. A minimal Arduino test data generator
3. Inline documentation and explanations
4. Optional performance and GUI improvements when applicable

---

## 📖 **Project Context**

Refer to the `Context.md` for background details.
Summary of the setup:

* **Hardware:** Arduino Uno + HC-SR04 ultrasonic sensor + SG90 servo
* **Function:** Servo sweeps from 0°–180°; sensor measures distance; Arduino sends serial CSV data to Processing.
* **Data Format:**

  ```
  angle,distance,timestamp\n
  ```

  Example: `45,123,1678912345\n`

Processing receives this data, visualizes it in multiple modes, logs CSVs, and allows replay.

---

## 🧩 **Required Features in the Processing Sketch**

### 1. Serial Handling

* Connect/disconnect UI
* Port selection dropdown (default `115200` baud)
* Robust parsing of CSV data
* Handle out-of-range readings (`999`, `nan`)

### 2. Visualization Modes (switchable)

| Mode | Type                   | Description              |
| ---- | ---------------------- | ------------------------ |
| `1`  | **Radar / Polar**      | Sweeping arm visual      |
| `2`  | **Cartesian 2D**       | X = d·cosθ, Y = d·sinθ   |
| `3`  | **Angle vs Distance**  | Line graph               |
| `4`  | **Replay / Heatmap**   | Time-based visualization |
| `5`  | **3D Fan Sweep (P3D)** | Extruded radial display  |

Use number keys (`1–5`) or GUI tabs (ControlP5 or G4P).

### 3. Logging & Replay

* Save `angle,distance,timestamp` to CSV
* Load CSV for replay
* Timestamp-based playback with optional time scaling

### 4. Smoothing & Filters

* Implement exponential moving average (EMA)
* Optional median filter by angle window
* Configurable alpha and window size

### 5. Color Mapping

* Map distance → hue or brightness
* Include a visible color scale legend

### 6. GUI Controls

* Pause / Resume stream
* Clear buffer
* Adjust smoothing & range
* Toggle grid, labels, or color map

### 7. Performance

* Maintain ≥30 FPS on typical serial rates
* Use efficient drawing (e.g., PGraphics for persistent layers)

### 8. Documentation

* Inline comments explaining each module
* Short README summary embedded as comments

---

## 💾 **Deliverables**

1. `Visualizer.pde` — fully functional Processing sketch
2. `arduino_test/ultrasonic_simulator.ino` — minimal Arduino simulation
3. Explanatory comments throughout code
4. Optional bonus features (auto-port detect, PNG export, 3D orbit control)

---

## 🧱 **Code Architecture (Recommended)**

Use modular class-like structure for clarity:

```text
Visualizer.pde
 ├─ SerialHandler     // manages serial input, parsing
 ├─ VisualModes       // contains draw() functions for each mode
 ├─ FilterManager     // EMA, median filter
 ├─ ReplayManager     // CSV load/playback
 ├─ UIController      // ControlP5 setup, buttons, sliders
 └─ Main setup/draw   // coordinates all modules
```

---

## 🧮 **Implementation Notes**

* Polar → Cartesian:

  ```java
  float x = distance * cos(radians(angle));
  float y = distance * sin(radians(angle));
  ```
* Center visualization at canvas middle.
* Use `millis()` for timestamps if missing from Arduino.
* Keep GUI elements non-blocking to drawing performance.
* When generating multiple `.pde` tabs, output each file clearly delimited.

---

## 🧩 **Arduino Test Snippet Requirements**

Include a minimal test sketch that:

* Sweeps the servo angle between 0–180° (or simulates this numerically)
* Sends random or sinusoidal distance values
* Prints CSV lines at 115200 baud

---

## 🧠 **LLM Behavior Instructions**

When you (the model) respond to this prompt:

1. Output clean, runnable code (no placeholders or pseudo-code).
2. Structure output into logical `.pde` files.
3. Include comments explaining each section.
4. Add a short summary at the end on how to run the sketch.
5. If the user asks for *modifications*, read this prompt as the fixed context and apply requested changes without rewriting unrelated parts.

---

## 🧩 **Example Follow-Up Requests You Should Support**

* “Add a GUI slider to control EMA alpha.”
* “Include moving object detection between sweeps.”
* “Add PNG snapshot export for the current view.”
* “Integrate 3D orbit control for the P3D mode.”

---

## 📦 **Expected Output Example**

When executed, your Processing sketch should:

* Connect to serial, show live sweep visualization
* Log data and replay from saved CSVs
* Allow mode switching and filter adjustments
* Run smoothly (~30 FPS) with typical Arduino serial stream

---

## 📜 **License**

Open for educational and research use.
Include attribution to original author(s) when redistributing code.

---

## 🧩 **Prompt Summary**

This `Prompt.md` defines *what* the AI must generate and *how* to structure its response for reliable, modular code generation.
It complements the `Context.md` (project intent) and `README.md` (setup guide).

---
