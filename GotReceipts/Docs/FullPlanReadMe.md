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

