/*
=======================================================
  ReplayManager.pde - Handles CSV data logging and 
  replay functionality
  
  Features: Save/load scan data, timed replay,
  speed control, data manipulation
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