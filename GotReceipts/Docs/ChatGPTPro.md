Awesome — here are **both files** ready to paste into your repo. I used your app name **GotReceipts** throughout.

---

### `FullPlanReadMe.md`

````markdown
# GotReceipts — Full Plan (1–19)

This is the complete, opinionated build plan for **GotReceipts**, the three-step receipt capture app (“tap → snap → speak”). It specifies the iOS implementation (Swift/SwiftUI), on-device OCR + speech + NLP, a minimal cloud backend, and a QuickBooks Online (QBO) integration designed to maximize downstream auto-matching.

---

## 0) What “great” looks like (MVP scope)

**Three steps only:**
1. **Tap** app icon → opens **directly to the receipt scanner**.
2. **Snap** the receipt (auto-detect edges, auto-crop).
3. **Speak** a short description (fallback to typing).  
   Example: *“Dinner at Joe’s Diner with Maya about Q1 marketing plan for ElectroSpit.”*

**Background work (no extra taps):**
- OCR extracts merchant, total, date (and last4 if present).
- App tags **location** and timestamp.
- Speech is transcribed; NLP parses payee, attendees, purpose, company/project (“ElectroSpit”), category hints (“Meals”), optional payment method (Visa/Amex/Apple Pay/Cash).
- **Image + structured record** are saved to a cloud DB.
- Server creates a **QBO Expense/Purchase** and **attaches the receipt** to maximize QBO’s auto-match with bank feeds. Any misses are already categorized, minimizing human review.

---

## 1) Architecture (recommended choices)

- **Client (iOS 17+)**: SwiftUI; **VisionKit** document camera; **Vision** OCR; **Speech** transcription; **NaturalLanguage** NLP; **CoreLocation**; **BackgroundTasks** for uploads; **App Intents** + **Home Screen Quick Action**.
- **Backend** (fastest path): **Firebase** — Auth (anonymous), Firestore (metadata), Storage (images), Cloud Functions (post-processing + QBO).  
  _Alt_: **Supabase** (Postgres + Storage + RLS) with Swift SDK.
- **Accounting**: **QuickBooks Online** — OAuth 2.0; create Expense/Purchase; upload **Attachable** and link to transaction.

> Note: QBO’s “For review” bank feed isn’t exposed via public API. The reliable pattern is to create the Expense/Purchase with correct vendor/date/amount and attach the receipt so QBO can auto-match when the feed arrives.

---

## 2) Data model (Firestore or Supabase)

**Collection:** `receipts`  
**Document example:**
```json
{
  "id": "auto",
  "createdAt": "2025-09-26T04:12:00Z",
  "deviceId": "ios:…",
  "userType": "initiator",
  "companyKey": "electrospit",
  "status": "new|parsed|queued|pushed|error",

  "imagePath": "gs://.../receipts/2025/09/26/abc.jpg",
  "ocrText": "JOE'S DINER ... TOTAL 48.76 ... 04/11/2025 ...",
  "geo": { "lat": 37.77, "lng": -122.42, "accuracyM": 25 },
  "photoTimestamp": "2025-04-11T19:24:55-07:00",

  "speech": "Dinner at Joe's Diner with Maya about Q1 marketing plan for ElectroSpit",
  "parsed": {
    "merchant": "Joe's Diner",
    "amount": 48.76,
    "currency": "USD",
    "date": "2025-04-11",
    "paymentMethod": "Visa •1234",
    "categoryHint": "Meals",
    "purpose": "Q1 marketing plan",
    "attendees": ["Maya"],
    "projectOrCompany": "ElectroSpit",
    "locationName": "Joe's Diner, SF CA"
  },

  "qbo": {
    "realmId": "1234567890",
    "vendorRef": { "id": "42", "name": "Joe's Diner" },
    "expenseCategory": { "accountRefId": "MealsID" },
    "attachableId": null,
    "txnId": null
  }
}
````

---

## 3) iOS app: end-to-end steps

### 3.1 Repo & Xcode setup

* Create GitHub repo: `GotReceipts`.
* Xcode → **App** template (SwiftUI, Swift, iOS 17+).
* Set Bundle ID, Team, Automatic Signing.
* Add packages (SPM): Firebase (Firestore, Storage, Auth) or Supabase SDK.
* **Info.plist** usage strings:

  * `NSCameraUsageDescription`
  * `NSMicrophoneUsageDescription`
  * `NSSpeechRecognitionUsageDescription`
  * `NSLocationWhenInUseUsageDescription`
* Capabilities: **Background Modes** (fetch, processing). Register **BGTaskScheduler**.

### 3.2 Launch directly to the camera

* First screen = **VisionKit** `VNDocumentCameraViewController` wrapped for SwiftUI. Edge detect + crop.

### 3.3 Quick Action + Siri

* **Home Screen Quick Action**: “Scan Receipt”.
* **App Shortcut** with **App Intents**: “Log receipt”.

### 3.4 OCR the image

* **Vision** `VNRecognizeTextRequest` with `.accurate`.
* Extract **amount** with regex on “TOTAL/AMOUNT”.
* **NSDataDetector** to find **dates**; prefer OCR date near photo timestamp.

### 3.5 Speech to text

* **SFSpeechRecognizer** streaming; show live transcript in a single text field (user can fix a word quickly).

### 3.6 Parse the transcript to structure

* **NLTagger** (nameType) for people/org/place.
* Simple patterns: “with {Person}”, “about/for {Purpose}”, “at {Merchant}”.
* Payment method tokens: Visa/Amex/Apple Pay/Cash + last4.

### 3.7 Location & timestamp

* **CoreLocation** While-In-Use; optional reverse-geocode for place label.

### 3.8 Save offline, upload in background

* Local queue; optimistic UI (“Saved” toast).
* `BGProcessingTask` uploads image → Storage and JSON → Firestore; retries with backoff.

### 3.9 Minimal “nag”

* Only if amount/date missing or vendor ambiguous; one small sheet with a single field.

---

## 4) iOS code snippets (starter)

### 4.1 VisionKit scanner wrapper (SwiftUI)

```swift
import SwiftUI
import VisionKit

struct DocumentScannerView: UIViewControllerRepresentable {
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onImages: ([UIImage]) -> Void
        init(onImages: @escaping ([UIImage]) -> Void) { self.onImages = onImages }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            var images = [UIImage]()
            for i in 0..<scan.pageCount { images.append(scan.imageOfPage(at: i)) }
            controller.dismiss(animated: true) { self.onImages(images) }
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
    let onImages: ([UIImage]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onImages: onImages) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
}
```

### 4.2 OCR with Vision

```swift
import Vision

func recognizeText(in image: CGImage) async throws -> [String] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["en-US"]
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])
    let texts = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    return texts
}
```

### 4.3 Date detection from OCR text

```swift
import Foundation

func detectDates(in text: String) -> [Date] {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return [] }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return detector.matches(in: text, options: [], range: range)
        .compactMap { $0.date }
}
```

### 4.4 NER with NaturalLanguage (attendees, payee, org)

```swift
import NaturalLanguage

func extractEntities(from text: String) -> (people: [String], orgs: [String], places: [String]) {
    let tagger = NLTagger(tagSchemes: [.nameType])
    tagger.string = text
    var people = [String](), orgs = [String](), places = [String]()
    let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
    tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
        guard let tag = tag else { return true }
        let token = String(text[range])
        switch tag {
        case .personalName: people.append(token)
        case .organizationName: orgs.append(token)
        case .placeName: places.append(token)
        default: break
        }
        return true
    }
    return (Array(Set(people)), Array(Set(orgs)), Array(Set(places)))
}
```

---

## 5) Backend: Firebase (quick path)

* Create Firebase project; enable **Auth** (Anonymous), **Firestore**, **Storage**.
* iOS app uses Anonymous Auth to avoid visible login for initiators.
* Upload: image → **Storage**; metadata → **Firestore** (`receipts/{docId}`).
* **Cloud Functions**:

  * Firestore trigger on `receipts` to normalize, run heuristics, and call QBO APIs.
  * QBO OAuth endpoints (authorization code + token refresh).
  * Attachable upload (multipart) → get `Attachable.Id`.
  * Create **Expense/Purchase** with `Vendor`, `TxnDate`, `TotalAmt`, `AccountRef` (category), `Memo` (purpose + attendees).
  * Link the Attachable to the transaction.
  * Update Firestore with `qbo.txnId`, `qbo.attachableId`, `status="pushed"`.

*Alternative backend*: Supabase (Postgres/Storage) with Row Level Security; analogous flow.

---

## 6) Matching logic (your rules, then QBO’s)

* **Txn type**:

  * If OCR shows card (“VISA …”): **Purchase** (Credit).
  * If “Cash”: **Expense**.
* **Vendor normalization**: strip punctuation/legal suffixes; fuzzy match existing QBO vendors; create if needed.
* **Date window**: prefer OCR date; fallback to photo timestamp; allow ±2 days tolerance.
* **Amount precision**: match to 2 decimals; if tax rounding weird, allow ±$0.01.
* **Memo**: “Purpose: … | Attendees: … | Source: GotReceipts”.

---

## 7) Security & privacy checklist

* All traffic over HTTPS.
* Storage & DB access via server rules; role-based (initiator vs. bookkeeper).
* Redact PANs to **last4** if OCR finds card numbers.
* Show a small location consent banner; allow disabling location tagging.
* Hard-delete image + metadata on receipt deletion.

---

## 8) UX details (keep it to 3 steps)

* No visible login on mobile (Anonymous Auth + invite deep link maps device to `companyKey`).
* One primary screen: camera → “Use Photo” → mic auto-starts; transcript field visible for quick fix.
* Only “nag” for missing amount/date/vendor; single-field micro-sheet.
* Offline-first: queue locally; show “Saved. Uploading in background.”

---

## 9) Git & project structure

```
/GotReceipts
  /iOS
    GotReceiptsApp.swift
    Scanner/
      DocumentScannerView.swift
      OCRService.swift
    Speech/
      SpeechRecognizer.swift
    NLP/
      ReceiptParser.swift
    Data/
      Models.swift
      UploadQueue.swift
      FirestoreService.swift
    Location/
      LocationService.swift
    Background/
      BGTasks.swift
    UI/
      CaptureFlowView.swift
      ConfirmTinySheet.swift
  /server
    functions/
      index.ts
      qbo/
        oauth.ts
        vendors.ts
        expenses.ts
        attachable.ts
      firestoreTriggers.ts
    .env.example
  /docs
    FullPlanReadMe.md
    README.md
```

---

## 10) Step-by-step build plan (phased)

### Phase A — iOS capture (2–3 days)

1. Project + entitlements (camera/mic/speech/location/background).
2. Scanner screen (VisionKit) as initial view.
3. OCR pipeline; extract amount/date (Vision + NSDataDetector).
4. Speech recognizer; live transcript with quick edit.
5. NLP pass (NLTagger + regex) to fill merchant/attendees/purpose/org.
6. Location capture; optional reverse-geocode.
7. Queue & background upload (BGTasks).
8. Quick Action + App Shortcut.

**Acceptance:** Cold start → “Saved” in ≤10s on normal network; offline works.

### Phase B — Backend MVP (2–3 days)

1. Firebase: Auth (Anonymous), Firestore, Storage.
2. Upload image + metadata; security rules by `companyKey` and role.
3. Cloud Function trigger for normalization and queuing QBO push.
4. Minimal web console (optional): list/search/CSV.

### Phase C — QBO integration (2–4 days)

1. Intuit Developer app; OAuth 2.0 (authorization code + refresh).
2. Attachable upload tested with sandbox.
3. Create Purchase/Expense; link Attachable.
4. Idempotency (hash on image or merchant+date+amount).

**Acceptance:** New receipt → visible QBO transaction with correct vendor/date/amount and attached receipt.

### Phase D — Quality & nagging (1–2 days)

* Add tiny verifications for missing fields.
* Local notifications to complete missing info (single tap).

---

## 11) QuickBooks specifics (server)

* **OAuth 2.0**: store refresh tokens per `realmId`.
* **Attachable**: multipart upload image; get `Attachable.Id`; link to created transaction.
* **Purchase/Expense**: choose payment type (Credit/Cash/Check), set `EntityRef` (Vendor), `AccountRef` (category), `TxnDate`, `TotalAmt`, `Memo`.

---

## 12) Example parsing

Input: *“Dinner at Joe’s Diner with Maya about Q1 marketing plan for ElectroSpit.”*
Result:

* merchant: Joe’s Diner (NLP + OCR cross-check)
* categoryHint: Meals
* attendees: [Maya]
* purpose: Q1 marketing plan
* projectOrCompany: ElectroSpit
* date: from OCR (fallback photo time)
* amount: OCR “TOTAL …”

---

## 13) Info.plist keys (copy text)

* `NSCameraUsageDescription` = “We use the camera to scan your receipt.”
* `NSMicrophoneUsageDescription` = “We use the microphone so you can dictate the details.”
* `NSSpeechRecognitionUsageDescription` = “We transcribe your voice description.”
* `NSLocationWhenInUseUsageDescription` = “We tag the receipt with where/when you made the purchase.”

---

## 14) Edge cases & fallbacks

* Long/crinkled receipts: allow multi-page scan; merge OCR.
* No signal: queue persists; background upload later.
* Cash tips: micro-prompt “+ tip” if spoken amount ≠ OCR total.
* Ambiguous vendor: show top 3 past vendors near current location.

---

## 15) Bookkeeper / software access

* Web dashboard with email or magic-link login; list, filter, export; deep links to QBO transaction.
* Share single-receipt links with expiration (auditors).

---

## 16) Testing checklist

* 20 real receipts across categories (meals, rideshare, fuel, tolls, hardware).
* Lighting variations; with/without speech; offline test.
* Amount/date accuracy ≥ 98% (others get a nag).
* QBO record created and receipt attached promptly after upload.

---

## 17) Optional enhancements (later)

* Action Button shortcut on supported iPhones to launch scanner.
* Contacts integration for attendee autocomplete.
* Auto-select company by transcript hints.
* Rules engine for merchant → category/class/customer mappings.

---

## 18) Clarifications

* “Entity was the highway” interpreted as: capture **which business entity/company** the expense belongs to → mapped to QBO `realmId` via `companyKey` (device-to-company mapping + transcript hints).
* Payment method is inferred from OCR/transcript; fallback to your default per company.

---

## 19) What to hand to your AI coding assistant (“Alex”)

* Seed it with the code in **§4.1–4.4**.
* Tasks:

  1. Implement `ReceiptParser` merging OCR + speech.
  2. Wire Firebase upload (Storage + Firestore with Codable).
  3. Add BG task with retry/backoff.
  4. Add App Intent “Log Receipt” with optional voice params.

````

---

### `README.md` (checklist)

```markdown
# GotReceipts — Build Checklist

A short, copy-paste checklist to drive the MVP.

## Phase A — iOS Capture

- [ ] Create repo `GotReceipts`; Xcode SwiftUI app (iOS 17+).
- [ ] Add Firebase SPM (or Supabase) packages.
- [ ] Capabilities & Info.plist:
  - [ ] Camera, Microphone, Speech Recognition, Location (When-In-Use)
  - [ ] Background Modes (fetch, processing)
  - [ ] `NSCameraUsageDescription`
  - [ ] `NSMicrophoneUsageDescription`
  - [ ] `NSSpeechRecognitionUsageDescription`
  - [ ] `NSLocationWhenInUseUsageDescription`
- [ ] Root view = **VisionKit** scanner (opens on launch).
- [ ] OCR pipeline (Vision) → extract **amount**/**date** (regex + NSDataDetector).
- [ ] Speech input (SFSpeechRecognizer) → live transcript field (editable).
- [ ] NLP (NLTagger) → merchant, attendees, purpose, company hint.
- [ ] CoreLocation capture (optional reverse-geocode).
- [ ] Local queue + toast “Saved”; `BGProcessingTask` for uploads.
- [ ] Home Screen Quick Action “Scan Receipt”; App Intent “Log receipt”.

## Phase B — Backend MVP

- [ ] Firebase project created; enable **Auth (Anonymous)**, **Firestore**, **Storage**.
- [ ] iOS anonymous sign-in working (no visible login).
- [ ] Upload flow:
  - [ ] Image → Storage at `receipts/YYYY/MM/{docId}.jpg`
  - [ ] Metadata → Firestore `receipts/{docId}`
- [ ] Security rules (role-based: initiator/bookkeeper) keyed by `companyKey`.
- [ ] Cloud Functions skeleton + env (`.env.example`).

## Phase C — QuickBooks Online Integration

- [ ] Intuit Developer app + OAuth 2.0 (authorization code + refresh).
- [ ] Store refresh token per `realmId`.
- [ ] **Attachable** upload endpoint (multipart) → `Attachable.Id`.
- [ ] Create **Expense/Purchase** with Vendor, AccountRef (category), TxnDate, TotalAmt, Memo.
- [ ] Link Attachable to the transaction.
- [ ] Idempotency: hash(image) or (merchant+date+amount).
- [ ] Update Firestore: `qbo.txnId`, `qbo.attachableId`, `status="pushed"`.

## Phase D — Quality & “Nag” UX

- [ ] Trigger one-field micro-sheet if amount/date/vendor missing.
- [ ] Local notification to complete the single missing field.
- [ ] Offline test (airplane mode) → queued upload on reconnect.

## Testing

- [ ] 20 diverse receipts; lighting variations; with/without speech; offline.
- [ ] Amount/date accuracy ≥ 98%; remaining get a nag.
- [ ] QBO transaction visible with correct vendor/date/amount and attached receipt.

## Security & Privacy

- [ ] HTTPS everywhere (default).
- [ ] Storage/DB rules locked to `companyKey` + role.
- [ ] Card numbers redacted to **last4**.
- [ ] Location consent banner; toggle in settings.
- [ ] Delete = hard-delete image + metadata.

## Nice-to-Haves (post-MVP)

- [ ] Action Button shortcut → instant scan.
- [ ] Contacts integration for attendees.
- [ ] Auto-route to company based on transcript hints.
- [ ] Rules engine for merchant → category/class/customer.

---

### File Layout (suggested)

````

/GotReceipts
/iOS
GotReceiptsApp.swift
Scanner/DocumentScannerView.swift
Scanner/OCRService.swift
Speech/SpeechRecognizer.swift
NLP/ReceiptParser.swift
Data/Models.swift
Data/UploadQueue.swift
Data/FirestoreService.swift
Location/LocationService.swift
Background/BGTasks.swift
UI/CaptureFlowView.swift
UI/ConfirmTinySheet.swift
/server
functions/index.ts
functions/qbo/oauth.ts
functions/qbo/vendors.ts
functions/qbo/expenses.ts
functions/qbo/attachable.ts
functions/firestoreTriggers.ts
.env.example
/docs
FullPlanReadMe.md
README.md

```
```

---

Want me to also generate a starter `/server/functions` folder with TypeScript stubs for the QBO OAuth/Attachable/Expense endpoints and a Firestore trigger?

