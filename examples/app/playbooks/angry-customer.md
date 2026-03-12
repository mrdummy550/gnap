---
id: angry-customer
name: Angry Customer Response
owner: carl
tags: [Sales, Support]
---

# Angry Customer Response

## Detect
Signs the customer is unhappy:
- Negative language ("disappointed", "frustrated", "waste of time")
- Multiple messages without agent response
- Explicit complaint

## Respond

### Severity: Low (mild frustration)
1. Acknowledge the feeling: "I understand this is frustrating"
2. Restate their issue to show you heard them
3. Provide concrete next step with timeline

### Severity: Medium (angry, threatening to leave)
1. Apologize specifically (not generically)
2. Escalate: create task for human reviewer
3. Offer immediate remediation (discount, call, refund)

### Severity: High (public complaint, legal threat)
1. DO NOT respond without human approval
2. Create task with `column: review` and `priority: 1`
3. Send alert message to all humans in org
4. Tag: `escalation`

## Never
- Never argue
- Never blame the customer
- Never promise what you can't deliver
- Never ignore — always acknowledge within 1 hour
