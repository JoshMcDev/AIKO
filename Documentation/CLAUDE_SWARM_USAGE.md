# AIKO Claude Swarm Usage Guide

## Phase 5 Meta-Orchestrator TDD System

Successfully installed and configured Claude Swarm for AIKO Phase 5 development with:
- ✅ Claude Sonnet 4 minimum (all instances)
- ✅ VanillaIce P1-P11 priority system integration
- ✅ Mandatory TDD workflow enforcement

## Quick Start

### 1. Setup PATH (run once per terminal session)
```bash
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"
```

### 2. Launch AIKO Meta-Orchestrator Team
```bash
cd /Users/J/aiko
claude-swarm start claude-swarm.yml
```

### 3. Use TDD Workflow Commands
The Meta-Orchestrator enforces this workflow:
```
/prd → /conTS → /tdd → /dev → /green → /refactor → /qa
```

## Team Structure

### Core TDD Workflow Team (8 Instances)
1. **meta_orchestrator** - Coordinates entire TDD workflow (Claude Sonnet 4)
2. **prd_specialist** - Enhanced requirements documents
3. **plan_architect** - Implementation planning with VanillaIce consensus  
4. **tdd_engineer** - DoS/DoD rubric and failing tests
5. **swift_dev_lead** - Swift/SwiftUI development with P1-P2 integration
6. **test_validator** - GREEN phase validation
7. **refactor_expert** - Code cleanup with P4 integration
8. **qa_gatekeeper** - Quality assurance gate
9. **vanillaice_coordinator** - P1-P11 specialized analysis

### VanillaIce P1-P11 Integration
- **P1**: Swift Implementation Expert (codex-mini-latest)
- **P2**: SwiftUI Sprint Leader (gemini-2.5-flash)  
- **P3**: Swift Test Engineer (moonshotai/kimi-k2)
- **P4**: Code Refactoring Specialist (mistralai/codestral-2501)
- **P5**: iOS API Scout (perplexity)
- **P6**: iOS Architecture Strategist (openai-o3)
- **P7**: Core Data Architect (qwen/qwen3-235b-a22b-07-25)
- **P8**: Performance Detective (deepseek/deepseek-r1-0528)
- **P9**: Utility Code Generator (qwen/qwen-2.5-coder-32b-instruct)
- **P10**: Code Review Validator (meta-llama/llama-3.3-70b-instruct)
- **P11**: UX/UI Consultant (x-ai/grok-4)

## Phase 5 Development Focus

The team is specifically configured for Phase 5 goals:

### Smart Integrations & Provider Flexibility
- Universal LLM provider support with automatic discovery
- Dynamic adapter generation for any API
- Provider discovery service implementation

### iPad Compatibility & Apple Pencil Integration
- iPad UI adaptation and responsive design
- Apple Pencil gesture recognition and drawing
- Touch interaction optimization for tablets

### Prompt Optimization Engine (15+ patterns)
- Instruction patterns (plain, rolePersona, outputFormat)
- Example-based patterns (fewShot, oneShot)
- Reasoning boosters (chainOfThought, selfConsistency, treeOfThought)
- Knowledge injection (rag, react, pal)

## Quality Gates & Markers

Each phase MUST include these markers:
- `<!-- /prd complete -->` - Requirements finalized
- `<!-- /conts complete -->` - Plan approved
- `<!-- /tdd complete -->` - Tests defined
- `<!-- /dev scaffold ready -->` - Implementation scaffolded
- `<!-- /green complete -->` - All tests passing
- `<!-- /refactor ready -->` - Code cleaned up
- `<!-- /qa complete -->` - Quality gate passed

## TodoWrite & Project_Tasks.md Integration

The Meta-Orchestrator system automatically maintains task synchronization:

### Task Management Flow
1. **Task Start**: Mark as "in_progress" in TodoWrite
2. **Task Completion**: Immediately mark as "completed" in TodoWrite
3. **Project Sync**: Update Project_Tasks.md with completion details
4. **QA Gate Hook**: When /qa complete + GREEN, auto-update Project_Tasks.md

### Automation Features
- Real-time TodoWrite → Project_Tasks.md synchronization
- Completion statistics auto-update (total tasks, completion rate)
- Timestamp tracking for all completed tasks
- No batch completions - immediate status updates

## VanillaIce Commands Available

The system automatically integrates with VanillaIce:
```bash
/Users/J/.claude/commands/vanillaice-command.sh "your prompt" --operation consensus
```

## Session Management

### View Active Sessions
```bash
claude-swarm ps
```

### List Previous Sessions  
```bash
claude-swarm list-sessions
```

### Restore Previous Session
```bash
claude-swarm restore SESSION_ID
```

### Watch Session Activity
```bash
claude-swarm watch SESSION_ID
```

### Clean Up Old Sessions
```bash
claude-swarm clean
```

## Installation Verification

✅ **Ruby Version**: 3.4.5 (required >= 3.2.0)  
✅ **Claude Swarm**: 0.3.5 installed globally  
✅ **Configuration**: AIKO Phase 5 Meta-Orchestrator TDD  
✅ **VanillaIce Integration**: P1-P11 priority system active  
✅ **TDD Workflow**: Mandatory 7-phase process enforced  
✅ **Testing**: Configuration validated successfully  

## Troubleshooting

### Path Issues
If `claude-swarm` command not found:
```bash
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"
```

### Ruby Version Issues
Verify Ruby version:
```bash
ruby --version  # Should be 3.4.5+
```

### Configuration Validation
Test YAML syntax:
```bash
ruby -e "require 'yaml'; puts 'Valid' if YAML.load_file('claude-swarm.yml')"
```

## Next Steps

1. **Launch the Meta-Orchestrator**: `claude-swarm start claude-swarm.yml`
2. **Begin Phase 5 Development**: Start with `/prd` command
3. **Follow TDD Workflow**: Complete all 7 phases systematically
4. **Utilize VanillaIce**: Let the system coordinate P1-P11 models automatically

The system is now ready for AIKO Phase 5 development with comprehensive TDD workflow enforcement and VanillaIce integration.