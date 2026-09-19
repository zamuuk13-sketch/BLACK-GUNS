# BLACK GUNS

## Black Guns Mobile VR — Phase 1

Dedicated Android companion app for the Black Guns PC VR game.

### Included now

- Godot Android project foundation.
- Minimal 3D test place.
- Connect-to-PC screen.
- Gyroscope and accelerometer acquisition.
- UDP tracking packet format.
- Android camera permission foundation; camera frames are not displayed.
- Provider-independent 21-joint hand skeleton placeholder.
- Curved blue teleport trajectory and destination sphere.

### Tracking architecture

The phone is intended to act as the VR/tracking device while the PC renders Black Guns. The phone sends head pose and hand landmarks to the PC; the PC will later return a stereo L/R game stream.

The current accelerometer position estimator is only a development fallback. Accurate 6DoF positional tracking needs visual/inertial sensor fusion to avoid inertial drift.

Godot documents optical hand tracking through OpenXR hand trackers and skeleton modifiers for supported XR runtimes:
https://docs.godotengine.org/en/latest/tutorials/xr/openxr_hand_tracking.html

### Next implementation phases

1. Android camera frame provider + real hand landmarks.
2. Visual/inertial 6DoF head tracking.
3. PC receiver and low-latency transport.
4. PC-to-phone stereo video streaming.
5. Teleport confirmation gesture.
6. Physical hand interaction and Black Guns gameplay.
