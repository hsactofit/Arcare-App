# API Data Specification

This document details the request bodies, query parameters, headers, and responses required by the backend API at `http://192.168.1.101:8000`.

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
  "daily_summary": "You are 64% towards your daily steps goal. Your hydration levels look stable, and you got a healthy sleep duration of 7.5 hours.",
  "recommendations": [
    "Take a 10-minute active stretch after your next sit-down period.",
    "Drink a glass of water before dinner to close out your hydration targets."
  ],
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
