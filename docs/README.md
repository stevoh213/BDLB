# SwiftClimb Documentation

This directory contains all technical documentation for the SwiftClimb project, organized by category.

## Documentation Structure

```
docs/
├── architecture/          # System architecture & design
│   ├── adr/              # Architecture Decision Records
│   ├── ARCHITECTURE.md    # Complete architecture guide
│   ├── DESIGN_SYSTEM.md   # UI components & design tokens
│   └── SYNC_STRATEGY.md   # Offline-first sync implementation
│
├── features/             # Feature documentation
│   ├── ADD_CLIMB.md      # Add Climb feature guide
│   ├── ADD_CLIMB_API.md  # Add Climb API reference
│   └── SESSIONS.md       # Session management
│
├── specifications/        # Feature & system specifications
│   ├── features/         # Per-feature specifications
│   │   ├── specs/        # Phase-by-phase implementation specs
│   │   ├── SOCIAL_PROFILE_FEATURE.md
│   │   ├── SOCIAL_PROFILE_COMPLETE.md
│   │   └── VALIDATION_REPORT.md
│   ├── PREMIUM_SYSTEM_SPECIFICATION.md
│   └── PREMIUM_SYNC_SPECIFICATION.md
│
├── design/               # UX/UI design documentation
│   └── (design guides)
│
├── database/             # Database documentation
│   └── (schema documentation)
│
├── agents/               # Multi-agent workflow documentation
│   └── (agent-specific docs)
│
└── reports/              # Implementation & validation reports
    ├── archive/          # Historical reports
    ├── IMPLEMENTATION_SUMMARY.md
    ├── DOCUMENTATION_SUMMARY.md
    ├── DOCUMENTATION_UPDATE_SUMMARY.md
    ├── PREMIUM_DOCUMENTATION_SUMMARY.md
    └── VALIDATION_REPORT_PREMIUM_SYNC.md
```

## Quick Links

### For New Developers
1. [README.md](../README.md) - Project overview and setup
2. [Architecture Guide](architecture/ARCHITECTURE.md) - System design and patterns
3. [Design System](architecture/DESIGN_SYSTEM.md) - UI components and tokens
4. [Contributing Guide](../CONTRIBUTING.md) - Coding standards

### For Understanding the System
- [Offline-First Sync Strategy](architecture/SYNC_STRATEGY.md) - How data synchronization works
- [Premium System Specification](specifications/PREMIUM_SYSTEM_SPECIFICATION.md) - Subscription features
- [Premium Sync Specification](specifications/PREMIUM_SYNC_SPECIFICATION.md) - Premium status synchronization

### Feature Documentation
- [Sessions Feature](features/SESSIONS.md) - Session tracking and management
- [Add Climb Feature](features/ADD_CLIMB.md) - Comprehensive climb data capture
- [Add Climb API Reference](features/ADD_CLIMB_API.md) - Technical API documentation
- [Tag System](features/TAG_SYSTEM.md) - Hold types and skills tagging with impact ratings

### For Implementation
- [Next Steps](../NEXT_STEPS.md) - Current roadmap and priorities
- [Technical Debt](../TECHNICAL_DEBT.md) - Known issues and improvements needed
- [Feature Specifications](specifications/features/) - Detailed feature specs

### Historical Context
- [Implementation Summary](reports/IMPLEMENTATION_SUMMARY.md) - Initial scaffolding summary
- [Documentation Summary](reports/DOCUMENTATION_SUMMARY.md) - Documentation creation process
- [Validation Reports](reports/) - Feature validation reports

## Architecture Decision Records (ADRs)

ADRs document important architectural decisions and their rationale:

_Note: ADR files need to be added to `architecture/adr/` directory_

## Documentation Standards

All documentation in this project follows these principles:

1. **Clarity Over Brevity** - Be clear and thorough
2. **Complete Context** - Explain the "why" not just the "what"
3. **Actionable Content** - Include code examples and step-by-step guides
4. **Accessibility** - Use clear headings, table of contents, and cross-references
5. **Maintainability** - Keep docs up-to-date with implementation

## Contributing to Documentation

When adding new documentation:

1. Choose the appropriate category (architecture, specifications, design, etc.)
2. Follow the existing documentation format
3. Include code examples where relevant
4. Add cross-references to related docs
5. Update this README.md with links to your new documentation

---

**Last Updated**: 2026-01-22
