# Link Testing Page for Obsidian Extensions

**Purpose**: Test different link formats and conversion behavior for WikiLinks and markdown links.

## WikiLinks Format Examples

### Basic Internal Page Links

- [[getting-started-basics]]
- [[daily-tasks-email]]
- [[troubleshooting-common]]
- [[reference-shortcuts]]

### Links with Spaces (Common Problem Area)

- [[Getting Started Basics]]
- [[Daily Tasks Email Management]]
- [[Troubleshooting Common Issues]]
- [[Reference Keyboard Shortcuts]]
- [[Advanced System Maintenance]]
- [[Browser Security Settings]]
- [[Safe Browsing Practices]]

### Links with Special Characters

- [[Email & Communication]]
- [[Passwords - Security Guide]]
- [[Files/Folders Management]]
- [[System Updates & Maintenance]]
- [[FAQ: Common Questions]]
- [[Rob's Computer Manual]]

### WikiLinks with Aliases (Display Text Different from Target)

- [[getting-started-basics|Computer Basics]]
- [[daily-tasks-email|Email Guide]]
- [[troubleshooting-common|Common Problems]]
- [[reference-shortcuts|Keyboard Reference]]
- [[Browser Security Settings|Browser Safety]]

### WikiLinks with Aliases and Spaces

- [[Getting Started Basics|Introduction to Computers]]
- [[Daily Tasks Email Management|Managing Your Email]]
- [[Troubleshooting Common Issues|Solving Problems]]
- [[Advanced System Maintenance|System Care]]

### Image WikiLinks

- ![](<./assets/screenshots/1password-main.png>)
- ![](<./assets/screenshots/1password-search.png>)
- ![](<./assets/screenshots/screenshot-desktop.png>)
- ![](<./assets/screenshots/browser-settings.png>)
- ![](<./assets/diagrams/diagram-system-overview.png>)
- ![](<./assets/diagrams/workflow-diagram.png>)

### Image WikiLinks with Alt Text

- ![1Password Main Interface](<./assets/screenshots/1password-main.png>)
- ![Searching in 1Password](<./assets/screenshots/1password-search.png>)
- ![Desktop Screenshot](<./assets/screenshots/screenshot-desktop.png>)
- ![System Overview Diagram](<./assets/diagrams/diagram-system-overview.png>)

## Markdown Links Format Examples

### Basic Internal Page Links (Target Format)

- [getting-started-basics](https://claude.ai/chat/getting-started-basics.md)
- [daily-tasks-email](https://claude.ai/chat/daily-tasks-email.md)
- [troubleshooting-common](https://claude.ai/chat/troubleshooting-common.md)
- [reference-shortcuts](https://claude.ai/chat/reference-shortcuts.md)

### Links with Spaces Converted to Hyphens

- [Getting Started Basics](https://claude.ai/chat/getting-started-basics.md)
- [Daily Tasks Email Management](https://claude.ai/chat/daily-tasks-email-management.md)
- [Troubleshooting Common Issues](https://claude.ai/chat/troubleshooting-common-issues.md)
- [Reference Keyboard Shortcuts](https://claude.ai/chat/reference-keyboard-shortcuts.md)
- [Advanced System Maintenance](https://claude.ai/chat/advanced-system-maintenance.md)
- [Browser Security Settings](https://claude.ai/chat/browser-security-settings.md)
- [Safe Browsing Practices](https://claude.ai/chat/safe-browsing-practices.md)

### Links with Special Characters (How They Should Convert)

- [Email & Communication](https://claude.ai/chat/email-communication.md)
- [Passwords - Security Guide](https://claude.ai/chat/passwords-security-guide.md)
- [Files/Folders Management](https://claude.ai/chat/files-folders-management.md)
- [System Updates & Maintenance](https://claude.ai/chat/system-updates-maintenance.md)
- [FAQ: Common Questions](https://claude.ai/chat/faq-common-questions.md)
- [Rob's Computer Manual](https://claude.ai/chat/robs-computer-manual.md)

### Markdown Links with Display Text

- [Computer Basics](https://claude.ai/chat/getting-started-basics.md)
- [Email Guide](https://claude.ai/chat/daily-tasks-email.md)
- [Common Problems](https://claude.ai/chat/troubleshooting-common.md)
- [Keyboard Reference](https://claude.ai/chat/reference-shortcuts.md)
- [Browser Safety](https://claude.ai/chat/browser-security-settings.md)

### Image Markdown Links

- ![1password-main.png](https://claude.ai/chat/assets/screenshots/1password-main.png)
- ![1password-search.png](https://claude.ai/chat/assets/screenshots/1password-search.png)
- ![screenshot-desktop.png](https://claude.ai/chat/assets/screenshots/screenshot-desktop.png)
- ![browser-settings.png](https://claude.ai/chat/assets/screenshots/browser-settings.png)
- ![diagram-system-overview.png](https://claude.ai/chat/assets/diagrams/diagram-system-overview.png)
- ![workflow-diagram.png](https://claude.ai/chat/assets/diagrams/workflow-diagram.png)

### Image Markdown Links with Alt Text

- ![1Password Main Interface](https://claude.ai/chat/assets/screenshots/1password-main.png)
- ![Searching in 1Password](https://claude.ai/chat/assets/screenshots/1password-search.png)
- ![Desktop Screenshot](https://claude.ai/chat/assets/screenshots/screenshot-desktop.png)
- ![System Overview Diagram](https://claude.ai/chat/assets/diagrams/diagram-system-overview.png)

## Side-by-Side Comparison Examples

### WikiLinks vs Expected Markdown Conversion

#### Example 1: Simple Page Link

**WikiLink**: `[[getting-started-basics]]`  
**Should Convert To**: `[getting-started-basics](getting-started-basics.md)`

#### Example 2: Link with Spaces

**WikiLink**: `[[Getting Started Basics]]`  
**Should Convert To**: `[Getting Started Basics](getting-started-basics.md)`

#### Example 3: Link with Alias

**WikiLink**: `[[getting-started-basics|Computer Basics]]`  
**Should Convert To**: `[Computer Basics](getting-started-basics.md)`

#### Example 4: Link with Spaces and Alias

**WikiLink**: `[[Getting Started Basics|Introduction to Computers]]`  
**Should Convert To**: `[Introduction to Computers](getting-started-basics.md)`

#### Example 5: Special Characters

**WikiLink**: `[[Email & Communication]]`  
**Should Convert To**: `[Email & Communication](email-communication.md)`

#### Example 6: Image Link (Screenshots)

**WikiLink**: `![[1password-main.png]]`  
**Should Convert To**: `![1password-main.png](assets/screenshots/1password-main.png)`

#### Example 7: Image Link (Diagrams)

**WikiLink**: `![[diagram-system-overview.png]]`  
**Should Convert To**: `![diagram-system-overview.png](assets/diagrams/diagram-system-overview.png)`

#### Example 8: Image with Alt Text

**WikiLink**: `![[1password-main.png|1Password Main Interface]]`  
**Should Convert To**: `![1Password Main Interface](assets/screenshots/1password-main.png)`

#### Example 9: Diagram with Alt Text

**WikiLink**: `![[diagram-system-overview.png|System Overview Diagram]]`  
**Should Convert To**: `![System Overview Diagram](assets/diagrams/diagram-system-overview.png)`

## Complex Link Scenarios

### Nested in Lists

1. First item with [[Getting Started Basics]] link
2. Second item with [[Daily Tasks Email Management]] link
3. Third item with [[Advanced System Maintenance]] link

### In Tables

|Topic|Link|Description|
|---|---|---|
|Basics|[[Getting Started Basics]]|Computer fundamentals|
|Email|[[Daily Tasks Email Management]]|Email operations|
|Troubleshooting|[[Troubleshooting Common Issues]]|Problem solving|

### In Blockquotes

> For more information, see [[Getting Started Basics]] and [[Daily Tasks Email Management]].
> 
> Also check the [[Reference Keyboard Shortcuts]] for quick commands.

### Mixed with Markdown Links

Here's a mix: [[Getting Started Basics]] and [External Link](https://example.com/) and [[Daily Tasks Email Management|Email Guide]].

## Edge Cases and Problem Areas

### Links That Might Cause Issues

- [[File with (Parentheses)]]
- [[File with [Brackets]]]
- [[File with "Quotes"]]
- [[File with 'Apostrophe']]
- [[File with Multiple Spaces]]
- [[File-with-existing-hyphens]]
- [[File_with_underscores]]

### URLs That Should NOT Convert

- https://example.com
- http://robkanzer.com
- mailto:robkanzer@robkanzer.com
- ftp://files.example.com

### Existing Markdown Links (Should Remain Unchanged)

- [External Website](https://example.com/)
- [Email Link](mailto:test@example.com)
- [Anchor Link](https://claude.ai/chat/3ef65fa2-c8e8-42b1-814f-213bcf3a88b9#section-name)
- [Relative Path](https://claude.ai/other-folder/file.md)

## Testing Instructions

### What to Check After Extension Runs:

1. **WikiLinks should convert** to markdown format
2. **Spaces should become hyphens** in file names
3. **Special characters should be cleaned** from file names
4. **Aliases should become display text** in markdown links
5. **Images should get proper asset paths**:
    - Screenshots: `assets/screenshots/filename.png`
    - Diagrams: `assets/diagrams/filename.png`
6. **Existing markdown links should remain unchanged**
7. **External URLs should remain unchanged**

### Common Conversion Issues:

- Extension doesn't run automatically on save
- Spaces not converted to hyphens properly
- Special characters not handled correctly
- Image paths not updated to include asset folder
- Aliases not preserved as display text
- Extension converts external URLs (should not happen)

### Manual Testing Steps:

1. Save this file with WikiLinks
2. Check if extension automatically converts
3. If not, try manual trigger (if available)
4. Compare results with expected markdown format above
5. Check for any unconverted or incorrectly converted links

---

**Extension Testing Status**:

- [ ] WikiLinks converted to markdown
- [ ] Spaces handled correctly
- [ ] Special characters cleaned
- [ ] Image paths updated
- [ ] Aliases preserved
- [ ] External links unchanged