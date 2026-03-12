---
id: lead-qualification
name: Lead Qualification
owner: carl
trigger: manual
goal: g1
tags: [Sales]
inputs:
  - lead_name: string
  - lead_source: string
  - lead_contact: string
outputs:
  - qualified: boolean
  - score: number
  - next_action: string
creates_task: true
task_template:
  id_pattern: "{owner}-lead-{input.lead_name}"
  tag: Sales
  column: next
---

# Lead Qualification

## Purpose
Determine whether a lead is a fit for Sebastian/Ori and decide next action.

## Steps

### 1. Research
- Check company website
- Determine size (1-10, 10-50, 50+)
- Identify industry
- Find decision maker

### 2. Score

| Criterion | 0 | 1 | 2 |
|-----------|---|---|---|
| Size | 50+ | 10-50 | 1-10 |
| Messenger usage | None | Partial | Primary |
| Budget | None | Limited | Available |
| Pain level | None | Moderate | Acute |

### 3. Decide

- Score ≥ 6 → **Hot** → Create task, schedule call
- Score 4-5 → **Warm** → Send materials, follow up in 1 week
- Score < 4 → **Cold** → Log and move on

## Exit Criteria
- [ ] Score assigned
- [ ] Next action determined
- [ ] If hot: task created in .gnap/tasks/
