/*
=======================================================
  SerialHandler.pde - Manages serial communication
  with Arduino for real-time ultrasonic data reception
  
  Handles: port selection, data parsing, connection
  management
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
      // Find available port (typically the first one that isn't a system port)
      String[] ports = Serial.list();
      String targetPort = "";
      
      for (String port : ports) {
        // Skip system/invalid ports on Windows
        if (!port.contains("COM") && !port.contains("tty") || 
            (port.contains("COM") && !port.contains("COM3") && !port.contains("COM4"))) {
          targetPort = port;
          break;
        }
      }
      
      if (targetPort.isEmpty() && ports.length > 0) {
        targetPort = ports[0]; // Use first available port as fallback
      }
      
      if (!targetPort.isEmpty()) {
        port = new Serial(this, targetPort, selectedBaudRate);
        port.bufferUntil('\n');
        selectedPort = targetPort;
        return true;
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
    while (port != null && port.available() > 0) {
      String line = port.readString();
      if (line != null) {
        processSerialData(line.trim());
      }
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
    static float testAngle = 0;
    static int testDir = 1;
    
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