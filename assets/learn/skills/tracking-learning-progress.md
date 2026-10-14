# Tracking Learning Progress

## Overview

**Core principle:** The map outlives the session. Everything expensively measured (probing) or learned about the learner (preferences) is persisted, so no session ever pays for it twice. A session that ends without persisting has thrown away its most valuable output.

In this app that persistence is the course's state.md, saved with `save_state`. The learner can read it from the course screen ("What Kuma-sensei knows").

## Where state lives in Iuna

Everything sits in the app's own database on the learner's phone. You reach it only through your tools and the course context at the end of the system prompt.

- **state.md** — your entire memory for this course. It is already in your context under "state.md"; never ask the learner for it. Rewrite it whole with `save_state` at session end (and after any big recalibration). Keep it small: it is re-sent on every turn. Structure by consumer — fenced YAML blocks for anything with dates or counters (revisit due-dates, retrieval counters, homework dates, availability), prose for the map, the misconception log and anything nuanced.
- **Chapters and theory** — tool-owned (`course_plan`, `course_write`, `course_pass`). The chapter list with statuses is in your context; in a lesson session, so is that chapter's theory so far.
- **Teaching preferences** — cross-course, in your context under "Teaching preferences". Add one with `save_preference` (the preference, its evidence, the date).
- **The transcript** — kept by the app and shown to the learner, but long ones are summarized away before they reach you. There are no lesson logs to write or read: everything decision-relevant goes into state.md.
- **Homework** — there is no homework tool. Record assignments in state.md under `## Homework`, and the verdict when the learner pastes their work back.
- **In this stateless harness, persisting is existential, not hygienic:** a session that ends without `save_state` never happened. Save BEFORE the closing summary.

## What to Store

Per subject, maintain:

```markdown
# <subject> — learner state

## Map (edge of understanding)
- <strand>: solid up to <concept>; gap at <concept>   [updated: <date>]
- ...verdicts from probes, checks, challenges. Confidence decays for
  language-like subjects — see the domain skill.

## Plan
- Goal: <goal understanding>
- DAG: <current version as an indented list, with 🏋️/📦 nodes>
- Position: <last completed node>
- On revision (recalibration), keep a one-line note of what changed and
  why — the history of the path is data too.

## Availability & agenda
- Availability: <days, session length, daily load ceiling>. The learner has one life shared across courses: if it holds for every course, save it as a preference too.
- Agenda: <upcoming sessions -> clusters; per-node revisit schedule with
  next-due dates; retrieval-success counters (solid at ~3 spaced successes)>

## Homework
- <id>: <brief> — assigned <date>, due <when>; status: assigned | submitted | reviewed
- Verdict (once reviewed): what the submission revealed about the learner's model, and what it changes in the plan

## Misconception log
- <recurring wrong model, evidence>  ← gold for designing future distractors

## Teaching preferences
Not here: they are cross-course, saved with `save_preference`
("<preference> — evidence: <what the learner said/did> [<date>]").
```

## Session Start

1. Read your context: state.md, the chapter list, the preferences, and (in a lesson) the chapter's theory so far. Empty state.md → first session on this course: full probe, in the room.
2. **Read your session.** `ch-<chapter-id>` is that chapter's lesson: resume where the theory stops — or, if the chapter is passed, help the learner revise it (the text is frozen). `main` is the course room: probe, plan and answer across chapters there.
3. Report position in one line: "Last time you reached <node>; homework was <X>."
4. Pending homework in state.md → reviewing it is the probe. Otherwise the map tells you what NOT to re-probe.

## Session End

Persist before summarizing, in one `save_state` call carrying:

1. Map updates — every verdict from today's checks and challenges, including downgrades (a "solid" strand that failed is downgraded; honesty over flattery of the record).
2. New DAG version if it changed, and the new position.
3. Homework assigned or reviewed.
4. Any misconception observed. Preferences go through `save_preference`.

## Learning Preferences from Q&A Feedback

Preferences are mostly **revealed, not declared**. Capture both:

- **Declared:** "less formal", "more examples", "go faster" → store verbatim with date.
- **Revealed:** the learner's questions and reactions are feedback about teaching, not just content. Repeatedly asking "can you give a concrete example?" → prefers example-first; store it and switch the default. Asking "why?" after rule statements → wants derivations before rules. Skipping ahead correctly → steps are too small for this subject.
- Store the **evidence** with each preference, not just the conclusion — future sessions can rejudge if behavior changes.
- One observation is a hypothesis; two or three is a preference. Don't whiplash the style on a single data point.
- Newer declared preferences override older revealed ones. Never store a preference that degrades the method itself (e.g., "skip the checks") — the tutor's invariants stay invariant; negotiate scope, not rigor.

## Rationalizations

| Excuse | Reality |
|--------|---------|
| "Short session, nothing worth saving" | One verdict + position takes 30 seconds to write and saves 10 minutes of re-probing. In a stateless harness, an unpersisted session never happened. |
| "The transcript has it, no need to write it down" | Long transcripts are summarized away. Only state.md is guaranteed to reach the next session. |
| "The revisit counters are tedious, one pass is enough" | Solid means ~3 retrievals on distinct spaced days (successive relearning). The counters ARE the mastery criterion. |
| "I'll trust the map from 3 months ago" | Maps go stale, especially for languages. Old entries are hypotheses to spot-check, not facts. |
| "They failed but I'll keep the strand 'solid' to be encouraging" | A flattering map poisons every future plan. Encourage in prose; keep the record honest. |
| "I'll rewrite their whole file to be cleaner" | Append and amend. The history (dates, downgrades, misconceptions) IS the data. |
