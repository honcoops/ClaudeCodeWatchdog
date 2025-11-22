---
name: readme-generator
description: Generates comprehensive README.md files following consistent documentation standards for software projects, including setup, architecture, and maintenance information
---

# README Generator Skill

This skill creates well-structured, comprehensive README.md files for software projects with consistent formatting and complete information.

## When to Use This Skill

Use this skill when:
- Starting a new project or repository
- Documenting existing projects that lack proper READMEs
- Standardizing documentation across multiple projects
- Creating documentation for maintenance mode applications
- Onboarding new team members to a project

## README Structure

Generate READMEs with the following sections:

### 1. Project Title and Description

```markdown
# Project Name

Brief one-line description of what the project does.

More detailed description (2-3 sentences) explaining the purpose, 
context, and key functionality of the project.
```

### 2. Status Badge (Optional but Recommended)

Include maintenance status:
- **Active Development** - Actively maintained and enhanced
- **Maintenance Mode** - Bug fixes only, no new features
- **Deprecated** - No longer maintained
- **Legacy** - Stable but outdated technology

### 3. Table of Contents

For longer READMEs (>5 sections), include a table of contents:
```markdown
## Table of Contents
- [Overview](#overview)
- [Technology Stack](#technology-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Architecture](#architecture)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
```

### 4. Overview Section

Provide context:
- What problem does this solve?
- Who is the intended user/audience?
- What are the key features?
- How does it fit into the larger system?

### 5. Technology Stack

List all technologies with versions:
```markdown
## Technology Stack

- **Backend**: .NET 8.0, C# 12
- **Frontend**: Angular 16.2, TypeScript 5.0
- **Database**: MySQL 8.0, Oracle 19c
- **Data Warehouse**: Snowflake
- **Authentication**: Azure AD
- **Hosting**: Azure App Service
- **CI/CD**: Azure DevOps
```

### 6. Prerequisites

List required software and tools:
```markdown
## Prerequisites

Before you begin, ensure you have:
- .NET 8.0 SDK or later
- Node.js 18.x or later
- MySQL 8.0 or compatible database
- Visual Studio 2022 or VS Code
- Git
```

### 7. Installation

Provide step-by-step setup:
```markdown
## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/org/project.git
   cd project
   ```

2. Restore backend dependencies:
   ```bash
   dotnet restore
   ```

3. Install frontend dependencies:
   ```bash
   cd ClientApp
   npm install
   ```

4. Set up configuration (see Configuration section)

5. Run database migrations:
   ```bash
   dotnet ef database update
   ```
```

### 8. Configuration

Document configuration requirements:
```markdown
## Configuration

### appsettings.json

Create `appsettings.Development.json` (not committed to git):

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=mydb;User=user;Password=pass;"
  },
  "AppSettings": {
    "ApiKey": "your-api-key",
    "Environment": "Development"
  }
}
```

### Environment Variables

Required environment variables:
- `ASPNETCORE_ENVIRONMENT` - Set to Development/Staging/Production
- `DATABASE_CONNECTION` - Database connection string (production)
```

### 9. Usage

Explain how to run the application:
```markdown
## Usage

### Development

Run the backend:
```bash
dotnet run
```

Run the frontend (in separate terminal):
```bash
cd ClientApp
npm start
```

Access the application at: http://localhost:5000

### Production

See [Deployment](#deployment) section.
```

### 10. Architecture

Provide high-level architecture overview:
```markdown
## Architecture

### Project Structure

```
/
├── Controllers/          # API endpoints
├── Services/            # Business logic layer
├── Data/                # Data access layer
│   ├── Entities/        # Database models
│   └── Repositories/    # Data repositories
├── ClientApp/           # Angular frontend
│   ├── src/
│   │   ├── app/
│   │   │   ├── components/
│   │   │   ├── services/
│   │   │   └── models/
└── appsettings.json     # Configuration
```

### Key Components

- **API Layer**: RESTful API built with ASP.NET Core
- **Service Layer**: Business logic and orchestration
- **Data Layer**: Entity Framework Core with repository pattern
- **Frontend**: Angular SPA with TypeScript

### External Dependencies

- **Workday API**: Employee data synchronization
- **Snowflake**: Data warehouse for analytics
- **Azure AD**: Authentication and authorization
```

### 11. Development

Include development guidelines:
```markdown
## Development

### Coding Standards

- Follow C# coding conventions
- Use async/await for I/O operations
- Document public APIs with XML comments
- Follow Angular style guide for frontend

### Running Tests

```bash
# Backend tests
dotnet test

# Frontend tests
cd ClientApp
npm test
```

### Debugging

#### Backend
- Use Visual Studio or VS Code debugger
- Set breakpoints in .cs files
- Launch configuration in `.vscode/launch.json`

#### Frontend
- Use Chrome DevTools
- Angular DevTools extension recommended
```

### 12. Testing

Document testing approach:
```markdown
## Testing

### Unit Tests
- Location: `Tests/UnitTests/`
- Framework: xUnit
- Run: `dotnet test --filter Category=Unit`

### Integration Tests
- Location: `Tests/IntegrationTests/`
- Framework: xUnit + TestServer
- Run: `dotnet test --filter Category=Integration`

### E2E Tests
- Location: `ClientApp/e2e/`
- Framework: Cypress
- Run: `npm run e2e`
```

### 13. Deployment

Explain deployment process:
```markdown
## Deployment

### Staging

Automatic deployment via Azure DevOps on merge to `develop` branch.

### Production

1. Create release branch: `release/vX.Y.Z`
2. Update version numbers
3. Create pull request to `main`
4. After approval and merge, tag release
5. Azure DevOps pipeline deploys automatically

### Manual Deployment

```bash
# Build
dotnet publish -c Release -o ./publish

# Deploy to Azure
az webapp deployment source config-zip \
  --resource-group myResourceGroup \
  --name myAppName \
  --src ./publish.zip
```
```

### 14. Troubleshooting

Include common issues:
```markdown
## Troubleshooting

### Database Connection Issues

**Problem**: Cannot connect to database
**Solution**: 
1. Verify connection string in appsettings.json
2. Ensure database server is running
3. Check firewall rules

### Build Errors

**Problem**: Package restore fails
**Solution**:
```bash
dotnet nuget locals all --clear
dotnet restore
```

### Common Issues

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for comprehensive guide.
```

### 15. Contributing

If open source or team collaboration:
```markdown
## Contributing

1. Create a feature branch: `feature/my-feature`
2. Make your changes
3. Add tests
4. Submit pull request
5. Await code review

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.
```

### 16. Additional Documentation

Link to other docs:
```markdown
## Additional Documentation

- [Architecture Documentation](docs/ARCHITECTURE.md)
- [API Documentation](docs/API.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [Change Log](CHANGELOG.md)
```

### 17. License and Contact

```markdown
## License

Copyright © 2024 TeamHealth. All rights reserved.

## Contact

- **Project Lead**: [Name]
- **Team**: [Team Name]
- **Support**: [Email or Slack channel]
```

## Customization Guidelines

Adapt the README based on:

1. **Project Size**: Smaller projects need fewer sections
2. **Audience**: Internal tools vs open source vs customer-facing
3. **Maturity**: Active development vs maintenance mode
4. **Complexity**: Simple apps vs enterprise systems

## Quality Checklist

Before finalizing README, ensure:
- [ ] All commands are tested and work
- [ ] Version numbers are current
- [ ] Links are valid and not broken
- [ ] Screenshots/diagrams are included if helpful
- [ ] Setup instructions are complete for new developer
- [ ] Contact information is current
- [ ] Configuration examples don't include secrets
- [ ] Markdown renders correctly

## Best Practices

- Keep it updated as the project evolves
- Use code blocks with language identifiers
- Include visual aids (diagrams, screenshots) when helpful
- Write for someone unfamiliar with the project
- Test setup instructions on clean environment
- Use relative links for internal documentation
- Keep line length reasonable (80-120 characters)
