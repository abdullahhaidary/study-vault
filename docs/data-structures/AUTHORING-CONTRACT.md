# Authoring contract — Data Structures lectures

You are writing one lecture of a self-study course that replaces a university semester. The student is an adult software engineer studying alone. The lecture is the textbook chapter, the lab, and the exam. Write the chapter. Do not write an outline, a slide deck, or a blog post.

## File

Write exactly one Markdown file, at the path given in your assignment. Do not edit any other file. Do not open or write the Study Vault database.

## Standard of completeness

A student who has never seen the topic must be able to learn it from this file alone, then solve the examination without looking back at an outside source.

Include, in this order:

1. The title block specified below.
2. Learning objectives, numbered, each one observable.
3. The purpose of the lecture and what it deliberately does not teach.
4. The body, divided into parts. Every part teaches. Definitions come before examples. The reason for a design comes before the mechanism.
5. A practical laboratory: guided traces, then problems the student does, then a complete program.
6. Common mistakes, each with the wrong idea and the correction.
7. A formal examination: definitions, short answers, and quantitative problems. No answers in this part.
8. An answer key that solves every examination item in full.
9. An independent assignment that takes several hours and produces an artifact.
10. A glossary of every term introduced in this lecture.
11. A lecture summary and five principles.
12. References. Only real books and real papers. No invented page numbers. Chapter numbers are allowed when they are the well-known chapter numbers of the cited edition.

Target length is whatever the topic needs, usually well above a short tutorial. Do not pad with repeated restatements. Do not stop early.

## Title block

Use this shape, with the lecture number and title from your assignment:

```markdown
# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE NN — TITLE

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** NN of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** N hours
**Prerequisites:** list the earlier lectures by number and title
**Primary references:** the specific chapters you actually used

**This lecture owns:** one sentence.
**This lecture does not teach:** the topics reserved for other lectures.
```

## Notation locked for the whole course

Later lectures rely on these choices. Do not invent a conflicting convention.

- Arrays and strings are 0-indexed.
- $n$ is the input size. $\log$ is base 2. $\ln$ is natural. $\log_b$ names another base.
- Use $\Theta$ for tight bounds, $O$ for upper bounds, $\Omega$ for lower bounds. Do not write $O$ when you mean a tight bound.
- Empty tree height is $-1$. A leaf has height $0$. Depth of the root is $0$.
- AVL balance factor is $\mathrm{height}(\mathrm{left}) - \mathrm{height}(\mathrm{right})$, and a node is balanced when the factor is in $\{-1,0,1\}$.
- Binary heap arrays are 0-indexed: parent $\lfloor (i-1)/2 \rfloor$, left child $2i+1$, right child $2i+2$.
- Quicksort in this course uses Lomuto partition. Mention Hoare as an alternative; do not switch the worked example to Hoare.
- Graph algorithms use adjacency lists unless a section is explicitly about matrices.
- Dijkstra in this course assumes nonnegative weights. The implementation uses an indexed binary heap with a position map, not a Fibonacci heap.
- Union-find uses union by rank and path compression.
- JavaScript is the only implementation language. No libraries, no TypeScript, no DOM, no `any`.
- Use `null` for an absent link. Prefer `class`. Numeric code uses ordinary numbers and states the safe-integer limit when it matters.
- Pseudocode may appear first. Every algorithm that the lecture owns also appears as runnable JavaScript.

## Mathematics

The Study Vault reader renders TeX.

- Inline: `$...$`
- Display: a line `$$`, the formula, a line `$$`
- Do not put a bare dollar sign in prose. Say "constant" or "cost".
- Inside fenced code, `$` is ordinary text and must not be used as math.

Prove a claim, or label it **Theorem (stated)** / **Proof sketch** and say what is missing. Do not call a paragraph a proof if the argument skips the step that makes it true.

## Laboratory program

Include a heading exactly:

```markdown
## LABORATORY PROGRAM
```

Under it, exactly one fenced block tagged `javascript`. The block is a complete Node.js program:

- no imports except the built-in `node:assert/strict` if you need it
- defines the structures and algorithms taught in the lecture
- runs concrete assertions on those algorithms
- prints exactly `ALL TESTS PASSED` on success
- throws on failure
- does not read the network, the filesystem, or `process.argv`

The program must be correct. Trace at least one example by hand in the prose before the program, with the same numbers the program checks.

## Diagrams

Use fenced `text` blocks for pointer diagrams, trees, and arrays. Keep them accurate.

## Tone

Write complete sentences. Name the concept, then explain it. Use a short analogy only when you immediately map it back to the technical object. No jokes, no motivational filler, no emoji, no "in this article".

## Examination and key

The examination must be solvable from the lecture. The answer key repeats the question number and gives the full solution, including arithmetic. Quantitative answers must match the definitions used in the body.

## Honesty

If a result is due to an engine-specific optimization, say so and do not build a proof on it. JavaScript arrays are dynamic arrays at the language level; engine representations vary. Teach the data structure you implement, and describe the language array as an abstraction that already provides dynamic-array behavior.
