# React Query — Lesson 03: Advance Data Fetching And Production Level

**JOB Core · React Query**  
**Phases 5–6**  
**Source lesson in app:** Advance Data Fetching And Production Level

> Topic map for PDF-style review.  
> **Core** = know these.  
> **Mention** = learn later / open the deep explanation when unclear.

---

## How to use this

1. Review this page like a checklist PDF.
2. If a topic is unclear, open the lesson in Study Vault and toggle the explanation.
3. Practice items at the bottom stay in the full `lesson.md`.

---

## 18–21. Advanced fetching

### Core

- Pagination + page keys
- `useInfiniteQuery` (next page / `hasNextPage`)
- Parallel queries · `useQueries`
- Dependent queries with `enabled`

### Mention

- `placeholderData` / `keepPreviousData`
- Cursor pagination
- Avoiding waterfalls
- Combining results

---

## 22–23. Prefetch & cancellation

### Core

- `prefetchQuery` idea (hover / navigation)
- Perceived performance
- `AbortSignal` / cancel in-flight work

### Mention

- `ensureQueryData`
- `cancelQueries`
- Axios cancel patterns

---

## 24–26. Production craft

### Core

- TypeScript: typed queries & mutations
- Custom query/mutation hooks
- Error handling levels (query / global)

### Mention

- `queryOptions` / `mutationOptions`
- Key factories in features
- `throwOnError`
- `QueryErrorResetBoundary`
- Toasts

---

## 27–29. Auth · DevTools · SSR

### Core

- Auth-dependent queries
- Clear cache on logout (no leaks)
- DevTools: inspect stale/fresh/refetch

### Mention

- Login/logout mutations
- 401 handling
- Next.js prefetch
- `dehydrate` / `HydrationBoundary`

---

## Practice (in full lesson)

- Project 4: Blog Application

---

## Tip

Treat **Core** as your PDF checklist. Treat **Mention** as bookmarks — learn from the full lesson file or a future AI explanation when you hit them in real code.
