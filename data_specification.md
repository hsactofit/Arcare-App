# API Data Specification

This document details the request bodies, query parameters, headers, and responses required by the backend API at `http://192.168.1.107:8000`.

---

## 🔐 1. Authentication Endpoints

### 1.1 Email Sign Up
* **Path**: `POST /api/auth/signup`
* **Content-Type**: `application/json`
* **Request Body**:
```json
{
  "email": "user@example.com",
  "password": "securepassword123",
  "name": "John Doe",
  "provider": "email"
}
```
* **Response (201 Created)**:
```json
{
  "access_token": "eyJhbGciOi...",
  "refresh_token": "eyJhbGciOi...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "provider": "email",
    "onboarding_completed": false,
    "completed_at": null,
    "last_sync_date": null,
    "profile": null,
    "goals": [],
    "permissions": null
  }
}
```

### 1.2 Email Login
* **Path**: `POST /api/auth/login`
* **Content-Type**: `application/json`
* **Request Body**:
```json
{
  "email": "user@example.com",
  "password": "securepassword123"
}
```
* **Response (200 OK)**:
```json
{
  "access_token": "eyJhbGciOi...",
  "refresh_token": "eyJhbGciOi...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "provider": "email",
    "onboarding_completed": true,
    "completed_at": "2026-06-28T14:00:00Z",
    "last_sync_date": "2026-07-02T14:30:00Z",
    "profile": {
      "dob": "1995-08-15",
      "gender": "Male",
      "height": 178.5,
      "weight": 76.2
    },
    "goals": ["Weight Loss", "Daily Activity"],
    "permissions": {
      "health_connect_connected": true,
      "notifications": {
        "daily_reminder": true,
        "hydration_reminder": true,
        "activity_reminder": true,
        "sleep_reminder": true,
        "challenge_updates": false,
        "rewards": false,
        "ai_tips": true
      }
    }
  }
}
```

### 1.3 Social Login & Registration
* **Path**: `POST /api/auth/social-login`
* **Content-Type**: `application/json`
* **Request Body**:
```json
{
  "provider": "google", 
  "token": "firebase_id_token_string",
  "name": "John Doe"
}
```
* **Response (200 OK / 201 Created)**: Same schema as `AuthResponse` (refer to Section 1.2).

---

## 📋 2. Onboarding Endpoints

### 2.1 Submit Onboarding Profile
* **Path**: `POST /api/onboarding`
* **Content-Type**: `application/json`
* **Headers**: `Authorization: Bearer <access_token>` (Optional but recommended if logged in)
* **Request Body**:
```json
{
  "onboarding_completed": true,
  "completed_at": "2026-06-28T08:30:00Z",
  "auth": {
    "provider": "email",
    "name": "John Doe",
    "email": "user@example.com"
  },
  "profile": {
    "dob": "1995-08-15",
    "gender": "Male",
    "height": 178.5,
    "weight": 76.2
  },
  "goals": ["Weight Loss", "Daily Activity"],
  "permissions": {
    "health_connect_connected": true,
    "notifications": {
      "daily_reminder": true,
      "hydration_reminder": true,
      "activity_reminder": true,
      "sleep_reminder": true,
      "challenge_updates": false,
      "rewards": false,
      "ai_tips": true
    }
  }
}
```
* **Response (201 Created)**:
```json
{
  "message": "Onboarding completed successfully"
}
```

---

## 📈 3. Health & Dashboard Sync Endpoints (Combined)

### 3.1 Sync Health Data
* **Path**: `POST /api/health/sync/{email}`
* **Content-Type**: `application/json`
* **Headers**: `Authorization: Bearer <access_token>`
* **Request Body**:
```json
{
  "steps": 6430,
  "calories": 2150,
  "sleep_duration_hours": 7.5,
  "water_intake_ml": 1500,
  "workouts_count": 1,
  "heart_rate_bpm": 72
}
```
* **Response (200 OK)**:
```json
{
  "steps": 6430,
  "calories": 2150,
  "sleep_duration_hours": 7.5,
  "water_intake_ml": 1500,
  "workouts_count": 1,
  "heart_rate_bpm": 72,
  "updated_at": "2026-06-28T08:35:12Z"
}
```

### 3.2 Get Dashboard Layout & Metrics
* **Path**: `GET /api/dashboard/{email}`
* **Headers**: `Authorization: Bearer <access_token>`
* **Response (200 OK)**:
```json
{
  "wellness_score": 78,
  "active_subscore": 92,
  "sleep_subscore": 78,
  "nutrition_subscore": 70,
  "mindfulness_subscore": 85,
  "daily_summary": "You are 64% towards your daily steps goal. Your hydration levels look stable, and you got a healthy sleep duration of 7.5 hours.",
  "recommendations": [
    "Take a 10-minute active stretch after your next sit-down period.",
    "Drink a glass of water before dinner to close out your hydration targets."
  ],
  "goals": {
    "step_goal": 10000.0,
    "sleep_goal": 8.0,
    "water_goal": 2500.0,
    "calorie_goal": 600.0,
    "exercise_goal": 60.0
  },
  "widgets": [
    {
      "title": "Steps",
      "value": "6,430",
      "target": "10,000",
      "unit": "steps",
      "status": "active"
    }
  ]
}
```

### 3.3 Update User Goals
* **Path**: `POST /api/goals/update/{email}`
* **Content-Type**: `application/json`
* **Headers**: `Authorization: Bearer <access_token>`
* **Request Body**:
```json
{
  "step_goal": 10000.0,
  "sleep_goal": 8.0,
  "water_goal": 2500.0,
  "calorie_goal": 600.0,
  "exercise_goal": 60.0
}
```
* **Response (200 OK)**:
```json
{
  "message": "Goals updated successfully",
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

## 💧 4. Water Logging Endpoints

### 4.1 Fetch Last 7 Water Logs
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

### 4.2 Log Water Intake
* **Path**: `POST /api/water/log/{email}`
* **Content-Type**: `application/json`
* **Headers**: `Authorization: Bearer <access_token>`
* **Request Body**:
```json
{
  "amount": 250,
  "timestamp": "2026-07-05T10:15:30.000Z"
}
```
* **Response (200 OK)**:
```json
{
  "message": "Water intake logged successfully",
  "amount": 250,
  "timestamp": "2026-07-05T10:15:30.000Z"
}
```

### 4.3 Water Graph API
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

### 4.4 Update Water Log
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

### 4.5 Delete Water Log
* **Path**: `DELETE /api/water/log/{log_id}`
* **Headers**: `Authorization: Bearer <access_token>`
* **Response (200 OK)**:
```json
{
  "message": "Water log deleted successfully"
}
```


