import UIKit
import Flutter
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var gainNode: AVAudioUnitEQ?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let audioChannel = FlutterMethodChannel(name: "com.soyo.audio/boost",
                                                binaryMessenger: controller.binaryMessenger)
        
        audioChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard let self = self else { return }
            
            switch call.method {
            case "initAudioBoost":
                self.initAudioBoost(result: result)
            case "setAudioBoost":
                if let args = call.arguments as? [String: Any],
                   let multiplier = args["multiplier"] as? Double {
                    self.setAudioBoost(multiplier: multiplier, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }
            case "releaseAudioBoost":
                self.releaseAudioBoost(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func initAudioBoost(result: @escaping FlutterResult) {
        do {
            audioEngine = AVAudioEngine()
            playerNode = AVAudioPlayerNode()
            
            // Create EQ node for gain control
            gainNode = AVAudioUnitEQ(numberOfBands: 1)
            gainNode?.bands[0].frequency = 1000 // Center frequency
            gainNode?.bands[0].bandwidth = 2.0
            gainNode?.bands[0].bypass = false
            gainNode?.globalGain = 0 // Start at 0 dB
            
            if let engine = audioEngine, let player = playerNode, let gain = gainNode {
                engine.attach(player)
                engine.attach(gain)
                
                engine.connect(player, to: gain, format: nil)
                engine.connect(gain, to: engine.mainMixerNode, format: nil)
                
                try engine.start()
            }
            
            result(true)
        } catch {
            result(FlutterError(code: "INIT_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func setAudioBoost(multiplier: Double, result: @escaping FlutterResult) {
        // Convert multiplier to dB
        // 2x = +6 dB, 3x = +9.5 dB, 4x = +12 dB
        let gainDB: Float
        switch multiplier {
        case ...1.0:
            gainDB = 0
        case 1.0..<2.0:
            gainDB = Float((multiplier - 1.0) * 6.0)
        case 2.0..<3.0:
            gainDB = Float(6.0 + (multiplier - 2.0) * 3.5)
        case 3.0..<4.0:
            gainDB = Float(9.5 + (multiplier - 3.0) * 2.5)
        default:
            gainDB = 12.0
        }
        
        gainNode?.globalGain = gainDB
        result(true)
    }
    
    private func releaseAudioBoost(result: @escaping FlutterResult) {
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        gainNode = nil
        result(true)
    }
}