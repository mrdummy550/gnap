---
id: spending-limits
name: Spending Limits
enforced_by: all
---

# Spending Limits

## Rules

1. No single task may cost more than $50 in API calls
2. If a run exceeds $10, agent MUST pause and report
3. Total daily spend across all agents MUST NOT exceed $200
4. If budget is >80% consumed, only priority-1 tasks may run

## Exceptions
- Human-approved tasks may exceed limits
- Tasks tagged `emergency` skip budget check
