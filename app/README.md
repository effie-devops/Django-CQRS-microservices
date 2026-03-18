# Application Services

## CQRS Architecture

| Service | Operations | Port | Purpose |
|---------|------------|------|----------|
| **Reader** | GET, DELETE | 8000 | Data retrieval |
| **Writer** | POST, PUT, PATCH | 8001 | Data manipulation |

## Structure

```
app/
├── reader-service/         # Read operations service
├── writer-service/         # Write operations service
├── requirements.txt        # Python dependencies
└── .env                   # Environment variables
```

## Endpoints

- **Reader**: http://api.effiecancode.buzz
- **Writer**: http://api.effiecancode.buzz
- **Health**: `/health/` on both services

trigger workflow