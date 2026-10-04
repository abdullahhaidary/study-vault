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
- MCQ needs exactly 4 options; "correct" is the 0-based index (0–3) or the
  letter A–D.
- "page" is the 1-based page / slide number the item comes from.
- Stay grounded in the material I give you; do not invent facts.
- Do not include my API keys or any personal data.
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
