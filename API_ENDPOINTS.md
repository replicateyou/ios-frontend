# Relay API → UX Mapping

Base URL: `Constants.relayBaseURL` (default `http://localhost:3001`)

---

## GET /categories

**Returns:** `[CategoryPool]`

```
category        String    e.g. "towel-fold"
fundReserve     String    wei — total pool funds
virtualSupply   String    current clip supply count
totalShares     String    wei
currentPrice    String    wei — price per accepted clip
```

Helpers on `CategoryPool`:
- `.currentPriceA0GI` → `Double` in A0GI
- `.fundReserveA0GI`  → `Double` in A0GI

**Natural UX home:** `HomeView` — call on appear to replace `Quest.samples` with live categories. Each `CategoryPool` drives a card.

---

## GET /categories/:name

**Returns:** `CategoryPool` (same shape as one item above)

**Natural UX home:** `QuestDetailView` — poll while the user is on this screen to keep the price ticker live. Category name comes from the selected quest/category passed in via navigation.

---

## POST /upload   (multipart/form-data)

**Sends:**
```
file           Data      video file (mp4, max 200 MB)
category       String    exact category name from /categories
workerAddress  String    worker's EVM address (AppState.walletAddress)
```

**Returns:** `SubmissionResult`
```
submissionId   Int       on-chain ID
storageHash    String    0G storage root hash
score          Int       0–100 AI quality score
status         String    "accepted" | "rejected"
payout         String    wei — 0 if rejected
```

Helpers on `SubmissionResult`:
- `.isAccepted`  → `Bool`
- `.payoutA0GI`  → `Double` in A0GI

**Natural UX home:** `QuestStreamView` — triggered when the user taps "End Stream". The recorded video buffer is passed as `Data`, `category` from the active quest, `workerAddress` from `AppState.walletAddress`. The result (score + payout) drives the post-stream result screen.

---

## Call signature quick-ref

```swift
// Home screen loads
let categories = try await RelayService.shared.fetchCategories()

// Detail screen price ticker
let pool = try await RelayService.shared.fetchCategory("towel-fold")

// End stream submit
let result = try await RelayService.shared.uploadClip(
    videoData,
    category: quest.category,
    workerAddress: appState.walletAddress ?? ""
)
```

---

## Notes

- All wei values have 18 decimals (A0GI). Use `.currentPriceA0GI` / `.payoutA0GI` helpers for display.
- Category names are case-sensitive — always pass exactly what `/categories` returns.
- `POST /upload` takes 10–30 s (storage upload + AI scoring + 2 on-chain txs). Show a loading state.
- Errors surface as `RelayError.httpError(statusCode, message)` — the `message` string is user-displayable.
