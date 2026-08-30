# Dhuruva INS (Intelligent Navigation System)

## Overview
**Dhuruva INS** is an advanced, offline-capable Flutter application designed to provide **Intelligent Dead Reckoning (IDR)** and Turn-by-Turn navigation. By combining standard GNSS routing with deep hardware sensor integration, the app ensures continuous, high-accuracy tracking of the user's position and orientation, especially in environments where GPS signals may be weak or temporarily unavailable.

---

## Data Fetching & Processing Architecture

The core of the system relies heavily on **Sensor Fusion**. The application actively fetches data from the device's hardware at **50Hz** (50 times per second) and processes it through custom mathematical filters to generate perfectly smooth orientation telemetry.

### 1. GNSS (GPS) Data Processing
*   **Data Source:** Device GPS hardware (via `geolocator`).
*   **Configuration:** The OS is forced into `bestForNavigation` mode for maximum spatial accuracy, paired with a persistent foreground service.
*   **Processing Engine:** The raw latitude, longitude, and velocity are fetched via a continuous stream. The application implements an intelligent drift-cancellation algorithm: if the spatial change is under 3 meters while the user's speed is near zero, the micro-drift is ignored. This prevents the navigation UI from "vibrating" when the user is stationary.

### 2. IMU Sensor Fusion Engine (Pitch, Roll, Yaw)
Standard GPS cannot determine which way a device is pointing when stationary. The app solves this by fusing data from three separate hardware sensors: the **Accelerometer**, **Gyroscope**, and **Magnetometer**.

#### A. Pitch (X-Axis) and Roll (Y-Axis)
First, the absolute tilt is calculated using gravity vectors from the **Accelerometer**:
*   `Pitch_acc = atan2(accel_y, sqrt(accel_x^2 + accel_z^2)) * (180 / π)`
*   `Roll_acc = atan2(-accel_x, accel_z) * (180 / π)`

Because accelerometer data is extremely noisy during physical movement, a **Complementary Filter** is applied. This filter fuses the noisy accelerometer data with the fast, smooth angular velocity from the **Gyroscope**, yielding near-perfect stability:
*   `Pitch_new = 0.98 * (Pitch_old + gyro_x * dt) + 0.02 * Pitch_acc`
*   `Roll_new = 0.98 * (Roll_old + gyro_y * dt) + 0.02 * Roll_acc`

#### B. Yaw / Heading (Z-Axis)
A standard compass is highly inaccurate if the device is not held perfectly flat. Dhuruva INS performs a **3D Tilt-Compensation** on the raw **Magnetometer** using the highly accurate Pitch and Roll angles calculated above. 
*   This mathematical projection "flattens" the magnetic field vectors, calculating a true North heading regardless of how the user tilts the device.
*   The raw magnetic heading is then fused with the **Gyroscope Z-axis** using another complementary filter.
*   The system actively interpolates "wrap-around" boundaries to seamlessly handle the mathematical jump when the compass crosses from -180° to +180°.

---

## 3. Machine Learning / JSON Telemetry Export
Dhuruva INS is fully equipped to feed data into external Python models. 

While the app processes the complex IMU mathematics in real-time for the UI, it also runs a silent background process that builds a `List` of the telemetry frames.
*   Every **60 seconds**, a background timer automatically serializes this buffer into a JSON file (`telemetry_latest.json`).
*   This file is saved directly to the device's Documents directory.
*   The JSON payload includes universally synchronized UNIX timestamps, making it effortless to ingest into frameworks like Pandas, TensorFlow, or PyTorch.

**Sample JSON Output Format:**
```json
[
  {
    "timestamp": 1709234567890,
    "gps": {
      "lat": 28.6139,
      "lon": 77.2090,
      "speed": 1.2
    },
    "imu": {
      "accel": {"x": 0.02, "y": 9.81, "z": -0.05},
      "gyro": {"x": 0.0, "y": 0.0, "z": 0.01},
      "mag": {"x": 10.5, "y": -22.1, "z": 45.2}
    },
    "orientation": {
      "pitch": 2.45,
      "roll": -1.12,
      "yaw": 85.3
    }
  }
]
```
