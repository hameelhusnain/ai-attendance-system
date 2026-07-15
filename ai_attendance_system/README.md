# AI Attendance System

AI Attendance System is a Flutter-based attendance management application designed for classrooms and educational environments. The frontend is built to work with a backend API and future AI/vision services for attendance recognition, reporting, and analytics.

This document is intended to help backend developers, documentation writers, and AI-assisted tooling understand what the frontend does, how it is structured, and how it interacts with the backend.

---

## 1. Project Overview

The app helps users:
- log in securely
- view classes and select a class for a session
- start and stop attendance sessions
- view student rosters for the selected class
- track attendance in real time during a session
- view attendance reports and session summaries
- inspect student details and attendance history

The current frontend is mobile-first, but it also supports desktop layouts with responsive behavior.

### App purpose
The application is meant to serve as the operational front end for attendance management. It is not just a UI shell; it contains the main business flow for:
- class/session management
- attendance recording lifecycle
- report generation workflow
- student and class exploration

---

## 2. Main Features Implemented in the Frontend

### Authentication
- Login screen for user authentication
- Token-based login flow
- Token saved in local storage using SharedPreferences
- Logout clears the token and resets session state

### Dashboard
- Shows available classes for the logged-in user
- Lets the user choose a class and navigate into the session flow

### Sessions
- Start a session for a selected class
- Stop a session when attendance is completed
- Poll the backend for attendance progress during a session
- Restore an active session if the app is reopened
- Show class roster and student breakdown

### Students
- Fetch and display students from the backend
- Search and filter students by name, class, and status
- Navigate to a student detail screen

### Reports / Profile view
- Load session data and attendance report rows
- Show summary counts of present/absent students
- Show recent sessions and report details

### Settings / About
- Theme toggle support
- About screen describing the product vision and platform goals

---

## 3. Frontend Architecture

The project uses a feature-based Flutter architecture.

### Core structure
- lib/main.dart: application entry point
- lib/app.dart: root app widget and theme setup
- lib/core/: shared app infrastructure such as routing, theme, reusable widgets, and responsive helpers
- lib/features/: feature modules for authentication, dashboard, sessions, students, reports, profile, about, and settings
- lib/shared/: shared models, services, and session storage utilities

### Architectural style
The frontend is built with:
- StatefulWidget-based screens
- go_router for navigation
- a shared API service layer for all network calls
- a lightweight session store for persistent app state
- reusable UI widgets for cards, buttons, text fields, spacing, and layouts

### Navigation model
Routing is centralized in the router layer. The main routes include:
- /
- /dashboard
- /sessions
- /students
- /students/:id
- /reports
- /settings
- /about
- /profile

---

## 4. Important Frontend Modules

### 4.1 Authentication flow
Files involved:
- lib/features/auth/presentation/login_screen.dart
- lib/shared/services/api_service.dart
- lib/shared/services/session_store.dart

Flow:
1. User enters email/username and password
2. Frontend calls the backend login endpoint
3. Backend returns an access token
4. Token is stored locally and used in subsequent requests
5. User is redirected to the dashboard

### 4.2 Dashboard flow
Files involved:
- lib/features/dashboard/presentation/dashboard_screen.dart

Behavior:
- Fetches classes from the backend
- Displays them as cards
- When a class is selected, the selected class is saved in the session store and the user is sent to the sessions screen

### 4.3 Session lifecycle flow
Files involved:
- lib/features/sessions/presentation/sessions_screen.dart

This is the most important part of the app.

Responsibilities:
- startSession(): sends a request to create/open a session
- stopSession(): closes the session and prepares a report
- syncSessionState(): restores the active session state from the backend
- _pollAttendanceCount(): periodically checks the backend to update present/absent counts
- _loadStudentBreakdown(): loads the current attendance breakdown for the active session

This flow is designed to work even if the backend returns slightly different field names or nested structures, because the frontend includes flexible response parsing helpers.

### 4.4 Students screen
Files involved:
- lib/features/students/presentation/students_screen.dart

Responsibilities:
- load students from the backend
- allow filtering by class and status
- search by name, ID, or email
- navigate to a student details page

### 4.5 Reports screen
Files involved:
- lib/features/reports/presentation/reports_screen.dart

Responsibilities:
- load sessions and student records
- show high-level summary cards
- show report rows for a chosen session
- support selection of relevant sessions

---

## 5. Shared Services and State Handling

### ApiService
The app uses a centralized API layer in:
- lib/shared/services/api_service.dart

This service is responsible for:
- building request URLs
- attaching auth headers
- handling JSON responses
- implementing all primary API calls for students, classes, sessions, attendance, and photos

### SessionStore
The app uses:
- lib/shared/services/session_store.dart

This stores:
- auth token
- selected class
- current active session id
- current session payload
- report session id

This is used so that the user experience continues across app restarts and screen transitions.

### SharedPreferences
The app uses SharedPreferences to persist:
- auth token
- configured API base URL
- current session details where appropriate

---

## 6. Backend API Interaction Model

The frontend talks to a backend API through the ApiService class.

### Base URL behavior
The app supports a configurable base URL.
- If no URL is set, it uses a default value.
- The base URL is stored and reused from the session configuration.

### Authentication endpoints
Expected endpoints include:
- POST /auth/login
- GET /auth/me

### Student endpoints
Expected endpoints include:
- GET /students/
- GET /students/:id
- POST /students/
- DELETE /students/:id
- POST /students/upload-photo
- GET /students/:id/photos
- GET /students/no-embedding
- PUT /students/:id/photos/:photoId/embedding

### Class and teacher endpoints
Expected endpoints include:
- GET /classes/
- POST /classes/
- GET /teachers/
- POST /teachers/

### Session endpoints
Expected endpoints include:
- GET /sessions/
- GET /sessions/:id
- POST /sessions/
- POST /sessions/:id/end

### Attendance endpoints
Expected endpoints include:
- POST /attendance/sessions/:sessionId/submit
- GET /attendance/sessions/:sessionId/report
- GET /attendance/students/:studentId/history

---

## 7. How the Frontend, Backend, and AI Work Together

The frontend is the user-facing layer that collects and displays data. The backend is responsible for storing and processing that data. AI-related functionality is expected to be integrated at the backend or service layer for tasks such as:
- image-based attendance recognition
- student photo embedding and matching
- intelligent analytics and anomaly detection
- future report enhancement

### Current frontend integration points for backend and AI
The frontend already contains hooks for AI-related data flow:
- photo upload endpoints for student images
- embedding update endpoints
- attendance report retrieval that can be used by AI analytics or reporting modules

### Typical runtime flow
1. User logs in.
2. The frontend requests classes and students from the backend.
3. The user starts a session.
4. The backend creates or activates the session.
5. The frontend polls the backend for status and attendance progress.
6. The user stops the session.
7. The backend closes the session and prepares a report.
8. The frontend displays the final report.

This means the frontend is not isolated; it depends on backend responses and should be treated as a consumer of backend business logic.

---

## 8. Data Shapes the Frontend Expects

The frontend is designed to be resilient to multiple possible response shapes. It supports payloads that may come as:
- arrays directly
- objects with keys such as data, items, sessions, students, records, attendance
- nested objects with session or class information inside another object

### Example expected student object shape
```json
{
  "id": "student-1",
  "full_name": "Amina Khan",
  "email": "amina@example.com",
  "class_name": "Math 101",
  "status": "Active"
}
```

### Example expected session object shape
```json
{
  "id": "session-1",
  "status": "active",
  "class_name": "Math 101",
  "created_at": "2026-07-15T10:00:00Z"
}
```

### Example expected attendance report shape
```json
{
  "students": [
    {
      "full_name": "Amina Khan",
      "final_status": "PRESENT"
    }
  ]
}
```

This flexibility is important because backend implementations may differ slightly across team members.

---

## 9. What Functions Were Added or Important in the Frontend

The frontend implements several practical functions and interactions:
- login and token persistence
- class loading and selection
- session start/stop logic
- active session restoration on app reopen
- real-time attendance polling
- student roster fetching and filtering
- attendance report loading
- student detail retrieval
- resilient parsing of nested API payloads
- theme switching and polished app shell navigation

These are the functions that your documentation writers and AI tools should highlight as the main value-add of the frontend.

---

## 10. UI/UX Notes

The app uses a modern, polished UI with:
- card-based layout
- responsive spacing and adaptive screen behavior
- animated transitions for screens and session views
- clear status chips and summary cards
- a strong focus on large touch targets and mobile usability

This matters because attendance tools are often used during live classroom operation, where speed and clarity are essential.

---

## 11. Development Setup

### Requirements
- Flutter SDK
- Android Studio / Xcode for device builds if needed
- A running backend API that exposes the expected endpoints

### Install dependencies
```bash
flutter pub get
```

### Run the app
```bash
flutter run
```

### Run tests
```bash
flutter test
```

---

## 12. Recommended Backend Contract for Smooth Frontend Integration

To make the app work smoothly, the backend should provide consistent endpoints and predictable response structures.

### Recommended conventions
- Always return JSON
- Use clear field names such as id, name, status, class_name
- Keep student and session data nested or flattened consistently
- Return attendance status values like PRESENT, ABSENT, or similar readable strings
- Return report rows in a clearly enumerable structure

### Best practice for API consistency
The frontend is currently robust, but the backend should ideally follow a consistent schema so that documentation, analytics, and AI features become easier to build.

---

## 13. Documentation Notes for Backend and AI Teams

For backend and AI collaborators, the main things to understand are:
- the frontend is centered around the session lifecycle
- attendance data is driven by session-based reporting
- students and classes are core entities that feed the UI
- authentication is token-based
- the frontend uses the backend as the source of truth for all live data

If a new AI feature is added, the frontend is already prepared to interact with endpoints around photos, embeddings, and analytics-related report responses.

---

## 14. Summary

This project is not just a basic Flutter demo. It is a real attendance-management workflow app with:
- login and session authentication
- class-based session operation
- student roster management
- live attendance tracking
- reporting and summary views
- API-driven architecture designed for backend integration and future AI enhancement

The frontend already provides the main user experience layer. The backend and AI components should focus on making the request/response flow reliable, consistent, and rich enough to power the UI effectively.
