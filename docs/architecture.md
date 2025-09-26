# rk-comp-wksp Architecture

## Project Overview

The rk-comp-wksp project provides remote assistance infrastructure for Rob Kanzer's computer workspace management. The system enables Kent Gale (kentonium3) to maintain and update a reference manual that Rob can access locally through a web interface.

## System Components

### Content Authoring (Kent's MacBook)
- **Obsidian Vault**: `~/Vaults-repos/rk-comp-wksp/rk-comp-man/`
  - Content creation and editing environment
  - WikiLinks converted to markdown links via extension
  - Git-integrated for version control

- **Git Repository**: `~/Vaults-repos/rk-comp-wksp/`
  - Central coordination point for all project files
  - Syncs with GitHub repository
  - Structure:
    ```
    rk-comp-wksp/
    ├── code/           # Windows batch files, scripts
    ├── docs/           # Project documentation 
    └── rk-comp-man/    # Obsidian vault & Docsify content
        ├── assets/     # Images, animations, diagrams
        ├── index.html  # Docsify configuration
        └── *.md        # Reference manual content
    ```

### Content Distribution (GitHub)
- **Repository**: github.com/kentonium3/rk-comp-wksp
- **Purpose**: Intermediate sync point between Kent's authoring and Rob's consumption
- **Branch Strategy**: Single main branch for simplicity

### Content Consumption (Rob's Windows Machine)

#### File Structure
```
C:\Users\Rob\
├── rk-comp-wksp\                    # Git repository (background)
│   ├── code\
│   ├── docs\
│   └── rk-comp-man\
└── Documents\
    └── Rob's Computer Manual\       # Deployed content (user-facing)
        ├── logs\                    # System operation logs
        ├── assets\                  # Copied from repo
        ├── index.html              # Docsify entry point
        └── *.md                    # Reference content
```

#### Services
- **Web Server**: Minimal Python HTTP server (port 8080)
  - Auto-starts on login
  - Serves content from `Documents\Rob's Computer Manual\`
  - Robust error handling and logging

- **Update Service**: Daily git pull + content deployment
  - Scheduled task runs daily
  - Manual trigger via desktop icon
  - Updates Python, Docsify, and other components
  - 30-day log rotation

#### User Interface
- **Desktop Shortcut**: Direct link to `localhost:8080`
- **Refresh Icon**: Manual update trigger for immediate content refresh
- **Invisible Operation**: All technical components hidden from daily use

## Technical Specifications

### Dependencies
- **Kent's Machine**: 
  - Obsidian with WikiLinks extension
  - Git with GitHub authentication
  - macOS Sequoia/Tahoe compatibility

- **Rob's Machine**:
  - Python 3.x (minimal installation)
  - Git with configured credentials
  - Windows Task Scheduler
  - Modern web browser

### Git Configuration
- **Credentials**: To be configured during Rob's machine setup
- **Repository Access**: Read-only for Rob's machine
- **Sync Strategy**: Pull-only, no local commits from Rob's machine

### Error Handling & Monitoring

#### Logging Strategy
- **Location**: `Documents\Rob's Computer Manual\logs\`
- **Rotation**: 30-day automatic cleanup
- **Format**: Timestamped entries with error levels
- **Files**: 
  - `webserver_YYYYMMDD.log`
  - `update_YYYYMMDD.log`

#### Failure Notification
- **Method**: Email alerts on task failures
- **Configuration**: File-based settings for easy updates
- **Recipients**: Configurable notification list
- **Triggers**: 
  - Web server startup failure
  - Git pull failures  
  - Component update failures
  - Scheduled task execution problems

### Security Considerations
- **Network**: Local-only web server (localhost:8080)
- **File Access**: Standard user permissions
- **Git Access**: HTTPS with stored credentials
- **Remote Administration**: AnyDesk for Kent's access

## Workflow Processes

### Content Creation (Kent)
1. Author content in Obsidian vault
2. WikiLinks automatically converted to markdown
3. Commit and push changes to GitHub
4. Changes automatically propagate to Rob's machine within 24 hours

### Content Updates (Rob's Machine)
1. **Automatic**: Daily scheduled task pulls updates
2. **Manual**: Desktop icon triggers immediate refresh
3. **Components**: System also updates Python, Docsify, web server
4. **Deployment**: Content copied to user-friendly location
5. **Logging**: All operations logged with error detection

### Maintenance (Kent)
1. **Remote Access**: AnyDesk for troubleshooting
2. **Log Review**: Check operation logs for issues
3. **Component Updates**: Manage Python, Git, and tool versions
4. **Configuration Changes**: Update email settings, schedules, etc.

## Design Decisions

### Repository Structure
- **Separation**: Obsidian vault separate from other project files
- **Deployment**: Copy content rather than serve directly from repo
- **Hidden Files**: .gitignore configured for Obsidian and system files

### Web Server Choice
- **Python HTTP Server**: Minimal footprint, reliable, cross-platform
- **Alternative Options**: Node.js http-server, Go binary server
- **Port Selection**: 8080 (commonly available, easy to remember)

### Update Strategy
- **Pull-Only**: Rob's machine never commits changes
- **Deployment Copy**: Separate user-facing location from repo
- **Component Management**: Automated updates for stability

### User Experience
- **Invisibility**: Technical components hidden from Rob
- **Simplicity**: Single desktop icon for manual refresh
- **Reliability**: Robust error handling and automatic recovery

## Future Considerations

### Scalability
- **Multiple Users**: Architecture supports additional machines
- **Content Versioning**: Git provides rollback capabilities
- **Component Updates**: Automated dependency management

### Enhancement Opportunities
- **Health Dashboard**: Status page showing system state
- **Rollback Mechanism**: Quick recovery from problematic updates
- **Advanced Notifications**: Slack, SMS, or other alert methods
- **Content Analytics**: Usage tracking and optimization

## Implementation Status

### Completed
- Overall system design and approach
- AnyDesk remote access setup
- Initial Obsidian vault and Git repository
- Basic workflow testing
- Directory structure planning

### In Progress
- Kent's local directory migration
- Obsidian vault relocation
- Git repository reorganization

### Pending
- Rob's machine setup and configuration
- Windows task creation and testing
- Error notification system implementation
- Component update automation
- Documentation completion