# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 13 — SHORTEST PATHS, SPANNING TREES, AND DISJOINT SETS

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 13 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 10 hours
**Prerequisites:** Lecture 06 — Sorting and Order Statistics; Lecture 10 — Heaps and Priority Queues; Lecture 12 — Graphs: Representation, BFS, and DFS
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapters 19, 21, and 22; Sedgewick and Wayne, *Algorithms*, 4th edition, Sections 1.5, 4.3, and 4.4

**This lecture owns:** relaxation, Dijkstra's algorithm, the Bellman–Ford algorithm, shortest paths in a directed acyclic graph, the cut and cycle properties, Prim's algorithm, Kruskal's algorithm, and disjoint-set forests.
**This lecture does not teach:** all-pairs shortest paths, maximum flow, or Fibonacci heaps. Tries belong to Lecture 14. Breadth-first search, topological search, and the binary heap are used here and are not rebuilt.

---

## Learning objectives

After this lecture you should be able to:

1. Compute the weight of a directed path and decide, for a source $s$ and a vertex $v$, whether a finite shortest $s$–$v$ path exists.
2. Relax an edge and prove that the distance label remains the weight of some walk from the source, or stays infinite.
3. Execute Dijkstra's algorithm on a nonnegative instance with an indexed binary heap, reconstruct the path from predecessor pointers, and state the worst-case bound $O((n + m) \log n)$.
4. Give a directed graph with one negative edge on which the distance Dijkstra settles is not the true distance.
5. Execute the Bellman–Ford algorithm for $|V|-1$ passes, use one further pass to detect a negative cycle reachable from the source, and state the bound $\Theta(nm)$.
6. Compute single-source distances in a directed acyclic graph by one relaxation pass in topological order, in $\Theta(n + m)$ time, including when an edge weight is negative.
7. State the cut property and the cycle property and prove each by an exchange of edges.
8. Execute Kruskal's algorithm and Prim's algorithm on one weighted undirected graph, obtain the same minimum-spanning-tree edge set when the weights are distinct, and state both running times.
9. Maintain a disjoint-set forest with union by rank and with path compression; prove that, with union by rank and no compression, the height is at most $\lfloor \log_2 n \rfloor$; and state Tarjan's inverse-Ackermann bound as a theorem.
10. Choose among breadth-first search, Dijkstra, Bellman–Ford, and the DAG method from the weight restriction, and choose between Prim and Kruskal from the way the graph is presented.

---

## Purpose

Lecture 12 computed reachability, layers, and finishing times on an unweighted graph. The cost of a route in a road network, a pipeline, or a dependency schedule is not the number of edges. It is the sum of the weights on the edges. This lecture solves two optimization problems that start from that sum.

The first problem is the single-source shortest-path problem: from one source, find a minimum-weight walk to every vertex that has one. The algorithm changes with the weights. Nonnegative weights allow Dijkstra's algorithm to settle a vertex the moment it leaves the priority queue. A directed acyclic graph allows one pass in topological order, even if some weights are negative. A general digraph needs the Bellman–Ford algorithm, which also reports a negative cycle reachable from the source. A negative cycle makes the minimum undefined, because walking around the cycle decreases the weight without bound.

The second problem is the minimum spanning tree of a connected undirected graph: a set of edges that touches every vertex, contains no cycle, and has minimum total weight. Prim's algorithm and Kruskal's algorithm are different ways of applying one fact, the cut property. Kruskal's cycle test is a disjoint-set forest. The forest is a structure in its own right. With union by rank and no path compression, find runs in $O(\log n)$ time, and that bound is proved in this lecture. With union by rank and path compression together, the amortized cost is the inverse Ackermann function $\alpha(n)$. That theorem is stated and cited. It is not derived.

A Fibonacci heap is the priority queue that makes Dijkstra's algorithm run in $\Theta(m + n \log n)$ time in the amortized analysis of Fredman and Tarjan. This course does not develop Fibonacci heaps. Every priority queue in this lecture is the indexed binary heap prepared in Lecture 10: a 0-indexed binary heap plus a position map, so decrease-key is $O(\log n)$.

All-pairs methods, including the Floyd–Warshall algorithm and Johnson's algorithm, compute a distance for every pair of vertices. Maximum flow assigns capacities and pushes flow. Those are the next course. They are named here only so that a shortest-path or spanning-tree question is not answered with them.

The parts follow the dependency of the ideas.

1. Weighted digraphs and the meaning of a shortest path.
2. Relaxation and the upper-bound invariant.
3. Dijkstra's algorithm.
4. The Bellman–Ford algorithm.
5. Shortest paths in a DAG.
6. Cuts, cycles, and the exchange proofs for a minimum spanning tree.
7. Kruskal's algorithm.
8. Prim's algorithm.
9. Disjoint-set forests.
10. A comparison that chooses an algorithm from the restriction on the weights.

Study the traces with the next row covered. The laboratory program checks the same numbers.

---

## Part 1 — Weighted directed graphs

### 1.1 The input

A **weighted directed graph** is a triple $(V, E, w)$. The vertex set $V$ is finite. The edge set $E$ consists of ordered pairs: an edge is written $u \to v$ with $u, v \in V$. The weight function $w$ assigns each edge a real number $w(u, v)$. This lecture allows a weight to be negative unless an algorithm's statement forbids it.

Throughout the lecture, $n = |V|$ and $m = |E|$. A simple digraph has at most one edge in each ordered direction, so $m \le n(n - 1)$. A simple undirected graph has $m \le n(n - 1)/2$.

The representation is the adjacency list of Lecture 12. The list for $u$ stores records $\{v, w(u, v)\}$ for each outgoing edge. The whole graph occupies $\Theta(n + m)$ space. Matrices are not used in this lecture.

An undirected weighted edge $\{u, v\}$ of weight $w$ is stored, when an algorithm needs it, as the two arcs $u \to v$ and $v \to u$, both of weight $w$. That translation is valid for a minimum spanning tree, which uses each undirected edge at most once. It is valid for shortest paths when $w \ge 0$. If $w < 0$, the two arcs form a cycle of weight $2w < 0$, and the shortest-path problem on that directed copy is a different problem from the undirected one. Undirected shortest paths with negative weights are outside this lecture.

### 1.2 Path weight

A **walk** is a finite sequence of vertices in which each consecutive pair is an edge. A **path** is a walk that repeats no vertex. A **cycle** is a walk of at least one edge whose first and last vertices are the same and whose other vertices are distinct.

The **weight of a walk** is the sum of its edge weights. The empty walk at a vertex $s$ has weight $0$ and no edges. If the walk is $v_0, v_1, \ldots, v_k$, then

$$
w(v_0, v_1, \ldots, v_k) = \sum_{i=1}^{k} w(v_{i-1}, v_i).
$$

**Example.** The walk $s, a, c, b, t$ on the edges $s \to a$ of weight $2$, $a \to c$ of weight $1$, $c \to b$ of weight $1$, and $b \to t$ of weight $1$ has weight $2 + 1 + 1 + 1 = 5$.

### 1.3 Shortest-path weight

Fix a source $s \in V$. For each vertex $v$, the **shortest-path weight** $\delta(s, v)$ is defined as follows.

- If no walk from $s$ to $v$ exists, $\delta(s, v) = \infty$.
- If walks from $s$ to $v$ exist and their weights have a finite minimum, $\delta(s, v)$ is that minimum.
- If the weights of the walks from $s$ to $v$ are unbounded below, $\delta(s, v)$ is undefined as a minimum. The extended value $-\infty$ records that fact. There is then no shortest walk to $v$.

A **shortest path** from $s$ to $v$ is a path whose weight equals $\delta(s, v)$, in the case where that minimum is finite.

The symbol $\infty$ is an upper sentinel, not a walk. Arithmetic on the sentinels is fixed for the whole lecture: $\infty + c = \infty$ for every finite $c$, and the comparison $\infty < \infty$ is false. A finite number is strictly less than $\infty$.

### 1.4 When the minimum fails to exist

**Lemma 1 (negative cycle).** Suppose a cycle $C$ is reachable from $s$, and some vertex $v$ is reachable from $C$. If $w(C) < 0$, then the walk weights from $s$ to $v$ have no finite lower bound.

**Proof.** Take any walk $W$ from $s$ to a vertex $x$ on $C$, then follow $C$ to a vertex from which $v$ is reachable, then take a walk to $v$. Call this walk $W_0$, of some finite weight. For every integer $t \ge 0$, the walk that follows $W_0$'s route but travels around $C$ an extra $t$ times is a walk from $s$ to $v$ of weight $w(W_0) + t \cdot w(C)$. Since $w(C) < 0$, this quantity tends to $-\infty$ as $t$ grows. No finite number is a lower bound. $\square$

The hypothesis is reachability from the source, then from the cycle onward to $v$. A negative cycle in another component does not change $\delta(s, \cdot)$. A negative cycle reachable from $s$ does not spoil a vertex that the cycle cannot reach.

**Lemma 2 (a minimum is achieved by a path).** Suppose no negative cycle is reachable from $s$. If $v$ is reachable from $s$, then some path from $s$ to $v$ has weight $\delta(s, v)$, and that path has at most $n - 1$ edges.

**Proof.** Let $W$ be a walk from $s$ to $v$ of minimum weight; the hypothesis says a minimum exists and is finite. If $W$ repeats a vertex, it contains a cycle. That cycle is reachable from $s$, so its weight is at least $0$. Deleting it produces a shorter walk whose weight is at most $w(W)$. Repeat. The result is a path, still of weight $w(W)$, and a path on $n$ vertices has at most $n - 1$ edges. $\square$

So the phrase "shortest path" is justified exactly when Lemma 2 applies. When Lemma 1 applies, the right report is that a shortest path is undefined, not that the algorithm should return some very negative number and stop.

### 1.5 The unweighted case, named and not rebuilt

If every edge weight equals $1$, the weight of a path equals its number of edges. Breadth-first search, from Lecture 12, computes $\delta(s, v)$ for every $v$ in $\Theta(n + m)$ time. It is the special case of weight $1$. This lecture does not repeat the queue argument. It uses the result: when the input really is unweighted, BFS is the algorithm, and Dijkstra's algorithm is a slower correct alternative.

### 1.6 Numbers in the language

The mathematics is about real weights. The programs use JavaScript numbers. Integer weights whose partial sums lie in the safe-integer range, from $-(2^{53} - 1)$ to $2^{53} - 1$, compare exactly. Every graph in this lecture is far inside that range. The sentinel $\infty$ is `Infinity`. The identity `Infinity + c === Infinity` for a finite `c`, and the comparison `Infinity < Infinity` being false, match the sentinel rules above.

### 1.7 Optimal substructure

The algorithms in Parts 3 through 5 all rely on one structural fact.

**Lemma 3 (optimal substructure).** Suppose no negative cycle is reachable from $s$, and $p$ is a shortest path from $s$ to $v$. Let $u$ be the predecessor of $v$ on $p$, and let $p'$ be the prefix of $p$ that ends at $u$. Then $p'$ is a shortest path from $s$ to $u$, and

$$
\delta(s, v) = \delta(s, u) + w(u, v).
$$

**Proof.** The prefix $p'$ is a walk from $s$ to $u$, so $\delta(s, u) \le w(p')$. If a walk $q$ from $s$ to $u$ satisfied $w(q) < w(p')$, the walk $q$ followed by $u \to v$ would be a walk to $v$ of weight $w(q) + w(u, v) < w(p') + w(u, v) = w(p)$, contradicting the choice of $p$. Thus $w(p') = \delta(s, u)$. Lemma 2 lets us take $q$ to be a path if we wish; the inequality already contradicts using walks. The displayed equation is $w(p) = w(p') + w(u, v)$. $\square$

**Lemma 4 (triangle inequality).** Suppose no negative cycle is reachable from $s$. Then every edge $u \to v$ satisfies

$$
\delta(s, v) \le \delta(s, u) + w(u, v),
$$

in the extended arithmetic where the sum is $\infty$ if $\delta(s, u) = \infty$.

**Proof.** If $u$ is unreachable the right-hand side is $\infty$. If $u$ is reachable, a shortest path to $u$ followed by the edge is a walk to $v$ of that weight, and $\delta(s, v)$ is at most the weight of any walk. $\square$

---

## Part 2 — Relaxation

### 2.1 What a distance label is allowed to mean

The algorithms do not write $\delta$ into an array. They write an estimate. For each vertex $v$ the algorithm stores a number $d[v]$ and a predecessor $\pi[v]$.

**Upper-bound invariant.** For every vertex $v$, either $d[v] = \infty$, or $d[v]$ equals the weight of some walk from $s$ to $v$.

The name "upper bound" is the corollary: when $\delta(s, v)$ exists as a finite minimum or as $\infty$, the invariant forces $d[v] \ge \delta(s, v)$, because a walk weight cannot undercut the minimum walk weight, and $\infty$ is at least as large as any extended value we compare against it in the finite case. When a negative cycle makes the infimum $-\infty$, the invariant still says something precise and weaker: $d[v]$, if finite, is the weight of a real walk, not an arbitrary integer.

Initialization establishes the invariant.

- $d[s] = 0$, the empty walk at $s$.
- $d[v] = \infty$ for every $v \ne s$, meaning no walk has been recorded.
- $\pi[v] = \mathrm{null}$ for every vertex, including $s$.

### 2.2 The operation

**Relaxation** of an edge $u \to v$ is the following test and assignment.

```text
relax(u, v):
    if d[u] is finite and d[u] + w(u, v) < d[v]:
        d[v] = d[u] + w(u, v)
        π[v] = u
```

If the test fails, the arrays do not change. If $d[u] = \infty$, the test fails under the sentinel rules, so an edge out of an unreached vertex does nothing.

**Theorem 5.** Relaxation maintains the upper-bound invariant.

**Proof.** Consider one call on the edge $u \to v$, and assume the invariant holds before the call.

If the test fails, $d$ does not change, so the invariant holds after the call.

If the test succeeds, then $d[u]$ is finite. By the invariant, some walk $W$ from $s$ to $u$ has weight $d[u]$. The walk $W$ followed by the edge $u \to v$ is a walk from $s$ to $v$ of weight $d[u] + w(u, v)$. The assignment stores exactly that weight in $d[v]$. Every other vertex keeps its previous value, which still names a walk or remains $\infty$. The invariant holds after the call. $\square$

The predecessor is bookkeeping for the walk just chosen: the last edge of that walk is $u \to v$. Part 4 shows how to recover the whole walk when the labels have stopped changing. The invariant itself does not need $\pi$.

### 2.3 What relaxation does not do

Relaxation never raises a finite label. It never writes a finite label that is not a walk weight. It does not, by itself, know whether the walk it stored is a shortest path. Shortest-path algorithms are schedules for which edges to relax, plus a theorem that says when the schedule has driven $d[v]$ down to $\delta(s, v)$.

**Worked step.** Suppose $d[p] = 7$ because of a walk of weight $7$, and $d[q] = 12$. The edge $p \to q$ has weight $4$. Then $7 + 4 = 11$, and $11 < 12$, so relaxation sets $d[q] = 11$ and $\pi[q] = p$. The new walk to $q$ is the old walk to $p$ followed by $p \to q$. If the edge weight had been $6$, then $7 + 6 = 13$, which is not strictly less than $12$, and the label would stay $12$. The rejected candidate is a real walk; it is simply heavier than the walk already stored.

---

## Part 3 — Dijkstra's algorithm

### 3.1 The restriction

Dijkstra's algorithm requires $w(e) \ge 0$ for every edge $e$. The proof uses that hypothesis in one place, identified in Theorem 7. The counterexample in Section 3.6 is a three-vertex digraph on which the algorithm, run unchanged, settles a wrong distance. The failure is the algorithm's output, not an implementation accident.

### 3.2 The priority queue this course uses

Lecture 10 stores a binary min-heap in a 0-indexed array. The parent of index $i$ is $\lfloor (i - 1) / 2 \rfloor$. The children of $i$ are $2i + 1$ and $2i + 2$. This lecture needs one more operation: **decrease-key**, which lowers the key of a vertex that is already in the heap.

An **indexed binary heap** is that array together with a **position map**. The map sends each stored vertex $v$ to the index $\mathrm{pos}[v]$ at which $v$ sits in the array. The heap invariant is the usual one on the keys, plus the map invariant $\mathrm{pos}[\mathrm{heap}[i]] = i$ for every occupied index $i$.

The keys live in the distance array $d$. The heap stores vertices.

- `insert(v)` places $v$ at the next leaf and sifts it up, using $d[v]$ as its key. The map records the new index.
- `decrease-key(v)` is legal only when the caller has already lowered $d[v]$. The vertex is found in $O(1)$ time through the position map. Because the key fell, the heap property can fail only between $v$ and its parent, so the repair is a sift-up. A sift-up walks at most the height of the heap.
- `extract-min` removes the root, moves the last leaf to the root, and sifts down, updating the position map on every swap.

The heap holds each vertex at most once, so its size is at most $n$ and its height is at most $\lfloor \log_2 n \rfloor$. Lecture 10 showed that a sift of a binary heap is $O(\log n)$. Therefore insert, decrease-key, and extract-min are each $O(\log n)$ in the worst case.

If two keys are equal, this course breaks the tie by the string form of the vertex identifier, the smaller string winning. Every trace in this lecture extracts vertices whose current keys are distinct, so the tie-break does not choose the extraction order. It is part of the program so that the order is a function of the keys and the identifiers.

**A three-key check of the map.** Insert $x$ at key $4$, $y$ at key $1$, and $z$ at key $3$. Extract-min returns $y$. Decrease the key of $x$ from $4$ to $0$. Extract-min returns $x$, then $z$. After every operation the position map agrees with the array. The laboratory asserts this sequence before it runs a shortest-path trace.

### 3.3 The alternative of duplicate entries

A binary heap that cannot find an interior vertex has another implementation. On every successful relaxation into $v$, push a fresh pair $(d[v], v)$ and leave the old, larger pair in the heap. Extract-min ignores a pair whose recorded distance is larger than the current $d[v]$, or ignores a vertex already settled.

That heap can hold one entry per successful relaxation, hence $O(m)$ entries in the worst case. Each insertion costs $O(\log m)$. There are $O(m)$ insertions. The resulting bound is $O(m \log m)$. Since $m \le n(n - 1)$, one has $\log m \le 2 \log n$, so the same runs are also $O(m \log n)$, but the heap stores $\Theta(m)$ records in the worst case rather than at most $n$.

This lecture does not use duplicate entries. The implementation and the bound below are the indexed heap.

### 3.4 The algorithm

Dijkstra's algorithm grows a set $S$ of **settled** vertices. A vertex enters $S$ when it is extracted. The heap holds the discovered vertices that are not yet settled, ordered by the current $d$ value.

```text
Dijkstra(G, s):    // every weight is nonnegative
    for each vertex v:
        d[v] = ∞
        π[v] = null
    d[s] = 0
    insert s into the indexed heap
    S = empty
    while the heap is not empty:
        u = extract-min
        add u to S
        for each edge u → v:
            if v is not in S and d[u] + w(u, v) < d[v]:
                d[v] = d[u] + w(u, v)
                π[v] = u
                if v is in the heap: decrease-key(v)
                else: insert v
    return d and π
```

A vertex that is never discovered stays at $\infty$ and is never inserted. After $u$ is settled, an edge into $u$ is ignored. Under nonnegative weights that ignored edge cannot be an improvement; Theorem 7 says why. The counterexample shows that the same ignore-step keeps a wrong value when a weight is negative.

### 3.5 Correctness

Two invariants hold after every extraction, under the hypothesis that every weight is nonnegative.

**I1.** The upper-bound invariant of Theorem 5. Initialization gives it, and every update is a relaxation.

**I2.** For every vertex $x$ already in $S$, $d[x] = \delta(s, x)$.

**Theorem 7.** If every edge weight is nonnegative, then when Dijkstra's algorithm extracts a vertex $u$, the value $d[u]$ equals $\delta(s, u)$, and no later relaxation changes $d[u]$.

**Proof.** I1 holds whether or not weights are negative, by Theorem 5. The proof of I2 is an induction on the number of extractions. The nonnegative hypothesis is used in exactly one sentence, marked below.

The first extraction is $s$, and $d[s] = 0$. Nonnegative weights imply there is no negative cycle, so the empty walk is optimal and $\delta(s, s) = 0$.

Suppose I2 holds for the set $S$ of vertices already extracted, and $u$ is the next vertex extracted. Then $u$ was in the heap, so $d[u]$ is finite, and I1 gives a walk of that weight. Hence $\delta(s, u) \le d[u]$. The rest of the argument rules out the strict inequality $d[u] > \delta(s, u)$.

Let $p$ be a shortest $s$–$u$ path; Lemma 2 supplies one. Let $y$ be the first vertex of $p$ that is not in $S$, and let $x$ be the predecessor of $y$ on $p$. The vertex $x$ is in $S$: it is either $s$ or a vertex of $p$ before the first unsettled vertex. By I2, $d[x] = \delta(s, x)$. When $x$ was extracted, the edge $x \to y$ was relaxed, so

$$
d[y] \le \delta(s, x) + w(x, y).
$$

Lemma 3 says the prefix of $p$ that ends at $y$ is a shortest path, so $\delta(s, y) = \delta(s, x) + w(x, y)$. Combined with I1, $d[y] \ge \delta(s, y)$. Therefore $d[y] = \delta(s, y)$.

The vertex $y$ is not settled. It was inserted when the edge into it was first relaxed, and it has not been extracted, so $y$ is in the heap at the moment $u$ is extracted. Extract-min returns a minimum key, and keys in the heap equal the current labels, so $d[u] \le d[y]$.

Let $w_{\mathrm{suf}}$ be the weight of the suffix of $p$ from $y$ to $u$. **Every edge weight is nonnegative, so $w_{\mathrm{suf}} \ge 0$, and therefore $\delta(s, y) \le \delta(s, u)$.** This is the only step that uses the sign of the weights. Every preceding identity is an optimal-substructure or relaxation fact, and those facts survive a negative edge that does not create a negative cycle.

The chain is

$$
\delta(s, u) \le d[u] \le d[y] = \delta(s, y) \le \delta(s, u).
$$

Every term equals $\delta(s, u)$. In particular $d[u] = \delta(s, u)$, which is I2 for the enlarged set $S \cup \{u\}$.

A later relaxation cannot lower $d[u]$. I1 says a finite label is a walk weight, and a walk weight is at least $\delta(s, u)$. The algorithm also refuses to relax an edge into a settled vertex; the inequality just proved says that refusal does not discard an improvement. $\square$

Unreachable vertices are never extracted. Their labels stay $\infty$, which equals $\delta(s, v)$.

### 3.6 A negative edge, and the step that breaks

Consider the digraph with vertices $s, a, b$ and edges

```text
s → a    weight 2
s → b    weight 3
b → a    weight -2
```

There is no negative cycle. The walk $s, b, a$ has weight $3 + (-2) = 1$, and the direct edge $s \to a$ has weight $2$, so $\delta(s, a) = 1$ and $\delta(s, b) = 3$.

Dijkstra's algorithm extracts $s$ first and sets $d[a] = 2$, $d[b] = 3$. The next minimum is $a$, with label $2$. The algorithm settles $a$ and never changes $d[a]$ again. The true distance is $1$. The laboratory runs this graph and asserts that the settled label $2$ differs from the Bellman–Ford label $1$.

Place the same graph against the proof. When $a$ is extracted, $S = \{s\}$. On the true shortest path $s, b, a$, the first unsettled vertex is $y = b$, and $\delta(s, b) = 3$, while $\delta(s, a) = 1$. The suffix $b \to a$ has weight $-2 < 0$, so the claim $\delta(s, y) \le \delta(s, u)$ is false. The rest of the machinery is intact: $d[b]$ really is $3$, and $d[a] = 2 \le d[b]$. The extracted label is still not $\delta(s, a)$.

### 3.7 One full trace

The nonnegative digraph used for the rest of the Dijkstra section has vertices $s, a, b, c, t, z$. The vertex $z$ has no incident edge. The edges are

```text
s → a    2
s → b    6
a → b    3
a → c    1
b → t    1
c → b    1
c → t    7
```

```text
        2
   s ─────── a
   │         │ \
   │ 6       │3 \ 1
   │         │   \
   v         v    v
   b ←────── c    z     (z is isolated)
   │    1    │
   │ 1       │ 7
   v         v
   t ←───────┘
```

The trace records labels after the relaxations that follow each extraction. A blank heap means the algorithm has ended. The predecessor column records $\pi$ at that moment. A vertex whose predecessor changes is marked in the note.

| Step | Extract | $d(s)$ | $d(a)$ | $d(b)$ | $d(c)$ | $d(t)$ | $d(z)$ | Heap afterward | Predecessors set or changed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 |  | $0$ | $\infty$ | $\infty$ | $\infty$ | $\infty$ | $\infty$ | $s:0$ |  |
| 1 | $s$ | $0$ | $2$ | $6$ | $\infty$ | $\infty$ | $\infty$ | $a:2,\ b:6$ | $\pi[a]=s,\ \pi[b]=s$ |
| 2 | $a$ | $0$ | $2$ | $5$ | $3$ | $\infty$ | $\infty$ | $c:3,\ b:5$ | $\pi[b]=a,\ \pi[c]=a$ |
| 3 | $c$ | $0$ | $2$ | $4$ | $3$ | $10$ | $\infty$ | $b:4,\ t:10$ | $\pi[b]=c,\ \pi[t]=c$ |
| 4 | $b$ | $0$ | $2$ | $4$ | $3$ | $5$ | $\infty$ | $t:5$ | $\pi[t]=b$ |
| 5 | $t$ | $0$ | $2$ | $4$ | $3$ | $5$ | $\infty$ | empty |  |

Check the arithmetic of the decreases.

- After $s$: the edge $s \to a$ writes $0 + 2 = 2$; the edge $s \to b$ writes $0 + 6 = 6$.
- After $a$: the edge $a \to b$ offers $2 + 3 = 5$, which is less than $6$, so $d[b]$ falls from $6$ to $5$ and $\pi[b]$ changes from $s$ to $a$. The edge $a \to c$ writes $2 + 1 = 3$.
- After $c$: the edge $c \to b$ offers $3 + 1 = 4$, which is less than $5$, so $d[b]$ falls from $5$ to $4$ and $\pi[b]$ changes from $a$ to $c$. The edge $c \to t$ writes $3 + 7 = 10$.
- After $b$: the edge $b \to t$ offers $4 + 1 = 5$, which is less than $10$, so $d[t]$ falls from $10$ to $5$ and $\pi[t]$ changes from $c$ to $b$.
- The vertex $z$ is never inserted. Its label stays $\infty$.

The extraction order is $s, a, c, b, t$. At each extraction the chosen key is strictly smaller than every other key in the heap, so the order does not depend on the tie-break.

Final labels: $\delta(s, s) = 0$, $\delta(s, a) = 2$, $\delta(s, b) = 4$, $\delta(s, c) = 3$, $\delta(s, t) = 5$, and $\delta(s, z) = \infty$.

### 3.8 Reconstructing the path

Follow $\pi$ from the target back to the source, then reverse the list. On the trace,

$$
t \mapsto b \mapsto c \mapsto a \mapsto s,
$$

which reverses to the path $s, a, c, b, t$. Its weight is $2 + 1 + 1 + 1 = 5$, matching $d[t]$.

This reconstruction is correct for every settled vertex, not only for this example. When the edge $x \to y$ last lowered $d[y]$, the vertex $x$ was being extracted, so Theorem 7 had already fixed $d[x] = \delta(s, x)$, and the assignment wrote $d[y] = \delta(s, x) + w(x, y)$. Lemma 3 says that is the right recurrence for a successor on a shortest path. Walking $\pi$ from a settled vertex therefore walks backward along a shortest path and reaches $s$ after at most $n - 1$ steps. An unsettled vertex has $\pi = \mathrm{null}$ and $d = \infty$; it has no path.

### 3.9 The bound

Each vertex is inserted at most once and extracted at most once. Each edge causes at most one decrease-key, because a successful relaxation of $u \to v$ happens only while $u$ is being extracted, and $u$ is extracted once. The heap contains at most $n$ vertices, so each of these operations is $O(\log n)$.

Every one of those operations is $O(\log n)$, and there are $O(n + m)$ of them, so the running time on every adjacency-list input is

$$
O((n + m) \log n).
$$

The bound is an upper bound, not a claim about every graph. An isolated source performs one insertion and one extraction. A single sift that travels from a leaf to the root takes $\Theta(\log n)$ parent steps, so this implementation does not run in $O(n + m)$ time in the worst case: the logarithm is the height of the indexed heap. A Fibonacci heap improves the theoretical amortized bound to $\Theta(m + n \log n)$ by making decrease-key $O(1)$ amortized and extract-min $O(\log n)$ amortized. That structure is not used in this course.

---

## Part 4 — The Bellman–Ford algorithm

### 4.1 The schedule

The Bellman–Ford algorithm makes no sign restriction. It relaxes every edge, then does that again, for $n - 1$ passes. One more pass detects a negative cycle reachable from the source.

The edge list is an arbitrary fixed order. The final labels, when a negative cycle is absent, do not depend on that order. The intermediate labels do. The trace in Section 4.5 uses an order that moves the distance along a three-edge path one edge per pass, so that all $n - 1$ passes are visible.

```text
BellmanFord(G, s):
    for each vertex v:
        d[v] = ∞
        π[v] = null
        witness[v] = null
    d[s] = 0
    witness[s] = a node naming s, with no predecessor
    repeat n - 1 times:
        for each edge u → v in the fixed order:
            if d[u] is finite and d[u] + w(u, v) < d[v]:
                d[v] = d[u] + w(u, v)
                π[v] = u
                witness[v] = a new node naming v,
                             pointing at the current witness[u],
                             storing w(u, v)
    for each edge u → v in the same order:
        if d[u] is finite and d[u] + w(u, v) < d[v]:
            report a negative cycle on the walk
                witness[u] followed by u → v
            stop
    report the labels d and the predecessors π
```

The **witness** of $v$ is an immutable linked record of the walk whose weight is the current $d[v]$. Replacing `witness[v]` does not alter an older record that some other vertex still points at. Theorem 5 is then visible in the data: follow the links and add the stored edge weights, and the sum equals $d[v]$.

The predecessor $\pi[v]$ is the tail of the current witness, stored again so that a simple path can be read without walking an object chain. After a successful run with no negative cycle, $\pi$ reconstructs shortest paths. Section 4.4 proves that claim.

### 4.2 Why $n - 1$ passes are enough

**Lemma 8 (path-relaxation).** Let $p = \langle v_0, v_1, \ldots, v_k \rangle$ be any path with $v_0 = s$. After $k$ passes of relaxing every edge, $d[v_k] \le w(p)$.

**Proof.** Induction on $k$. For $k = 0$ the claim is $d[s] = 0$.

Assume the claim for the prefix $p'$ that ends at $v_{k-1}$: at the end of pass $k - 1$, $d[v_{k-1}] \le w(p')$. During pass $k$ every label either stays or falls, so at the moment the pass relaxes the edge $v_{k-1} \to v_k$, the current value of $d[v_{k-1}]$ is still at most $w(p')$. That relaxation writes a value at most $d[v_{k-1}] + w(v_{k-1}, v_k) \le w(p)$ into $d[v_k]$, or leaves $d[v_k]$ already smaller. Later relaxations in the same pass do not raise $d[v_k]$. At the end of pass $k$, $d[v_k] \le w(p)$. $\square$

The induction does not care where the edge $v_{k-1} \to v_k$ sits inside the pass. It cares that the whole pass happens after the prefix bound has already been achieved.

**Theorem 9.** Suppose no negative cycle is reachable from $s$. After $n - 1$ passes, $d[v] = \delta(s, v)$ for every vertex $v$.

**Proof.** If $v$ is unreachable, no relaxation writes a finite label into $d[v]$, because a finite label is a walk from $s$ by Theorem 5. Thus $d[v] = \infty = \delta(s, v)$.

If $v$ is reachable, Lemma 2 supplies a shortest path with $k \le n - 1$ edges. Lemma 8, applied to that path, says that after $k$ passes, and therefore after $n - 1$ passes, $d[v] \le \delta(s, v)$. Theorem 5 says $d[v]$ is a walk weight or $\infty$, so $d[v] \ge \delta(s, v)$. The two inequalities give equality. $\square$

The same proof shows why the schedule cannot be shortened to a constant number of passes in the worst case. A path of $n - 1$ edges whose edges appear in the list in reverse path order advances the finite label by only one vertex per pass. Pass $k$ is the first pass that is allowed to write the head of a $k$-edge path. The laboratory graph in Section 4.5 is a small case: $n = 4$, the shortest path to $c$ has three edges, and $d[c]$ becomes optimal on pass 3.

### 4.3 The extra pass

**Theorem 10.** After $n - 1$ passes, if any edge $u \to v$ still satisfies $d[u] + w(u, v) < d[v]$ with $d[u]$ finite, then a negative cycle is reachable from $s$. Conversely, if a negative cycle is reachable from $s$, some edge fails the triangle test on that extra pass and on every later pass that continues to relax.

**Proof of the first direction.** Suppose no negative cycle is reachable from $s$. Theorem 9 says $d = \delta$ everywhere. Lemma 4 says $\delta(s, v) \le \delta(s, u) + w(u, v)$ for every edge, so the strict test cannot succeed.

**Proof of the second direction.** Let $C$ be a cycle of negative weight reachable from $s$. Every vertex of $C$ is reachable from $s$ by a path of at most $n - 1$ edges. Lemma 8 applied to any such path writes a finite label by the end of pass $n - 1$. Thus, when the extra pass begins, $d[x]$ is finite for every vertex $x$ on $C$.

The same numerical test does not depend on the pass number. Whenever every vertex of $C$ has a finite label and no edge of $C$ satisfies $d[x] + w(x, y) < d[y]$, every edge $x \to y$ of $C$ satisfies

$$
d[x] + w(x, y) \ge d[y].
$$

Sum those inequalities around $C$. Each label $d[x]$ appears once on the left and once on the right and cancels, leaving $w(C) \ge 0$. That contradicts $w(C) < 0$. Therefore, at the start of the extra pass, some edge of $C$ still relaxes. Its tail has a finite label, so the tail is reachable from $s$, and $C$ itself is reachable from $s$.

After that relaxation the labels on $C$ are still finite. The same summing argument says that a later full pass also finds an edge of $C$ to relax, for as long as the algorithm continues. The detection pass is the first place the schedule looks. $\square$

### 4.4 Naming the cycle, and reading a path when there is none

**Theorem 11.** Suppose the extra pass finds an edge $u \to v$ with $d[u]$ finite and $d[u] + w(u, v) < d[v]$. Let $W$ be the witness walk of $u$ followed by the edge $u \to v$. Then $W$ contains a cycle of negative weight.

**Proof.** The witness invariant says $w(W) = d[u] + w(u, v) < d[v]$. Suppose, for a contradiction, that every cycle lying on $W$ has nonnegative weight. While $W$ is not a path, it contains a cycle; delete one. Each deletion removes a nonnegative weight, so the weight of the remaining walk does not increase. The process ends at a path $P$ from $s$ to $v$ with $w(P) \le w(W) < d[v]$. A path has at most $n - 1$ edges. Let $k \le n - 1$ be the number of edges of $P$. Lemma 8 gives $d[v] \le w(P)$ at the end of pass $k$. Later passes never raise a label, so the same inequality holds at the end of pass $n - 1$. Therefore $d[v] < d[v]$, which is absurd. Some cycle on $W$ has negative weight. $\square$

The program walks $W$, and for every repeated vertex it sums the subwalk between two occurrences. Theorem 11 guarantees that at least one of those subwalks has negative weight. The laboratory graph produces the cycle $a \to b \to a$ of weight $2 + (-4) = -2$.

When the extra pass updates nothing, predecessors describe shortest paths.

**Theorem 12.** Suppose no negative cycle is reachable from $s$. After $n - 1$ passes, for every reachable vertex $v$ the predecessor chain $\pi$ is a shortest path from $s$ to $v$ read backward.

**Proof.** Let $v$ be reachable, $v \ne s$. The last relaxation that wrote the final value $d[v] = \delta(s, v)$ did so along some edge $u \to v$, at a moment when $d[u]$ had some value $d_{\mathrm{then}}(u)$, and $\delta(s, v) = d_{\mathrm{then}}(u) + w(u, v)$. Labels only fall, so $d_{\mathrm{then}}(u) \ge \delta(s, u)$, and Lemma 4 says $\delta(s, v) \le \delta(s, u) + w(u, v)$. Combine them:

$$
\delta(s, v) = d_{\mathrm{then}}(u) + w(u, v) \ge \delta(s, u) + w(u, v) \ge \delta(s, v).
$$

Every term is equal, so $d_{\mathrm{then}}(u) = \delta(s, u)$. The later final label of $u$ is also $\delta(s, u)$, so $u$ was already final at that moment, and $\pi[v] = u$ was not overwritten by a later improvement. Induction along the chain reaches $s$ and every edge satisfies the equality of Lemma 3. $\square$

### 4.5 Trace: a negative edge, and no negative cycle

Vertices $s, a, b, c$, so $n = 4$ and the algorithm runs three passes plus a detection pass. The edge list, in the order the passes use, is

```text
b → c    3
a → b   -2
a → c    8
s → c   10
s → a    4
```

There is no cycle at all through a negative edge. The only cycle-free routes are simple paths. The shortest path to $c$ is $s, a, b, c$, of weight $4 + (-2) + 3 = 5$. The direct edge $s \to c$ has weight $10$.

| After pass | $d(s)$ | $d(a)$ | $d(b)$ | $d(c)$ | What the pass wrote |
| --- | --- | --- | --- | --- | --- |
| 0 | $0$ | $\infty$ | $\infty$ | $\infty$ | initialization |
| 1 | $0$ | $4$ | $\infty$ | $10$ | $s \to c$ writes $10$; $s \to a$ writes $4$. The edges out of $a$ and $b$ see an infinite tail and do nothing. |
| 2 | $0$ | $4$ | $2$ | $10$ | $b \to c$ still sees $d[b] = \infty$ because $a \to b$ appears later in the list. Then $a \to b$ writes $4 + (-2) = 2$. The offer $4 + 8 = 12$ does not beat $d[c] = 10$. |
| 3 | $0$ | $4$ | $2$ | $5$ | $b \to c$ now sees $d[b] = 2$ and writes $2 + 3 = 5$. |
| extra | $0$ | $4$ | $2$ | $5$ | $2 + 3 = 5$ is not strictly less than $5$. No other edge improves. There is no negative cycle. |

The predecessors after pass 3 are $\pi[a] = s$, $\pi[b] = a$, $\pi[c] = b$. The path to $c$ is $s, a, b, c$.

Pass 2 does not write the optimal label of $c$, even though $d[b]$ becomes $2$ during that pass, because $b \to c$ was considered before $a \to b$. The next pass is the repair. This is the path-relaxation lemma in numbers: the three-edge path is guaranteed by the end of pass 3, not by the end of the pass that first touches its last edge in the wrong order.

A separate one-vertex check belongs with this algorithm. On the digraph with vertices $s, r$ and no edges, $n - 1 = 1$. The single pass examines nothing. The detection pass examines nothing. The label $d[r]$ stays $\infty$, and the algorithm does not report a cycle. An unreachable vertex is not a negative cycle.

### 4.6 Trace: the extra pass reports a cycle

Vertices $s, a, b$, so two passes plus a detection pass. The edge list is

```text
s → a    1
a → b    2
b → a   -4
```

The cycle $a \to b \to a$ has weight $2 + (-4) = -2$ and is reachable from $s$.

| After pass | $d(s)$ | $d(a)$ | $d(b)$ | Witness event |
| --- | --- | --- | --- | --- |
| 0 | $0$ | $\infty$ | $\infty$ |  |
| 1 | $0$ | $-1$ | $3$ | $s \to a$ writes $1$; $a \to b$ writes $3$; $b \to a$ writes $3 + (-4) = -1$. |
| 2 | $0$ | $-3$ | $1$ | $a \to b$ writes $-1 + 2 = 1$; $b \to a$ writes $1 + (-4) = -3$. |
| extra |  |  |  | The edge $a \to b$ offers $-3 + 2 = -1$, and $-1 < 1$. The algorithm reports a cycle. |

The witness of $a$ after pass 2 is the walk $s, a, b, a, b, a$ of weight $1 + 2 + (-4) + 2 + (-4) = -3$, which equals $d[a]$. Extending it by the detecting edge $a \to b$ keeps the cycle $a \to b \to a$ of weight $-2$ on the walk. Theorem 11 says some negative cycle had to be there; the arithmetic shows which one.

### 4.7 The bound

Each of the $n - 1$ passes examines all $m$ edges, and the detection pass examines at most $m$ edges. The running time is

$$
\Theta(nm).
$$

The bound is tight for this schedule because the loops do not stop early: they always perform $(n - 1)m$ relaxation attempts in the main phase. An implementation may stop early when a pass updates nothing. That optimization is correct, by the same triangle argument as Theorem 10, and it does not change the worst-case bound. A graph whose shortest path has $n - 1$ edges, listed backward, updates on every pass. This lecture's program runs all $n - 1$ passes so that the trace and the code describe the same schedule.

---

## Part 5 — Shortest paths in a DAG

### 5.1 The restriction

A **directed acyclic graph**, a DAG, has no directed cycle of any weight. Lecture 12 produces a topological order: a list of all vertices such that every edge goes from an earlier vertex to a later vertex. The existence of that order is equivalent to the absence of a directed cycle. This lecture uses the order and does not re-prove the depth-first numbering. The laboratory builds the order by source removal, which is the same order: a finite DAG has a vertex of indegree $0$, because a walk that always enters along an incoming edge would otherwise be infinite and would repeat a vertex. Delete that vertex, and repeat.

Negative weights are allowed. A DAG cannot contain a negative cycle, because it cannot contain a cycle. Lemma 2 applies to every source.

### 5.2 One pass

```text
DAG-shortest-paths(G, s):
    order = a topological order of G
    initialize d and π as in relaxation, with d[s] = 0
    for each vertex u in topological order:
        if d[u] is finite:
            for each edge u → v:
                relax(u, v)
```

**Theorem 13.** The algorithm sets $d[v] = \delta(s, v)$ for every vertex $v$.

**Proof.** Induction along the topological order. For a vertex $v$ that appears before $s$, every predecessor of $v$ also appears before $s$, and none of those vertices is reachable from $s$ (an edge into the past would contradict the order). Those labels stay $\infty$, and $\delta(s, v) = \infty$.

Suppose every vertex before $v$ in the order already holds its true distance, and consider $v$ itself after the algorithm has processed every earlier vertex. Every incoming edge $u \to v$ starts at an earlier vertex, so $u$ has already been processed and $d[u] = \delta(s, u)$ at the time the edge was relaxed. Relaxation has therefore already considered the candidate $\delta(s, u) + w(u, v)$.

If $v$ is unreachable, every predecessor is unreachable, every candidate was skipped because of an infinite tail, and $d[v] = \infty$.

If $v$ is reachable, Lemma 3 says a shortest path enters $v$ from some predecessor $u$ with $\delta(s, v) = \delta(s, u) + w(u, v)$. That candidate was written, or an equal candidate was already present, so $d[v] \le \delta(s, v)$. Theorem 5 gives the opposite inequality. $\square$

One pass is enough because a shortest path uses vertices in topological order. When the pass reaches the tail of an edge on that path, the tail's distance is already final, and the head has not yet needed its own outgoing edges. A second pass would relax the same edges against the same finite labels and would change nothing.

### 5.3 The trace

Vertices, already written in the unique topological order $s, a, b, c, t$:

```text
s → a    3
s → b    6
a → b   -2
a → c    4
b → c    1
b → t    5
c → t    2
```

Indegrees: $s$ has indegree $0$, and every other vertex has a positive indegree until its predecessors are deleted. Source removal therefore emits exactly $s, a, b, c, t$.

Process $s$. The edge $s \to a$ writes $d[a] = 3$. The edge $s \to b$ writes $d[b] = 6$.

Process $a$. The edge $a \to b$ offers $3 + (-2) = 1$, which replaces $6$, and $\pi[b] = a$. The edge $a \to c$ writes $d[c] = 7$, and $\pi[c] = a$.

Process $b$. The edge $b \to c$ offers $1 + 1 = 2$, which replaces $7$, and $\pi[c] = b$. The edge $b \to t$ writes $d[t] = 6$, and $\pi[t] = b$.

Process $c$. The edge $c \to t$ offers $2 + 2 = 4$, which replaces $6$, and $\pi[t] = c$.

Process $t$. There is no outgoing edge.

Final labels: $d(s) = 0$, $d(a) = 3$, $d(b) = 1$, $d(c) = 2$, $d(t) = 4$. The path to $t$ is $s, a, b, c, t$, of weight $3 + (-2) + 1 + 2 = 4$. The path $s, a, b, t$ weighs $3 + (-2) + 5 = 6$. The negative edge was useful and was safe, because it does not close a cycle.

### 5.4 The bound

Source removal scans each vertex and each edge a constant number of times, which is $\Theta(n + m)$. The relaxation pass does the same. The total is $\Theta(n + m)$.

---

## Part 6 — Minimum spanning trees, cuts, and cycles

### 6.1 Definitions

The input for the rest of the spanning-tree sections is a connected undirected graph $G = (V, E)$ with a weight function on $E$. Weights may be negative. A spanning tree selects edges; it does not walk around them, so a negative edge is a cheap connection rather than a cycle to exploit.

A **spanning tree** is a subset $T \subseteq E$ such that $(V, T)$ is connected and contains no cycle. Any such $T$ has exactly $n - 1$ edges. Equivalently, $T$ is acyclic and has $n - 1$ edges, or $T$ is connected and has $n - 1$ edges.

A **minimum spanning tree**, an MST, is a spanning tree whose total weight is minimum among all spanning trees.

If $G$ is disconnected, no spanning tree exists. The same algorithms then produce a **minimum spanning forest**: an MST of each connected component. The laboratory checks a three-vertex graph with one edge, which is a forest of one tree-edge and one isolated vertex.

A **cut** is a partition of $V$ into two nonempty sets $S$ and $V \setminus S$. An edge **crosses** the cut when one endpoint lies in $S$ and the other lies in $V \setminus S$.

Let $A \subseteq E$. The cut **respects** $A$ when no edge of $A$ crosses the cut. Every edge of $A$ is internal to $S$ or internal to $V \setminus S$.

A **light edge** across the cut is a crossing edge of minimum weight. If several crossing edges share that weight, each of them is light.

An edge $e \notin A$ is **safe for $A$** when $A \cup \{e\}$ is still a subset of some MST.

### 6.2 Distinct weights, then ties

**Theorem 14.** If all edge weights are distinct, the MST is unique.

**Proof.** Suppose $T_1$ and $T_2$ are distinct MSTs. Let $e$ be the lightest edge that belongs to one of them and not the other. Say $e \in T_1 \setminus T_2$. Add $e$ to $T_2$. The resulting graph has a cycle $C$. Some edge $e'$ of $C$ is not in $T_1$, because $T_1$ is acyclic, so $C$ is not contained in $T_1$. Then $e' \in T_2 \setminus T_1$ and $e' \ne e$. The edge $e$ was the lightest edge of the symmetric difference, so $w(e') > w(e)$: the weights differ, and $w(e') < w(e)$ would contradict the choice of $e$. The set $T_2 - \{e'\} \cup \{e\}$ is a spanning tree, and it is strictly lighter than $T_2$, which contradicts the optimality of $T_2$. $\square$

If weights may tie, uniqueness fails. The graph with vertices $a, b, c, d$ and weights $ab:1$, $bc:2$, $ac:2$, $cd:3$, $ad:7$, $bd:8$ has two MSTs, $\{ab, bc, cd\}$ and $\{ab, ac, cd\}$, both of weight $6$. The cut and cycle theorems below name the extra hypothesis each one needs.

### 6.3 The cut property

**Theorem 15 (cut property).** Let $A$ be a subset of some MST. Let $(S, V \setminus S)$ be a cut that respects $A$, and let $e$ be a light edge across the cut. Then $e$ is safe for $A$.

**Proof.** Let $T$ be an MST that contains $A$. If $e \in T$, then $A \cup \{e\} \subseteq T$ and there is nothing to prove. Suppose $e \notin T$. Add $e$ to $T$. The unique cycle $C$ of $T \cup \{e\}$ has at least one edge other than $e$ that crosses the cut, because $C$ must leave $S$ and later return. Choose such an edge $e'$. The cut respects $A$, and $e'$ crosses the cut, so $e' \notin A$.

Delete $e'$ and keep $e$. The set $T' = T - \{e'\} \cup \{e\}$ is still a spanning tree: it reconnects the two components of $T - \{e'\}$ by the crossing edge $e$, and it has $n - 1$ edges. Since $e$ is light and $e'$ crosses the same cut, $w(e) \le w(e')$. Therefore $w(T') \le w(T)$. But $T$ is an MST, so $w(T') = w(T)$ and $T'$ is an MST. Also $A \subseteq T$ and $e' \notin A$, so $A \cup \{e\} \subseteq T'$. The edge $e$ is safe for $A$. $\square$

When the weights are distinct, $e$ is the only light edge, the inequality $w(e) \le w(e')$ is strict, and $e$ belongs to the unique MST.

The exchange removes $e'$, an edge that crosses the cut. It does not remove an edge of $A$, because no edge of $A$ crosses the cut. That is why the hypothesis "the cut respects $A$" is part of the statement and not a decoration.

### 6.4 The cycle property

**Theorem 16 (cycle property).** Suppose all edge weights are distinct. If $e$ is the heaviest edge on a cycle $C$, then $e$ belongs to no MST.

**Proof.** Suppose some MST $T$ contains $e$. Delete $e$. The tree falls into two components; call one side of that cut $S$. The cycle $C$ leaves $S$ along $e$ and must re-enter along a different edge $e'$. Then $e'$ crosses the cut, and $T' = T - \{e\} \cup \{e'\}$ is a spanning tree. Distinct weights on $C$ give $w(e') < w(e)$, so $w(T') < w(T)$, which contradicts the optimality of $T$. $\square$

If another edge of $C$ ties $e$ for heaviest, the exchange yields $w(T') \le w(T)$, so there exists an MST that avoids $e$. A different MST may still contain $e$. The statement that survives ties is: a unique heaviest edge of a cycle is in no MST.

### 6.5 A negative weight is a legal tree edge

On the connected graph with vertices $a, b$ and one edge of weight $-5$, that edge is the MST. Both algorithms in the laboratory return it. Nothing in Theorems 15 or 16 required a positive weight.

---

## Part 7 — Kruskal's algorithm

### 7.1 The rule

Sort the undirected edges into nondecreasing order of weight. Scan that list. Add the next edge when its endpoints lie in different connected components of the forest built so far. Reject it when they lie in the same component, because the edge would close a cycle.

The component test is a disjoint-set structure. Part 9 specifies the operations. For correctness it is enough that `find` returns the same representative for two vertices exactly when the edges already accepted connect them, and that `union` merges those two components. The implementation uses union by rank and path compression. The time bound in Section 7.4 names the cost of that choice.

Each undirected edge is stored with its endpoints in lexicographic order, and `union` is called in that stored order. The equal-rank rule of Part 9 then makes the parent pointers of the trace a determined function of the edge list.

### 7.2 The trace, on the graph Prim will use again

Vertices $a, b, c, d$. Edges, already sorted by distinct weights:

```text
a—b    1
b—c    2
c—d    3
a—c    4
a—d    7
b—d    8
```

```text
          1
     a -------- b
     | \        | \
    4|  \7     2|  \8
     |   \      |   \
     c ---3---- d
```

The six weights on that drawing are $a$—$b:1$, $a$—$c:4$, $a$—$d:7$, $b$—$c:2$, $b$—$d:8$, and $c$—$d:3$.

| Edge | Endpoints' components before the test | Decision | Forest afterward |
| --- | --- | --- | --- |
| $a$—$b$ weight $1$ | $\{a\}, \{b\}$ | add | $\{a, b\}, \{c\}, \{d\}$ |
| $b$—$c$ weight $2$ | $\{a, b\}, \{c\}$ | add | $\{a, b, c\}, \{d\}$ |
| $c$—$d$ weight $3$ | $\{a, b, c\}, \{d\}$ | add | $\{a, b, c, d\}$ |
| $a$—$c$ weight $4$ | same component | reject | unchanged |
| $a$—$d$ weight $7$ | same component | reject | unchanged |
| $b$—$d$ weight $8$ | same component | reject | unchanged |

The accepted edges are $a$—$b$, $b$—$c$, and $c$—$d$. The total weight is $1 + 2 + 3 = 6$. There are $n - 1 = 3$ of them, and they connect all four vertices, so they form a spanning tree. Theorem 14 says it is the only MST.

The same three decisions are the cut property in order.

- After $A = \emptyset$, any cut respects $A$. The first edge in sorted order is a lightest edge of the graph, hence light across the cut that separates one of its ends from the other before it is added. The first accepted edge of Kruskal is always safe.
- Take $A = \{a\text{—}b\}$ and $S = \{a, b\}$. No edge of $A$ leaves $S$. The crossing edges are $a$—$c$ of weight $4$, $b$—$c$ of weight $2$, $a$—$d$ of weight $7$, and $b$—$d$ of weight $8$. The light edge is $b$—$c$. Kruskal adds it next.
- Take $A = \{a\text{—}b,\ b\text{—}c\}$ and $S = \{a, b, c\}$. The crossing edges are $a$—$d$ of weight $7$, $b$—$d$ of weight $8$, and $c$—$d$ of weight $3$. The light edge is $c$—$d$. Kruskal adds it next.

The rejected edge $a$—$c$ is the heaviest edge on the triangle $a, b, c$, whose weights are $1, 2, 4$. Theorem 16 says it is in no MST.

### 7.3 Correctness

**Theorem 17.** On a connected undirected graph, Kruskal's algorithm returns an MST. On a disconnected graph it returns a minimum spanning forest.

**Proof.** Let $A$ be the set of edges accepted so far. The claim proved by induction on the number of accepted edges is that $A$ is a subset of some MST of the component structure it spans; on a connected graph, of some MST of $G$. The empty set is a subset of every MST.

Suppose the claim holds, and the algorithm next accepts $e = \{u, v\}$. Let $S$ be the component of $u$ in $(V, A)$. Then $v \notin S$, and the cut $(S, V \setminus S)$ respects $A$. The edge $e$ crosses it. It is light: if a strictly lighter edge $e'$ also crossed the cut, then $e'$ would appear earlier in the sorted list, its endpoints would have been in different components at that earlier moment (components only grow), and Kruskal would have accepted $e'$, contradicting that the endpoints are still separated. If several edges share the light weight, the one Kruskal accepts is one of the light edges. Theorem 15 says $e$ is safe for $A$.

The algorithm never accepts an edge inside a component, so $A$ stays acyclic. Each accepted edge reduces the number of components by one. On a connected graph the algorithm accepts $n - 1$ edges. An acyclic set of $n - 1$ edges is a spanning tree, and it is contained in an MST, so it is an MST.

On a disconnected graph the same argument applies inside each component of $G$, and no edge of $G$ crosses between those components. $\square$

### 7.4 The bound

Sorting $m$ edges by a comparison sort is $\Theta(m \log m)$ in the worst case. Lecture 06 supplies the sort; this lecture does not reopen it. For a simple graph, $m \le n(n - 1)/2$, so $\log m \le 2 \log n$ and the sort is $O(m \log n)$. Whenever $n \le m$, one also has $\log m \ge \log n$, so the sort is $\Theta(m \log n)$ for every simple graph that has at least as many edges as vertices.

The scan performs $O(m)$ find and union operations on $n$ elements. With union by rank and path compression, Theorem 22 of Part 9 bounds that scan by $O(m \, \alpha(n))$.

The disjoint-set term is absorbed by the sort: $\alpha(n)$ grows slower than $\log n$, so the running time of Kruskal's algorithm is $O(m \log n)$, and sorting dominates. The precise split is worth keeping. Replacing the forest with a slower cycle test would change the bound. The $O(m \, \alpha(n))$ term is the cost of the test this course actually uses.

---

## Part 8 — Prim's algorithm

### 8.1 The rule

Prim's algorithm grows one tree from a chosen source. Let $S$ be the vertex set of the tree grown so far, and let $A$ be its edge set. The next edge is a light edge leaving $S$. The indexed binary heap stores each discovered vertex $v \notin S$ under a key equal to the weight of the lightest edge already seen from $S$ to $v$. The predecessor $\pi[v]$ names the other end of that edge, which lies in $S$.

```text
Prim(G, r):
    for each vertex v:
        key[v] = ∞
        π[v] = null
    key[r] = 0
    insert r into the indexed heap
    S = empty
    while the heap is not empty:
        u = extract-min
        add u to S
        if π[u] is not null:
            accept the undirected edge {π[u], u} of weight key[u]
        for each edge {u, v} with v not in S:
            if w(u, v) < key[v]:
                key[v] = w(u, v)
                π[v] = u
                if v is in the heap: decrease-key(v)
                else: insert v
```

The source is extracted first, with key $0$, and it contributes no tree edge. Every later extraction adds the edge that justified the key.

**Heap invariant.** For every vertex $v$ not in $S$, $\mathrm{key}[v]$ equals the minimum weight of an edge from $S$ to $v$, or $\infty$ if no such edge has been seen. Processing $u$ is the moment $u$ enters $S$. Every new edge from $S$ into the complement is incident to $u$, and the loop considers each of them. Edges from the old set $S$ were considered when their $S$-endpoint was processed. The invariant holds after the loop.

### 8.2 The same graph as Kruskal

Start Prim at $a$ on the six-edge graph of Section 7.2.

| Extract | Keys written during this step | Tree edge added |
| --- | --- | --- |
| $a$, key $0$ | $b \leftarrow 1$ via $a$; $c \leftarrow 4$ via $a$; $d \leftarrow 7$ via $a$ | none |
| $b$, key $1$ | $c$ falls from $4$ to $2$ via $b$; the edge $b$—$d$ of weight $8$ does not beat $d$'s key $7$ | $a$—$b$ of weight $1$ |
| $c$, key $2$ | $d$ falls from $7$ to $3$ via $c$ | $b$—$c$ of weight $2$ |
| $d$, key $3$ | no vertex remains outside | $c$—$d$ of weight $3$ |

The extraction order is $a, b, c, d$. The accepted edges are $a$—$b$, $b$—$c$, and $c$—$d$. As a set, that is the MST Kruskal built. The order of acceptance differs in the story each algorithm tells: Kruskal commits to a globally lightest safe edge, Prim commits to a lightest edge on the single cut around its growing tree. Distinct weights force the two edge sets to coincide, by Theorem 14. The algorithms can accept the shared edges in different sequences on a larger graph; the set is what uniqueness determines.

### 8.3 Correctness

**Theorem 18.** On a connected undirected graph, Prim's algorithm returns an MST.

**Proof.** Let $A$ be the set of accepted edges when a vertex $u \ne r$ is about to be added, and let $S$ be the vertex set already in the tree. The cut $(S, V \setminus S)$ respects $A$, because every edge of $A$ has both ends in $S$. The heap invariant says $\mathrm{key}[u]$ is the weight of a lightest edge from $S$ to $u$, and $u$ has the minimum key in the heap, so the edge $\{\pi[u], u\}$ is a light edge across the cut. Theorem 15 says the edge is safe for $A$. After $n - 1$ additions, $A$ is a spanning tree contained in an MST. $\square$

If the graph is disconnected, the loop as written grows only the component of $r$, because a vertex in another component is never inserted. The edges it returns are an MST of that component.

### 8.4 The bound

Each undirected edge is stored at both endpoints, so the scan examines $2m$ adjacency records and performs at most $2m$ decrease-key operations. Together with at most $n$ insertions and $n$ extractions, on a heap of size at most $n$, every heap operation is $O(\log n)$. The running time is

$$
O((n + m) \log n).
$$

A version of Prim that keeps no heap, and instead scans all vertices to find the next minimum key, runs in $\Theta(n^2)$ time. When $m = \Theta(n^2)$ the heap version is $O(n^2 \log n)$, and the scan's $\Theta(n^2)$ guarantee is the better worst-case bound. This course implements the heap version, which is the better of the two when the graph is sparse.

---

## Part 9 — Disjoint sets

### 9.1 The abstract operations

A **disjoint-set** structure maintains a partition of a finite set. Three operations define it.

- `make-set(x)` creates a block $\{x\}$. The element $x$ must not already belong to the structure.
- `find(x)` returns the **representative** of the block that contains $x$. Two elements are in the same block exactly when their representatives are equal.
- `union(a, b)` merges the block of $a$ with the block of $b$. If they are already the same block, the operation changes nothing and reports that fact.

Kruskal's algorithm calls `make-set` once per vertex, `find` on the endpoints of every edge, and `union` on each accepted edge.

### 9.2 The forest

The representation is a **disjoint-set forest**. Each element is a node. Each node stores a parent pointer and a nonnegative integer called its **rank**. A root is its own parent. The nodes of one tree are one block, and the root is the representative.

`make-set(x)` sets $\mathrm{parent}[x] = x$ and $\mathrm{rank}[x] = 0$.

`find(x)` walks parent pointers to the root. That walk is the whole operation when path compression is off. Section 9.4 adds compression.

`union(a, b)` finds both roots and links one root under the other.

**Union by rank.** Let $x$ and $y$ be distinct roots. The root of smaller rank becomes the child. The root of larger rank becomes the parent. Precisely:

```text
link(x, y):          // x and y are distinct roots
    if rank[x] < rank[y]:
        swap x and y
    parent[y] = x
    if rank[x] = rank[y]:
        rank[x] = rank[x] + 1
```

When the ranks differ, the root of larger rank becomes the parent, and neither rank changes. When the ranks are equal, the root of the first argument of `link` becomes the parent, and its rank increases by $1$. The call `union(a, b)` invokes `link(find(a), find(b))`, so on an equal-rank tie the root of the first argument of `union` becomes the parent.

Rank is not a count of nodes. Section 9.3 proves what it measures.

### 9.3 Height without compression

Until Section 9.4, `find` does not rewrite pointers. Links are the only changes to parent.

**Lemma 19.** With union by rank and no path compression, every node $x$ satisfies $\mathrm{height}(x) = \mathrm{rank}(x)$. Height is the length, in edges, of a longest downward path in the subtree of $x$. A leaf has height $0$.

**Proof.** Induction on the number of links. After `make-set`, the node is a leaf of rank $0$.

Consider a link that makes $y$ a child of $x$, under the rule above. Ranks of nodes that are already children do not change, and a non-root never receives a rank update, so the inductive hypothesis still identifies height with rank inside the old trees of $x$ and of $y$.

If the ranks differed before the link, then $\mathrm{rank}[y] < \mathrm{rank}[x]$ after the swap in the pseudocode, and $\mathrm{rank}[x]$ does not change. The new height of $x$ is

$$
\max(\mathrm{rank}[x],\ \mathrm{rank}[y] + 1).
$$

The second argument is at most $\mathrm{rank}[x]$ because $\mathrm{rank}[y] \le \mathrm{rank}[x] - 1$. The new height equals $\mathrm{rank}[x]$.

If the ranks were equal, the new rank of $x$ is the old rank plus one, and the new height is $\mathrm{rank}[y] + 1$, which equals the new rank. $\square$

So, with no compression, rank is not an estimate of height. It is the height.

**Lemma 20.** With union by rank and no path compression, a node of rank $r$ has at least $2^r$ nodes in its subtree.

**Proof.** Induction on $r$. A node of rank $0$ is a singleton at birth, and later growth only adds descendants, so the subtree has size at least $1 = 2^0$.

A node first reaches rank $r \ge 1$ when, as a root of rank $r - 1$, it is linked with another root of rank $r - 1$. By the inductive hypothesis each of those trees has size at least $2^{r-1}$. The link produces a tree of size at least $2^r$. Later links under this node add descendants and do not reduce the size. Without compression, descendants are never moved out. $\square$

**Theorem 21.** With union by rank and no path compression, every tree on a universe of $n$ elements has height at most $\lfloor \log_2 n \rfloor$. Therefore `find` runs in $O(\log n)$ time.

**Proof.** Lemma 20 applied to a root of rank $r$ gives $2^r \le n$, so $r \le \lfloor \log_2 n \rfloor$. Lemma 19 says the height equals the rank. A find walks at most that many edges. $\square$

The bound is tight. On eight elements, the equal-rank links

```text
union(1, 2), union(3, 4), union(5, 6), union(7, 8),
union(1, 3), union(5, 7),
union(1, 5)
```

build one tree of rank $3$ and height $3$. And $\lfloor \log_2 8 \rfloor = 3$. Each linking step doubles a lower bound that the previous step established, which is the same arithmetic as Lemma 20, achieved with equality because each merged pair had equal size as well as equal rank.

### 9.4 Path compression

**Path compression** changes `find`. While the walk from $x$ climbs to the root, the walk records the nodes it touched. It then sets the parent of each of those nodes to the root. The next find on any of them is a single hop, unless a later link puts a new root above.

```text
find(x):
    if parent[x] ≠ x:
        parent[x] = find(parent[x])
    return parent[x]
```

Compression does not change any rank. It can move a node from a deep subtree into a direct child of the root, so a subtree can lose nodes. Lemma 20 does not survive that move. Lemma 19 does not survive it either: height can fall while rank stays. Rank remains an upper bound on the height of the current tree, because compression never lengthens a path and never raises a rank, but rank is no longer the exact height.

The course still implements both mechanisms together. The $O(\log n)$ theorem is the fact proved without compression. The fact used for Kruskal's bound is the next theorem, which needs both mechanisms and is not proved in this lecture.

**Theorem 22 (Tarjan).** A sequence of $m$ make-set, find, and union operations, of which $n$ are make-set, runs in $O(m \, \alpha(n))$ time on a disjoint-set forest that uses union by rank and path compression. Here $\alpha$ is the inverse of Ackermann's function.

Tarjan proved this in 1975. The textbook development is Cormen, Leiserson, Rivest, and Stein, 4th edition, Chapter 19, Section 19.4. The same chapter is Chapter 21 of the 3rd edition, which is the numbering many citations still use. This lecture does not construct Ackermann's function and does not prove Theorem 22. What a student needs in order to use the theorem is the growth of $\alpha$: $\alpha(n)$ tends to infinity, and it does so slowly enough that $\alpha(n) \le 4$ for every $n$ that fits in memory on any machine this course's programs will run on. For every graph in this lecture, and for every graph whose vertex set fits in a JavaScript array in ordinary memory, the disjoint-set scan of Kruskal's algorithm is linear for every practical purpose, and the asymptotic name of that near-linearity is $O(m \, \alpha(n))$.

A weaker bound, $O(m \log^* n)$ with a related compression argument, was proved earlier by Hopcroft and Ullman. It is cited so that $\alpha$ is not confused with an iterated logarithm. The course claims Tarjan's bound, not the weaker one, and it claims the bound as a citation.

### 9.5 The forest behind the Kruskal trace

Use the equal-rank rule of Section 9.2 on the accepted edges of Section 7.2, in order, with compression on. Compression does not rewrite any pointer beyond what the links themselves write, because every find in this particular run already sits next to a root.

- `make-set` on $a, b, c, d$. Every parent is the element itself. Every rank is $0$.
- `union(a, b)`. Ranks are equal. Then $\mathrm{parent}[b] = a$ and $\mathrm{rank}[a] = 1$.
- `union(b, c)`. The root of $b$ is $a$, the root of $c$ is $c$, and $\mathrm{rank}[a] > \mathrm{rank}[c]$. Then $\mathrm{parent}[c] = a$. The rank of $a$ stays $1$.
- `union(c, d)`. The root of $c$ is $a$. Then $\mathrm{parent}[d] = a$.

The four vertices have one representative. The parent array is $a \mapsto a$, $b \mapsto a$, $c \mapsto a$, $d \mapsto a$, and $\mathrm{rank}[a] = 1$. The rejected edges find that same root twice and call no link. This is the forest the laboratory asserts after the Kruskal scan.

### 9.6 A compression trace that actually rewrites a pointer

The Kruskal forest was already flat. The following five elements exist so that compression has a path to shorten. Ranks start at $0$.

1. `union(d, e)`. Equal ranks. Then $\mathrm{parent}[e] = d$ and $\mathrm{rank}[d] = 1$.
2. `union(c, d)`. The root $d$ outranks the root $c$. Then $\mathrm{parent}[c] = d$. The tree is $d$ with children $e$ and $c$.
3. `union(a, b)`. Then $\mathrm{parent}[b] = a$ and $\mathrm{rank}[a] = 1$.
4. `union(a, d)`. The roots $a$ and $d$ both have rank $1$. Then $\mathrm{parent}[d] = a$ and $\mathrm{rank}[a] = 2$.

The forest is now

```text
          a          rank 2, height 2
         / \
        b   d        rank 1, height 1
           / \
          e   c      rank 0, height 0
```

Before any deep find, $\mathrm{parent}[e] = d$ and $\mathrm{parent}[c] = d$. The height is $2$, equal to the rank of $a$, which agrees with Lemma 19 because no compression has happened.

`find(e)` walks $e \to d \to a$ and sets $\mathrm{parent}[e] = a$. The node $c$ is still under $d$, so the height is still $2$. The rank of $a$ is still $2$.

`find(c)` walks $c \to d \to a$ and sets $\mathrm{parent}[c] = a$. Every child of $a$ is now a leaf or the node $d$ with no remaining child. The height is $1$. The rank of $a$ is still $2$. Rank is an upper bound on the height and is not the height.

The same four unions with compression disabled leave $\mathrm{parent}[e] = d$ and $\mathrm{parent}[c] = d$ after both finds. The height stays $2$, equal to the rank. The laboratory builds both forests and asserts both outcomes.

---

## Part 10 — Choosing an algorithm

The weight restriction decides the shortest-path algorithm. The shape of the input decides the spanning-tree algorithm. Both spanning-tree algorithms are correct on the same connected undirected graphs, including graphs with negative weights.

| Problem | Restriction that makes it correct | Algorithm | Bound claimed in this lecture |
| --- | --- | --- | --- |
| Single-source distances, every weight equal to $1$ | unweighted | BFS, Lecture 12 | $\Theta(n + m)$ |
| Single-source distances | every weight nonnegative | Dijkstra, indexed binary heap | $O((n + m) \log n)$ |
| Single-source distances, or a report that none exist | directed edges, negative weights allowed | Bellman–Ford | $\Theta(nm)$ |
| Single-source distances | the digraph is acyclic; negative weights allowed | one pass in topological order | $\Theta(n + m)$ |
| Minimum spanning tree, edges given as a list | undirected and connected; negative weights allowed | Kruskal | $O(m \log n)$, of which the disjoint-set term is $O(m \, \alpha(n))$ |
| Minimum spanning tree, grown from a vertex | undirected and connected; adjacency lists | Prim, indexed binary heap | $O((n + m) \log n)$ |

Dijkstra's algorithm on a Fibonacci heap is $\Theta(m + n \log n)$ amortized. That row is not an algorithm of this course.

A practical tie between Prim and Kruskal, when both are correct, is the representation you already have. Kruskal wants a list it can sort. Prim wants adjacency lists and a source. On a sparse graph both bounds are a logarithmic factor times $m$. On a dense graph, the $\Theta(n^2)$ scan version of Prim, mentioned in Section 8.4 and not implemented here, beats a binary heap.

Wrong pairs, stated so the table is usable under pressure:

- A negative edge disqualifies Dijkstra's algorithm and does not disqualify Prim, Kruskal, Bellman–Ford, or the DAG method.
- A directed cycle disqualifies the DAG method even when every weight is positive. Use Dijkstra or Bellman–Ford according to the signs.
- An undirected negative edge disqualifies the trick of replacing it by two arcs and running a shortest-path algorithm. It does not disqualify an MST algorithm.
- All-pairs algorithms and maximum flow answer different questions.

---

## LABORATORY

### Guided traces

Reproduce each trace with the next row covered. The final checkpoints below are the values the program asserts. They are the same numbers as in the body.

1. **Indexed heap.** Insert $x$ at $4$, $y$ at $1$, $z$ at $3$. Extract-min returns $y$. Decrease $x$ from $4$ to $0$. Extract-min returns $x$, then $z$.
2. **Dijkstra.** On the graph of Section 3.7, the extraction order is $s, a, c, b, t$. The final labels are $d(s)=0$, $d(a)=2$, $d(b)=4$, $d(c)=3$, $d(t)=5$, $d(z)=\infty$. The path to $t$ is $s, a, c, b, t$.
3. **The negative counterexample.** On $s \to a$ of weight $2$, $s \to b$ of weight $3$, and $b \to a$ of weight $-2$, Dijkstra settles $d[a] = 2$. Bellman–Ford reports $d[a] = 1$ and does not report a cycle. The two labels differ.
4. **Bellman–Ford, no cycle.** On the edge order of Section 4.5, the label rows after passes $0, 1, 2, 3$ are $(0, \infty, \infty, \infty)$, $(0, 4, \infty, 10)$, $(0, 4, 2, 10)$, and $(0, 4, 2, 5)$ for $(s, a, b, c)$. The extra pass is silent. The path to $c$ is $s, a, b, c$.
5. **Bellman–Ford, cycle.** On the edge order of Section 4.6, the rows after passes $0, 1, 2$ are $(0, \infty, \infty)$, $(0, -1, 3)$, and $(0, -3, 1)$ for $(s, a, b)$. The extra pass relaxes $a \to b$ because $-3 + 2 = -1 < 1$. The witness contains the cycle through $a$ and $b$ of weight $-2$.
6. **DAG.** The topological order is $s, a, b, c, t$. The labels are $0, 3, 1, 2, 4$. The path to $t$ is $s, a, b, c, t$.
7. **Kruskal and Prim.** Both return the edge set $\{a\text{—}b,\ b\text{—}c,\ c\text{—}d\}$ of total weight $6$. Prim's extraction order from $a$ is $a, b, c, d$. After Kruskal's unions, the parent of $b$, of $c$, and of $d$ is $a$, and the rank of $a$ is $1$.
8. **Compression.** After the four unions of Section 9.6, $\mathrm{parent}[e] = d$ and the height is $2$. After `find(e)` and `find(c)`, $\mathrm{parent}[e] = \mathrm{parent}[c] = a$, the rank of $a$ is still $2$, and the height is $1$. The same unions with compression disabled leave $\mathrm{parent}[e] = d$ and height $2$.
9. **Tight height.** The eight-element link sequence of Section 9.3 produces height $3$ with compression disabled.

### Problems

Solve these before you read the program and before you read the answer key. Solutions are at the end of the answer key.

**L1.** An edge $u \to v$ has weight $1$, $d[u] = 4$, and $d[v] = 4$. Perform the relaxation. Then change the weight to $-1$ and relax again from the original labels $d[u] = 4$, $d[v] = 4$. For each attempt, give $d[v]$, $\pi[v]$, and the walk whose weight is stored if the label changes.

**L2.** Run Dijkstra's algorithm from $s$ on the nonnegative digraph with edges $s \to a$ of weight $5$, $s \to b$ of weight $1$, and $b \to a$ of weight $2$. Give the extraction order, the final labels, and the path to $a$.

**L3.** Vertices $p, q$, edges in the order $p \to q$ of weight $2$ and $q \to p$ of weight $-3$. The source is $p$. Run the Bellman–Ford schedule, including the extra pass. State the labels after the main pass and the comparison that detects a cycle. Give the cycle weight.

**L4.** The cut puts $a$ alone on one side. The edges incident to $a$ are $a$—$b$ of weight $5$, $a$—$c$ of weight $1$, and $a$—$d$ of weight $4$. The set $A$ is empty. Name the light edge and say why the cut property applies to $A$.

**L5.** With union by rank, no compression, and the equal-rank rule of this lecture, execute `union(x, y)` and then `union(y, z)`, starting from singletons. Give the parent and the rank of each element, and the height of the tree.

## LABORATORY PROGRAM

The program is the runnable form of the indexed heap, Dijkstra's algorithm, the Bellman–Ford algorithm, DAG shortest paths, Kruskal's algorithm, Prim's algorithm, and both disjoint-set forests. It imports only `node:assert/strict`. Run it with Node.js. On success it prints `ALL TESTS PASSED`.

```javascript
import assert from "node:assert/strict";

class IndexedMinHeap {
  constructor() {
    this.nodes = [];
    this.pos = new Map();
    this.key = new Map();
  }

  get size() {
    return this.nodes.length;
  }

  isEmpty() {
    return this.nodes.length === 0;
  }

  has(v) {
    return this.pos.has(v);
  }

  getKey(v) {
    return this.key.get(v);
  }

  insert(v, k) {
    if (this.pos.has(v)) {
      throw new Error(`duplicate insert: ${String(v)}`);
    }
    this.nodes.push(v);
    this.pos.set(v, this.nodes.length - 1);
    this.key.set(v, k);
    this.siftUp(this.nodes.length - 1);
    this.check();
  }

  decreaseKey(v, k) {
    if (!this.pos.has(v)) {
      throw new Error(`decrease-key on absent vertex: ${String(v)}`);
    }
    const old = this.key.get(v);
    if (k > old) {
      throw new Error("decrease-key received a larger key");
    }
    if (k === old) {
      return;
    }
    this.key.set(v, k);
    this.siftUp(this.pos.get(v));
    this.check();
  }

  extractMin() {
    if (this.nodes.length === 0) {
      throw new Error("extract-min on an empty heap");
    }
    const top = this.nodes[0];
    const last = this.nodes.pop();
    this.pos.delete(top);
    this.key.delete(top);
    if (this.nodes.length > 0 && last !== top) {
      this.nodes[0] = last;
      this.pos.set(last, 0);
      this.siftDown(0);
    }
    this.check();
    return top;
  }

  less(i, j) {
    const ki = this.key.get(this.nodes[i]);
    const kj = this.key.get(this.nodes[j]);
    if (ki < kj) return true;
    if (ki > kj) return false;
    return String(this.nodes[i]) < String(this.nodes[j]);
  }

  siftUp(i) {
    while (i > 0) {
      const parent = Math.floor((i - 1) / 2);
      if (!this.less(i, parent)) break;
      this.swap(i, parent);
      i = parent;
    }
  }

  siftDown(i) {
    const n = this.nodes.length;
    while (true) {
      let best = i;
      const left = 2 * i + 1;
      const right = 2 * i + 2;
      if (left < n && this.less(left, best)) best = left;
      if (right < n && this.less(right, best)) best = right;
      if (best === i) break;
      this.swap(i, best);
      i = best;
    }
  }

  swap(i, j) {
    const a = this.nodes[i];
    const b = this.nodes[j];
    this.nodes[i] = b;
    this.nodes[j] = a;
    this.pos.set(a, j);
    this.pos.set(b, i);
  }

  check() {
    for (let i = 0; i < this.nodes.length; i++) {
      if (this.pos.get(this.nodes[i]) !== i) {
        throw new Error("position map does not match the heap array");
      }
    }
    if (this.pos.size !== this.nodes.length || this.key.size !== this.nodes.length) {
      throw new Error("heap maps have the wrong size");
    }
  }
}

class WeightedDigraph {
  constructor(vertices) {
    this.vertices = vertices.slice();
    this.adj = new Map();
    for (const v of vertices) this.adj.set(v, []);
  }

  addEdge(u, v, w) {
    this.adj.get(u).push({ to: v, w });
  }

  addUndirected(u, v, w) {
    this.addEdge(u, v, w);
    this.addEdge(v, u, w);
  }
}

function pathTo(parent, source, target) {
  const path = [];
  let v = target;
  const seen = new Set();
  while (v !== null && v !== undefined) {
    if (seen.has(v)) throw new Error("parent cycle during path reconstruction");
    seen.add(v);
    path.push(v);
    if (v === source) break;
    v = parent.get(v);
  }
  path.reverse();
  return path;
}

function dijkstra(graph, source) {
  const dist = new Map();
  const parent = new Map();
  for (const v of graph.vertices) {
    dist.set(v, Infinity);
    parent.set(v, null);
  }
  dist.set(source, 0);
  const heap = new IndexedMinHeap();
  heap.insert(source, 0);
  const settled = new Set();
  const order = [];

  while (!heap.isEmpty()) {
    const u = heap.extractMin();
    settled.add(u);
    order.push(u);
    for (const edge of graph.adj.get(u)) {
      if (settled.has(edge.to)) continue;
      const cand = dist.get(u) + edge.w;
      if (cand < dist.get(edge.to)) {
        dist.set(edge.to, cand);
        parent.set(edge.to, u);
        if (heap.has(edge.to)) heap.decreaseKey(edge.to, cand);
        else heap.insert(edge.to, cand);
      }
    }
  }
  return { dist, parent, order };
}

function snapshot(dist, vertices) {
  return vertices.map((v) => dist.get(v));
}

function bellmanFord(vertices, edges, source) {
  const dist = new Map();
  const parent = new Map();
  const witness = new Map();
  for (const v of vertices) {
    dist.set(v, Infinity);
    parent.set(v, null);
  }
  dist.set(source, 0);
  witness.set(source, { name: source, w: 0, pred: null });
  const history = [snapshot(dist, vertices)];
  const n = vertices.length;

  for (let pass = 1; pass <= n - 1; pass++) {
    for (const e of edges) {
      const du = dist.get(e.u);
      if (du === Infinity) continue;
      const cand = du + e.w;
      if (cand < dist.get(e.v)) {
        dist.set(e.v, cand);
        parent.set(e.v, e.u);
        witness.set(e.v, { name: e.v, w: e.w, pred: witness.get(e.u) });
      }
    }
    history.push(snapshot(dist, vertices));
  }

  let detected = null;
  for (const e of edges) {
    const du = dist.get(e.u);
    if (du === Infinity) continue;
    if (du + e.w < dist.get(e.v)) {
      detected = e;
      break;
    }
  }

  let cycle = null;
  if (detected !== null) {
    const extended = {
      name: detected.v,
      w: detected.w,
      pred: witness.get(detected.u),
    };
    cycle = findNegativeCycle(extended);
  }

  return {
    dist,
    parent,
    history,
    hasNegativeCycle: detected !== null,
    detected,
    cycle,
  };
}

function findNegativeCycle(tail) {
  const walk = [];
  let node = tail;
  while (node !== null) {
    walk.push(node);
    node = node.pred;
  }
  walk.reverse();
  const positions = new Map();
  for (let i = 0; i < walk.length; i++) {
    const name = walk[i].name;
    if (!positions.has(name)) positions.set(name, []);
    positions.get(name).push(i);
  }
  for (const idxs of positions.values()) {
    if (idxs.length < 2) continue;
    for (let k = 0; k < idxs.length - 1; k++) {
      const start = idxs[k];
      const end = idxs[k + 1];
      let weight = 0;
      const cycle = [];
      for (let j = start + 1; j <= end; j++) {
        weight += walk[j].w;
        cycle.push(walk[j].name);
      }
      if (weight < 0) return { weight, cycle };
    }
  }
  return null;
}

function topoOrder(graph) {
  const indeg = new Map();
  for (const v of graph.vertices) indeg.set(v, 0);
  for (const u of graph.vertices) {
    for (const e of graph.adj.get(u)) indeg.set(e.to, indeg.get(e.to) + 1);
  }
  const queue = [];
  for (const v of graph.vertices) {
    if (indeg.get(v) === 0) queue.push(v);
  }
  const order = [];
  while (queue.length > 0) {
    const u = queue.shift();
    order.push(u);
    for (const e of graph.adj.get(u)) {
      indeg.set(e.to, indeg.get(e.to) - 1);
      if (indeg.get(e.to) === 0) queue.push(e.to);
    }
  }
  if (order.length !== graph.vertices.length) {
    throw new Error("topological order requires a DAG");
  }
  return order;
}

function dagShortestPaths(graph, source) {
  const order = topoOrder(graph);
  const dist = new Map();
  const parent = new Map();
  for (const v of graph.vertices) {
    dist.set(v, Infinity);
    parent.set(v, null);
  }
  dist.set(source, 0);
  for (const u of order) {
    if (dist.get(u) === Infinity) continue;
    for (const e of graph.adj.get(u)) {
      const cand = dist.get(u) + e.w;
      if (cand < dist.get(e.to)) {
        dist.set(e.to, cand);
        parent.set(e.to, u);
      }
    }
  }
  return { dist, parent, order };
}

class UnionFind {
  constructor(compress) {
    this.compress = compress;
    this.parent = new Map();
    this.rank = new Map();
  }

  makeSet(x) {
    if (this.parent.has(x)) throw new Error(`duplicate make-set: ${String(x)}`);
    this.parent.set(x, x);
    this.rank.set(x, 0);
  }

  find(x) {
    if (this.compress) {
      const p = this.parent.get(x);
      if (p !== x) {
        const root = this.find(p);
        this.parent.set(x, root);
        return root;
      }
      return x;
    }
    let v = x;
    while (this.parent.get(v) !== v) v = this.parent.get(v);
    return v;
  }

  link(x, y) {
    if (this.rank.get(x) < this.rank.get(y)) {
      const t = x;
      x = y;
      y = t;
    }
    this.parent.set(y, x);
    if (this.rank.get(x) === this.rank.get(y)) {
      this.rank.set(x, this.rank.get(x) + 1);
    }
  }

  union(a, b) {
    const x = this.find(a);
    const y = this.find(b);
    if (x === y) return false;
    this.link(x, y);
    return true;
  }
}

function forestHeight(uf) {
  const nodes = [...uf.parent.keys()];
  const children = new Map(nodes.map((v) => [v, []]));
  for (const v of nodes) {
    const p = uf.parent.get(v);
    if (p !== v) children.get(p).push(v);
  }
  const heightOf = (v) => {
    const kids = children.get(v);
    if (kids.length === 0) return 0;
    let max = 0;
    for (const k of kids) max = Math.max(max, heightOf(k));
    return max + 1;
  };
  let max = 0;
  for (const v of nodes) {
    if (uf.parent.get(v) === v) max = Math.max(max, heightOf(v));
  }
  return max;
}

function kruskal(vertices, edges) {
  const sorted = edges.slice().sort((a, b) => a.w - b.w || a.u.localeCompare(b.u) || a.v.localeCompare(b.v));
  const uf = new UnionFind(true);
  for (const v of vertices) uf.makeSet(v);
  const mst = [];
  const steps = [];
  for (const e of sorted) {
    const same = uf.find(e.u) === uf.find(e.v);
    if (!same) {
      uf.union(e.u, e.v);
      mst.push(e);
    }
    steps.push({
      u: e.u,
      v: e.v,
      w: e.w,
      added: !same,
      rootU: uf.find(e.u),
      rootV: uf.find(e.v),
    });
  }
  return { mst, uf, steps };
}

function prim(graph, source) {
  const key = new Map();
  const parent = new Map();
  const inTree = new Set();
  for (const v of graph.vertices) {
    key.set(v, Infinity);
    parent.set(v, null);
  }
  key.set(source, 0);
  const heap = new IndexedMinHeap();
  heap.insert(source, 0);
  const edges = [];
  const order = [];

  while (!heap.isEmpty()) {
    const u = heap.extractMin();
    inTree.add(u);
    order.push(u);
    if (parent.get(u) !== null) {
      edges.push({ u: parent.get(u), v: u, w: key.get(u) });
    }
    for (const e of graph.adj.get(u)) {
      if (inTree.has(e.to)) continue;
      if (e.w < key.get(e.to)) {
        key.set(e.to, e.w);
        parent.set(e.to, u);
        if (heap.has(e.to)) heap.decreaseKey(e.to, e.w);
        else heap.insert(e.to, e.w);
      }
    }
  }
  return { edges, parent, key, order };
}

function canon(e) {
  const a = String(e.u);
  const b = String(e.v);
  return a < b ? `${a}-${b}:${e.w}` : `${b}-${a}:${e.w}`;
}

function edgeSet(edges) {
  return edges.map(canon).sort();
}

// Position-map trace: insert x:4, y:1, z:3; extract y; decrease x to 0; extract x; extract z.
{
  const heap = new IndexedMinHeap();
  heap.insert("x", 4);
  heap.insert("y", 1);
  heap.insert("z", 3);
  assert.equal(heap.extractMin(), "y");
  heap.decreaseKey("x", 0);
  assert.equal(heap.extractMin(), "x");
  assert.equal(heap.extractMin(), "z");
  assert.equal(heap.isEmpty(), true);
}

// Dijkstra on the nonnegative trace, plus an unreachable vertex z.
{
  const g = new WeightedDigraph(["s", "a", "b", "c", "t", "z"]);
  g.addEdge("s", "a", 2);
  g.addEdge("s", "b", 6);
  g.addEdge("a", "b", 3);
  g.addEdge("a", "c", 1);
  g.addEdge("b", "t", 1);
  g.addEdge("c", "b", 1);
  g.addEdge("c", "t", 7);
  const result = dijkstra(g, "s");
  assert.deepEqual(result.order, ["s", "a", "c", "b", "t"]);
  assert.deepEqual(snapshot(result.dist, ["s", "a", "b", "c", "t", "z"]), [0, 2, 4, 3, 5, Infinity]);
  assert.equal(result.parent.get("a"), "s");
  assert.equal(result.parent.get("c"), "a");
  assert.equal(result.parent.get("b"), "c");
  assert.equal(result.parent.get("t"), "b");
  assert.equal(result.parent.get("z"), null);
  assert.deepEqual(pathTo(result.parent, "s", "t"), ["s", "a", "c", "b", "t"]);
}

// Negative-edge counterexample: Dijkstra settles a at 2; the true distance is 1.
{
  const g = new WeightedDigraph(["s", "a", "b"]);
  g.addEdge("s", "a", 2);
  g.addEdge("s", "b", 3);
  g.addEdge("b", "a", -2);
  const wrong = dijkstra(g, "s");
  assert.equal(wrong.dist.get("a"), 2);
  assert.equal(wrong.dist.get("b"), 3);
  assert.deepEqual(wrong.order, ["s", "a", "b"]);
  const truth = bellmanFord(
    ["s", "a", "b"],
    [
      { u: "s", v: "a", w: 2 },
      { u: "s", v: "b", w: 3 },
      { u: "b", v: "a", w: -2 },
    ],
    "s",
  );
  assert.equal(truth.hasNegativeCycle, false);
  assert.equal(truth.dist.get("a"), 1);
  assert.equal(truth.dist.get("b"), 3);
  assert.notEqual(wrong.dist.get("a"), truth.dist.get("a"));
  assert.deepEqual(pathTo(truth.parent, "s", "a"), ["s", "b", "a"]);
}

// Bellman-Ford, negative edge, no negative cycle. Edge order delays the 3-edge path.
{
  const vertices = ["s", "a", "b", "c"];
  const edges = [
    { u: "b", v: "c", w: 3 },
    { u: "a", v: "b", w: -2 },
    { u: "a", v: "c", w: 8 },
    { u: "s", v: "c", w: 10 },
    { u: "s", v: "a", w: 4 },
  ];
  const result = bellmanFord(vertices, edges, "s");
  assert.equal(result.hasNegativeCycle, false);
  assert.equal(result.cycle, null);
  assert.deepEqual(result.history, [
    [0, Infinity, Infinity, Infinity],
    [0, 4, Infinity, 10],
    [0, 4, 2, 10],
    [0, 4, 2, 5],
  ]);
  assert.equal(result.parent.get("a"), "s");
  assert.equal(result.parent.get("b"), "a");
  assert.equal(result.parent.get("c"), "b");
  assert.deepEqual(pathTo(result.parent, "s", "c"), ["s", "a", "b", "c"]);
}

// Bellman-Ford negative cycle reachable from the source.
{
  const vertices = ["s", "a", "b"];
  const edges = [
    { u: "s", v: "a", w: 1 },
    { u: "a", v: "b", w: 2 },
    { u: "b", v: "a", w: -4 },
  ];
  const result = bellmanFord(vertices, edges, "s");
  assert.deepEqual(result.history, [
    [0, Infinity, Infinity],
    [0, -1, 3],
    [0, -3, 1],
  ]);
  assert.equal(result.hasNegativeCycle, true);
  assert.equal(result.detected.u, "a");
  assert.equal(result.detected.v, "b");
  assert.equal(result.cycle.weight, -2);
  assert.deepEqual(result.cycle.cycle.slice().sort(), ["a", "b"]);
}

// Unreachable vertex is not a negative cycle.
{
  const result = bellmanFord(["s", "r"], [], "s");
  assert.equal(result.dist.get("r"), Infinity);
  assert.equal(result.hasNegativeCycle, false);
}

// DAG shortest paths, including one negative edge.
{
  const g = new WeightedDigraph(["s", "a", "b", "c", "t"]);
  g.addEdge("s", "a", 3);
  g.addEdge("s", "b", 6);
  g.addEdge("a", "b", -2);
  g.addEdge("a", "c", 4);
  g.addEdge("b", "c", 1);
  g.addEdge("b", "t", 5);
  g.addEdge("c", "t", 2);
  const result = dagShortestPaths(g, "s");
  assert.deepEqual(result.order, ["s", "a", "b", "c", "t"]);
  assert.deepEqual(snapshot(result.dist, ["s", "a", "b", "c", "t"]), [0, 3, 1, 2, 4]);
  assert.equal(result.parent.get("a"), "s");
  assert.equal(result.parent.get("b"), "a");
  assert.equal(result.parent.get("c"), "b");
  assert.equal(result.parent.get("t"), "c");
  assert.deepEqual(pathTo(result.parent, "s", "t"), ["s", "a", "b", "c", "t"]);
}

// Kruskal and Prim on the same undirected graph.
{
  const vertices = ["a", "b", "c", "d"];
  const edges = [
    { u: "a", v: "b", w: 1 },
    { u: "b", v: "c", w: 2 },
    { u: "c", v: "d", w: 3 },
    { u: "a", v: "c", w: 4 },
    { u: "a", v: "d", w: 7 },
    { u: "b", v: "d", w: 8 },
  ];
  const k = kruskal(vertices, edges);
  assert.deepEqual(
    k.steps.map((s) => [s.u, s.v, s.w, s.added]),
    [
      ["a", "b", 1, true],
      ["b", "c", 2, true],
      ["c", "d", 3, true],
      ["a", "c", 4, false],
      ["a", "d", 7, false],
      ["b", "d", 8, false],
    ],
  );
  assert.equal(k.uf.find("a"), k.uf.find("b"));
  assert.equal(k.uf.find("a"), k.uf.find("c"));
  assert.equal(k.uf.find("a"), k.uf.find("d"));
  assert.equal(k.uf.rank.get("a"), 1);
  assert.equal(k.uf.parent.get("b"), "a");
  assert.equal(k.uf.parent.get("c"), "a");
  assert.equal(k.uf.parent.get("d"), "a");

  const g = new WeightedDigraph(vertices);
  for (const e of edges) g.addUndirected(e.u, e.v, e.w);
  const p = prim(g, "a");
  assert.deepEqual(p.order, ["a", "b", "c", "d"]);
  assert.deepEqual(edgeSet(k.mst), edgeSet(p.edges));
  assert.deepEqual(edgeSet(k.mst), ["a-b:1", "b-c:2", "c-d:3"]);
  const weight = k.mst.reduce((sum, e) => sum + e.w, 0);
  assert.equal(weight, 6);
}

// A negative undirected edge is a legal MST edge.
{
  const k = kruskal(["a", "b"], [{ u: "a", v: "b", w: -5 }]);
  assert.deepEqual(edgeSet(k.mst), ["a-b:-5"]);
  const g = new WeightedDigraph(["a", "b"]);
  g.addUndirected("a", "b", -5);
  const p = prim(g, "a");
  assert.deepEqual(edgeSet(p.edges), ["a-b:-5"]);
}

// Minimum spanning forest: c stays apart.
{
  const k = kruskal(
    ["a", "b", "c"],
    [{ u: "a", v: "b", w: 5 }],
  );
  assert.deepEqual(edgeSet(k.mst), ["a-b:5"]);
  assert.equal(k.uf.find("a"), k.uf.find("b"));
  assert.notEqual(k.uf.find("a"), k.uf.find("c"));
}

// Path compression changes parents and can make height strictly smaller than rank.
{
  const uf = new UnionFind(true);
  for (const v of ["a", "b", "c", "d", "e"]) uf.makeSet(v);
  uf.union("d", "e");
  uf.union("c", "d");
  uf.union("a", "b");
  uf.union("a", "d");
  assert.equal(uf.parent.get("e"), "d");
  assert.equal(uf.parent.get("c"), "d");
  assert.equal(uf.parent.get("d"), "a");
  assert.equal(uf.rank.get("a"), 2);
  assert.equal(forestHeight(uf), 2);
  assert.equal(uf.find("e"), "a");
  assert.equal(uf.parent.get("e"), "a");
  assert.equal(forestHeight(uf), 2);
  assert.equal(uf.find("c"), "a");
  assert.equal(uf.parent.get("c"), "a");
  assert.equal(uf.rank.get("a"), 2);
  assert.equal(forestHeight(uf), 1);
}

// The same links without compression keep height equal to rank.
{
  const uf = new UnionFind(false);
  for (const v of ["a", "b", "c", "d", "e"]) uf.makeSet(v);
  uf.union("d", "e");
  uf.union("c", "d");
  uf.union("a", "b");
  uf.union("a", "d");
  assert.equal(uf.find("e"), "a");
  assert.equal(uf.parent.get("e"), "d");
  assert.equal(uf.find("c"), "a");
  assert.equal(uf.parent.get("c"), "d");
  assert.equal(uf.rank.get("a"), 2);
  assert.equal(forestHeight(uf), 2);
}

// Union by rank with no compression meets the height bound with equality on 8 nodes.
{
  const uf = new UnionFind(false);
  for (let i = 1; i <= 8; i++) uf.makeSet(i);
  uf.union(1, 2);
  uf.union(3, 4);
  uf.union(5, 6);
  uf.union(7, 8);
  uf.union(1, 3);
  uf.union(5, 7);
  uf.union(1, 5);
  assert.equal(uf.rank.get(uf.find(1)), 3);
  assert.equal(forestHeight(uf), 3);
  assert.equal(forestHeight(uf), Math.floor(Math.log2(8)));
}

console.log("ALL TESTS PASSED");
```

---

## Common mistakes

**Wrong idea.** Dijkstra's algorithm may be run on a negative edge, and the first time a vertex is extracted its label is still final.
**Correction.** Theorem 7 needs every suffix weight on a shortest path to be nonnegative. Section 3.6 settles $d[a] = 2$ when $\delta(s, a) = 1$. The laboratory asserts those two numbers side by side.

**Wrong idea.** A finite label $d[v]$ might be smaller than every walk from $s$ to $v$, and the algorithm will repair it later.
**Correction.** Theorem 5 says a finite label is the weight of a walk that the witness (or the predecessor chain, once it is simple) can name. Later passes find lighter walks. They do not repair a number that was never a walk.

**Wrong idea.** Bellman–Ford is finished after $n$ passes of the main loop, or after $n - 2$.
**Correction.** The optimality argument uses a simple path of at most $n - 1$ edges, so the main schedule is $n - 1$ passes. Pass $n$ is the detection pass. It is not one of the passes that Theorem 9 counts.

**Wrong idea.** Any negative cycle in the graph, including one the source cannot reach, makes the extra pass report a cycle.
**Correction.** An edge is relaxed only from a finite label, and a finite label is a walk from $s$. The sum in Theorem 10 is over a cycle reachable from $s$. The one-edge-free digraph on $\{s, r\}$ in Section 4.5 stays quiet.

**Wrong idea.** On a DAG, a negative edge forces a switch to Bellman–Ford.
**Correction.** A DAG has no cycle, so it has no negative cycle. One topological pass is correct and runs in $\Theta(n + m)$ time. Section 5.3 uses the edge of weight $-2$.

**Wrong idea.** The cut property applies to any light edge across any cut, whether or not the edges already chosen cross that cut.
**Correction.** The cut has to respect $A$. The exchange deletes a crossing edge. If an edge of $A$ crossed the cut, the exchange could delete it, and $A \cup \{e\}$ would no longer sit inside the new tree.

**Wrong idea.** The heaviest edge on a cycle is never in an MST, even when another edge on the cycle has the same weight.
**Correction.** Theorem 16 needs a unique heaviest edge. A tie allows the exchange to preserve the total weight, so one MST can avoid the edge and another can contain it.

**Wrong idea.** A negative undirected edge cannot belong to an MST, or it should be replaced by two directed arcs before Prim or Kruskal runs.
**Correction.** An MST selects each edge at most once. The one-edge graph of weight $-5$ has that edge as its MST. Two arcs of weight $-5$ form a negative directed cycle and are a shortest-path input, not a spanning-tree input.

**Wrong idea.** Rank remains equal to height after path compression, because rank is updated to follow the tree.
**Correction.** Compression does not write ranks. Section 9.6 ends at height $1$ with rank $2$. Without compression, Lemma 19 says height equals rank. The size bound $2^{\mathrm{rank}}$ also needs the absence of compression, because compression moves nodes out of subtrees.

**Wrong idea.** Pushing a new heap entry on every relaxation still costs $O((n + m) \log n)$, because each entry is a vertex.
**Correction.** Duplicate entries are not vertices. The heap can hold $\Theta(m)$ pairs, and the bound is $O(m \log m)$. The indexed heap, which stores each vertex once, is the implementation whose bound is $O((n + m) \log n)$.

**Wrong idea.** The predecessor $\pi[v]$ points to the next vertex on the path from the source toward $v$.
**Correction.** $\pi[v]$ is the previous vertex, the tail of the last edge that wrote $d[v]$. Reconstruction walks from the target back to the source and then reverses the list.

---

## Examination

The lecture is closed. Ninety minutes is the right length if the traces are written in full and the proofs are written in sentences. Numerical answers use the definitions from the body. There is no partial credit procedure here: write the arithmetic.

### Question 1

Define each term as this lecture uses it.

(a) The weight of a walk.
(b) The shortest-path weight $\delta(s, v)$, including the unreachable case and the negative-cycle case.
(c) Relaxation of an edge $u \to v$.
(d) A cut, a light edge across that cut, and a safe edge for a set $A$.
(e) The rank of a node in a disjoint-set forest: what it equals if path compression is never used, and what remains true of it after path compression.

### Question 2

A walk of weight $7$ from $s$ to $p$ is stored as $d[p] = 7$. Also $d[q] = 12$ and $\pi[q] = s$. The edge $p \to q$ has weight $4$.

(a) Relax $p \to q$. Give the new $d[q]$ and the new $\pi[q]$.
(b) Name a walk from $s$ to $q$ whose weight equals the new $d[q]$.
(c) Suppose instead that the edge weight is $6$, and the labels start again from $d[p] = 7$ and $d[q] = 12$. What does relaxation do, and which fact about walk weights justifies leaving $d[q]$ unchanged?

### Question 3

Run Dijkstra's algorithm from $s$ on the digraph with vertices $s, a, b, c$ and nonnegative edges

```text
s → a    2
s → b    8
a → b    3
a → c    5
b → c    1
```

(a) Give the labels of $s, a, b, c$ after each extraction, and the extraction order.
(b) Give the final predecessors and the path from $s$ to $c$, including its weight as a sum.
(c) In the proof that an extracted label is final, which inequality uses the hypothesis that every weight is nonnegative?
(d) On the digraph with edges $s \to a$ of weight $2$, $s \to b$ of weight $3$, and $b \to a$ of weight $-2$, Dijkstra extracts $a$ before $b$. Give the label it settles for $a$, the true distance $\delta(s, a)$, the first unsettled vertex $y$ on the true shortest path at the moment $a$ is extracted, and the weight of the suffix from $y$ to $a$.

### Question 4

Vertices $s, x, y$. The Bellman–Ford edge order is

```text
s → x    6
x → y    2
y → x   -5
```

The source is $s$.

(a) Give $d(s), d(x), d(y)$ after each of the $n - 1$ main passes.
(b) On the extra pass, give the first comparison that reports a negative cycle. Write both sides of the inequality.
(c) Name the cycle and compute its weight.

### Question 5

An undirected graph has vertices $\{1, 2, 3, 4\}$ and distinct edge weights

```text
1—2    4
1—3    2
2—3    5
2—4    1
3—4    3
```

Let $A = \{2\text{—}4\}$ and let $S = \{2, 4\}$.

(a) List every edge that crosses the cut $(S, V \setminus S)$, with its weight, and name the light edge.
(b) Explain why the cut respects $A$.
(c) Suppose $T$ is an MST that contains $A$ and does not contain the light edge. The exchange of Theorem 15 adds the light edge and deletes another edge. What property does the deleted edge have, and why is the weight of the new spanning tree at most the weight of $T$?

### Question 6

Kruskal's algorithm on vertices $a, b, c, d$, with edges stored in lexicographic endpoint order:

```text
a—b    1
a—c    2
b—c    3
c—d    4
a—d    9
```

Use union by rank and the equal-rank rule of this lecture: `union(u, v)` links the root of $v$ under the root of $u$ when the ranks are equal. Call `union` with the stored endpoint order.

(a) For each edge, say whether it is accepted or rejected.
(b) After each accepted edge, give the parent of every vertex and the rank of every root.
(c) When $c\text{—}d$ is accepted, take $S$ to be the component of $c$ just before the union. Name the light edge across $(S, V \setminus S)$ and its weight.
(d) Give the total weight of the tree.

### Question 7

For each problem, name the algorithm this course uses and the bound claimed for it. One sentence is enough for the weight restriction that makes the algorithm correct. If a second algorithm from the lecture is also correct, name it.

(a) Single-source distances in a digraph that may contain negative edges. The algorithm must also report when a negative cycle is reachable from the source.
(b) The same distances, and the digraph is promised to be acyclic. A negative edge may be present.
(c) Single-source distances, every weight nonnegative, adjacency lists, the priority queue of this course.
(d) Every weight equals $1$.
(e) A minimum spanning tree of a connected undirected graph. Weights may be negative. The input is an edge list.
(f) A minimum spanning tree grown from a designated vertex. The graph is connected and undirected, the weights are positive and distinct, and the input is an adjacency list.

### Question 8

Union by rank, no path compression, equal-rank rule of this lecture. The elements $1, 2, 3, 4, 5$ start as singletons. Execute

```text
union(1, 2)
union(3, 4)
union(1, 3)
union(1, 5)
```

(a) Draw the final forest by naming the parent of each element, and give the rank of the root.
(b) Give the height of that tree.
(c) Compute $\lfloor \log_2 5 \rfloor$ and explain, from the subtree-size fact, why the height cannot be $3$.

### Question 9

A digraph has $n = 1000$ vertices and $m = 5000$ edges. Every vertex is reachable from the source. Every weight is nonnegative.

(a) How many relaxation attempts does the main phase of the Bellman–Ford algorithm perform? The detection pass is not part of this count. Give the exact integer.
(b) Write the worst-case bound for Dijkstra's algorithm with an indexed binary heap on this input, with $1000$ and $5000$ substituted.
(c) The weights are nonnegative. Which of the two algorithms does this lecture select, and which of the two expressions grows more slowly as this shape of input grows ($m = 5n$)?

---

## Answer key

### Question 1

(a) The weight of a walk is the sum of the weights of its edges. The empty walk at a vertex has weight $0$.

(b) If no walk from $s$ to $v$ exists, $\delta(s, v) = \infty$. If walks exist and their weights have a finite minimum, $\delta(s, v)$ is that minimum, and some path achieves it whenever no negative cycle is reachable from $s$. If a negative cycle is reachable from $s$ and $v$ is reachable from that cycle, the walk weights are unbounded below, the minimum does not exist, and the extended value $-\infty$ records that fact.

(c) If $d[u]$ is finite and $d[u] + w(u, v) < d[v]$, set $d[v] = d[u] + w(u, v)$ and $\pi[v] = u$. Otherwise leave both arrays unchanged.

(d) A cut is a partition of the vertex set into two nonempty sets $S$ and $V \setminus S$. A light edge across the cut is a crossing edge of minimum weight. An edge $e \notin A$ is safe for $A$ when $A \cup \{e\}$ is still a subset of some MST.

(e) With union by rank and no path compression, the rank of a node equals the height of its subtree. After path compression, rank is unchanged and is still an upper bound on the height, and it need not equal the height. The inequality "subtree size at least $2^{\mathrm{rank}}$" is proved for the forest that does not compress.

### Question 2

(a) $7 + 4 = 11$, and $11 < 12$, so $d[q] = 11$ and $\pi[q] = p$.

(b) The walk of weight $7$ from $s$ to $p$, followed by the edge $p \to q$. Its weight is $7 + 4 = 11$.

(c) $7 + 6 = 13$, and $13 < 12$ is false, so $d[q]$ stays $12$ and $\pi[q]$ stays $s$. The candidate $13$ is the weight of a real walk. The label $12$ is the weight of a lighter walk already stored. The upper-bound invariant does not require the algorithm to replace a walk by a heavier one.

### Question 3

(a) Only $s$ starts in the heap, with label $0$.

| Extract | $d(s)$ | $d(a)$ | $d(b)$ | $d(c)$ |
| --- | --- | --- | --- | --- |
| $s$ | $0$ | $2$ | $8$ | $\infty$ |
| $a$ | $0$ | $2$ | $5$ | $7$ |
| $b$ | $0$ | $2$ | $5$ | $6$ |
| $c$ | $0$ | $2$ | $5$ | $6$ |

The order is $s, a, b, c$. The decrease of $b$ is $2 + 3 = 5$, which replaces $8$. The first label of $c$ is $2 + 5 = 7$. The decrease of $c$ is $5 + 1 = 6$, which replaces $7$.

(b) $\pi[a] = s$, $\pi[b] = a$, $\pi[c] = b$. The path is $s, a, b, c$, of weight $2 + 3 + 1 = 6$.

(c) If $y$ is the first unsettled vertex on a shortest path from $s$ to the vertex $u$ being extracted, the suffix from $y$ to $u$ has nonnegative weight, so $\delta(s, y) \le \delta(s, u)$. Every earlier step of that proof is optimal substructure or relaxation.

(d) The algorithm sets $d[a] = 2$ while extracting $s$, then extracts $a$ and settles $2$. The true distance is $\delta(s, a) = 3 + (-2) = 1$, by the walk $s, b, a$. At the moment $a$ is extracted, $S = \{s\}$, so on that walk the first unsettled vertex is $y = b$. The suffix $b \to a$ has weight $-2$.

### Question 4

$n = 3$, so there are two main passes.

(a) Initialization: $d(s) = 0$, $d(x) = \infty$, $d(y) = \infty$.

Pass 1. The edge $s \to x$ writes $d[x] = 6$. The edge $x \to y$ writes $d[y] = 6 + 2 = 8$. The edge $y \to x$ offers $8 + (-5) = 3$, and $3 < 6$, so $d[x] = 3$. After pass 1: $d(s) = 0$, $d(x) = 3$, $d(y) = 8$.

Pass 2. The edge $s \to x$ offers $6$, which does not beat $3$. The edge $x \to y$ offers $3 + 2 = 5$, and $5 < 8$, so $d[y] = 5$. The edge $y \to x$ offers $5 + (-5) = 0$, and $0 < 3$, so $d[x] = 0$. After pass 2: $d(s) = 0$, $d(x) = 0$, $d(y) = 5$.

(b) The extra pass first tries $s \to x$: $0 + 6 = 6$, and $6 < 0$ is false. It next tries $x \to y$: $0 + 2 = 2$, and $2 < 5$. That success reports the cycle.

(c) The cycle is $x \to y \to x$. Its weight is $2 + (-5) = -3$.

### Question 5

(a) The complement of $S$ is $\{1, 3\}$. Crossing edges: $1\text{—}2$ of weight $4$ (vertex $1$ is outside, vertex $2$ is inside), $2\text{—}3$ of weight $5$, and $3\text{—}4$ of weight $3$. The edge $1\text{—}3$ has both ends outside. The edge $2\text{—}4$ has both ends inside. The light edge is $3\text{—}4$, of weight $3$, because $3 < 4 < 5$.

(b) The only edge of $A$ is $2\text{—}4$, and both of its ends lie in $S$. No edge of $A$ crosses the cut.

(c) Adding the light edge $3\text{—}4$ to $T$ creates a cycle. That cycle must cross the cut again on some other edge $e'$. The edge $e'$ is not in $A$, because $A$ does not cross the cut, so deleting $e'$ leaves $A$ in the new edge set. Since $3\text{—}4$ is light, $w(3\text{—}4) \le w(e')$. The new spanning tree $T - \{e'\} \cup \{3\text{—}4\}$ therefore weighs at most $w(T)$.

### Question 6

(a) and (b), in order.

Accept $a\text{—}b$. `union(a, b)` sees equal ranks $0$. Then $\mathrm{parent}[b] = a$, $\mathrm{rank}[a] = 1$, and $c$ and $d$ remain roots of rank $0$.

Accept $a\text{—}c$. `union(a, c)` finds roots $a$ and $c$, with ranks $1$ and $0$. Then $\mathrm{parent}[c] = a$. The rank of $a$ stays $1$.

Reject $b\text{—}c$. Both ends have root $a$.

Accept $c\text{—}d$. `union(c, d)` finds roots $a$ and $d$, with ranks $1$ and $0$. Then $\mathrm{parent}[d] = a$. The rank of $a$ stays $1$.

Reject $a\text{—}d$. Both ends have root $a$.

Final parents: $a \mapsto a$, $b \mapsto a$, $c \mapsto a$, $d \mapsto a$. The only root is $a$, of rank $1$.

(c) Just before `union(c, d)`, the component of $c$ is $S = \{a, b, c\}$, and $V \setminus S = \{d\}$. The crossing edges in the input are $c\text{—}d$ of weight $4$ and $a\text{—}d$ of weight $9$. The light edge is $c\text{—}d$, of weight $4$.

(d) The accepted weights sum to $1 + 2 + 4 = 7$.

### Question 7

(a) Bellman–Ford, in $\Theta(nm)$ time. Negative edges are allowed, and the extra pass reports a negative cycle reachable from the source.

(b) One relaxation pass in topological order, in $\Theta(n + m)$ time. A DAG has no negative cycle, so a negative edge is allowed. Bellman–Ford is also correct and slower.

(c) Dijkstra's algorithm with an indexed binary heap, in $O((n + m) \log n)$ time. Every weight is nonnegative.

(d) Breadth-first search from Lecture 12, in $\Theta(n + m)$ time. Every weight equals $1$, so path weight equals hop count. Dijkstra's algorithm is also correct.

(e) Kruskal's algorithm, in $O(m \log n)$ time, of which the disjoint-set operations cost $O(m \, \alpha(n))$. Negative undirected weights are allowed. Prim's algorithm is also correct.

(f) Prim's algorithm with an indexed binary heap, in $O((n + m) \log n)$ time. The weights are positive, so they are a legal MST input, and the adjacency lists are the representation Prim scans. Kruskal's algorithm is also correct.

### Question 8

(a) `union(1, 2)` sets $\mathrm{parent}[2] = 1$ and $\mathrm{rank}[1] = 1$. `union(3, 4)` sets $\mathrm{parent}[4] = 3$ and $\mathrm{rank}[3] = 1$. `union(1, 3)` links two roots of rank $1$, so $\mathrm{parent}[3] = 1$ and $\mathrm{rank}[1] = 2$. `union(1, 5)` finds rank $0$ under rank $2$, so $\mathrm{parent}[5] = 1$ and the rank of $1$ stays $2$.

```text
        1     rank 2
      / | \
     2  3  5
        |
        4
```

Parents: $1 \mapsto 1$, $2 \mapsto 1$, $3 \mapsto 1$, $4 \mapsto 3$, $5 \mapsto 1$. The root rank is $2$.

(b) The longest downward path has two edges, for example $1, 3, 4$. The height is $2$, equal to the rank, which Lemma 19 requires because compression is off.

(c) $\lfloor \log_2 5 \rfloor = 2$, because $2^2 = 4 \le 5$ and $2^3 = 8 > 5$. A node of rank $3$ would have at least $2^3 = 8$ nodes in its subtree. Only $5$ elements exist, so no node has rank $3$. Without compression, height equals rank, so the height is not $3$.

### Question 9

(a) The main phase runs $n - 1 = 999$ passes and each pass examines $m = 5000$ edges. The product is $999 \times 5000 = 4{,}995{,}000$.

(b) $O((1000 + 5000) \log 1000) = O(6000 \log 1000)$.

(c) The lecture selects Dijkstra's algorithm, because every weight is nonnegative. Along the family $m = 5n$, Bellman–Ford's main phase examines $(n - 1)(5n) = \Theta(n^2)$ edges, while Dijkstra's bound is $O((n + 5n) \log n) = O(n \log n)$. The heap algorithm grows more slowly.

### Solutions to the laboratory problems

**L1.** With weight $1$, the candidate is $4 + 1 = 5$, and $5 < 4$ is false. The label $d[v]$ stays $4$, and $\pi[v]$ stays as it was. With weight $-1$, the candidate is $4 + (-1) = 3$, and $3 < 4$, so $d[v] = 3$ and $\pi[v] = u$. The stored walk is a walk of weight $4$ from the source to $u$, followed by $u \to v$.

**L2.** Extract $s$. Then $d[a] = 5$ and $d[b] = 1$. Extract $b$, because $1 < 5$. The edge $b \to a$ offers $1 + 2 = 3$, which replaces $5$. Extract $a$. The order is $s, b, a$. The labels are $d(s) = 0$, $d(b) = 1$, $d(a) = 3$. The path to $a$ is $s, b, a$, of weight $1 + 2 = 3$.

**L3.** Here $n = 2$, so the main schedule is one pass. Initialization: $d[p] = 0$, $d[q] = \infty$. The edge $p \to q$ writes $d[q] = 2$. The edge $q \to p$ offers $2 + (-3) = -1$, and $-1 < 0$, so $d[p] = -1$ and $\pi[p] = q$. After the main pass, $d(p) = -1$ and $d(q) = 2$. The extra pass tries $p \to q$: $-1 + 2 = 1$, and $1 < 2$. That comparison reports a cycle. The cycle is $p \to q \to p$, of weight $2 + (-3) = -1$.

**L4.** The crossing edges are $a\text{—}b$ of weight $5$, $a\text{—}c$ of weight $1$, and $a\text{—}d$ of weight $4$. The light edge is $a\text{—}c$. The set $A$ is empty, so it contributes no crossing edge: the cut respects $A$. The empty set is a subset of every MST, so the cut property says $a\text{—}c$ is safe for $A$.

**L5.** `union(x, y)` sets $\mathrm{parent}[y] = x$ and $\mathrm{rank}[x] = 1$. `union(y, z)` finds the root $x$ and the root $z$. Rank $1$ outranks rank $0$, so $\mathrm{parent}[z] = x$ and $\mathrm{rank}[x]$ stays $1$. Parents: $x \mapsto x$, $y \mapsto x$, $z \mapsto x$. Ranks: $x$ has rank $1$, and $y$ and $z$ have rank $0$. The height is $1$.

---

## Independent assignment

Budget four to six hours. The artifact is one JavaScript program, `lecture-13-studio.js`, with a comment at the top of about half a page. No libraries, no filesystem, no network, and no `process.argv`. A fixed linear congruential generator is allowed if you want several graphs; do not call `Math.random`, so a second run checks the same graphs.

The program must contain all of the following, written again rather than imported from the laboratory file.

1. A directed path of $8$ vertices whose edges are listed from the far end back toward the source, each of weight $1$, plus no cycle. Run the Bellman–Ford schedule and record the pass on which the last vertex first becomes finite. The comment explains why that pass index equals the number of edges on the path when the edge list is reversed.
2. The negative-cycle graph of Examination Question 4, with an assertion that the extra pass reports a cycle of weight $-3$.
3. Three connected undirected graphs on at least six vertices, with distinct integer weights produced by your generator. On each graph, Prim and Kruskal return spanning trees of equal weight. Because the weights are distinct, the edge sets coincide as well. Assert both facts. Include one negative weight on the first graph and assert that the edge appears in the tree if it is the unique lightest edge incident to one of its ends, or explain in the comment, from the cut property, why it does not.
4. Union by rank with compression disabled, on $n = 32$ elements, using the doubling links of Section 9.3. Assert that the height equals $5$, which is $\lfloor \log_2 32 \rfloor$. Then enable compression, find a deepest leaf, and assert that its parent is the root and that the rank of the root is still $5$.
5. The opening comment answers two questions in your own sentences. Why does this course's Dijkstra bound stay $O((n + m) \log n)$ even though a Fibonacci heap would improve the theoretical amortized bound, and what is the name of that improved bound? Why does the subtree-size argument fail to prove an $O(\log n)$ find once path compression is turned on, even though Theorem 22 still gives a stronger amortized bound?

Keep the program. Lecture 14 assumes you can still build the heap, the forest, and a shortest-path trace from a blank file.

---

## Glossary

| Term | Meaning in this lecture |
| --- | --- |
| Weighted directed graph | A vertex set, a set of ordered edges, and a real weight on each edge |
| Walk | A finite sequence of vertices joined by edges; vertices may repeat |
| Path | A walk that repeats no vertex |
| Cycle | A closed walk of at least one edge with no other repeated vertex |
| Path weight | The sum of the edge weights along a walk; the empty walk weighs $0$ |
| Shortest-path weight | $\delta(s, v)$, the minimum walk weight from $s$ to $v$, or $\infty$ if $v$ is unreachable, or undefined as a minimum when a negative cycle makes the weights unbounded below |
| Negative cycle | A cycle whose weight is strictly negative; if it is reachable from the source and can reach $v$, then $\delta(s, v)$ has no finite value |
| Upper-bound invariant | $d[v]$ is $\infty$ or the weight of some walk from the source to $v$ |
| Relaxation | Replacing $d[v]$ by $d[u] + w(u, v)$ when that candidate is strictly smaller, and setting $\pi[v] = u$ |
| Predecessor | The parent $\pi[v]$ on the walk that most recently wrote $d[v]$ |
| Witness | The immutable linked record of the walk whose weight is the current finite label |
| Dijkstra's algorithm | Single-source shortest paths for nonnegative weights; a vertex is settled when it is extracted |
| Settled vertex | A vertex already extracted by Dijkstra or Prim; its label or key is final under that algorithm's hypothesis |
| Indexed binary heap | A 0-indexed binary heap plus a position map from each stored vertex to its array index |
| Position map | The map that makes decrease-key find an interior vertex in constant time |
| Decrease-key | Lowering the key of a vertex that is already in the heap, then sifting up |
| Bellman–Ford algorithm | $n - 1$ passes of relaxing every edge, plus one detection pass |
| DAG shortest paths | One relaxation pass in topological order |
| Topological order | A listing of the vertices in which every edge goes forward; Lecture 12 constructs it |
| Spanning tree | An acyclic connected edge set on all $n$ vertices; it has $n - 1$ edges |
| Minimum spanning tree | A spanning tree of minimum total weight |
| Minimum spanning forest | An MST of each connected component of a disconnected graph |
| Cut | A partition of the vertices into two nonempty sides |
| Crossing edge | An edge with one end on each side of a cut |
| Light edge | A crossing edge of minimum weight |
| Safe edge | An edge that can be added to $A$ while $A$ remains a subset of some MST |
| Cut property | A light edge across a cut that respects $A$ is safe for $A$, when $A$ lies in some MST |
| Cycle property | If the weights are distinct, the heaviest edge on a cycle is in no MST |
| Exchange argument | Replacing one tree edge by another and comparing the totals |
| Kruskal's algorithm | Sort edges, add the next edge when its ends lie in different components |
| Prim's algorithm | Grow one tree, always adding a light edge that leaves the tree |
| Disjoint-set forest | A partition stored as trees, one tree per block, the root representing the block |
| Representative | The root returned by find |
| Make-set | Create a singleton block |
| Find | Return the representative of the block that contains an element |
| Union | Merge the blocks of two elements |
| Union by rank | Link the root of smaller rank under the root of larger rank; on a tie, increase the parent's rank by one |
| Rank | With no compression, the height of the node's subtree; with compression, an upper bound on that height |
| Path compression | During find, point every node on the walked path at the root |
| Inverse Ackermann function | The function $\alpha$ in Tarjan's $O(m \, \alpha(n))$ bound; this lecture cites it and does not derive it |

---

## Lecture summary

A finite distance label is the weight of a concrete walk from the source. Relaxation replaces that walk by a lighter one and preserves the invariant. The schedule around the relaxation is what the weights allow.

Dijkstra's algorithm settles a vertex at the moment of extraction, and the proof uses nonnegativity exactly when it compares a shortest-path suffix with zero. An indexed binary heap gives decrease-key in $O(\log n)$ and a bound of $O((n + m) \log n)$. Duplicate heap entries would instead cost $O(m \log m)$. A Fibonacci heap is the theoretical route to $\Theta(m + n \log n)$ and is not built here. One negative edge is enough to make the settled label wrong.

The Bellman–Ford algorithm relaxes every edge $n - 1$ times. Path-relaxation says that a particular path of $k$ edges has been taken into account after $k$ passes, so a simple shortest path is in hand after $n - 1$ passes whenever no negative cycle is reachable from the source. One more pass reports such a cycle, and the witness of the improving edge contains one. The time is $\Theta(nm)$.

A DAG needs one pass in topological order, in $\Theta(n + m)$ time, because a shortest path lists vertices in that order. Negative edges are allowed. Breadth-first search remains the algorithm when every weight is $1$.

A minimum spanning tree is chosen by safe edges. The cut property, proved by exchanging a heavier crossing edge for a light one, is the reason Prim's next edge and Kruskal's next edge are safe. The cycle property is the reason a unique heaviest edge on a cycle is rejected. Distinct weights make the MST unique; ties make it a set of trees. Kruskal sorts, then tests components with a disjoint-set forest, in $O(m \log n)$ time including an $O(m \, \alpha(n))$ union-find term. Prim grows one tree on an indexed binary heap, in $O((n + m) \log n)$ time. Negative undirected weights are legal for both.

Union by rank without compression keeps height equal to rank, and a node of rank $r$ owns at least $2^r$ descendants, so find is $O(\log n)$ and the height is at most $\lfloor \log_2 n \rfloor$. Path compression can make the height strictly smaller than the rank. The bound with both mechanisms is Tarjan's theorem: $O(m \, \alpha(n))$, cited from CLRS Chapter 19 in the 4th edition (Chapter 21 in the 3rd) and not re-derived.

### Five principles

1. A distance label is the weight of a walk from the source, or it is infinite.
2. Settle a vertex on extraction only when every shortest-path suffix is nonnegative; otherwise keep relaxing for $n - 1$ passes and then look once more.
3. A light edge across a cut that respects the edges already chosen is safe, and that one fact is Prim's algorithm and Kruskal's algorithm.
4. Without compression, rank is the height and the height is $O(\log n)$. With compression, rank is only an upper bound, and the inverse-Ackermann bound is a theorem you cite.
5. The weight restriction chooses the shortest-path algorithm, and the bound is part of the choice.

---

## References

1. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*, 4th edition. MIT Press, 2022. Chapter 19, Data Structures for Disjoint Sets, including Section 19.4 on union by rank with path compression. Chapter 21, Minimum Spanning Trees. Chapter 22, Single-Source Shortest Paths, including the Bellman–Ford algorithm, shortest paths in a DAG, and Dijkstra's algorithm. The 3rd edition numbers the disjoint-set chapter as Chapter 21; that is the chapter number in many citations of the inverse-Ackermann analysis.

2. Robert Sedgewick and Kevin Wayne. *Algorithms*, 4th edition. Addison-Wesley, 2011. Section 1.5, Union-Find. Section 4.3, Minimum Spanning Trees. Section 4.4, Shortest Paths. Course site: [https://algs4.cs.princeton.edu/home/](https://algs4.cs.princeton.edu/home/).

3. Robert E. Tarjan. "Efficiency of a good but not linear set union algorithm." *Journal of the ACM* 22, no. 2 (1975). Theorem 22 of this lecture is this result, as developed in CLRS.

4. J. E. Hopcroft and J. D. Ullman. "Set merging algorithms." *SIAM Journal on Computing* 2, no. 4 (1973). The earlier $O(m \log^* n)$ bound, cited so that $\alpha(n)$ is not confused with an iterated logarithm.

5. Michael L. Fredman and Robert E. Tarjan. "Fibonacci heaps and their uses in improved network optimization algorithms." *Journal of the ACM* 34, no. 3 (1987). The amortized $\Theta(m + n \log n)$ bound for Dijkstra's algorithm. This course names the structure and does not implement it.

6. E. W. Dijkstra. "A note on two problems in connexion with graphs." *Numerische Mathematik* 1 (1959).

7. Richard Bellman. "On a routing problem." *Quarterly of Applied Mathematics* 16 (1958). The schedule is also associated with Lester Ford's work on network flows in the 1950s; the lecture follows the combined name Bellman–Ford used by CLRS.

8. Joseph B. Kruskal. "On the shortest spanning subtree of a graph and the traveling salesman problem." *Proceedings of the American Mathematical Society* 7 (1956).

9. R. C. Prim. "Shortest connection networks and some generalizations." *Bell System Technical Journal* 36 (1957). The same growth rule was published by Vojtěch Jarník in 1930.

10. Michael T. Goodrich, Roberto Tamassia, and Michael H. Goldwasser. *Data Structures and Algorithms in Java*, 6th edition. Wiley, 2014. The graph-algorithm chapters carry the same cut property and the same separation between a priority-queue Dijkstra and a queue-based BFS. The laboratories in this course are JavaScript.
