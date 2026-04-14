## Android 설정 (필수)

### 1. android/app/build.gradle.kts (또는 build.gradle)

```kotlin
android {
    // compileSdk는 flutter create가 자동 설정
    
    defaultConfig {
        applicationId = "com.yourname.kioskhelper"
        minSdk = 23          // ← 반드시 23 이상 (ML Kit 요구)
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }
}
```

### 2. android/app/src/main/AndroidManifest.xml

`<manifest>` 태그 바로 안에 추가:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### 3. android/app/src/main/AndroidManifest.xml (ML Kit 모델 자동 다운로드)

`<application>` 태그 안에 추가:

```xml
<meta-data
    android:name="com.google.mlkit.vision.DEPENDENCIES"
    android:value="ocr_korean"/>
```

이렇게 하면 앱 설치 시 한국어 OCR 모델이 자동으로 다운로드됩니다.

---

## iOS 설정 (macOS에서만 가능)

### 1. ios/Runner/Info.plist

`<dict>` 안에 추가:

```xml
<key>NSCameraUsageDescription</key>
<string>키오스크 화면을 스캔하기 위해 카메라가 필요합니다</string>

<key>NSMicrophoneUsageDescription</key>
<string>음성으로 메뉴를 입력하기 위해 마이크가 필요합니다</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>음성 인식을 위해 필요합니다</string>
```

### 2. ios/Podfile

최상단에 iOS 최소 버전 설정:

```ruby
platform :ios, '15.0'
```

그 후:

```bash
cd ios
pod install
cd ..
```

---

## 첫 실행 체크리스트

- [ ] Flutter 설치 완료 (`flutter doctor` 전부 ✓)
- [ ] Android Studio + Android SDK 설치
- [ ] `flutter create kiosk_helper` 실행
- [ ] 이 프로젝트의 `lib/` 폴더로 교체
- [ ] 이 프로젝트의 `pubspec.yaml`로 교체
- [ ] `flutter pub get` 실행
- [ ] `android/app/build.gradle.kts`에서 minSdk = 23 설정
- [ ] `AndroidManifest.xml`에 카메라/마이크 권한 추가
- [ ] 실제 Android 폰 USB 연결
- [ ] 폰에서 "개발자 옵션" → "USB 디버깅" 활성화
- [ ] `flutter run` 실행
