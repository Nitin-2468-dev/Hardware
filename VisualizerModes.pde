/*
=======================================================
  VisualizerModes.pde - Contains all visualization
  rendering functions for different display modes
  
  Modes: Radar/Polar, Cartesian 2D, Graph, Replay/Heatmap,
  3D Fan Sweep
=======================================================
*/

class VisualizerModes {
  private PGraphics radarLayer, cartesianLayer, graphLayer, replayLayer, layer3D;
  private PGraphics effectsLayer;
  private int centerX, centerY, centerZ;
  private float maxRange;
  
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
        float screenX = centerX + point.smoothDistance * cos(radians(point.angle - 90)) * 2;
        float screenY = centerY + point.smoothDistance * sin(radians(point.angle - 90)) * 2;
        
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
      HashMap<String, Integer> intensity = new HashMap<String, Integer>();
      
      // Aggregate data for heatmap - only store actual data points
      for (ScanData point : data) {
        if (point.isValid()) {
          int angleIdx = constrain((int)(point.angle / 2) * 2, 0, 180); // Round to nearest 2
          int distanceIdx = constrain((int)(point.smoothDistance / 3) * 3, 0, 300); // Round to nearest 3
          String key = angleIdx + "," + distanceIdx;
          
          intensity.put(key, intensity.getOrDefault(key, 0) + 1);
        }
      }
      
      // Draw heatmap - only render where we have data
      for (String key : intensity.keySet()) {
        String[] parts = key.split(",");
        int angle = Integer.parseInt(parts[0]);
        int dist = Integer.parseInt(parts[1]);
        int intensityValue = intensity.get(key);
        
        float screenX = centerX + cos(radians(angle - 90)) * dist * 2;
        float screenY = centerY + sin(radians(angle - 90)) * dist * 2;
        
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
    
    // Draw 3D data points
    for (ScanData point : data) {
      if (point.isValid()) {
        float x = point.smoothDistance * cos(radians(point.angle));
        float z = point.smoothDistance * sin(radians(point.angle));
        float y = 0;
        
        // Scale and translate to screen
        float screenX = centerX + x * 2;
        float screenZ = centerZ + z * 2;
        float screenY = centerY - y * 2;
        
        color pointColor = getDistanceColor(point.smoothDistance);
        
        // Draw point with depth effect
        pushMatrix();
        translate(screenX, screenY, screenZ);
        fill(pointColor);
        noStroke();
        sphereDetail(4);
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
    if (enabled) {
      // Enable 3D rendering
      size(width, height, P3D);
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