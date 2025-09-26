# rk-comp-wksp Workflow Guide

**Target Audience**: Kent Gale (Content Creator)  
**Content Platform**: Obsidian with WikiLinks extension  
**Publishing Platform**: Docsify via automated deployment  
**Update Mechanism**: Git-based with automated distribution  

## Content Creation Workflow

### Overview

The content creation workflow enables Kent to author and update Rob's computer manual using Obsidian, with automatic distribution to Rob's machine through GitHub and the automated PowerShell system.

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AUTHORING     │    │   DISTRIBUTION  │    │   CONSUMPTION   │
│                 │    │                 │    │                 │
│ 1. Edit in      │───▶│ 2. Git Push     │───▶│ 3. Auto-Update │
│    Obsidian     │    │    to GitHub    │    │    Rob's PC     │
│                 │    │                 │    │                 │
│ • WikiLinks     │    │ • Version Ctrl  │    │ • Daily Sync    │
│ • Live Preview  │    │ • Change Log    │    │ • Web Server    │
│ • Asset Mgmt    │    │ • Collaboration │    │ • Notifications │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Obsidian Setup and Configuration

### Workspace Location
```
~/Vaults-repos/rk-comp-wksp/rk-comp-man/
├── assets/                 # Images, animations, diagrams
│   ├── screenshots/        # Step-by-step visual guides
│   ├── animations/         # GIF demonstrations
│   └── diagrams/          # System architecture visuals
├── index.html             # Docsify configuration
├── _sidebar.md            # Navigation structure
├── README.md              # Manual homepage/introduction
└── *.md                   # Manual content files
```

### Required Obsidian Extensions

#### WikiLinks Extension (Critical)
**Purpose**: Converts `[[Page Name]]` to `[Page Name](page-name.md)` for Docsify compatibility

**Installation**:
1. Open Obsidian Settings → Community Plugins
2. Search for "WikiLinks"
3. Install and enable extension
4. Configure conversion settings:
   - Auto-convert on save: ✅ Enabled
   - Preserve original text: ✅ Enabled
   - Case conversion: `kebab-case` for file names

#### Recommended Extensions
- **Templater**: For consistent page formatting
- **Advanced Tables**: For data presentation
- **Image Toolkit**: For asset management
- **Git**: For version control within Obsidian

### Obsidian Configuration
```json
{
  "useMarkdownLinks": true,
  "newLinkFormat": "relative",
  "attachmentFolderPath": "assets",
  "promptToDeleteEmptyFolders": true,
  "showUnsupportedFiles": false
}
```

## Content Organization Strategy

### Navigation Structure

#### Primary Categories
1. **Getting Started** - Rob's introduction and basic concepts
2. **Daily Tasks** - Common computer operations
3. **Applications** - Software-specific guides
4. **Troubleshooting** - Problem-solving procedures
5. **Reference** - Quick lookup information
6. **Advanced** - Complex procedures and maintenance

#### File Naming Convention
```
category-topic-subtopic.md

Examples:
- getting-started-introduction.md
- daily-tasks-email-management.md
- applications-browser-bookmarks.md
- troubleshooting-printer-offline.md
- reference-keyboard-shortcuts.md
- advanced-system-maintenance.md
```

#### _sidebar.md Structure
```markdown
- [Introduction](README.md)

- Getting Started
  - [Computer Basics](getting-started-basics.md)
  - [Desktop Navigation](getting-started-desktop.md)
  - [File Management](getting-started-files.md)

- Daily Tasks
  - [Email Management](daily-tasks-email.md)
  - [Web Browsing](daily-tasks-web.md)
  - [Document Creation](daily-tasks-documents.md)

- Applications
  - [Browser](applications-browser.md)
  - [Email Client](applications-email.md)
  - [Office Suite](applications-office.md)

- Troubleshooting
  - [Common Issues](troubleshooting-common.md)
  - [Error Messages](troubleshooting-errors.md)
  - [Getting Help](troubleshooting-help.md)

- Reference
  - [Keyboard Shortcuts](reference-shortcuts.md)
  - [Quick Commands](reference-commands.md)
  - [Contact Information](reference-contacts.md)
```

## Content Creation Best Practices

### Writing Guidelines

#### Tone and Style
- **Conversational**: Write as if explaining to a friend
- **Patient**: Assume no prior technical knowledge
- **Encouraging**: Build confidence with positive language
- **Specific**: Use exact button names, menu paths, and terminology

#### Structure Template
```markdown
# Task/Topic Title

## What This Does
Brief explanation of the purpose and outcome.

## When to Use This
Situations where this information is helpful.

## Step-by-Step Instructions

### Step 1: [Action Description]
1. Click on [specific button/menu]
2. Look for [specific text/icon]
3. Select [specific option]

**What you'll see**: Description of expected result.

### Step 2: [Next Action]
[Continue with detailed steps...]

## Common Issues
- **Problem**: Description of common problem
  **Solution**: Step-by-step solution

## Related Topics
- [Link to related guide](related-topic.md)
- [Link to troubleshooting](troubleshooting-related.md)
```

### Visual Content Strategy

#### Screenshots
**Location**: `assets/screenshots/`
**Naming**: `topic-step-description.png`
**Guidelines**:
- Capture full screen context when helpful
- Highlight relevant areas with arrows/boxes
- Use consistent highlighting colors
- Include mouse cursor when showing click locations

#### Animations/GIFs
**Location**: `assets/animations/`
**Naming**: `topic-process-description.gif`
**Use Cases**:
- Multi-step procedures
- Mouse movement demonstrations
- Software interactions
- Error resolution workflows

#### Diagrams
**Location**: `assets/diagrams/`
**Tools**: Obsidian Canvas, Draw.io, or external tools
**Types**:
- System layouts
- Process flows
- Concept relationships
- Troubleshooting decision trees

### Asset Management

#### Image Embedding
```markdown
# Correct format for Docsify compatibility
![Description](assets/screenshots/example.png)

# NOT: ![Description](assets/screenshots/example.png)
# NOT: ![[example.png]]
```

#### Asset Organization
```
assets/
├── screenshots/
│   ├── applications/
│   ├── daily-tasks/
│   ├── getting-started/
│   └── troubleshooting/
├── animations/
│   ├── procedures/
│   └── demonstrations/
└── diagrams/
    ├── system-layouts/
    └── process-flows/
```

## Content Publishing Workflow

### Development Process

#### 1. Content Planning
```markdown
# Create content outline in Obsidian
- Identify Rob's specific needs
- Research current best practices
- Plan screenshot/asset requirements
- Structure information hierarchy
```

#### 2. Content Creation
```markdown
# In Obsidian vault
1. Create new .md file with proper naming
2. Use content template for consistency
3. Write step-by-step instructions
4. Capture necessary screenshots/assets
5. Test all links and references
```

#### 3. Local Review
```markdown
# Before publishing
1. Preview content in Obsidian
2. Verify WikiLinks conversion
3. Check asset links and embedding
4. Review for clarity and completeness
5. Test on different screen sizes
```

#### 4. Publishing
```bash
# From ~/Vaults-repos/rk-comp-wksp/
git add .
git commit -m "Add: [description of changes]"
git push origin main
```

#### 5. Verification
```markdown
# After publishing (within 24 hours)
1. Verify content appears on Rob's machine
2. Test all links and navigation
3. Confirm assets display correctly
4. Check for any formatting issues
```

### Git Workflow

#### Commit Message Conventions
```bash
# New content
git commit -m "Add: New email troubleshooting guide"

# Content updates
git commit -m "Update: Browser security section with latest procedures"

# Asset additions
git commit -m "Assets: Add screenshots for printer setup guide"

# Structure changes
git commit -m "Organize: Restructure troubleshooting section"

# Fixes
git commit -m "Fix: Correct broken links in applications section"
```

#### Branch Strategy
**Main Branch Only**: For simplicity, all content goes directly to main branch
**Alternative**: Feature branches for major reorganizations

### Quality Assurance

#### Pre-Publication Checklist
- [ ] Content follows established style guide
- [ ] All links work correctly (use relative paths)
- [ ] Screenshots are current and clear
- [ ] Step-by-step instructions tested
- [ ] No technical jargon without explanation
- [ ] Related topics linked appropriately
- [ ] Consistent formatting throughout

#### Post-Publication Verification
- [ ] Content appears correctly on Rob's machine
- [ ] Navigation works properly
- [ ] Assets load without errors
- [ ] Search functionality works (if implemented)
- [ ] Mobile responsiveness (if Rob uses tablet/phone)

## Content Maintenance

### Regular Updates

#### Monthly Review
```markdown
# Content freshness check
1. Review software screenshots for UI changes
2. Verify all procedures still work
3. Update outdated information
4. Add new topics based on Rob's questions
5. Remove or archive obsolete content
```

#### Quarterly Overhaul
```markdown
# Comprehensive content audit
1. Reorganize structure based on usage patterns
2. Improve unclear or confusing sections
3. Add advanced topics as Rob's skills develop
4. Update all screenshots and assets
5. Optimize for search and navigation
```

### Content Analytics

#### Tracking Effectiveness
```markdown
# Informal feedback methods
1. Direct feedback from Rob during support calls
2. AnyDesk session observations
3. Email questions indicating content gaps
4. System logs showing accessed pages (if implemented)
```

#### Continuous Improvement
```markdown
# Based on feedback
1. Identify most-used content for prioritization
2. Find common confusion points for clarification
3. Discover missing topics for future content
4. Optimize navigation based on user flow
```

## Collaboration Considerations

### Future Content Contributors

#### Onboarding Process
```markdown
# For additional content creators
1. Obsidian setup and configuration
2. WikiLinks extension installation
3. Content style guide review
4. Git workflow training
5. Quality assurance procedures
```

#### Content Standards
```markdown
# Maintaining consistency
1. Use established templates
2. Follow naming conventions
3. Maintain tone and style
4. Verify technical accuracy
5. Test all procedures before publishing
```

### Version Control

#### Change Tracking
```markdown
# Document significant changes
1. Keep changelog.md updated
2. Use descriptive commit messages
3. Tag major releases/reorganizations
4. Backup before major changes
```

#### Rollback Procedures
```bash
# If content changes cause issues
git log --oneline
git revert [commit-hash]
git push origin main

# Rob's system will automatically update within 24 hours
```

## Content Types and Templates

### Procedure Guide Template
```markdown
# [Task Name]

## Overview
What this accomplishes and why it's useful.

## You'll Need
- Required information
- Necessary access/permissions
- Time estimate

## Instructions

### Step 1: [Action]
Detailed instruction with expected outcome.

### Step 2: [Next Action]
Continue with specific steps.

## Troubleshooting
Common issues and solutions.

## Related
Links to related procedures.
```

### Reference Page Template
```markdown
# [Reference Topic]

## Quick Reference
Key information for immediate use.

## Detailed Information
Comprehensive explanation when needed.

## Examples
Real-world usage examples.

## See Also
Related reference materials.
```

### Troubleshooting Template
```markdown
# [Problem Description]

## Symptoms
What the user experiences.

## Likely Causes
Common reasons for this problem.

## Solutions

### Solution 1: [Simple Fix]
Try this first.

### Solution 2: [Advanced Fix]
If the simple fix doesn't work.

## Prevention
How to avoid this problem in the future.

## Get Help
When to contact Kent for assistance.
```

## Success Metrics

### Content Quality Indicators
- Rob can complete tasks independently using the manual
- Fewer support calls for covered topics
- Positive feedback on content clarity
- Successful task completion without confusion

### Process Efficiency Metrics
- Time from content creation to Rob's access: <24 hours
- Content update frequency: Weekly as needed
- Zero technical publishing failures
- Minimal Kent maintenance overhead

### User Experience Goals
- Rob finds information quickly
- Instructions are clear and accurate
- Content stays current and relevant
- System operates invisibly to Rob

---

**Workflow Confidence**: High - Proven process with robust automation  
**Content Platform**: Obsidian + WikiLinks extension  
**Distribution**: Automated via Git and PowerShell system  
**Maintenance**: Minimal overhead with maximum impact for Rob