---
name: troubleshooting-guide-generator
description: Creates structured troubleshooting documentation for common technical problems with symptoms, diagnostics, and resolution steps
---

# Troubleshooting Guide Generator Skill

This skill creates comprehensive troubleshooting guides that help diagnose and resolve common technical issues systematically.

## When to Use This Skill

Use this skill when:
- Documenting recurring technical problems
- Creating support documentation
- Building knowledge base articles
- Documenting production issues and resolutions
- Creating runbooks for operations teams
- Onboarding support staff

## Troubleshooting Guide Structure

### 1. Issue Title

Use clear, searchable titles:

**Good titles:**
- "Database Connection Timeout Errors"
- "Angular Application Fails to Build After npm Update"
- "Authentication Token Expired Errors"
- "Snowflake Query Performance Degradation"

**Avoid vague titles:**
- "Application Not Working"
- "Error in System"
- "Problem with Login"

### 2. Issue Summary

Provide a brief overview:

```markdown
## Issue: [Title]

**Severity**: Critical / High / Medium / Low
**Affected Components**: List components/services
**Common Occurrence**: How often this typically happens
**Estimated Resolution Time**: X minutes/hours

### Quick Summary

Brief 1-2 sentence description of the problem and its impact.
```

### 3. Symptoms

List observable behaviors that indicate this issue:

```markdown
## Symptoms

Users experiencing this issue will observe:

1. **Primary Symptom**
   - Specific error message or behavior
   - Where it appears (UI, logs, etc.)
   - When it occurs (timing, conditions)

2. **Secondary Symptoms**
   - Related issues that may appear
   - Side effects or cascading problems

3. **User Impact**
   - What users cannot do
   - Business process impact
```

**Example:**

```markdown
## Symptoms

1. **HTTP 500 Errors on Login**
   - Error: "An error occurred while processing your request"
   - Appears on login page after entering credentials
   - Occurs intermittently, affecting ~10% of login attempts

2. **Authentication Token Issues**
   - Users may see "Session expired" immediately after login
   - Some authenticated API calls fail with 401 Unauthorized

3. **User Impact**
   - Users unable to access application
   - Productivity loss during outage
   - Support ticket volume increases
```

### 4. Possible Causes

List potential root causes in order of likelihood:

```markdown
## Possible Causes

### Most Likely

1. **[Cause Name]**
   - Explanation of this cause
   - Why it occurs
   - How to identify if this is the issue

### Less Common

2. **[Another Cause]**
   - Details
   
3. **[Edge Case]**
   - Rare scenario details
```

**Example:**

```markdown
## Possible Causes

### Most Likely

1. **Database Connection Pool Exhaustion**
   - Application runs out of available database connections
   - Occurs under high load or when connections leak
   - Check: Monitor active connections vs pool size

2. **Azure AD Token Validation Failure**
   - Token validation endpoint unreachable
   - Clock skew between servers
   - Check: Review authentication middleware logs

### Less Common

3. **Expired SSL Certificate**
   - HTTPS connection fails due to certificate issues
   - Check: Verify certificate expiration date

4. **Memory Leak in Application**
   - Application runs out of memory over time
   - Check: Monitor memory usage trends
```

### 5. Diagnostic Steps

Provide step-by-step investigation process:

```markdown
## Diagnostic Steps

Follow these steps to identify the root cause:

### Step 1: Check Application Logs

```bash
# View recent error logs
tail -n 100 /var/log/application/error.log

# Filter for specific errors
grep "SqlException" /var/log/application/*.log
```

**What to look for:**
- Specific error messages
- Stack traces indicating failure point
- Timestamp correlation with user reports

### Step 2: Verify Database Connectivity

```sql
-- Check active connections
SELECT COUNT(*) FROM sys.dm_exec_connections;

-- Check blocked queries
SELECT * FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;
```

**Expected results:**
- Connection count below pool max (default: 100)
- No blocked queries

**If problems found:**
- Proceed to Resolution Step X

### Step 3: Check System Resources

```bash
# Check memory usage
free -h

# Check CPU usage
top -bn1 | head -20

# Check disk space
df -h
```

**Warning thresholds:**
- Memory usage > 90%
- CPU sustained > 80%
- Disk usage > 85%

### Step 4: Review Recent Changes

- Check recent deployments (last 24-48 hours)
- Review configuration changes
- Verify no infrastructure changes

**Where to check:**
- Azure DevOps release history
- Git commit log
- Change management tickets
```

### 6. Resolution Steps

Provide clear, actionable solutions:

```markdown
## Resolution

### Immediate Fix (Workaround)

If this is a production emergency, apply this quick fix first:

1. **Restart Application Service**
   ```bash
   az webapp restart --name myapp --resource-group mygroup
   ```
   
2. **Clear Application Cache**
   - Navigate to Azure Portal
   - Select App Service
   - Click "Advanced Tools" → "Go"
   - Select "Debug console" → "CMD"
   - Run: `del /s /q D:\home\site\wwwroot\cache\*`

3. **Verify Resolution**
   - Test login functionality
   - Monitor error logs for 10-15 minutes
   - Check with affected users

**Expected outcome:** Issue should be resolved temporarily
**Duration:** Fix lasts until next deployment or server restart

### Permanent Fix

To prevent this issue from recurring:

#### Solution 1: Increase Connection Pool Size

**When to use:** If diagnostic shows connection pool exhaustion

1. Update appsettings.json:
   ```json
   {
     "ConnectionStrings": {
       "DefaultConnection": "Server=...;Max Pool Size=200;..."
     }
   }
   ```

2. Deploy configuration change

3. Monitor connection usage to ensure adequate headroom

**Testing:**
- Load test with increased pool size
- Verify no connection timeout errors
- Monitor for 24 hours

#### Solution 2: Fix Connection Leak

**When to use:** If connections are not being properly disposed

1. Review code for connection management:
   ```csharp
   // BAD - Connection leak
   var connection = new SqlConnection(connectionString);
   connection.Open();
   // Missing using or dispose
   
   // GOOD - Proper disposal
   using (var connection = new SqlConnection(connectionString))
   {
       connection.Open();
       // Use connection
   } // Automatically disposed
   ```

2. Locate and fix all connection usage

3. Run code analysis tools:
   ```bash
   dotnet build /p:EnforceCodeStyleInBuild=true
   ```

4. Test thoroughly in development

5. Deploy fix to production

**Testing:**
- Monitor connection count over time
- Should remain stable under load
- No growth indicating leaks
```

### 7. Prevention

Explain how to avoid this issue:

```markdown
## Prevention

### Monitoring

Set up alerts to catch this before users are affected:

1. **Application Insights Alert**
   - Metric: Failed Requests > 10 in 5 minutes
   - Action: Email operations team

2. **Database Connection Monitor**
   - Metric: Active Connections > 80% of pool
   - Action: Alert before exhaustion

3. **Log Alert**
   - Pattern: "SqlException.*timeout"
   - Action: Create incident ticket

### Best Practices

1. **Always use `using` statements for database connections**
   ```csharp
   using (var connection = new SqlConnection(connectionString))
   using (var command = new SqlCommand(sql, connection))
   {
       // Code here
   }
   ```

2. **Implement connection retry logic**
   - Use Polly library for transient fault handling
   - Configure exponential backoff

3. **Regular health checks**
   - Endpoint: `/health`
   - Check database connectivity
   - Monitor response times

4. **Load testing before deployment**
   - Test with production-like load
   - Monitor connection usage
   - Identify leaks early

### Code Review Checklist

- [ ] All database connections properly disposed
- [ ] No synchronous blocking calls in async code
- [ ] Connection strings use connection pooling
- [ ] Timeout values are configured appropriately
- [ ] Error handling includes retry logic
```

### 8. Additional Resources

```markdown
## Additional Resources

### Internal Documentation
- [Database Best Practices](docs/database-guidelines.md)
- [Deployment Checklist](docs/deployment.md)
- [Monitoring Dashboard](https://portal.azure.com/...)

### External References
- [Entity Framework Connection Management](https://docs.microsoft.com/...)
- [SQL Server Connection Pooling](https://docs.microsoft.com/...)

### Related Issues
- Issue #234: Similar authentication problems
- KB-1856: Connection pool configuration guide

### Support Contacts
- **Database Team**: database-team@company.com
- **DevOps Team**: #devops-support on Slack
- **On-Call Engineer**: Use PagerDuty escalation
```

### 9. Troubleshooting History

Track issue occurrences:

```markdown
## Issue History

| Date | Affected Users | Root Cause | Resolution | Resolved By |
|------|---------------|------------|------------|-------------|
| 2024-01-15 | ~50 | Connection pool exhaustion | Increased pool size | John D. |
| 2024-02-03 | ~20 | Connection leak in new code | Fixed disposal | Jane S. |

### Patterns Observed
- Typically occurs during peak usage (9-11 AM)
- More common after deployments
- Correlated with batch processing jobs
```

## Quality Checklist

Before publishing a troubleshooting guide:

- [ ] Title is clear and searchable
- [ ] Symptoms are specific and observable
- [ ] Root causes are listed by likelihood
- [ ] Diagnostic steps are actionable
- [ ] Commands/scripts are tested and accurate
- [ ] Resolution steps are clear and complete
- [ ] Both immediate and permanent fixes provided
- [ ] Prevention measures documented
- [ ] Severity level is appropriate
- [ ] Related issues are linked
- [ ] Contact information is current
- [ ] Code examples are formatted properly
- [ ] Testing steps are included

## Best Practices

1. **Write as You Troubleshoot**: Document while resolving the actual issue
2. **Test All Commands**: Verify every command/script works
3. **Use Screenshots**: Visual aids help for UI-based steps
4. **Keep Updated**: Revise as new information emerges
5. **Get Peer Review**: Have another engineer validate
6. **Think Chronologically**: Order steps as you'd actually perform them
7. **Include Timeframes**: How long should each step take?
8. **Note Prerequisites**: Required access, tools, permissions
9. **Explain Why**: Don't just say what to do, explain why
10. **Version Information**: Document which versions affected
