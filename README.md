# 📱 Rayworks Reels Studio - Android Mobile App

인스타그램 릴스 제작 자동화 솔루션 **Rayworks Reels Studio**의 순수 안드로이드 모바일 앱 프로젝트입니다.  
PC 없이 스마트폰(삼성 갤럭시 등 안드로이드) 자체에서 **10개 영상 일괄 제작, Gemini AI 3단어 제목 추천, 한·일 이원화 1080x1920 템플릿 합성, 인스타 알고리즘 우회 데이터 변조**를 모두 수행합니다.

---

## 🚀 GitHub Actions를 통한 무료 3분 클라우드 APK 빌드 방법

PC에 20GB짜리 안드로이드 스튜디오나 Java를 설치할 필요가 전혀 없습니다!  
GitHub의 무료 클라우드 서버가 3분 만에 컴파일하여 스마트폰 설치용 `.apk`를 만들어 줍니다.

### 1단계: GitHub 새 저장소(Repository) 만들기
1. [github.com](https://github.com)에 로그인합니다.
2. 우측 상단 **[+]** 버튼 -> **[New repository]** 클릭
3. 저장소 이름(Repository name)에 `reels-studio-android` 입력
4. 공개 설정(Public 또는 Private 모두 가능) 선택 후 **[Create repository]** 클릭

### 2단계: 프로젝트 코드 업로드
이 `android_app` 폴더 안의 모든 파일과 폴더(`.github`, `android`, `lib`, `assets`, `pubspec.yaml` 등)를 생성한 GitHub 저장소에 업로드합니다.

* **Git 명령어로 올릴 경우**:
```bash
cd android_app
git init
git add .
git commit -m "Initial commit for Rayworks Reels Studio Mobile"
git branch -M main
git remote add origin https://github.com/당신의아이디/reels-studio-android.git
git push -u origin main
```

### 3단계: 클라우드 자동 빌드 시작 (클릭 한 번)
1. 깃허브 저장소 상단의 **[Actions]** 탭을 클릭합니다.
2. 좌측 워크플로우 목록에서 **[Build Android APK (Release)]**를 선택합니다.
3. 우측의 **[Run workflow]** 버튼을 클릭합니다.
4. 마이크로소프트 클라우드 서버가 자동으로 Java 17, Flutter 3.24, Android SDK를 켜고 약 **3~4분** 동안 컴파일을 진행합니다.

### 4단계: 갤럭시 스마트폰에 설치하기
1. 작업이 끝나고 초록색 체크표시(✅)가 뜨면 해당 작업 이름을 클릭합니다.
2. 화면 맨 아래 **[Artifacts]** 섹션에 있는 **`RayworksReelsStudio-v1.0.0`**를 클릭하여 다운로드합니다.
3. 압축을 풀면 나오는 **`app-release.apk`** 파일을 갤럭시 스마트폰에서 열고 **[설치]**를 누르면 끝!

---

## 🛠️ 주요 모바일 기능 안내

1. **갤러리 일괄 불러오기**:
   - 폰 갤러리에서 다운받아둔 릴스/쇼츠 영상을 최대 10개까지 한 번에 선택하여 슬롯에 등록합니다.
2. **Gemini AI 바이럴 추천**:
   - 상단 `[🇰🇷 한국어]` / `[🇯🇵 日本語]` 모드에 맞춰 인스타 14~18자 킬러 후크 제목과 5단계 매거진 피드 본문을 자동 생성합니다.
3. **한·일 이원화 인스타 알고리즘 우회 변조**:
   - 🇰🇷 한국판: 미세 가속(1.03x), 중앙 줌, 핑크 노이즈, 대비/채도 보정
   - 🇯🇵 일본판: 미세 감속(0.98x), 대각 편향 줌, 브라운 노이즈, 감마/선명도 보정
4. **갤러리 즉시 저장 및 공유**:
   - 렌더링 완료 즉시 폰의 `DCIM/Reels` 폴더에 MP4 파일이 저장되며, 인스타그램 앱으로 즉시 공유 가능합니다.
