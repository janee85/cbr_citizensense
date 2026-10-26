# Cabadbaran CitizenSense - Flutter Web client

Complete client for the three roles (citizen, office staff, administrator).

## Run

```bash
flutter create . --platforms web      # one time, adds web/ (keeps lib/ and pubspec.yaml)
flutter pub get
flutter run -d chrome                 # mock API, works with no backend
flutter test
```

Needs Flutter 3.35 or newer (uses `DropdownButtonFormField.initialValue`).

Mock-mode accounts, password `password123`:
`citizen@gmail.com`, `staff@staff.com` (Engineering), `health@staff.com` (Health), `admin@admin.com`

## Screens

| Route | Who | What |
|---|---|---|
| /login, /register | everyone | role comes from the email domain, terms must be accepted |
| /citizen/dashboard, /staff/dashboard, /admin/dashboard | by role | overview, charts, recent complaints |
| /submit-complaint | citizen | live ML priority check, office routing, attachment, consent |
| /complaint-tracking | citizen | own complaints: search, status/priority filters, paging |
| /complaint-review | staff | complaints of the staff's office, urgent first |
| /admin/complaints | admin | all complaints |
| /complaints/:id | all (scoped) | details, ML result, responses, status history; staff update form |
| /reports-analytics | admin | filters, breakdowns, copy as CSV |
| /admin/users | admin | activate/deactivate users, office workload |
| /settings | all | profile, change password, terms |

## Connect to the FastAPI backend

```bash
flutter run -d chrome --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Success bodies may be `{ "data": {...} }` or the object itself. Errors: `{ "error": { "code", "message", "details" } }`.
List endpoints return `{ "data": { "items": [ ... ] } }`. The session is kept in the browser and a 401 logs the user out.

| Endpoint | Role | Status |
|---|---|---|
| POST /api/auth/register, /api/auth/login | public | EP-01, EP-02 |
| POST /api/complaints (JSON, or multipart with `attachment`; now sends `office_id`) | citizen | EP-03, updated |
| GET /api/complaints | citizen | EP-04 |
| GET /api/complaints/{id} | owner / assigned staff / admin | EP-05 |
| GET /api/staff/complaints | staff | EP-06 |
| PATCH /api/complaints/{id}/status `{status, response_message}` | staff of that office | EP-07 |
| GET /api/reports?days=&office_id=&category_id= | admin | EP-08 |
| POST /api/complaints/classify `{category_id, description}` | citizen | NEW |
| GET /api/dashboard/summary | all | NEW |
| GET /api/admin/complaints | admin | NEW |
| GET /api/admin/users, PATCH /api/admin/users/{id} `{active}` | admin | NEW |
| GET /api/admin/offices | admin | NEW |
| GET /api/notifications | all | NEW |
| POST /api/auth/change-password `{current_password, new_password}` | all | NEW |

Complaint JSON used by lists/detail: `id, title, description, category_id, office_id, location_id, status, priority, sentiment, created_at, citizen_name, attachment_name`.
Detail adds `location, confidence, keywords, responses[{message, staff_name, created_at}], history[{status, note, by, at}]`.
Status values: `submitted, received, in_progress, resolved, closed`. Legal moves: submitted to received or in_progress; received to in_progress or resolved; in_progress to resolved; resolved to closed or in_progress. Anything else returns 409.


## Backend setup
See [`backend/README.md`](backend/README.md) for database configuration and FastAPI startup steps. The backend is a starter integration and the classification endpoint is not a trained ML model yet.
