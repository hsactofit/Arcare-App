# Arcare Home Screen Combined API Specification

This document details the single, merged API endpoint designed for the Arcare Home Screen. It handles the synchronization of daily health metrics for the last 7 days and returns the parsed dashboard layout states, daily summaries, recommendations, and the AI Buddy greeting.

---

## 🚀 Combined Sync & Dashboard Endpoint

* **Endpoint Path**: `POST /api/dashboard/sync/{email}`
* **Headers**: 
  - `Content-Type: application/json`
  - `Authorization: Bearer <access_token>` (Optional/Required based on JWT auth setup)
* **Description**: Receives daily health metrics for the last 7 days, updates the backend database, and returns all variables required to render the Home Screen widgets.

---

## 📤 1. Request Body Format

The request payload is a **JSON Array** of daily health records from the mobile client, covering up to the last 7 days.

### Fields per Daily Record:
| Field | Type | Description |
| :--- | :--- | :--- |
| `date` | `String` | The date of the record in `YYYY-MM-DD` format. |
| `steps` | `Integer` | Total step count completed on that day. |
| `calories` | `Integer` | Total energy burned in kilocalories (Active + Basal metabolic rate). |
| `sleep_duration_hours` | `Float` | Total sleep time tracked for the night/day. |
| `water_intake_ml` | `Integer` | Total hydration amount logged in milliliters. |
| `workouts_count` | `Integer` | Number of completed physical exercise routines. |
| `heart_rate_bpm` | `Integer` | The average heart rate recorded in beats per minute. |

### Request Payload Example:
```json
[
  {
    "date": "2026-07-02",
    "steps": 8430,
    "calories": 2180,
    "sleep_duration_hours": 7.4,
    "water_intake_ml": 1800,
    "workouts_count": 1,
    "heart_rate_bpm": 68
  },
  {
    "date": "2026-07-01",
    "steps": 9800,
    "calories": 2340,
    "sleep_duration_hours": 8.0,
    "water_intake_ml": 2200,
    "workouts_count": 2,
    "heart_rate_bpm": 70
  },
  {
    "date": "2026-06-30",
    "steps": 5120,
    "calories": 1950,
    "sleep_duration_hours": 6.2,
    "water_intake_ml": 1200,
    "workouts_count": 0,
    "heart_rate_bpm": 74
  }
]
```

---

## 📥 2. Response Body Format

The server responds with a **200 OK** containing the calculated scores and personalized wellness content.

### Fields in Response:
| Field | Type | Description |
| :--- | :--- | :--- |
| `wellness_score` | `Integer` | Current overall health score out of 100 (renders inside the wellness circular meter). |
| `active_subscore` | `Integer` | Activity subscore out of 100. |
| `sleep_subscore` | `Integer` | Sleep subscore out of 100. |
| `nutrition_subscore` | `Integer` | Nutrition subscore out of 100. |
| `mindfulness_subscore` | `Integer` | Mindfulness subscore out of 100. |
| `water_intake_today` | `Integer` | The daily total water volume logged by the user today (in ml). |
| `daily_summary` | `String` | Dynamic descriptive summary text of the user's progress. |
| `recommendations` | `List<String>` | Actionable advice strings displayed inside the AI Advisor recommendations card. |
| `ai_buddy_message` | `String` | Dynamic, personalized message from the AI Buddy. (Cached locally to serve as the initial message in the AI tab). |
| `goals` | `Map<String, Float>` | The active daily goal metrics targets configured by the user. |

### Response Payload Example:
```json
{
  "wellness_score": 82,
  "active_subscore": 92,
  "sleep_subscore": 78,
  "nutrition_subscore": 70,
  "mindfulness_subscore": 85,
  "water_intake_today": 1450,
  "daily_summary": "Incredible progress! You are average 7,780 steps daily and hitting your sleep goals. Keep tracking your hydration to increase your wellness metrics.",
  "recommendations": [
    "Increase your daily water intake by 500 ml to meet standard hydration guidelines.",
    "Try scheduling a brief 15-minute stretch routine during mid-day break."
  ],
  "ai_buddy_message": "Hello Champion! I noticed you average 7.4 hours of sleep this week, which is excellent. Let's aim to hit 10,000 steps today to secure your new streak record!",
  "goals": {
    "step_goal": 10000.0,
    "sleep_goal": 8.0,
    "water_goal": 2500.0,
    "calorie_goal": 600.0,
    "exercise_goal": 60.0
  }
}
```

---

## ⏱️ 3. Mobile Synchronization Gating Logic

To optimize battery life, reduce server request overhead, and improve the offline user experience, the mobile application applies the following rules:

1. **Local Caching:**
   - The returned parameters (`wellness_score`, `daily_summary`, `recommendations`, `ai_buddy_message`, and the successful sync timestamp `last_sync_timestamp`) are saved to local persistent storage (`SharedPreferences`).
   - On page launch or tab change, the UI loads the cached states instantly to guarantee a fast, responsive user interface.

2. **2-Hour Auto-Sync Interval Gating:**
   - When the dashboard refreshes automatically on load, it compares the current time to the cached `last_sync_timestamp`.
   - If the difference is **less than 2 hours**, the application **skips the backend request** and renders local/cached data.
   - If the difference is **greater than or equal to 2 hours**, a backend synchronization is automatically triggered.

3. **Manual Overrides:**
   - If the user explicitly hits **Refresh Dashboard**, **Verify Setup**, or clicks the sync options inside the visual debugger, a forced sync is dispatched (`forceSync: true`).
   - Manual sync bypasses the 2-hour gating interval and uploads a fresh query of Health Connect records immediately.

---

## 🧠 4. Wellness Score & Subscores Calculation Methodology

To ensure consistency between the mobile application's UI representation and backend database tracking, the backend service should compute the **Overall Wellness Score** and its individual components (**Active, Sleep, Nutri, Mind**) based on the last 7 days of daily synchronization arrays using the following mathematical formulas.

### 1. Active Subscore (Weight: 35%)
Focuses on physical energy expenditure and movement tracking relative to the user's custom goals.
* **Inputs:** Steps ($S$), Active Calories ($C$, in kcal), and Exercise/Active Minutes ($E$, in minutes).
* **Weights:** $W_{\text{steps}} = 0.50$, $W_{\text{calories}} = 0.30$, $W_{\text{exercise}} = 0.20$.
* **Formulas:**
  $$\text{Steps Ratio} = \min\left(\frac{S}{S_{\text{goal}}}, 1.2\right)$$
  $$\text{Calories Ratio} = \min\left(\frac{C}{C_{\text{goal}}}, 1.2\right)$$
  $$\text{Exercise Ratio} = \min\left(\frac{E}{E_{\text{goal}}}, 1.2\right)$$
  $$\text{Active Subscore} = \min\left(\left(W_{\text{steps}} \times \text{Steps Ratio} + W_{\text{calories}} \times \text{Calories Ratio} + W_{\text{exercise}} \times \text{Exercise Ratio}\right) \times 100, 100\right)$$

### 2. Sleep Subscore (Weight: 25%)
Measures recovery efficiency based on total sleep duration and resting heart rate indices.
* **Inputs:** Sleep Hours ($H$, in hours), and Sleep Quality Estimate ($Q$, scaled 0.0 to 1.0 based on sleep structure or resting pulse stability).
* **Formulas:**
  - Let optimal sleep range be $H_{\text{optimal}} = H_{\text{goal}}$ (typically 7 to 9 hours).
  - Penalize sleep under 5 hours or over 10 hours:
    $$\text{Duration Factor} = \max\left(0.0, 1.0 - 0.2 \times |H - H_{\text{goal}}|\right)$$
  $$\text{Sleep Subscore} = \min\left(\left(0.7 \times \text{DurationFactor} + 0.3 \times Q\right) \times 100, 100\right)$$

### 3. Nutrition Subscore (Nutri) (Weight: 20%)
Measures cellular hydration levels and balanced nutritional intake.
* **Inputs:** Water Intake ($W$, in ml) and Macro Balance Factor ($M$, from food logs or normalized macro distributions).
* **Formulas:**
  $$\text{Water Ratio} = \min\left(\frac{W}{W_{\text{goal}}}, 1.0\right)$$
  $$\text{Nutrition Subscore} = \min\left(\left(0.60 \times \text{Water Ratio} + 0.40 \times M\right) \times 100, 100\right)$$

### 4. Mindfulness Subscore (Mind) (Weight: 20%)
Assesses stress resilience, heart rate variation (HRV), and mindful pauses.
* **Inputs:** Mindfulness Minutes ($M_{\text{mind}}$, in minutes) and Resting Heart Rate Stability Factor ($H_{\text{stable}}$, derived from average deviations).
* **Formulas:**
  $$\text{Mindfulness Ratio} = \min\left(\frac{M_{\text{mind}}}{\text{Mindfulness Goal}}, 1.0\right)$$
  $$\text{Mindfulness Subscore} = \min\left(\left(0.50 \times \text{Mindfulness Ratio} + 0.50 \times H_{\text{stable}}\right) \times 100, 100\right)$$

---

$$\text{Wellness Score} = \min\left(0.35 \times \text{Active} + 0.25 \times \text{Sleep} + 0.20 \times \text{Nutri} + 0.20 \times \text{Mind}, 100\right)$$

---

### 6. App-Flow & Interactive Features Influence on Wellness Scores

Beyond passive Health Connect sensor readings, actions taken by the user inside the mobile application directly impact their subscores and overall Wellness Score. The backend calculates these influences daily to incentivize engagement:

| Interactive App Action | Affected Metric / Subscore | Mathematical / Logical Impact |
| :--- | :--- | :--- |
| **Water Logging (ml)** | Nutrition Subscore (`Nutri`) | Hydration contributes **60%** of the Nutrition subscore. Tapping "Log Water" increases the daily Water Intake ($W$) total toward $W_{\text{goal}}$. |
| **Gym QR Check-in & Workout Starts** | Active Subscore (`Active`) | Adds directly to Active/Exercise Minutes ($E$). Consistent gym streaks trigger a **1.05x multiplier** (up to 1.2x max) on the `Active` subscore. |
| **Meal photo/text logging** | Nutrition Subscore (`Nutri`) | Controls the Macro Balance Factor ($M$). Logging $\ge 3$ balanced meals/day sets $M = 1.0$. Repeatedly skipping meals or logging late-night snack records decays $M$ by $0.15$ per occurrence. |
| **Mood Check-in & Stress Logs** | Mindfulness Subscore (`Mind`) | Directly populates the Stress Factor index. Logging balanced moods and normal stress levels sets the stability factor $H_{\text{stable}} = 1.0$. High stress alerts decay it unless a breathing exercise is logged. |
| **Expert Consults & Webinars** | Multiplier / Recovery Booster | Completing a booked counsellor, doctor, or nutritionist session provides a **+5 point recovery booster** to the overall Wellness Score for that day to offset high stress/poor sleep penalties. |

---

## 💧 7. Hydration (Water Logging) Endpoints

### 7.1 Fetch Hydration History (Last 7 Logs)
* **Path**: `GET /api/water/logs/{email}`
* **Headers**: `Authorization: Bearer <access_token>`
* **Response (200 OK)**:
```json
{
  "water_intake_today": 1450,
  "logs": [
    {
      "amount": 250,
      "timestamp": "2026-07-05T17:12:55.108993"
    },
    {
      "amount": 500,
      "timestamp": "2026-07-05T08:30:00.000000"
    }
  ]
}
```

### 7.2 Log Daily Water Volume
* **Path**: `POST /api/water/log/{email}`
* **Content-Type**: `application/json`
* **Headers**: `Authorization: Bearer <access_token>`
* **Request Body**:
```json
{
  "amount": 500,
  "timestamp": "2026-07-05T10:20:15.000Z"
}
```
* **Response (200 OK)**:
```json
{
  "message": "Water intake logged successfully",
  "amount": 500,
  "timestamp": "2026-07-05T10:20:15.000Z"
}
```

### 7.3 Water Graph Trend Data
* **Path**: `GET /api/water/graph/{email}?period={period}`
* **Query parameters**: `period` (values: `day`, `week`, `month`. Default: `week`)
* **Headers**: `Authorization: Bearer <access_token>`
* **Response (200 OK)**:
```json
{
  "period": "week",
  "data": [
    { "label": "2026-06-29", "amount": 0 },
    { "label": "2026-06-30", "amount": 0 },
    { "label": "2026-07-01", "amount": 0 },
    { "label": "2026-07-02", "amount": 0 },
    { "label": "2026-07-03", "amount": 0 },
    { "label": "2026-07-04", "amount": 0 },
    { "label": "2026-07-05", "amount": 500 }
  ]
}
```

### 7.4 Update Specific Water Log
* **Path**: `PUT /api/water/log/{log_id}`
* **Content-Type**: `application/json`
* **Headers**: `Authorization: Bearer <access_token>`
* **Request Body**:
```json
{
  "amount": 600,
  "timestamp": "2026-07-05T14:14:00.828100Z"
}
```
* **Response (200 OK)**:
```json
{
  "id": "1",
  "message": "Water intake logged successfully",
  "amount": 600,
  "timestamp": "2026-07-05T14:14:00.828100Z"
}
```

### 7.5 Delete Specific Water Log
* **Path**: `DELETE /api/water/log/{log_id}`
* **Headers**: `Authorization: Bearer <access_token>`
* **Response (200 OK)**:
```json
{
  "message": "Water log deleted successfully"
}
```




