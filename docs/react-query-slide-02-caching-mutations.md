# React Query — Lesson 02: Caching, Sync, Mutation & Server Update

**JOB Core · React Query**  
**Phases 3–4**  
**Source lesson in app:** Caching, Sync, Mutation & Server Update

> Topic map for PDF-style review.  
> **Core** = know these.  
> **Mention** = learn later / open the deep explanation when unclear.

---

## How to use this

1. Review this page like a checklist PDF.
2. If a topic is unclear, open the lesson in Study Vault and toggle the explanation.
3. Practice items at the bottom stay in the full `lesson.md`.

---

## 8–9. Caching · `staleTime` · `gcTime`

### Core

- How React Query caches by key
- Fresh / stale / active / inactive
- Garbage collection
- `staleTime` vs `gcTime` (different knobs)

### Mention

- Cache expiration details
- Sharing cache across components
- Canonical timing example

---

## 10–12. Refetch · retry · `enabled`

### Core

- Refetch: focus · mount · reconnect
- Background + manual refetch
- Retry defaults (when to disable)
- `enabled` · dependent queries

### Mention

- Polling / `refetchInterval`
- Exponential backoff
- `skipToken`
- Auth-gated fetching

---

## 13–14. `useMutation`

### Core

- Queries vs mutations (read vs write)
- `mutationFn` · `mutate` / `mutateAsync`
- States: pending · error · success
- Callbacks: `onSuccess` · `onError` · `onSettled`

### Mention

- `onMutate` intro
- Resetting mutation state
- API error shapes

---

## 15–17. Invalidation · cache writes · optimistic

### Core

- `invalidateQueries` (partial key match)
- `setQueryData` / `getQueryData` idea
- Invalidate vs direct cache update
- Optimistic: snapshot → update → rollback

### Mention

- `setQueriesData`
- Immutable cache updates
- Canceling outgoing queries
- Concurrent optimistic updates
- Full optimistic pattern code

---

## Practice (in full lesson)

- Project 2: Product Explorer
- Project 3: Todo Management Application
- Self-check questions (Phases 3 & 4)
- What’s next (Phase 5 preview)
