import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // 플러그인 등록을 채널 설정보다 먼저 해주는 것이 더 안정적입니다.
        GeneratedPluginRegistrant.register(with: self)
        
        // 🚨 수정된 부분: 강제 언래핑(as!) 대신 안전하게 값이 있을 때만 실행(if let)
        if let controller = window?.rootViewController as? FlutterViewController {
            
            // ── OCR MethodChannel ──
            let ocrChannel = FlutterMethodChannel(
                name: "com.kioskhelper/ocr",
                binaryMessenger: controller.binaryMessenger
            )
            
            ocrChannel.setMethodCallHandler { (call, result) in
                if call.method == "recognizeText" {
                    guard let args = call.arguments as? [String: Any],
                          let imagePath = args["imagePath"] as? String else {
                        result(FlutterError(code: "INVALID_ARGS", message: "imagePath required", details: nil))
                        return
                    }
                    
                    OcrHandler.recognizeText(imagePath: imagePath) { ocrResult in
                        DispatchQueue.main.async {
                            result(ocrResult)
                        }
                    }
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
