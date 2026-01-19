# Technical Debt

This document tracks known technical debt, temporary workarounds, and deferred work items for SwiftClimb. All items should be prioritized and addressed before public release.

**Last Updated**: 2026-01-19
**Status**: Xcode Project Configured, Services Partially Implemented

---

## Critical Items

*No critical items currently.*

---

## Resolved Items

### ~~1. Missing Xcode Project Configuration~~ ✅ RESOLVED

**Resolution Date**: 2026-01-19

**Completed**:
- ✅ Created `SwiftClimb.xcodeproj` and `SwiftClimb.xcworkspace`
- ✅ Added XCConfig files (Debug, Release, Shared, Tests)
- ✅ Configured build settings (iOS 18.0, Swift 6, Strict Concurrency)
- ✅ Created `Assets.xcassets` with AppIcon and AccentColor
- ✅ Created entitlements file at `Config/SwiftClimb.entitlements`

**Note**: Using custom Supabase implementation via `SupabaseClientActor` rather than supabase-swift SDK.

---

### ~~4. Supabase Configuration Missing~~ ✅ RESOLVED

**Resolution Date**: 2026-01-19

**Completed**:
- ✅ Created `SupabaseConfig.swift` with URL and anon key
- ✅ Implemented `SupabaseClientActor` for API communication
- ✅ Added table definitions (ProfilesTable, SessionsTable, ClimbsTable, etc.)

**Security Note**: Anon key is hardcoded. For production, consider environment-based configuration.

---

## High Priority Items

### 2. @unchecked Sendable in Service Layer ⚠️

**Impact**: HIGH - Violates Swift 6 concurrency safety
**Effort**: Medium (4-6 hours total)
**Count**: 14 instances

**Issue**: All Domain/Services and UseCases use `@unchecked Sendable` as a temporary measure during stub implementation phase.

**Affected Files**:
```
Domain/Services/
  - AuthService.swift
  - ProfileService.swift
  - SessionService.swift
  - ClimbService.swift
  - AttemptService.swift
  - TagService.swift
  - SocialService.swift
  - GradeConversionService.swift (assumed based on pattern)

Domain/UseCases/
  - StartSessionUseCase.swift
  - EndSessionUseCase.swift
  - AddClimbUseCase.swift
  - LogAttemptUseCase.swift
  - SearchOpenBetaUseCase.swift
  - ToggleFollowUseCase.swift
  - CreatePostUseCase.swift
```

**Resolution Strategy**:

Option 1: Convert services to actors
```swift
// Before (stub)
final class SessionService: SessionServiceProtocol, @unchecked Sendable {
    func createSession(...) async throws -> SCSession {
        fatalError("Not implemented")
    }
}

// After (actor implementation)
actor SessionService: SessionServiceProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createSession(...) async throws -> SCSession {
        let session = SCSession(...)
        modelContext.insert(session)
        try modelContext.save()
        return session
    }
}
```

Option 2: Final classes with Sendable dependencies
```swift
final class SessionService: SessionServiceProtocol, Sendable {
    private let modelContext: ModelContext  // If ModelContext becomes Sendable

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
}
```

**Recommendation**: Use actors for services that manage mutable state (sync, network). Use final classes with Sendable dependencies for stateless services.

**Assigned To**: TBD
**Target Milestone**: 0.2.0 (Local MVP)

---

### 3. Unimplemented Service Methods

**Impact**: HIGH - Limited functionality
**Effort**: Medium (15-20 hours remaining)

**Issue**: Some service protocol methods still use `fatalError("Not implemented")`.

**Current Status**: 8 stub methods remaining across 6 service files (reduced from ~50+)

**Implementation Order** (by dependency):
1. **ProfileService** (no dependencies)
   - `createProfile`, `getProfile`, `updateProfile`

2. **SessionService** (depends on Profile)
   - `createSession`, `endSession`, `getActiveSession`, `getSessionHistory`

3. **ClimbService** (depends on Session)
   - `createClimb`, `updateClimb`, `deleteClimb`, `getClimbsForSession`

4. **AttemptService** (depends on Climb)
   - `logAttempt`, `updateAttempt`, `deleteAttempt`, `getAttemptsForClimb`

5. **TagService** (reference data)
   - `getAllTechniqueTags`, `getAllSkillTags`, `getAllWallStyleTags`

6. **GradeConversionService** (standalone utility)
   - `parseGrade`, `normalizeGrade`, `convertGrade`

7. **AuthService** (Supabase integration)
   - `signUp`, `signIn`, `signOut`, `getCurrentUser`

8. **SocialService** (depends on Auth, Profile)
   - Follow, post, kudos, comment methods

**Assigned To**: TBD
**Target Milestone**: 0.2.0 - 0.5.0 (phased)

---

## Medium Priority Items

### 5. Deferred Optional Views

**Impact**: MEDIUM - Limits UX but not core functionality
**Effort**: Medium (10-15 hours total)
**Count**: 12 components

**Issue**: Several UI components were deferred during initial scaffolding to focus on core functionality.

**Missing Components**:

**Session Feature**:
- [ ] AddClimbSheet - Modal for adding climbs to session
- [ ] AttemptLoggerView - Quick attempt logging interface
- [ ] ClimbDetailView - Detailed view of single climb with attempts
- [ ] SessionEndSheet - End session form with RPE/pump/notes

**Logbook Feature**:
- [ ] SessionDetailView - Detailed session view with all climbs
- [ ] SessionListRow - Custom row component for session list
- [ ] FilterSheet - Filter sessions by date/discipline/grade

**Insights Feature** (Premium):
- [ ] VolumeTrendChart - Volume over time chart
- [ ] PyramidChart - Attempt/send pyramid visualization
- [ ] ProgressionChart - Grade progression over time
- [ ] DateRangePicker - Custom date range selector

**Feed Feature**:
- [ ] PostCard - Social feed post card component
- [ ] CommentList - Comment thread view

**All deferred views are documented with TODO comments in respective feature files.**

**Assigned To**: TBD
**Target Milestone**: 0.2.0 - 0.5.0 (phased by feature)

---

### 6. Grade Parsing Algorithm Not Implemented

**Impact**: MEDIUM - Manual grade entry only
**Effort**: Medium (4-6 hours)

**Issue**: `GradeConversionService` has stub implementations. Grade normalization is required for:
- Sorting climbs by difficulty
- Progress tracking
- Pyramid visualizations

**Required**:
1. Implement parsing for each grade scale:
   - V-scale: `V0`, `V1`, ... `V17`, `VB` (beginner)
   - YDS: `5.1` to `5.15d`
   - French: `1` to `9c`
   - UIAA: `I` to `XII`

2. Handle slash grades: `5.10a/b`, `V4/5`

3. Create normalization lookup tables for cross-scale comparison

**Reference Data Needed**:
- Grade conversion tables (community consensus)
- Handling of plus/minus variants

**Assigned To**: TBD
**Target Milestone**: 0.4.0 (OpenBeta Integration)

---

### 7. SwiftData Schema Migrations

**Impact**: MEDIUM - Future data loss risk
**Effort**: Low (2-3 hours per migration)

**Issue**: `ModelMigrations.swift` is a stub. No migration plan exists for schema changes.

**Required**:
1. Define migration strategy (lightweight vs. heavyweight)
2. Implement SchemaV1 and VersionedSchema
3. Create migration plans for common scenarios:
   - Adding new properties
   - Changing relationships
   - Renaming properties

4. Test migrations with sample data

**Current Risk**: Low (no users yet)
**Future Risk**: HIGH (data loss on schema changes)

**Assigned To**: TBD
**Target Milestone**: 0.2.0 (before first user data)

---

### 8. Tag Catalog Seed Data

**Impact**: MEDIUM - Empty tag lists
**Effort**: Low (2-3 hours)

**Issue**: Tag tables (Technique, Skill, WallStyle) have no initial data.

**Required**:
1. Define canonical tag list:
   - Techniques: e.g., "Drop Knee", "Heel Hook", "Flag", "Smear"
   - Skills: e.g., "Finger Strength", "Core", "Flexibility", "Balance"
   - Wall Styles: e.g., "Overhang", "Slab", "Vertical", "Roof"

2. Create seed data migration or initial load
3. Handle localization for tag names

**Assigned To**: TBD
**Target Milestone**: 0.2.0 (Local MVP)

---

## Low Priority Items

### 9. OpenBeta GraphQL Query Improvements

**Impact**: LOW - Works but not optimal
**Effort**: Low (1-2 hours)

**Issue**: GraphQL queries in `OpenBetaQueries.swift` use string interpolation instead of proper variable binding.

**Current**:
```swift
static func searchAreas(query: String) -> String {
    """
    query {
      areas(filter: { name: "\(query)" }) {
        id
        name
      }
    }
    """
}
```

**Recommended**:
```swift
static let searchAreasQuery = """
query SearchAreas($query: String!) {
  areas(filter: { name: $query }) {
    id
    name
  }
}
"""

// Then pass variables separately
```

**Benefit**: Better security (prevents injection), cleaner code

**Assigned To**: TBD
**Target Milestone**: 0.4.0 (OpenBeta Integration)

---

### 10. Network Retry Backoff Not Implemented

**Impact**: LOW - Basic retry exists
**Effort**: Low (2 hours)

**Issue**: `HTTPClient` has retry logic stubbed but not fully implemented with exponential backoff.

**Current**: Basic retry without backoff
**Required**: Implement exponential backoff with jitter per ADR-002

**Reference**: See `RetryPolicy` in ADR-002-DATA-SYNC-STRATEGY.md

**Assigned To**: TBD
**Target Milestone**: 0.3.0 (Supabase Integration)

---

### 11. Soft Delete Cleanup Job

**Impact**: LOW - Storage grows over time
**Effort**: Low (2-3 hours)

**Issue**: Soft deletes accumulate indefinitely. Need periodic cleanup.

**Required**:
1. Define retention policy (e.g., hard delete after 90 days)
2. Implement background cleanup job
3. Add admin/debugging UI to view soft-deleted records

**Assigned To**: TBD
**Target Milestone**: 1.0.0 (Public Release)

---

### 12. Preview Providers Need Sample Data

**Impact**: LOW - Previews show empty states
**Effort**: Low (1-2 hours)

**Issue**: Many preview providers use empty data or simple stubs.

**Required**:
1. Create shared preview data factory
2. Provide realistic sample data (sessions, climbs, attempts)
3. Test previews render correctly with data

**Example**:
```swift
#Preview {
    SessionView()
        .environment(\.startSessionUseCase, PreviewData.startSessionUseCase)
        .modelContainer(PreviewData.container)
}
```

**Assigned To**: TBD
**Target Milestone**: 0.2.0 (Local MVP)

---

## Deferred Features (Post-1.0)

These are not debt but intentionally deferred:

### 13. Advanced Conflict Resolution
- Current: Last-write-wins
- Future: User-prompted conflict resolution UI
- Milestone: 2.0.0

### 14. Offline Map Support
- Current: Text-only location
- Future: Embedded map tiles for offline use
- Milestone: 1.5.0

### 15. Export Data
- Current: No export
- Future: Export to CSV, JSON, PDF
- Milestone: 1.2.0

### 16. Custom Tag Creation
- Current: Predefined tags only
- Future: User-created custom tags
- Milestone: 1.3.0

---

## Tracking Metrics

### Total Debt Items: 9 active + 4 deferred (2 resolved)
### Critical: 0 ✅
### High Priority: 2
### Medium Priority: 4
### Low Priority: 3

### Estimated Total Effort: 35-45 hours (reduced from 45-60)

**Note**: Architecture simplified to MV (removed ViewModel layer), reducing overall complexity and technical debt. Xcode project configuration and Supabase setup completed.

---

## Review Schedule

This document should be reviewed and updated:
- Before each milestone release
- When new technical debt is introduced
- When debt items are resolved

**Next Review**: Before 0.2.0 release

---

## How to Add Items

When adding technical debt:
1. Assign priority (Critical/High/Medium/Low)
2. Estimate effort in hours
3. Describe the issue clearly
4. Provide resolution strategy
5. Link to related files/issues
6. Assign target milestone

Example template:
```markdown
### N. [Title]

**Impact**: [CRITICAL/HIGH/MEDIUM/LOW] - [Why this matters]
**Effort**: [Low/Medium/High] ([X-Y hours])

**Issue**: [What's wrong]

**Required Actions**:
1. [Step 1]
2. [Step 2]

**Assigned To**: [Name or TBD]
**Target Milestone**: [Version]
```

---

**Last Updated by**: Agent 4 (The Scribe)
**Review Status**: Current as of Xcode project configuration completion (2026-01-19)
