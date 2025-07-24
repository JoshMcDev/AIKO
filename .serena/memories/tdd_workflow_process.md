# AIKO TDD Workflow Process

## Overview
The project follows a strict Test-Driven Development (TDD) workflow with specific phases that must be executed in order for each new feature or task.

## Workflow Phases

### 1. /prd (Product Requirements Document)
- Analyze the codebase and draft the PRD for the task
- Use /vanillaIce to gain consensus and synthesize information
- Revise the PRD based on consensus
- Output: `[project_task]_prd.md` in project root

### 2. /design (Implementation Plan)
- Input: Enhanced PRD from previous phase
- Analyze codebase for integration points
- Draft implementation plan for integrating PRD into architecture
- Use /vanillaIce for consensus and refinement
- Output: `[project_task]_implementation.md` in project root

### 3. /tdd (Test Rubric)
- Input: PRD and implementation plan
- Create comprehensive test rubric
- Define test cases and acceptance criteria
- Output: `[project_task]_rubric.md` in project root

### 4. /dev (Development)
- Input: PRD, implementation plan, and rubric
- Implement the feature following TDD principles
- Write tests first, then implementation
- Ensure all rubric criteria are addressed

### 5. /green (All Tests Pass)
- Continue until all tests pass
- Fix and resolve any test dependency issues
- Do NOT bypass failing tests
- Output: `[project_task]_green.md` documenting test results

### 6. /refactor (Code Quality)
- Fix all SwiftLint violations and warnings
- Zero tolerance for violations/warnings
- Apply SwiftFormat for consistency
- Improve code structure and documentation
- Output: `[project_task]_refactor.md` documenting improvements

### 7. /qa (Quality Assurance)
- Final comprehensive validation
- Fix all build errors and warnings
- Ensure all tests pass
- Verify integration with existing features
- Fix and resolve any dependency issues
- Status must be green
- Output: `[project_task]_qa.md` for review and approval

## Important Notes
- Each phase must be completed before moving to the next
- All outputs are markdown files in the project root
- VanillaIce consensus is used in /prd and /design phases
- Zero tolerance for SwiftLint violations in /refactor
- All tests must pass - no bypassing allowed