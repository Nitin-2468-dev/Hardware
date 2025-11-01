/*
=======================================================
  Multi-Mode Real-Time Visualizer for Single-Axis 
  Ultrasonic Scanner
  
  Author: MiniMax Agent
  Date: 2025-11-01
  Processing: 4.x
  Purpose: Real-time visualization of HC-SR04 + SG90 
  ultrasonic scanner data with multiple display modes
  
  ALL CODE COMPILED INTO ONE FILE
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

/*
=======================================================
  DATA STRUCTURES
=======================================================
*/

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

// Motion event data structure
class MotionEvent {
  float angle;
  float distance;
  float changeMagnitude;
  long timestamp;
  
  MotionEvent(float angle, float distance, float changeMagnitude, long timestamp) {
    this.angle = angle;
    this.distance = distance;
    this.changeMagnitude = changeMagnitude;
    this.timestamp = timestamp;
  }
  
  boolean isRecent(long currentTime) {
    return currentTime - timestamp < 3000; // 3 second recent window
  }
}

/*
=======================================================
  SERIAL HANDLER CLASS
=======================================================
*/

class SerialHandler {
  private Serial port;
  private String[] availablePorts;
  private String selectedPort;
  private int selectedBaudRate;
  private String inputBuffer;
  private ScanData latestData;
  private boolean newDataAvailable;
  
  // Simulation state variables for test data generation
  private float testAngle = 0;      // Current sweep angle (0-180 degrees)
  private int testDir = 1;          // Sweep direction: 1 for forward, -1 for backward
  
  // Constructor
  SerialHandler() {
    this.availablePorts = Serial.list();
    this.selectedPort = "";
    this.selectedBaudRate = 115200;
    this.inputBuffer = "";
    this.latestData = null;
    this.newDataAvailable = false;
  }
  
  // Get available serial ports
  String[] getAvailablePorts() {
    return Serial.list();
  }
  
  // Connect to selected port
  boolean connect() {
    try {
      // Find available port - prefer Arduino ports
      String[] ports = Serial.list();
      String targetPort = "";
      
      // First, try to find Arduino-specific ports
      for (String p : ports) {
        if (p.contains("ttyUSB") || p.contains("ttyACM") || 
            p.contains("COM3") || p.contains("COM4") || 
            p.contains("usbserial") || p.contains("usbmodem")) {
          targetPort = p;
          break;
        }
      }
      
      // If no Arduino port found, use first available non-system port
      if (targetPort.isEmpty() && ports.length > 0) {
        targetPort = ports[0]; // Use first available port as fallback
      }
      
      if (!targetPort.isEmpty()) {
        port = new Serial(this, targetPort, selectedBaudRate);
        port.bufferUntil('\n');
        selectedPort = targetPort;
        println("Connected to port: " + targetPort);
        return true;
      } else {
        println("No serial ports available");
      }
      
    } catch (Exception e) {
      println("Connection failed: " + e.getMessage());
    }
    return false;
  }
  
  // Connect to specific port
  boolean connect(String portName) {
    try {
      port = new Serial(this, portName, selectedBaudRate);
      port.bufferUntil('\n');
      selectedPort = portName;
      return true;
    } catch (Exception e) {
      println("Connection to " + portName + " failed: " + e.getMessage());
      return false;
    }
  }
  
  // Disconnect
  void disconnect() {
    if (port != null) {
      port.stop();
      port = null;
      selectedPort = "";
    }
  }
  
  // Update serial data
  void update() {
    if (port == null) return;
    
    try {
      while (port.available() > 0) {
        String line = port.readString();
        if (line != null && !line.isEmpty()) {
          processSerialData(line.trim());
        }
      }
    } catch (Exception e) {
      println("Error reading serial data: " + e.getMessage());
    }
  }
  
  // Process incoming serial data
  private void processSerialData(String data) {
    // Expected format: angle,distance,timestamp
    String[] parts = data.split(",");
    
    if (parts.length >= 2) {
      try {
        float angle = Float.parseFloat(parts[0]);
        float distance = Float.parseFloat(parts[1]);
        long timestamp = millis(); // Use Processing millis() as fallback
        
        if (parts.length >= 3) {
          timestamp = Long.parseLong(parts[2]);
        }
        
        // Validate data ranges
        if (angle >= 0 && angle <= 180 && distance > 0 && distance < 999) {
          latestData = new ScanData(angle, distance, timestamp);
          newDataAvailable = true;
        }
        
      } catch (NumberFormatException e) {
        // Skip invalid data
      }
    }
  }
  
  // Check if new data is available
  boolean hasNewData() {
    return newDataAvailable;
  }
  
  // Get latest data and consume it
  ScanData getLatestData() {
    if (newDataAvailable) {
      newDataAvailable = false;
      return latestData;
    }
    return null;
  }
  
  // Get latest data without consuming
  ScanData peekLatestData() {
    return latestData;
  }
  
  // Get connection status
  boolean isConnected() {
    return port != null;
  }
  
  // Get selected port name
  String getSelectedPort() {
    return selectedPort;
  }
  
  // Send command to Arduino (optional)
  void sendCommand(String command) {
    if (port != null && isConnected()) {
      port.write(command + '\n');
    }
  }
  
  // Set baud rate
  void setBaudRate(int baudRate) {
    this.selectedBaudRate = baudRate;
    // Note: Changes take effect on next connect
  }
  
  // Get current baud rate
  int getBaudRate() {
    return selectedBaudRate;
  }
  
  // Debug: Test with simulated data
  void simulateData() {
    // Simulate realistic distance data with some noise
    float distance = 80 + 40 * sin(radians(testAngle * 2)) + random(-10, 10);
    distance = max(20, min(distance, 300)); // Clamp to realistic range
    
    long timestamp = millis();
    
    latestData = new ScanData(testAngle, distance, timestamp);
    newDataAvailable = true;
    
    testAngle += testDir * 2;
    if (testAngle >= 180 || testAngle <= 0) testDir *= -1;
  }
}

/*
=======================================================
  FILTER MANAGER CLASS
=======================================================
*/

class FilterManager {
  private float emaAlpha;
  private int medianWindowSize;
  private HashMap<Integer, ArrayList<Float>> angleBuckets;
  private HashMap<Integer, Float> emaValues;
  
  // Outlier detection parameters
  private float outlierThreshold;
  private float minDistance;
  private float maxDistance;
  
  // Constructor
  FilterManager() {
    emaAlpha = 0.3f; // Default EMA smoothing factor
    medianWindowSize = 5; // Default median window
    outlierThreshold = 2.0f; // Standard deviations for outlier detection
    minDistance = 10.0f; // Minimum valid distance in cm
    maxDistance = 400.0f; // Maximum valid distance in cm
    
    angleBuckets = new HashMap<Integer, ArrayList<Float>>();
    emaValues = new HashMap<Integer, Float>();
    
    // Initialize angle buckets
    for (int i = 0; i <= 180; i++) {
      angleBuckets.put(i, new ArrayList<Float>());
      emaValues.put(i, 0.0f);
    }
  }
  
  // Apply Exponential Moving Average filter
  float applyEMA(float newValue, float angle) {
    int angleIndex = Math.round(angle);
    
    // Clamp angle to valid range to prevent HashMap growth
    angleIndex = constrain(angleIndex, 0, 180);
    
    if (!emaValues.containsKey(angleIndex)) {
      emaValues.put(angleIndex, newValue);
      return newValue;
    }
    
    float previousEma = emaValues.get(angleIndex);
    float newEma = emaAlpha * newValue + (1 - emaAlpha) * previousEma;
    
    emaValues.put(angleIndex, newEma);
    return newEma;
  }
  
  // Apply Median filter with window
  float applyMedianFilter(float newValue, float angle) {
    int angleIndex = Math.round(angle);
    
    // Clamp angle to valid range to prevent HashMap growth
    angleIndex = constrain(angleIndex, 0, 180);
    
    ArrayList<Float> bucket = angleBuckets.get(angleIndex);
    
    if (bucket == null) {
      bucket = new ArrayList<Float>();
      angleBuckets.put(angleIndex, bucket);
    }
    
    // Add new value to bucket
    bucket.add(newValue);
    
    // Maintain window size
    while (bucket.size() > medianWindowSize) {
      bucket.remove(0);
    }
    
    // Return median if we have enough data
    if (bucket.size() >= 3) {
      return calculateMedian(bucket);
    }
    
    return newValue; // Return original if not enough data
  }
  
  // Combined filter: Median + EMA
  float applyCombinedFilter(float newValue, float angle) {
    // First apply median filter
    float medianValue = applyMedianFilter(newValue, angle);
    
    // Then apply EMA to median-filtered value
    float emaValue = applyEMA(medianValue, angle);
    
    return emaValue;
  }
  
  // Apply outlier detection
  boolean isOutlier(float value, float angle) {
    if (value < minDistance || value > maxDistance) {
      return true; // Out of valid range
    }
    
    int angleIndex = Math.round(angle);
    ArrayList<Float> bucket = angleBuckets.get(angleIndex);
    
    if (bucket == null || bucket.size() < 5) {
      return false; // Not enough data to detect outliers
    }
    
    // Calculate mean and standard deviation
    float sum = 0;
    for (Float val : bucket) {
      sum += val;
    }
    float mean = sum / bucket.size();
    
    float variance = 0;
    for (Float val : bucket) {
      variance += pow(val - mean, 2);
    }
    float stdDev = sqrt(variance / bucket.size());
    
    // Check if current value is an outlier
    return abs(value - mean) > outlierThreshold * stdDev;
  }
  
  // Smooth noisy data
  float smoothData(float value, float angle) {
    // First check for outliers
    if (isOutlier(value, angle)) {
      // Use previous filtered value if current is an outlier
      int angleIndex = Math.round(angle);
      if (emaValues.containsKey(angleIndex)) {
        return emaValues.get(angleIndex);
      }
    }
    
    // Apply combined filtering
    return applyCombinedFilter(value, angle);
  }
  
  // Calculate median from ArrayList
  private float calculateMedian(ArrayList<Float> values) {
    ArrayList<Float> sorted = new ArrayList<Float>(values);
    Collections.sort(sorted);
    
    int size = sorted.size();
    if (size % 2 == 0) {
      return (sorted.get(size / 2 - 1) + sorted.get(size / 2)) / 2.0f;
    } else {
      return sorted.get(size / 2);
    }
  }
  
  // Reset filters (clear history)
  void reset() {
    for (int i = 0; i <= 180; i++) {
      angleBuckets.get(i).clear();
      emaValues.put(i, 0.0f);
    }
  }
  
  // Get current EMA smoothing factor
  float getEmaAlpha() {
    return emaAlpha;
  }
  
  // Set EMA smoothing factor
  void setEmaAlpha(float alpha) {
    this.emaAlpha = constrain(alpha, 0.0f, 1.0f);
  }
  
  // Get median window size
  int getMedianWindowSize() {
    return medianWindowSize;
  }
  
  // Set median window size
  void setMedianWindowSize(int windowSize) {
    this.medianWindowSize = constrain(windowSize, 3, 15);
  }
  
  // Get outlier threshold
  float getOutlierThreshold() {
    return outlierThreshold;
  }
  
  // Set outlier threshold
  void setOutlierThreshold(float threshold) {
    this.outlierThreshold = constrain(threshold, 1.0f, 5.0f);
  }
  
  // Get filter statistics for debugging
  String getFilterStats(float angle) {
    int angleIndex = Math.round(angle);
    ArrayList<Float> bucket = angleBuckets.get(angleIndex);
    
    if (bucket == null) {
      return "No data for angle " + angleIndex;
    }
    
    float currentEma = emaValues.get(angleIndex);
    float medianValue = bucket.isEmpty() ? 0 : calculateMedian(bucket);
    
    return String.format("Angle %d: EMA=%.1f, Median=%.1f, Samples=%d", 
                        angleIndex, currentEma, medianValue, bucket.size());
  }
  
  // Apply Kalman-like filtering (advanced smoothing)
  float applyKalmanFilter(float measurement, float angle) {
    // Simple Kalman filter implementation for ultrasonic data
    int angleIndex = Math.round(angle);
    
    // Prediction step
    float predictedValue = emaValues.get(angleIndex);
    
    // Kalman gain (simplified)
    float kalmanGain = 0.3f;
    
    // Update step
    float filteredValue = predictedValue + kalmanGain * (measurement - predictedValue);
    
    emaValues.put(angleIndex, filteredValue);
    
    return filteredValue;
  }
  
  // Apply moving average filter
  float applyMovingAverage(float newValue, float angle, int windowSize) {
    int angleIndex = Math.round(angle);
    ArrayList<Float> bucket = angleBuckets.get(angleIndex);
    
    if (bucket == null) {
      bucket = new ArrayList<Float>();
      angleBuckets.put(angleIndex, bucket);
    }
    
    bucket.add(newValue);
    
    // Maintain window size
    while (bucket.size() > windowSize) {
      bucket.remove(0);
    }
    
    // Calculate average
    float sum = 0;
    for (Float val : bucket) {
      sum += val;
    }
    
    return bucket.isEmpty() ? newValue : sum / bucket.size();
  }
}

/*
=======================================================
  REPLAY MANAGER CLASS
=======================================================
*/

class ReplayManager {
  private ArrayList<ScanData> replayData;
  private int currentIndex;
  private boolean isPlaying;
  private float replaySpeed;
  private long startTime;
  private long lastReplayTime;
  private String currentFilePath;
  
  // Replay timing control
  private static final long REPLAY_INTERVAL = 30; // milliseconds between samples
  
  // Constructor
  ReplayManager() {
    replayData = new ArrayList<ScanData>();
    currentIndex = 0;
    isPlaying = false;
    replaySpeed = 1.0f;
    startTime = 0;
    lastReplayTime = 0;
    currentFilePath = "";
  }
  
  // Load data from CSV file
  boolean loadFromCSV(String filePath) {
    try {
      replayData.clear();
      currentIndex = 0;
      
      BufferedReader reader = createReader(filePath);
      if (reader == null) {
        return false;
      }
      
      String line;
      int lineCount = 0;
      
      while ((line = reader.readLine()) != null) {
        line = line.trim();
        
        // Skip empty lines and comments
        if (line.isEmpty() || line.startsWith("#")) {
          continue;
        }
        
        // Parse CSV data: angle,distance,timestamp
        String[] parts = line.split(",");
        
        if (parts.length >= 2) {
          try {
            float angle = Float.parseFloat(parts[0].trim());
            float distance = Float.parseFloat(parts[1].trim());
            long timestamp = millis(); // Use current time as fallback
            
            if (parts.length >= 3) {
              timestamp = Long.parseLong(parts[2].trim());
            }
            
            // Validate data
            if (angle >= 0 && angle <= 180 && distance > 0 && distance < 999) {
              ScanData data = new ScanData(angle, distance, timestamp);
              replayData.add(data);
              lineCount++;
            }
            
          } catch (NumberFormatException e) {
            // Skip invalid lines
            continue;
          }
        }
      }
      
      reader.close();
      currentFilePath = filePath;
      
      println("Loaded " + lineCount + " data points from " + filePath);
      return lineCount > 0;
      
    } catch (Exception e) {
      println("Error loading CSV: " + e.getMessage());
      return false;
    }
  }
  
  // Save data to CSV file
  boolean saveToCSV(ArrayList<ScanData> data) {
    if (data.isEmpty()) {
      return false;
    }
    
    try {
      // Generate filename with timestamp
      String timestamp = nf(year(), 4) + "-" + nf(month(), 2) + "-" + nf(day(), 2) + 
                        "_" + nf(hour(), 2) + "-" + nf(minute(), 2) + "-" + nf(second(), 2);
      String filename = "ultrasonic_scan_" + timestamp + ".csv";
      
      // Create data directory if it doesn't exist
      File dataDir = new File("data");
      if (!dataDir.exists()) {
        dataDir.mkdir();
      }
      
      String fullPath = dataDir.getAbsolutePath() + "/" + filename;
      
      PrintWriter writer = createWriter(fullPath);
      
      // Write header
      writer.println("# Ultrasonic Scanner Data Log");
      writer.println("# Format: angle,distance,timestamp");
      writer.println("# Angle: 0-180 degrees");
      writer.println("# Distance: centimeters");
      writer.println("# Timestamp: milliseconds since start");
      writer.println();
      
      // Write data
      for (ScanData dataPoint : data) {
        if (dataPoint.isValid()) {
          writer.printf("%.1f,%.1f,%d%n", 
                       dataPoint.angle, 
                       dataPoint.smoothDistance, 
                       dataPoint.timestamp);
        }
      }
      
      writer.flush();
      writer.close();
      
      println("Saved " + data.size() + " data points to " + filename);
      return true;
      
    } catch (Exception e) {
      println("Error saving CSV: " + e.getMessage());
      return false;
    }
  }
  
  // Start replay
  void startReplay() {
    if (!replayData.isEmpty()) {
      isPlaying = true;
      currentIndex = 0;
      startTime = millis();
      lastReplayTime = millis();
    }
  }
  
  // Stop replay
  void stopReplay() {
    isPlaying = false;
    currentIndex = 0;
  }
  
  // Update replay (call this from main draw loop)
  void update() {
    if (!isPlaying || replayData.isEmpty()) {
      return;
    }
    
    long currentTime = millis();
    
    // Check if it's time for the next sample
    if (currentTime - lastReplayTime >= REPLAY_INTERVAL / replaySpeed) {
      lastReplayTime = currentTime;
      currentIndex++;
      
      // Stop if we've reached the end
      if (currentIndex >= replayData.size()) {
        stopReplay();
      }
    }
  }
  
  // Get next data point for replay
  ScanData getNextData() {
    if (!isPlaying || replayData.isEmpty() || currentIndex >= replayData.size()) {
      return null;
    }
    
    return replayData.get(currentIndex);
  }
  
  // Check if replay has data available
  boolean hasData() {
    return isPlaying && currentIndex < replayData.size();
  }
  
  // Get current replay progress (0.0 to 1.0)
  float getProgress() {
    if (replayData.isEmpty()) {
      return 0.0f;
    }
    return (float)currentIndex / (float)replayData.size();
  }
  
  // Set replay speed (1.0 = normal speed, 2.0 = 2x speed, 0.5 = half speed)
  void setReplaySpeed(float speed) {
    this.replaySpeed = constrain(speed, 0.1f, 10.0f);
  }
  
  // Get current replay speed
  float getReplaySpeed() {
    return replaySpeed;
  }
  
  // Jump to specific position in replay (0.0 to 1.0)
  void setReplayPosition(float position) {
    if (!replayData.isEmpty()) {
      position = constrain(position, 0.0f, 1.0f);
      currentIndex = (int)(position * replayData.size());
    }
  }
  
  // Get replay statistics
  String getReplayStats() {
    if (replayData.isEmpty()) {
      return "No data loaded";
    }
    
    return String.format("Data: %d points | Progress: %d%% | Speed: %.1fx", 
                        replayData.size(), 
                        (int)(getProgress() * 100), 
                        replaySpeed);
  }
  
  // Get angle range of loaded data
  String getDataRange() {
    if (replayData.isEmpty()) {
      return "No data";
    }
    
    float minAngle = 999, maxAngle = -999;
    float minDistance = 999, maxDistance = -999;
    
    for (ScanData data : replayData) {
      if (data.angle < minAngle) minAngle = data.angle;
      if (data.angle > maxAngle) maxAngle = data.angle;
      if (data.smoothDistance < minDistance) minDistance = data.smoothDistance;
      if (data.smoothDistance > maxDistance) maxDistance = data.smoothDistance;
    }
    
    return String.format("Angles: %.1f° - %.1f° | Distances: %.1f - %.1f cm", 
                        minAngle, maxAngle, minDistance, maxDistance);
  }
  
  // Export filtered data to CSV (with additional processing)
  boolean exportFilteredData(ArrayList<ScanData> sourceData, String filename) {
    try {
      PrintWriter writer = createWriter(filename);
      
      // Write enhanced header
      writer.println("# Filtered Ultrasonic Scanner Data");
      writer.println("# Original data processed with smoothing");
      writer.println("# Format: angle,original_distance,filtered_distance,timestamp");
      writer.println();
      
      // Write processed data
      for (ScanData data : sourceData) {
        if (data.isValid()) {
          writer.printf("%.1f,%.1f,%.1f,%d%n", 
                       data.angle, 
                       data.distance, 
                       data.smoothDistance, 
                       data.timestamp);
        }
      }
      
      writer.flush();
      writer.close();
      
      println("Exported filtered data to " + filename);
      return true;
      
    } catch (Exception e) {
      println("Error exporting filtered data: " + e.getMessage());
      return false;
    }
  }
  
  // Clear loaded data
  void clear() {
    replayData.clear();
    currentIndex = 0;
    isPlaying = false;
    currentFilePath = "";
  }
  
  // Check if currently playing
  boolean isCurrentlyPlaying() {
    return isPlaying;
  }
  
  // Get size of loaded dataset
  int getDataSize() {
    return replayData.size();
  }
  
  // Get current file path
  String getCurrentFilePath() {
    return currentFilePath;
  }
}


/*
=======================================================
  VISUALIZER MODES CLASS
=======================================================
*/

class VisualizerModes {
  private PGraphics radarLayer, cartesianLayer, graphLayer, replayLayer, layer3D;
  private PGraphics effectsLayer;
  private int centerX, centerY, centerZ;
  private float maxRange;
  
  // Heatmap resolution constants
  private static final int ANGLE_STEP = 2;  // Degrees per heatmap cell
  private static final int DISTANCE_STEP = 3; // Centimeters per heatmap cell
  
  // Colors for different distance ranges
  private color nearColor, mediumColor, farColor;
  
  // 3D rotation variables for orbit control
  private float rotationX = 0;
  private float rotationY = 0;
  private boolean orbitEnabled = false;
  
  // Setup visualization layers
  void setup() {
    centerX = width / 2;
    centerY = height / 2 + 50; // Offset down for UI space
    centerZ = 0; // Initialize centerZ for 3D visualization
    maxRange = 200; // Maximum distance range in cm
    
    // Initialize graphics layers for double buffering
    radarLayer = createGraphics(width, height);
    cartesianLayer = createGraphics(width, height);
    graphLayer = createGraphics(width, height);
    replayLayer = createGraphics(width, height);
    layer3D = createGraphics(width, height, P3D);
    effectsLayer = createGraphics(width, height);
    
    // Set up color scheme
    setupColorScheme();
    
    // Initialize 3D layer
    layer3D.beginDraw();
    layer3D.background(20, 25, 35);
    layer3D.endDraw();
  }
  
  // Setup color mapping scheme
  private void setupColorScheme() {
    nearColor = color(255, 100, 100);    // Red for near objects
    mediumColor = color(255, 200, 100);  // Orange for medium distance
    farColor = color(100, 200, 255);     // Blue for far objects
  }
  
  // Main draw function - routes to appropriate mode
  void draw(ArrayList<ScanData> data, int mode) {
    switch(mode) {
      case 1:
        drawRadarView(data);
        break;
      case 2:
        drawCartesianView(data);
        break;
      case 3:
        drawGraphView(data);
        break;
      case 4:
        drawReplayView(data);
        break;
      case 5:
        draw3DView(data);
        break;
    }
  }
  
  // Mode 1: Radar/Polar View
  void drawRadarView(ArrayList<ScanData> data) {
    radarLayer.beginDraw();
    radarLayer.background(20, 25, 35);
    
    // Draw radar grid
    drawRadarGrid(radarLayer);
    
    // Draw data points
    for (ScanData point : data) {
      if (point.isValid()) {
        // Cache trigonometric calculations for performance
        float angleRad = radians(point.angle - 90);
        float scaledDistance = point.smoothDistance * 2;
        float screenX = centerX + scaledDistance * cos(angleRad);
        float screenY = centerY + scaledDistance * sin(angleRad);
        
        color pointColor = getDistanceColor(point.smoothDistance);
        radarLayer.fill(pointColor);
        radarLayer.noStroke();
        radarLayer.ellipse(screenX, screenY, 8, 8);
        
        // Draw radial lines for sweep effect
        if (point.angle % 10 < 2) { // Occasional sweep lines
          radarLayer.stroke(pointColor, 100);
          radarLayer.strokeWeight(1);
          radarLayer.line(centerX, centerY, screenX, screenY);
        }
      }
    }
    
    // Draw angle indicators
    drawAngleIndicators(radarLayer);
    
    radarLayer.endDraw();
    image(radarLayer, 0, 0);
    
    // Draw mode title
    fill(200, 220, 240);
    textSize(20);
    textAlign(LEFT, TOP);
    text("Mode 1: Radar/Polar View", 20, 20);
  }
  
  // Mode 2: Cartesian 2D View
  void drawCartesianView(ArrayList<ScanData> data) {
    cartesianLayer.beginDraw();
    cartesianLayer.background(20, 25, 35);
    
    // Draw Cartesian grid
    drawCartesianGrid(cartesianLayer);
    
    // Convert polar to Cartesian and draw
    for (ScanData point : data) {
      if (point.isValid()) {
        float x = point.smoothDistance * cos(radians(point.angle));
        float y = point.smoothDistance * sin(radians(point.angle));
        
        // Scale to screen coordinates
        float screenX = centerX + x * 2;
        float screenY = centerY - y * 2; // Invert Y for standard math orientation
        
        color pointColor = getDistanceColor(point.smoothDistance);
        cartesianLayer.fill(pointColor);
        cartesianLayer.noStroke();
        cartesianLayer.ellipse(screenX, screenY, 6, 6);
        
        // Draw connecting lines for pattern visualization
        if (point.angle % 5 < 1) { // Sparse connections
          cartesianLayer.stroke(pointColor, 80);
          cartesianLayer.strokeWeight(1);
          cartesianLayer.line(centerX, centerY, screenX, screenY);
        }
      }
    }
    
    cartesianLayer.endDraw();
    image(cartesianLayer, 0, 0);
    
    // Draw mode title
    fill(200, 220, 240);
    textSize(20);
    textAlign(LEFT, TOP);
    text("Mode 2: Cartesian 2D View", 20, 20);
  }
  
  // Mode 3: Angle vs Distance Graph
  void drawGraphView(ArrayList<ScanData> data) {
    graphLayer.beginDraw();
    graphLayer.background(20, 25, 35);
    
    // Draw graph grid and axes
    drawGraphGrid(graphLayer);
    
    // Draw data as line graph
    if (data.size() > 1) {
      graphLayer.stroke(100, 200, 255);
      graphLayer.strokeWeight(2);
      graphLayer.noFill();
      
      graphLayer.beginShape();
      for (ScanData point : data) {
        if (point.isValid()) {
          float x = map(point.angle, 0, 180, 100, width - 100);
          float y = map(point.smoothDistance, 0, maxRange, height - 100, 150);
          graphLayer.vertex(x, y);
        }
      }
      graphLayer.endShape();
    }
    
    // Draw individual points
    for (ScanData point : data) {
      if (point.isValid()) {
        float x = map(point.angle, 0, 180, 100, width - 100);
        float y = map(point.smoothDistance, 0, maxRange, height - 100, 150);
        
        color pointColor = getDistanceColor(point.smoothDistance);
        graphLayer.fill(pointColor);
        graphLayer.noStroke();
        graphLayer.ellipse(x, y, 4, 4);
      }
    }
    
    graphLayer.endDraw();
    image(graphLayer, 0, 0);
    
    // Draw mode title
    fill(200, 220, 240);
    textSize(20);
    textAlign(LEFT, TOP);
    text("Mode 3: Angle vs Distance Graph", 20, 20);
  }
  
  // Mode 4: Replay/Heatmap View
  void drawReplayView(ArrayList<ScanData> data) {
    replayLayer.beginDraw();
    replayLayer.background(20, 25, 35);
    
    // Draw heatmap-style visualization - optimized to avoid large array allocation
    if (data.size() > 0) {
      // Use HashMap for sparse data instead of large 2D array
      // Key encoding: (angle * 1000 + distance) for efficient integer-based lookup
      HashMap<Integer, Integer> intensity = new HashMap<Integer, Integer>();
      HashMap<Integer, int[]> keyCoords = new HashMap<Integer, int[]>();
      
      // Aggregate data for heatmap - only store actual data points
      for (ScanData point : data) {
        if (point.isValid()) {
          int angleIdx = constrain((int)(point.angle / ANGLE_STEP) * ANGLE_STEP, 0, 180);
          int distanceIdx = constrain((int)(point.smoothDistance / DISTANCE_STEP) * DISTANCE_STEP, 0, 300);
          int key = angleIdx * 1000 + distanceIdx; // Encode as single integer
          
          intensity.put(key, intensity.getOrDefault(key, 0) + 1);
          if (!keyCoords.containsKey(key)) {
            keyCoords.put(key, new int[]{angleIdx, distanceIdx});
          }
        }
      }
      
      // Draw heatmap - only render where we have data
      for (Integer key : intensity.keySet()) {
        int[] coords = keyCoords.get(key);
        int angle = coords[0];
        int dist = coords[1];
        int intensityValue = intensity.get(key);
        
        // Cache trigonometric calculation
        float angleRad = radians(angle - 90);
        float scaledDist = dist * 2;
        float screenX = centerX + cos(angleRad) * scaledDist;
        float screenY = centerY + sin(angleRad) * scaledDist;
        
        // Color based on intensity
        float heatValue = constrain(map(intensityValue, 1, 10, 0, 1), 0, 1);
        color heatColor = lerpColor(color(50, 100, 150), color(255, 200, 100), heatValue);
        replayLayer.fill(heatColor, map(intensityValue, 1, 10, 100, 220));
        replayLayer.noStroke();
        replayLayer.ellipse(screenX, screenY, 6, 6);
      }
    }
    
    replayLayer.endDraw();
    image(replayLayer, 0, 0);
    
    // Draw mode title
    fill(200, 220, 240);
    textSize(20);
    textAlign(LEFT, TOP);
    text("Mode 4: Replay/Heatmap View", 20, 20);
  }
  
  // Mode 5: 3D Fan Sweep View
  void draw3DView(ArrayList<ScanData> data) {
    // Switch to 3D mode
    pushMatrix();
    
    // Orbit control if enabled
    if (orbitEnabled) {
      translate(centerX, centerY, 0);
      rotateX(rotationX);
      rotateY(rotationY);
      translate(-centerX, -centerY, 0);
    }
    
    // Draw 3D grid
    draw3DGrid();
    
    // Set sphere detail once outside loop for performance
    sphereDetail(4);
    
    // Draw 3D data points
    for (ScanData point : data) {
      if (point.isValid()) {
        // Cache trigonometric calculations
        float angleRad = radians(point.angle);
        float scaledDistance = point.smoothDistance * 2;
        float x = scaledDistance * cos(angleRad);
        float z = scaledDistance * sin(angleRad);
        
        // Calculate screen coordinates
        float screenX = centerX + x;
        float screenZ = centerZ + z;
        float screenY = centerY;
        
        color pointColor = getDistanceColor(point.smoothDistance);
        
        // Draw point with depth effect
        pushMatrix();
        translate(screenX, screenY, screenZ);
        fill(pointColor);
        noStroke();
        sphere(8);
        popMatrix();
      }
    }
    
    popMatrix();
    
    // Draw mode title
    fill(200, 220, 240);
    textSize(20);
    textAlign(LEFT, TOP);
    text("Mode 5: 3D Fan Sweep View", 20, 20);
    
    if (orbitEnabled) {
      textAlign(RIGHT, TOP);
      text("Drag mouse to rotate", width - 20, 20);
    }
  }
  
  // Utility functions for grid drawing
  private void drawRadarGrid(PGraphics g) {
    g.stroke(60, 80, 120);
    g.strokeWeight(1);
    g.noFill();
    
    // Concentric circles
    for (int r = 50; r <= 400; r += 50) {
      g.ellipse(centerX, centerY, r * 2, r * 2);
      g.fill(150);
      g.textSize(10);
      g.textAlign(CENTER, CENTER);
      g.text((r/2) + "cm", centerX, centerY - r - 10);
    }
    
    // Radial lines
    for (int angle = 0; angle < 360; angle += 30) {
      float x = centerX + cos(radians(angle - 90)) * 400;
      float y = centerY + sin(radians(angle - 90)) * 400;
      g.line(centerX, centerY, x, y);
    }
  }
  
  private void drawCartesianGrid(PGraphics g) {
    g.stroke(60, 80, 120);
    g.strokeWeight(1);
    g.noFill();
    
    // Grid lines
    for (int x = centerX - 400; x <= centerX + 400; x += 50) {
      g.line(x, centerY - 300, x, centerY + 300);
    }
    for (int y = centerY - 300; y <= centerY + 300; y += 50) {
      g.line(centerX - 400, y, centerX + 400, y);
    }
    
    // Axis labels
    g.fill(150);
    g.textSize(12);
    g.textAlign(CENTER, CENTER);
    g.text("X", centerX + 420, centerY);
    g.text("Y", centerX, centerY - 320);
  }
  
  private void drawGraphGrid(PGraphics g) {
    g.stroke(60, 80, 120);
    g.strokeWeight(1);
    
    // Grid lines
    for (int x = 100; x <= width - 100; x += 50) {
      g.line(x, 150, x, height - 100);
    }
    for (int y = 150; y <= height - 100; y += 50) {
      g.line(100, y, width - 100, y);
    }
    
    // Axes
    g.stroke(100, 200, 255);
    g.strokeWeight(2);
    g.line(100, height - 100, width - 100, height - 100); // X axis
    g.line(100, 150, 100, height - 100); // Y axis
    
    // Labels
    g.fill(150);
    g.textSize(12);
    g.textAlign(CENTER, CENTER);
    g.text("Angle (degrees)", (width - 100 + 100) / 2, height - 80);
    g.textAlign(RIGHT, CENTER);
    g.text("Distance (cm)", 80, (height - 100 + 150) / 2);
  }
  
  private void draw3DGrid() {
    stroke(60, 80, 120);
    strokeWeight(1);
    noFill();
    
    // 3D grid - simplified version
    for (int i = -200; i <= 200; i += 50) {
      line(centerX + i, centerY - 100, centerZ, centerX + i, centerY + 100, centerZ);
      line(centerX - 100, centerY + i, centerZ, centerX + 100, centerY + i, centerZ);
    }
  }
  
  private void drawAngleIndicators(PGraphics g) {
    g.fill(150);
    g.textSize(12);
    g.textAlign(CENTER, CENTER);
    
    for (int angle = 0; angle < 360; angle += 30) {
      float x = centerX + cos(radians(angle - 90)) * 380;
      float y = centerY + sin(radians(angle - 90)) * 380;
      
      if (angle == 0) g.text("N", x, y);
      else if (angle == 90) g.text("E", x, y);
      else if (angle == 180) g.text("S", x, y);
      else if (angle == 270) g.text("W", x, y);
      else g.text((angle) + "°", x, y);
    }
  }
  
  // Color mapping based on distance
  private color getDistanceColor(float distance) {
    if (distance < 100) {
      return lerpColor(nearColor, mediumColor, distance / 100);
    } else {
      return lerpColor(mediumColor, farColor, (distance - 100) / 100);
    }
  }
  
  // Apply visual effects
  void applyEffects() {
    // Handle fade trails (implement fading for smooth visuals)
    if (frameCount % 2 == 0) { // Apply every other frame for performance
      // Add subtle fade effect to create motion trails
      fill(20, 25, 35, 30);
      noStroke();
      rect(0, 0, width, height);
    }
  }
  
  // Enable/disable 3D orbit control
  void setOrbitEnabled(boolean enabled) {
    orbitEnabled = enabled;
    // Note: P3D renderer is now enabled in main setup()
    if (enabled) {
      println("3D orbit control enabled");
    }
  }
  
  // Handle mouse drag for 3D orbit
  void handleMouseDrag(int dx, int dy) {
    if (orbitEnabled) {
      rotationY += dx * 0.01;
      rotationX += dy * 0.01;
    }
  }
}


/*
=======================================================
  UI CONTROLLER CLASS
=======================================================
*/

class UIController {
  private ControlP5 cp5;
  
  // GUI element references
  private DropdownList portDropdown;
  private Button connectButton;
  private Button recordButton;
  private Button loadButton;
  private Button clearButton;
  private Button saveButton;
  
  // Sliders
  private Slider emaAlphaSlider;
  private Slider medianWindowSlider;
  private Slider maxRangeSlider;
  private Slider replaySpeedSlider;
  
  // Checkboxes
  private Checkbox showGridCheckbox;
  private Checkbox showLabelsCheckbox;
  private Checkbox showColorMapCheckbox;
  private Checkbox enableSmoothingCheckbox;
  
  // Text labels
  private Textlabel statusLabel;
  private Textlabel fpsLabel;
  private Textlabel dataLabel;
  
  // Constants for UI layout
  private final int UI_X = 20;
  private final int UI_Y = 60;
  private final int UI_WIDTH = 250;
  private final int UI_HEIGHT = height - 100;
  private final int BUTTON_WIDTH = 100;
  private final int BUTTON_HEIGHT = 30;
  private final int SLIDER_WIDTH = 200;
  private final int LABEL_HEIGHT = 20;
  
  // State tracking
  private String lastStatusMessage = "";
  private int lastFrameCount = 0;
  private float lastFrameRate = 0;
  
  // Setup all GUI elements
  void setupGUI(ControlP5 cp5) {
    this.cp5 = cp5;
    
    // Set global properties
    cp5.setColorBackground(color(40, 50, 70));
    cp5.setColorForeground(color(60, 80, 100));
    cp5.setColorActive(color(80, 120, 160));
    cp5.setColorLabel(color(200, 220, 240));
    cp5.setColorValue(color(150, 180, 200));
    cp5.setColorCursor(color(255, 200, 100));
    
    setupSerialControls();
    setupDataControls();
    setupFilterControls();
    setupReplayControls();
    setupDisplayControls();
    setupStatusLabels();
  }
  
  // Serial communication controls
  private void setupSerialControls() {
    // Port selection dropdown
    portDropdown = cp5.addDropdownList("portSelect")
      .setPosition(UI_X, UI_Y)
      .setSize(200, 150)
      .setBarHeight(20)
      .setItemHeight(18);
    
    // Populate port list
    updatePortList();
    
    // Connect/Disconnect button
    connectButton = cp5.addButton("connectButton")
      .setPosition(UI_X, UI_Y + 35)
      .setSize(BUTTON_WIDTH, BUTTON_HEIGHT)
      .setLabel("Connect")
      .onClick(new CallbackListener() {
        public void controlEvent(CallbackEvent theEvent) {
          handleConnectButton();
        }
      });
    
    // Record button
    recordButton = cp5.addButton("recordButton")
      .setPosition(UI_X + BUTTON_WIDTH + 10, UI_Y + 35)
      .setSize(BUTTON_WIDTH, BUTTON_HEIGHT)
      .setLabel("Record")
      .onClick(new CallbackListener() {
        public void controlEvent(CallbackEvent theEvent) {
          handleRecordButton();
        }
      });
  }
  
  // Data management controls
  private void setupDataControls() {
    int yOffset = UI_Y + 75;
    
    // Load CSV button
    loadButton = cp5.addButton("loadButton")
      .setPosition(UI_X, yOffset)
      .setSize(BUTTON_WIDTH, BUTTON_HEIGHT)
      .setLabel("Load CSV")
      .onClick(new CallbackListener() {
        public void controlEvent(CallbackEvent theEvent) {
          handleLoadButton();
        }
      });
    
    // Clear buffer button
    clearButton = cp5.addButton("clearButton")
      .setPosition(UI_X + BUTTON_WIDTH + 10, yOffset)
      .setSize(BUTTON_WIDTH, BUTTON_HEIGHT)
      .setLabel("Clear")
      .onClick(new CallbackListener() {
        public void controlEvent(CallbackEvent theEvent) {
          handleClearButton();
        }
      });
    
    // Save PNG button
    saveButton = cp5.addButton("saveButton")
      .setPosition(UI_X, yOffset + 35)
      .setSize(BUTTON_WIDTH, BUTTON_HEIGHT)
      .setLabel("Save PNG")
      .onClick(new CallbackListener() {
        public void controlEvent(CallbackEvent theEvent) {
          handleSaveButton();
        }
      });
  }
  
  // Filter parameter controls
  private void setupFilterControls() {
    int yOffset = UI_Y + 155;
    
    // EMA Alpha slider
    cp5.addLabel("emaLabel")
      .setPosition(UI_X, yOffset)
      .setText("EMA Smoothing (α)")
      .setColor(color(200, 220, 240));
    
    emaAlphaSlider = cp5.addSlider("emaAlpha")
      .setPosition(UI_X, yOffset + 15)
      .setSize(SLIDER_WIDTH, 15)
      .setRange(0.1, 0.9)
      .setValue(0.3)
      .setNumberOfTickMarks(9)
      .setSliderMode(Slider.FLEXIBLE);
    
    // Median window slider
    cp5.addLabel("medianLabel")
      .setPosition(UI_X, yOffset + 40)
      .setText("Median Window Size")
      .setColor(color(200, 220, 240));
    
    medianWindowSlider = cp5.addSlider("medianWindow")
      .setPosition(UI_X, yOffset + 55)
      .setSize(SLIDER_WIDTH, 15)
      .setRange(3, 9)
      .setValue(5)
      .setNumberOfTickMarks(7)
      .setSliderMode(Slider.FLEXIBLE);
  }
  
  // Replay controls
  private void setupReplayControls() {
    int yOffset = UI_Y + 230;
    
    // Replay speed slider
    cp5.addLabel("replayLabel")
      .setPosition(UI_X, yOffset)
      .setText("Replay Speed")
      .setColor(color(200, 220, 240));
    
    replaySpeedSlider = cp5.addSlider("replaySpeed")
      .setPosition(UI_X, yOffset + 15)
      .setSize(SLIDER_WIDTH, 15)
      .setRange(0.5, 3.0)
      .setValue(1.0)
      .setNumberOfTickMarks(11)
      .setSliderMode(Slider.FLEXIBLE);
    
    // Max range slider
    cp5.addLabel("rangeLabel")
      .setPosition(UI_X, yOffset + 40)
      .setText("Max Range (cm)")
      .setColor(color(200, 220, 240));
    
    maxRangeSlider = cp5.addSlider("maxRange")
      .setPosition(UI_X, yOffset + 55)
      .setSize(SLIDER_WIDTH, 15)
      .setRange(100, 500)
      .setValue(200)
      .setNumberOfTickMarks(9)
      .setSliderMode(Slider.FLEXIBLE);
  }
  
  // Display options
  private void setupDisplayControls() {
    int yOffset = UI_Y + 305;
    
    showGridCheckbox = cp5.addCheckbox("showGrid")
      .setPosition(UI_X, yOffset)
      .setSize(15, 15)
      .setLabel("Show Grid")
      .setColorLabel(color(200, 220, 240))
      .setValue(1);
    
    showLabelsCheckbox = cp5.addCheckbox("showLabels")
      .setPosition(UI_X, yOffset + 20)
      .setSize(15, 15)
      .setLabel("Show Labels")
      .setColorLabel(color(200, 220, 240))
      .setValue(1);
    
    showColorMapCheckbox = cp5.addCheckbox("showColorMap")
      .setPosition(UI_X, yOffset + 40)
      .setSize(15, 15)
      .setLabel("Show Color Legend")
      .setColorLabel(color(200, 220, 240))
      .setValue(1);
    
    enableSmoothingCheckbox = cp5.addCheckbox("enableSmoothing")
      .setPosition(UI_X, yOffset + 60)
      .setSize(15, 15)
      .setLabel("Enable Smoothing")
      .setColorLabel(color(200, 220, 240))
      .setValue(1);
  }
  
  // Status information display
  private void setupStatusLabels() {
    statusLabel = cp5.addLabel("status")
      .setPosition(UI_X, height - 80)
      .setSize(300, LABEL_HEIGHT)
      .setText("Status: Ready")
      .setColor(color(150, 180, 200));
    
    fpsLabel = cp5.addLabel("fps")
      .setPosition(UI_X, height - 60)
      .setSize(300, LABEL_HEIGHT)
      .setText("FPS: 0")
      .setColor(color(150, 180, 200));
    
    dataLabel = cp5.addLabel("data")
      .setPosition(UI_X, height - 40)
      .setSize(300, LABEL_HEIGHT)
      .setText("Data Points: 0")
      .setColor(color(150, 180, 200));
  }
  
  // Handle ControlP5 events
  void handleEvent(ControlEvent theEvent) {
    if (theEvent.isController()) {
      String controllerName = theEvent.getController().getName();
      
      switch(controllerName) {
        case "emaAlpha":
          if (filterManager != null) {
            filterManager.setEmaAlpha(theEvent.getController().getValue());
          }
          break;
          
        case "medianWindow":
          if (filterManager != null) {
            filterManager.setMedianWindowSize((int)theEvent.getController().getValue());
          }
          break;
          
        case "maxRange":
          if (visualizer != null) {
            // Update max range for visualization
          }
          break;
          
        case "replaySpeed":
          if (replayManager != null) {
            replayManager.setReplaySpeed(theEvent.getController().getValue());
          }
          break;
      }
    }
  }
  
  // Update port list
  void updatePortList() {
    if (portDropdown != null && serialHandler != null) {
      portDropdown.clear();
      
      String[] ports = serialHandler.getAvailablePorts();
      if (ports != null) {
        for (int i = 0; i < ports.length; i++) {
          portDropdown.addItem(ports[i], i);
        }
      }
    }
  }
  
  // Draw UI overlay information
  void drawOverlay(boolean isConnected, boolean isRecording, boolean isPaused, boolean replayMode, int currentMode) {
    // Update FPS calculation
    if (frameCount > lastFrameCount + 30) {
      lastFrameRate = frameRate;
      lastFrameCount = frameCount;
    }
    
    // Update status information
    String status = "";
    if (replayMode) {
      status = "Mode: REPLAY";
    } else if (isConnected) {
      status = isPaused ? "Mode: PAUSED" : "Mode: LIVE";
    } else {
      status = "Mode: DISCONNECTED";
    }
    
    if (isRecording) {
      status += " | REC";
    }
    
    // Update labels
    if (statusLabel != null) statusLabel.setText("Status: " + status);
    if (fpsLabel != null) fpsLabel.setText("FPS: " + nf(lastFrameRate, 2, 1));
    if (dataLabel != null) dataLabel.setText("Data Points: " + scanBuffer.size());
    
    // Draw UI panel background
    fill(40, 50, 70, 200);
    noStroke();
    rect(0, 0, UI_WIDTH + 40, UI_HEIGHT + 80);
    
    // Draw mode selection tabs
    drawModeTabs(currentMode);
    
    // Draw color legend if enabled
    if (showColorMapCheckbox != null && showColorMapCheckbox.getValue() == 1) {
      drawColorLegend();
    }
  }
  
  // Draw visualization mode tabs
  private void drawModeTabs(int currentMode) {
    int tabY = 400;
    int tabWidth = 45;
    int tabHeight = 25;
    
    String[] modes = {"Radar", "Cartesian", "Graph", "Replay", "3D"};
    
    for (int i = 0; i < 5; i++) {
      int x = UI_X + i * (tabWidth + 5);
      
      if (i + 1 == currentMode) {
        fill(80, 120, 160);
      } else {
        fill(60, 80, 100);
      }
      stroke(100, 120, 140);
      rect(x, tabY, tabWidth, tabHeight);
      
      fill(200, 220, 240);
      textSize(10);
      textAlign(CENTER, CENTER);
      text((i + 1) + ". " + modes[i], x + tabWidth/2, tabY + tabHeight/2);
    }
  }
  
  // Draw color distance legend
  private void drawColorLegend() {
    int legendX = width - 120;
    int legendY = 50;
    int legendWidth = 80;
    int legendHeight = 200;
    
    // Draw gradient
    for (int i = 0; i < legendHeight; i++) {
      float t = (float)i / legendHeight;
      float distance = lerp(10, 200, t);
      color gradColor = getDistanceColor(distance);
      
      stroke(gradColor);
      line(legendX, legendY + i, legendX + legendWidth, legendY + i);
    }
    
    // Border
    stroke(200, 220, 240);
    noFill();
    rect(legendX, legendY, legendWidth, legendHeight);
    
    // Labels
    fill(200, 220, 240);
    textSize(12);
    textAlign(LEFT, CENTER);
    text("Distance (cm)", legendX + legendWidth + 10, legendY + 10);
    text("200", legendX + legendWidth + 10, legendY + 10);
    text("100", legendX + legendWidth + 10, legendY + legendHeight/2);
    text("10", legendX + legendWidth + 10, legendY + legendHeight - 10);
    
    noFill();
  }
  
  // Color mapping utility (same as in VisualizerModes)
  private color getDistanceColor(float distance) {
    color nearColor = color(255, 100, 100);
    color mediumColor = color(255, 200, 100);
    color farColor = color(100, 200, 255);
    
    if (distance < 100) {
      return lerpColor(nearColor, mediumColor, distance / 100);
    } else {
      return lerpColor(mediumColor, farColor, (distance - 100) / 100);
    }
  }
  
  // Event handlers for buttons
  private void handleConnectButton() {
    if (connectButton.getLabel().equals("Connect")) {
      toggleConnection();
    } else {
      toggleConnection();
    }
  }
  
  private void handleRecordButton() {
    toggleRecording();
  }
  
  private void handleLoadButton() {
    loadCSV();
  }
  
  private void handleClearButton() {
    clearBuffer();
  }
  
  private void handleSaveButton() {
    savePNG();
  }
  
  // Update connect button state
  void updateConnectButton(boolean isConnected) {
    if (connectButton != null) {
      connectButton.setLabel(isConnected ? "Disconnect" : "Connect");
    }
  }
  
  // Update record button state
  void updateRecordButton(boolean isRecording) {
    if (recordButton != null) {
      recordButton.setLabel(isRecording ? "Stop" : "Record");
      recordButton.setColorBackground(isRecording ? color(180, 80, 80) : color(60, 80, 100));
    }
  }
}

/*
=======================================================
  ADVANCED FEATURES CLASS
=======================================================
*/

class AdvancedFeatures {
  
  // Motion detection parameters
  private ArrayList<ScanData> previousSweep;
  private ArrayList<MotionEvent> motionEvents;
  private float motionThreshold;
  private int sweepAngleThreshold;
  
  // Performance monitoring
  private float[] fpsHistory;
  private int fpsIndex;
  private long lastPerformanceCheck;
  private int frameCount;
  
  // Auto-detection settings
  private boolean autoDetectPorts;
  private String[] detectedPorts;
  private boolean lastConnectionStatus;
  
  // 3D orbit control
  private boolean orbitControlEnabled;
  private float orbitSpeed;
  private int lastMouseX, lastMouseY;
  private boolean mouseDragging;
  
  // PNG export settings
  private int exportQuality;
  private String exportDirectory;
  
  // Constructor
  AdvancedFeatures() {
    previousSweep = new ArrayList<ScanData>();
    motionEvents = new ArrayList<MotionEvent>();
    motionThreshold = 15.0f; // cm difference threshold
    sweepAngleThreshold = 180; // Complete sweep detection
    
    fpsHistory = new float[30]; // Store last 30 FPS readings
    fpsIndex = 0;
    lastPerformanceCheck = millis();
    frameCount = 0;
    
    autoDetectPorts = true;
    detectedPorts = new String[0];
    lastConnectionStatus = false;
    
    orbitControlEnabled = false;
    orbitSpeed = 0.01f;
    lastMouseX = 0;
    lastMouseY = 0;
    mouseDragging = false;
    
    exportQuality = 100;
    exportDirectory = "exports/";
    
    // Create export directory
    createDirectoryIfNeeded(exportDirectory);
  }
  
  // Motion detection between sweeps
  void detectMotion(ArrayList<ScanData> currentSweep) {
    // Check if we have a complete sweep (angle 0-180)
    if (currentSweep.size() < 90) return; // Need sufficient data points
    
    // Find sweep boundaries
    int minAngle = 999, maxAngle = -999;
    for (ScanData data : currentSweep) {
      minAngle = min(minAngle, (int)data.angle);
      maxAngle = max(maxAngle, (int)data.angle);
    }
    
    // Process only if we have a complete sweep
    if (maxAngle - minAngle >= sweepAngleThreshold - 10) {
      // Compare with previous sweep for motion detection
      if (previousSweep.size() > 0) {
        detectSweepChanges(currentSweep, previousSweep);
      }
      
      // Store current sweep for next comparison
      previousSweep = new ArrayList<ScanData>(currentSweep);
    }
  }
  
  // Detect changes between sweeps
  private void detectSweepChanges(ArrayList<ScanData> current, ArrayList<ScanData> previous) {
    for (ScanData currentData : current) {
      // Find corresponding angle in previous sweep
      ScanData previousData = findClosestAngle(previous, currentData.angle);
      
      if (previousData != null && previousData.isValid() && currentData.isValid()) {
        float distanceDiff = abs(currentData.smoothDistance - previousData.smoothDistance);
        
        if (distanceDiff > motionThreshold) {
          // Motion detected
          MotionEvent event = new MotionEvent(
            currentData.angle, 
            currentData.smoothDistance, 
            distanceDiff, 
            millis()
          );
          motionEvents.add(event);
          
          // Limit memory usage
          if (motionEvents.size() > 50) {
            motionEvents.remove(0);
          }
        }
      }
    }
  }
  
  // Find closest angle data
  private ScanData findClosestAngle(ArrayList<ScanData> sweep, float targetAngle) {
    float minDiff = 999;
    ScanData closest = null;
    
    for (ScanData data : sweep) {
      float diff = abs(data.angle - targetAngle);
      if (diff < minDiff) {
        minDiff = diff;
        closest = data;
      }
    }
    
    return minDiff < 5 ? closest : null; // Within 5 degrees
  }
  
  // Auto-detect serial ports
  void autoDetectSerialPorts() {
    if (!autoDetectPorts) return;
    
    String[] currentPorts = Serial.list();
    
    // Check for new ports
    if (currentPorts.length != detectedPorts.length) {
      detectedPorts = currentPorts;
      println("Auto-detected " + detectedPorts.length + " serial ports");
    }
  }
  
  // Auto-connect to detected port
  boolean autoConnectIfAvailable() {
    autoDetectSerialPorts();
    
    if (detectedPorts.length > 0 && !isConnected) {
      // Try to connect to first available port
      String targetPort = "";
      
      for (String port : detectedPorts) {
        // Skip common system ports
        if (!port.contains("COM1") && !port.contains("COM2") && 
            !port.equals("/dev/ttyUSB0") && !port.equals("/dev/ttyACM0")) {
          targetPort = port;
          break;
        }
      }
      
      if (targetPort.isEmpty() && detectedPorts.length > 0) {
        targetPort = detectedPorts[0];
      }
      
      if (!targetPort.isEmpty()) {
        return serialHandler.connect(targetPort);
      }
    }
    
    return false;
  }
  
  // Enhanced PNG export with options
  void exportPNG(String filename, boolean includeUI) {
    try {
      // Create export directory
      createDirectoryIfNeeded(exportDirectory);
      
      // Set full path
      String fullPath = exportDirectory + filename + ".png";
      
      // Save with custom settings
      if (includeUI) {
        // Save full window including UI
        save(fullPath);
      } else {
        // Save only visualization area
        PGraphics exportImage = createGraphics(width, height);
        exportImage.beginDraw();
        
        // Copy visualization area only (exclude UI panel)
        exportImage.image(get(), 0, 0);
        
        // Remove UI panel area
        exportImage.fill(20, 25, 35);
        exportImage.noStroke();
        exportImage.rect(0, 0, 270, height);
        
        exportImage.endDraw();
        exportImage.save(fullPath);
      }
      
      println("PNG exported: " + fullPath);
      
    } catch (Exception e) {
      println("Export failed: " + e.getMessage());
    }
  }
  
  // Performance monitoring
  void updatePerformanceMonitor() {
    frameCount++;
    long currentTime = millis();
    
    // Update FPS history every second
    if (currentTime - lastPerformanceCheck >= 1000) {
      fpsHistory[fpsIndex] = frameRate;
      fpsIndex = (fpsIndex + 1) % fpsHistory.length;
      lastPerformanceCheck = currentTime;
      frameCount = 0;
    }
  }
  
  // Get average FPS
  float getAverageFPS() {
    float sum = 0;
    int count = 0;
    
    for (float fps : fpsHistory) {
      if (fps > 0) {
        sum += fps;
        count++;
      }
    }
    
    return count > 0 ? sum / count : 0;
  }
  
  // Get performance statistics
  String getPerformanceStats() {
    float avgFPS = getAverageFPS();
    float minFPS = 999;
    float maxFPS = 0;
    
    for (float fps : fpsHistory) {
      if (fps > 0) {
        minFPS = min(minFPS, fps);
        maxFPS = max(maxFPS, fps);
      }
    }
    
    if (minFPS == 999) {
      return "Performance: No data";
    }
    
    return String.format("FPS: Avg=%.1f, Min=%.1f, Max=%.1f", avgFPS, minFPS, maxFPS);
  }
  
  // 3D orbit control handling
  void handleMousePressed(int x, int y) {
    if (orbitControlEnabled && currentMode == 5) {
      mouseDragging = true;
      lastMouseX = x;
      lastMouseY = y;
    }
  }
  
  void handleMouseDragged(int x, int y) {
    if (mouseDragging && orbitControlEnabled) {
      int dx = x - lastMouseX;
      int dy = y - lastMouseY;
      
      visualizer.handleMouseDrag(dx, dy);
      
      lastMouseX = x;
      lastMouseY = y;
    }
  }
  
  void handleMouseReleased() {
    mouseDragging = false;
  }
  
  // Toggle orbit control
  void toggleOrbitControl() {
    orbitControlEnabled = !orbitControlEnabled;
    visualizer.setOrbitEnabled(orbitControlEnabled);
    
    if (orbitControlEnabled) {
      println("3D orbit control enabled - drag mouse to rotate");
    } else {
      println("3D orbit control disabled");
    }
  }
  
  // Get motion events for visualization
  ArrayList<MotionEvent> getMotionEvents() {
    // Clean old events - more efficiently
    long currentTime = millis();
    
    // Use iterator for safe removal during iteration
    Iterator<MotionEvent> iterator = motionEvents.iterator();
    while (iterator.hasNext()) {
      MotionEvent event = iterator.next();
      if (currentTime - event.timestamp > 5000) { // 5 second TTL
        iterator.remove();
      }
    }
    
    return new ArrayList<MotionEvent>(motionEvents);
  }
  
  // Export motion data to CSV
  boolean exportMotionData(String filename) {
    try {
      String fullPath = exportDirectory + "motion_" + filename + ".csv";
      
      PrintWriter writer = createWriter(fullPath);
      writer.println("# Motion Detection Data");
      writer.println("# Format: angle,distance,change_magnitude,timestamp");
      writer.println();
      
      for (MotionEvent event : motionEvents) {
        writer.printf("%.1f,%.1f,%.1f,%d%n", 
                     event.angle, event.distance, event.changeMagnitude, event.timestamp);
      }
      
      writer.flush();
      writer.close();
      
      println("Motion data exported: " + fullPath);
      return true;
      
    } catch (Exception e) {
      println("Motion export failed: " + e.getMessage());
      return false;
    }
  }
  
  // Utility function to create directory
  private void createDirectoryIfNeeded(String dirPath) {
    File dir = new File(dirPath);
    if (!dir.exists()) {
      dir.mkdirs();
    }
  }
  
  // Get/set methods
  void setMotionThreshold(float threshold) {
    this.motionThreshold = threshold;
  }
  
  float getMotionThreshold() {
    return motionThreshold;
  }
  
  void setAutoDetectEnabled(boolean enabled) {
    this.autoDetectPorts = enabled;
  }
  
  boolean getAutoDetectEnabled() {
    return autoDetectPorts;
  }
  
  void setOrbitSpeed(float speed) {
    this.orbitSpeed = constrain(speed, 0.001f, 0.1f);
  }
  
  float getOrbitSpeed() {
    return orbitSpeed;
  }
  
  void setExportDirectory(String directory) {
    this.exportDirectory = directory;
    if (!directory.endsWith("/")) {
      this.exportDirectory += "/";
    }
  }
  
  String getExportDirectory() {
    return exportDirectory;
  }
}


/*
=======================================================
  MAIN SETUP AND DRAW FUNCTIONS
=======================================================
*/

// Setup and initialization
void setup() {
  size(CANVAS_WIDTH, CANVAS_HEIGHT, P3D);
  
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
    // Keep only recent data for performance - use subList for O(n) instead of O(n²)
    scanBuffer = new ArrayList<ScanData>(scanBuffer.subList(scanBuffer.size() - 800, scanBuffer.size()));
  }
  
  // Update and draw current visualization mode
  visualizer.draw(scanBuffer, currentMode);
  
  // Draw UI overlay
  uiController.drawOverlay(isConnected, isRecording, isPaused, replayMode, currentMode);
  
  // Apply effects like fading trails
  visualizer.applyEffects();
}

/*
=======================================================
  EVENT HANDLERS
=======================================================
*/

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

/*
=======================================================
  HELPER FUNCTIONS
=======================================================
*/

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
