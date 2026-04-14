# 키오스크 도우미 — 실제 OCR + 음성 입력 설정 가이드

## 1. pubspec.yaml 의존성

```yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.11.0+2
  path_provider: ^2.1.4
  speech_to_text: ^7.0.0
  flutter_tts: ^4.0.0
  permission_handler: ^11.3.1
```

**참고:** `google_mlkit_text_recognition`은 pubspec에 추가하지 않음.
- iOS: Apple Vision (네이티브, 추가 패키지 불필요)
- Android: ML Kit (build.gradle에서 직접 의존성 추가)


## 2. iOS 설정

### ios/Runner/Info.plist — 권한 추가
```xml
<key>NSCameraUsageDescription</key>
<string>키오스크 화면을 스캔하기 위해 카메라가 필요합니다.</string>
<key>NSMicrophoneUsageDescription</key>
<string>음성으로 메뉴를 말씀하시면 인식합니다.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>음성 인식을 위해 권한이 필요합니다.</string>
```

### 파일 배치
1. `ios/Runner/OcrHandler.swift` → 프로젝트에 추가
2. `ios/Runner/AppDelegate.swift` → 기존 파일 교체

### Xcode에서 OcrHandler.swift 추가
Xcode > Runner 폴더 우클릭 > "Add Files to Runner" > OcrHandler.swift 선택
(Target Membership: Runner 체크)


## 3. Android 설정

### android/app/build.gradle — ML Kit 의존성 추가
```groovy
dependencies {
    // 기존 의존성...
    
    // ML Kit 한국어 텍스트 인식
    implementation 'com.google.mlkit:text-recognition-korean:16.0.1'
}

android {
    // minSdkVersion 21 이상 필요
    defaultConfig {
        minSdkVersion 21
    }
}
```

### android/app/src/main/AndroidManifest.xml — 권한
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

### 파일 배치
`MainActivity.kt` → `android/app/src/main/kotlin/com/example/kiosk_helper/MainActivity.kt`
(패키지명이 다르면 파일 상단의 package 선언 수정)


## 4. 프로젝트 파일 구조 (최종)

```
lib/
  main.dart
  screens/
    home_screen.dart          # 메뉴 선택 화면
    scan_screen.dart          # 자동 연속 스캔 화면
  services/
    ocr_service.dart          # MethodChannel 기반 OCR
    voice_guide_service.dart  # TTS 음성 안내
  models/
    scan_result.dart          # OCR 결과 모델
    set_menu_detector.dart    # 메뉴 분류/세트 감지
  widgets/
    guide_overlay.dart        # 바운딩 박스 오버레이

ios/Runner/
  AppDelegate.swift           # MethodChannel 등록
  OcrHandler.swift            # Apple Vision OCR

android/app/src/main/kotlin/.../
  MainActivity.kt             # MethodChannel + ML Kit OCR
```


## 5. 동작 원리

### OCR 흐름
1. `scan_screen.dart`: 1.5초마다 카메라 캡처 → 임시 파일 저장
2. `ocr_service.dart`: MethodChannel로 네이티브 호출
3. iOS → `OcrHandler.swift`: Apple Vision이 이미지 분석
   Android → `MainActivity.kt`: ML Kit이 이미지 분석
4. 결과(텍스트 + 바운딩박스) → Dart로 반환
5. `_findMatches()`: 사용자 키워드와 매칭
6. `guide_overlay.dart`: 매칭된 위치에 빨간 박스 표시

### 음성 입력 흐름
1. `home_screen.dart`: "말하기" 버튼 → `speech_to_text` 패키지
2. 기기 마이크로 한국어 음성 인식 (localeId: 'ko_KR')
3. 인식된 텍스트 → 키워드로 분리 → 메뉴 선택에 추가

### 음성 안내 (TTS) 흐름
1. 매칭 발견 시 `voice_guide_service.dart`가 안내
2. "빅맥을 찾았습니다. 표시된 곳을 눌러주세요."
3. 느린 속도 (0.4) + 최대 볼륨으로 어르신도 잘 들을 수 있음
```
