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
  
  // Simulation state variables for test data generation
  private float testAngle = 0;      // Current sweep angle (0-180 degrees)
  private int testDir = 1;          // Sweep direction: 1 for forward, -1 for backward
  
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