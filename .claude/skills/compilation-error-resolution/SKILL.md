---
name: compilation-error-resolution
description: Diagnoses and resolves compilation errors in TypeScript/Angular and C#/.NET builds, including module resolution, dependency, and configuration issues
---

# Compilation Error Resolution Skill

This skill helps systematically resolve compilation errors in TypeScript/Angular and C#/.NET projects.

## When to Use This Skill

Use this skill when:
- Build fails with compilation errors
- Module resolution errors occur
- Dependency conflicts prevent compilation
- Configuration issues block builds
- Upgrading dependencies breaks compilation
- Setting up new projects or environments

## Compilation Error Process

### Step 1: Read the Error Carefully

Extract critical information:
- Error code/number
- File and line number
- Which phase failed (restore, compile, link)
- Related files or dependencies

### Step 2: Check Common Causes

Most compilation errors fall into these categories:
1. **Missing Dependencies** - Packages not installed
2. **Module Resolution** - Can't find imports
3. **Configuration Issues** - Wrong settings
4. **Version Conflicts** - Incompatible package versions
5. **Syntax Errors** - Code syntax problems
6. **Build Tool Issues** - Webpack, MSBuild problems

### Step 3: Apply Systematic Fixes

Work through fixes from simplest to most complex.

## TypeScript/Angular Build Errors

### Cannot find module 'X' or its corresponding type declarations

**Common Causes:**
1. Package not installed
2. Missing type definitions
3. Wrong import path
4. Module resolution configuration

**Resolution Strategies:**

**Strategy 1: Install Missing Package**
```bash
# ERROR: Cannot find module 'lodash'

# FIX: Install package
npm install lodash

# If TypeScript types needed
npm install --save-dev @types/lodash
```

**Strategy 2: Install Type Definitions**
```bash
# ERROR: Could not find a declaration file for module 'some-package'

# FIX: Install types
npm install --save-dev @types/some-package

# If no types available
# Create types file: src/types/some-package.d.ts
declare module 'some-package';
```

**Strategy 3: Fix Import Path**
```typescript
// ERROR: Cannot find module './utils'

// Wrong - missing file extension or wrong path
import { helper } from './utils';

// FIX 1: Add correct extension
import { helper } from './utils.ts';

// FIX 2: Correct path
import { helper } from '../utils/helper';

// FIX 3: Use path alias (if configured)
import { helper } from '@app/utils/helper';
```

**Strategy 4: Update tsconfig.json**
```json
{
  "compilerOptions": {
    "moduleResolution": "node",
    "baseUrl": "./",
    "paths": {
      "@app/*": ["src/app/*"],
      "@shared/*": ["src/app/shared/*"]
    }
  }
}
```

### Module build failed: Error: ENOENT: no such file or directory

**Resolution Strategies:**

**Strategy 1: File Doesn't Exist**
```bash
# ERROR: ENOENT: no such file or directory 'src/app/missing.ts'

# FIX 1: Create the file
touch src/app/missing.ts

# FIX 2: Fix the import path
# Change from:
import { Something } from './missing';
# To correct path:
import { Something } from './existing';
```

**Strategy 2: Case Sensitivity**
```typescript
// ERROR on Linux/Mac (case-sensitive)
import { User } from './User'; // File is user.ts

// FIX: Match case exactly
import { User } from './user';
```

### Argument of type X is not assignable to parameter of type Y

**Resolution Strategies:**

**Strategy 1: Update to Compatible Version**
```bash
# ERROR after upgrade: Type incompatibility with new version

# FIX: Check breaking changes
# Update code to match new API
# OR downgrade if not ready
npm install package@previous-version
```

**Strategy 2: Fix Type Usage**
```typescript
// ERROR: Type 'string' is not assignable to type 'number'

// FIX: Convert type
const value: number = parseInt(stringValue);

// OR fix the source
const value: string = stringValue; // Keep as string
```

### Property 'X' does not exist on type 'Y'

**Resolution Strategies:**

**Strategy 1: Update Type Definition**
```typescript
// ERROR: Property 'newProp' does not exist on type 'User'

interface User {
  id: number;
  name: string;
  // Add missing property
  newProp: string;
}
```

**Strategy 2: Check Package Version**
```bash
# If property should exist in newer version
npm list package-name
npm install package-name@latest
```

### Circular dependency detected

**Resolution Strategies:**

**Strategy 1: Restructure Imports**
```typescript
// ERROR: Circular dependency between A.ts and B.ts

// BAD:
// A.ts
import { B } from './B';
export class A { b: B; }

// B.ts
import { A } from './A';
export class B { a: A; }

// FIX: Create separate interface file
// types.ts
export interface IUser { }
export interface IOrder { }

// A.ts
import { IOrder } from './types';
export class A { order: IOrder; }

// B.ts
import { IUser } from './types';
export class B { user: IUser; }
```

**Strategy 2: Use Forward Reference**
```typescript
// In Angular
import { forwardRef } from '@angular/core';

@Component({
  providers: [
    { provide: SomeService, useClass: forwardRef(() => SomeServiceImpl) }
  ]
})
```

### Angular: Error: src/app/app.module.ts is missing from the TypeScript compilation

**Resolution Strategies:**

**Strategy 1: Check tsconfig.json**
```json
{
  "files": [
    "src/main.ts",
    "src/polyfills.ts"
  ],
  "include": [
    "src/**/*.ts"
  ],
  "exclude": [
    "node_modules",
    "**/*.spec.ts"
  ]
}
```

**Strategy 2: Restart Development Server**
```bash
# Stop server
# Clear Angular cache
rm -rf .angular/
# Restart
ng serve
```

### npm ERR! peer dependencies conflict

**Resolution Strategies:**

**Strategy 1: Use --legacy-peer-deps**
```bash
# Temporary fix during migration
npm install --legacy-peer-deps
```

**Strategy 2: Resolve Peer Dependencies**
```bash
# Check what's conflicting
npm ls package-name

# Update to compatible versions
npm install package-a@version package-b@version

# OR use npm overrides (package.json)
{
  "overrides": {
    "conflicting-package": "^specific-version"
  }
}
```

### Angular: Cannot find name 'process'

**Resolution Strategies:**

```typescript
// ERROR: Cannot find name 'process'

// FIX 1: Install Node types
npm install --save-dev @types/node

// FIX 2: Add to tsconfig.json
{
  "compilerOptions": {
    "types": ["node"]
  }
}

// FIX 3: Add to polyfills (if needed for browser)
(window as any).process = {
  env: { DEBUG: undefined }
};
```

## C#/.NET Build Errors

### CS0246: The type or namespace name 'X' could not be found

**Resolution Strategies:**

**Strategy 1: Add Using Directive**
```csharp
// ERROR: The type or namespace name 'List' could not be found

// FIX: Add using
using System.Collections.Generic;
```

**Strategy 2: Add Package Reference**
```bash
# ERROR: Missing EntityFramework types

# FIX: Add NuGet package
dotnet add package Microsoft.EntityFrameworkCore
```

**Strategy 3: Check Target Framework**
```xml
<!-- ERROR: Package not compatible with target framework -->

<!-- FIX: Update .csproj -->
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>
```

### CS0104: Ambiguous reference between 'X' and 'Y'

**Resolution Strategies:**

```csharp
// ERROR: Ambiguous reference between 
// 'System.Threading.Tasks.Task' and 'MyProject.Task'

// FIX 1: Use fully qualified name
System.Threading.Tasks.Task.Run(() => { });

// FIX 2: Alias the namespace
using SysTasks = System.Threading.Tasks;
SysTasks.Task.Run(() => { });

// FIX 3: Rename your conflicting type
// Rename MyProject.Task to MyProject.TaskItem
```

### CS0234: The type or namespace name 'X' does not exist in the namespace 'Y'

**Resolution Strategies:**

**Strategy 1: Check Package Version**
```bash
# ERROR: Type exists in newer version

# Check current version
dotnet list package

# Update package
dotnet add package PackageName --version latest
```

**Strategy 2: Check Conditional Compilation**
```csharp
// ERROR: Type only available in specific target

// FIX: Add conditional compilation
#if NET8_0_OR_GREATER
using ModernNamespace;
#else
using LegacyNamespace;
#endif
```

### CS1061: Type 'X' does not contain a definition for 'Y'

**Resolution Strategies:**

**Strategy 1: Add Extension Method Using**
```csharp
// ERROR: 'string' does not contain 'IsNullOrEmpty'

// Wrong
string value = "test";
value.IsNullOrEmpty(); // Instance method doesn't exist

// FIX: Use correct syntax
string.IsNullOrEmpty(value); // Static method
```

**Strategy 2: Update Package for New API**
```bash
# New method added in newer version
dotnet add package PackageName --version 8.0.0
```

### Package restore failed

**Resolution Strategies:**

**Strategy 1: Clear NuGet Cache**
```bash
# Clear all caches
dotnet nuget locals all --clear

# Restore packages
dotnet restore

# Rebuild
dotnet build
```

**Strategy 2: Check NuGet Sources**
```bash
# List configured sources
dotnet nuget list source

# Add missing source
dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org
```

**Strategy 3: Check Network/Authentication**
```bash
# Test connectivity
ping api.nuget.org

# Check authentication for private feeds
# Update nuget.config
```

### CS8603: Possible null reference return

**Resolution Strategies:**

```csharp
// ERROR: Possible null reference return
public string GetName()
{
    return null; // CS8603
}

// FIX 1: Return non-null
public string GetName()
{
    return string.Empty;
}

// FIX 2: Make return type nullable
public string? GetName()
{
    return null;
}

// FIX 3: Throw instead of returning null
public string GetName()
{
    throw new InvalidOperationException("Name not set");
}
```

### CS0103: The name 'X' does not exist in the current context

**Resolution Strategies:**

**Strategy 1: Check Variable Declaration**
```csharp
// ERROR: Variable not declared
Console.WriteLine(message);

// FIX: Declare variable
string message = "Hello";
Console.WriteLine(message);
```

**Strategy 2: Check Scope**
```csharp
// ERROR: Variable out of scope
if (condition)
{
    string message = "Hello";
}
Console.WriteLine(message); // Out of scope

// FIX: Declare in correct scope
string message;
if (condition)
{
    message = "Hello";
}
Console.WriteLine(message);
```

### Build failed: Project file 'X' not found

**Resolution Strategies:**

**Strategy 1: Check Project References**
```xml
<!-- ERROR: Referenced project not found -->

<!-- FIX: Update path in .csproj -->
<ItemGroup>
  <ProjectReference Include="../CorrectPath/Project.csproj" />
</ItemGroup>
```

**Strategy 2: Check Solution File**
```bash
# Rebuild solution file
dotnet sln remove OldProject.csproj
dotnet sln add NewPath/Project.csproj
```

### Error MSB4019: Project file could not be loaded

**Resolution Strategies:**

```bash
# ERROR: Invalid XML or missing SDK

# FIX 1: Check XML syntax
# Ensure all tags are properly closed

# FIX 2: Verify SDK specification
# .csproj should have:
<Project Sdk="Microsoft.NET.Sdk.Web">
  <!-- Content -->
</Project>

# FIX 3: Clean and rebuild
dotnet clean
dotnet build
```

## Build Configuration Issues

### Angular: Production build fails but development works

**Resolution Strategies:**

```bash
# ERROR: Build optimization failures

# FIX 1: Check Angular configuration
# angular.json - ensure production configuration is valid

# FIX 2: Build optimization
# Disable specific optimizations temporarily
ng build --configuration=production --optimization=false

# FIX 3: Source map generation (debugging)
ng build --configuration=production --source-map

# FIX 4: Increase memory (large projects)
NODE_OPTIONS=--max_old_space_size=8192 ng build --configuration=production
```

### Webpack errors in Angular

**Resolution Strategies:**

```bash
# ERROR: Module not found or webpack compilation error

# FIX 1: Clear cache
rm -rf node_modules .angular
npm install

# FIX 2: Check webpack configuration
# If using custom webpack config, verify paths

# FIX 3: Update Angular CLI
npm install -g @angular/cli@latest
```

### MSBuild restore failed

**Resolution Strategies:**

```bash
# ERROR: MSBuild restore failures

# FIX 1: Use dotnet CLI restore
dotnet restore --force

# FIX 2: Restore with verbosity
dotnet restore -v detailed

# FIX 3: Check MSBuild version
dotnet --info

# FIX 4: Clear MSBuild cache
# Windows: %LOCALAPPDATA%\Microsoft\MSBuild\
# Mac/Linux: ~/.local/share/NuGet/
```

## Preventive Measures

### Before Building

1. **Ensure Clean State**
```bash
# Node/Angular
rm -rf node_modules package-lock.json
npm install

# .NET
dotnet clean
dotnet restore
```

2. **Check Versions**
```bash
# Node/npm versions
node --version
npm --version

# .NET SDK
dotnet --version

# Angular CLI
ng version
```

3. **Validate Configuration**
```bash
# TypeScript config
npx tsc --showConfig

# .NET project validate
dotnet build --no-restore /p:ValidateExecutableReferencesMatchSelfContained=true
```

## Troubleshooting Checklist

- [ ] Error message completely read
- [ ] File and line number identified
- [ ] Dependencies installed correctly
- [ ] Configuration files valid
- [ ] No circular dependencies
- [ ] Type definitions available
- [ ] Compatible versions used
- [ ] Cache cleared if needed
- [ ] Build succeeds after fix
- [ ] Tests still pass

## Quick Diagnostic Commands

**TypeScript/Angular:**
```bash
# Check for issues
npm run lint
npm run type-check  # if configured

# Verify installation
npm list --depth=0
npm audit

# Clean build
rm -rf node_modules .angular dist
npm install
npm run build
```

**C#/.NET:**
```bash
# Diagnostic build
dotnet build -v detailed

# Check packages
dotnet list package --outdated
dotnet list package --vulnerable

# Clean build
dotnet clean
dotnet restore --force
dotnet build --no-restore
```

## Best Practices

1. **Version Lock**: Use package-lock.json / .csproj versions
2. **Regular Updates**: Keep dependencies updated
3. **Clean Builds**: Clear caches when troubleshooting
4. **Read Errors Carefully**: Don't skip error details
5. **Check Changelogs**: Review breaking changes when upgrading
6. **Test Incrementally**: Build after small changes
7. **Use CI/CD**: Catch build issues early
8. **Document Fixes**: Note solutions for future reference
9. **Maintain Build Scripts**: Keep build configuration updated
10. **Monitor Warnings**: Address warnings before they become errors
