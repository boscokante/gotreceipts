pl//
//  New.swift
//  GotReceipts
//
//  Created by Bosco "Bosko" Kante on 9/28/25.
//
# ChatBooks (GotReceipts) — Strategy & Universal Capture Plan

> **One-liner:** Capture every business transaction in **3 seconds** (tap/snap/speak or screenshot) and turn it into **tax-ready books with receipts**—no email rules, no bank connections required. Optional exports to QBO; first-class Beancount/Fava support.

---

## 1) Goals & Non-Goals

**Goals**
- **Zero-friction capture:** 3 seconds, 3 taps max, anywhere (phone, desktop, web).
- **Universal coverage:** paper, mobile P2P, web orders, desktop invoices, cash sales, deposits.
- **Audit-ready:** every transaction gets a **receipt + purpose** (and attendees/project if relevant).
- **No back-and-forth:** bookkeepers stop chasing clients for “what was this?” and missing docs.
- **Own the books:** produce a **P&L** and exports without requiring third-party accounting.

**Non-Goals (MVP)**
- Full bank-feed automation (OAuth aggregators); optional CSV/OFX import later.
- Line-item itemization/Inventory; keep postings simple (can split tips/tax where detected).

---

## 2) Universal Capture Matrix (Source-First, Setup-Free)

| Source | How We Capture | Evidence Stored | Fields We Extract (auto) |
|---|---|---|---|
| **Paper receipts** | iOS VisionKit camera (tap → snap → speak) | Image (HEIC/JPG) | Amount, date, vendor, tax/tip, last-4 if printed; voice purpose/attendees |
| **Mobile app screens** (Cash App, Venmo, PayPal, rideshare, POS) | **Screenshot → Share to ChatBooks** (iOS share extension) | Image | Amount, date/time, counterparty, ref id; optional voice note |
| **Desktop** | Menubar hotkey screenshot; **Print to ChatBooks** virtual printer; drag-&-drop PDFs | PNG/PDF | Same as above; better text from PDFs |
| **Web purchases** (Amazon, Shopify, airlines, SaaS) | **Browser extension**: capture DOM + render PDF; or print page to ChatBooks | PDF + JSON snapshot | Amount, date, vendor, order id, tax, last-4 if shown |
| **Cash payments** | Generate a **PDF receipt** in-app (issue to counterparty) | PDF | Amount, customer, memo; marks payment method = Cash |
| **Deposits / incoming** | Screenshot/print payment confirmations; (later) CSV import to reconcile | Image/PDF | Amount, payer, channel, reference |
| **Backfill / safety net** | (Optional) **CSV/OFX upload** from bank/CC; flag lines without evidence | CSV + linkage | Date, amount, descriptor → match to captured docs |

> **Principle:** We never *require* email forwarding or bank connects to be useful. Users can add them later for reconciliation if they want.

---

## 3) Product Pillars

1. **3-Second Capture**  
   - Default to camera (paper) or **Share Extension** (screenshots).  
   - Auto-dismiss post-save; one “Saved” toast.  
   - Only interrupt with a **single-question micro-nag** if a required field is missing.

2. **Single-Transaction View (not a list)**  
   - Show the card immediately after capture: Amount, Vendor, Date, Evidence (inline), Purpose, Attendees, Project, Payment Method (last-4), Location.  
   - Actions: Quick edit (one field), Reassign company, Delete, Share PDF.  
   - Close or auto-dismiss; list lives in a secondary screen.

3. **Background Enrichment**  
   - OCR + heuristics; voice → NLP for purpose/attendees/projects; vendor normalization; last-4 → account memory; optional reverse-geocode.  
   - Confidence thresholds; defer questions; batch nags once/day.

4. **Your Books, Your Choice**  
   - **Built-in ledger & P&L** (double-entry: Accounts/Transactions/Splits, category = posting account).  
   - **Beancount/Fava mode:** emit `.beancount` fragments + attach documents with deterministic paths.  
   - **QBO mode (optional):** create Expense/Purchase/SalesReceipt with **attachment**; user matches bank lines in QBO (one click).

5. **Firm-Friendly (White-Label)**  
   - Firms can brand the portal (“Powered by ChatBooks”).  
   - Multi-client dashboard; pooled storage; “Missing paperwork” view; role-based access.  
   - Soft lock-in: once clients adopt source capture, churn to generic apps is painful.

---

## 4) Architecture (High Level)

- **Clients:**  
  - iOS app (SwiftUI): VisionKit scanner + Share Extension; optional Photos “new screenshot” prompt.  
  - macOS menubar app: hotkey capture, drag-drop, Print-to-PDF.  
  - Browser extension (Chrome/Safari/Edge): DOM capture + PDF render + structured JSON.

- **Backend:**  
  - API + Worker (Docker): receives artifacts; runs OCR/NLP; applies rules; writes ledger entries; stores documents (S3/R2/B2).  
  - **Rules**: `payee_rules.yaml` and `card_map.yaml` (last-4 → account), per-company overrides.  
  - **Ledger options**:  
    - **Internal DB Ledger:** Postgres tables (Accounts, Transactions, Splits, Entities, Documents).  
    - **Beancount:** write `.beancount` fragments to `includes/inbox/` + save docs under `documents/YYYY/MM/vendor/…`; Fava serves UI.  
    - **QBO (optional):** push txn + attachment via Attachable; rely on QBO “Match”.

- **Storage/Costs:**  
  - Target ≤ **0.8 MB** avg per artifact; hot retention 12 months; archive older originals; keep 200–400 KB previews hot.  
  - ~$0.005/GB-mo class storage keeps COGS trivial at early scale.

---

## 5) Data Model (Essentials)

- **Document**: { path, hash, type=image/pdf, size, createdAt, source (ios_screenshot|scan|web_print|desktop_print) }  
- **Extraction**: { amount, date, currency, vendor_guess, tax, tip, last4, refId, purpose, attendees, project, confidence, provenance }  
- **Transaction**: { id, date, amount, currency, payee, narration, project, status, linkId }  
- **Splits**: [{ account, amount, memo }] enforcing double-entry sum=0  
- **Entities**: Vendors, Customers/Projects, PaymentInstruments (last-4 ↔ account)  
- **Idempotency**: hash(image/PDF) or (vendor+date+amount) to avoid dupes

---

## 6) Matching & Reconciliation (Without Pain)

- **Source capture first** ⇒ we already know purpose/attendees and hold the receipt.  
- **If bank data is added** (CSV or later via aggregator), we **link by** date±2d, amount, and **last-4**; unmatched lines flow into a “Needs evidence” tray.  
- **QBO path:** create txn + attach image; user confirms “Match” in Banking → For review (one click).  
- **Beancount path:** importer adds `^link` id to bank txn; Fava shows linked pair.

---

## 7) Privacy & Security

- User-initiated captures only (no background scraping).  
- TLS in transit; at-rest encryption; tenant-scoped buckets/prefixes.  
- Optional on-device redaction before upload; delete = hard-delete artifact + derived data.  
- Principle of least privilege for firm staff; audit trail on edits.

---

## 8) Pricing & Packaging (Draft)

- **Free** — 25 receipts/mo, 1 GB, P&L, exports.  
- **Starter $9** — 100 receipts/mo, 10 GB, 1 business, rules.  
- **Pro $19** — 300 receipts/mo, 50 GB, multi-business, projects, bookkeeper share.  
- **Firm** — $99 (10 clients), $199 (25), $399 (50). Extra storage: $3 / +50 GB.

> Unit economics are strong if support minutes stay low; storage is cheap. Firm plans have the best margins.

---

## 9) Rollout Plan (Milestones)

**M0 — Screenshot-First MVP (2–3 weeks)**
- iOS Share Extension + VisionKit; macOS hotkey + Print-to-PDF; Browser “Capture receipt” (Amazon/PayPal first).  
- OCR + minimal rules; Single-Transaction view; Built-in ledger + Monthly P&L; CSV export.

**M1 — Universal Capture Polish (2–4 weeks)**
- Templates for common screens (rideshare, Cash App, airlines).  
- Last-4 memory; vendor normalization cache; single-question nags; weekly “Potential gaps” card.

**M2 — Firm Mode & White-Label (2–3 weeks)**
- Multi-tenant admin; pooled storage; missing-paperwork queue; branded domain.  
- Beancount/Fava hosting option; QBO push optional.

**M3 — Reconciliation Aids (optional)**
- Bank CSV/OFX importer; link to captures by amount/date/last-4; discrepancy report.

---

## 10) Success Metrics (What “Working” Looks Like)

- **Coverage:** ≥ **90%** of real-world transactions have a captured receipt within **24h**.  
- **Ping-pong reduction:** ≥ **70%** fewer “what was this?” messages between client and bookkeeper.  
- **Time saved:** **2–4 hrs/mo** (solo) or **10–20 hrs/mo** per 20-client bookkeeper.  
- **Capture friction:** median time from screenshot to saved ≤ **3 seconds**.  
- **Attachment size:** avg ≤ **0.8 MB**; steady hot storage predictable.

---

## 11) Risks & Mitigations

- **Users forget to capture** → Share Extension from screenshot thumbnail; subtle “Process last screenshot?” prompt; weekly gap card.  
- **Inconsistent web layouts** → extension targets top merchants first; always allow print-to-PDF fallback.  
- **QBO matching expectations** → we attach receipts and structure metadata; the one-click **Match** in QBO remains user action (API can’t auto-press).  
- **Support creep** → crisp micro-nags, simple edits; firm plans offload first-line support to the firm.

---

## 12) Why This Wins

- **Setup-free:** No email rules or bank connects required to get value.  
- **Moment-of-truth capture:** purpose/attendees captured when the memory is fresh.  
- **Universal:** works for paper, apps, web, desktop, cash, and deposits.  
- **Bookkeeper-grade:** receipts attached + context = audit-ready; firms can brand it and reduce churn.

---

