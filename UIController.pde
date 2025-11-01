/*
=======================================================
  UIController.pde - Manages ControlP5 GUI elements
  and user interface interactions
  
  Provides: Buttons, sliders, dropdowns, status display
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
    if (showColorMapCheckbox.getValue() == 1) {
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