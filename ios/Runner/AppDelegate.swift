import Flutter
import UIKit
import GoogleMaps
import CoreLocation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  let locationManager = CLLocationManager()
  var methodChannel: FlutterMethodChannel?

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
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 10

    // Configure notification center for foreground and background notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self

      // Request notification permissions with critical alert (for alarm sounds on lock screen)
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
        if granted {
          print("✅ Notification permissions granted (including critical alerts)")
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
          self.startGeofenceMonitoring(id: id, latitude: lat, longitude: lng, radius: radius, name: name)
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

  // MARK: - Native iOS Geofencing

  func startGeofenceMonitoring(id: String, latitude: Double, longitude: Double, radius: Double, name: String) {
    // iOS minimum radius is 100m, but 200m is recommended for reliability
    let effectiveRadius = max(radius, 200.0)

    let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    let region = CLCircularRegion(center: center, radius: effectiveRadius, identifier: id)
    region.notifyOnEntry = true
    region.notifyOnExit = false

    // Store alarm name in UserDefaults for notification
    UserDefaults.standard.set(name, forKey: "geofence_name_\(id)")

    locationManager.startMonitoring(for: region)
    print("📍 Native iOS geofence started: \(name) at \(latitude), \(longitude) radius: \(effectiveRadius)m")
  }

  func stopGeofenceMonitoring(id: String) {
    for region in locationManager.monitoredRegions {
      if region.identifier == id {
        locationManager.stopMonitoring(for: region)
        UserDefaults.standard.removeObject(forKey: "geofence_name_\(id)")
        print("🛑 Native iOS geofence stopped: \(id)")
        break
      }
    }
  }

  func stopAllGeofenceMonitoring() {
    for region in locationManager.monitoredRegions {
      locationManager.stopMonitoring(for: region)
      UserDefaults.standard.removeObject(forKey: "geofence_name_\(region.identifier)")
    }
    print("🛑 All native iOS geofences stopped")
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    print("🎯🎯🎯 NATIVE iOS GEOFENCE ENTERED: \(region.identifier)")

    let alarmName = UserDefaults.standard.string(forKey: "geofence_name_\(region.identifier)") ?? "Location Alarm"

    // Show notification
    showGeofenceNotification(title: "⏰ \(alarmName)", body: "You have arrived at your destination!")

    // Notify Flutter
    methodChannel?.invokeMethod("onGeofenceEntered", arguments: ["id": region.identifier, "name": alarmName])
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    print("🚪 Native iOS geofence exited: \(region.identifier)")
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
    switch state {
    case .inside:
      print("📍 Already inside geofence: \(region.identifier)")
      // Trigger immediately if already inside
      locationManager(manager, didEnterRegion: region)
    case .outside:
      print("📍 Currently outside geofence: \(region.identifier)")
    case .unknown:
      print("📍 Unknown state for geofence: \(region.identifier)")
    @unknown default:
      break
    }
  }

  // MARK: - Notifications

  func showGeofenceNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body

    // Use default critical sound for maximum reliability on lock screen
    // Critical alerts bypass Do Not Disturb and silent mode
    if #available(iOS 12.0, *) {
      content.sound = UNNotificationSound.defaultCritical
    } else {
      content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm.mp3"))
    }

    if #available(iOS 15.0, *) {
      content.interruptionLevel = .critical
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
      // Notify Flutter to stop the alarm sound
      methodChannel?.invokeMethod("stopAlarm", arguments: nil)
    }
    completionHandler()
  }
}
