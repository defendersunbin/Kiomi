// ios/Runner/OcrHandler.swift
//
// Apple Vision 프레임워크를 이용한 네이티브 OCR
// - arm64 포함 모든 아키텍처 지원
// - 한국어 자동 인식
// - 빠른 온디바이스 처리

import Foundation
import Vision
import UIKit

class OcrHandler {
    
    static func recognizeText(imagePath: String, completion: @escaping ([String: Any]?) -> Void) {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let imageWidth = cgImage.width
        let imageHeight = cgImage.height
        
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            var blocks: [[String: Any]] = []
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                
                let text = topCandidate.string
                let boundingBox = observation.boundingBox
                
                // Vision의 좌표계: 좌하단 원점, 0~1 정규화
                // → 좌상단 원점 픽셀 좌표로 변환
                let left = boundingBox.origin.x * Double(imageWidth)
                let top = (1.0 - boundingBox.origin.y - boundingBox.height) * Double(imageHeight)
                let right = (boundingBox.origin.x + boundingBox.width) * Double(imageWidth)
                let bottom = (1.0 - boundingBox.origin.y) * Double(imageHeight)
                
                blocks.append([
                    "text": text,
                    "left": left,
                    "top": top,
                    "right": right,
                    "bottom": bottom,
                    "confidence": topCandidate.confidence
                ])
            }
            
            let result: [String: Any] = [
                "blocks": blocks,
                "imageWidth": imageWidth,
                "imageHeight": imageHeight
            ]
            
            completion(result)
        }
        
        // 한국어 + 영어 인식 설정
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.recognitionLevel = .accurate  // .fast로 변경하면 더 빠름
        request.usesLanguageCorrection = true
        
        // iOS 16+에서는 자동 언어 감지 지원
        if #available(iOS 16.0, *) {
            request.automaticallyDetectsLanguage = true
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Vision OCR error: \(error)")
                completion(nil)
            }
        }
    }
}
