import Flutter
import UIKit
import GoogleMaps
import CoreLocation
import UserNotifications
import AudioToolbox
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate, AVAudioPlayerDelegate {
  let locationManager = CLLocationManager()
  var methodChannel: FlutterMethodChannel?
  var alarmTimer: Timer?
  var audioPlayer: AVAudioPlayer?
  var isPlayingAlarm = false
  var vibrationTimer: DispatchSourceTimer?
  var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
  var triggeredGeofences: Set<String> = [] // Track already triggered geofences to prevent duplicates
  var hasActiveGeofences = false // Track if we have active geofences

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Read Google Maps API key from Info.plist
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String {
      GMSServices.provideAPIKey(apiKey)
    }

    // Configure location manager for native iOS geofencing
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 10

    // CRITICAL: Request authorization BEFORE setting background updates
    // iOS requires explicit authorization request
    let authStatus: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      authStatus = locationManager.authorizationStatus
    } else {
      authStatus = CLLocationManager.authorizationStatus()
    }
    print("📍 Current location authorization status: \(authStatus.rawValue)")

    if authStatus == .notDetermined {
      print("📍 Requesting Always authorization for background geofencing...")
      locationManager.requestAlwaysAuthorization()
    } else if authStatus == .authorizedWhenInUse {
      print("📍 Upgrading to Always authorization...")
      locationManager.requestAlwaysAuthorization()
    } else if authStatus == .authorizedAlways {
      print("✅ Already have Always authorization - enabling background updates")
      enableBackgroundLocationUpdates()
    } else {
      print("⚠️ Location authorization denied or restricted: \(authStatus.rawValue)")
    }

    // Configure notification center for foreground and background notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self

      // Request notification permissions (critical alerts require Apple approval, so we use standard alerts)
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
          print("✅ Notification permissions granted")
        } else if let error = error {
          print("❌ Notification permission error: \(error)")
        }
      }

      // Register notification category with actions
      let stopAction = UNNotificationAction(identifier: "STOP_ALARM", title: "Stop Alarm", options: [.foreground])
      let alarmCategory = UNNotificationCategory(
        identifier: "ALARM_CATEGORY",
        actions: [stopAction],
        intentIdentifiers: [],
        options: [.customDismissAction]
      )
      UNUserNotificationCenter.current().setNotificationCategories([alarmCategory])
    }

    // Set up Flutter method channel for native geofencing
    let controller = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(name: "com.wakemeup/geofence", binaryMessenger: controller.binaryMessenger)

    methodChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }

      switch call.method {
      case "startGeofence":
        if let args = call.arguments as? [String: Any],
           let id = args["id"] as? String,
           let lat = args["latitude"] as? Double,
           let lng = args["longitude"] as? Double,
           let radius = args["radius"] as? Double,
           let name = args["name"] as? String {
          let ringtone = args["ringtone"] as? String ?? "alarm"
          self.startGeofenceMonitoring(id: id, latitude: lat, longitude: lng, radius: radius, name: name, ringtone: ringtone)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }

      case "stopGeofence":
        if let args = call.arguments as? [String: Any],
           let id = args["id"] as? String {
          self.stopGeofenceMonitoring(id: id)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }

      case "stopAllGeofences":
        self.stopAllGeofenceMonitoring()
        result(true)

      case "playSystemSound":
        if let args = call.arguments as? [String: Any],
           let soundType = args["soundType"] as? String,
           let loop = args["loop"] as? Bool {
          self.playSystemSound(soundType: soundType, loop: loop)
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }

      case "stopSystemSound":
        self.stopSystemSound()
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)

    // Check if app was launched by location event
    if launchOptions?[.location] != nil {
      print("🚀 App launched by location event")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Background Location Updates

  /// Enable background location updates after authorization is granted
  func enableBackgroundLocationUpdates() {
    print("🔧 Enabling background location updates...")

    // These settings are REQUIRED for background geofencing
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false

    // Start significant location change monitoring to keep app alive in background
    // This is essential for geofencing to work when app is suspended
    if CLLocationManager.significantLocationChangeMonitoringAvailable() {
      locationManager.startMonitoringSignificantLocationChanges()
      print("✅ Significant location change monitoring started")
    } else {
      print("⚠️ Significant location change monitoring not available")
    }

    // Also start standard location updates for more accurate tracking
    // This helps geofencing trigger more reliably
    locationManager.startUpdatingLocation()
    print("✅ Location updates started")
  }

  /// Handle authorization changes
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    print("📍 Location authorization changed to: \(status.rawValue)")

    switch status {
    case .authorizedAlways:
      print("✅ Always authorization granted - enabling background updates")
      enableBackgroundLocationUpdates()

      // Restart monitoring for any existing geofences
      let monitoredCount = manager.monitoredRegions.count
      print("📍 Re-checking \(monitoredCount) monitored regions after authorization")

    case .authorizedWhenInUse:
      print("⚠️ Only 'When In Use' granted - background geofencing may not work reliably")
      print("⚠️ User should go to Settings > Privacy > Location > WakeMeUp > Always")
      // Still enable what we can
      locationManager.allowsBackgroundLocationUpdates = true
      locationManager.startUpdatingLocation()

    case .denied, .restricted:
      print("❌ Location access denied or restricted - geofencing will NOT work")

    case .notDetermined:
      print("📍 Authorization not yet determined")

    @unknown default:
      print("📍 Unknown authorization status: \(status.rawValue)")
    }
  }

  // MARK: - Native iOS Geofencing

  func startGeofenceMonitoring(id: String, latitude: Double, longitude: Double, radius: Double, name: String, ringtone: String = "alarm") {
    // First check authorization
    let authStatus: CLAuthorizationStatus
    if #available(iOS 14.0, *) {
      authStatus = locationManager.authorizationStatus
    } else {
      authStatus = CLLocationManager.authorizationStatus()
    }
    if authStatus != .authorizedAlways && authStatus != .authorizedWhenInUse {
      print("⚠️ Location not authorized - requesting permission")
      locationManager.requestAlwaysAuthorization()
    }

    // iOS minimum radius is 100m, but 200m is recommended for reliability
    let effectiveRadius = max(radius, 200.0)

    let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    let region = CLCircularRegion(center: center, radius: effectiveRadius, identifier: id)
    region.notifyOnEntry = true
    region.notifyOnExit = true // Also notify on exit for "moving away" warning

    // Store alarm data in UserDefaults for background trigger
    UserDefaults.standard.set(name, forKey: "geofence_name_\(id)")
    UserDefaults.standard.set(ringtone, forKey: "geofence_ringtone_\(id)")
    UserDefaults.standard.set(true, forKey: "geofence_active_\(id)") // Mark as active
    UserDefaults.standard.synchronize()

    // Mark that we have active geofences
    hasActiveGeofences = true

    // Ensure background location updates are enabled
    if authStatus == .authorizedAlways {
      enableBackgroundLocationUpdates()
    }

    locationManager.startMonitoring(for: region)
    print("📍 Native iOS geofence started: \(name) at \(latitude), \(longitude) radius: \(effectiveRadius)m, ringtone: \(ringtone)")
    print("   Authorization status: \(authStatus.rawValue)")
    print("   Background updates enabled: \(locationManager.allowsBackgroundLocationUpdates)")
    print("   Monitored regions count: \(locationManager.monitoredRegions.count)")
  }

  func stopGeofenceMonitoring(id: String) {
    // Stop the alarm sound when geofence is stopped
    stopSystemSound()

    // Clear triggered flag so geofence can trigger again if reactivated
    triggeredGeofences.remove(id)

    // Always clean up UserDefaults regardless of whether region is found
    UserDefaults.standard.removeObject(forKey: "geofence_name_\(id)")
    UserDefaults.standard.removeObject(forKey: "geofence_ringtone_\(id)")
    UserDefaults.standard.removeObject(forKey: "geofence_active_\(id)")
    UserDefaults.standard.synchronize()

    for region in locationManager.monitoredRegions {
      if region.identifier == id {
        locationManager.stopMonitoring(for: region)
        print("🛑 Native iOS geofence stopped: \(id)")
        break
      }
    }

    // Check if we still have active geofences
    hasActiveGeofences = !locationManager.monitoredRegions.isEmpty
    print("   Remaining monitored regions: \(locationManager.monitoredRegions.count)")

    // If no more geofences, we can stop location updates to save battery
    if !hasActiveGeofences {
      print("📍 No more active geofences - stopping continuous location updates")
      locationManager.stopUpdatingLocation()
      // Keep significant location monitoring as it uses minimal battery
    }
  }

  func stopAllGeofenceMonitoring() {
    // Clear all triggered flags
    triggeredGeofences.removeAll()

    for region in locationManager.monitoredRegions {
      locationManager.stopMonitoring(for: region)
      UserDefaults.standard.removeObject(forKey: "geofence_name_\(region.identifier)")
      UserDefaults.standard.removeObject(forKey: "geofence_ringtone_\(region.identifier)")
      UserDefaults.standard.removeObject(forKey: "geofence_active_\(region.identifier)")
    }
    UserDefaults.standard.synchronize()

    hasActiveGeofences = false
    locationManager.stopUpdatingLocation()
    print("🛑 All native iOS geofences stopped")
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    print("🎯🎯🎯 NATIVE iOS GEOFENCE ENTERED: \(region.identifier)")
    print("   App state: \(UIApplication.shared.applicationState.rawValue) (0=active, 1=inactive, 2=background)")

    // CRITICAL: Check if this geofence is still active in UserDefaults
    // This prevents triggers when user has toggled off the alarm
    let isActive = UserDefaults.standard.bool(forKey: "geofence_active_\(region.identifier)")
    if !isActive {
      print("⚠️ Geofence is NOT active in UserDefaults - alarm was toggled off, skipping")
      // Stop monitoring this region since it's no longer active
      manager.stopMonitoring(for: region)
      return
    }

    // PREVENT DUPLICATE TRIGGERS - check if already triggered
    if triggeredGeofences.contains(region.identifier) {
      print("⚠️ Geofence already triggered, skipping duplicate: \(region.identifier)")
      return
    }

    // Mark as triggered
    triggeredGeofences.insert(region.identifier)
    print("✅ Geofence marked as triggered: \(region.identifier)")

    let alarmName = UserDefaults.standard.string(forKey: "geofence_name_\(region.identifier)") ?? "Location Alarm"
    let ringtone = UserDefaults.standard.string(forKey: "geofence_ringtone_\(region.identifier)") ?? "alarm"

    // IMPORTANT: Start alarm sound IMMEDIATELY from native code
    // This works even when app is in background or screen is locked
    print("🔊 Starting alarm sound from native iOS (background-safe)")
    print("   - Ringtone: \(ringtone)")
    playSystemSound(soundType: ringtone, loop: true)

    // Show notification with critical alert (ONLY notification - Flutter won't show another)
    showGeofenceNotification(title: "⏰ \(alarmName)", body: "You have arrived at your destination!")

    // Notify Flutter (for UI update only, not for notification/sound)
    methodChannel?.invokeMethod("onGeofenceEntered", arguments: ["id": region.identifier, "name": alarmName])
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    print("🚪 Native iOS geofence exited: \(region.identifier)")

    // Check if this geofence is still active
    let isActive = UserDefaults.standard.bool(forKey: "geofence_active_\(region.identifier)")
    if !isActive {
      print("⚠️ Geofence is not active, skipping exit notification")
      return
    }

    // Check if the alarm has already triggered (user arrived)
    // If already triggered, don't show "moving away" warning
    if triggeredGeofences.contains(region.identifier) {
      print("ℹ️ Alarm already triggered, skipping exit warning")
      return
    }

    let alarmName = UserDefaults.standard.string(forKey: "geofence_name_\(region.identifier)") ?? "Location Alarm"

    // Show warning notification that user is moving away from destination
    showExitWarningNotification(alarmName: alarmName, regionId: region.identifier)

    // Notify Flutter about exit
    methodChannel?.invokeMethod("onGeofenceExited", arguments: ["id": region.identifier, "name": alarmName])
  }

  /// Show a warning notification when user moves away from the alarm location
  func showExitWarningNotification(alarmName: String, regionId: String) {
    let content = UNMutableNotificationContent()
    content.title = "⚠️ Moving Away"
    content.body = "You're leaving the area for '\(alarmName)'. The alarm is still active."
    content.sound = UNNotificationSound.default

    if #available(iOS 15.0, *) {
      content.interruptionLevel = .active
    }

    content.categoryIdentifier = "WARNING_CATEGORY"

    // Use a unique identifier for exit notifications
    let request = UNNotificationRequest(identifier: "GEOFENCE_EXIT_\(regionId)", content: content, trigger: nil)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("❌ Exit notification error: \(error)")
      } else {
        print("✅ Exit warning notification sent")
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    print("❌ Geofence monitoring failed: \(error.localizedDescription)")
  }

  func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
    print("✅ Started monitoring geofence: \(region.identifier)")
    // Request state to check if already inside
    manager.requestState(for: region)
  }

  func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
    // CRITICAL: Check if this geofence is still active before doing anything
    let isActive = UserDefaults.standard.bool(forKey: "geofence_active_\(region.identifier)")

    switch state {
    case .inside:
      print("📍 Already inside geofence: \(region.identifier), isActive: \(isActive)")
      // Only trigger if the alarm is still active
      if isActive {
        // Trigger immediately if already inside
        locationManager(manager, didEnterRegion: region)
      } else {
        print("⚠️ Skipping trigger - alarm is not active")
      }
    case .outside:
      print("📍 Currently outside geofence: \(region.identifier)")
    case .unknown:
      print("📍 Unknown state for geofence: \(region.identifier)")
    @unknown default:
      break
    }
  }

  /// Handle location updates - important for keeping geofencing alive in background
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }

    // Only log occasionally to avoid spam
    let now = Date()
    let lastLogKey = "last_location_log_time"
    let lastLogTime = UserDefaults.standard.double(forKey: lastLogKey)
    let elapsed = now.timeIntervalSince1970 - lastLogTime

    // Log every 30 seconds max
    if elapsed > 30 {
      UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastLogKey)
      print("📍 Location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
      print("   Accuracy: \(location.horizontalAccuracy)m, State: \(UIApplication.shared.applicationState.rawValue)")
      print("   Monitored regions: \(manager.monitoredRegions.count)")
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("❌ Location manager error: \(error.localizedDescription)")
  }

  // MARK: - Notifications

  func showGeofenceNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body

    // Use custom alarm sound or default sound
    // Note: Critical alerts require Apple approval, so we use time-sensitive instead
    content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.mp3"))

    if #available(iOS 15.0, *) {
      content.interruptionLevel = .timeSensitive
    }

    content.categoryIdentifier = "ALARM_CATEGORY"
    content.badge = 1

    // Use a consistent identifier so we can update/cancel if needed
    let request = UNNotificationRequest(identifier: "GEOFENCE_ALARM", content: content, trigger: nil)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("❌ Notification error: \(error)")
      } else {
        print("✅ Geofence notification sent (critical alert for lock screen)")
      }
    }
  }

  // This makes notifications show even when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show banner, sound, and badge even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // Handle notification action responses (when user taps "Stop Alarm")
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.actionIdentifier == "STOP_ALARM" {
      print("🛑 User tapped Stop Alarm")
      // Stop system sound first
      stopSystemSound()
      // Notify Flutter to stop the alarm sound
      methodChannel?.invokeMethod("stopAlarm", arguments: nil)
    }
    completionHandler()
  }

  // MARK: - iOS System Sounds (Background-safe)

  /// Play iOS system sound with looping - uses AVAudioPlayer for background support
  func playSystemSound(soundType: String, loop: Bool) {
    print("🔊 Playing iOS alarm sound: \(soundType), loop: \(loop)")
    print("   App state: \(UIApplication.shared.applicationState.rawValue) (0=active, 1=inactive, 2=background)")

    // Stop any existing sound first
    stopSystemSound()

    // CRITICAL: Configure audio session for background playback
    // This must be done BEFORE playing any audio
    do {
      let session = AVAudioSession.sharedInstance()

      // Register for audio session interruption notifications
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAudioSessionInterruption),
        name: AVAudioSession.interruptionNotification,
        object: session
      )

      // Use .playback category - this allows background audio
      // .mixWithOthers is removed to ensure our alarm takes priority
      try session.setCategory(.playback, mode: .default, options: [])
      try session.setActive(true, options: [])
      print("✅ Audio session configured for BACKGROUND playback")
      print("   - Category: \(session.category.rawValue)")
      print("   - Mode: \(session.mode.rawValue)")
      print("   - Is active: \(session.isOtherAudioPlaying)")
    } catch {
      print("❌ Audio session error: \(error)")
    }

    isPlayingAlarm = true

    // Start a background task to keep app alive for vibration
    if backgroundTaskId == .invalid {
      backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "AlarmSound") { [weak self] in
        print("⚠️ Background task expired")
        self?.stopVibrationLoop()
        if let taskId = self?.backgroundTaskId, taskId != .invalid {
          UIApplication.shared.endBackgroundTask(taskId)
          self?.backgroundTaskId = .invalid
        }
      }
      print("🔄 Started background task: \(backgroundTaskId.rawValue)")
    }

    // Find and play the alarm sound file
    // Use AVAudioPlayer with looping - this works in background unlike Timer-based approach
    if let soundURL = findAlarmSoundURL(for: soundType) {
      playAudioFileInBackground(url: soundURL, loop: loop)
    } else {
      // Fallback: use a bundled sound or system sound
      print("⚠️ Could not find sound file for: \(soundType), using system sound")
      playSystemSoundOnce()
    }

    // Start continuous vibration loop (works in background with DispatchSourceTimer)
    if loop {
      startVibrationLoop()
    } else {
      // Single vibration
      triggerVibration()
    }
  }

  /// Start continuous vibration using DispatchSourceTimer (background-safe)
  func startVibrationLoop() {
    // Stop any existing vibration timer
    stopVibrationLoop()

    print("📳 Starting background-safe vibration loop")

    // Create a DispatchSourceTimer - this works in background unlike Timer
    let queue = DispatchQueue.global(qos: .userInteractive)
    vibrationTimer = DispatchSource.makeTimerSource(queue: queue)
    // Match Android pattern: vibrate every 1 second (800ms vibrate + 200ms gap)
    vibrationTimer?.schedule(deadline: .now(), repeating: 1.0) // Vibrate every 1 second

    vibrationTimer?.setEventHandler { [weak self] in
      guard self?.isPlayingAlarm == true else {
        self?.stopVibrationLoop()
        return
      }
      // Vibrate on main thread - use multiple methods for reliability
      DispatchQueue.main.async {
        self?.triggerVibration()
      }
    }

    vibrationTimer?.resume()
    print("✅ Vibration loop started")

    // Trigger first vibration immediately
    triggerVibration()
  }

  /// Trigger vibration using multiple methods for reliability
  func triggerVibration() {
    // Method 1: Standard vibration (works on most devices)
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

    // Method 2: Alert sound with vibration (1352 = strong vibration pattern)
    AudioServicesPlaySystemSound(1352)

    // Method 3: Use haptic feedback for newer devices (iOS 10+)
    if #available(iOS 10.0, *) {
      let generator = UINotificationFeedbackGenerator()
      generator.prepare()
      generator.notificationOccurred(.warning)
    }

    print("📳 Vibration triggered")
  }

  /// Stop vibration loop
  func stopVibrationLoop() {
    vibrationTimer?.cancel()
    vibrationTimer = nil
    print("🛑 Vibration loop stopped")
  }

  /// Find the URL for alarm sound
  func findAlarmSoundURL(for soundType: String) -> URL? {
    print("🔍 Looking for alarm sound: \(soundType)")

    // Available MP3 files in assets/sounds/
    // alarm.mp3, digital_alarm.mp3, gentle_alarm.mp3, melody_alarm.mp3, urgent_alarm.mp3
    let soundFileName: String
    switch soundType {
    case "alarm":
      soundFileName = "alarm"
    case "digital", "digital_alarm":
      soundFileName = "digital_alarm"
    case "gentle", "gentle_alarm":
      soundFileName = "gentle_alarm"
    case "melody", "melody_alarm":
      soundFileName = "melody_alarm"
    case "urgent", "urgent_alarm":
      soundFileName = "urgent_alarm"
    default:
      soundFileName = "alarm" // Default fallback
    }

    // FIRST: Check Flutter assets folder in app bundle
    // Flutter assets are bundled at: Runner.app/Frameworks/App.framework/flutter_assets/
    if let flutterAssetsPath = Bundle.main.path(forResource: "flutter_assets", ofType: nil, inDirectory: "Frameworks/App.framework") {
      print("📂 Flutter assets path: \(flutterAssetsPath)")
      let soundPath = "\(flutterAssetsPath)/assets/sounds/\(soundFileName).mp3"
      if FileManager.default.fileExists(atPath: soundPath) {
        print("✅ Found sound in Flutter assets: \(soundFileName).mp3")
        return URL(fileURLWithPath: soundPath)
      }
    }

    // SECOND: Check app bundle directly (for sounds added to Xcode project)
    if let bundleURL = Bundle.main.url(forResource: soundFileName, withExtension: "mp3") {
      print("✅ Found sound in bundle: \(soundFileName).mp3")
      return bundleURL
    }

    // THIRD: Try to find any alarm sound in Flutter assets as fallback
    if let flutterAssetsPath = Bundle.main.path(forResource: "flutter_assets", ofType: nil, inDirectory: "Frameworks/App.framework") {
      let fallbackSounds = ["alarm.mp3", "urgent_alarm.mp3", "digital_alarm.mp3", "melody_alarm.mp3", "gentle_alarm.mp3"]
      for sound in fallbackSounds {
        let soundPath = "\(flutterAssetsPath)/assets/sounds/\(sound)"
        if FileManager.default.fileExists(atPath: soundPath) {
          print("✅ Found fallback sound: \(sound)")
          return URL(fileURLWithPath: soundPath)
        }
      }
    }

    print("⚠️ No sound file found for: \(soundType)")
    return nil
  }

  /// Play audio file with AVAudioPlayer - BACKGROUND SAFE with infinite looping
  func playAudioFileInBackground(url: URL, loop: Bool) {
    do {
      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.delegate = self
      audioPlayer?.numberOfLoops = loop ? -1 : 0 // -1 = infinite loop (works in background!)
      audioPlayer?.volume = 1.0
      audioPlayer?.prepareToPlay()

      let success = audioPlayer?.play() ?? false
      if success {
        print("✅ Audio playing in background: \(url.lastPathComponent), looping: \(loop), numberOfLoops: \(audioPlayer?.numberOfLoops ?? 0)")
      } else {
        print("❌ Failed to start audio playback")
        playSystemSoundOnce()
      }
    } catch {
      print("❌ Error creating audio player: \(error)")
      playSystemSoundOnce()
    }
  }

  /// AVAudioPlayerDelegate - handle audio playback events
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    print("🎵 Audio player finished: \(flag), isPlayingAlarm: \(isPlayingAlarm)")
    // This should NEVER be called when numberOfLoops = -1 (infinite)
    // If it is called, something went wrong - restart the audio
    if isPlayingAlarm {
      print("⚠️ Audio finished unexpectedly while alarm is active - restarting...")
      if let url = player.url {
        playAudioFileInBackground(url: url, loop: true)
      }
    }
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    print("❌ Audio decode error: \(error?.localizedDescription ?? "unknown")")
    // Try to restart
    if isPlayingAlarm, let url = player.url {
      print("🔄 Attempting to restart audio after decode error...")
      playAudioFileInBackground(url: url, loop: true)
    }
  }

  /// Play a single system sound (fallback, doesn't loop in background)
  func playSystemSoundOnce() {
    // Play the SMS sound - one of the loudest built-in sounds
    AudioServicesPlayAlertSound(1005)
    triggerVibration()
    print("🔔 Played system alert sound (one-shot)")
  }

  /// Stop playing system sound
  func stopSystemSound() {
    print("🛑 Stopping iOS system sound")

    isPlayingAlarm = false

    // Stop vibration loop
    stopVibrationLoop()

    // Stop timer (legacy, may not be used)
    alarmTimer?.invalidate()
    alarmTimer = nil

    // Stop audio player
    if let player = audioPlayer {
      player.stop()
      audioPlayer = nil
      print("✅ Audio player stopped")
    }

    // Remove audio session interruption observer
    NotificationCenter.default.removeObserver(
      self,
      name: AVAudioSession.interruptionNotification,
      object: nil
    )

    // Deactivate audio session
    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      print("✅ Audio session deactivated")
    } catch {
      print("⚠️ Error deactivating audio session: \(error)")
    }

    // End background task
    if backgroundTaskId != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTaskId)
      backgroundTaskId = .invalid
      print("✅ Background task ended")
    }
  }

  /// Handle audio session interruptions (calls, alarms, etc.)
  @objc func handleAudioSessionInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }

    print("🔔 Audio session interruption: \(type == .began ? "BEGAN" : "ENDED")")

    switch type {
    case .began:
      // Interruption began (e.g., phone call)
      print("⚠️ Audio interrupted - will resume when interruption ends")

    case .ended:
      // Interruption ended - resume playback if alarm is still active
      if isPlayingAlarm {
        print("🔄 Interruption ended - resuming alarm playback")
        do {
          // Reactivate audio session
          try AVAudioSession.sharedInstance().setActive(true, options: [])
          // Resume audio player
          audioPlayer?.play()
          print("✅ Audio resumed after interruption")
        } catch {
          print("❌ Failed to resume audio: \(error)")
        }
      }

    @unknown default:
      break
    }
  }
}
