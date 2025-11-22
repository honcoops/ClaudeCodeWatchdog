---
name: type-error-resolution
description: Diagnoses and resolves type errors in TypeScript and C# code, including nullable reference types, generics, and type mismatches
---

# Type Error Resolution Skill

This skill helps diagnose and fix type errors in TypeScript (Angular) and C# (.NET) code systematically.

## When to Use This Skill

Use this skill when:
- Encountering TypeScript compilation errors
- Resolving C# type mismatch errors
- Dealing with nullable reference type warnings
- Working with generic type constraints
- Fixing type inference issues
- Resolving implicit/explicit conversion errors

## Error Resolution Process

### Step 1: Identify the Error

Read the error message carefully and extract:
- Error code (e.g., TS2322, CS0029)
- File and line number
- Type involved
- Expected vs actual type

### Step 2: Classify the Error Type

Determine which category:
1. **Type Mismatch** - Incompatible types
2. **Null/Undefined** - Nullable reference issues
3. **Generic Constraints** - Generic type parameter issues
4. **Type Inference** - Compiler can't infer type
5. **Access Violations** - Accessing non-existent properties
6. **Async/Promise Types** - Promise/Task type issues

### Step 3: Apply Appropriate Fix

Use the resolution strategies below based on error type.

## TypeScript Error Patterns

### TS2322: Type X is not assignable to type Y

**Common Causes:**
1. Wrong type assignment
2. Missing properties in object literal
3. Union type not narrowed
4. Incorrect generic type argument

**Resolution Strategies:**

**Strategy 1: Fix the Type Assignment**
```typescript
// ERROR
let count: number = "123";

// FIX
let count: number = 123;
// OR if string is intended
let count: string = "123";
```

**Strategy 2: Add Missing Properties**
```typescript
interface User {
  id: number;
  name: string;
  email: string;
}

// ERROR
const user: User = {
  id: 1,
  name: "John"
  // missing email
};

// FIX
const user: User = {
  id: 1,
  name: "John",
  email: "john@example.com"
};
```

**Strategy 3: Narrow Union Types**
```typescript
function processValue(value: string | number) {
  // ERROR: Property 'toFixed' does not exist on type 'string | number'
  return value.toFixed(2);
}

// FIX: Type guard
function processValue(value: string | number) {
  if (typeof value === 'number') {
    return value.toFixed(2);
  }
  return parseFloat(value).toFixed(2);
}
```

### TS2531: Object is possibly 'null' or 'undefined'

**Resolution Strategies:**

**Strategy 1: Optional Chaining**
```typescript
// ERROR
const userName = user.profile.name;

// FIX
const userName = user?.profile?.name;
```

**Strategy 2: Nullish Coalescing**
```typescript
// FIX with default value
const userName = user?.profile?.name ?? 'Unknown';
```

**Strategy 3: Type Guard**
```typescript
if (user && user.profile) {
  const userName = user.profile.name; // Safe
}
```

**Strategy 4: Non-null Assertion (use sparingly)**
```typescript
// Only use if you're CERTAIN it's not null
const userName = user!.profile!.name;
```

### TS2339: Property X does not exist on type Y

**Common Causes:**
1. Typo in property name
2. Property exists but type definition missing
3. Wrong type imported

**Resolution Strategies:**

**Strategy 1: Fix Typo**
```typescript
// ERROR
user.usrName

// FIX
user.userName
```

**Strategy 2: Update Interface**
```typescript
// ERROR: Property 'role' does not exist on type 'User'
interface User {
  id: number;
  name: string;
}

// FIX: Add missing property
interface User {
  id: number;
  name: string;
  role: string;
}
```

**Strategy 3: Type Assertion (temporary fix)**
```typescript
// Temporary fix while type definitions are updated
(user as any).newProperty
// Better: extend the interface properly
```

### TS2345: Argument of type X is not assignable to parameter of type Y

**Resolution Strategies:**

**Strategy 1: Fix Argument Type**
```typescript
function getId(id: number): void { }

// ERROR
getId("123");

// FIX
getId(123);
// OR
getId(parseInt("123"));
```

**Strategy 2: Update Function Signature**
```typescript
// If function should accept both
function getId(id: number | string): void {
  const numId = typeof id === 'string' ? parseInt(id) : id;
  // use numId
}
```

### TS2740: Type X is missing the following properties from type Y

**Resolution Strategies:**

**Strategy 1: Implement Missing Properties**
```typescript
interface Config {
  apiUrl: string;
  timeout: number;
  retryCount: number;
}

// ERROR
const config: Config = {
  apiUrl: "https://api.example.com",
  timeout: 5000
  // missing retryCount
};

// FIX
const config: Config = {
  apiUrl: "https://api.example.com",
  timeout: 5000,
  retryCount: 3
};
```

**Strategy 2: Use Partial Type**
```typescript
// If not all properties are always required
const config: Partial<Config> = {
  apiUrl: "https://api.example.com"
};
```

**Strategy 3: Make Properties Optional**
```typescript
interface Config {
  apiUrl: string;
  timeout: number;
  retryCount?: number; // Now optional
}
```

### TS2556: Expected X arguments, but got Y

**Resolution Strategies:**

**Strategy 1: Provide Missing Arguments**
```typescript
function createUser(name: string, email: string) { }

// ERROR
createUser("John");

// FIX
createUser("John", "john@example.com");
```

**Strategy 2: Make Parameters Optional**
```typescript
function createUser(name: string, email?: string) {
  // Handle optional email
}
```

**Strategy 3: Use Default Parameters**
```typescript
function createUser(name: string, email: string = "no-email@example.com") { }
```

### TS7006: Parameter X implicitly has an 'any' type

**Resolution Strategies:**

**Strategy 1: Add Explicit Type**
```typescript
// ERROR (with strict mode)
function processItem(item) { }

// FIX
function processItem(item: Item) { }
```

**Strategy 2: Infer from Usage**
```typescript
interface Item {
  id: number;
  name: string;
}

function processItem(item: Item) { }
```

## C# Error Patterns

### CS0029: Cannot implicitly convert type X to Y

**Resolution Strategies:**

**Strategy 1: Explicit Cast**
```csharp
// ERROR
int x = 5;
double y = 2.5;
int result = x + y;

// FIX
int result = x + (int)y;
// OR preserve precision
double result = x + y;
```

**Strategy 2: Use Conversion Methods**
```csharp
// ERROR
string strNum = "123";
int num = strNum;

// FIX
int num = int.Parse(strNum);
// OR safer
int num = int.TryParse(strNum, out int result) ? result : 0;
```

### CS0266: Cannot implicitly convert type X to Y (explicit conversion exists)

**Resolution Strategies:**

**Strategy 1: Add Explicit Cast**
```csharp
// ERROR
long bigNumber = 1000000;
int smallNumber = bigNumber;

// FIX (with potential data loss)
int smallNumber = (int)bigNumber;

// BETTER: Check for overflow
int smallNumber = checked((int)bigNumber); // Throws if overflow
// OR
int smallNumber = bigNumber > int.MaxValue ? int.MaxValue : (int)bigNumber;
```

### CS8600: Converting null literal or possible null value to non-nullable type

**Resolution Strategies:**

**Strategy 1: Handle Null Case**
```csharp
// ERROR (with nullable reference types enabled)
string? nullableString = GetNullableString();
string nonNullableString = nullableString;

// FIX: Null check
string nonNullableString = nullableString ?? "default";
// OR
if (nullableString != null)
{
    string nonNullableString = nullableString;
}
```

**Strategy 2: Use Null-Forgiving Operator**
```csharp
// Only if you're CERTAIN it's not null
string nonNullableString = nullableString!;
```

### CS8602: Dereference of a possibly null reference

**Resolution Strategies:**

**Strategy 1: Null-Conditional Operator**
```csharp
// ERROR
string? name = GetName();
int length = name.Length;

// FIX
int? length = name?.Length;
// OR with default
int length = name?.Length ?? 0;
```

**Strategy 2: Null Check**
```csharp
if (name != null)
{
    int length = name.Length; // Safe
}
```

### CS8604: Possible null reference argument

**Resolution Strategies:**

**Strategy 1: Null Check Before Passing**
```csharp
void ProcessName(string name) { }

// ERROR
string? nullableName = GetName();
ProcessName(nullableName);

// FIX
if (nullableName != null)
{
    ProcessName(nullableName);
}
// OR
ProcessName(nullableName ?? "Unknown");
```

**Strategy 2: Change Parameter to Nullable**
```csharp
void ProcessName(string? name)
{
    if (name == null) return;
    // process name
}
```

### CS0452: Type parameter constraint mismatch

**Resolution Strategies:**

**Strategy 1: Fix Generic Constraints**
```csharp
// ERROR
interface IRepository<T> where T : class
{
}

class EntityRepository<T> : IRepository<T> where T : struct
{
    // Constraint mismatch: struct vs class
}

// FIX: Match constraints
class EntityRepository<T> : IRepository<T> where T : class
{
}
```

**Strategy 2: Remove Conflicting Constraints**
```csharp
// If constraint too restrictive
class EntityRepository<T> : IRepository<T>
{
    // No constraint if not needed
}
```

### CS1061: Type X does not contain a definition for Y

**Resolution Strategies:**

**Strategy 1: Add Using Directive**
```csharp
// ERROR: 'List<T>' doesn't have 'FirstOrDefault'
var list = new List<int>();
var first = list.FirstOrDefault();

// FIX
using System.Linq;
```

**Strategy 2: Cast to Correct Type**
```csharp
// ERROR
object obj = GetObject();
obj.CustomMethod();

// FIX
if (obj is MyClass myClass)
{
    myClass.CustomMethod();
}
```

## Angular-Specific Type Issues

### Reactive Forms Type Safety

```typescript
// ERROR: Type safety issues with FormControl
import { FormControl } from '@angular/forms';

const nameControl = new FormControl('');
const value: string = nameControl.value; // Could be null

// FIX: Use typed FormControl
const nameControl = new FormControl<string>('', { nonNullable: true });
const value: string = nameControl.value; // Guaranteed string
```

### HttpClient Response Types

```typescript
// ERROR: Response type unknown
this.http.get('/api/users').subscribe(data => {
  console.log(data.users); // No type safety
});

// FIX: Specify response type
interface UsersResponse {
  users: User[];
}

this.http.get<UsersResponse>('/api/users').subscribe(data => {
  console.log(data.users); // Type-safe
});
```

### Observable Type Issues

```typescript
// ERROR: Observable type mismatch
getData(): Observable<string> {
  return this.http.get('/api/data'); // Returns Observable<Object>
}

// FIX: Map to correct type
getData(): Observable<string> {
  return this.http.get<{ data: string }>('/api/data').pipe(
    map(response => response.data)
  );
}
```

## Best Practices

1. **Enable Strict Mode**: Use strict TypeScript and C# nullable settings
2. **Type Everything**: Avoid `any` and implicit types
3. **Use Type Guards**: Narrow types before use
4. **Handle Nulls Explicitly**: Don't rely on null-forgiving operators
5. **Leverage Type Inference**: Let compiler infer when obvious
6. **Update Type Definitions**: Keep interfaces synchronized with data
7. **Test Edge Cases**: Test with null/undefined values
8. **Use Generic Constraints**: Constrain generic types appropriately
9. **Document Type Decisions**: Comment non-obvious type choices
10. **Refactor Incrementally**: Fix types gradually in large codebases

## Resolution Checklist

- [ ] Error message read and understood
- [ ] Root cause identified
- [ ] Type mismatch analyzed
- [ ] Fix applied (not suppressed)
- [ ] Code compiles without warnings
- [ ] Tests updated if needed
- [ ] Similar errors checked elsewhere
- [ ] Type definitions updated if needed
- [ ] Code review for type safety
