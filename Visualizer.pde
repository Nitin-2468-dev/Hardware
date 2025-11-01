/*
=======================================================
  Multi-Mode Real-Time Visualizer for Single-Axis 
  Ultrasonic Scanner
  
  Author: MiniMax Agent
  Date: 2025-11-01
  Processing: 4.x
  Purpose: Real-time visualization of HC-SR04 + SG90 
  ultrasonic scanner data with multiple display modes
=======================================================
*/

import controlP5.*;
import processing.serial.*;

// Global objects - modules
SerialHandler serialHandler;
VisualizerModes visualizer;
FilterManager filterManager;
ReplayManager replayManager;
UIController uiController;

// Global variables
int currentMode = 1;
boolean isConnected = false;
boolean isRecording = false;
boolean isPaused = false;
boolean replayMode = false;

// Data buffers
ArrayList<ScanData> scanBuffer;
ArrayList<ScanData> recordedData;

// GUI elements
ControlP5 cp5;

// Configuration
final int SERIAL_BAUD = 115200;
final int CANVAS_WIDTH = 1000;
final int CANVAS_HEIGHT = 700;
final color BG_COLOR = color(20, 25, 35);
final color GRID_COLOR = color(40, 50, 70);
final color TEXT_COLOR = color(200, 220, 240);

// Data structure for scan readings
class ScanData {
  float angle;
  float distance;
  long timestamp;
  float smoothDistance;
  
  ScanData(float angle, float distance, long timestamp) {
    this.angle = angle;
    this.distance = distance;
    this.timestamp = timestamp;
    this.smoothDistance = distance;
  }
  
  void setSmoothDistance(float smooth) {
    this.smoothDistance = smooth;
  }
  
  boolean isValid() {
    return distance > 0 && distance < 999 && !Float.isNaN(distance);
  }
}

// Setup and initialization
void setup() {
  size(CANVAS_WIDTH, CANVAS_HEIGHT);
  
  // Initialize data structures
  scanBuffer = new ArrayList<ScanData>();
  recordedData = new ArrayList<ScanData>();
  
  // Initialize modules
  serialHandler = new SerialHandler();
  visualizer = new VisualizerModes();
  filterManager = new FilterManager();
  replayManager = new ReplayManager();
  uiController = new UIController();
  
  // Initialize ControlP5
  cp5 = new ControlP5(this);
  uiController.setupGUI(cp5);
  
  // Setup visualizer
  visualizer.setup();
  
  // Set frame rate for smooth animation
  frameRate(30);
  
  println("Multi-Mode Ultrasonic Visualizer initialized");
  println("Ready for connection. Press 'C' to connect or use GUI.");
}

// Main draw loop
void draw() {
  background(BG_COLOR);
  
  // Handle serial data if connected
  if (isConnected && !isPaused && !replayMode) {
    serialHandler.update();
    
    // Apply smoothing to new data
    if (serialHandler.hasNewData()) {
      ScanData newData = serialHandler.getLatestData();
      if (newData != null && newData.isValid()) {
        float smoothDistance = filterManager.applyEMA(newData.distance, newData.angle);
        newData.setSmoothDistance(smoothDistance);
        scanBuffer.add(newData);
        
        // Record data if recording
        if (isRecording) {
          recordedData.add(newData);
        }
      }
    }
  }
  
  // Handle replay mode
  if (replayMode) {
    replayManager.update();
    if (replayManager.hasData()) {
      ScanData replayData = replayManager.getNextData();
      if (replayData != null) {
        float smoothDistance = filterManager.applyEMA(replayData.distance, replayData.angle);
        replayData.setSmoothDistance(smoothDistance);
        scanBuffer.add(replayData);
      }
    }
  }
  
  // Maintain buffer size for performance
  if (scanBuffer.size() > 1000) {
    // Keep only recent data for performance
    for (int i = 0; i < 200; i++) {
      if (scanBuffer.size() > 800) scanBuffer.remove(0);
    }
  }
  
  // Update and draw current visualization mode
  visualizer.draw(scanBuffer, currentMode);
  
  // Draw UI overlay
  uiController.drawOverlay(isConnected, isRecording, isPaused, replayMode, currentMode);
  
  // Apply effects like fading trails
  visualizer.applyEffects();
}

// Handle ControlP5 events
void controlEvent(ControlEvent theEvent) {
  uiController.handleEvent(theEvent);
}

// Handle keyboard shortcuts
void keyPressed() {
  switch(key) {
    case '1': case '2': case '3': case '4': case '5':
      currentMode = key - '0';
      break;
    case 'c': case 'C':
      toggleConnection();
      break;
    case 'p': case 'P':
      isPaused = !isPaused;
      break;
    case 'r': case 'R':
      toggleRecording();
      break;
    case 'l': case 'L':
      loadCSV();
      break;
    case ' ':
      clearBuffer();
      break;
    case 's': case 'S':
      savePNG();
      break;
  }
}

// Toggle serial connection
void toggleConnection() {
  if (!isConnected) {
    if (serialHandler.connect()) {
      isConnected = true;
      println("Connected to serial port");
    }
  } else {
    serialHandler.disconnect();
    isConnected = false;
    println("Disconnected from serial port");
  }
}

// Toggle recording
void toggleRecording() {
  if (!isRecording) {
    isRecording = true;
    recordedData.clear();
    println("Started recording");
  } else {
    isRecording = false;
    replayManager.saveToCSV(recordedData);
    println("Stopped recording and saved to CSV");
  }
}

// Load CSV for replay
void loadCSV() {
  selectInput("Select CSV file for replay:", "csvSelected");
}

// Clear data buffer
void clearBuffer() {
  scanBuffer.clear();
  println("Buffer cleared");
}

// Save PNG screenshot
void savePNG() {
  String filename = "ultrasonic_scan_" + year() + "-" + nf(month(), 2) + "-" + 
                   nf(day(), 2) + "_" + nf(hour(), 2) + "-" + nf(minute(), 2) + 
                   "-" + nf(second(), 2) + ".png";
  save("data/" + filename);
  println("Saved PNG: " + filename);
}

// Handle file selection
void csvSelected(File selection) {
  if (selection != null && selection.exists()) {
    if (replayManager.loadFromCSV(selection.getAbsolutePath())) {
      replayMode = true;
      isConnected = false; // Disconnect during replay
      println("Loaded CSV for replay: " + selection.getName());
    }
  }
}