# Design System Reference

SwiftClimb's design system implements Apple's Liquid Glass design language for iOS 26+ with full accessibility support. This document serves as a reference for all design tokens and components.

## Table of Contents
1. [Design Principles](#design-principles)
2. [Design Tokens](#design-tokens)
3. [Components](#components)
4. [Accessibility](#accessibility)
5. [Usage Examples](#usage-examples)

---

## Design Principles

### 1. Liquid Glass Aesthetic
SwiftClimb uses iOS 26's Liquid Glass design language:
- **Frosted glass backgrounds** using system materials (`.regularMaterial`, `.thickMaterial`)
- **Subtle depth** through layering and transparency
- **Fluid animations** with natural spring curves
- **Adaptive colors** that respond to light/dark mode

### 2. Accessibility First
All components support:
- **Dynamic Type** for text scaling
- **Reduce Transparency** mode with solid backgrounds
- **Darker System Colors** for increased contrast
- **VoiceOver** with descriptive labels
- **Minimum 44x44pt tap targets** (iOS HIG requirement)

### 3. Consistency
- All spacing uses the defined scale (no arbitrary values)
- All colors use semantic names (not hardcoded colors)
- All components reuse design tokens

---

## Design Tokens

Design tokens are the atomic values that compose the design system. Always use tokens instead of hardcoded values.

### Spacing

**File**: `Core/DesignSystem/Tokens/Spacing.swift`

```swift
enum SCSpacing {
    static let xxs: CGFloat = 4   // Extra extra small
    static let xs: CGFloat = 8    // Extra small
    static let sm: CGFloat = 12   // Small
    static let md: CGFloat = 16   // Medium (default)
    static let lg: CGFloat = 24   // Large
    static let xl: CGFloat = 32   // Extra large
    static let xxl: CGFloat = 48  // Extra extra large
}
```

**Usage Guide**:
- `xxs` (4pt): Minimal spacing between tightly related elements (icon + text)
- `xs` (8pt): Tight spacing within components (chip padding)
- `sm` (12pt): Default spacing between related elements
- `md` (16pt): Standard padding for cards and containers
- `lg` (24pt): Spacing between sections
- `xl` (32pt): Large spacing between major sections
- `xxl` (48pt): Maximum spacing for visual separation

**Example**:
```swift
VStack(spacing: SCSpacing.md) {
    Text("Title")
    Text("Subtitle")
}
.padding(SCSpacing.lg)
```

---

### Typography

**File**: `Core/DesignSystem/Tokens/Typography.swift`

All typography uses Dynamic Type for accessibility.

```swift
enum SCTypography {
    static let largeTitle: Font = .largeTitle
    static let title: Font = .title
    static let title2: Font = .title2
    static let title3: Font = .title3
    static let headline: Font = .headline
    static let body: Font = .body
    static let callout: Font = .callout
    static let caption: Font = .caption

    // Custom semantic styles
    static let cardTitle: Font = .headline
    static let metricValue: Font = .title2.bold()
    static let buttonLabel: Font = .body.weight(.semibold)
}
```

**Usage Guide**:
- `largeTitle`: Hero text (session summaries, main headings)
- `title`: Primary screen titles
- `title2`: Secondary headings
- `title3`: Tertiary headings
- `headline`: Card titles, list headers
- `body`: Default body text
- `callout`: Emphasized body text
- `caption`: Metadata, timestamps

**Example**:
```swift
VStack(alignment: .leading, spacing: SCSpacing.xs) {
    Text("My Session")
        .font(SCTypography.cardTitle)
    Text("45 min • 12 climbs")
        .font(SCTypography.caption)
        .foregroundStyle(.secondary)
}
```

---

### Colors

**File**: `Core/DesignSystem/Tokens/Colors.swift`

All colors are semantic and adapt to light/dark mode automatically.

#### Semantic Colors

```swift
enum SCColors {
    // Brand colors
    static let primary: Color = .blue      // Primary brand color
    static let secondary: Color = .cyan    // Secondary brand color
    static let accent: Color = .tint       // Accent highlights

    // Text colors
    static let textPrimary: Color = .primary
    static let textSecondary: Color = .secondary
    static let textTertiary: Color = Color(white: 0.6)
}
```

#### Metric Colors

Used for readiness, RPE, and pump level indicators.

```swift
enum SCColors {
    static let metricLow: Color = .red      // Low values (1-3)
    static let metricMedium: Color = .orange // Medium values (4-6)
    static let metricHigh: Color = .green   // High values (7-10)
}
```

**Mapping**:
- **Readiness (1-5)**: 1-2 = red, 3 = orange, 4-5 = green
- **RPE (1-10)**: 1-3 = green, 4-7 = orange, 8-10 = red (reversed!)
- **Pump (1-5)**: 1-2 = green, 3 = orange, 4-5 = red (reversed!)

#### Tag Impact Colors

```swift
enum SCColors {
    static let impactHelped: Color = .green    // Positive impact
    static let impactHindered: Color = .red    // Negative impact
    static let impactNeutral: Color = .gray    // Neutral impact
}
```

#### Surface Colors

```swift
enum SCColors {
    static let cardBackground: Material = .regularMaterial
    static let sheetBackground: Material = .thickMaterial
}
```

**Material Hierarchy**:
- `.regularMaterial`: Default cards, inline elements
- `.thickMaterial`: Sheets, modals, overlays (more opacity)

**Example**:
```swift
func readinessColor(_ readiness: Int) -> Color {
    switch readiness {
    case 1...2: return SCColors.metricLow
    case 3: return SCColors.metricMedium
    case 4...5: return SCColors.metricHigh
    default: return SCColors.textSecondary
    }
}

Text("Readiness: \(readiness)")
    .foregroundStyle(readinessColor(readiness))
```

---

### Corner Radius

**File**: `Core/DesignSystem/Tokens/CornerRadius.swift`

```swift
enum SCCornerRadius {
    static let card: CGFloat = 12     // Cards, containers
    static let sheet: CGFloat = 16    // Sheets, modals
    static let chip: CGFloat = 8      // Tags, chips
    static let button: CGFloat = 12   // Buttons
}
```

**Usage**:
```swift
RoundedRectangle(cornerRadius: SCCornerRadius.card)
    .fill(.regularMaterial)
```

---

## Components

All components are in `Core/DesignSystem/Components/`.

### SCGlassCard

**Purpose**: Primary container for content with Liquid Glass effect.

**File**: `SCGlassCard.swift`

**API**:
```swift
struct SCGlassCard<Content: View>: View {
    init(@ViewBuilder content: () -> Content)
}
```

**Features**:
- Frosted glass background (`.regularMaterial`)
- Automatic Reduce Transparency support (solid background fallback)
- Rounded corners (12pt)
- Standard padding (16pt)

**Usage**:
```swift
SCGlassCard {
    VStack(alignment: .leading, spacing: SCSpacing.xs) {
        Text("Card Title")
            .font(SCTypography.cardTitle)
        Text("Card content")
            .font(SCTypography.body)
    }
}
```

**Accessibility**:
- ✅ Reduce Transparency: Uses solid `.systemBackground` color
- ✅ VoiceOver: Content inside is accessible
- ✅ Dynamic Type: Adapts to text size

---

### SCPrimaryButton

**Purpose**: Primary call-to-action button.

**File**: `SCPrimaryButton.swift`

**API**:
```swift
struct SCPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isFullWidth: Bool = false
}
```

**Features**:
- Prominent styling (`.borderedProminent`)
- Loading state with spinner
- Optional full-width mode
- Minimum 44pt height

**Usage**:
```swift
struct SessionView: View {
    @Environment(\.startSessionUseCase) private var startSessionUseCase

    var body: some View {
        SCPrimaryButton(title: "Start Session") {
            await handleStartSession()
        }
    }

    private func handleStartSession() async {
        do {
            _ = try await startSessionUseCase.execute(
                userId: currentUserId,
                mentalReadiness: nil,
                physicalReadiness: nil
            )
        } catch {
            // Handle error
        }
    }
}

// With loading state
@State private var isSaving = false

SCPrimaryButton(
    title: "Save",
    action: { await save() },
    isLoading: isSaving
)

// Full width
SCPrimaryButton(
    title: "Continue",
    action: { await handleContinue() },
    isFullWidth: true
)
```

**States**:
- **Normal**: Blue background, white text
- **Loading**: Spinner + disabled
- **Disabled**: Grayed out

**Accessibility**:
- ✅ Minimum 44x44pt tap target
- ✅ Loading state announced by VoiceOver
- ✅ Disabled state announced

---

### SCSecondaryButton

**Purpose**: Secondary actions, less prominent than primary.

**File**: `SCSecondaryButton.swift`

**API**:
```swift
struct SCSecondaryButton: View {
    let title: String
    let action: () -> Void
}
```

**Features**:
- Bordered style (`.bordered`)
- Subtle appearance
- Minimum 44pt height

**Usage**:
```swift
struct FormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.saveUseCase) private var saveUseCase

    var body: some View {
        HStack {
            SCSecondaryButton(title: "Cancel") {
                dismiss()
            }

            SCPrimaryButton(title: "Save") {
                await handleSave()
            }
        }
    }

    private func handleSave() async {
        do {
            try await saveUseCase.execute()
            dismiss()
        } catch {
            // Handle error
        }
    }
}
```

---

### SCTagChip

**Purpose**: Display tags with impact indicators.

**File**: `SCTagChip.swift`

**API**:
```swift
struct SCTagChip: View {
    let tag: String
    let impact: TagImpact?
}

enum TagImpact {
    case helped, hindered, neutral
}
```

**Features**:
- Compact pill shape
- Color-coded impact indicators
- Small corner radius (8pt)

**Usage**:
```swift
HStack {
    SCTagChip(tag: "Drop Knee", impact: .helped)
    SCTagChip(tag: "Flexibility", impact: .hindered)
    SCTagChip(tag: "Overhang", impact: nil)
}
```

**Visual**:
- Helped: Green foreground
- Hindered: Red foreground
- Neutral/nil: Gray foreground

**Accessibility**:
- ✅ Impact announced by VoiceOver ("Drop Knee, helped")

---

### SCMetricPill

**Purpose**: Display metrics (RPE, readiness, pump).

**File**: `SCMetricPill.swift`

**API**:
```swift
struct SCMetricPill: View {
    let label: String
    let value: Int?
    let range: ClosedRange<Int>
}
```

**Features**:
- Color-coded by value
- Shows label + value
- Optional (handles nil values)

**Usage**:
```swift
HStack {
    SCMetricPill(label: "RPE", value: 7, range: 1...10)
    SCMetricPill(label: "Readiness", value: 4, range: 1...5)
    SCMetricPill(label: "Pump", value: nil, range: 1...5)
}
```

**Colors**:
- RPE (1-10): 1-3 green, 4-7 orange, 8-10 red
- Readiness (1-5): 1-2 red, 3 orange, 4-5 green
- Pump (1-5): 1-2 green, 3 orange, 4-5 red

**Accessibility**:
- ✅ Value announced with context ("RPE: 7 out of 10")

---

### SCSessionBanner

**Purpose**: Indicates active climbing session.

**File**: `SCSessionBanner.swift`

**API**:
```swift
struct SCSessionBanner: View {
    let session: SCSession
    let onTap: () -> Void
}
```

**Features**:
- Prominent banner at top of screen
- Shows session duration
- Tappable to navigate to session

**Usage**:
```swift
struct HomeView: View {
    @Query(
        filter: #Predicate<SCSession> {
            $0.endedAt == nil && $0.deletedAt == nil
        }
    )
    private var activeSessions: [SCSession]

    @State private var navigationPath = NavigationPath()

    var body: some View {
        if let activeSession = activeSessions.first {
            SCSessionBanner(session: activeSession) {
                navigationPath.append(.sessionDetail(activeSession))
            }
        }
    }
}
```

**Accessibility**:
- ✅ Announced as "Active session" by VoiceOver
- ✅ Tap action announced

---

## Accessibility

### Dynamic Type

All text uses Dynamic Type:
```swift
Text("Title")
    .font(SCTypography.title)  // Scales with user settings
```

Test with:
- Settings > Accessibility > Display & Text Size > Larger Text
- Drag slider to test different sizes

### Reduce Transparency

All materials have fallback:
```swift
if UIAccessibility.isReduceTransparencyEnabled {
    RoundedRectangle(cornerRadius: SCCornerRadius.card)
        .fill(Color(UIColor.systemBackground))
} else {
    RoundedRectangle(cornerRadius: SCCornerRadius.card)
        .fill(.regularMaterial)
}
```

Test with:
- Settings > Accessibility > Display & Text Size > Reduce Transparency

### Darker System Colors

Colors automatically adapt:
```swift
static func adaptiveColor(
    _ color: Color,
    darkerSystemColors: Bool = UIAccessibility.isDarkerSystemColorsEnabled
) -> Color {
    guard darkerSystemColors else { return color }
    return color.opacity(1.2)  // System handles darkening
}
```

Test with:
- Settings > Accessibility > Display & Text Size > Increase Contrast

### VoiceOver

All interactive elements have labels:
```swift
Button("Save") { }
    .accessibilityLabel("Save session")
    .accessibilityHint("Saves the current session to your logbook")
```

Test with:
- Settings > Accessibility > VoiceOver
- Or triple-click side button

### Minimum Tap Targets

All buttons use 44x44pt minimum:
```swift
.frame(minWidth: 44, minHeight: 44)
```

---

## Usage Examples

### Building a Session Card

```swift
SCGlassCard {
    VStack(alignment: .leading, spacing: SCSpacing.sm) {
        // Header
        HStack {
            Text("Evening Session")
                .font(SCTypography.cardTitle)

            Spacer()

            Text("2h 15m")
                .font(SCTypography.caption)
                .foregroundStyle(.secondary)
        }

        // Metrics
        HStack(spacing: SCSpacing.xs) {
            SCMetricPill(label: "RPE", value: 7, range: 1...10)
            SCMetricPill(label: "Readiness", value: 4, range: 1...5)
            SCMetricPill(label: "Pump", value: 3, range: 1...5)
        }

        // Tags
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SCSpacing.xs) {
                SCTagChip(tag: "Drop Knee", impact: .helped)
                SCTagChip(tag: "Core", impact: .hindered)
                SCTagChip(tag: "Overhang", impact: nil)
            }
        }

        // Summary
        Text("12 climbs • 45 attempts • 8 sends")
            .font(SCTypography.caption)
            .foregroundStyle(.secondary)
    }
}
.padding(SCSpacing.md)
```

### Building a Form

```swift
VStack(spacing: SCSpacing.lg) {
    // Section 1
    VStack(alignment: .leading, spacing: SCSpacing.sm) {
        Text("Readiness")
            .font(SCTypography.headline)

        HStack(spacing: SCSpacing.xs) {
            ForEach(1...5, id: \.self) { value in
                Button("\(value)") {
                    readiness = value
                }
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(readiness == value ? SCColors.primary : .clear)
                )
            }
        }
    }

    // Section 2
    VStack(alignment: .leading, spacing: SCSpacing.sm) {
        Text("Notes")
            .font(SCTypography.headline)

        TextField("Optional notes", text: $notes, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(3...6)
    }

    // Actions
    HStack(spacing: SCSpacing.sm) {
        SCSecondaryButton(title: "Cancel") {
            dismiss()
        }

        SCPrimaryButton(
            title: "Start Session",
            action: { await startSession() },
            isLoading: isLoading,
            isFullWidth: true
        )
    }
}
.padding(SCSpacing.lg)

// View methods
@State private var isLoading = false
@Environment(\.startSessionUseCase) private var startSessionUseCase

private func startSession() async {
    isLoading = true
    defer { isLoading = false }

    do {
        _ = try await startSessionUseCase.execute(
            userId: currentUserId,
            mentalReadiness: mentalReadiness,
            physicalReadiness: physicalReadiness
        )
    } catch {
        // Handle error
    }
}
```

### Building a List

```swift
ScrollView {
    LazyVStack(spacing: SCSpacing.md) {
        ForEach(sessions) { session in
            SCGlassCard {
                VStack(alignment: .leading, spacing: SCSpacing.xs) {
                    // Session details
                    Text(session.startedAt, style: .date)
                        .font(SCTypography.cardTitle)

                    if let duration = session.duration {
                        Text(formatDuration(duration))
                            .font(SCTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Metrics
                    HStack {
                        if let rpe = session.rpe {
                            SCMetricPill(label: "RPE", value: rpe, range: 1...10)
                        }
                    }
                }
            }
            .onTapGesture {
                navigationPath.append(session)
            }
        }
    }
    .padding(SCSpacing.md)
}
```

---

## Best Practices

### DO:
✅ Always use design tokens (spacing, colors, typography)
✅ Test with Dynamic Type (all sizes)
✅ Test with Reduce Transparency
✅ Provide VoiceOver labels for all interactive elements
✅ Use minimum 44x44pt tap targets
✅ Use semantic color names (not literal colors)

### DON'T:
❌ Hardcode spacing values (`padding(16)`)
❌ Hardcode colors (`.blue`, `Color(red: 0.5, ...)`)
❌ Use custom fonts without Dynamic Type support
❌ Create tap targets smaller than 44x44pt
❌ Forget accessibility modifiers

---

## Component Checklist

When creating a new component:

- [ ] Uses design tokens (spacing, colors, typography)
- [ ] Has accessibility label/hint if interactive
- [ ] Minimum 44x44pt tap target
- [ ] Supports Dynamic Type
- [ ] Supports Reduce Transparency (material fallback)
- [ ] Supports light and dark mode
- [ ] Has preview provider
- [ ] Documented with doc comments
- [ ] Follows naming convention (SC prefix)

---

## Future Enhancements

Planned but not yet implemented:

1. **Animation tokens**: Standard spring curves, durations
2. **Shadow tokens**: Elevation system
3. **Gradient tokens**: Brand gradients
4. **Icon system**: SF Symbols catalog
5. **Loading states**: Skeleton screens, shimmer effects
6. **Empty states**: Illustrations, messages
7. **Error states**: Error cards, inline errors

---

**Last Updated**: 2026-01-18
**Author**: Agent 4 (The Scribe)
