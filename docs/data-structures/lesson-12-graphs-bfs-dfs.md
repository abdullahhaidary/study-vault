# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 12 — GRAPHS: REPRESENTATION, BFS, AND DFS

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 12 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 10 hours
**Prerequisites:** Lecture 01 — Models, ADTs, and Asymptotic Analysis; Lecture 04 — Stacks, Queues, and Deques; Lecture 05 — Recursion, Induction, and Divide-and-Conquer
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapter 20, Sections 20.1–20.5; Sedgewick and Wayne, *Algorithms*, 4th edition, Sections 4.1 and 4.2

**This lecture owns:** graph vocabulary, the edge-list, adjacency-matrix, and adjacency-list representations, breadth-first search and unweighted shortest paths, depth-first search with the parenthesis theorem and edge classification, cycle detection, topological sort, and Kosaraju's algorithm for strongly connected components.
**This lecture does not teach:** weighted shortest paths, minimum spanning trees, or union-find. Breadth-first search reports the minimum number of edges. Dijkstra's algorithm, the Bellman–Ford algorithm, shortest paths in a weighted DAG, Prim's algorithm, Kruskal's algorithm, and union-find are Lecture 13.

---

## Learning objectives

After this lecture you should be able to do the following.

1. Define a directed graph, an undirected graph, a simple graph, degree, path, cycle, connectedness, strong connectivity, and a DAG, and compute or reject a degree sequence by the handshaking lemma.
2. State the space and the cost of an adjacency test and of listing neighbors for an edge list, an adjacency matrix, and an adjacency list, and choose the adjacency list as the default representation for search.
3. Execute breadth-first search from a source, maintain the white/gray/black colors, and prove that the recorded distance equals the minimum number of edges.
4. Reconstruct the corresponding path from parent pointers, and state why that path is a shortest path in the unweighted sense.
5. Execute depth-first search with discovery and finish times, apply the parenthesis theorem, and classify each directed edge as tree, back, forward, or cross.
6. Detect a directed cycle from a back edge to a gray vertex, and detect an undirected cycle while skipping the parent edge.
7. Produce a topological order of a DAG by decreasing finish time and by Kahn's algorithm, and show that a directed cycle leaves at least one vertex unprocessed by Kahn's algorithm.
8. Compute the strongly connected components of a digraph by Kosaraju's algorithm and explain, by the component-graph lemma, why the second search must follow decreasing finish times on the transpose.

---

## Purpose

A graph records a set of objects and a set of pairwise connections. Reachability, unweighted distance, cyclicity, a valid order of prerequisites, and the decomposition of a directed graph into mutually reachable pieces are all answered by walking those connections in a controlled order.

The walk needs two tools you already have. Breadth-first search uses the queue of Lecture 04, first in, first out. Depth-first search uses the recursion stack of Lecture 05, which is the stack of Lecture 04 in call-stack form. The correctness arguments are inductions of the kind Lecture 05 trained. The costs are $\Theta$ bounds in the RAM model of Lecture 01. In that model the input size of a graph is $\Theta(n + m)$, where $n$ is the number of vertices and $m$ is the number of edges, so a linear graph algorithm is $\Theta(n + m)$ and not $\Theta(n)$.

This lecture stops at unweighted graphs. An edge weight is a number attached to an edge. Breadth-first search never reads such a number. Section 10 says what that restriction costs you, and Lecture 13 takes up the weighted problems.

---

## 1. Directed and undirected graphs

### 1.1 Vertices, edges, and the two directions

A **graph** is a pair $G = (V, E)$. The finite set $V$ is the set of **vertices**. The set $E$ is the set of **edges**. Write $n = |V|$ and $m = |E|$.

In a **directed graph**, also called a **digraph**, each edge is an ordered pair $(u, v)$ of vertices. The edge leaves $u$ and enters $v$. Draw it as an arrow $u \to v$. The vertex $u$ is the **tail** and $v$ is the **head**. An edge $(u, v)$ is **incident** to $u$ and to $v$, and $u$ and $v$ are its **endpoints**. Two vertices joined by an edge are **adjacent**.

In an **undirected graph**, each edge is an unordered pair $\{u, v\}$ of distinct vertices. The connection has no arrow. The same edge may be read from $u$ to $v$ or from $v$ to $u$.

A **loop** is an edge whose two ends are the same vertex: $(u, u)$ in a digraph, or a degenerate undirected edge $\{u, u\}$. **Parallel edges** are two or more edges with the same endpoints. In a digraph, parallel edges share the same ordered pair; the opposite arrow $(v, u)$ is a different edge, not a parallel copy of $(u, v)$.

A **simple graph** has no loops and no parallel edges. A **multigraph** is what you get if those restrictions are dropped: parallel edges are allowed, and loops may be allowed. Parallel edges do not change which vertices can reach which other vertices. They would matter if the edges carried different weights, because a shortest-path algorithm would then keep the copy it prefers. This course studies simple graphs. The laboratory rejects a loop and ignores a second insertion of the same simple edge. A multigraph representation would store repeated neighbor entries, or store edge objects that have their own identities, and the degree of a vertex would count multiplicity.

### 1.2 Degree

In an undirected graph, the **degree** of a vertex $v$, written $\deg(v)$, is the number of edges incident to $v$.

In a digraph, the **out-degree** $\mathrm{out}(v)$ is the number of edges leaving $v$, and the **in-degree** $\mathrm{in}(v)$ is the number of edges entering $v$.

**Theorem (Handshaking lemma).** In an undirected simple graph, or more generally in an undirected graph with no loops,

$$
\sum_{v \in V} \deg(v) = 2m.
$$

**Proof.** Let $I$ be the set of pairs $(v, e)$ in which $v$ is an endpoint of the edge $e$. Count $|I|$ in two ways.

Fix a vertex $v$. The number of edges $e$ for which $(v, e)$ belongs to $I$ is exactly $\deg(v)$. Summing over $v$ gives $|I| = \sum_{v \in V} \deg(v)$.

Fix an edge $e = \{x, y\}$. Because the graph has no loop, $x$ and $y$ are distinct, so $e$ contributes exactly the two pairs $(x, e)$ and $(y, e)$. Summing over edges gives $|I| = 2m$.

The two counts are equal, which is the lemma. $\square$

A loop that is defined to contribute $2$ to the degree of its vertex also contributes two pairs, so the same identity survives that convention. The proof above does not need that case.

The identity forces the sum of the degrees to be even. A sequence of nonnegative integers whose sum is odd is not the degree sequence of any undirected graph.

The directed form is the same double count, split by direction.

**Theorem (Directed handshaking).** In a directed graph,

$$
\sum_{v \in V} \mathrm{in}(v) = \sum_{v \in V} \mathrm{out}(v) = m.
$$

**Proof.** Let $I_{\mathrm{in}}$ be the set of pairs $(v, e)$ in which $v$ is the head of $e$. Each vertex $v$ contributes $\mathrm{in}(v)$ pairs, and each edge has exactly one head, so the sum of the in-degrees equals $m$. The same argument with tails gives the sum of the out-degrees. $\square$

Kahn's algorithm in Section 8 is a walk on these in-degrees.

A simple undirected graph has at most one edge per unordered pair of distinct vertices, and there are $n(n-1)/2$ such pairs, so $m \le n(n-1)/2$. A simple digraph without loops has at most one edge per ordered pair of distinct vertices, so $m \le n(n-1)$. Those two ceilings are the dense extremes. A graph is **sparse** when $m$ is far below that ceiling, in particular when $m = o(n^2)$ in the sense of Lecture 01. Search algorithms are designed for that range.

### 1.3 Paths, cycles, and connectedness

A **path** of length $k \ge 0$ is a sequence of vertices $v_0, v_1, \ldots, v_k$ such that each consecutive pair is joined by an edge: $\{v_{i-1}, v_i\}$ in an undirected graph, and $(v_{i-1}, v_i)$ in a digraph. The length is the number of edges, not the number of vertices. A path of length $0$ is a single vertex.

Some books call a sequence that is allowed to repeat vertices a **walk**, and reserve "path" for a sequence with no repeated vertex. This lecture follows Cormen, Leiserson, Rivest, and Stein: a path may repeat vertices, and a **simple path** is a path whose vertices are all distinct.

A **cycle** is a path $v_0, v_1, \ldots, v_k$ with $k \ge 1$, $v_0 = v_k$, and $k \ge 3$ when the graph is undirected and simple. The extra restriction in the undirected simple case is there because the two directions of one undirected edge are the same edge: the sequence $u, v, u$ walks that edge twice and is not a cycle. In a simple digraph a cycle may have length $2$, because $(u, v)$ and $(v, u)$ are different edges. A **simple cycle** repeats no vertex except that the first and the last are the same.

An undirected graph is **connected** when every pair of vertices is joined by a path. A maximal connected piece is a **connected component**.

In a digraph, $v$ is **reachable** from $u$ when a directed path from $u$ to $v$ exists. The digraph is **strongly connected** when every vertex is reachable from every other vertex. A **strongly connected component** is a maximal set of vertices such that every vertex in the set is reachable from every other vertex in the set. Two vertices are in the same strongly connected component exactly when each can reach the other.

The **underlying undirected graph** is obtained by forgetting directions and deleting duplicate undirected edges. A digraph is **weakly connected** when that underlying graph is connected. Weak connectivity does not give you a way home. Strong connectivity does.

A **directed acyclic graph**, or **DAG**, is a digraph with no directed cycle. Prerequisite lists, task schedules, and the component graph of Section 9 are DAGs. An undirected acyclic connected graph is a tree in the sense of Lecture 07; this lecture uses that fact only as vocabulary and does not redevelop tree traversals.

---

## 2. Representations

An abstract graph says what the vertices and edges are. A representation says how a program stores them so that the operations used by search are cheap. Breadth-first search and depth-first search do one thing almost all of the time: given $u$, look at every neighbor of $u$. They rarely ask, in isolation, whether one particular pair is adjacent. The representation is chosen for the operation the algorithms actually perform.

Throughout this course, graph algorithms use adjacency lists unless a section is explicitly about another representation. This section is the comparison that justifies the default.

### 2.1 Edge list

An **edge list** is an array of the edges, each edge stored as a pair of vertices, together with a separate list of the vertices. The space is $\Theta(n + m)$ if the vertex list is stored, and $\Theta(m)$ for the edges alone.

The test "are $u$ and $v$ adjacent?" scans the edge array, which takes $\Theta(m)$ time in the worst case. Listing the neighbors of $u$ also scans the whole array, because the edges of $u$ are not gathered in one place, and that scan is $\Theta(m)$ as well. Inserting a new edge at the end of a dynamic array is amortized $\Theta(1)$ by the aggregate bound of Lecture 02, provided duplicates are not checked.

An edge list is a reasonable way to *receive* a graph. It is a poor way to *search* one. The first step of a serious algorithm is to convert the edge list into adjacency lists, in $\Theta(n + m)$ time, and then search.

### 2.2 Adjacency matrix

Number the vertices $0, 1, \ldots, n - 1$, or keep a table from vertex names to those indexes. An **adjacency matrix** is an $n \times n$ array $A$ with

$$
A[u][v] =
\begin{cases}
1 & \text{if the edge from } u \text{ to } v \text{ exists}, \\
0 & \text{otherwise}.
\end{cases}
$$

An undirected simple graph has a symmetric matrix: $A[u][v] = A[v][u]$, and the diagonal is $0$ because there is no loop.

The matrix stores $n^2$ entries whether or not the edges exist. The space is $\Theta(n^2)$. The test "are $u$ and $v$ adjacent?" reads one entry and is $\Theta(1)$. Listing the neighbors of $u$ scans row $u$. The row has $n$ entries, so the scan is $\Theta(n)$ even when the degree of $u$ is $0$.

That last cost is the reason search prefers lists. A breadth-first search that finds neighbors by scanning matrix rows spends $\Theta(n)$ per vertex it dequeues. Over $n$ vertices the bound is $\Theta(n^2)$, even when $m$ is linear in $n$. Section 3 shows that the same search on adjacency lists is $\Theta(n + m)$. Whenever $m = o(n^2)$, the list bound is asymptotically smaller.

The matrix earns its space when the graph is dense, $m = \Theta(n^2)$, or when the algorithm asks arbitrary adjacency questions and can pay $\Theta(n^2)$ memory. This lecture's searches do not.

### 2.3 Adjacency lists

An **adjacency list** representation stores, for each vertex $u$, a list $\mathrm{Adj}[u]$ of the neighbors of $u$. In a digraph, $\mathrm{Adj}[u]$ contains every $v$ such that $(u, v)$ is an edge, and it contains nothing else. The sum of the list lengths is $m$.

In an undirected graph the same edge $\{u, v\}$ must be visible from both ends, because a search that is sitting at $v$ has to be able to step to $u$. Store the edge twice: put $v$ in $\mathrm{Adj}[u]$ and put $u$ in $\mathrm{Adj}[v]$. The sum of the list lengths is then $2m$. Say this explicitly whenever you build an undirected graph. Forgetting the second copy makes the graph directed by accident, and distances come out wrong.

The space is $\Theta(n + m)$ in both cases: $n$ list heads, plus $m$ neighbor cells in a digraph or $2m$ neighbor cells in an undirected graph. Asymptotically $n + 2m$ is $\Theta(n + m)$.

The test "are $u$ and $v$ adjacent?" scans $\mathrm{Adj}[u]$ until it finds $v$ or exhausts the list. The worst-case cost is $\Theta(\deg(u))$ in an undirected graph and $\Theta(\mathrm{out}(u))$ in a digraph. That can be as large as $\Theta(n)$ for a single vertex of high degree. Listing the neighbors of $u$ is the scan you wanted anyway, and it costs $\Theta(\deg(u))$ or $\Theta(\mathrm{out}(u))$, which is optimal in the sense that the algorithm must look at each neighbor to report it.

| Representation | Space | Are $u$ and $v$ adjacent? | List the neighbors of $u$ |
| --- | --- | --- | --- |
| Edge list | $\Theta(n + m)$ | $\Theta(m)$ | $\Theta(m)$ |
| Adjacency matrix | $\Theta(n^2)$ | $\Theta(1)$ | $\Theta(n)$ |
| Adjacency list, directed | $\Theta(n + m)$ | $\Theta(\mathrm{out}(u))$ | $\Theta(\mathrm{out}(u))$ |
| Adjacency list, undirected | $\Theta(n + m)$, with $2m$ neighbor cells | $\Theta(\deg(u))$ | $\Theta(\deg(u))$ |

### 2.4 The order inside a list

The mathematical set $\mathrm{Adj}[u]$ has no order. An algorithm that classifies edges and assigns timestamps does. Two depth-first searches that scan the same neighbors in different orders discover vertices at different times. Every trace in this lecture, and every assertion in the laboratory, fixes the order as follows.

- Vertices are iterated in the order they were inserted.
- The neighbors of $u$ are iterated in the order the corresponding edges were successfully inserted.
- An undirected edge appends one neighbor to each of the two lists at the moment it is inserted, so the two copies occupy whatever positions those appends produce.
- A duplicate simple edge is not inserted again, so it does not change the order.

The laboratory uses a `Map` from vertex name to a neighbor array. A `Map` yields its keys in insertion order, and each neighbor array is only appended to. That is a language guarantee of the `Map` and array abstractions, not an accident of one engine's optimizer. Do not sort the neighbor lists unless an algorithm asks you to.

---

## 3. Breadth-first search

### 3.1 The reason for a queue

Fix a source vertex $s$. Paint every vertex white, meaning undiscovered. The search discovers a vertex when it first reaches it, paints it gray, and puts it in a queue. Gray means "discovered, and its neighbors have not all been scanned." When the scan of a vertex finishes, the vertex becomes black.

The queue is the queue of Lecture 04: enqueue at the back, dequeue from the front. Breadth-first search discovers vertices in order of increasing distance from $s$ because a vertex enters the queue only from an already discovered vertex, and the queue gives the earlier vertex its turn first.

**Breadth-first search** from $s$ on an adjacency-list graph:

```text
BFS(G, s)
  for each vertex u
    color[u] = white
    d[u] = infinity
    parent[u] = null
  color[s] = gray
  d[s] = 0
  parent[s] = null
  Q = an empty queue
  enqueue(Q, s)
  while Q is not empty
    u = dequeue(Q)
    for each v in Adj[u], in insertion order
      if color[v] is white
        color[v] = gray
        d[v] = d[u] + 1
        parent[v] = u
        enqueue(Q, v)
    color[u] = black
```

The value $d[v]$ is the **BFS distance** of $v$. It stays $\infty$ when $v$ is never discovered. The **parent** of a discovered vertex is the vertex from which it was discovered. The parent of $s$ is null.

On an undirected graph the same procedure runs unchanged, because each undirected edge was stored in both adjacency lists. Stepping from $u$ to $v$ and later from $v$ to $u$ uses those two copies.

A vertex is enqueued only when it is white, and the enqueue paints it gray. Therefore each vertex is enqueued at most once and dequeued at most once. There is no decrease of $d[v]$ later. The first time $v$ is seen, its distance is final.

### 3.2 The queue holds two consecutive distances

Write the queue from front to back as $v_1, v_2, \ldots, v_r$ at a moment when it is nonempty.

**Lemma (Queue distances).** Throughout breadth-first search, $d[v_1] \le d[v_2] \le \cdots \le d[v_r]$ and $d[v_r] \le d[v_1] + 1$. Consequently every distance present in the queue is one of two consecutive integers.

**Proof.** Induction on the number of enqueue and dequeue operations.

At the start the queue is $(s)$ and $d[s] = 0$. The claim holds.

Suppose the claim holds and the next operation dequeues $v_1$. The remaining queue is $v_2, \ldots, v_r$, or it is empty. The nonempty case inherits $d[v_2] \le \cdots \le d[v_r]$ from the inductive hypothesis. Also $d[v_r] \le d[v_1] + 1$ and $d[v_1] \le d[v_2]$, so $d[v_r] \le d[v_2] + 1$.

Suppose the next operation enqueues a white neighbor $w$ of a vertex $u$ whose adjacency list is being scanned, and the algorithm sets $d[w] = d[u] + 1$. The vertex $u$ was dequeued earlier, and during its scan the algorithm does not dequeue. Every enqueue since that dequeue has therefore been a neighbor of this same $u$, each assigned distance $d[u] + 1$.

If the queue is empty, it becomes $(w)$ and the claim holds.

If the queue is nonempty, write it $v_1, \ldots, v_r$ before $w$ is appended. The head $v_1$ was already behind $u$ when $u$ was dequeued. The lemma at that earlier moment gives $d[u] \le d[v_1]$, so $d[w] = d[u] + 1 \le d[v_1] + 1$.

For the tail, return to the moment just after $u$ was dequeued. The dequeue case says that the tail $t$ then present satisfies $d[t] \le d[u] + 1$, or else the queue was empty. The current tail $v_r$ is either that vertex $t$ or a neighbor of $u$ enqueued since, and every such neighbor has distance $d[u] + 1$. In both subcases $d[v_r] \le d[u] + 1 = d[w]$. Appending $w$ keeps the sequence nondecreasing, and the new tail is $w$, already shown to be at most $d[v_1] + 1$. $\square$

Vertices therefore leave the queue in nondecreasing order of distance. A layer finishes before the next layer begins, except that the queue may contain the end of one layer and the beginning of the next at the same time. It never contains three distances.

### 3.3 BFS distances are minimum edge counts

For vertices $s$ and $v$, write $\delta(s, v)$ for the minimum length of a path from $s$ to $v$, measured in number of edges. If no such path exists, $\delta(s, v) = \infty$. In particular $\delta(s, s) = 0$.

If $(u, v)$ is an edge, or $\{u, v\}$ is an undirected edge, then $\delta(s, v) \le \delta(s, u) + 1$. A shortest path to $u$, followed by that edge, is some path to $v$, and the minimum cannot exceed its length. This is the triangle inequality for unweighted distance. It is an inequality of counts of edges. It does not mention weights.

**Lemma (BFS never underestimates).** At every moment of the search, $d[v] \ge \delta(s, v)$ for every vertex $v$.

**Proof.** Induction on the number of assignments to distance entries. Initially $d[s] = 0 = \delta(s, s)$ and every other distance is $\infty$, which is at least $\delta(s, v)$.

The only later assignment sets $d[v] = d[u] + 1$ because of an edge between $u$ and $v$. By the inductive hypothesis $d[u] \ge \delta(s, u)$, so

$$
d[v] = d[u] + 1 \ge \delta(s, u) + 1 \ge \delta(s, v),
$$

where the last step is the triangle inequality. A distance is assigned at most once, so the inequality remains in force. $\square$

**Theorem (BFS correctness).** When breadth-first search from $s$ terminates, $d[v] = \delta(s, v)$ for every vertex $v$. Every vertex reachable from $s$ has been discovered, and every unreachable vertex still has distance $\infty$.

**Proof.** The unreachable case is immediate from the previous lemma: $d[v] \ge \delta(s, v) = \infty$, so $d[v] = \infty$, and the vertex was never enqueued.

Now take $v$ with $\delta(s, v) = k$, a finite number, and use induction on $k$.

If $k = 0$, then $v = s$ and $d[s] = 0$.

Suppose $k \ge 1$, and assume the theorem's equality is already known for every vertex whose true distance is at most $k - 1$. Choose a shortest path $s = u_0, u_1, \ldots, u_k = v$. Then $\delta(s, u_{k-1}) = k - 1$, because any shorter route to $u_{k-1}$ would yield a route to $v$ shorter than $k$. The inductive hypothesis says $d[u_{k-1}] = k - 1$. In particular $u_{k-1}$ was discovered, hence enqueued, hence dequeued.

Consider the moment $u_{k-1}$ is dequeued. The vertex $v$ is a neighbor of $u_{k-1}$.

If $v$ is still white, the algorithm sets $d[v] = d[u_{k-1}] + 1 = k$. Combined with the lemma $d[v] \ge \delta(s, v) = k$, this is equality.

If $v$ is already gray or black, then $v$ was discovered from some vertex $w$ that was dequeued earlier than $u_{k-1}$, and $d[v] = d[w] + 1$. The queue lemma says that dequeue order is nondecreasing in distance, so $d[w] \le d[u_{k-1}] = k - 1$. Therefore $d[v] \le k$. The underestimate lemma says $d[v] \ge k$. So $d[v] = k$.

The white case and the already-discovered case are exhaustive: $u_{k-1}$ is dequeued, and at that moment $v$ has some color. Thus every vertex at distance $k$ receives distance $k$. $\square$

The inductive step is exactly an induction on the distance. The queue lemma is what lets an earlier discovery be charged to a distance no larger than $k - 1$.

### 3.4 Time

Assume the adjacency-list representation and a queue whose enqueue and dequeue are $\Theta(1)$. The laboratory queue is an array plus a head index. Advancing the head is $\Theta(1)$. `Array.prototype.shift` moves every later entry, so a queue built on `shift` does not have $\Theta(1)$ dequeue and does not support the bound in this section.

Initialization writes a color, a distance, and a parent for each of the $n$ vertices: $\Theta(n)$.

Each vertex is enqueued at most once, so the work outside the neighbor scans is $\Theta(n)$. When a vertex $u$ is dequeued, its adjacency list is scanned once. Each entry of that list is therefore examined at most once. A directed graph has $m$ list entries in total, and an undirected graph has $2m$, because each edge was stored twice. The scans cost $\Theta(m)$ when every vertex is reachable from $s$, since then every list is scanned. If some vertices are unreachable, their lists are never scanned. Let $m_R$ be the number of adjacency-list entries that belong to vertices reachable from $s$. The scans cost $\Theta(m_R)$, and $m_R \le m$ in a digraph while $m_R \le 2m$ in an undirected graph.

The whole search is therefore $\Theta(n + m_R)$, which is $O(n + m)$ on every input and $\Theta(n + m)$ whenever the source can reach every vertex. That is the bound meant by "breadth-first search on adjacency lists runs in $\Theta(n + m)$ time." The same search on an adjacency matrix is $\Theta(n^2)$, as Section 2 explained, because each of up to $n$ row scans costs $\Theta(n)$.

Discovery and finish colors are not a second asymptotic term. Painting a vertex is $\Theta(1)$, and it happens $O(1)$ times per vertex.

### 3.5 A trace

The undirected graph below is the running breadth-first example. Vertices are inserted in the order $s, a, b, c, d, e$. Undirected edges are inserted in the order $\{s, a\}$, $\{s, b\}$, $\{a, c\}$, $\{a, d\}$, $\{b, d\}$, $\{d, e\}$. Each edge is stored twice.

```text
s —— a —— c
|    |
b —— d —— e
```

The adjacency lists, in insertion order, are:

```text
s: a, b
a: s, c, d
b: s, d
c: a
d: a, b, e
e: d
```

Search from $s$. The queue is written from front to back, with distances attached.

| Step | Action | Queue afterward |
| --- | --- | --- |
| 0 | Discover $s$, $d[s] = 0$ | $s:0$ |
| 1 | Dequeue $s$. Discover $a$ and $b$ | $a:1,\ b:1$ |
| 2 | Dequeue $a$. $s$ is black. Discover $c$ and $d$ | $b:1,\ c:2,\ d:2$ |
| 3 | Dequeue $b$. $s$ is black. $d$ is already gray | $c:2,\ d:2$ |
| 4 | Dequeue $c$. $a$ is black | $d:2$ |
| 5 | Dequeue $d$. $a$ and $b$ are black. Discover $e$ | $e:3$ |
| 6 | Dequeue $e$. $d$ is black | empty |

After step 2 the queue holds distance $1$ and distance $2$. After step 5 it holds only distance $3$. It never holds three distances. The final distances are

$$
d[s] = 0,\ d[a] = 1,\ d[b] = 1,\ d[c] = 2,\ d[d] = 2,\ d[e] = 3.
$$

The layers, which are the sets of vertices at each distance, are $\{s\}$, then $\{a, b\}$, then $\{c, d\}$, then $\{e\}$.

If a new vertex $z$ is inserted with no incident edge, the same search leaves $d[z] = \infty$ and $\mathrm{parent}[z] = \mathrm{null}$. The distances of $s, a, b, c, d, e$ do not change. The laboratory asserts that isolated vertex as well.

---

## 4. Unweighted shortest paths and the BFS tree

### 4.1 The predecessor subgraph is a tree of shortest paths

Define the **predecessor subgraph** of a breadth-first search from $s$ to contain $s$, every vertex $v$ with a finite BFS distance, and every edge from $\mathrm{parent}[v]$ to $v$.

**Theorem (BFS tree).** The predecessor subgraph is a tree rooted at $s$, on the vertices reachable from $s$. For every such vertex $v$, the unique path from $s$ to $v$ in this tree has length $d[v]$, and that length equals $\delta(s, v)$.

**Proof.** Every reachable vertex other than $s$ has exactly one parent, and $s$ has none. Following parent pointers strictly decreases the recorded distance, because $d[v] = d[\mathrm{parent}[v]] + 1$ by the assignment in the algorithm. A finite descent cannot cycle, so the subgraph is acyclic. It has one fewer edge than it has vertices, and every vertex is joined to $s$ by the parent chain, so it is a tree rooted at $s$.

The length claim is an induction on $d[v]$. It is $0$ at $s$. If it holds for the parent, the tree path to $v$ is the tree path to the parent followed by one edge, and its length is $d[\mathrm{parent}[v]] + 1 = d[v]$. The correctness theorem of Section 3.3 says $d[v] = \delta(s, v)$. $\square$

The tree is called the **BFS tree**. It is one shortest-path tree. Another run, with a different neighbor order, may produce a different tree of the same distances. The distances themselves do not depend on the order. The parents do.

### 4.2 Reconstructing the path

To recover the path from $s$ to a target $t$, follow parent pointers from $t$ until $s$, then reverse the sequence. If a null parent appears before $s$ is reached, $t$ is not reachable from $s$ and no path exists.

On the trace of Section 3 the parents are $\mathrm{parent}[a] = s$, $\mathrm{parent}[b] = s$, $\mathrm{parent}[c] = a$, $\mathrm{parent}[d] = a$, and $\mathrm{parent}[e] = d$. Starting at $e$ yields $e, d, a, s$. Reversed, the path is $s, a, d, e$, of length $3$. That matches $d[e] = 3 = \delta(s, e)$. The route $s, b, d, e$ is another shortest path, of the same length, and this particular neighbor order did not select it, because $d$ was discovered from $a$ while $a$ was still ahead of $b$ in the queue.

The reconstruction looks at each parent once and takes time proportional to the length of the path, which is $O(n)$.

### 4.3 What "shortest" means here

The quantity $\delta(s, v)$ is the minimum number of edges. If every edge is treated as having the same positive cost, that count is also the minimum total cost. The moment edges are allowed to carry different costs, the minimum number of edges and the minimum total cost can name different paths. Section 10 gives the smallest example. Until then, every occurrence of "shortest path" in this lecture means "minimum number of edges."

---

## 5. Depth-first search

### 5.1 The reason for the recursion stack

Breadth-first search finishes an entire layer before it goes deeper. Depth-first search does the opposite: when it discovers a vertex, it immediately explores from that vertex, and it returns to the discoverer only after the new vertex is exhausted. The pending work sits on the call stack.

The same three colors apply. White means undiscovered. Gray means discovered and not yet finished: the call `DFS-Visit` on that vertex is on the stack. Black means finished: the adjacency list has been scanned and the call has returned.

Two timestamps are written. The **discovery time** $d[u]$ is the value of a global clock at the moment $u$ becomes gray. The **finish time** $f[u]$ is the clock at the moment $u$ becomes black. The clock starts at $0$ and increases by $1$ at every discovery and every finish. Every timestamp is an integer in $\{1, 2, \ldots, 2n\}$, and all $2n$ timestamps are distinct, because each vertex contributes one discovery and one finish.

```text
DFS(G)
  for each vertex u
    color[u] = white
    parent[u] = null
  time = 0
  for each vertex u, in vertex insertion order
    if color[u] is white
      DFS-Visit(u)

DFS-Visit(u)
  time = time + 1
  d[u] = time
  color[u] = gray
  for each v in Adj[u], in insertion order
    if color[v] is white
      parent[v] = u
      DFS-Visit(v)
    else if color[v] is gray
      record (u, v) as a back edge
    else
      record (u, v) as forward or cross, by Section 6
  color[u] = black
  time = time + 1
  f[u] = time
  record u as finishing now
```

The outer loop matters. A vertex that is not reached from the first source becomes the root of a later tree. The collection of trees is the **depth-first forest**. Parent pointers again point from a vertex to the vertex that discovered it. A root has parent null.

The algorithm above classifies directed edges. On an undirected graph the same timestamps are well defined, but each undirected edge is stored twice, and the copy that points back at the parent is gray for a reason that is not a cycle. Section 7 handles that case with a separate walk. The laboratory's timestamp search refuses an undirected graph so that the two procedures stay distinct.

### 5.2 The gray vertices are the stack

**Lemma (Gray path).** At every moment of depth-first search, the gray vertices are exactly the vertices on the recursion stack. They form a path of tree edges from the root of the current depth-first tree down to the vertex whose visit is in progress, and discovery times strictly increase along that path.

**Proof.** `DFS-Visit(u)` paints $u$ gray on entry and black on exit. A nested call is made only on a white neighbor, and that neighbor's parent is set to the caller, so the nested call extends a tree edge. By induction on the nesting depth, the stack is a tree path from the root that the outer loop most recently started. A vertex not on the stack is white if its call has not begun and black if its call has returned. Discovery time increases along the stack because the clock advances before each new discovery, and the parent was discovered at an earlier tick. $\square$

A back edge, a directed cycle, and a pair of nested time intervals are three descriptions of this one path.

### 5.3 The parenthesis theorem

For a vertex $u$ the **interval** of $u$ is the closed integer interval from $d[u]$ to $f[u]$. While the clock is strictly between $d[u]$ and $f[u]$, the vertex $u$ is gray.

**Theorem (Parenthesis theorem).** In any depth-first search of a directed or undirected graph, for any two distinct vertices $u$ and $v$, exactly one of the following holds.

1. The intervals of $u$ and $v$ are disjoint, and neither vertex is a descendant of the other in the depth-first forest.
2. The interval of $u$ is properly contained in the interval of $v$, and $u$ is a descendant of $v$.
3. The interval of $v$ is properly contained in the interval of $u$, and $v$ is a descendant of $u$.

Here a **descendant** of $u$ means a vertex discovered during `DFS-Visit(u)`, reached by a path of tree edges from $u$. A vertex is not called a descendant of itself in this statement; the containment for distinct vertices is proper.

**Proof.** Discovery times are distinct. Swap names if needed so that $d[u] < d[v]$.

Case 1: $v$ is discovered before $u$ finishes, that is $d[v] < f[u]$. Then $v$ is discovered while $u$ is gray. By the gray-path lemma, $u$ lies on the stack at that moment, so the stack path from $u$ down to the vertex that discovers $v$, plus the tree edge into $v$, is a tree path from $u$ to $v$. Thus $v$ is a descendant of $u$. The call `DFS-Visit(v)` is nested inside `DFS-Visit(u)` and returns first, so $f[v] < f[u]$. The interval of $v$ is properly inside the interval of $u$.

Case 2: $u$ finishes before $v$ is discovered, that is $f[u] < d[v]$. Then $d[u] < f[u] < d[v] < f[v]$, so the intervals are disjoint. The vertex $v$ is not a descendant of $u$, because every descendant of $u$ is discovered before $f[u]$. The vertex $u$ is not a descendant of $v$, because $u$ is already black when $v$ is discovered, so $u$ is not discovered during the call on $v$.

These two cases partition the possibilities under $d[u] < d[v]$. The symmetric situation $d[v] < d[u]$ is the same argument. Exactly one of the three listed geometries occurs. $\square$

The picture of the theorem is a string of parentheses, one pair per vertex, opening at the discovery time and closing at the finish time. The parentheses are properly matched, and two pairs are either nested or side by side.

### 5.4 The white-path theorem

The parenthesis theorem says what the timestamps look like after the search. The next theorem says which vertices will end up inside a call, and it is the fact Section 9 uses.

**Theorem (White-path theorem).** A vertex $v$ is a descendant of a vertex $u$ in the depth-first forest if and only if, at the moment $u$ is discovered, there is a path from $u$ to $v$ whose vertices other than $u$ are all white.

**Proof.** Suppose $v$ is a descendant of $u$. The tree path from $u$ to $v$ consists of vertices discovered after $d[u]$. At time $d[u]$ those vertices are still white.

Suppose, in the other direction, that $u = w_0, w_1, \ldots, w_k = v$ is a path and that $w_1, \ldots, w_k$ are white at time $d[u]$. The claim is that each $w_i$ with $i \ge 1$ becomes a descendant of $u$. Proceed by induction on $i$.

Take $w_1$. It is a white neighbor of $u$ at time $d[u]$, so it was not discovered before $u$. Between $d[u]$ and $f[u]$ the only active calls are `DFS-Visit(u)` and calls nested inside it, by the gray-path lemma. So if $w_1$ is discovered in that interval, its discoverer is $u$ or a descendant of $u$, and $w_1$ itself becomes a descendant of $u$. It is discovered in that interval: `DFS-Visit(u)` scans the edge from $u$ to $w_1$ before $u$ finishes, and if $w_1$ is still white at that scan it is discovered then; if it is no longer white, it was discovered earlier in the same interval. It cannot remain undiscovered, and it cannot be discovered by a vertex off this stack.

The step from $w_{i-1}$ to $w_i$ is the same argument with $w_{i-1}$ in the role of the ancestor. The inductive hypothesis says $w_{i-1}$ is a descendant of $u$, so its visit occurs before $u$ finishes, and $w_i$ is white at time $d[u]$, hence is discovered under $w_{i-1}$ or under some other descendant of $u$ during that visit. $\square$

### 5.5 Time

`DFS-Visit` is called once per vertex, because a vertex is white only until its discovery. The outer loop examines each vertex once. Each call scans the adjacency list of its vertex once. The sum of the list lengths is $m$ in a digraph and $2m$ in an undirected graph. Every list is scanned, including the lists of vertices in later trees of the forest, because the outer loop restarts on every white vertex.

The total is $\Theta(n + m)$. This bound is tight for every graph, not only for graphs that are reachable from one source. Single-source breadth-first search may skip the lists of unreachable vertices; the depth-first forest does not skip vertices.

Recording the decreasing-finish order costs an additional $\Theta(n)$, not $\Theta(n \log n)$. Push a vertex onto an array when it finishes. The array is then in increasing order of finish time. Reverse it. Reversal is $\Theta(n)$, and $n$ appends to a dynamic array cost $\Theta(n)$ altogether by the aggregate bound of Lecture 02. A comparison sort of the finish times would cost $\Theta(n \log n)$ and would spoil the $\Theta(n + m)$ bound on a sparse graph. The laboratory uses push and reverse.

JavaScript numbers are safe integers up through $2^{53} - 1$. Discovery and finish times are at most $2n$. They remain safe integers for every graph this representation can allocate. The bound $\Theta(n + m)$ is a RAM-model bound. A separate engine limit exists: a recursive visit along a path of length tens of thousands may exhaust the call stack of a particular JavaScript engine. That limit is not part of the mathematical cost. The laboratory graphs are short. An explicit-stack implementation computes the same timestamps when the recursion depth would be a problem; the independent assignment is a natural place to write it.

### 5.6 A trace with times

The directed graph for timestamps and edge classes has vertices inserted in the order $a, b, c, d, e$ and adjacency lists

```text
a: b, c, d
b: c, e
c: a
d: e
e: b
```

The outer loop starts at $a$, and that one tree contains every vertex. The clock runs as follows.

| Event | Clock | Vertex | Color change |
| --- | --- | --- | --- |
| Discover $a$ | 1 | $a$ | white to gray |
| Discover $b$, tree edge $a \to b$ | 2 | $b$ | white to gray |
| Discover $c$, tree edge $b \to c$ | 3 | $c$ | white to gray |
| See $a$ gray, back edge $c \to a$ |  |  |  |
| Finish $c$ | 4 | $c$ | gray to black |
| Discover $e$, tree edge $b \to e$ | 5 | $e$ | white to gray |
| See $b$ gray, back edge $e \to b$ |  |  |  |
| Finish $e$ | 6 | $e$ | gray to black |
| Finish $b$ | 7 | $b$ | gray to black |
| See $c$ black, forward edge $a \to c$ |  |  |  |
| Discover $d$, tree edge $a \to d$ | 8 | $d$ | white to gray |
| See $e$ black, cross edge $d \to e$ |  |  |  |
| Finish $d$ | 9 | $d$ | gray to black |
| Finish $a$ | 10 | $a$ | gray to black |

The times $d[u]/f[u]$ are $a: 1/10$, $b: 2/7$, $c: 3/4$, $e: 5/6$, $d: 8/9$.

```text
a 1/10
├── b 2/7
│   ├── c 3/4
│   └── e 5/6
└── d 8/9
```

The parenthesis string, openings and closings in time order, is

```text
(a (b (c c) (e e) b) (d d) a)
```

The interval of $c$, namely $[3, 4]$, and the interval of $e$, namely $[5, 6]$, are disjoint and both sit inside the interval of $b$, namely $[2, 7]$. The intervals of $b$ and of $d$ are disjoint and both sit inside the interval of $a$, namely $[1, 10]$. That is the parenthesis theorem on this forest. The parents are $\mathrm{parent}[b] = a$, $\mathrm{parent}[c] = b$, $\mathrm{parent}[e] = b$, and $\mathrm{parent}[d] = a$.

---

## 6. Classification of edges in a directed graph

### 6.1 Four kinds of edge

Take a directed edge $(u, v)$ at the moment `DFS-Visit(u)` examines it. The color of $v$, together with the discovery times when the color is black, puts the edge in exactly one class.

- **Tree edge.** $v$ is white. The search discovers $v$ through this edge and sets $\mathrm{parent}[v] = u$. The edge belongs to the depth-first forest.
- **Back edge.** $v$ is gray. By the gray-path lemma, $v$ is an ancestor of $u$ on the stack. The edge points back up that path. A loop $(u, u)$ would be a back edge, because $u$ is gray during its own visit; simple graphs in this course have no loops, and a back edge here joins two distinct vertices.
- **Forward edge.** $v$ is black and $d[u] < d[v]$. The vertex $v$ was discovered after $u$ and has already finished, so $v$ is a descendant of $u$ by the parenthesis theorem, but this edge is not the tree edge that discovered $v$. It jumps forward to a descendant.
- **Cross edge.** $v$ is black and $d[v] < d[u]$. The interval of $v$ is disjoint from the interval of $u$ and lies entirely earlier. Neither vertex is a descendant of the other.

These are definitions by color at examination time. The next paragraph shows that the time tests describe the same partition.

### 6.2 The time tests match the colors

Suppose $(u, v)$ is examined while $u$ is gray, which is the only moment at which the search examines it.

If $v$ is white, the edge is a tree edge by definition. After the recursive call, the parenthesis theorem gives $d[u] < d[v] < f[v] < f[u]$, and $\mathrm{parent}[v] = u$.

If $v$ is gray, the edge is a back edge. The gray-path lemma puts $v$ above $u$ on the stack, so $v$ was discovered before $u$ and has not finished. Therefore $d[v] < d[u] < f[u] < f[v]$.

If $v$ is black and $d[u] < d[v]$, then $v$ finished before the examination, so $f[v]$ is already set and is less than the still-pending $f[u]$. Combined with $d[u] < d[v]$, the parenthesis theorem says the interval of $v$ is nested in the interval of $u$, so $v$ is a descendant of $u$. The tree edge into $v$ was a different edge, examined when $v$ was white. This edge is forward.

If $v$ is black and $d[v] < d[u]$, the interval of $v$ cannot contain $u$: if it did, $u$ would be a descendant of $v$ and would finish before $v$, but $u$ is still gray. The parenthesis theorem therefore makes the intervals disjoint, with $f[v] < d[u]$. Neither is a descendant of the other. The edge is a cross edge.

### 6.3 One edge of each kind on the traced digraph

Section 5 examined eight directed edges. Their classes are:

| Edge | Class | Why |
| --- | --- | --- |
| $a \to b$ | tree | $b$ was white |
| $b \to c$ | tree | $c$ was white |
| $b \to e$ | tree | $e$ was white |
| $a \to d$ | tree | $d$ was white |
| $c \to a$ | back | $a$ was gray; $d[a] = 1 < d[c] = 3 < f[c] = 4 < f[a] = 10$ |
| $e \to b$ | back | $b$ was gray; $d[b] = 2 < d[e] = 5 < f[e] = 6 < f[b] = 7$ |
| $a \to c$ | forward | $c$ was black and $d[a] = 1 < d[c] = 3$; the tree path is $a \to b \to c$ |
| $d \to e$ | cross | $e$ was black and $f[e] = 6 < d[d] = 8$; $e$ sits in the other branch under $b$ |

The forward edge $a \to c$ does not discover $c$. The cross edge $d \to e$ does not make $e$ a descendant of $d$. Both observations come straight from the colors at the time of the examination.

### 6.4 Undirected graphs have no forward or cross edge

**Theorem (stated for use in Section 7).** In a depth-first search of an undirected graph, every edge is a tree edge or a back edge, once each undirected edge is classified at the first examination of either of its two stored copies.

**Proof.** Let $\{u, v\}$ be an undirected edge with $d[u] < d[v]$. At time $d[u]$ the vertex $v$ is white. The call on $u$ is still active until $f[u]$.

The first time one of the two stored copies is examined, the examined endpoint's neighbor is either white or gray. It cannot yet be a finished non-ancestor seen from a disjoint interval, for the following reason. The vertex $v$ is discovered during `DFS-Visit(u)`: the white-path theorem applies to the one-edge path $u, v$. So $v$ becomes a descendant of $u$, and $f[v] < f[u]$. During `DFS-Visit(v)` the vertex $u$ is still gray. The copy of the edge stored in $\mathrm{Adj}[v]$ is examined before $v$ finishes, and at that moment $u$ is gray, so that examination sees a back edge toward an ancestor.

If the copy in $\mathrm{Adj}[u]$ is examined while $v$ is still white, the edge is a tree edge instead, and $u$ is the parent of $v$. In that case the later examination from $v$ sees the parent. Section 7 refuses to treat the parent as a second, back, edge.

There is no remaining case in which the first examination sees a black vertex in a disjoint interval. A forward classification would be a second look at an edge already classified, from the ancestor, after the descendant has finished. The algorithm classifies an undirected edge once. $\square$

---

## 7. Cycle detection

### 7.1 A back edge is a directed cycle

**Theorem (Directed cycle).** A directed graph has a directed cycle if and only if a depth-first search produces a back edge.

**Proof.** First suppose $(u, v)$ is a back edge. Then $v$ is gray when $u$ examines it, and $u$ is gray as well because its visit is in progress. The gray-path lemma gives a tree path from $v$ down to $u$. That path is simple. The edge $(u, v)$ returns to $v$. The vertices of the tree path are distinct, and $u \ne v$ because a simple graph has no loop, so the closed walk is a simple directed cycle.

Conversely, suppose the digraph has a directed cycle, and run depth-first search. Let $v$ be the first vertex of that cycle to be discovered. Let $(u, v)$ be the cycle edge that enters $v$. At time $d[v]$ every other vertex of the cycle is still white. Walking from $v$ around the cycle to $u$ is a path whose vertices other than $v$ are white. The white-path theorem says that $u$ becomes a descendant of $v$. The call on $u$ therefore runs while $v$ is gray, and it finishes before $v$ finishes. When that call examines $(u, v)$, the vertex $v$ is still gray. The edge is a back edge. $\square$

On the traced digraph, $c \to a$ is a back edge. The gray path at that moment is $a, b, c$, because $c$ was discovered under $b$ and $b$ under $a$. The cycle is $a, b, c, a$. The other back edge, $e \to b$, closes the cycle $b, e, b$, which is a directed cycle of length $2$. The forward edge and the cross edge are not the witnesses. A cross edge may or may not lie on some cycle elsewhere; the theorem does not use it as the test. The test is the gray vertex.

The laboratory returns one such cycle by walking parent pointers from the tail of the first back edge up to its gray head, then closing the edge. On this graph the first back edge is $c \to a$, and the walk produces $a, b, c, a$.

### 7.2 Why the parent edge is not an undirected cycle

Store an undirected edge twice, and a depth-first search that has just walked the tree edge from $p$ to $u$ will later see $p$ in $\mathrm{Adj}[u]$. At that moment $p$ is gray: it is the parent, still on the stack. If the directed test were applied unchanged, every tree edge would be reported as a back edge, and every undirected graph with at least one edge would look cyclic.

The repair is the **parent exception**. In an undirected search, ignore the neighbor that is the parent. After that exception, a neighbor that is gray, or more generally a neighbor that has already been discovered and is not the parent, closes a cycle.

The justification is Section 6.4. The edge back to the parent is the tree edge seen from the child. Any other edge out of $u$ into an already discovered vertex goes to an ancestor other than the parent, or is the first examination of an edge whose other end is already on the gray path. Following parent pointers from $u$ up to that vertex and returning along the edge produces a simple cycle of length at least $3$.

```text
Undirected-Cycle(G)
  for each vertex u
    color[u] = white
    parent[u] = null
  for each vertex u in insertion order
    if color[u] is white
      Visit(u)

Visit(u)
  color[u] = gray
  for each v in Adj[u], in insertion order
    if v is parent[u]
      skip v
    else if color[v] is white
      parent[v] = u
      Visit(v)
    else
      a cycle exists: v is visited and is not the parent
  color[u] = black
```

### 7.3 Two undirected traces

Take vertices $x, y, z$ in that order and undirected edges $\{x, y\}$, $\{y, z\}$, $\{z, x\}$, each stored twice. The lists are

```text
x: y, z
y: x, z
z: y, x
```

The search starts at $x$, discovers $y$ with parent $x$, and from $y$ skips $x$ because $x$ is the parent. It then discovers $z$ with parent $y$. From $z$, the neighbor $y$ is the parent and is skipped. The next neighbor is $x$, which is gray and is not the parent of $z$. That is the detection. Walking parents from $z$ up to $x$ gives $z, y, x$, and closing the edge gives the cycle $x, y, z, x$.

The same procedure on the graph of Section 3, starting at $s$, walks the tree edges $s \to a \to d$ and then from $d$ discovers $b$, because $b$ is still white at that moment. From $b$, the neighbor $s$ is gray, and the parent of $b$ is $d$, not $s$. The detected cycle is $s, a, d, b, s$. A star with edges $\{t, u\}$ and $\{t, v\}$ only, and a single edge $\{p, q\}$, produce no detection: every gray neighbor encountered is the parent, and it is skipped.

---

## 8. Topological sort

### 8.1 The order a DAG permits

A **topological order** of a digraph is a list of all the vertices such that for every edge $(u, v)$, the vertex $u$ appears before $v$. The list is a schedule: every prerequisite comes first.

**Theorem (Existence).** A directed graph has a topological order if and only if it is a DAG.

**Proof.** Suppose a cycle $v_0, v_1, \ldots, v_k = v_0$ exists, with $k \ge 1$. In any total order some vertex of the cycle is last among the cycle's vertices. The cycle edge leaving that vertex points to an earlier vertex. That edge goes backward. So no topological order exists.

Suppose the digraph is a DAG. Then it has a vertex of in-degree $0$. Indeed, start at any vertex and walk backward along incoming edges. A DAG cannot repeat a vertex on that walk, and the graph is finite, so the walk stops at a vertex with no incoming edge. Place that vertex first, delete it and its outgoing edges, and repeat. The remainder is still a DAG. After $n$ steps every vertex has been placed, and every edge pointed from an earlier choice to a later one, because an edge is still present until its tail is chosen, and its head is still in the remainder. $\square$

The two algorithms below construct such an order without searching for an arbitrary zero-in-degree vertex by an unstructured scan at every step. Both run in $\Theta(n + m)$ time. They need not return the same order. A DAG can have many topological orders.

### 8.2 Decreasing finish time

Run depth-first search. If any back edge appears, Section 7 says the graph has a cycle and no topological order exists. If none appears, output the vertices in order of **decreasing finish time**: the vertex that finishes last is first in the order.

Build that list by appending each vertex at the moment it finishes, then reversing the array, as in Section 5.5. The cost of the list is $\Theta(n)$ on top of a depth-first search, so the whole algorithm is $\Theta(n + m)$.

**Theorem (Finish-time order).** If $G$ is a DAG, the decreasing order of finish times from a depth-first search is a topological order of $G$.

**Proof.** It is enough to show that every edge $(u, v)$ satisfies $f[v] < f[u]$, because then $u$, which finishes later, stands earlier in the decreasing list.

Consider $(u, v)$ when the search examines it. The vertex $v$ is not gray: a gray $v$ would make $(u, v)$ a back edge, hence a cycle by Section 7, contradicting that $G$ is a DAG.

If $v$ is white, the edge is a tree edge and $v$ is a descendant of $u$. The parenthesis theorem gives $f[v] < f[u]$.

If $v$ is black, then $v$ has already been assigned a finish time, and $u$ has not, because $u$ is still gray. The clock value $f[v]$ is therefore strictly less than the later value $f[u]$.

Every edge runs from a later finish time to an earlier finish time. $\square$

### 8.3 Kahn's algorithm

Kahn's algorithm maintains the in-degrees of the not-yet-output vertices and repeatedly outputs a vertex whose current in-degree is $0$.

```text
Kahn(G)
  for each vertex u
    indegree[u] = 0
  for each vertex u
    for each v in Adj[u]
      indegree[v] = indegree[v] + 1
  Q = an empty queue
  for each vertex u, in insertion order
    if indegree[u] = 0
      enqueue(Q, u)
  order = an empty list
  while Q is not empty
    u = dequeue(Q)
    append u to order
    for each v in Adj[u], in insertion order
      indegree[v] = indegree[v] - 1
      if indegree[v] = 0
        enqueue(Q, v)
  if order contains fewer than n vertices
    report that a cycle remains
  else
    return order
```

The initial in-degree pass scans every adjacency-list entry once and is $\Theta(n + m)$. Each vertex is enqueued at most once, and each edge causes at most one decrement. With a $\Theta(1)$ queue the whole algorithm is $\Theta(n + m)$.

The queue order must be fixed for a trace to be unique. This lecture enqueues the initial in-degree-zero vertices in vertex insertion order, and it enqueues a vertex at the moment its in-degree falls to $0$, in the neighbor order of the vertex that caused the decrement.

**Theorem (Kahn is correct on a DAG).** If $G$ is a DAG, Kahn's algorithm outputs a topological order of all $n$ vertices.

**Proof.** Induction on $n$. A DAG has a vertex of in-degree $0$, so the queue starts nonempty. The first vertex $u$ that the algorithm outputs has in-degree $0$, so no edge is required to precede $u$. Delete $u$. Each decrement writes the in-degrees of the remaining digraph, which is still a DAG. By induction the rest of the output is a topological order of the remainder. Placing $u$ first preserves every edge that left $u$, and every other edge was already ordered by the inductive result. $\square$

**Theorem (A cycle leaves a vertex unprocessed).** If the directed graph has a cycle, Kahn's algorithm terminates with at least one vertex unprocessed.

**Proof.** Let $C$ be a directed cycle, and suppose, for a contradiction, that some vertex of $C$ is processed. Let $x$ be the first vertex of $C$ that the algorithm processes, and let $p$ be the predecessor of $x$ along $C$. The edge $(p, x)$ contributes $1$ to the in-degree of $x$. That contribution is removed only when $p$ is processed. The vertex $p$ also lies on $C$, and $x$ was supposed to be the first processed vertex of $C$, so $p$ has not been processed. The residual in-degree of $x$ is therefore still at least $1$, and $x$ is not eligible for the queue. This contradicts the choice of $x$.

Hence no vertex of $C$ is processed. $\square$

The converse observation is useful and short. If the algorithm stops with a nonempty set $U$ of unprocessed vertices, every vertex of $U$ has residual in-degree at least $1$ from edges whose tails are also in $U$: edges from processed vertices have already been decremented. Walk backward along residual edges inside $U$. The walk stays in the finite set $U$ and must repeat a vertex. The portion between the repetition is a directed cycle. So an early stop is not an ambiguous failure. It is a certificate that a cycle exists.

### 8.4 Both algorithms on one DAG

Vertices $a, b, c, d, e$ in that insertion order. Directed edges $a \to c$, $a \to d$, $b \to d$, $c \to e$, $d \to e$. There is no cycle: every edge moves toward $e$, and nothing returns.

```text
a: c, d
b: d
c: e
d: e
e:        (no neighbors)
```

Depth-first search, outer loop $a$ then $b$ then the rest:

| Vertex | Discovery | Finish | What happened |
| --- | --- | --- | --- |
| $a$ | 1 | 8 | starts the first tree |
| $c$ | 2 | 5 | tree edge $a \to c$ |
| $e$ | 3 | 4 | tree edge $c \to e$, then $e$ finishes |
| $d$ | 6 | 7 | tree edge $a \to d$; $d \to e$ meets black $e$, a cross edge |
| $b$ | 9 | 10 | a new tree; $b \to d$ meets black $d$, a cross edge |

No back edge appears. Finish times in decreasing order are $b$ at $10$, $a$ at $8$, $d$ at $7$, $c$ at $5$, $e$ at $4$. The finish-time order is

$$
b,\ a,\ d,\ c,\ e.
$$

Check the edges: $a$ precedes $c$ and $d$, $b$ precedes $d$, and both $c$ and $d$ precede $e$.

Kahn's algorithm starts from the in-degrees. The edge tails contribute

$$
\mathrm{in}(a) = 0,\ \mathrm{in}(b) = 0,\ \mathrm{in}(c) = 1,\ \mathrm{in}(d) = 2,\ \mathrm{in}(e) = 2.
$$

| Processed | Queue afterward | In-degrees that changed |
| --- | --- | --- |
| start | $a, b$ | the two zeros, in insertion order |
| $a$ | $b, c$ | $\mathrm{in}(c)$ falls $1 \to 0$, so $c$ is enqueued; $\mathrm{in}(d)$ falls $2 \to 1$ |
| $b$ | $c, d$ | $\mathrm{in}(d)$ falls $1 \to 0$, so $d$ is enqueued |
| $c$ | $d$ | $\mathrm{in}(e)$ falls $2 \to 1$ |
| $d$ | $e$ | $\mathrm{in}(e)$ falls $1 \to 0$, so $e$ is enqueued |
| $e$ | empty |  |

The Kahn order is $a, b, c, d, e$. It is a topological order, and it is not the finish-time order. Both are correct. They differ because several pairs of vertices have no edge between them. In particular $a$ and $b$ are incomparable, and so are $c$ and $d$.

Now add the edge $e \to b$. The in-degrees become $\mathrm{in}(a) = 0$, $\mathrm{in}(b) = 1$, $\mathrm{in}(c) = 1$, $\mathrm{in}(d) = 2$, $\mathrm{in}(e) = 2$. The queue starts as $(a)$. Processing $a$ reduces $\mathrm{in}(c)$ to $0$ and $\mathrm{in}(d)$ to $1$, and enqueues $c$. Processing $c$ reduces $\mathrm{in}(e)$ to $1$. The queue is then empty. The vertices $b$, $d$, and $e$ are unprocessed. They are exactly the cycle $b \to d \to e \to b$. This is the preceding theorem, on a five-vertex graph: the algorithm did not fail by running out of time. The residual in-degree of each cycle vertex stayed positive.

---

## 9. Strongly connected components

### 9.1 The component graph is a DAG

Recall that a strongly connected component is a maximal set of vertices inside which every vertex can reach every other by directed paths. The **component graph** $G^{\mathrm{SCC}}$ has one vertex per strongly connected component of $G$. It has an edge from component $C$ to a different component $C'$ when $G$ has at least one edge from a vertex of $C$ to a vertex of $C'$. Parallel edges in $G^{\mathrm{SCC}}$ are collapsed: the component graph is simple.

**Lemma (The component graph is a DAG).** $G^{\mathrm{SCC}}$ has no cycle.

**Proof.** Suppose $C_0, C_1, \ldots, C_k = C_0$ were a cycle of components, $k \ge 1$. Take any vertex $x$ in $C_i$ and any vertex $y$ in $C_{i+1}$. There is an edge from some vertex of $C_i$ to some vertex of $C_{i+1}$, and inside each component every vertex reaches every other. So $x$ reaches $y$. Repeating around the cycle, every vertex in every $C_i$ reaches every vertex in every $C_j$. Those components would be one strongly connected set, contradicting that distinct components were chosen. $\square$

A consequence, already proved for every DAG, is that $G^{\mathrm{SCC}}$ has a source component, with no incoming component edge, and a sink component, with no outgoing component edge.

The **transpose** $G^{T}$ is the digraph with the same vertices and with every edge reversed: $(u, v)$ is an edge of $G^{T}$ exactly when $(v, u)$ is an edge of $G$. Build it by scanning the adjacency lists of $G$ in vertex order and appending each reverse edge. The scan is $\Theta(n + m)$, and $G^{T}$ is an adjacency-list graph.

Reversal preserves strong connectivity inside a component. A directed path from $x$ to $y$ becomes a directed path from $y$ to $x$ in the transpose, so each strongly connected component of $G$ is a strongly connected component of $G^{T}$, and the component graph of $G^{T}$ is the transpose of the component graph of $G$.

### 9.2 Finish times order the components

Run depth-first search on $G$, the original digraph. For a component $C$, write $f(C)$ for the largest finish time of any vertex in $C$, and write $d(C)$ for the smallest discovery time of any vertex in $C$.

**Lemma (Finish times order the components).** Let $C$ and $C'$ be distinct strongly connected components, and suppose $G$ has an edge from $C$ to $C'$. Then $f(C) > f(C')$.

This is the key lemma. Kosaraju's algorithm is a way of reading it. The proof is the white-path theorem applied to whichever component is discovered first.

**Proof.** Let $x$ be the first vertex discovered, among all vertices of $C \cup C'$. Two cases arise, according to which component contains $x$.

Case 1: $x$ belongs to $C$, so $d(C) < d(C')$. At time $d[x]$ every vertex of $C$ and of $C'$ is white, except that $x$ itself has just been discovered. Inside $C$, every vertex is reachable from $x$ by a path that stays in $C$, and those other vertices are white. There is also an edge from some vertex of $C$ to some vertex of $C'$, and inside $C'$ every vertex is reachable from that entry vertex. Concatenating gives a path from $x$ to any chosen vertex of $C \cup C'$ whose intermediate vertices are white at time $d[x]$. The white-path theorem says that every vertex of both components becomes a descendant of $x$. The parenthesis theorem then says that $x$ finishes after all of them. Therefore $f(C) \ge f[x] > f(C')$. In fact $f(C) = f[x]$.

Case 2: $x$ belongs to $C'$, so $d(C') < d(C)$. The same white-path argument, applied inside $C'$ only, shows that every vertex of $C'$ becomes a descendant of $x$, so $f(C') = f[x]$. There is no path from $C'$ to $C$. If there were, together with the assumed edge from $C$ to $C'$ and the strong connectivity of each side, the two components would be one. So no vertex of $C$ is discovered during the call on $x$. Every vertex of $C$ is still white when $x$ finishes. Whichever vertex of $C$ is discovered first is discovered at a time strictly greater than $f[x]$, and its own finish time is later still. Therefore $f(C) > f[x] = f(C')$. $\square$

Along every edge of the component graph, finish time strictly decreases. That is a second proof that the component graph is a DAG: a cycle of components would force a finish time to be strictly greater than itself.

**Corollary (Edges of the transpose).** If $G^{T}$ has an edge from component $C$ to a different component $C'$, then $f(C) < f(C')$.

**Proof.** An edge of $G^{T}$ from $C$ to $C'$ is an edge of $G$ from $C'$ to $C$. The lemma, applied to that edge of $G$, gives $f(C') > f(C)$. $\square$

In $G$, edges of the component graph run from a later finish time to an earlier one. In $G^{T}$, edges of the component graph run from an earlier finish time to a later one. The component of globally maximum finish time is therefore a source of $G^{\mathrm{SCC}}$ and a sink of the component graph of $G^{T}$: nothing in $G^{T}$ leaves it, because a leaving edge would require a component of still larger finish time.

### 9.3 Kosaraju's algorithm

**Kosaraju's algorithm** computes the strongly connected components.

```text
Kosaraju(G)
  run DFS(G) and record the vertices in decreasing order of finish time, as the list L
  build the transpose G^T
  run DFS on G^T, but let the outer loop follow L rather than the insertion order
  output each tree of that second forest as one strongly connected component
```

The first search is $\Theta(n + m)$. The transpose is $\Theta(n + m)$. The second search is $\Theta(n + m)$. The total is $\Theta(n + m)$.

The decreasing list $L$ is the push-and-reverse list of Section 5.5. It is not a comparison sort.

Sedgewick and Wayne, Section 4.2, describe the same partition under the name Kosaraju–Sharir, with the two passes swapped: the first search runs on the transpose, and the second search runs on the original graph in the resulting reverse-finish order. Reversing every edge twice returns the original graph, so that presentation computes the same components. This lecture and the laboratory use the order above, which is the order in Cormen, Leiserson, Rivest, and Stein, Section 20.5: finish times on $G$, then depth-first search on $G^{T}$.

**Theorem (Kosaraju's algorithm).** Each tree grown by the second depth-first search is exactly one strongly connected component of $G$.

**Proof sketch.** The argument is an induction on the number of components. The inductive step is the finish-time lemma; the bookkeeping that deletion preserves the lemma is named at the end of the sketch.

The first vertex $x$ of $L$ has the maximum finish time in $G$. Let $C$ be its component. Then $f(C)$ is the maximum of $f(\cdot)$ over all components. By the corollary, $G^{T}$ has no edge from $C$ to a different component. In the second search, which runs on $G^{T}$, every neighbor of a vertex of $C$ that lies outside $C$ fails to exist. The search that starts at $x$ therefore never leaves $C$.

It does visit all of $C$. The transpose of a strongly connected component is strongly connected, so every vertex of $C$ is reachable from $x$ inside the induced subdigraph of $C$ in $G^{T}$, and those vertices are still white. The second search, started at $x$, discovers exactly $C$. That tree is the first component.

Delete $C$. The remaining digraph has the remaining components, and every edge among them is an edge of the original graph, so the finish-time lemma still applies to them with the finish times already computed. The next white vertex in $L$ is a vertex of maximum finish time among what remains. The same paragraph applies to the induced subdigraph of the remaining vertices in $G^{T}$. By induction, every subsequent tree is one remaining component.

What this sketch treats as bookkeeping, rather than rewriting in full, is the formal statement that "the induced subdigraph on the still-white vertices" is the right object for the inductive hypothesis. No new edge is created by deletion, and no finish time is recomputed, so the inequality $f(C) > f(C')$ for an original edge from $C$ to $C'$ remains available among the survivors. That is the whole gap between the sketch and a fully written induction. $\square$

The order in which the second search starts its trees is decreasing order of $f(C)$. Edges of $G^{\mathrm{SCC}}$ run from larger $f$ to smaller $f$, so that start-order is a topological order of the component graph of $G$. It is a reverse topological order of the component graph of $G^{T}$, which is consistent with the second search being unable to leave a component along a transpose edge: those edges point toward components that have already been finished, because they point toward larger finish times.

### 9.4 Why the order cannot be arbitrary

Two vertices, inserted as $a$ then $b$, and one edge $a \to b$. The components are $\{a\}$ and $\{b\}$.

Depth-first search discovers $a$ at time $1$, discovers $b$ at time $2$, finishes $b$ at time $3$, and finishes $a$ at time $4$. Decreasing finish order is $a$, then $b$. The transpose has the single edge $b \to a$, so its lists are $a:$ empty and $b: a$.

The second search starts at $a$ and cannot move. The tree is $\{a\}$. It then starts at $b$, whose only neighbor $a$ is black. The tree is $\{b\}$. The partition is correct.

If the second search ignores finish times and starts at $b$, the edge $b \to a$ of the transpose is still present and $a$ is white. One tree contains both vertices. The algorithm reports a single component, which is wrong. Decreasing finish time is not a presentation choice. It is the reason a sink of the transpose is started before the vertices that can reach it in the transpose.

### 9.5 A full trace with three components

Vertices $a, b, c, d, e$ in that order. Edges

$$
a \to b,\quad b \to a,\quad b \to c,\quad c \to d,\quad d \to e,\quad e \to d.
$$

```text
a ⇄ b → c → d ⇄ e
```

The set $\{a, b\}$ is strongly connected by the $2$-cycle. The set $\{d, e\}$ is strongly connected by the $2$-cycle. The vertex $c$ can reach $\{d, e\}$ and cannot return, and $\{a, b\}$ can reach $c$ and cannot return. The three components are $\{a, b\}$, $\{c\}$, and $\{d, e\}$. The component graph is the path

$$
\{a, b\} \to \{c\} \to \{d, e\}.
$$

First depth-first search, on $G$. The lists are $a: b$; $b: a, c$; $c: d$; $d: e$; $e: d$.

| Vertex | Discovery | Finish |
| --- | --- | --- |
| $a$ | 1 | 10 |
| $b$ | 2 | 9 |
| $c$ | 3 | 8 |
| $d$ | 4 | 7 |
| $e$ | 5 | 6 |

One tree contains everyone, because $a$ reaches every vertex. The back edges are $b \to a$, into gray $a$, and $e \to d$, into gray $d$. Decreasing finish order is $a, b, c, d, e$, with finish times $10, 9, 8, 7, 6$. Component finish times: $f(\{a, b\}) = 10$, $f(\{c\}) = 8$, $f(\{d, e\}) = 7$. They strictly decrease along $\{a, b\} \to \{c\} \to \{d, e\}$, as the lemma requires.

The transpose is built by scanning vertices $a, b, c, d, e$ and appending each reversed edge:

| Scan | Reverse edge appended | List that grows |
| --- | --- | --- |
| $a \to b$ | $b \to a$ | $b$ receives $a$ |
| $b \to a$ | $a \to b$ | $a$ receives $b$ |
| $b \to c$ | $c \to b$ | $c$ receives $b$ |
| $c \to d$ | $d \to c$ | $d$ receives $c$ |
| $d \to e$ | $e \to d$ | $e$ receives $d$ |
| $e \to d$ | $d \to e$ | $d$ receives $e$ |

```text
a: b
b: a
c: b
d: c, e
e: d
```

Second depth-first search, on this transpose, outer loop $a, b, c, d, e$.

- Start at $a$, which is white. The neighbor $b$ is white. Discover $b$. The only neighbor of $b$ is $a$, which is gray. Finish $b$, then finish $a$. The tree is $a, b$.
- $b$ is already black. Skip it.
- Start at $c$. Its neighbor $b$ is black. The tree is $c$ alone.
- Start at $d$. The neighbor $c$ is black. The neighbor $e$ is white. Discover $e$. The neighbor of $e$ is $d$, which is gray. Finish $e$, then finish $d$. The tree is $d, e$.
- $e$ is already black.

The components, in the order the second search grows them, are $\{a, b\}$, $\{c\}$, and $\{d, e\}$. That is a topological order of the component graph of $G$. The search that started at $a$ did not walk into $c$, because the edge $b \to c$ of $G$ points the other way in the transpose: it has become $c \to b$, and $c$ has not been started. This is the sink property of $\{a, b\}$ inside $G^{T}$.

---

## 10. When breadth-first search is the wrong shortest-path algorithm

Breadth-first search computes $\delta(s, v)$, the minimum number of edges on a path from $s$ to $v$. A **weight** is a number $w(u, v)$ stored on the edge $(u, v)$. The **weight of a path** is the sum of the weights of its edges. The weighted shortest-path problem asks for the minimum path weight, not the minimum number of edges.

Those two minima select different paths as soon as the weights are allowed to differ. Consider a digraph with vertices $s, a, t$ and edges

$$
s \xrightarrow{1} a,\quad a \xrightarrow{1} t,\quad s \xrightarrow{3} t.
$$

Breadth-first search from $s$ discovers $t$ along the direct edge and sets $d[t] = 1$. The path $s, a, t$ has two edges, so it loses on edge count. On weights, the direct edge costs $3$ and $s, a, t$ costs $1 + 1 = 2$. The minimum-weight path is the path with more edges.

Nothing inside breadth-first search can repair this. The algorithm never reads $w$. Its inductive claim is about counts of edges. Replacing the claim with a sum of weights makes the queue lemma false: a vertex discovered late, along many cheap edges, may deserve a smaller distance than a vertex discovered early along one expensive edge, and the early vertex has already left the queue.

Lecture 13 owns the repair, under three restrictions that must not be collapsed into one algorithm.

- Nonnegative weights: Dijkstra's algorithm, using the indexed binary heap of Lecture 10.
- Weights that may be negative, with no negative cycle reachable from the source: the Bellman–Ford algorithm.
- A DAG, with weights of either sign: one pass in a topological order.

If every weight equals the same positive constant, the minimum weight is that constant times $\delta(s, v)$, and breadth-first search solves the weighted problem. A single edge of a different weight is enough to leave that special case. Minimum spanning trees and union-find are also Lecture 13. They are not substitutions for the unweighted distances of this lecture.

---

## Laboratory

Work the four traces on paper before you read the program. The program asserts those same numbers. Cover each table in the lecture, produce the next row yourself, and only then uncover it.

1. Section 3. From $s$, write the queue after every dequeue and the final distances of $s, a, b, c, d, e$. Then write the parent-pointer path from $s$ to $e$.
2. Section 5 and Section 6. On the directed graph with lists $a: b, c, d$; $b: c, e$; $c: a$; $d: e$; $e: b$, write discovery and finish times and the class of each of the eight edges.
3. Section 8. On the DAG with edges $a \to c$, $a \to d$, $b \to d$, $c \to e$, $d \to e$, write both the decreasing-finish order and the Kahn order, including the queue after each step of Kahn's algorithm.
4. Section 9. On the three-component digraph, write the first-search finish times, the six lines of the transpose construction, and the trees of the second search.

Then do these problems, still before reading the program.

5. Add an isolated vertex $z$ to the undirected graph of Section 3 and state $d[z]$ and $\mathrm{parent}[z]$ after breadth-first search from $s$.
6. Run the undirected cycle procedure on the triangle $x, y, z$ with the lists in Section 7.3. Name the first gray non-parent and the cycle returned by the parent walk. Then run it on the Section 3 graph and name that cycle.
7. Add $e \to b$ to the DAG of Section 8 and list the vertices Kahn's algorithm leaves unprocessed.
8. On the two-vertex digraph with the single edge $a \to b$, write the components produced by the legal second-search order, and write the incorrect tree produced if the second search starts at $b$.

The program below checks problems 1 through 8. Type it, or type your own implementation of the same specification, and run it with Node. Then change one expected distance so that an assertion must fail, confirm that it fails, and restore it. A run that prints `ALL TESTS PASSED` has executed the traces. It has not replaced the proofs.

## LABORATORY PROGRAM

```javascript
import assert from 'node:assert/strict';

// Vertices iterate in insertion order. Each neighbor array is append-only,
// so neighbors iterate in the order of successful addEdge calls.
// An undirected edge {u, v} is stored twice: v is appended to u, and u is
// appended to v. A duplicate simple edge is ignored. A loop is rejected.
// Dequeue advances a head index. It does not use Array.prototype.shift.
// Decreasing finish order is push-on-finish followed by reversal, so the
// extra cost is linear and the graph algorithms stay Theta(n + m).

const WHITE = 'white';
const GRAY = 'gray';
const BLACK = 'black';

class Queue {
  constructor() {
    this.items = [];
    this.head = 0;
  }

  enqueue(value) {
    this.items.push(value);
  }

  dequeue() {
    if (this.head >= this.items.length) {
      throw new Error('dequeue from an empty queue');
    }
    const value = this.items[this.head];
    this.head += 1;
    return value;
  }

  isEmpty() {
    return this.head >= this.items.length;
  }
}

class Graph {
  constructor(directed) {
    this.directed = directed;
    this.adj = new Map();
  }

  addVertex(vertex) {
    if (!this.adj.has(vertex)) {
      this.adj.set(vertex, []);
    }
  }

  vertices() {
    return Array.from(this.adj.keys());
  }

  neighbors(vertex) {
    const list = this.adj.get(vertex);
    if (list === undefined) {
      throw new Error('unknown vertex');
    }
    return list;
  }

  addEdge(u, v) {
    if (!this.adj.has(u) || !this.adj.has(v)) {
      throw new Error('unknown vertex');
    }
    if (u === v) {
      throw new Error('a simple graph has no loop');
    }
    const fromU = this.adj.get(u);
    if (fromU.includes(v)) {
      return;
    }
    fromU.push(v);
    if (!this.directed) {
      this.adj.get(v).push(u);
    }
  }

  breadthFirstSearch(source) {
    if (!this.adj.has(source)) {
      throw new Error('unknown source');
    }
    const color = new Map();
    const dist = new Map();
    const parent = new Map();
    for (const vertex of this.vertices()) {
      color.set(vertex, WHITE);
      dist.set(vertex, Infinity);
      parent.set(vertex, null);
    }
    color.set(source, GRAY);
    dist.set(source, 0);
    const queue = new Queue();
    queue.enqueue(source);
    const order = [];
    while (!queue.isEmpty()) {
      const u = queue.dequeue();
      order.push(u);
      for (const v of this.neighbors(u)) {
        if (color.get(v) === WHITE) {
          color.set(v, GRAY);
          dist.set(v, dist.get(u) + 1);
          parent.set(v, u);
          queue.enqueue(v);
        }
      }
      color.set(u, BLACK);
    }
    return { dist, parent, order };
  }

  path(source, target) {
    const search = this.breadthFirstSearch(source);
    const reversed = [];
    let current = target;
    const seen = new Set();
    while (current !== null && !seen.has(current)) {
      seen.add(current);
      reversed.push(current);
      if (current === source) {
        reversed.reverse();
        return reversed;
      }
      current = search.parent.get(current);
    }
    return null;
  }

  depthFirstSearch() {
    if (!this.directed) {
      throw new Error('timestamp search classifies directed edges');
    }
    const color = new Map();
    const discovery = new Map();
    const finish = new Map();
    const parent = new Map();
    const edges = [];
    const finishedIncreasing = [];
    let time = 0;
    for (const vertex of this.vertices()) {
      color.set(vertex, WHITE);
      parent.set(vertex, null);
    }
    const visit = (u) => {
      time += 1;
      discovery.set(u, time);
      color.set(u, GRAY);
      for (const v of this.neighbors(u)) {
        const tone = color.get(v);
        if (tone === WHITE) {
          edges.push({ from: u, to: v, kind: 'tree' });
          parent.set(v, u);
          visit(v);
        } else if (tone === GRAY) {
          edges.push({ from: u, to: v, kind: 'back' });
        } else if (discovery.get(u) < discovery.get(v)) {
          edges.push({ from: u, to: v, kind: 'forward' });
        } else {
          edges.push({ from: u, to: v, kind: 'cross' });
        }
      }
      color.set(u, BLACK);
      time += 1;
      finish.set(u, time);
      finishedIncreasing.push(u);
    };
    for (const vertex of this.vertices()) {
      if (color.get(vertex) === WHITE) {
        visit(vertex);
      }
    }
    return {
      discovery,
      finish,
      parent,
      edges,
      decreasingFinish: finishedIncreasing.slice().reverse(),
    };
  }

  directedCycle() {
    if (!this.directed) {
      throw new Error('directed cycle search expects a directed graph');
    }
    const color = new Map();
    const parent = new Map();
    for (const vertex of this.vertices()) {
      color.set(vertex, WHITE);
      parent.set(vertex, null);
    }
    let cycle = null;
    const visit = (u) => {
      color.set(u, GRAY);
      for (const v of this.neighbors(u)) {
        if (cycle !== null) {
          return;
        }
        if (color.get(v) === WHITE) {
          parent.set(v, u);
          visit(v);
        } else if (color.get(v) === GRAY) {
          const chain = [v];
          let cursor = u;
          while (cursor !== v) {
            chain.push(cursor);
            cursor = parent.get(cursor);
          }
          chain.push(v);
          chain.reverse();
          cycle = chain;
          return;
        }
      }
      color.set(u, BLACK);
    };
    for (const vertex of this.vertices()) {
      if (color.get(vertex) === WHITE && cycle === null) {
        visit(vertex);
      }
    }
    return cycle;
  }

  undirectedCycle() {
    if (this.directed) {
      throw new Error('undirected cycle search expects an undirected graph');
    }
    const color = new Map();
    const parent = new Map();
    for (const vertex of this.vertices()) {
      color.set(vertex, WHITE);
      parent.set(vertex, null);
    }
    let cycle = null;
    const visit = (u) => {
      color.set(u, GRAY);
      for (const v of this.neighbors(u)) {
        if (cycle !== null) {
          return;
        }
        if (v === parent.get(u)) {
          continue;
        }
        if (color.get(v) === WHITE) {
          parent.set(v, u);
          visit(v);
        } else {
          const chain = [v];
          let cursor = u;
          while (cursor !== v) {
            chain.push(cursor);
            cursor = parent.get(cursor);
          }
          chain.push(v);
          chain.reverse();
          cycle = chain;
          return;
        }
      }
      color.set(u, BLACK);
    };
    for (const vertex of this.vertices()) {
      if (color.get(vertex) === WHITE && cycle === null) {
        visit(vertex);
      }
    }
    return cycle;
  }

  topologicalSortByFinish() {
    if (!this.directed) {
      throw new Error('topological sort expects a directed graph');
    }
    const search = this.depthFirstSearch();
    if (search.edges.some((edge) => edge.kind === 'back')) {
      return null;
    }
    return search.decreasingFinish;
  }

  topologicalSortKahn() {
    if (!this.directed) {
      throw new Error('topological sort expects a directed graph');
    }
    const indegree = new Map();
    for (const vertex of this.vertices()) {
      indegree.set(vertex, 0);
    }
    for (const vertex of this.vertices()) {
      for (const next of this.neighbors(vertex)) {
        indegree.set(next, indegree.get(next) + 1);
      }
    }
    const queue = new Queue();
    for (const vertex of this.vertices()) {
      if (indegree.get(vertex) === 0) {
        queue.enqueue(vertex);
      }
    }
    const order = [];
    while (!queue.isEmpty()) {
      const u = queue.dequeue();
      order.push(u);
      for (const v of this.neighbors(u)) {
        indegree.set(v, indegree.get(v) - 1);
        if (indegree.get(v) === 0) {
          queue.enqueue(v);
        }
      }
    }
    if (order.length !== this.vertices().length) {
      return null;
    }
    return order;
  }

  transpose() {
    if (!this.directed) {
      throw new Error('transpose expects a directed graph');
    }
    const reversed = new Graph(true);
    for (const vertex of this.vertices()) {
      reversed.addVertex(vertex);
    }
    for (const vertex of this.vertices()) {
      for (const next of this.neighbors(vertex)) {
        reversed.addEdge(next, vertex);
      }
    }
    return reversed;
  }

  stronglyConnectedComponents() {
    if (!this.directed) {
      throw new Error('strongly connected components expect a directed graph');
    }
    const first = this.depthFirstSearch();
    const reversed = this.transpose();
    const color = new Map();
    for (const vertex of reversed.vertices()) {
      color.set(vertex, WHITE);
    }
    const components = [];
    const visit = (u, bucket) => {
      color.set(u, GRAY);
      bucket.push(u);
      for (const v of reversed.neighbors(u)) {
        if (color.get(v) === WHITE) {
          visit(v, bucket);
        }
      }
      color.set(u, BLACK);
    };
    for (const vertex of first.decreasingFinish) {
      if (color.get(vertex) === WHITE) {
        const bucket = [];
        visit(vertex, bucket);
        components.push(bucket);
      }
    }
    return components;
  }
}

function build(directed, names, edges) {
  const graph = new Graph(directed);
  for (const name of names) {
    graph.addVertex(name);
  }
  for (const [u, v] of edges) {
    graph.addEdge(u, v);
  }
  return graph;
}

const layers = build(false, ['s', 'a', 'b', 'c', 'd', 'e'], [
  ['s', 'a'],
  ['s', 'b'],
  ['a', 'c'],
  ['a', 'd'],
  ['b', 'd'],
  ['d', 'e'],
]);
assert.deepEqual(layers.neighbors('s'), ['a', 'b']);
assert.deepEqual(layers.neighbors('a'), ['s', 'c', 'd']);
assert.deepEqual(layers.neighbors('b'), ['s', 'd']);
assert.deepEqual(layers.neighbors('c'), ['a']);
assert.deepEqual(layers.neighbors('d'), ['a', 'b', 'e']);
assert.deepEqual(layers.neighbors('e'), ['d']);
layers.addEdge('s', 'a');
assert.deepEqual(layers.neighbors('s'), ['a', 'b']);
layers.addVertex('z');
const breadth = layers.breadthFirstSearch('s');
assert.equal(breadth.dist.get('s'), 0);
assert.equal(breadth.dist.get('a'), 1);
assert.equal(breadth.dist.get('b'), 1);
assert.equal(breadth.dist.get('c'), 2);
assert.equal(breadth.dist.get('d'), 2);
assert.equal(breadth.dist.get('e'), 3);
assert.equal(breadth.dist.get('z'), Infinity);
assert.equal(breadth.parent.get('a'), 's');
assert.equal(breadth.parent.get('b'), 's');
assert.equal(breadth.parent.get('c'), 'a');
assert.equal(breadth.parent.get('d'), 'a');
assert.equal(breadth.parent.get('e'), 'd');
assert.equal(breadth.parent.get('z'), null);
assert.deepEqual(breadth.order, ['s', 'a', 'b', 'c', 'd', 'e']);
assert.deepEqual(layers.path('s', 'e'), ['s', 'a', 'd', 'e']);
assert.equal(layers.path('s', 'z'), null);
assert.deepEqual(layers.undirectedCycle(), ['s', 'a', 'd', 'b', 's']);

const tree = build(false, ['t', 'u', 'v'], [
  ['t', 'u'],
  ['t', 'v'],
]);
assert.equal(tree.undirectedCycle(), null);
const edgeOnly = build(false, ['p', 'q'], [['p', 'q']]);
assert.equal(edgeOnly.undirectedCycle(), null);

const triangle = build(false, ['x', 'y', 'z'], [
  ['x', 'y'],
  ['y', 'z'],
  ['z', 'x'],
]);
assert.deepEqual(triangle.neighbors('x'), ['y', 'z']);
assert.deepEqual(triangle.neighbors('y'), ['x', 'z']);
assert.deepEqual(triangle.neighbors('z'), ['y', 'x']);
assert.deepEqual(triangle.undirectedCycle(), ['x', 'y', 'z', 'x']);

const timed = build(true, ['a', 'b', 'c', 'd', 'e'], [
  ['a', 'b'],
  ['a', 'c'],
  ['a', 'd'],
  ['b', 'c'],
  ['b', 'e'],
  ['c', 'a'],
  ['d', 'e'],
  ['e', 'b'],
]);
const depth = timed.depthFirstSearch();
const expectTime = {
  a: [1, 10],
  b: [2, 7],
  c: [3, 4],
  d: [8, 9],
  e: [5, 6],
};
for (const [vertex, pair] of Object.entries(expectTime)) {
  assert.equal(depth.discovery.get(vertex), pair[0]);
  assert.equal(depth.finish.get(vertex), pair[1]);
}
assert.equal(depth.parent.get('b'), 'a');
assert.equal(depth.parent.get('c'), 'b');
assert.equal(depth.parent.get('e'), 'b');
assert.equal(depth.parent.get('d'), 'a');
assert.ok(
  depth.discovery.get('a') < depth.discovery.get('b') &&
    depth.discovery.get('b') < depth.discovery.get('c') &&
    depth.discovery.get('c') < depth.finish.get('c') &&
    depth.finish.get('c') < depth.discovery.get('e') &&
    depth.discovery.get('e') < depth.finish.get('e') &&
    depth.finish.get('e') < depth.finish.get('b') &&
    depth.finish.get('b') < depth.discovery.get('d') &&
    depth.discovery.get('d') < depth.finish.get('d') &&
    depth.finish.get('d') < depth.finish.get('a'),
);
assert.deepEqual(depth.edges, [
  { from: 'a', to: 'b', kind: 'tree' },
  { from: 'b', to: 'c', kind: 'tree' },
  { from: 'c', to: 'a', kind: 'back' },
  { from: 'b', to: 'e', kind: 'tree' },
  { from: 'e', to: 'b', kind: 'back' },
  { from: 'a', to: 'c', kind: 'forward' },
  { from: 'a', to: 'd', kind: 'tree' },
  { from: 'd', to: 'e', kind: 'cross' },
]);
assert.deepEqual(timed.directedCycle(), ['a', 'b', 'c', 'a']);
assert.equal(timed.topologicalSortByFinish(), null);
assert.equal(timed.topologicalSortKahn(), null);

const twoCycle = build(true, ['a', 'b'], [
  ['a', 'b'],
  ['b', 'a'],
]);
assert.deepEqual(twoCycle.directedCycle(), ['a', 'b', 'a']);

const dag = build(true, ['a', 'b', 'c', 'd', 'e'], [
  ['a', 'c'],
  ['a', 'd'],
  ['b', 'd'],
  ['c', 'e'],
  ['d', 'e'],
]);
assert.equal(dag.directedCycle(), null);
assert.deepEqual(dag.topologicalSortByFinish(), ['b', 'a', 'd', 'c', 'e']);
assert.deepEqual(dag.topologicalSortKahn(), ['a', 'b', 'c', 'd', 'e']);

const cyclic = build(true, ['a', 'b', 'c', 'd', 'e'], [
  ['a', 'c'],
  ['a', 'd'],
  ['b', 'd'],
  ['c', 'e'],
  ['d', 'e'],
  ['e', 'b'],
]);
assert.equal(cyclic.topologicalSortKahn(), null);
assert.equal(cyclic.topologicalSortByFinish(), null);

const components = build(true, ['a', 'b', 'c', 'd', 'e'], [
  ['a', 'b'],
  ['b', 'a'],
  ['b', 'c'],
  ['c', 'd'],
  ['d', 'e'],
  ['e', 'd'],
]);
const transposed = components.transpose();
assert.deepEqual(transposed.neighbors('a'), ['b']);
assert.deepEqual(transposed.neighbors('b'), ['a']);
assert.deepEqual(transposed.neighbors('c'), ['b']);
assert.deepEqual(transposed.neighbors('d'), ['c', 'e']);
assert.deepEqual(transposed.neighbors('e'), ['d']);
assert.deepEqual(components.stronglyConnectedComponents(), [
  ['a', 'b'],
  ['c'],
  ['d', 'e'],
]);

const separated = build(true, ['a', 'b'], [['a', 'b']]);
assert.deepEqual(separated.stronglyConnectedComponents(), [['a'], ['b']]);

assert.throws(() => layers.addEdge('s', 's'));
assert.throws(() => build(true, ['a'], []).addEdge('a', 'b'));

console.log('ALL TESTS PASSED');
```

---

## Common mistakes

**Wrong idea:** the sum of the degrees equals the number of edges.
**Correction:** each edge has two endpoints, so the handshaking lemma says the sum equals $2m$. A degree sum of $9$ cannot occur.

**Wrong idea:** an adjacency matrix occupies space proportional to the number of edges.
**Correction:** the matrix stores an $n \times n$ array, which is $\Theta(n^2)$ cells, including the cells that hold $0$.

**Wrong idea:** listing the neighbors of $u$ in an adjacency list takes $\Theta(n)$ time.
**Correction:** the list of $u$ contains exactly the neighbors of $u$. The scan is $\Theta(\deg(u))$ in an undirected graph and $\Theta(\mathrm{out}(u))$ in a digraph. The $\Theta(n)$ scan is the matrix row.

**Wrong idea:** an undirected edge can be stored only in the list of the endpoint named first.
**Correction:** a search sitting at the other endpoint must see the edge. Store it in both lists. The sum of the list lengths is $2m$.

**Wrong idea:** breadth-first distance is a weighted length.
**Correction:** $d[v]$ counts edges. The algorithm does not read weights. Section 10 is the counterexample, and Lecture 13 owns the weighted problem.

**Wrong idea:** the breadth-first queue can hold vertices from three distances at once.
**Correction:** the queue lemma says the tail's distance is at most the head's distance plus $1$, and distances along the queue are nondecreasing. At most two consecutive integers appear.

**Wrong idea:** `Array.prototype.shift` is a constant-time dequeue.
**Correction:** `shift` moves every later array entry. The laboratory queue advances a head index so that dequeue is $\Theta(1)$ and the $\Theta(n + m)$ bound survives.

**Wrong idea:** discovery time is the distance from the source.
**Correction:** discovery time is the clock tick at which depth-first search paints the vertex gray. It depends on the order of vertices and of neighbors. On the traced digraph, $e$ has discovery time $5$ and is not at distance $5$ from $a$ in any sense the lecture defined. Finish time is not a distance either.

**Wrong idea:** every edge into a black vertex is a cross edge.
**Correction:** if the black vertex was discovered after the current vertex, the edge is forward. If it was discovered before, the edge is cross. On the trace, $a \to c$ is forward and $d \to e$ is cross.

**Wrong idea:** a cross edge is the witness of a directed cycle.
**Correction:** the witness is a back edge to a gray vertex. On the trace, the cycles are $a, b, c, a$ from the back edge $c \to a$, and $b, e, b$ from the back edge $e \to b$. The cross edge $d \to e$ is not the test.

**Wrong idea:** in an undirected graph, the adjacency entry that points at the parent is a cycle.
**Correction:** that entry is the tree edge stored at the child. Skip the parent. A cycle is a different already-discovered neighbor. Without the exception, the single edge $\{p, q\}$ would be reported as a cycle.

**Wrong idea:** if Kahn's algorithm stops early, the list it has already produced is a topological order of the whole graph.
**Correction:** a topological order contains every vertex. An unprocessed vertex means a cycle remains. On the DAG with $e \to b$ added, $b$, $d$, and $e$ stay unprocessed.

**Wrong idea:** comparison-sorting the finish times is compatible with a $\Theta(n + m)$ topological sort.
**Correction:** a comparison sort costs $\Theta(n \log n)$. Append each vertex when it finishes and reverse the array. The extra cost is $\Theta(n)$.

**Wrong idea:** the second search of Kosaraju's algorithm may start at any vertex.
**Correction:** the outer loop must follow decreasing finish time from the first search. On the digraph with the single edge $a \to b$, starting the second search at $b$ walks the transpose edge $b \to a$ and merges two components into one tree.

**Wrong idea:** a weakly connected digraph is strongly connected.
**Correction:** weak connectivity forgets directions. Strong connectivity requires a directed path in each direction. The three-component trace is weakly connected and has three strong components.

---

## Examination

Answer from the lecture. Do not consult the answer key until you have written full solutions. Vertex iteration order is the order the vertices are named. Neighbor order is the order written in each list. Undirected lists are already symmetric; you do not insert them a second time.

### 1. Definitions

Define each term in one or two sentences.

(a) Simple path.
(b) Simple cycle in a directed graph.
(c) Strongly connected digraph.
(d) DAG.

### 2. Handshaking

(a) Prove the handshaking lemma for an undirected graph with no loops.
(b) A simple undirected graph has degree sequence $4, 3, 3, 2, 2, 2$. If the graph exists, what is $m$? Show the arithmetic.
(c) Explain why no undirected graph has degree sequence $1, 2, 3, 3$.

### 3. Representation costs

A directed graph has $n = 500$ vertices and $m = 4000$ edges. Use the cell counts from Section 2: a matrix stores $n^2$ entries; a directed adjacency-list representation stores $n$ list heads and $m$ neighbor cells.

(a) How many entries does the adjacency matrix store?
(b) How many heads and neighbor cells do the adjacency lists store, as an expression and as a number?
(c) State the worst-case time to test whether a specific edge $(u, v)$ exists, for the matrix and for the lists. For the lists, express the cost in terms of the out-degree of $u$.
(d) State the time to list every neighbor of $u$, for the matrix and for the lists.
(e) If the same $n$ and $m$ described an undirected graph stored with both copies of each edge, how many neighbor cells would the lists contain, and how many cells is that together with the $n$ heads?

### 4. Breadth-first layers

An undirected graph has adjacency lists

```text
a: b, c
b: a, d, e
c: a, e
d: b, f
e: b, c, f
f: d, e
```

Run breadth-first search from $a$.

(a) Write the queue, with distances, after each dequeue.
(b) Write the distance of every vertex and the three nonempty layers after layer $0$.
(c) Write the parent of each vertex other than $a$, and the shortest path from $a$ to $f$.
(d) Point to one line of your queue trace in which the queue holds two consecutive distances, and name those distances.

### 5. Depth-first times and edge classes

A digraph has vertices $u, v, w, x$ in that outer-loop order and lists

```text
u: v, w
v: w, x
w: u
x: w
```

(a) Write discovery and finish times of all four vertices.
(b) Classify each of the six edges as tree, back, forward, or cross.
(c) From the back edge, write the directed cycle given by the tree path.
(d) Write the parenthesis string of the search.

### 6. Topological order

A DAG has vertices $w, x, y, z$ in that order and lists

```text
w: x, y
x: z
y: z
z:        (no neighbors)
```

(a) Compute the in-degrees and run Kahn's algorithm. Write the queue after each step and the resulting order.
(b) Run depth-first search and write the decreasing-finish order.
(c) For the Kahn order, check each of the four edges and state the positions that show the tail precedes the head.

### 7. A Kosaraju step

A digraph has vertices $p, q, r, s$ in that order and lists

```text
p: q
q: p, r
r: s
s: r
```

(a) Compute discovery and finish times of the first depth-first search, and write the decreasing-finish order.
(b) Build the transpose by scanning vertices in order $p, q, r, s$. Write the four adjacency lists of the transpose.
(c) Run the second search in the order from (a). Write the components as trees, in the order they are grown, and name the vertices inside each tree in discovery order.
(d) State why the tree that starts at $p$ does not contain $r$.

### 8. The wrong distance

A digraph has edges $s \to t$ of weight $10$ and $s \to a \to t$ with weights $1$ and $1$.

(a) What distance does breadth-first search from $s$ assign to $t$, and which path does the parent pointer record if $t$ is the first neighbor of $s$?
(b) What is the minimum path weight from $s$ to $t$?
(c) Which lecture owns the algorithm that computes that weight, and which restriction of that lecture applies to these weights?

### 9. The parent exception

An undirected triangle has lists

```text
a: b, c
b: a, c
c: a, b
```

Depth-first cycle detection starts at $a$.

(a) When a gray non-parent is first seen, name the current vertex and that neighbor.
(b) Write the cycle produced by walking parent pointers and closing the edge.
(c) At vertex $b$, the neighbor $a$ is gray. State why that adjacency entry is skipped.

---

## Answer key

### 1. Definitions

(a) A simple path is a path whose vertices are all distinct. Its length is the number of edges on it.

(b) A simple cycle in a directed graph is a directed path of length at least $1$ that starts and ends at the same vertex and repeats no other vertex. In a simple digraph the length is at least $2$, because a loop is excluded.

(c) A digraph is strongly connected when, for every pair of vertices $x$ and $y$, a directed path from $x$ to $y$ exists.

(d) A DAG is a directed graph that contains no directed cycle.

### 2. Handshaking

(a) Let $I$ be the set of pairs $(v, e)$ in which vertex $v$ is an endpoint of edge $e$. For fixed $v$, the number of such edges is $\deg(v)$, so $|I| = \sum_v \deg(v)$. For fixed $e = \{x, y\}$ with $x \ne y$, the edge contributes exactly the two pairs $(x, e)$ and $(y, e)$, so $|I| = 2m$. Therefore the sum of the degrees equals $2m$.

(b) The sum of the degrees is $4 + 3 + 3 + 2 + 2 + 2$. First $4 + 3 = 7$, then $7 + 3 = 10$, then $10 + 2 = 12$, then $12 + 2 = 14$, then $14 + 2 = 16$. The handshaking lemma says $16 = 2m$, so $m = 8$.

(c) The sum is $1 + 2 + 3 + 3 = 9$, which is odd. The handshaking lemma says every degree sum equals $2m$ and is therefore even. No such undirected graph exists.

### 3. Representation costs

(a) The matrix stores $n^2 = 500 \times 500 = 250000$ entries.

(b) The lists store $n + m = 500 + 4000 = 4500$ cells: $500$ heads and $4000$ neighbor cells.

(c) The matrix test reads one entry and is $\Theta(1)$. The list test scans the out-list of $u$ and is $\Theta(\mathrm{out}(u))$ in the worst case, which occurs when $v$ is absent or stands at the end of the list.

(d) Listing neighbors from the matrix scans a row of length $n$ and is $\Theta(n)$. Listing them from the adjacency list scans a list of length $\mathrm{out}(u)$ and is $\Theta(\mathrm{out}(u))$.

(e) Each undirected edge contributes two neighbor cells, so the lists contain $2m = 2 \times 4000 = 8000$ neighbor cells. Together with $n = 500$ heads, that is $8000 + 500 = 8500$ cells.

### 4. Breadth-first layers

(a) The queue from front to back:

| After dequeueing | Queue |
| --- | --- |
| start, before any dequeue | $a:0$ |
| $a$ | $b:1,\ c:1$ |
| $b$ | $c:1,\ d:2,\ e:2$ |
| $c$ | $d:2,\ e:2$ |
| $d$ | $e:2,\ f:3$ |
| $e$ | $f:3$ |
| $f$ | empty |

From $a$ the search discovers $b$ and then $c$. From $b$ it discovers $d$ and then $e$; $a$ is already discovered. From $c$, both $a$ and $e$ are already discovered. From $d$ it discovers $f$. From $e$, the neighbor $f$ is already gray. From $f$, both neighbors are black.

(b) Distances: $a: 0$, $b: 1$, $c: 1$, $d: 2$, $e: 2$, $f: 3$. Layers after $\{a\}$ are $\{b, c\}$, then $\{d, e\}$, then $\{f\}$.

(c) Parents: $b$ from $a$, $c$ from $a$, $d$ from $b$, $e$ from $b$, $f$ from $d$. The path is $a, b, d, f$, of length $3$.

(d) After $d$ is dequeued, the queue is $e:2,\ f:3$. Those are the consecutive distances $2$ and $3$. After $b$ is dequeued, the queue $c:1,\ d:2,\ e:2$ is the other such moment, with distances $1$ and $2$.

### 5. Depth-first times and edge classes

(a) The clock:

- Discover $u$ at $1$. Discover $v$ at $2$. Discover $w$ at $3$. The edge $w \to u$ meets gray $u$. Finish $w$ at $4$.
- Discover $x$ at $5$. The edge $x \to w$ meets black $w$. Finish $x$ at $6$. Finish $v$ at $7$.
- The edge $u \to w$ meets black $w$. Finish $u$ at $8$.

Times: $u$ is $1/8$, $v$ is $2/7$, $w$ is $3/4$, $x$ is $5/6$.

(b) $u \to v$ tree, $v \to w$ tree, $v \to x$ tree, $w \to u$ back, $u \to w$ forward because $w$ is black and $d[u] = 1 < d[w] = 3$, and $x \to w$ cross because $w$ is black and $d[w] = 3 < d[x] = 5$.

(c) The back edge is $w \to u$. The tree path from $u$ to $w$ is $u, v, w$. The cycle is $u, v, w, u$.

(d) `(u (v (w w) (x x) v) u)`.

### 6. Topological order

(a) In-degrees: $w$ has $0$, $x$ has $1$, $y$ has $1$, $z$ has $2$. The queue starts as $w$. Processing $w$ reduces both $x$ and $y$ from $1$ to $0$ and enqueues $x$ then $y$, so the queue is $x, y$. Processing $x$ reduces $z$ from $2$ to $1$; the queue is $y$. Processing $y$ reduces $z$ from $1$ to $0$ and enqueues $z$. Processing $z$ empties the queue. The Kahn order is $w, x, y, z$.

(b) Depth-first search discovers $w$ at $1$, $x$ at $2$, $z$ at $3$, finishes $z$ at $4$ and $x$ at $5$, discovers $y$ at $6$, sees $z$ already black, finishes $y$ at $7$ and $w$ at $8$. Finish times: $w: 8$, $y: 7$, $x: 5$, $z: 4$. The decreasing-finish order is $w, y, x, z$.

(c) In $w, x, y, z$ the edge $w \to x$ has $w$ in position $1$ and $x$ in position $2$; $w \to y$ has $w$ in position $1$ and $y$ in position $3$; $x \to z$ has $x$ in position $2$ and $z$ in position $4$; $y \to z$ has $y$ in position $3$ and $z$ in position $4$. Each tail has the smaller position.

### 7. A Kosaraju step

(a) Discover $p$ at $1$ and $q$ at $2$. The edge $q \to p$ meets gray $p$. Discover $r$ at $3$ and $s$ at $4$. The edge $s \to r$ meets gray $r$. Finish $s$ at $5$, $r$ at $6$, $q$ at $7$, and $p$ at $8$. Times: $p$ is $1/8$, $q$ is $2/7$, $r$ is $3/6$, $s$ is $4/5$. Decreasing finish order is $p, q, r, s$.

(b) Scanning $p \to q$ appends $p$ to $q$. Scanning $q \to p$ appends $q$ to $p$. Scanning $q \to r$ appends $q$ to $r$. Scanning $r \to s$ appends $r$ to $s$. Scanning $s \to r$ appends $s$ to $r$. The transpose lists are $p: q$; $q: p$; $r: q, s$; $s: r$.

(c) Start at $p$. Discover $q$. The neighbor of $q$ is gray $p$. The first tree is $p, q$. Skip the black vertex $q$. Start at $r$. The neighbor $q$ is black. Discover $s$. The neighbor of $s$ is gray $r$. The second tree is $r, s$. The components are $\{p, q\}$ and $\{r, s\}$.

(d) In the transpose, $p$ points only at $q$, and $q$ points only at $p$. The original edge $q \to r$ has become $r \to q$, which leaves the component of $r$ and enters the component of $q$. There is no transpose edge from $\{p, q\}$ to $\{r, s\}$, because $\{p, q\}$ is a sink of the transpose. Its finish time $8$ is larger than the finish time $6$ of $\{r, s\}$, and transpose edges run toward larger finish times.

### 8. The wrong distance

(a) The direct edge is one edge, so breadth-first search assigns $d[t] = 1$. If $t$ is the first neighbor of $s$, the parent of $t$ is $s$, and the recorded path is $s, t$.

(b) The path $s, a, t$ has weight $1 + 1 = 2$. The direct edge has weight $10$. The minimum path weight is $2$.

(c) Lecture 13 owns weighted single-source shortest paths. Both weights here are positive, so the nonnegative restriction applies, and the algorithm of that restriction is Dijkstra's algorithm.

### 9. The parent exception

(a) The search discovers $b$ from $a$, skips $a$ at $b$ because $a$ is the parent, and discovers $c$ from $b$ with parent $b$. At $c$, the neighbor list is $a, b$. The neighbor $a$ is gray, and the parent of $c$ is $b$, so $a$ is a gray non-parent. The current vertex is $c$ and the neighbor is $a$.

(b) Walk from $c$ through parent $b$ to parent $a$. Closing the edge $c \to a$ in the undirected sense yields the cycle $a, b, c, a$.

(c) The vertex $a$ is the parent of $b$. The list entry is the tree edge $\{a, b\}$ stored at the child. The parent exception skips it. Reporting it would call every tree edge a cycle.

---

## Independent assignment

Build a file `component-dag.js` that Node can run with no libraries and with no reads from the network, the filesystem, or `process.argv`. Budget several hours. The artifact is the program together with a comment block, at the top, of about a page.

Design a directed simple graph with at least $12$ vertices and at least $4$ strongly connected components. In the comment block, write a full hand trace of Kosaraju's algorithm on that graph: adjacency lists in insertion order, discovery and finish times, the transpose lists, and the second-search trees. Also write, in your own words, the argument that the component graph is a DAG and that every component-graph edge runs from a strictly larger finish time to a strictly smaller one. Check that inequality numerically on each component edge of your example.

The program must:

- implement the graph, both topological sorts, and Kosaraju's algorithm from a blank file, using adjacency lists in insertion order and a head-index queue;
- assert that the components it computes equal the trees in your hand trace;
- build the component graph, with one vertex per component and one edge for each original edge that changes component, duplicates removed;
- assert that both topological algorithms accept the component graph;
- assert that every component-graph edge goes forward in both orders;
- on a second graph that is a directed cycle of six vertices, recover one simple cycle from the back edge and the parent pointers, and assert that the returned list has length $7$ (the six vertices with the start repeated at the end).

A run prints `ALL TESTS PASSED` only when those assertions hold. Keep the file. Lecture 13 assumes you can still build an adjacency list and a topological order.

---

## Glossary

**Adjacency list.** The representation that stores, for each vertex, a list of its neighbors. Undirected edges are stored in both lists. This course uses it by default.

**Adjacency matrix.** The $n \times n$ array with a $1$ in position $(u, v)$ exactly when the edge from $u$ to $v$ exists. Space $\Theta(n^2)$.

**Adjacent.** Joined by an edge.

**Back edge.** A directed edge examined while its head is gray. It points to an ancestor on the recursion stack and witnesses a directed cycle.

**BFS distance.** The integer $d[v]$ assigned by breadth-first search. It equals the minimum number of edges on a path from the source, or $\infty$ if no path exists.

**BFS tree.** The predecessor subgraph of a breadth-first search. Each tree path from the source is a minimum-edge path.

**Black.** The color of a vertex whose adjacency list has been fully scanned.

**Breadth-first search.** The single-source exploration that discovers vertices in nondecreasing order of edge-count distance, using a queue.

**Component graph.** The DAG whose vertices are the strongly connected components of a digraph, with an edge from $C$ to a different component $C'$ when some original edge runs from $C$ to $C'$.

**Connected.** An undirected graph in which every pair of vertices is joined by a path.

**Connected component.** A maximal connected set of vertices in an undirected graph.

**Cross edge.** A directed edge to a black vertex whose discovery time is earlier than the tail's, so the two time intervals are disjoint.

**Cycle.** A path of positive length that starts and ends at the same vertex. In a simple undirected graph the length is at least $3$.

**DAG.** A directed acyclic graph: a digraph with no directed cycle.

**Degree.** In an undirected graph, the number of edges incident to a vertex.

**Depth-first forest.** The collection of trees produced by depth-first search, one tree per call from the outer loop.

**Depth-first search.** The exploration that, on discovering a vertex, immediately explores from that vertex before returning to the discoverer.

**Descendant.** In a depth-first forest, a vertex reached from $u$ by a path of tree edges. The parenthesis theorem's statement in this lecture uses proper descendants: a vertex is not a descendant of itself there.

**Digraph.** A directed graph.

**Directed graph.** A graph whose edges are ordered pairs.

**Discovery time.** The clock value at which depth-first search paints a vertex gray.

**Edge.** A connection between vertices: an ordered pair in a digraph, an unordered pair in an undirected graph.

**Edge list.** A representation that stores edges as an array of pairs. Neighbor queries scan the whole array.

**Endpoint.** A vertex at one end of an edge.

**Finish time.** The clock value at which depth-first search paints a vertex black.

**Forward edge.** A directed edge to a black descendant that is not the tree edge which discovered that descendant.

**Graph.** A pair $(V, E)$ of a vertex set and an edge set.

**Gray.** The color of a vertex that has been discovered and has not finished. Gray vertices form the recursion stack.

**Gray-path lemma.** The statement that the gray vertices are the active recursion stack and form a tree path from the current root.

**Handshaking lemma.** In an undirected graph with no loops, the sum of the degrees equals $2m$.

**Head.** The vertex a directed edge enters.

**In-degree.** The number of directed edges entering a vertex.

**Incident.** An edge is incident to its endpoints.

**Interval.** The closed range from a vertex's discovery time to its finish time.

**Kahn's algorithm.** Topological sort by repeatedly outputting a vertex of current in-degree $0$ and decrementing its successors.

**Kosaraju's algorithm.** The $\Theta(n + m)$ computation of strongly connected components: depth-first finish times on $G$, then depth-first search on the transpose in decreasing finish order. Sedgewick and Wayne call the same method Kosaraju–Sharir.

**Layer.** The set of vertices at one breadth-first distance from the source.

**Loop.** An edge from a vertex to itself. Simple graphs in this course exclude loops.

**Multigraph.** A graph that allows parallel edges, and possibly loops.

**Out-degree.** The number of directed edges leaving a vertex.

**Parent.** The vertex from which a search discovered a vertex. The parent of a root or of an undiscovered vertex is null.

**Parent exception.** In undirected cycle detection, the rule that skips the neighbor which is the tree parent, so the stored reverse of a tree edge is not reported as a cycle.

**Parenthesis theorem.** Discovery–finish intervals of two vertices are disjoint or properly nested, and nesting means the inner vertex is a descendant of the outer one.

**Path.** A sequence of vertices with an edge between each consecutive pair. Length is the number of edges.

**Predecessor subgraph.** The vertices reached by a search together with the edges from each parent to its child.

**Queue lemma.** During breadth-first search the queue's distances are nondecreasing and the tail is at most one greater than the head.

**Reachable.** A vertex $v$ is reachable from $u$ when a directed path from $u$ to $v$ exists.

**Simple cycle.** A cycle that repeats no vertex except the shared start and end.

**Simple graph.** A graph with no loops and no parallel edges.

**Simple path.** A path with no repeated vertex.

**Source.** The vertex from which a single-source search begins.

**Strongly connected.** A digraph in which every vertex is reachable from every other vertex.

**Strongly connected component.** A maximal strongly connected set of vertices.

**Tail.** The vertex a directed edge leaves.

**Topological order.** A listing of all vertices such that every directed edge goes from an earlier vertex to a later one.

**Transpose.** The digraph obtained by reversing every edge.

**Tree edge.** The edge by which a search discovers a white vertex.

**Undirected graph.** A graph whose edges are unordered pairs.

**Vertex.** An element of $V$. Also called a node when the graph is drawn as a diagram. This lecture says vertex.

**Weakly connected.** A digraph whose underlying undirected graph is connected.

**Weight.** A number attached to an edge. Breadth-first search does not read weights. Lecture 13 does.

**White.** The color of a vertex that a search has not discovered.

**White-path theorem.** A vertex becomes a descendant of $u$ exactly when, at the discovery of $u$, a path from $u$ to that vertex has all its later vertices white.

---

## Lecture summary

A graph is a set of vertices and a set of edges. The handshaking lemma counts each undirected edge twice, once at each end. Adjacency lists use $\Theta(n + m)$ space and make neighbor scans proportional to the degree; that is the representation breadth-first search and depth-first search assume, and undirected edges are stored in both lists.

Breadth-first search, driven by a queue, assigns to each vertex the minimum number of edges from the source. The queue never holds more than two consecutive distances, and the parent pointers form a tree of those minimum-edge paths. Depth-first search, driven by the recursion stack, assigns nested or disjoint time intervals. A directed edge is a tree, back, forward, or cross edge according to the color of its head. A back edge to a gray vertex is a directed cycle; in an undirected graph the edge back to the parent is the tree edge and is not a cycle.

A DAG is exactly a digraph that has a topological order. Decreasing finish time and Kahn's in-degree queue both build one, in $\Theta(n + m)$ time, and a cycle leaves Kahn's queue unable to empty. Strong connectivity is finer than weak connectivity. The component graph is a DAG, finish times strictly decrease along its edges, and Kosaraju's second search reads that order on the transpose, one tree per component, again in $\Theta(n + m)$ time.

### Five principles

1. Store the graph so that "list the neighbors of $u$" costs the degree of $u$. Adjacency lists do that, and both searches are a constant amount of work per vertex plus a constant amount of work per list cell.
2. Breadth-first distance counts edges. Parent pointers reconstruct one such minimum-edge path. A weight is a different question, and it belongs to Lecture 13.
3. The gray vertices are the stack. Nested finish intervals, back edges, and directed cycles are three views of that stack.
4. A topological order exists exactly when the digraph has no cycle. Finish times and in-degrees are two linear-time ways to build the order, and they may legally disagree when the order is not unique.
5. Strong connectivity requires a directed path each way. Kosaraju's algorithm works because the component graph is a DAG and finish times order its edges, so the transpose's second search starts in a sink component and cannot leave it.

---

## References

1. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapter 20, Sections 20.1 through 20.5. The representations, breadth-first search, depth-first search, the parenthesis structure, topological sort by finish time, and the strongly connected component algorithm and its finish-time lemma are the versions used here.
2. Robert Sedgewick and Kevin Wayne. *Algorithms*. 4th edition. Addison-Wesley, 2011. Sections 4.1 and 4.2. Section 4.2 presents Kosaraju–Sharir with the first search on the transpose and the second on the original graph; Section 9.3 of this lecture records that the component partition is the same and then follows the pass order of the first reference.
