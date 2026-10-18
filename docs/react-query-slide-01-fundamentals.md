# React Query — Lesson 01: Fundamentals

**JOB Core · React Query**  
**Phases 1–2**  
**Source lesson in app:** Fundamentals

> Topic map for PDF-style review.  
> **Core** = know these.  
> **Mention** = learn later / open the deep explanation when unclear.

---

## How to use this

1. Review this page like a checklist PDF.
2. If a topic is unclear, open the lesson in Study Vault and toggle the explanation.
3. Practice items at the bottom stay in the full `lesson.md`.

---

## 1. Introduction

### Core

- What is React Query (TanStack Query)
- Why we need it / problems it solves
- Server state vs client state
- Manual `useEffect` fetching pain

### Mention

- React Query vs Redux
- vs RTK Query
- vs Axios
- When to use / avoid

---

## 2. Server state & architecture

### Core

- Server-state lifecycle
- Fetch · cache · synchronize
- Stale vs fresh · background refetch
- Cache invalidation · ownership

### Mention

- Full architecture flow
- Step-by-step concepts

---

## 4–5. Setup & `useQuery`

### Core

- `QueryClient` + `QueryClientProvider`
- `useQuery`: `queryKey` + `queryFn`
- `isPending` / `isLoading` / `isFetching`
- `refetch` · initial vs background load

### Mention

- Global defaults
- DevTools setup
- Full return object fields

---

## 6–7. Keys & `queryFn`

### Core

- Why keys identify the cache
- Params / nested keys / uniqueness
- `queryFn` returns a Promise
- Errors · params · cancellation idea

### Mention

- Key factories
- Fetch vs Axios
- `AbortSignal` detail
- Query function context

---

## Practice (in full lesson)

- Practice: `useEffect` vs React Query
- Project 1: User Directory
- Self-check questions (Phases 1 & 2)
- What’s next (Phase 3 preview)
