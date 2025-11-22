---
name: lint-error-resolution
description: Resolves linting errors and warnings in TypeScript/JavaScript (ESLint) and C# (Roslyn analyzers), following best practices and coding standards
---

# Lint Error Resolution Skill

This skill helps identify and fix linting errors and warnings in TypeScript/JavaScript and C# code systematically.

## When to Use This Skill

Use this skill when:
- Encountering ESLint errors or warnings
- Resolving C# code analysis warnings
- Enforcing code style consistency
- Preparing code for pull request review
- Setting up new linting rules
- Refactoring to meet coding standards

## ESLint Error Patterns

### no-unused-vars / @typescript-eslint/no-unused-vars

**Error**: Variable declared but never used

**Resolution Strategies:**

**Strategy 1: Remove Unused Variable**
```typescript
// ERROR
const unused = 'value';
const used = 'another';
console.log(used);

// FIX
const used = 'another';
console.log(used);
```

**Strategy 2: Prefix with Underscore (intentionally unused)**
```typescript
// When parameter must exist but isn't used
function handleEvent(_event: Event, data: any) {
  // Only using data, but event must be in signature
  console.log(data);
}
```

**Strategy 3: Use Variable**
```typescript
// ERROR
const config = loadConfig();
// config never used

// FIX
const config = loadConfig();
applyConfig(config);
```

### no-explicit-any / @typescript-eslint/no-explicit-any

**Error**: Unexpected any type

**Resolution Strategies:**

**Strategy 1: Define Proper Type**
```typescript
// ERROR
function process(data: any) {
  return data.value;
}

// FIX
interface DataType {
  value: string;
}

function process(data: DataType) {
  return data.value;
}
```

**Strategy 2: Use Generic**
```typescript
// ERROR
function identity(arg: any): any {
  return arg;
}

// FIX
function identity<T>(arg: T): T {
  return arg;
}
```

**Strategy 3: Use unknown for Type-Safe any**
```typescript
// When type truly unknown
function process(data: unknown) {
  if (typeof data === 'object' && data !== null && 'value' in data) {
    return (data as { value: string }).value;
  }
}
```

### prefer-const

**Error**: Variable never reassigned, use const instead

**Resolution Strategies:**

```typescript
// ERROR
let name = 'John';
console.log(name); // Never reassigned

// FIX
const name = 'John';
console.log(name);

// When variable IS reassigned, keep let
let counter = 0;
counter++; // This is fine with let
```

### @typescript-eslint/no-floating-promises

**Error**: Promise returned without handling

**Resolution Strategies:**

**Strategy 1: Await the Promise**
```typescript
// ERROR
async function init() {
  loadData(); // Returns promise but not awaited
}

// FIX
async function init() {
  await loadData();
}
```

**Strategy 2: Handle with then/catch**
```typescript
// FIX
function init() {
  loadData()
    .then(data => process(data))
    .catch(error => handleError(error));
}
```

**Strategy 3: Explicitly Void (fire-and-forget)**
```typescript
// When you intentionally don't want to wait
function init() {
  void loadData(); // Explicit fire-and-forget
}
```

### @angular-eslint/no-empty-lifecycle-method

**Error**: Empty lifecycle method

**Resolution Strategies:**

**Strategy 1: Remove Empty Method**
```typescript
// ERROR
export class MyComponent implements OnInit {
  ngOnInit(): void {
    // Empty
  }
}

// FIX: Remove method and interface
export class MyComponent {
  // No ngOnInit needed
}
```

**Strategy 2: Add Implementation**
```typescript
// FIX: Implement properly
export class MyComponent implements OnInit {
  ngOnInit(): void {
    this.loadData();
  }
}
```

### @typescript-eslint/no-non-null-assertion

**Error**: Non-null assertion used

**Resolution Strategies:**

**Strategy 1: Proper Null Check**
```typescript
// ERROR
const value = maybeNull!.property;

// FIX
const value = maybeNull?.property;
// OR with default
const value = maybeNull?.property ?? defaultValue;
```

**Strategy 2: Type Guard**
```typescript
// FIX
if (maybeNull) {
  const value = maybeNull.property; // Type narrowed
}
```

### no-console

**Error**: Unexpected console statement

**Resolution Strategies:**

**Strategy 1: Remove Console Logs**
```typescript
// ERROR
console.log('Debug info');

// FIX: Remove for production code
```

**Strategy 2: Use Proper Logging**
```typescript
// FIX: Use logging service
import { LoggerService } from './logger.service';

constructor(private logger: LoggerService) {}

this.logger.debug('Debug info');
```

**Strategy 3: Disable for Specific Line (rarely)**
```typescript
// Only for debugging, remove before commit
// eslint-disable-next-line no-console
console.log('Temporary debug');
```

### @typescript-eslint/no-empty-function

**Error**: Empty function

**Resolution Strategies:**

**Strategy 1: Add Implementation**
```typescript
// ERROR
onClick() {}

// FIX
onClick() {
  this.handleClick();
}
```

**Strategy 2: Remove if Unnecessary**
```typescript
// ERROR
<button (click)="onClick()"></button>

onClick() {}

// FIX: Remove handler if not needed
<button></button>
```

**Strategy 3: Add Comment Explaining Why Empty**
```typescript
// FIX: Document intentional no-op
onClick() {
  // Intentionally empty - required by interface but not needed for this implementation
}
```

### prefer-arrow-callback

**Error**: Use arrow function instead of function expression

**Resolution Strategies:**

```typescript
// ERROR
array.map(function(item) {
  return item * 2;
});

// FIX
array.map(item => item * 2);
// OR with block
array.map(item => {
  return item * 2;
});
```

### @typescript-eslint/explicit-function-return-type

**Error**: Missing return type annotation

**Resolution Strategies:**

```typescript
// ERROR
function calculate(a: number, b: number) {
  return a + b;
}

// FIX
function calculate(a: number, b: number): number {
  return a + b;
}

// For void functions
function logMessage(message: string): void {
  console.log(message);
}
```

### no-shadow

**Error**: Variable shadows outer scope variable

**Resolution Strategies:**

```typescript
// ERROR
const name = 'Outer';

function process() {
  const name = 'Inner'; // Shadows outer 'name'
  console.log(name);
}

// FIX: Rename inner variable
const name = 'Outer';

function process() {
  const processName = 'Inner';
  console.log(processName);
}
```

## C# Analyzer Patterns

### CA1052: Static holder types should be sealed

**Resolution Strategies:**

```csharp
// ERROR
public class Helpers
{
    public static void DoSomething() { }
}

// FIX
public sealed class Helpers
{
    public static void DoSomething() { }
}

// BETTER: Make static class
public static class Helpers
{
    public static void DoSomething() { }
}
```

### CA1062: Validate arguments of public methods

**Resolution Strategies:**

```csharp
// ERROR
public void Process(string input)
{
    Console.WriteLine(input.Length); // No null check
}

// FIX: Add null check
public void Process(string input)
{
    if (input == null)
        throw new ArgumentNullException(nameof(input));
    
    Console.WriteLine(input.Length);
}

// OR with C# 10+
public void Process(string input)
{
    ArgumentNullException.ThrowIfNull(input);
    Console.WriteLine(input.Length);
}

// OR use nullable reference types
public void Process(string? input)
{
    if (input == null) return;
    Console.WriteLine(input.Length);
}
```

### CA1303: Do not pass literals as localized parameters

**Resolution Strategies:**

```csharp
// ERROR
throw new Exception("Error occurred");

// FIX: Use constants or resources
private const string ErrorMessage = "Error occurred";
throw new Exception(ErrorMessage);

// OR with resource file
throw new Exception(Resources.ErrorOccurred);
```

### CA1707: Identifiers should not contain underscores

**Resolution Strategies:**

```csharp
// ERROR
public int user_id { get; set; }

// FIX: Use PascalCase
public int UserId { get; set; }

// For constants (exception allowed)
private const string API_KEY = "key"; // OK for constants
```

### CA1822: Mark members as static

**Resolution Strategies:**

```csharp
// ERROR: Method doesn't use instance members
public class Calculator
{
    public int Add(int a, int b)
    {
        return a + b; // Doesn't use 'this'
    }
}

// FIX
public class Calculator
{
    public static int Add(int a, b)
    {
        return a + b;
    }
}
```

### CA2007: Do not directly await a Task

**Resolution Strategies:**

```csharp
// ERROR
public async Task ProcessAsync()
{
    await GetDataAsync();
}

// FIX: Use ConfigureAwait
public async Task ProcessAsync()
{
    await GetDataAsync().ConfigureAwait(false);
}

// In UI code (ASP.NET Core), ConfigureAwait(false) is the default
// and this warning can be suppressed or disabled
```

### IDE0058: Expression value is never used

**Resolution Strategies:**

```csharp
// ERROR
public void Process()
{
    GetValue(); // Return value ignored
}

// FIX 1: Use return value
public void Process()
{
    var value = GetValue();
    UseValue(value);
}

// FIX 2: Explicitly discard
public void Process()
{
    _ = GetValue();
}

// FIX 3: If method should be void
public void Process()
{
    PerformAction(); // Method now returns void
}
```

### CA1816: Dispose methods should call SuppressFinalize

**Resolution Strategies:**

```csharp
// ERROR
public class MyResource : IDisposable
{
    public void Dispose()
    {
        // Cleanup
    }
}

// FIX
public class MyResource : IDisposable
{
    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    protected virtual void Dispose(bool disposing)
    {
        if (disposing)
        {
            // Cleanup managed resources
        }
    }
}
```

### CA1031: Do not catch general exception types

**Resolution Strategies:**

```csharp
// ERROR
try
{
    DoSomething();
}
catch (Exception ex)
{
    // Too broad
}

// FIX: Catch specific exceptions
try
{
    DoSomething();
}
catch (IOException ex)
{
    // Handle IO errors
}
catch (InvalidOperationException ex)
{
    // Handle invalid operation
}

// If you must catch all exceptions (rare)
try
{
    DoSomething();
}
catch (Exception ex) when (ex is not StackOverflowException)
{
    // Handle all except critical exceptions
}
```

## Angular-Specific Lint Rules

### @angular-eslint/component-selector

**Error**: Component selector doesn't follow naming convention

**Resolution Strategies:**

```typescript
// ERROR
@Component({
  selector: 'MyComponent',
  template: '...'
})

// FIX: Use kebab-case with prefix
@Component({
  selector: 'app-my-component',
  template: '...'
})
```

### @angular-eslint/use-lifecycle-interface

**Error**: Lifecycle method without implementing interface

**Resolution Strategies:**

```typescript
// ERROR
export class MyComponent {
  ngOnInit() { }
}

// FIX
export class MyComponent implements OnInit {
  ngOnInit(): void { }
}
```

### @angular-eslint/no-output-on-prefix

**Error**: Output property starts with 'on'

**Resolution Strategies:**

```typescript
// ERROR
@Output() onSave = new EventEmitter<void>();

// FIX: Remove 'on' prefix
@Output() save = new EventEmitter<void>();

// Usage in template
<app-component (save)="handleSave()"></app-component>
```

## Configuration and Suppression

### When to Disable Rules

Only disable rules when:
1. Rule conflicts with team conventions
2. False positive that can't be fixed
3. Legacy code being gradually updated

### Disabling Rules Properly

**ESLint:**
```typescript
// Disable for single line
// eslint-disable-next-line rule-name
const value = problematicCode();

// Disable for file (use sparingly)
/* eslint-disable rule-name */

// Disable for block
/* eslint-disable rule-name */
// Code block
/* eslint-enable rule-name */
```

**C# Analyzers:**
```csharp
// Disable for line
#pragma warning disable CA1234
var value = ProblematicCode();
#pragma warning restore CA1234

// Disable for member
[SuppressMessage("Category", "CA1234", Justification = "Reason")]
public void Method() { }

// Configure in .editorconfig (preferred)
[*.cs]
dotnet_diagnostic.CA1234.severity = none
```

## Best Practices

1. **Fix, Don't Suppress**: Resolve issues rather than disabling rules
2. **Understand Why**: Know why a rule exists before disabling
3. **Document Suppressions**: Always include justification comments
4. **Consistent Style**: Follow team conventions consistently
5. **Autofix When Possible**: Use `eslint --fix` and IDE quick fixes
6. **Run Pre-Commit**: Configure pre-commit hooks to catch issues
7. **Address Warnings**: Treat warnings as seriously as errors
8. **Update Gradually**: Introduce new rules incrementally
9. **Team Agreement**: Ensure team agrees on rule configuration
10. **Review Regularly**: Periodically review and update lint config

## Quick Fix Checklist

- [ ] Error message understood
- [ ] Root cause identified
- [ ] Appropriate fix strategy selected
- [ ] Fix applied (not suppressed)
- [ ] Code still functions correctly
- [ ] Tests still pass
- [ ] Similar issues checked elsewhere
- [ ] Linter passes
- [ ] Code style consistent
- [ ] PR ready

## Automated Fixing

**TypeScript/JavaScript:**
```bash
# Fix auto-fixable issues
npm run lint -- --fix
# OR
npx eslint . --fix

# Check remaining issues
npm run lint
```

**C#:**
```bash
# Format code
dotnet format

# Analyze code
dotnet build /p:EnforceCodeStyleInBuild=true

# Fix in IDE
# Use Quick Actions (Ctrl+. or Cmd+.)
```
