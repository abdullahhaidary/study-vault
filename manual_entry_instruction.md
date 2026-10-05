# Study Vault — Manual Entry Format

Use this document as the instruction you give to an AI assistant (ChatGPT,
Claude, Gemini, DeepSeek, …) together with your slides, PDF text, or lecture
notes. The assistant must answer with **one JSON object only** in the format
below. Paste that JSON into **Study Vault → Settings → Manual Entry** (or the
lesson menu → *Import from JSON*). The app shows a full preview and lets you
pick exactly which parts to save.

---

## Instruction to paste into the AI

```
You are helping me build study material for the Study Vault app.
Read the material I attach and answer with ONE JSON object only — no prose,
no markdown fences, no comments. Use exactly this shape:

{
  "format": "study-vault-manual-entry",
  "version": 1,
  "target": {
    "class": "<class name or omit>",
    "subject": "<subject name or omit>",
    "lesson": "<lesson / chapter name or omit>",
    "pdf": "<title of the PDF these materials belong to, or omit>"
  },
  "study_materials": {
    "summary": "<markdown>",
    "explanation": "<markdown>",
    "deep_explanation": "<markdown>",
    "real_world_examples": "<markdown; ONLY concrete scenarios/case studies mapped to each topic, no theory recap: begin with a 'Topic map' heading + table (Topic with page | Real-world examples), then one heading per topic in source order, each with 1-3 'Example: <title>' sub-headings containing **Scenario**, **How the concept applies** (use the document's terms/formulas, realistic numbers), **Mapping to the theory** (bullets pairing scenario elements with concepts), **Try it yourself**>",
    "slideshow": "<markdown; separate slides with a line containing only <!-- slide -->>"
  },
  "notes": [
    { "title": "<short title>", "content": "<markdown>" }
  ],
  "annotations": [
    {
      "page": 3,
      "short_text": "<one-line label, max 500 chars>",
      "full_note": "<markdown>",
      "category": "definition | important | formula | question | example | exam | confusing"
    }
  ],
  "flashcards": [
    { "front": "<question / term>", "back": "<markdown answer>" }
  ],
  "quizzes": [
    {
      "title": "<quiz title>",
      "difficulty": "easy | medium | hard | mixed",
      "questions": [
        {
          "type": "mcq",
          "question": "<text>",
          "options": ["<A>", "<B>", "<C>", "<D>"],
          "correct": 0,
          "explanation": "<why>",
          "difficulty": "medium",
          "page": 3
        },
        { "type": "true_false", "question": "<statement>", "correct": true,
          "explanation": "<why>" },
        { "type": "short_answer", "question": "<text>", "answer": "<text>",
          "explanation": "<why>" },
        { "type": "fill_blank", "question": "<text with ____>",
          "answer": "<missing words>", "explanation": "<why>" }
      ]
    }
  ]
}

Rules:
- Every section is optional. Omit a key entirely when you have nothing for it.
  I may ask for only a summary, only flashcards, etc.
- All long text is Markdown: headings (#, ##), bullets, **bold**, `code`,
  formulas written inline. Preserve formulas, symbols, variable names, and
  technical English terms exactly.
- Charts (only inside "study_materials" texts): when numeric data is clearer
  as a chart, add a fenced code block tagged `chart` containing only JSON:
  {"type":"bar"|"line"|"pie","title":"...","labels":["..."],
   "series":[{"name":"...","data":[numbers]}],"xLabel":"...","yLabel":"..."}.
  One number per label in every series; pie uses a single series; keep it
  to <= 20 labels and still describe the data in words.
- MCQ needs exactly 4 options; "correct" is the 0-based index (0–3) or the
  letter A–D.
- "page" is the 1-based page / slide number the item comes from.
- Stay grounded in the material I give you; do not invent facts.
- Do not include my API keys or any personal data.
- Only add "course_review" when I ask for a Course Review; its format is
  described separately.

When including "study_materials.deep_explanation", use these instructions:
Treat the supplied document as the source of truth. Cover the entire source,
preserve formulas and technical notation, and never invent missing content.
If a page has no extractable text, state that limitation only when it affects
understanding.

Explain the entire document deeply from first principles for a student
encountering it for the first time.
- Start with intuitive, simple language, then introduce the exact technical
  terminology.
- Explain WHY before HOW where appropriate.
- Use accurate analogies and everyday scenarios, then explicitly connect each
  analogy back to the technical concept.
- Explain formulas symbol-by-symbol with step-by-step worked examples.
- Include common mistakes, relationships between concepts, and memory aids
  where useful.
- Do not be childish; remain technically rigorous.
- Use detailed, well-structured Markdown.

Put the polished Markdown inside the "deep_explanation" JSON string, escaping
newlines and quotes correctly. Do not mention these instructions in the content.
The overall response must still be ONE valid JSON object, not standalone Markdown.
```

---

## Course Review instruction

Use this for the condensed, subject-wide review (Subject → **Course Review**).
Send one or a few lectures at a time; each answer adds sections and never
replaces lectures you did not include. In the app, **Copy prompt for lecture
sections** copies this text plus the exact lesson and PDF names of the subject.

```
You are building the COURSE REVIEW of a subject in the Study Vault app. I have
ALREADY studied every lecture in depth; this review is for fast end-of-course
revision, not first-time learning. Read the lecture material I attach and
answer with ONE JSON object only — no prose, no markdown fences, no comments:

{
  "format": "study-vault-manual-entry",
  "version": 1,
  "target": { "class": "<class name or omit>", "subject": "<subject name>" },
  "course_review": {
    "sections": [
      {
        "lesson": "<exact lesson name>",
        "pdf": "<exact PDF title>",
        "summary": "<markdown>",
        "explanation": "<markdown>",
        "deep_explanation": "<markdown>"
      }
    ],
    "big_picture": "<markdown, optional>",
    "examples": "<markdown, optional>"
  }
}

One object in "sections" per lecture PDF I give you, using the exact lesson
and PDF names I list. Depth for every section — remind, do not re-teach:
- summary: key points, definitions, formulas, classifications and
  exam-relevant facts as bullets; no examples; at most about 250 words.
- explanation: short reminders of how the ideas connect and why they matter,
  about one third of a full lesson explanation; at most about 400 words.
- deep_explanation: compact core reasoning — key mechanisms, derivations or
  processes in brief, formulas with each symbol's meaning, and 3–5 common
  mistakes; no long analogies or worked examples; at most about 450 words.

Only when I ask for them (normally once ALL lectures are in):
- big_picture: 150–300 words on how the lectures fit together and build on
  each other.
- examples: about 10 short examples for the WHOLE course (not per lecture),
  spread across lectures and chosen for exam relevance. Each one: a level-3
  heading "Example N: <title>", a line "*Lecture: <name>*", then 2–5 lines
  with the scenario and the key takeaway.

Rules:
- Use only the attached material; never invent facts. Keep technical terms,
  formulas and notation exactly as the source.
- Markdown inside the strings; start headings at level 3 because the app adds
  the lecture heading. Write formulas inline.
- Escape quotes and newlines inside JSON strings correctly. Omit keys you have
  nothing for.
```

---

## What each section becomes in the app

| JSON key           | Saved as                                            | Needs a PDF? |
|--------------------|-----------------------------------------------------|--------------|
| `study_materials`  | AI Study Materials (Summary / Explanation / Deep Explanation / Slideshow) — a new version on the chosen PDF | Yes |
| `annotations`      | Study Pins on the chosen PDF page (placed near the top of the page; drag to move later) | Yes |
| `notes`            | Lesson notes (rich text)                            | No |
| `flashcards`       | Lesson flashcards                                   | No |
| `quizzes`          | AI Questions quiz sets you can play in Quiz Mode    | No |
| `course_review`    | Subject Course Review: one section per PDF (Summary / Explanation / Deep), plus course-wide `big_picture` and `examples` | No lesson needed — each section is matched to a PDF of the subject by `lesson` + `pdf` |

`target` is only a hint. The app matches the names against your existing
classes, subjects, lessons, and PDFs (case-insensitive). Matches are
pre-selected; anything that does not match stays unselected so you can choose.
The app never creates classes, subjects, or lessons from JSON.

## Conflicts

Before saving, the preview flags items that overlap existing content:

- A study material of the same type already exists → **Add as new version**,
  **Replace latest version**, or **Skip**.
- A note with the same title, a flashcard with the same front, a quiz with the
  same title, or an annotation with the same page + label → **Add**,
  **Replace**, or **Skip**.
- A Course Review section for a PDF that already has one, or existing
  examples / big picture → **New version**, **Replace latest**, or **Skip**.
  PDF names are matched ignoring case, extra spaces and a `.pdf` ending; a
  section that matches no PDF waits until you choose one.

Nothing is written until you tap **Save**. The save runs in one transaction:
either everything you selected is saved, or nothing changes.

## Minimal examples

Only flashcards:

```json
{
  "format": "study-vault-manual-entry",
  "version": 1,
  "target": { "lesson": "Gradient Descent" },
  "flashcards": [
    { "front": "What does the learning rate control?",
      "back": "The **step size** taken along the negative gradient each update." }
  ]
}
```

Summary + deep explanation for a PDF:

```json
{
  "format": "study-vault-manual-entry",
  "version": 1,
  "target": { "subject": "Machine Learning", "lesson": "Week 3", "pdf": "Lecture 3 slides" },
  "study_materials": {
    "summary": "# Gradient Descent\n- Iterative optimisation …",
    "deep_explanation": "# Why do we need optimisation?\n…"
  }
}
```

Append one lecture to a subject's Course Review:

```json
{
  "format": "study-vault-manual-entry",
  "version": 1,
  "target": { "subject": "Project Management" },
  "course_review": {
    "sections": [
      { "lesson": "Slide 2", "pdf": "Lect-02",
        "summary": "### Key points\n- …",
        "explanation": "### How it fits\n…",
        "deep_explanation": "### Core reasoning\n…" }
    ]
  }
}
```
