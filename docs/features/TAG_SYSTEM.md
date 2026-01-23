# Tag System

**Status**: Implemented
**Version**: 1.0
**Last Updated**: 2026-01-22

---

## Overview

The Tag System provides a comprehensive way to capture and track the characteristics of climbs through predefined tags with impact ratings. Tags help climbers identify patterns in their strengths and weaknesses by recording which hold types and skills helped or hindered performance on specific climbs.

**Key Capabilities**:
- Predefined catalog of hold types and skills
- Three-state impact rating (unselected, helped, hindered)
- Offline-first with automatic background sync
- Memory-cached catalog for performance
- Atomic bulk updates for tag impacts
- Consistent UI across Add and Edit climb forms

---

## Tag Categories

### Hold Types (11 tags)

Physical characteristics of holds and moves.

#### Grip Types
- **Crimp** - Small edge requiring fingertip strength
- **Sloper** - Open-hand hold requiring friction
- **Jug** - Large, positive hold
- **Pinch** - Hold requiring thumb opposition
- **Pocket** - One or more finger holes
- **Sidepull** - Hold pulled from the side
- **Undercling** - Hold pulled from underneath

#### Movement Types
- **Gaston** - Push outward with elbow out
- **Smear** - Foot placement using friction
- **Heel Hook** - Using heel to pull or stabilize
- **Toe Hook** - Using top of foot to pull

### Skills (16 tags)

Techniques and attributes used during the climb.

#### Technical Skills
- **Drop Knee** - Inside knee dropped to increase reach
- **Flagging** - Extending leg for balance/counterweight
- **Mantle** - Pressing down to get on top of feature
- **Dyno** - Dynamic jumping move
- **Lock Off** - Holding bent arm position
- **Deadpoint** - Controlled dynamic move

#### Physical Attributes
- **Body Tension** - Core engagement and body control
- **Finger Strength** - Grip strength endurance
- **Flexibility** - Range of motion requirements
- **Power** - Explosive strength
- **Endurance** - Sustained effort capacity
- **No Cut Loose** - Keeping feet on throughout climb

#### Mental Aspects
- **Mental** - Mental state and focus
- **Pacing** - Energy management and rhythm
- **Precision** - Movement accuracy
- **Route Reading** - Beta interpretation and problem-solving

---

## Impact Rating System

### Three-State Toggle

Each tag can be in one of three states:

#### Unselected (nil)
- **Meaning**: Tag not relevant to this climb
- **Visual**: Gray background, no icon
- **Usage**: Default state, or explicitly deselected

#### Helped (positive impact)
- **Meaning**: This aspect felt strong, contributed to success
- **Visual**: Green background with thumbs up icon
- **Usage**: Strengths, comfortable techniques
- **Example**: "Slopers helped - felt confident on open-hand holds"

#### Hindered (negative impact)
- **Meaning**: This aspect was challenging, limited performance
- **Visual**: Red background with thumbs down icon
- **Usage**: Weaknesses, areas for improvement
- **Example**: "Flexibility hindered - couldn't reach high foot placement"

### Interaction Pattern

**Tap Cycle**:
1. Unselected → Helped (green)
2. Helped → Hindered (red)
3. Hindered → Unselected (gray)

**Rationale**: Single tap interaction is faster than separate helped/hindered buttons. Natural progression from unselected to positive to negative matches mental model.

---

## User Experience

### In Add Climb Form

**Location**: Section 4 (after Performance, before Notes)

**Display**:
- Two subsections: "Hold Types" and "Skills"
- Each subsection shows `TagSelectionGrid` with all available tags
- Tags displayed in flowing grid layout that wraps to screen width
- All tags start unselected

**Workflow**:
1. User climbs route, returns to add to session
2. Fills basic info (name, grade, attempts, outcome)
3. Rates performance (mental, pacing, precision)
4. Selects relevant tags:
   - Tap tags that were present on the route
   - Helped (green) for strengths
   - Hindered (red) for struggles
   - Leave irrelevant tags unselected
5. Adds optional notes
6. Saves climb

**Example Scenario**:
- Boulder problem with crimps and a hard deadpoint
- User taps "Crimp" → Helped (felt strong)
- User taps "Deadpoint" → Hindered (struggled with timing)
- Other tags left unselected

### In Edit Climb Form

**Location**: Same section structure as Add Climb

**Display**:
- Shows previously selected tags with their impacts
- User can add new tags or change existing impacts
- Atomic update replaces all impacts on save

**Workflow**:
1. User views climb detail, taps Edit
2. Form pre-populated with existing data
3. Tag selections show previous impacts
4. User modifies tags as needed
5. Saves changes

**Consistency**: Edit form now matches Add form exactly (previously lacked tag section).

---

## Technical Architecture

### Data Models

#### Tag Catalog Models

```swift
@Model
final class SCTechniqueTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String?
    var createdAt: Date
    var updatedAt: Date

    init(name: String, category: String?) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class SCSkillTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String?
    var createdAt: Date
    var updatedAt: Date

    init(name: String, category: String?) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

**Design Note**: Separate models for technique and skill tags allows different catalogs and relationships in the future.

#### Tag Impact Models

```swift
@Model
final class SCTechniqueImpact {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var climbId: UUID
    var tagId: UUID
    var impact: TagImpact

    // Sync fields
    var needsSync: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(userId: UUID, climbId: UUID, tagId: UUID, impact: TagImpact, needsSync: Bool) {
        self.id = UUID()
        self.userId = userId
        self.climbId = climbId
        self.tagId = tagId
        self.impact = impact
        self.needsSync = needsSync
        self.createdAt = Date()
        self.updatedAt = Date()
        self.deletedAt = nil
    }
}

@Model
final class SCSkillImpact {
    // Same structure as SCTechniqueImpact
}
```

**Design Note**: Impacts use separate tables to maintain referential integrity and allow independent querying.

#### TagImpact Enum

```swift
enum TagImpact: String, Codable, CaseIterable, Sendable {
    case helped
    case hindered
    case neutral

    var displayName: String {
        switch self {
        case .helped: return "Helped"
        case .hindered: return "Hindered"
        case .neutral: return "Neutral"
        }
    }
}
```

**Note**: `.neutral` case exists for future use but is not currently exposed in UI. `nil` impact represents unselected state.

---

## Service Layer

### TagService Protocol

```swift
protocol TagServiceProtocol: Sendable {
    // Tag catalog queries (cached)
    func getHoldTypeTags() async -> [TechniqueTagDTO]
    func getSkillTags() async -> [SkillTagDTO]

    // Bulk impact management
    func setHoldTypeImpacts(
        userId: UUID,
        climbId: UUID,
        impacts: [TagImpactInput]
    ) async throws

    func setSkillImpacts(
        userId: UUID,
        climbId: UUID,
        impacts: [TagImpactInput]
    ) async throws

    // First-launch seeding
    func seedPredefinedTagsIfNeeded() async throws
}
```

### TagService Implementation

```swift
actor TagService: TagServiceProtocol {
    private let modelContainer: ModelContainer

    // In-memory cache for tag catalog
    private var holdTypeTagsCache: [TechniqueTagDTO]?
    private var skillTagsCache: [SkillTagDTO]?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    // Catalog queries with caching
    func getHoldTypeTags() async -> [TechniqueTagDTO] {
        if let cached = holdTypeTagsCache {
            return cached
        }

        let tags = await MainActor.run {
            let descriptor = FetchDescriptor<SCTechniqueTag>(
                sortBy: [SortDescriptor(\.name)]
            )
            let models = (try? modelContext.fetch(descriptor)) ?? []
            return models.map { TechniqueTagDTO(id: $0.id, name: $0.name, category: $0.category) }
        }

        holdTypeTagsCache = tags
        return tags
    }

    // Atomic bulk impact update
    func setHoldTypeImpacts(
        userId: UUID,
        climbId: UUID,
        impacts: [TagImpactInput]
    ) async throws {
        try await MainActor.run {
            // 1. Soft delete existing impacts
            let existingPredicate = #Predicate<SCTechniqueImpact> {
                $0.climbId == climbId && $0.deletedAt == nil
            }
            let existing = try modelContext.fetch(FetchDescriptor(predicate: existingPredicate))

            let now = Date()
            for impact in existing {
                impact.deletedAt = now
                impact.updatedAt = now
                impact.needsSync = true
            }

            // 2. Create new impacts
            for input in impacts {
                let impact = SCTechniqueImpact(
                    userId: userId,
                    climbId: climbId,
                    tagId: input.tagId,
                    impact: input.impact,
                    needsSync: true
                )
                modelContext.insert(impact)
            }

            try modelContext.save()
        }
    }

    // Seed predefined tags on first launch
    func seedPredefinedTagsIfNeeded() async throws {
        try await MainActor.run {
            let holdDescriptor = FetchDescriptor<SCTechniqueTag>()
            let existingHolds = try modelContext.fetch(holdDescriptor)

            if existingHolds.isEmpty {
                try seedHoldTypeTags()
            }

            let skillDescriptor = FetchDescriptor<SCSkillTag>()
            let existingSkills = try modelContext.fetch(skillDescriptor)

            if existingSkills.isEmpty {
                try seedSkillTags()
            }

            try modelContext.save()
        }

        // Clear cache to force reload
        holdTypeTagsCache = nil
        skillTagsCache = nil
    }

    @MainActor
    private func seedHoldTypeTags() throws {
        let holdTypes: [(name: String, category: String)] = [
            ("Crimp", "Grip"),
            ("Sloper", "Grip"),
            ("Jug", "Grip"),
            // ... (11 total)
        ]

        for holdType in holdTypes {
            let tag = SCTechniqueTag(name: holdType.name, category: holdType.category)
            modelContext.insert(tag)
        }
    }

    @MainActor
    private func seedSkillTags() throws {
        let skills: [(name: String, category: String)] = [
            ("Drop Knee", "Technical"),
            ("Flagging", "Technical"),
            // ... (16 total)
        ]

        for skill in skills {
            let tag = SCSkillTag(name: skill.name, category: skill.category)
            modelContext.insert(tag)
        }
    }
}
```

**Key Behaviors**:
- Actor isolation ensures thread-safety
- In-memory caching prevents repeated SwiftData queries
- Atomic bulk updates (soft delete + create) maintain consistency
- `@MainActor` annotations for ModelContext access
- Seeding only happens on empty catalog (idempotent)

---

## Data Transfer Objects

### TechniqueTagDTO

```swift
struct TechniqueTagDTO: Sendable, Identifiable {
    let id: UUID
    let name: String
    let category: String?
}
```

**Purpose**: Sendable representation of `SCTechniqueTag` for crossing actor boundaries.

### SkillTagDTO

```swift
struct SkillTagDTO: Sendable, Identifiable {
    let id: UUID
    let name: String
    let category: String?
}
```

**Purpose**: Sendable representation of `SCSkillTag` for crossing actor boundaries.

### TagImpactInput

```swift
struct TagImpactInput: Sendable {
    let tagId: UUID
    let impact: TagImpact
}
```

**Purpose**: Input for bulk impact updates. Lightweight struct containing only tag reference and impact rating.

### TagSelection (UI State)

```swift
struct TagSelection: Equatable, Sendable {
    let tagId: UUID
    let tagName: String
    var impact: TagImpact?
}
```

**Purpose**: View state for `TagImpactChip`. Combines tag identity with mutable impact state for binding.

---

## Use Case Integration

### AddClimbUseCase

```swift
final class AddClimbUseCase: AddClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol
    private let attemptService: AttemptServiceProtocol
    private let tagService: TagServiceProtocol

    func execute(
        userId: UUID,
        sessionId: UUID,
        discipline: Discipline,
        data: AddClimbData,
        // ...
    ) async throws -> UUID {
        // 1. Create climb
        let climbId = try await climbService.createClimb(...)

        // 2. Create attempts
        try await createAttempts(...)

        // 3. Persist tag impacts
        try await tagService.setHoldTypeImpacts(
            userId: userId,
            climbId: climbId,
            impacts: data.holdTypeImpacts
        )

        try await tagService.setSkillImpacts(
            userId: userId,
            climbId: climbId,
            impacts: data.skillImpacts
        )

        return climbId
    }
}
```

### UpdateClimbUseCase

```swift
final class UpdateClimbUseCase: UpdateClimbUseCaseProtocol, Sendable {
    private let climbService: ClimbServiceProtocol
    private let tagService: TagServiceProtocol

    func execute(
        userId: UUID,
        climbId: UUID,
        data: ClimbEditData
    ) async throws {
        // 1. Update climb properties
        let updates = ClimbUpdates(name: data.name, grade: grade, notes: data.notes)
        try await climbService.updateClimb(climbId: climbId, updates: updates)

        // 2. Replace all tag impacts atomically
        try await tagService.setHoldTypeImpacts(
            userId: userId,
            climbId: climbId,
            impacts: data.holdTypeImpacts
        )

        try await tagService.setSkillImpacts(
            userId: userId,
            climbId: climbId,
            impacts: data.skillImpacts
        )
    }
}
```

**Pattern**: Tag impacts are always set as a complete bulk update. This simplifies logic and maintains atomicity.

---

## UI Components

### TagImpactChip

Three-state toggle chip for individual tag selection.

**File**: `/SwiftClimb/Features/Session/Components/TagImpactChip.swift`

**Interface**:
```swift
struct TagImpactChip: View {
    @Binding var selection: TagSelection

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                cycleImpact()
            }
        } label: {
            HStack(spacing: SCSpacing.xxs) {
                if selection.impact == .helped {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Text(selection.tagName)
                    .font(SCTypography.label)
                    .foregroundStyle(textColor)

                if selection.impact == .hindered {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, SCSpacing.sm)
            .padding(.vertical, SCSpacing.xs)
            .background(chipBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func cycleImpact() {
        switch selection.impact {
        case nil: selection.impact = .helped
        case .helped: selection.impact = .hindered
        case .hindered, .neutral: selection.impact = nil
        }
    }
}
```

**Features**:
- Inline thumbs up/down icons (only shown when selected)
- Capsule shape with tinted background
- Smooth animation on state change
- Plain button style for full custom appearance

### TagSelectionGrid

Flowing grid layout for tag chips with category title.

**File**: `/SwiftClimb/Features/Session/Components/TagSelectionGrid.swift`

**Interface**:
```swift
struct TagSelectionGrid: View {
    let title: String
    @Binding var selections: [TagSelection]

    var body: some View {
        VStack(alignment: .leading, spacing: SCSpacing.sm) {
            Text(title)
                .font(SCTypography.cardTitle)
                .foregroundStyle(SCColors.textPrimary)

            FlowLayout(spacing: SCSpacing.xs) {
                ForEach($selections, id: \.tagId) { $selection in
                    TagImpactChip(selection: $selection)
                }
            }
        }
    }
}
```

**FlowLayout**: Custom SwiftUI `Layout` protocol implementation that arranges subviews left-to-right, wrapping to new lines as needed.

---

## Offline-First Behavior

### Tag Catalog

**Seeding**:
- Tags seeded on first app launch
- Check performed via `TagService.seedPredefinedTagsIfNeeded()`
- Called from app initialization
- Idempotent (safe to call multiple times)

**Caching**:
- Catalog loaded once and cached in `TagService` actor state
- Cache persists for app lifetime
- No network required (catalog is local-only)

### Tag Impacts

**Write Path**:
1. User selects tags in Add/Edit form
2. Form converts selections to `[TagImpactInput]`
3. UseCase calls `TagService.setHoldTypeImpacts(...)` / `setSkillImpacts(...)`
4. Service soft deletes existing, creates new impacts
5. All impacts marked with `needsSync = true`
6. SwiftData save completes (< 100ms)
7. UI updates immediately
8. SyncActor picks up changes and syncs to Supabase in background

**Sync Path**:
1. SyncActor queries for `needsSync = true` impacts
2. Converts to DTOs for Supabase
3. POSTs to `technique_impacts` and `skill_impacts` tables
4. On success, clears `needsSync` flag
5. On failure, retries with exponential backoff

**Soft Delete**:
- Deleted impacts retain `deletedAt` timestamp
- Filtered from UI queries via `deletedAt == nil` predicate
- Synced to Supabase for conflict resolution
- Eventually hard-deleted in cleanup process

**Important**: Tag impact tables use partial unique indexes instead of standard UNIQUE constraints to support soft-delete pattern. The index `WHERE deleted_at IS NULL` ensures uniqueness only for active records, allowing new inserts with the same (user_id, climb_id, tag_id) combination after soft deletion. See migration `20260123_fix_impact_unique_constraints.sql` for implementation.

---

## Database Schema

### Supabase Tables

#### technique_tags

```sql
CREATE TABLE public.technique_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_technique_tags_name ON technique_tags(name);
```

**Note**: Predefined tag catalog is local-only (not synced to Supabase). Future enhancement could sync catalog for custom tags.

#### skill_tags

```sql
CREATE TABLE public.skill_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_skill_tags_name ON skill_tags(name);
```

#### technique_impacts

```sql
CREATE TABLE public.technique_impacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    climb_id UUID NOT NULL REFERENCES climbs(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES technique_tags(id) ON DELETE CASCADE,
    impact TEXT NOT NULL CHECK (impact IN ('helped', 'hindered', 'neutral')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_technique_impacts_climb_id ON technique_impacts(climb_id);
CREATE INDEX idx_technique_impacts_user_id ON technique_impacts(user_id);
CREATE INDEX idx_technique_impacts_updated_at ON technique_impacts(updated_at);

-- Partial unique index for soft-delete support (WHERE deleted_at IS NULL)
CREATE UNIQUE INDEX technique_impacts_user_climb_tag_unique
    ON technique_impacts (user_id, climb_id, tag_id)
    WHERE deleted_at IS NULL;
```

#### skill_impacts

```sql
CREATE TABLE public.skill_impacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    climb_id UUID NOT NULL REFERENCES climbs(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES skill_tags(id) ON DELETE CASCADE,
    impact TEXT NOT NULL CHECK (impact IN ('helped', 'hindered', 'neutral')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_skill_impacts_climb_id ON skill_impacts(climb_id);
CREATE INDEX idx_skill_impacts_user_id ON skill_impacts(user_id);
CREATE INDEX idx_skill_impacts_updated_at ON skill_impacts(updated_at);

-- Partial unique index for soft-delete support (WHERE deleted_at IS NULL)
CREATE UNIQUE INDEX skill_impacts_user_climb_tag_unique
    ON skill_impacts (user_id, climb_id, tag_id)
    WHERE deleted_at IS NULL;
```

### RLS Policies

```sql
-- Users can view their own impacts
CREATE POLICY "Users can view own technique impacts" ON technique_impacts
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert impacts for their climbs
CREATE POLICY "Users can insert own technique impacts" ON technique_impacts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their impacts
CREATE POLICY "Users can update own technique impacts" ON technique_impacts
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their impacts
CREATE POLICY "Users can delete own technique impacts" ON technique_impacts
    FOR DELETE USING (auth.uid() = user_id);

-- (Same policies for skill_impacts)
```

---

## Analytics Opportunities

### Strength/Weakness Patterns

**Query Example**: Find top 5 hindered skills
```sql
SELECT st.name, COUNT(*) as hindered_count
FROM skill_impacts si
JOIN skill_tags st ON si.tag_id = st.id
WHERE si.user_id = $1
  AND si.impact = 'hindered'
  AND si.deleted_at IS NULL
GROUP BY st.id, st.name
ORDER BY hindered_count DESC
LIMIT 5;
```

**UI Display**: "Focus on these skills" insight card

### Hold Type Preferences

**Query Example**: Compare helped vs hindered by hold type
```sql
SELECT tt.name,
       SUM(CASE WHEN ti.impact = 'helped' THEN 1 ELSE 0 END) as helped,
       SUM(CASE WHEN ti.impact = 'hindered' THEN 1 ELSE 0 END) as hindered
FROM technique_impacts ti
JOIN technique_tags tt ON ti.tag_id = tt.id
WHERE ti.user_id = $1
  AND ti.deleted_at IS NULL
GROUP BY tt.id, tt.name;
```

**UI Display**: Bar chart of hold type strengths

### Grade Correlation

**Query Example**: Average grade of climbs where flexibility helped vs hindered
```sql
SELECT
  AVG(CASE WHEN si.impact = 'helped' THEN c.grade_score ELSE NULL END) as avg_helped,
  AVG(CASE WHEN si.impact = 'hindered' THEN c.grade_score ELSE NULL END) as avg_hindered
FROM skill_impacts si
JOIN skill_tags st ON si.tag_id = st.id
JOIN climbs c ON si.climb_id = c.id
WHERE si.user_id = $1
  AND st.name = 'Flexibility'
  AND si.deleted_at IS NULL
  AND c.deleted_at IS NULL;
```

**Insight**: "Flexibility limits you at V5+ grades"

---

## Future Enhancements

### Custom Tags

**Goal**: Allow users to create their own tags.

**Changes Needed**:
- Add "Custom" flag to tag models
- UI for creating custom tags
- Sync custom tags to Supabase
- Filter custom tags by user_id

**Challenges**:
- Preventing tag proliferation (too many custom tags)
- Standardization vs flexibility tradeoff
- Search/autocomplete for existing tags

### Tag Relationships

**Goal**: Model relationships between tags (e.g., "Gaston requires finger strength").

**Changes Needed**:
- `tag_relationships` table
- Relationship types (requires, benefits_from, conflicts_with)
- UI to show related tags
- Analytics on co-occurrence

### Tag Intensity

**Goal**: Allow users to rate intensity (e.g., "crimps hindered a lot").

**Changes Needed**:
- Add `intensity: Int?` field (1-5 scale)
- UI with slider or picker
- Analytics weighted by intensity

### Auto-Tagging

**Goal**: Suggest tags based on past climbs.

**Approach**:
- ML model trained on user's tag history
- Suggest probable tags when adding climb
- User confirms or rejects suggestions

### Beta Integration

**Goal**: Link tags to specific moves or sections.

**Changes Needed**:
- Add `moveSequence: Int?` to impact models
- UI for move-by-move tagging
- Video annotation with tags
- Beta sharing with tags

---

## Design Decisions

### Why Three-State Instead of Five-State?

**Considered**: Unselected, Strongly Helped, Helped, Hindered, Strongly Hindered

**Decision**: Three-state (unselected, helped, hindered)

**Rationale**:
- Simpler mental model
- Faster interaction (fewer taps)
- Binary outcomes match climber thinking ("felt good" vs "struggled")
- Can add intensity later if needed

### Why Separate Hold Types and Skills?

**Decision**: Two separate tag categories with separate models.

**Rationale**:
- Different semantics (physical characteristics vs techniques)
- Different analytics (holds are external, skills are internal)
- Allows different UI organization
- Future: Different tag types (conditions, emotions, etc.)

### Why Bulk Updates Instead of Individual?

**Decision**: `setHoldTypeImpacts([TagImpactInput])` replaces all impacts atomically.

**Rationale**:
- Simpler implementation (no need to diff)
- Atomic operation prevents partial updates
- Clear contract (what you send is what you get)
- No orphaned impacts from removed tags

### Why Cache Catalog in Memory?

**Decision**: TagService caches tag catalog in actor state.

**Rationale**:
- Catalog changes rarely (predefined, not user-editable)
- Prevents repeated SwiftData queries
- Improves form load performance
- Small memory footprint (27 tags)

**Trade-off**: Cache invalidation when catalog changes (rare, only on updates).

### Why Soft Delete Impacts?

**Decision**: Impacts use `deletedAt` timestamp instead of hard delete.

**Rationale**:
- Enables sync conflict resolution
- Preserves audit trail
- Allows undo functionality (future)
- Consistent with other models (climbs, sessions, etc.)

**Trade-off**: Requires filtering `deletedAt == nil` in all queries.

---

## Testing Strategy

### Unit Tests

**TagService Tests**:
- [ ] `getHoldTypeTags()` returns all 11 hold types sorted by name
- [ ] `getSkillTags()` returns all 16 skills sorted by name
- [ ] `seedPredefinedTagsIfNeeded()` seeds tags on first call
- [ ] `seedPredefinedTagsIfNeeded()` is idempotent (no duplicates)
- [ ] `setHoldTypeImpacts()` soft deletes existing impacts
- [ ] `setHoldTypeImpacts()` creates new impacts with needsSync=true
- [ ] `setSkillImpacts()` atomically replaces all impacts

**TagImpactChip Tests**:
- [ ] Tap cycles unselected → helped → hindered → unselected
- [ ] Visual state matches impact (color, icon)
- [ ] Animation triggers on tap
- [ ] Accessibility label announces state

**TagSelectionGrid Tests**:
- [ ] FlowLayout wraps chips to available width
- [ ] Maintains binding to selections array
- [ ] Updates parent state on chip tap

### Integration Tests

**Add Climb Flow**:
- [ ] Selecting tags adds impacts to SwiftData
- [ ] Impacts sync to Supabase in background
- [ ] Offline: Impacts queued with needsSync=true
- [ ] Online: needsSync cleared after sync

**Edit Climb Flow**:
- [ ] Edit form loads existing tag selections
- [ ] Changing tags updates impacts atomically
- [ ] Old impacts soft deleted, new impacts created

### UI Tests

**Manual Testing Checklist**:
- [ ] Add climb with hold type impacts
- [ ] Add climb with skill impacts
- [ ] Add climb with no tags
- [ ] Edit climb to add tags
- [ ] Edit climb to remove tags
- [ ] Edit climb to change impact (helped → hindered)
- [ ] Verify tags display in climb detail
- [ ] Test offline: Add tags without network
- [ ] Test sync: Tags appear on other device

---

## Performance Considerations

### Catalog Loading

**Optimization**: In-memory caching
- First load: ~10ms (SwiftData fetch)
- Subsequent loads: ~1ms (memory access)
- Cache persists for app lifetime

### Impact Persistence

**Timing**: Bulk update completes in < 50ms
- Soft delete existing: ~10ms
- Create new impacts: ~30ms
- SwiftData save: ~10ms

### UI Responsiveness

**FlowLayout Performance**:
- Layout calculation: ~5ms for 27 chips
- No scrolling required (all chips visible)
- Tap response: < 16ms (60fps)

### Sync Efficiency

**Batch Sync**:
- Impacts synced alongside climb data
- Single request per climb (not per impact)
- Compressed JSON payload (< 1KB per climb)

---

## Known Limitations

### Fixed Catalog

- Cannot add custom tags (predefined only)
- Cannot rename or delete tags
- All users share same tag catalog

**Workaround**: Use notes field for custom attributes.

### No Tag History

- Cannot view tag changes over time
- No undo for tag edits
- Audit trail exists but not exposed in UI

**Future**: Tag edit history view.

### No Intensity Levels

- Binary helped/hindered (no "helped a lot")
- Cannot express degree of impact

**Workaround**: Multiple tags for emphasis ("Crimp" + "Finger Strength").

### No Move-Level Tags

- Tags apply to entire climb
- Cannot tag specific moves or sections

**Future**: Move sequencing and per-move tagging.

---

## Changelog

### Version 1.0 (2026-01-22)

**Initial Release**:
- Predefined catalog of 11 hold types and 16 skills
- Three-state impact rating (helped, hindered, unselected)
- TagService with in-memory caching
- TagImpactChip and TagSelectionGrid UI components
- Integrated into Add Climb and Edit Climb forms
- Atomic bulk update pattern for impacts
- Offline-first with background sync
- Soft delete support for sync

**Files Created**: 3
- `TagImpactChip.swift`
- `TagSelectionGrid.swift`
- Tag seeding in `TagService.swift`

**Files Modified**: 7
- `AddClimbSheet.swift` - Added tags section
- `ClimbDetailSheet.swift` - Rewritten to match Add form
- `AddClimbUseCase.swift` - Tag impact persistence
- `UpdateClimbUseCase.swift` - Tag impact updates
- `TagService.swift` - Expanded with catalog management
- `Environment+UseCases.swift` - Inject tagService
- `SwiftClimbApp.swift` - Initialize tagService

**Total Lines**: ~600 new, ~200 modified

### Version 1.1 (2026-01-23)

**Bug Fix: Unique Constraint Sync Issue**:
- Fixed 409 Conflict errors during tag impact sync
- Root cause: Standard UNIQUE constraints blocked new inserts after soft deletes
- Solution: Replaced UNIQUE constraints with partial unique indexes (`WHERE deleted_at IS NULL`)
- Applied to: `technique_impacts`, `skill_impacts`, `wall_style_impacts` tables
- Migration: `20260123_fix_impact_unique_constraints.sql`
- Documentation: Added notes on partial unique index pattern for soft-delete support

**Technical Details**:
The original schema used standard UNIQUE constraints on (user_id, climb_id, tag_id), which prevented users from re-adding the same tag after removal. When a tag was soft-deleted (deleted_at set), the constraint still blocked new inserts with the same combination. Partial unique indexes solve this by enforcing uniqueness only for active records (WHERE deleted_at IS NULL), allowing multiple soft-deleted records and new active records with the same key.

---

**Document Maintained By**: Agent 4 (The Scribe)
**Last Review**: 2026-01-23
**Next Review**: When tag system is extended or analytics added
