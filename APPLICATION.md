# GNAP Application Layer (GNAL)

## Companion Spec — Business Logic Conventions for GNAP

```
Status:           Draft v1
Intended Status:  Informational (Companion to GNAP RFC)
Date:             March 2026
Author:           Farol Labs
```

---

## Table of Contents

- [Why This Document Exists](#why-this-document-exists)
- [Position in the Stack](#position-in-the-stack)
- [1. Workflows](#1-workflows)
  - [1.1 What is a Workflow](#11-what-is-a-workflow)
  - [1.2 File Format](#12-file-format)
  - [1.3 Frontmatter Schema](#13-frontmatter-schema)
  - [1.4 Trigger Types](#14-trigger-types)
  - [1.5 Task Generation](#15-task-generation)
  - [1.6 Versioning](#16-versioning)
- [2. Playbooks](#2-playbooks)
  - [2.1 What is a Playbook](#21-what-is-a-playbook)
  - [2.2 File Format](#22-file-format)
  - [2.3 Conditional Logic](#23-conditional-logic)
- [3. Policies](#3-policies)
  - [3.1 What is a Policy](#31-what-is-a-policy)
  - [3.2 File Format](#32-file-format)
  - [3.3 Enforcement](#33-enforcement)
- [4. Templates](#4-templates)
  - [4.1 Agent Templates](#41-agent-templates)
  - [4.2 Company Templates](#42-company-templates)
- [5. Events](#5-events)
  - [5.1 Event Bus](#51-event-bus)
  - [5.2 Event Types](#52-event-types)
  - [5.3 Event-Driven Workflows](#53-event-driven-workflows)
- [6. Knowledge Base](#6-knowledge-base)
  - [6.1 What is a Knowledge Base](#61-what-is-a-knowledge-base)
  - [6.2 Structure](#62-structure)
- [7. Directory Layout](#7-directory-layout)
- [8. Relationship to GNAP Core](#8-relationship-to-gnap-core)

---

## Why This Document Exists

GNAP core defines **protocol primitives**: Company, Agent, Task, Run, Message,
Budget. These are the atoms — they don't know about your business.

This companion spec defines **application-level conventions** that sit on top
of GNAP primitives. Workflows, playbooks, policies, templates, events, and
knowledge — the things that make agents actually useful for a specific company.

You can use GNAP without any of this. But if you want agents that understand
your business processes, this is how.

---

## Position in the Stack

```
┌─────────────────────────────────────────────────┐
│  GNAL — Application Layer (this document)        │
│                                                  │
│  Workflows      "When a lead comes in, do X"     │
│  Playbooks      "If customer angry, do Y"        │
│  Policies       "Never spend > $50 per task"     │
│  Templates      "New sales agent looks like..."  │
│  Events         "Lead created → trigger workflow"│
│  Knowledge      "Our pricing is $49/$200/mo"     │
│                                                  │
├─────────────────────────────────────────────────┤
│  GNAP — Protocol Layer (core RFC)                │
│                                                  │
│  Company  Agent  Task  Run  Message  Budget      │
│  State machines  Commit convention  Heartbeat    │
│  SHA locking  URI scheme  Budget control         │
│                                                  │
├─────────────────────────────────────────────────┤
│  Transport: git (push / pull / commit)           │
└─────────────────────────────────────────────────┘
```

**GNAP core** = what every agent MUST understand to participate.
**GNAL** = what makes agents effective for YOUR business. Optional but recommended.

---

## 1. Workflows

### 1.1 What is a Workflow

A Workflow is a **reusable business process template** written in Markdown.
It describes the steps, criteria, inputs, and outputs that an agent follows
when executing a class of work.

A Workflow is to a Task what a class is to an object: the template from which
concrete instances are created.

```
Workflow (template, lives forever)     →  "How to qualify a lead"
Task (instance, created and done)      →  "Qualify lead: Acme Corp"
Run (execution trace)                  →  "Ran at 10:00, score=7, hot"
```

### 1.2 File Format

**Directory:** `app/workflows/`

**File:** `app/workflows/{workflow-id}.md`

```markdown
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
Determine whether a lead is a fit and decide next action.

## Steps

### 1. Research
- Check company website
- Determine size (1-10, 10-50, 50+)
- Identify industry and decision maker

### 2. Score

| Criterion | 0 | 1 | 2 |
|-----------|---|---|---|
| Size | 50+ | 10-50 | 1-10 |
| Messenger usage | None | Partial | Primary |
| Budget | None | Limited | Available |
| Pain level | None | Moderate | Acute |

### 3. Decide
- Score ≥ 6 → Hot → Create task, schedule call
- Score 4-5 → Warm → Send materials, follow up in 1 week
- Score < 4 → Cold → Log and move on

## Exit Criteria
- [ ] Score assigned
- [ ] Next action determined
- [ ] If hot: task created in .gnap/tasks/
```

### 1.3 Frontmatter Schema

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | MUST | Unique workflow identifier |
| `name` | string | MUST | Human-readable name |
| `owner` | string | MUST | Default agent ID who executes |
| `trigger` | enum | MUST | `manual` / `schedule` / `event` |
| `schedule` | string | when trigger=schedule | Cron expression |
| `event` | string | when trigger=event | Event type that triggers this workflow |
| `goal` | string | MUST | Goal ID from `.gnap/company.json` |
| `tags` | array | SHOULD | Category tags |
| `inputs` | array | SHOULD | Required input params with types |
| `outputs` | array | SHOULD | Expected output params with types |
| `creates_task` | boolean | MAY | Auto-create task in `.gnap/tasks/` |
| `task_template` | object | when creates_task=true | ID pattern, tag, column |

### 1.4 Trigger Types

| Trigger | When | Implementation |
|---------|------|----------------|
| `manual` | Human or agent explicitly invokes | Read workflow on demand |
| `schedule` | Cron fires | Check on heartbeat if schedule matches |
| `event` | Something happens | React to event (see Section 5) |

### 1.5 Task Generation

When a workflow with `creates_task: true` is triggered:

```
Trigger (cron / event / manual)
         │
         ▼
Agent reads app/workflows/{id}.md
         │
         ▼
Validates inputs are available
         │
         ▼
Creates .gnap/tasks/{id}.json from task_template
         │
         ▼
Executes workflow steps
         │
         ▼
Records outputs + creates .gnap/runs/{id}.json
         │
         ▼
Updates task state (done / review / blocked)
```

Commit message: `{agent}: workflow {workflow-id} → task {task-id}`

### 1.6 Versioning

Workflows are Markdown in git. Version history is automatic.

- `git log app/workflows/lead-qualification.md` shows all changes
- Agents SHOULD read the current version on each execution (not cache)
- Breaking changes: commit with `{agent}: update workflow {id} — {what changed}`

---

## 2. Playbooks

### 2.1 What is a Playbook

A Playbook is a **decision tree for handling situations**. Unlike Workflows
(which are step-by-step processes), Playbooks are conditional:
"If X happens, do Y. If Z, do W."

Playbooks handle the messy reality of business — edge cases, escalations,
exceptions.

### 2.2 File Format

**Directory:** `app/playbooks/`

```markdown
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
```

### 2.3 Conditional Logic

Playbooks use natural language conditions, not code. Agents interpret them.

```markdown
## If lead is from competitor's customer
1. Prioritize — they're already educated on the problem
2. Focus on switching cost: "Migration takes 10 minutes"
3. DO NOT badmouth competitor

## If lead has no budget
1. Offer free trial (7 days, no credit card)
2. Schedule follow-up for day 5
3. If still no budget after trial → move to nurture list
```

---

## 3. Policies

### 3.1 What is a Policy

A Policy is a **constraint or rule** that agents MUST follow. Policies are
guardrails — they define boundaries, not processes.

### 3.2 File Format

**Directory:** `app/policies/`

```markdown
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
```

```markdown
---
id: communication-policy
name: External Communication Policy
enforced_by: all
---

# External Communication

## Rules

1. NEVER send emails without human approval
2. NEVER post on social media without human approval
3. NEVER share customer data with other customers
4. NEVER make commitments on pricing or timelines
5. Internal messages (GNAP messages/) — free to send
6. Task comments — free to write

## Escalation
If unsure whether something is "external" → treat it as external → ask.
```

### 3.3 Enforcement

Policies are advisory by default — agents read and follow them. For hard
enforcement, the policy MUST be implemented in the agent's runtime (OpenClaw
skill, budget.json limits, etc).

```
Advisory (soft)     → Agent reads policy, follows instructions
                       "SHOULD not spend > $50"

Enforced (hard)     → Runtime blocks the action
                       budget.json limit_usd = 50
```

Best practice: write the policy first, enforce with code later.

---

## 4. Templates

### 4.1 Agent Templates

Reusable agent configurations for quickly adding new agents to the org.

**Directory:** `app/templates/agents/`

```markdown
---
id: sales-agent
name: Sales Agent Template
role: Sales Representative
type: ai
runtime: openclaw
capabilities: [sales, outreach, research, writing]
heartbeat_sec: 3600
budget_monthly_usd: 100
---

# Sales Agent

## Personality
- Professional but friendly
- Persistent without being pushy
- Data-driven — always reference numbers

## Daily Routine
1. Check new leads (workflow: lead-qualification)
2. Follow up on warm leads (workflow: lead-followup)
3. Update pipeline (task: update CRM)
4. Report to manager (message: daily-report)

## Tools
- Web search for lead research
- Email (with approval) for outreach
- CRM for pipeline tracking

## Metrics
- Leads qualified per week: target 10
- Response time: < 1 hour
- Conversion rate: track and report
```

### 4.2 Company Templates

Portable company configurations for bootstrapping new GNAP deployments.

**Directory:** `app/templates/companies/`

```markdown
---
id: saas-startup
name: SaaS Startup Template
agents: [ceo, cto, cro, marketing]
workflows: [lead-qualification, content-publishing, sprint-review]
policies: [spending-limits, communication-policy]
---

# SaaS Startup

Pre-configured GNAP setup for a typical SaaS startup:

## Agents
- CEO (ai) — strategy, fundraising, vision
- CTO (human) — technical decisions, architecture
- CRO (ai) — revenue, sales pipeline, outreach
- Marketing (ai) — content, social, brand

## Goals (starter)
- MRR target
- User acquisition target
- Retention target

## Workflows (included)
- Lead qualification
- Content publishing
- Sprint review
- Customer onboarding
```

---

## 5. Events

### 5.1 Event Bus

GNAP doesn't have a real-time event bus — git is batch-oriented. Events are
implemented as **event files** that agents check on heartbeat.

**Directory:** `app/events/`

**File:** `app/events/{timestamp}-{type}-{source}.json`

```json
{
  "id": "evt-20260312-100000-new-lead",
  "type": "lead.created",
  "source": "carl",
  "at": "2026-03-12T10:00:00Z",
  "data": {
    "lead_name": "Acme Corp",
    "lead_source": "website",
    "lead_contact": "john@acme.com"
  },
  "consumed_by": []
}
```

### 5.2 Event Types

Events follow a `{domain}.{action}` naming convention:

| Event | Description |
|-------|-------------|
| `lead.created` | New lead detected |
| `lead.qualified` | Lead scored and categorized |
| `customer.onboarded` | Customer completed onboarding |
| `customer.churned` | Customer cancelled |
| `content.drafted` | Content ready for review |
| `content.published` | Content went live |
| `budget.warning` | Budget > 80% consumed |
| `budget.exhausted` | Budget fully consumed |
| `task.blocked` | Task hit a blocker |
| `task.overdue` | Task past due date |
| `incident.detected` | Something went wrong |

### 5.3 Event-Driven Workflows

Workflows with `trigger: event` listen for specific event types:

```markdown
---
id: lead-followup
trigger: event
event: lead.qualified
owner: carl
---
```

On heartbeat, the agent:

1. Reads `app/events/` for unconsumed events
2. Filters by event type matching its workflows
3. Triggers the workflow with event data as inputs
4. Marks event as consumed (`consumed_by: ["carl"]`)
5. Commits

```
Heartbeat
    │
    ▼
Read app/events/ → filter by type
    │
    ▼
Match against workflows with trigger=event
    │
    ▼
For each match: execute workflow with event.data as inputs
    │
    ▼
Mark event consumed → commit
```

### Event Cleanup

Events older than 30 days SHOULD be archived or deleted by any agent
during heartbeat maintenance.

---

## 6. Knowledge Base

### 6.1 What is a Knowledge Base

Structured information that agents need to do their jobs — pricing, product
features, competitive intel, FAQ, company facts. Unlike workflows (process)
and playbooks (decisions), knowledge is **reference material**.

### 6.2 Structure

**Directory:** `app/knowledge/`

```
app/knowledge/
├── product/
│   ├── pricing.md          # Current pricing tiers
│   ├── features.md         # Feature list and descriptions
│   └── roadmap.md          # Public roadmap
├── competitors/
│   ├── simpleclaw.md       # Competitor analysis
│   └── viktor.md
├── sales/
│   ├── objections.md       # Common objections + responses
│   ├── case-studies.md     # Success stories
│   └── ica.md              # Ideal customer avatar
└── company/
    ├── values.md           # Company values
    ├── team.md             # Team bios
    └── faq.md              # Frequently asked questions
```

Knowledge files are plain Markdown. No special frontmatter required.
Agents read them when relevant to their current task or workflow.

---

## 7. Directory Layout

Complete application layer directory:

```
app/
├── workflows/                    # Business processes
│   ├── lead-qualification.md
│   ├── client-onboarding.md
│   ├── content-publishing.md
│   └── sprint-review.md
│
├── playbooks/                    # Decision trees
│   ├── angry-customer.md
│   ├── competitor-objections.md
│   └── escalation.md
│
├── policies/                     # Rules and constraints
│   ├── spending-limits.md
│   ├── communication-policy.md
│   └── data-handling.md
│
├── templates/                    # Reusable configs
│   ├── agents/
│   │   ├── sales-agent.md
│   │   └── marketing-agent.md
│   └── companies/
│       └── saas-startup.md
│
├── events/                       # Event files
│   └── {timestamp}-{type}-{source}.json
│
└── knowledge/                    # Reference material
    ├── product/
    ├── competitors/
    ├── sales/
    └── company/
```

This sits alongside `.gnap/` in the same repo:

```
repo/
├── .gnap/                 # Protocol layer (GNAP core)
│   ├── company.json
│   ├── org.json
│   ├── budget.json
│   ├── workflow.md
│   ├── tasks/
│   ├── runs/
│   └── messages/
│
├── app/                   # Application layer (this spec)
│   ├── workflows/
│   ├── playbooks/
│   ├── policies/
│   ├── templates/
│   ├── events/
│   └── knowledge/
│
└── (working files)        # Code, docs, assets
```

---

## 8. Relationship to GNAP Core

| Concern | GNAP Core | GNAL (Application Layer) |
|---------|-----------|--------------------------|
| **Scope** | Protocol primitives | Business logic conventions |
| **Required?** | MUST for participation | MAY — optional but recommended |
| **Format** | JSON (machine-first) | Markdown (human-first) |
| **Who defines** | Protocol spec | Each company |
| **Examples** | Task state machine, commit convention | Lead qualification, angry customer playbook |
| **Changes** | Rare (protocol evolution) | Frequent (business evolves) |
| **Directory** | `.gnap/` | `app/` |

**Key principle:** GNAP core is minimal and universal. Application layer is
rich and company-specific. An agent needs only GNAP to participate. It needs
GNAL to be *effective*.

### How They Connect

```
GNAL Workflow (template)
    │
    │  triggers
    ▼
GNAP Task (instance in .gnap/tasks/)
    │
    │  executes
    ▼
GNAP Run (trace in .gnap/runs/)
    │
    │  communicates
    ▼
GNAP Message (in .gnap/messages/)
    │
    │  costs
    ▼
GNAP Budget (in .gnap/budget.json)
```

### Analogy

| Layer | Web Analogy | GNAP Analogy |
|-------|-------------|--------------|
| Application | REST API design, business logic | Workflows, playbooks, policies |
| Protocol | HTTP request/response, headers | Task, Run, Message, Budget |
| Transport | TCP/IP | Git (push/pull/commit) |

---

*GNAL v1 — Farol Labs, March 2026*
*Companion specification to the GNAP RFC.*
*Business logic conventions for agent teams.*
