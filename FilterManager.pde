/*
=======================================================
  FilterManager.pde - Handles data smoothing and 
  filtering for ultrasonic sensor data
  
  Implements: Exponential Moving Average (EMA), 
  Median Filter, Outlier Detection
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