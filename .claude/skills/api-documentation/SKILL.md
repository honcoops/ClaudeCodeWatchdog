---
name: api-documentation
description: Creates comprehensive REST API documentation with request/response examples, authentication details, and error handling for .NET/ASP.NET Core APIs
---

# API Documentation Skill

This skill generates complete, consistent API documentation for REST endpoints following OpenAPI/Swagger conventions.

## When to Use This Skill

Use this skill when:
- Documenting new API endpoints
- Creating API reference documentation
- Generating Swagger/OpenAPI documentation
- Updating existing API docs after changes
- Onboarding developers to API usage

## Documentation Structure

### 1. API Overview

Start with high-level information:

```markdown
# API Name

Base URL: `https://api.example.com/v1`

## Overview

Brief description of what this API provides and its purpose.

## Authentication

This API uses JWT Bearer token authentication.

Include the token in the Authorization header:
```
Authorization: Bearer {your_token}
```

## Rate Limiting

- Rate limit: 1000 requests per hour
- Limit header: `X-RateLimit-Remaining`
- Reset header: `X-RateLimit-Reset`

## Versioning

API version is specified in the URL path (`/v1/`).
Current version: v1.0
```

### 2. Endpoint Documentation Format

For each endpoint, use this structure:

```markdown
## [METHOD] /endpoint/path

Brief description of what this endpoint does.

### Authentication Required

Yes/No - If yes, specify required roles or permissions

### Request

#### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | integer | Yes | Unique identifier |

#### Query Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| page | integer | No | 1 | Page number |
| pageSize | integer | No | 10 | Items per page |
| sortBy | string | No | created | Sort field |
| sortOrder | string | No | desc | asc or desc |

#### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| Authorization | Yes | Bearer token |
| Content-Type | Yes | application/json |

#### Request Body

```json
{
  "field1": "string",
  "field2": 123,
  "nested": {
    "field3": "value"
  }
}
```

**Field Descriptions:**

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| field1 | string | Yes | Description | Max 100 chars |
| field2 | integer | Yes | Description | Min: 1, Max: 1000 |
| nested.field3 | string | No | Description | Enum: val1, val2 |

### Response

#### Success Response (200 OK)

```json
{
  "data": {
    "id": 123,
    "field1": "value",
    "createdAt": "2024-01-15T10:30:00Z"
  },
  "meta": {
    "timestamp": "2024-01-15T10:30:00Z",
    "requestId": "abc-123"
  }
}
```

**Response Fields:**

| Field | Type | Description |
|-------|------|-------------|
| data.id | integer | Unique identifier |
| data.field1 | string | Description |
| data.createdAt | datetime | ISO 8601 format |
| meta.timestamp | datetime | Response timestamp |
| meta.requestId | string | Request tracking ID |

#### Error Responses

**400 Bad Request**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request data",
    "details": [
      {
        "field": "field1",
        "message": "Field is required"
      }
    ]
  }
}
```

**401 Unauthorized**
```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or expired token"
  }
}
```

**403 Forbidden**
```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "Insufficient permissions"
  }
}
```

**404 Not Found**
```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Resource not found"
  }
}
```

**500 Internal Server Error**
```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "An unexpected error occurred",
    "requestId": "abc-123"
  }
}
```

### Example Request

#### cURL
```bash
curl -X POST https://api.example.com/v1/resources \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "field1": "value",
    "field2": 123
  }'
```

#### C#
```csharp
using var client = new HttpClient();
client.DefaultRequestHeaders.Authorization = 
    new AuthenticationHeaderValue("Bearer", "YOUR_TOKEN");

var content = new StringContent(
    JsonSerializer.Serialize(new { field1 = "value", field2 = 123 }),
    Encoding.UTF8,
    "application/json");

var response = await client.PostAsync(
    "https://api.example.com/v1/resources",
    content);

var result = await response.Content.ReadAsStringAsync();
```

#### TypeScript/Angular
```typescript
import { HttpClient, HttpHeaders } from '@angular/common/http';

const headers = new HttpHeaders({
  'Authorization': `Bearer ${token}`,
  'Content-Type': 'application/json'
});

this.http.post(
  'https://api.example.com/v1/resources',
  { field1: 'value', field2: 123 },
  { headers }
).subscribe(response => {
  console.log(response);
});
```

### Notes

- Important information about this endpoint
- Behavioral quirks or caveats
- Performance considerations
- Related endpoints
```

### 3. Common Patterns

Document these consistently across endpoints:

**Pagination:**
```markdown
### Pagination

Paginated endpoints return data in this format:

```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "pageSize": 10,
    "totalItems": 150,
    "totalPages": 15,
    "hasNext": true,
    "hasPrevious": false
  }
}
```

Use `page` and `pageSize` query parameters to navigate.
```

**Filtering:**
```markdown
### Filtering

Filter results using query parameters:
- `status=active` - Filter by status
- `createdAfter=2024-01-01` - Filter by date
- `search=term` - Full-text search

Multiple filters can be combined.
```

**Sorting:**
```markdown
### Sorting

Sort results using `sortBy` and `sortOrder` parameters:
- `sortBy=createdAt&sortOrder=desc` - Newest first
- `sortBy=name&sortOrder=asc` - Alphabetical

Sortable fields: id, name, createdAt, updatedAt
```

**Batch Operations:**
```markdown
### Batch Operations

Process multiple items in a single request:

```json
{
  "items": [
    { "id": 1, "action": "update", "data": {...} },
    { "id": 2, "action": "delete" }
  ]
}
```

Response includes status for each item:

```json
{
  "results": [
    { "id": 1, "status": "success" },
    { "id": 2, "status": "error", "message": "Not found" }
  ]
}
```
```

### 4. Error Code Reference

Create a comprehensive error code table:

```markdown
## Error Codes

| Code | HTTP Status | Description | Resolution |
|------|-------------|-------------|------------|
| VALIDATION_ERROR | 400 | Invalid input | Check request format |
| UNAUTHORIZED | 401 | Missing/invalid token | Authenticate first |
| FORBIDDEN | 403 | Insufficient permissions | Contact admin |
| NOT_FOUND | 404 | Resource not found | Verify ID exists |
| CONFLICT | 409 | Resource conflict | Check unique constraints |
| RATE_LIMIT_EXCEEDED | 429 | Too many requests | Wait and retry |
| INTERNAL_ERROR | 500 | Server error | Contact support |
| SERVICE_UNAVAILABLE | 503 | Service down | Retry later |
```

### 5. Common Response Structures

Document shared models:

```markdown
## Common Models

### User Object

```json
{
  "id": 123,
  "username": "john.doe",
  "email": "john@example.com",
  "firstName": "John",
  "lastName": "Doe",
  "roles": ["user", "admin"],
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

### Address Object

```json
{
  "street": "123 Main St",
  "city": "Springfield",
  "state": "IL",
  "zipCode": "62701",
  "country": "US"
}
```
```

### 6. Webhooks (if applicable)

```markdown
## Webhooks

Subscribe to events by registering a webhook URL.

### Event Types

- `resource.created` - New resource created
- `resource.updated` - Resource modified
- `resource.deleted` - Resource removed

### Webhook Payload

```json
{
  "event": "resource.created",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "id": 123,
    "...": "..."
  }
}
```

### Webhook Security

Verify webhook signature using HMAC-SHA256:
```
X-Webhook-Signature: sha256={signature}
```
```

## Documentation Quality Checklist

Before finalizing API documentation:

- [ ] All endpoints are documented
- [ ] Request/response examples are accurate
- [ ] All parameters are described
- [ ] Error responses are documented
- [ ] Authentication requirements are clear
- [ ] Code examples work and are tested
- [ ] Common patterns are explained
- [ ] Version number is specified
- [ ] Rate limits are documented
- [ ] Base URL is correct
- [ ] Response field descriptions are complete
- [ ] Data types are specified
- [ ] Required/optional fields are marked
- [ ] Constraints are documented (min/max, enums, etc.)

## C# XML Documentation

For .NET APIs, also include XML comments in code:

```csharp
/// <summary>
/// Creates a new resource
/// </summary>
/// <param name="request">Resource creation request</param>
/// <returns>Created resource with ID</returns>
/// <response code="201">Resource created successfully</response>
/// <response code="400">Invalid request data</response>
/// <response code="401">Unauthorized</response>
[HttpPost]
[ProducesResponseType(typeof(ResourceDto), StatusCodes.Status201Created)]
[ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
public async Task<ActionResult<ResourceDto>> CreateResource(
    [FromBody] CreateResourceRequest request)
{
    // Implementation
}
```

## Swagger/OpenAPI Integration

For ASP.NET Core, configure Swagger:

```csharp
// Program.cs or Startup.cs
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "API Name",
        Version = "v1",
        Description = "API Description",
        Contact = new OpenApiContact
        {
            Name = "Team Name",
            Email = "team@example.com"
        }
    });

    // Include XML comments
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    options.IncludeXmlComments(xmlPath);
});
```

## Best Practices

1. **Keep Examples Current**: Test all code examples regularly
2. **Be Specific**: Avoid vague descriptions like "some data"
3. **Show Real Data**: Use realistic examples, not foo/bar
4. **Document Edge Cases**: Explain special behaviors
5. **Version Changes**: Track what changed between versions
6. **Think Developer-First**: Write for the API consumer
7. **Test Authentication**: Ensure auth examples work
8. **Validate JSON**: Ensure all JSON examples are valid
9. **Update Promptly**: Update docs when API changes
10. **Get Feedback**: Ask API users if docs are clear
