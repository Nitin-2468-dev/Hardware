/*
=======================================================
  AdvancedFeatures.pde - Additional functionality
  and enhancements for the ultrasonic visualizer
  
  Features: Motion detection, auto-detection,
  PNG export, 3D controls, performance monitoring
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