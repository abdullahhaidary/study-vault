# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 10 — HEAPS AND PRIORITY QUEUES

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 10 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 8 hours
**Prerequisites:** Lecture 01 — Models, ADTs, and Asymptotic Analysis; Lecture 06 — Sorting and Order Statistics; Lecture 07 — Trees, Binary Trees, and Traversals
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapters 6 and 15; Sedgewick and Wayne, *Algorithms*, 4th edition, Sections 2.4 and 5.5; Goodrich, Tamassia, and Goldwasser, *Data Structures and Algorithms in Java*, 6th edition, Chapter 9

**This lecture owns:** the binary heap, linear-time heap construction, heapsort, the priority-queue abstract data type including decrease-key, and Huffman coding as an application.
**This lecture does not teach:** Dijkstra's algorithm. Lecture 13 uses this priority queue. It also does not re-teach the comparison-sort lower bound (Lecture 06), the binary-search-tree search property (Lecture 08), or tree traversals (Lecture 07). Fibonacci heaps are outside this course. Lecture 13 calls decrease-key on the indexed binary heap built here, and it assumes nonnegative edge weights for Dijkstra.

---

## Learning objectives

After this lecture you should be able to do each of the following on paper and in code.

1. List the priority-queue operations insert, minimum or maximum, extract-min or extract-max, and decrease-key or increase-key, and name an operation a binary heap does not support in $o(n)$ time unless a handle is added.
2. Given a drawing of a binary tree, decide whether it satisfies heap order and whether it satisfies the binary-search-tree property.
3. Compute the parent and the children of an index in a 0-indexed heap, and prove that a complete binary tree of $n \ge 1$ nodes has height $\lfloor \log n \rfloor$.
4. Trace sift-up and sift-down on a numeric array, and show that each performs $O(\log n)$ work.
5. Execute insert and extract-min, and state the heap invariant that holds after each call.
6. Build a heap by sifting down from the last internal node, prove $\sum_{k \ge 1} k/2^k = 2$, and conclude that this construction runs in $\Theta(n)$ time.
7. Trace heapsort, and justify three claims: the sort is in-place, it is unstable, and its worst-case cost is $\Theta(n \log n)$.
8. Decrease a key in a min-heap whose position map sends each unique key to its index, and state what the map assumes.
9. Build a Huffman code from a frequency table, prove that two rarest symbols are siblings in some optimal tree, and decode a bit string using the prefix-free property.
10. Choose among an unsorted array, a binary search tree, and a binary heap when told which operations dominate.

---

## Purpose

A priority queue stores keys so that the client can add a key and remove a smallest key (or a largest key) without keeping the whole collection in sorted order. Schedulers, compression, and several graph algorithms need exactly that pair of operations, together with a way to lower the priority of a key that is already inside the structure.

An unsorted array inserts at the end in constant time and must scan every slot to find the minimum. A sorted array returns the minimum in constant time and must shift elements to insert. A binary search tree supports both operations in time proportional to its height, and that height is $n-1$ on an adversarial insertion order. Heap order is a weaker rule than search order. The weaker rule is what makes the minimum sit at the root, what makes a sift cost one root-to-leaf path, and what makes a bottom-up construction linear.

The representation is a complete binary tree stored in a 0-indexed array. The index formulas are fixed for the rest of the course:

$$
\mathrm{parent}(i) = \lfloor (i-1)/2 \rfloor, \qquad \mathrm{left}(i) = 2i+1, \qquad \mathrm{right}(i) = 2i+2.
$$

Cormen, Leiserson, Rivest, and Stein, and also Sedgewick and Wayne, draw the same tree with indices starting at 1, where the parent of $i$ is $\lfloor i/2 \rfloor$ and the children are $2i$ and $2i+1$. Those formulas describe the same shape with a different origin. This course does not mix the two conventions in one array.

Keys compared by the heap are JavaScript numbers. Integer comparisons agree with mathematical order when every key is an integer in the safe range, from $-(2^{53}-1)$ through $2^{53}-1$. Huffman frequencies in this lecture are positive safe integers, and every sum of frequencies that the algorithm stores is also a safe integer. Past that limit, JavaScript number addition is not exact, and the heap can order two sums incorrectly.

The JavaScript array is the dynamic array of Lecture 02. Indexing, comparison, addition, and assignment are the constant-time RAM steps of Lecture 01. A `Map` from a key to an index is treated as a constant-time handle so that the heap bounds can be stated. Lecture 11 is where hashing receives its own hypothesis. The sift bounds below count comparisons and swaps along a tree path; they do not depend on hashing. If the keys are integers in a range of size $O(n)$, an ordinary array of indexes gives the same handle in worst-case constant time with no hash table.

---

## Part 1 — The priority-queue abstract data type

A **min-priority queue** is an abstract data type. The client sees operations and their effects. The client does not see the array, the tree, or the indexes.

Let $Q$ hold a finite set of keys. This lecture's heap implementation stores each key at most once. The operations are:

| Operation | Effect | Error |
| --- | --- | --- |
| `insert(x)` | Add the key $x$. | $x$ is already present. |
| `minimum()` | Return a smallest key. Leave $Q$ unchanged. | $Q$ is empty. |
| `extract-min()` | Remove and return a smallest key. | $Q$ is empty. |
| `decrease-key(x, x')` | Replace the stored key $x$ by $x'$, where $x' < x$. | $x$ is absent, $x'$ is already present, or $x' \ge x$. |

A **max-priority queue** is the same data type with the order reversed: `maximum`, `extract-max`, and `increase-key(x, x')` with $x' > x$. Heapsort in Part 7 uses the maximum form. The rest of the heap machinery is written for the minimum form. Replacing every comparison $a < b$ by $a > b$ turns one into the other.

`minimum` reports the extreme key and does not remove it. `extract-min` reports it and removes it. A client that peeks and then extracts must be prepared for another insertion to change the extreme key between the two calls.

`decrease-key` changes a key that is already stored. The operation is useful only if the implementation can find that key. Finding an arbitrary key by scanning the array takes $\Theta(n)$ time in the worst case: the key may sit in the last slot examined, and heap order does not tell the search which subtree to enter. A **handle** is extra information that names the slot. In this lecture the handle is a **position map** from the key to its index, under the assumption that keys are unique. If keys may repeat, the handle is the identity of the node object, and the map sends that object to its index. Part 8 maintains the map. Without a handle, the priority queue specified here does not provide an efficient search by key, an efficient predecessor or successor, or an efficient deletion of an arbitrary key.

The operation mix that justifies a heap is therefore:

- many insertions,
- many extractions of the extreme key,
- and, when a handle exists, many decreases of keys already stored.

The structure is the wrong choice when the client must search for arbitrary keys, must list the keys in sorted order without destroying the queue, or must extract the extreme key only once after all insertions and can afford a linear scan. Part 10 puts costs beside the unsorted array and the binary search tree.

Two array implementations show why a third structure exists. In an unsorted array, `insert` writes the new key at the end in $\Theta(1)$ time, and `extract-min` scans all $n$ slots in $\Theta(n)$ time. In an array kept in increasing order, `minimum` and `extract-min` touch the first slot in $\Theta(1)$ time, and `insert` opens a hole by shifting in $\Theta(n)$ time. Neither pair is logarithmic in both directions. The heap's design goal is worst-case $O(\log n)$ for insert, extract-min, and decrease-key, with `minimum` in $\Theta(1)$ time, bought by refusing arbitrary search.

---

## Part 2 — Heap order is a parent-child rule

Lecture 07 stored a binary tree as nodes with a left child and a right child. A missing child was `null`. This lecture keeps that vocabulary and adds a second, array-shaped picture of one special tree.

**Heap order** for a min-heap: every node is less than or equal to each child it has. In the array, that sentence is: for every index $i \ge 1$,

$$
\mathrm{keys}[\mathrm{parent}(i)] \le \mathrm{keys}[i].
$$

A **min-heap** is a complete binary tree that satisfies heap order. A **max-heap** uses $\ge$ in the same places.

Heap order talks about a parent and its children. The binary-search-tree property from Lecture 08 talks about whole subtrees: every key in the left subtree is less than or equal to the node, and every key in the right subtree is greater than or equal to the node. A tree can satisfy one rule and fail the other.

Here is a min-heap on the keys $1, 3, 4, 5, 10$. The array is $[1, 4, 3, 5, 10]$.

```text
            1
          /   \
         4     3
        / \
       5   10

index:  0  1  2  3  4
value:  1  4  3  5  10
```

Check heap order at each parent.

- Index 0 holds 1. The children are 4 and 3. Both are $\ge 1$.
- Index 1 holds 4. The children are 5 and 10. Both are $\ge 4$.
- Index 2 holds 3 and has no child, because $2\cdot 2+1 = 5$ is past the end of an array of length 5.

The array is not sorted: 4 sits immediately before 3. Heap order never promised a left-to-right order.

The same drawing fails the search property at the node that holds 4. The left child is 5, and $5 > 4$. A search tree would also place 3 somewhere in the left subtree of 4, because $3 < 4$. In this drawing, 3 is the right child of the root. The minimum is at the root, which a search tree guarantees only for the minimum of the whole tree by walking left, and which a heap guarantees by the local rule alone.

**Lemma (the root is a minimum).** In a min-heap, $\mathrm{keys}[0]$ is less than or equal to every stored key.

**Proof.** Take any index $j$. Repeated application of $\mathrm{parent}$ reaches 0, because each application strictly decreases the index when the index is positive, and the parent of a positive index is nonnegative. Along that chain each parent key is $\le$ its child key, so $\mathrm{keys}[0] \le \mathrm{keys}[j]$.

The same argument with the opposite comparison shows that the root of a max-heap is a maximum. The lemma is why `minimum` is a single array read. It is also why the array can remain unsorted below the root: the proof uses only the edges on one path, so keys in different branches are never compared with each other.

---

## Part 3 — The complete tree in the array

Lecture 07 called a binary tree **complete** when every level except the last is full and the last level is filled from the left. This lecture uses that shape and does not repeat the traversal material.

Number the positions of a complete tree in level order, starting at 0. The root has index 0. The next level is indexes 1 and 2. The level after that is indexes 3 through 6, and so on. Because the last level is filled from the left, the occupied indexes are exactly $0, 1, \ldots, n-1$ with no holes. A missing child is an index that is $\ge n$. In a node drawing that child is `null`. The array does not store a `null` placeholder for it.

**Height and depth** keep the course convention. The depth of the root is 0. The depth of any other node is one more than the depth of its parent. The height of a leaf is 0. The height of a non-leaf is one more than the larger height of its children. A missing child, if one is imagining a height for it while computing a sibling, has height $-1$, the height of the empty tree. The height of the tree is the height of the root.

**Lemma (index formulas).** In this numbering, the children of index $i$ are $2i+1$ and $2i+2$, and the parent of index $i \ge 1$ is $\lfloor (i-1)/2 \rfloor$.

**Proof.** Level $d$ begins at index $2^d - 1$, because the levels before it contain $\sum_{t=0}^{d-1} 2^t = 2^d - 1$ nodes. Let index $i$ lie on level $d$, and let $r = i - (2^d - 1)$ be its offset within that level. Its left child is the first index of level $d+1$, plus two slots per node of level $d$ that precedes it:

$$
(2^{d+1} - 1) + 2r = (2^{d+1} - 1) + 2\bigl(i - (2^d - 1)\bigr) = 2^{d+1} - 1 + 2i - 2^{d+1} + 2 = 2i + 1.
$$

The right child occupies the next index, $2i+2$. Solving $i = 2p+1$ or $i = 2p+2$ for the parent gives $p = \lfloor (i-1)/2 \rfloor$.

A node $i$ is a leaf when its left-child index falls off the array, that is, when $2i+1 \ge n$. Equivalently, the leaves are the indexes $i$ with

$$
\lfloor (n-2)/2 \rfloor < i \le n-1,
$$

and $\lfloor (n-2)/2 \rfloor$ is the last internal node when $n \ge 2$. For $n = 10$ that last internal index is $\lfloor 8/2 \rfloor = 4$. Index 4 has parent $\lfloor 3/2 \rfloor = 1$, left child $9$, and right child $10$. Index 10 is not a slot of a 10-element array, so index 4 has one child. The leaves are indexes 5 through 9.

**Theorem (height of a complete tree).** A complete binary tree with $n \ge 1$ nodes has height $\lfloor \log n \rfloor$.

**Proof.** Let $h$ be the height. If $h = 0$, the tree is a single node, $n = 1$, and $\lfloor \log 1 \rfloor = 0$.

Now let $h \ge 1$. Levels $0$ through $h-1$ are full, so they contain $\sum_{d=0}^{h-1} 2^d = 2^h - 1$ nodes. Level $h$ contains at least one node. Therefore

$$
n \ge (2^h - 1) + 1 = 2^h,
$$

which is $h \le \log n$. There is no level past $h$, so

$$
n \le \sum_{d=0}^{h} 2^d = 2^{h+1} - 1 < 2^{h+1},
$$

which is $\log n < h + 1$. The only integer $h$ satisfying $h \le \log n < h + 1$ is $h = \lfloor \log n \rfloor$.

The same two inequalities are the practical test: $h$ is the unique integer with $2^h \le n \le 2^{h+1} - 1$. For $n = 10$, $2^3 = 8 \le 10 \le 15 = 2^4 - 1$, so the height is 3. A sift that walks from the root to a leaf crosses at most $h$ edges, so it performs $O(\log n)$ comparisons. Part 4 turns that observation into the sift procedures. The bound is tight for the height: the shape really does contain a root-to-leaf path of $\lfloor \log n \rfloor$ edges whenever $n \ge 1$.

---

## Part 4 — Sift-up and sift-down

Both repairs move one key along a path until heap order holds again. They assume the rest of the tree is already a heap, in a sense made precise by the lemmas below. Each step swaps the key with its parent or with one child, so the number of swaps is at most the length of a root-to-leaf path, which is at most $\lfloor \log n \rfloor$.

### Sift-up

Sift-up starts at an index $i$ whose key may be smaller than its parent, and swaps upward while that is true.

```text
siftUp(i):
    while i > 0:
        p = floor((i - 1) / 2)
        if keys[p] <= keys[i]:
            return
        swap keys[i] and keys[p]
        i = p
```

**Trace.** The array $[3, 5, 4, 10]$ is a min-heap. Append 1 at index 4, producing $[3, 5, 4, 10, 1]$. Sift the new index.

1. Index 4 holds 1. Its parent is index 1, which holds 5. Because $1 < 5$, swap. The array is $[3, 1, 4, 10, 5]$, and the sift continues at index 1.
2. Index 1 holds 1. Its parent is index 0, which holds 3. Because $1 < 3$, swap. The array is $[1, 3, 4, 10, 5]$, and the sift continues at index 0.
3. The index is the root, so the loop ends.

Two comparisons and two swaps. The height of a 5-node tree is $\lfloor \log 5 \rfloor = 2$, and the sift used the whole height. The final tree is the drawing in Part 2.

```text
        1
       / \
      3   4
     / \
   10   5
```

**Lemma (sift-up).** Suppose the array is a min-heap, and then the key at a single index $i$ is replaced by a strictly smaller key. Sift-up from $i$ restores heap order. The keys outside the ancestor path of $i$ do not move.

**Proof.** Decreasing the key at $i$ preserves every comparison in which $i$ is the parent: its children were $\ge$ the old key, and the new key is smaller still. Every comparison that does not involve $i$ is unchanged. The only comparisons that can fail are those in which $i$ is the child.

Consider one swap. Let $v$ be the key being sifted, sitting at index $i$, and let $p$ be the key at $\mathrm{parent}(i)$, with $v < p$. If $i$ has a sibling, that sibling key $s$ satisfies $p \le s$, because the parent satisfied heap order before the swap. If $i$ has children, each of those children is $\ge$ the original key that occupied $i$ before the decrease, and that original key was $\ge p$ because $i$ was a child of $\mathrm{parent}(i)$ in a heap. Those children are therefore $\ge p$. They are also $\ge v$, because $v$ is smaller than the original key.

After the swap, $v$ occupies the parent index. Its children there are $p$ and, if present, $s$. From $v < p$ and $p \le s$ we get $v \le p$ and $v \le s$. The key $p$ now occupies $i$. If $i$ was a leaf, $p$ has no children. If $i$ had children, those children are $\ge p$, which is the heap-order requirement at $i$. The next iteration tests $v$ against its new parent. The index decreases at every swap, so the loop reaches the root or a parent that is $\le v$ after a finite number of steps bounded by the depth of the starting index.

### Sift-down

Sift-down starts at an index whose key may be larger than a child, and swaps it with the smaller child while that is true. The smaller child is required. Swapping with the larger child can leave the parent above the child that was not chosen.

```text
siftDown(i):
    n = length(keys)
    while true:
        smallest = i
        l = 2i + 1
        r = 2i + 2
        if l < n and keys[l] < keys[smallest]:
            smallest = l
        if r < n and keys[r] < keys[smallest]:
            smallest = r
        if smallest == i:
            return
        swap keys[i] and keys[smallest]
        i = smallest
```

The comparison is strict. A child equal to its parent does not move.

**Trace.** Start with $[20, 4, 3, 5, 10, 8, 7]$. The left subtree of the root and the right subtree of the root are already min-heaps: 4 is $\le$ both 5 and 10, and 3 is $\le$ both 8 and 7. The root 20 is not $\le$ its children. Sift index 0.

1. The children of index 0 are index 1 (value 4) and index 2 (value 3). The smaller child is 3. Because $20 > 3$, swap. The array is $[3, 4, 20, 5, 10, 8, 7]$. Continue at index 2.
2. The children of index 2 are index 5 (value 8) and index 6 (value 7). The smaller child is 7. Because $20 > 7$, swap. The array is $[3, 4, 7, 5, 10, 8, 20]$. Continue at index 6.
3. Index 6 has no child inside an array of length 7. The loop returns.

```text
            3
          /   \
         4     7
        / \   / \
       5  10 8  20
```

Two swaps. A wrong sift that preferred the larger child would swap 20 with 4 and produce $[4, 20, 3, 5, 10, 8, 7]$. Then 4 would sit above 3, and heap order would fail at the root.

**Lemma (sift-down).** Suppose both child subtrees of index $i$ are min-heaps, and every heap-order comparison outside the subtree of $i$ already holds. Sift-down from $i$ makes the subtree of $i$ a min-heap and does not move keys outside that subtree.

**Proof.** The loop moves a single key $v$ down the subtree. At the start of each iteration, both subtrees hanging off the current index are min-heaps, and $v$ may be larger than one or both of its children. Choose $s$ to be the current index if $v$ is $\le$ both children; the loop then stops, and the subtree is a heap. Otherwise $s$ is the index of a strictly smaller child, and that child is $\le$ the other child.

Swap $v$ with the key $c$ at $s$. The key $c$ moves up to the parent position. Its new children are $v$ and the other child. By the choice of $s$, $c \le v$ fails to be the stopping case only because $c < v$, and $c$ is $\le$ the other child. So $c$ satisfies heap order with both new children. The subtree that was not entered is unchanged and remains a heap. The subtree that $v$ entered had $c$ as its root and was a heap; its internal comparisons stay valid, and the next iteration repairs the position now occupied by $v$. Each swap increases the index, which is at most $n-1$, so the loop ends at a leaf or at a node whose children are both $\ge v$.

Both procedures are therefore $O(\log n)$ in the worst case: at most $\lfloor \log n \rfloor$ swaps, and a constant amount of index arithmetic per swap. The bound is $\Theta(\log n)$ on those inputs where the sifted key travels from the root to a leaf, or from a deepest leaf to the root. On other inputs the sift stops earlier. The worst-case statement is the one used in the operation table.

---

## Part 5 — Insert and extract-min

Insertion appends the new key at index $n$, which is the next free position in a complete tree, records that index in the position map, and sifts up. The shape stays complete because the new node is the next leaf from the left. Heap order is the conclusion of the sift-up lemma, applied to a new leaf: before the sift, the only new comparison is between the leaf and its parent.

```text
insert(x):
    require that x is not already stored
    append x
    position[x] = length(keys) - 1
    siftUp(length(keys) - 1)
```

Extraction removes the root, which the root lemma says is a minimum, and fills the hole with the last leaf. Deleting the last leaf leaves a complete shape on $n-1$ nodes. The two subtrees of the root are still heaps, because their keys did not change. Sift-down from the root is then exactly the hypothesis of the sift-down lemma.

```text
extractMin():
    require that the heap is not empty
    min = keys[0]
    last = pop the last key
    delete min from the position map
    if the heap is now empty:
        return min
    keys[0] = last
    position[last] = 0
    siftDown(0)
    return min
```

If the heap had one key, the pop empties it and there is nothing to sift. The implementation throws on an empty heap rather than returning a sentinel. A sentinel would collide with a client whose keys include that sentinel.

**Trace of five insertions.** Start from an empty min-heap and insert 4, 10, 3, 5, 1. The position map is updated on every swap; after all five insertions it sends each key to the index shown in the last row.

| Call | Array after the call | Swaps during the call |
| --- | --- | --- |
| `insert(4)` | $[4]$ | 0 |
| `insert(10)` | $[4, 10]$ | 0, because $10 \ge 4$ |
| `insert(3)` | $[3, 10, 4]$ | 1, the new key swaps with 4 |
| `insert(5)` | $[3, 5, 4, 10]$ | 1, the new key swaps with 10 and then $5 \ge 3$ |
| `insert(1)` | $[1, 3, 4, 10, 5]$ | 2, the sift-up trace of Part 4 |

Four swaps in total. After each row the parent of every positive index is $\le$ that index. After the last insertion the map is

$$
1 \mapsto 0,\quad 3 \mapsto 1,\quad 4 \mapsto 2,\quad 10 \mapsto 3,\quad 5 \mapsto 4.
$$

`minimum()` returns 1 and leaves the array unchanged.

**Trace of extract-min.** Start from $[1, 3, 4, 10, 5]$.

1. The root lemma says the minimum is 1. Pop 5. Delete 1 from the map. Write 5 at index 0. The array is $[5, 3, 4, 10]$, and the map sends 5 to 0, 3 to 1, 4 to 2, and 10 to 3.
2. Sift index 0. The children are 3 and 4. The smaller child is 3 at index 1. Swap. The array is $[3, 5, 4, 10]$.
3. At index 1 the key is 5, and the only child inside the array is 10 at index 3. Because $5 < 10$, sift-down returns.

The call returns 1. The heap that remains is $[3, 5, 4, 10]$. Heap order holds: $3 \le 5$, $3 \le 4$, and $5 \le 10$. The shape is the complete tree on four nodes. The map no longer contains 1.

These two operations are the priority queue a client can use without ever seeing an index. Their costs, with the array already able to hold the new key, are the costs of one sift: worst-case $\Theta(\log n)$ for an insertion that rises to the root, and worst-case $\Theta(\log n)$ for an extraction whose replacement key sinks to a leaf. `minimum` is $\Theta(1)$.

With a JavaScript array that grows geometrically, Lecture 02 charges the occasional copy of the whole array to the sequence of appends, at an amortized $\Theta(1)$ per append. Insert is then amortized $O(\log n)$: the sift is $O(\log n)$ on every call, and the growth contributes $O(1)$ amortized. One individual insert can take $\Theta(n)$ time when it triggers a growth. Extract-min pops, so it does not grow the array; its worst-case cost stays $\Theta(\log n)$. A caller that allocates the array at its final capacity up front removes the growth term, and insert is then worst-case $\Theta(\log n)$ as well. The laboratory uses the ordinary JavaScript array and counts swaps, which are the sift cost, separately from any growth the engine performs.

---

## Part 6 — Building a heap in linear time

Inserting $n$ keys one after another produces a heap. It is a different algorithm from the one this part analyzes. The $k$-th insertion sifts a key through a heap of size $k$, in $O(\log k)$ time. Summing over $k$,

$$
\sum_{k=1}^{n} \lfloor \log k \rfloor \le \sum_{k=1}^{n} \log n = n \log n,
$$

which is $O(n \log n)$. The matching lower bound on a particular input is short. Insert the keys $n, n-1, \ldots, 1$ into a min-heap, each key a new minimum. The $k$-th insertion appends at index $k-1$ and swaps once per edge on the path to the root. That path has $\lfloor \log k \rfloor$ edges, so the number of swaps is exactly $\sum_{k=1}^{n} \lfloor \log k \rfloor$. Let $H = \lfloor \log n \rfloor$, so $2^H \le n < 2^{H+1}$. Every integer $k$ with $\lfloor n/2 \rfloor < k \le n$ also satisfies $k > n/2 \ge 2^{H-1}$, and therefore $k \ge 2^{H-1} + 1$. Hence $\lfloor \log k \rfloor \ge H - 1$. For $n \ge 4$ one has $H \ge 2$, so $H - 1 \ge H/2$, and

$$
\lfloor \log k \rfloor \ge \lfloor \log n \rfloor - 1 \ge \tfrac{1}{2}\lfloor \log n \rfloor.
$$

There are $n - \lfloor n/2 \rfloor \ge n/2$ such values of $k$, so the total number of swaps is $\Omega(n \log n)$. Successive insertion is therefore $\Theta(n \log n)$ in the worst case. The trace in Part 5 is this algorithm on five keys: it performs 4 swaps and ends at $[1, 3, 4, 10, 5]$.

**Build-heap** does not do that. It writes all $n$ keys into the array in the given order, then sifts down from the last internal node toward the root. Leaves are already heaps of height 0, so the loop does not start at them.

```text
buildMinHeap(source):
    keys = a copy of source
    record each key's starting index in the position map
    if n <= 1:
        return
    for i from floor((n - 2) / 2) down to 0:
        siftDown(i)
```

For $n = 1$, $\lfloor (1-2)/2 \rfloor = \lfloor -1/2 \rfloor = -1$, and a loop from $-1$ down to 0 does not run. The single key is a heap.

**Correctness.** Proceed by decreasing index. When sift-down is about to run at index $i$, every child of $i$ has a larger index. Each child is either a leaf or an index that the loop has already sifted. By the sift-down lemma and induction on the index, both child subtrees are min-heaps. Sift-down makes the subtree of $i$ a min-heap. At $i = 0$ the whole array is a min-heap. The occupied indexes remain $0$ through $n-1$, so the shape stays complete.

**Trace.** Build a min-heap from $[4, 10, 3, 5, 1]$. Here $n = 5$ and the last internal index is $\lfloor 3/2 \rfloor = 1$.

```text
start        4              array [4, 10, 3, 5, 1]
            / \
          10   3
         / \
        5   1
```

Sift index 1, whose key is 10. The children are 5 and 1. The smaller child is 1 at index 4. Swap. The child that received 10 is a leaf, so the sift stops. One swap.

```text
after i = 1  4              array [4, 1, 3, 5, 10]
            / \
           1   3
          / \
         5  10
```

Sift index 0, whose key is 4. The children are 1 and 3. The smaller child is 1. Swap.

```text
continue     1              array [1, 4, 3, 5, 10]
            / \
           4   3
          / \
         5  10
```

Index 1 now holds 4. Its children are 5 and 10, and $4$ is $\le$ both, so the sift stops. One further swap.

The built heap is $[1, 4, 3, 5, 10]$. The swap count is 2, and sift-down was called twice. This is the Part 2 picture. It is a legal min-heap, and it is a different array from the heap $[1, 3, 4, 10, 5]$ produced by inserting the same keys from left to right. Both arrays contain the same keys. Build-heap does not promise the shape that successive insertion would have produced.

### The series

The cost of one sift-down is proportional to the height of the node where it starts: at most that many swaps, and a constant amount of work per level, including the final level that discovers it should stop. Leaves are not sifted. The running time is therefore proportional to

$$
\sum_{\text{nodes } v} O\bigl(1 + \mathrm{height}(v)\bigr),
$$

where the sum may be taken over all nodes by giving every leaf a constant inspection cost of zero in the swap sum and charging $\Theta(1)$ to each of the $\lfloor n/2 \rfloor$ internal nodes separately. The internal-node charge is $\Theta(n)$ on every input, because every internal node is inspected. What remains is to prove that the sum of the heights is $O(n)$ rather than $O(n \log n)$.

The loose estimate "there are $n$ nodes and each has height at most $\lfloor \log n \rfloor$" is a correct $O(n \log n)$ upper bound and a weak one. Most nodes are near the leaves and have small height. The tight estimate sums the actual heights.

**Lemma (finite series).** For every integer $n \ge 1$,

$$
S_n = \sum_{k=1}^{n} \frac{k}{2^k} = 2 - \frac{n+2}{2^n}.
$$

**Proof.** The geometric sum is the tool. For $r \ne 1$ and an integer $m \ge 0$, let $G = \sum_{k=0}^{m} r^k$. Then $rG = \sum_{k=1}^{m+1} r^k$, so $G - rG = 1 - r^{m+1}$, and

$$
\sum_{k=0}^{m} r^k = \frac{1 - r^{m+1}}{1 - r}.
$$

With $r = 1/2$ and $m = n-1$,

$$
\sum_{k=0}^{n-1} \frac{1}{2^k} = 2\bigl(1 - 2^{-n}\bigr),
$$

and dropping the $k = 0$ term gives

$$
\sum_{k=1}^{n} \frac{1}{2^k} = 1 - 2^{-n}.
$$

Now compare $S_n$ with half of itself:

$$
\frac{1}{2} S_n = \sum_{k=1}^{n} \frac{k}{2^{k+1}} = \sum_{k=2}^{n+1} \frac{k-1}{2^k}.
$$

Subtract term by term. The $k = 1$ term of $S_n$ is $1/2$. For $2 \le k \le n$ the difference of coefficients is $k - (k-1) = 1$. The extra term in $\tfrac{1}{2} S_n$ at $k = n+1$ is $n/2^{n+1}$. Therefore

$$
S_n - \frac{1}{2} S_n = \frac{1}{2} + \sum_{k=2}^{n} \frac{1}{2^k} - \frac{n}{2^{n+1}} = \sum_{k=1}^{n} \frac{1}{2^k} - \frac{n}{2^{n+1}}.
$$

The geometric evaluation turns the right-hand side into $1 - 2^{-n} - n \cdot 2^{-(n+1)}$. Multiply by 2:

$$
S_n = 2 - 2^{1-n} - n \cdot 2^{-n} = 2 - \frac{n+2}{2^n}.
$$

**Corollary.** $\sum_{k=1}^{\infty} k/2^k = 2$.

**Proof.** The finite formula says $S_n = 2 - (n+2)/2^n$. The subtracted term is positive, so $S_n < 2$. It remains to show that $(n+2)/2^n$ tends to 0.

First, $2^n \ge n^2$ for every integer $n \ge 4$. The base $n = 4$ is $16 \ge 16$. If $2^k \ge k^2$ for some $k \ge 4$, then $2^{k+1} \ge 2k^2$. And $2k^2 - (k+1)^2 = k^2 - 2k - 1$. The quadratic $k^2 - 2k - 1$ has roots $1 \pm \sqrt{2}$, so it is positive for every integer $k \ge 3$. Thus $2k^2 \ge (k+1)^2$, and $2^{k+1} \ge (k+1)^2$.

For $n \ge 4$, $n/2^n \le n/n^2 = 1/n$ and $2/2^n \le 2/n^2 \le 2/n$. Hence $(n+2)/2^n \le 3/n$, which tends to 0 as $n$ grows. Therefore $S_n$ tends to 2, which is the infinite sum.

**Numeric check of the identity.** For $n = 3$,

$$
S_3 = \frac{1}{2} + \frac{2}{4} + \frac{3}{8} = \frac{4}{8} + \frac{4}{8} + \frac{3}{8} = \frac{11}{8},
$$

and $2 - (3+2)/2^3 = 2 - 5/8 = 11/8$. A perfect tree of height 3 has $n = 2^4 - 1 = 15$ nodes. Every node at depth $d$ has height $3 - d$, and level $d$ has $2^d$ nodes, so the sum of heights is

$$
1\cdot 3 + 2\cdot 2 + 4\cdot 1 + 8\cdot 0 = 11 = 2^3 \cdot S_3.
$$

The loose estimate $n \cdot 3 = 45$ is several times larger. The series is what removes the factor $\log n$.

**Theorem (linear build).** Build-heap runs in $\Theta(n)$ time on every input of $n$ keys.

**Proof.** Let $H = \lfloor \log n \rfloor$, which is the height. A node at depth $d$ has height at most $H - d$, because no path continues past depth $H$. Level $d$ has at most $2^d$ nodes. Therefore the sum of heights is at most

$$
\sum_{d=0}^{H} 2^d \, (H - d).
$$

Substitute $k = H - d$. As $d$ runs from 0 to $H$, $k$ runs from $H$ down to 0, and $2^d = 2^{H-k}$:

$$
\sum_{k=0}^{H} k \cdot 2^{H-k} = 2^H \sum_{k=1}^{H} \frac{k}{2^k} = 2^H \, S_H.
$$

Since $S_H < 2$ and, by the height theorem, $2^H \le n$,

$$
\sum_v \mathrm{height}(v) \le 2^H \sum_{k \ge 1} \frac{k}{2^k} = 2^H \cdot 2 = 2^{H+1} \le 2n.
$$

The same chain is the form $n \sum_{k \ge 1} k/2^k = 2n$. The sum of heights is $O(n)$.

Each sift-down from $v$ costs $O(1 + \mathrm{height}(v))$ time. Summing over the nodes that the algorithm sifts, and adding the $\Theta(n)$ cost of writing the input into the array and of initializing the position map, gives an $O(n)$ upper bound.

For the matching lower bound, a complete tree on $n \ge 1$ nodes has $\lceil n/2 \rceil$ leaves, so it has $\lfloor n/2 \rfloor$ internal nodes. Build-heap inspects the children of each of them. That is $\Omega(n)$ work on every input, including an input that is already a heap and performs no swaps. Combined with the $O(n)$ upper bound, the running time is $\Theta(n)$ on every input.

On the running example the heights in the 5-node shape are 2 at the root, 1 at index 1, and 0 at indexes 2, 3, and 4. The sum of heights is 3. The series bound says this sum is at most $2^H S_H = 4 \cdot S_2$. And $S_2 = 1/2 + 2/4 = 1$, so the bound gives 4. The still looser bound $n \cdot 2 = 10$ remains $O(n)$ only because the hidden factor in a general $n \lfloor \log n \rfloor$ estimate would grow; for this single $n$ the arithmetic 10 is just a number. The swap count on this input is 2, which is under the sum of heights, because a sift is allowed to stop before it has walked the whole height.

Floyd's bottom-up construction is the linear algorithm. Williams's heapsort paper introduced the heap and the $n$-insertion construction. Calling the insertion loop "build-heap" names the slower algorithm.

---

## Part 7 — Heapsort

Heapsort turns the array into a max-heap, then repeatedly extracts the maximum into the end of the same array. The growing suffix is the sorted portion. The shrinking prefix is the heap. The sift during an extraction must stop at the current heap size, otherwise it will compare against keys that have already been placed in sorted position.

```text
heapSort(keys):                         # sorts the array in place, ascending
    n = length(keys)
    for i from floor((n - 2) / 2) down to 0:
        siftDownMax(i, n)
    for size from n down to 2:
        swap keys[0] with keys[size - 1]
        siftDownMax(0, size - 1)

siftDownMax(i, size):
    while true:
        largest = i
        l = 2i + 1
        r = 2i + 2
        if l < size and keys[l] > keys[largest]:
            largest = l
        if r < size and keys[r] > keys[largest]:
            largest = r
        if largest == i:
            return
        swap keys[i] with keys[largest]
        i = largest
```

The comparison is strict `>`. Equal keys do not swap during a sift.

**Trace.** Sort $[4, 10, 3, 5, 1]$. The last internal index is 1.

Build the max-heap. At index 1 the key 10 has children 5 and 1, and 10 is already $\ge$ both, so no swap occurs. At index 0 the key 4 has children 10 and 3. Swap 4 with 10, producing $[10, 4, 3, 5, 1]$. Continue at index 1: 4 has children 5 and 1, and the larger child is 5. Swap, producing $[10, 5, 3, 4, 1]$. Index 3 is a leaf inside this array. The max-heap is

```text
            10
           /  \
          5    3
         / \
        4   1
```

Extract into the suffix.

| Heap size after the extract swap | Array after the swap, before the sift | Array after the sift |
| --- | --- | --- |
| 4 | $[1, 5, 3, 4, 10]$ | $[5, 4, 3, 1, 10]$ |
| 3 | $[1, 4, 3, 5, 10]$ | $[4, 1, 3, 5, 10]$ |
| 2 | $[3, 1, 4, 5, 10]$ | $[3, 1, 4, 5, 10]$ |
| 1 | $[1, 3, 4, 5, 10]$ | $[1, 3, 4, 5, 10]$ |

Read the first data row carefully. The swap of the root with index 4 writes 10 into its final place and puts 1 at the root. Sift-down inside size 4 swaps 1 with 5, then swaps 1 with 4, and stops because index 3 has no child inside size 4. The later rows follow the same rule. The finished array is $[1, 3, 4, 5, 10]$.

Count the exchanges on this trace. The build swaps twice. The four extract phases then perform 3, 2, 1, and 1 exchanges, counting the swap that parks the maximum as well as the sift swaps: $3 + 2 + 1 + 1 = 7$. The extract phase already does more exchanges than the linear build. That count is an illustration on $n = 5$, not the proof.

**Theorem (heapsort is sorted).** When `heapSort` returns, $\mathrm{keys}[0] \le \mathrm{keys}[1] \le \cdots \le \mathrm{keys}[n-1]$.

**Proof.** The build loop is Part 6 with the max-heap comparison, so the array is a max-heap of size $n$. Claim: after $t$ extractions, the suffix $\mathrm{keys}[n-t], \ldots, \mathrm{keys}[n-1]$ is the $t$ largest input keys in increasing order, and the prefix of length $n-t$ is a max-heap of the remaining keys. The claim holds at $t = 0$. Suppose it holds for some $t < n$. The root of the prefix is a maximum of the remaining keys, by the root lemma for a max-heap. Swapping it with index $n-t-1$ extends the sorted suffix by one key, still in increasing order because the parked key is $\le$ every key already in the suffix: those suffix keys were extracted earlier and were maxima of larger sets. The prefix of length $n-t-1$ has two child subtrees that are still max-heaps. Sift-down inside that size restores the prefix. At $t = n-1$ the suffix is the entire array, sorted. The last iteration of the size loop leaves a heap of size 1, which needs no sift.

**In-place.** The algorithm writes only inside the input array, plus a constant number of index variables and one temporary used for a swap. It does not allocate a second array of $n$ keys. The laboratory keeps copies of the array after each phase so the assertions can name them. Those copies are instrumentation. They are not part of the sort.

**Unstable.** A sort is stable when equal keys leave the procedure in the same relative order they had on entry. Heapsort does not. Sort the two records $(2, a)$ then $(2, b)$, compared by the numeric priority alone.

```text
start:   index 0 holds (2, a), index 1 holds (2, b)
build:   the child priority 2 is not greater than the parent priority 2, so no sift swap
extract: swap index 0 with index 1
result:  (2, b), then (2, a)
```

The original order was $a$ before $b$. The output order is $b$ before $a$. The mandatory swap that parks the root caused the reversal. The strict sift comparison is why the build did not swap them; it is not a repair for stability.

**Theorem (cost of heapsort).** The worst-case running time of heapsort is $\Theta(n \log n)$.

**Proof.** The build is $\Theta(n)$ by Part 6. Each of the $n-1$ extractions sifts a heap of some size $k$ with $2 \le k \le n$, in $O(\log k)$ time. The sum of those bounds is

$$
\sum_{k=2}^{n} O(\log k) = O(n \log n).
$$

Adding the linear build does not change the sum: $\Theta(n) + O(n \log n) = O(n \log n)$. This is why a linear build does not make the whole sort linear. The build inspects each node according to that node's own height, and those heights add up to a linear function. The extract phase sifts from the root $\Theta(n)$ times, and the early sifts run on heaps whose height is still $\Theta(\log n)$.

The matching $\Omega(n \log n)$ lower bound is the comparison-sort theorem of Lecture 06. Heapsort decides order only by comparing keys, so some input of length $n$ forces it to perform $\Omega(n \log n)$ comparisons. The upper bound and that lower bound together are $\Theta(n \log n)$ in the worst case.

Lecture 06 also placed mergesort and Lomuto quicksort. Heapsort joins them as an $O(n \log n)$ comparison sort. Mergesort is stable and uses an auxiliary array. Lomuto quicksort is in-place and unstable, with a quadratic worst case. Heapsort is in-place and unstable, with a $\Theta(n \log n)$ worst case. The heap machinery is the reason the worst case improved relative to quicksort, and it is also the reason equal keys move.

---

## Part 8 — Handles and decrease-key

Sift-up and sift-down move keys, so any map from key to index is false the moment a swap is left unrecorded. The rule is local: the swap procedure writes both indexes before it returns.

```text
swap(i, j):
    exchange keys[i] and keys[j]
    position[keys[i]] = i
    position[keys[j]] = j
```

After the exchange, `keys[i]` is the key that used to sit at $j$, so the assignment `position[keys[i]] = i` records the slot that key just entered. The same reading applies to $j$.

**Assumption.** Either every key appears at most once, and the map is keyed by the key, or the client holds node objects and the map is keyed by object identity. The first assumption is the one the code below implements. Under that assumption, decreasing 10 to 2 must delete the map entry for 10 and create an entry for 2, because the key itself changed. The second assumption is what Lecture 13 needs when two vertices could otherwise look alike only through a numeric priority: the handle is the vertex, and the priority is a field that decrease-key is allowed to change. Duplicate priorities are then legal, and the heap orders nodes by priority. This lecture's laboratory stays with unique numeric keys so the trace can name every index by the key.

`decrease-key` on a min-heap replaces the key and sifts up. It does not sift down. Decreasing a key can break the comparison with the parent. It cannot break the comparison with the children, because those children were already $\ge$ the old, larger key.

```text
decreaseKey(x, x'):
    require position contains x
    require x' < x and position does not contain x'
    i = position[x]
    delete x from position
    keys[i] = x'
    position[x'] = i
    siftUp(i)
```

The sift-up lemma of Part 4 is this operation. Each swap inside the sift goes through `swap`, so the map matches the array when the sift returns.

**Trace.** Start from the inserted heap $[1, 3, 4, 10, 5]$, with $10 \mapsto 3$. Decrease 10 to 2.

1. Index 3 now holds 2. The array is $[1, 3, 4, 2, 5]$. The map has dropped 10 and sends 2 to 3.
2. The parent of index 3 is index 1, which holds 3. Because $2 < 3$, swap. The array is $[1, 2, 4, 3, 5]$. The map sends 2 to 1 and 3 to 3.
3. The parent of index 1 is index 0, which holds 1. Because $2 \ge 1$, sift-up returns.

The heap is $[1, 2, 4, 3, 5]$.

```text
            1
           / \
          2   4
         / \
        3   5
```

The map is $1 \mapsto 0$, $2 \mapsto 1$, $4 \mapsto 2$, $3 \mapsto 3$, $5 \mapsto 4$. Heap order holds, and 10 is gone. The lookup was $O(1)$ under the model of Part 1, and the sift was $O(\log n)$. That is the whole cost of decrease-key.

Increase-key on a min-heap is the symmetric operation: write the larger key and sift down, because the parent comparison still holds and a child comparison may fail. A max-heap exchanges the two directions. Lecture 13's Dijkstra implementation decreases a distance, so it uses the min-heap direction written here.

A client without a handle who wants to decrease a key must first find it. In a heap that search is $\Theta(n)$ in the worst case, which cancels the logarithmic sift. The handle is part of the data structure, not an optional debugging aid, whenever decrease-key is part of the client's operation mix.

---

## Part 9 — Huffman coding

A **prefix-free code**, also called a prefix code, assigns each symbol a binary codeword so that no codeword is a prefix of another. The pay-off is decoding. Read bits from the front of the message. Exactly one codeword matches the bits read so far. Emit that symbol and start again at the root of the code. A code in which one codeword extends another forces the decoder to look ahead or to accept an ambiguous split.

The code is stored as a binary tree. A left edge means the bit 0. A right edge means the bit 1. A leaf stores a symbol. The codeword of the symbol is the sequence of bits on the path from the root to that leaf. Internal nodes store no symbol. They store the total frequency of the leaves under them, because the algorithm builds those totals.

**Lemma (the tree is prefix-free).** In any binary tree whose symbols sit only at the leaves, no codeword is a prefix of another.

**Proof.** Suppose the codeword of symbol $a$ were a prefix of the codeword of symbol $b$, with $a \ne b$. The walk that spells the codeword of $a$ would end at a leaf, and the walk that spells the codeword of $b$ would continue past that leaf. A leaf has no child to continue into. The supposition is therefore false.

Frequencies tell the encoder which leaves should sit high in the tree. Let $f(c) > 0$ be the frequency of symbol $c$, and let $d_T(c)$ be the depth of its leaf. The **cost** of the tree is the weighted external path length

$$
B(T) = \sum_c f(c)\, d_T(c).
$$

It counts the bits needed to encode a file in which $c$ occurs $f(c)$ times. Shorter codewords for frequent symbols make $B(T)$ smaller.

**Lemma (an optimal tree is full).** If every frequency is positive, then every optimal tree is full: every node has 0 children or 2 children.

**Proof.** Suppose a node $u$ has exactly one child $v$. Delete $u$ and put $v$ in its place. Every leaf under $v$ moves one edge closer to the root, so its depth decreases by 1. The cost decreases by the total frequency under $v$, which is positive. The original tree was therefore not optimal.

A full tree on $n \ge 1$ leaves has $n - 1$ internal nodes. Count edges. A tree on $N$ nodes has $N - 1$ edges, and a full tree has exactly two edges leaving each internal node, so $N - 1 = 2(N - n)$. Solving gives $N = 2n - 1$ and $N - n = n - 1$ internal nodes.

**Lemma (cost equals the sum of internal frequencies).** In a full code tree, $B(T)$ equals the sum of the frequencies stored at the internal nodes.

**Proof.** Induct on the number of leaves. With two leaves the root frequency is $f(x) + f(y)$, and the cost is $f(x)\cdot 1 + f(y)\cdot 1$. Suppose the identity holds for a full tree $T'$, and form $T$ by replacing a leaf $z$ of $T'$ by an internal node with two leaf children $x$ and $y$, where $f(z) = f(x) + f(y)$. Depths of symbols other than $x$ and $y$ are unchanged. The new depths satisfy $d_T(x) = d_T(y) = d_{T'}(z) + 1$, so

$$
f(x)\, d_T(x) + f(y)\, d_T(y) = f(z)\, d_{T'}(z) + f(x) + f(y).
$$

Hence $B(T) = B(T') + f(x) + f(y)$. By the inductive hypothesis $B(T')$ is the sum of the internal frequencies of $T'$. The internal nodes of $T$ are those of $T'$, plus the new node whose frequency is $f(x) + f(y)$. Adding that frequency produces $B(T)$.

Each merge in the algorithm below creates one internal node. The identity says the cost of the finished tree is the sum of the merge frequencies. That is a useful checksum, and it is the same algebra as $B(T) = B(T') + f(x) + f(y)$.

### The greedy algorithm

Huffman’s algorithm builds the tree from the leaves upward. It keeps a min-heap of trees, ordered by the frequency stored at each root. While two or more trees remain, it extracts the two lightest, makes them the left and right children of a new node, and inserts that node. The first extracted tree becomes the left child. The second becomes the right child. Switching the two children changes the bits and does not change the cost. The convention is fixed here so the trace has one answer.

If two roots have the same frequency, the heap treats the one with the smaller creation id as lighter. Creation ids increase by one each time a node is allocated, leaves first, in the order the symbols are inserted. The worked example never consults the id: every frequency that occupies the heap at the same time is distinct. The rule is there so a tie has one deterministic outcome.

```text
huffman(symbols with positive frequencies):
    Q = an empty min-heap of nodes
    for each symbol c, in the given order:
        insert a leaf (c, f(c)) into Q
    while Q contains at least two nodes:
        x = extractMin(Q)
        y = extractMin(Q)
        z = a new internal node
        z.left = x
        z.right = y
        z.freq = x.freq + y.freq
        insert z into Q
    return extractMin(Q)
```

With a binary heap, the initial build is $\Theta(n)$ if the leaves are loaded by Part 6, and the implementation below inserts the leaves one by one, which is $O(n \log n)$ and harmless inside the same bound. The loop runs $n - 1$ times for $n \ge 1$ symbols. Each iteration performs two extractions and one insertion, each $O(\log n)$. The running time of this implementation is $O(n \log n)$.

### A full trace

The alphabet and frequencies are the standard six-symbol table, written here as integers rather than as thousands. Scaling every frequency by 1000 scales the cost by 1000 and is the 100,000-character file discussed with this table in Chapter 15 of Cormen, Leiserson, Rivest, and Stein. The tree shape is the same at either scale.

| Symbol | $a$ | $b$ | $c$ | $d$ | $e$ | $f$ |
| --- | --- | --- | --- | --- | --- | --- |
| Frequency | 45 | 13 | 12 | 16 | 9 | 5 |

Insert the leaves in increasing frequency order: $f, e, c, b, d, a$. Each new leaf is $\ge$ its parent, so the opening heap is already

```text
[ f:5, e:9, c:12, b:13, d:16, a:45 ]
```

The rows below give the heap after each extraction and after the insertion that follows a pair. A label $(w)$ is an internal node of frequency $w$.

| Step | Heap after the step |
| --- | --- |
| Extract $f{:}5$ | $[e{:}9,\ b{:}13,\ c{:}12,\ a{:}45,\ d{:}16]$ |
| Extract $e{:}9$ | $[c{:}12,\ b{:}13,\ d{:}16,\ a{:}45]$ |
| Insert $(14)$ with left $f$ and right $e$ | $[c{:}12,\ b{:}13,\ d{:}16,\ a{:}45,\ (14)]$ |
| Extract $c{:}12$ | $[b{:}13,\ (14),\ d{:}16,\ a{:}45]$ |
| Extract $b{:}13$ | $[(14),\ a{:}45,\ d{:}16]$ |
| Insert $(25)$ with left $c$ and right $b$ | $[(14),\ (25),\ d{:}16,\ a{:}45]$ |
| Extract $(14)$ | $[d{:}16,\ (25),\ a{:}45]$ |
| Extract $d{:}16$ | $[(25),\ a{:}45]$ |
| Insert $(30)$ with left $(14)$ and right $d$ | $[(25),\ a{:}45,\ (30)]$ |
| Extract $(25)$ | $[(30),\ a{:}45]$ |
| Extract $(30)$ | $[a{:}45]$ |
| Insert $(55)$ with left $(25)$ and right $(30)$ | $[a{:}45,\ (55)]$ |
| Extract $a{:}45$, extract $(55)$, insert $(100)$ | $[(100)]$ |

One check of a single sift, so the table is not magic: the first extraction pops $a{:}45$ into the root of a five-node heap and sifts it. The smaller child is $e{:}9$, then the smaller child of that slot is $b{:}13$, and $a{:}45$ stops as a leaf. The heap is $[e{:}9, b{:}13, c{:}12, a{:}45, d{:}16]$, which is the first row.

The finished tree is

```text
                         (100)
                        /     \
                    a:45      (55)
                             /    \
                         (25)      (30)
                         /  \      /   \
                     c:12  b:13  (14)  d:16
                                 /  \
                              f:5   e:9
```

Reading 0 to the left and 1 to the right:

| Symbol | Codeword | Depth |
| --- | --- | --- |
| $a$ | `0` | 1 |
| $c$ | `100` | 3 |
| $b$ | `101` | 3 |
| $d$ | `111` | 3 |
| $f$ | `1100` | 4 |
| $e$ | `1101` | 4 |

The cost is

$$
45\cdot 1 + 13\cdot 3 + 12\cdot 3 + 16\cdot 3 + 9\cdot 4 + 5\cdot 4 = 45 + 39 + 36 + 48 + 36 + 20 = 224.
$$

The internal frequencies sum to the same number: $14 + 25 + 30 + 55 + 100 = 224$. A fixed-length code for six symbols uses 3 bits each. The total frequency is $45 + 13 + 12 + 16 + 9 + 5 = 100$, so the fixed-length cost is $300$. The prefix code saves the difference on this table.

The word `cafe` encodes as $c$, $a$, $f$, $e$:

$$
100 \cdot 0 \cdot 1100 \cdot 1101 = 100011001101.
$$

Decoding walks from the root. Bits `100` reach $c$. The next bit `0` reaches $a$. Bits `1100` reach $f$. Bits `1101` reach $e$. The walk is back at the root at the end of the string, so the message did not stop inside an unfinished codeword. The word `face` is `110001001101`.

No codeword in the table is a prefix of another. For example, `0` is the code of $a$, and every other codeword begins with `1`. The code `10` is not in the table; it is only the path through $(55)$ and $(25)$.

### The sibling lemma

**Lemma (two rarest symbols are siblings).** Let every frequency be positive, and let $x$ and $y$ be two symbols with $f(x) \le f(y)$ and with $f(y) \le f(c)$ for every symbol $c$ other than $x$ and $y$. There exists an optimal full tree in which $x$ and $y$ are siblings.

**Proof.** Start from an optimal tree $T$. By the fullness lemma, $T$ is full. Because the alphabet has at least the two symbols $x$ and $y$, $T$ has a leaf of maximum depth, and that leaf has a sibling. The sibling is a leaf: an internal sibling would have a descendant leaf at a greater depth. Call these sibling leaves $a$ and $b$, and name them so that $f(a) \le f(b)$. Their common depth is a maximum among leaves.

Exchanging the leaves that occupy two positions changes the cost by a quantity we can sign. If leaves $u$ and $v$ exchange places,

$$
B_{\text{before}} - B_{\text{after}} = \bigl(f(u) - f(v)\bigr)\bigl(d(u) - d(v)\bigr),
$$

because each leaf keeps its frequency and takes the other's depth. The difference is nonnegative when the leaf of larger frequency also has larger or equal depth.

The minimum-frequency choice gives $f(x) \le f(a)$ and $f(x) \le f(b)$.

**Case 1: $b \ne x$.** Then $f(y) \le f(b)$. Indeed, if $b = y$ the two sides are equal, and if $b$ is some other symbol then $b$ is one of the symbols to which the hypothesis $f(y) \le f(c)$ applies. Exchange $a$ with $x$ in $T$, producing $T_1$. The cost does not increase, because $f(a) \ge f(x)$ and $d(a) \ge d(x)$. In $T_1$ the leaf $x$ occupies the old position of $a$, so $x$ is a sibling of $b$. Depths of positions are unchanged by an exchange of labels. Exchange $b$ with $y$ in $T_1$, producing $T_2$. The cost does not increase, because $f(b) \ge f(y)$ and $b$ still sits at maximum depth, so its depth is at least the depth of $y$. In $T_2$ the leaves $x$ and $y$ are siblings. Since $T$ was optimal and neither exchange increased the cost, $T_2$ is optimal.

**Case 2: $b = x$.** Then $x$ is already at maximum depth, and its sibling is $a$. From $f(a) \le f(b) = f(x)$ and $f(x) \le f(a)$ we get $f(a) = f(x)$. If $a = y$, then $x$ and $y$ are already siblings. If $a \ne y$, the hypothesis on $y$ gives $f(y) \le f(a)$, while $f(x) \le f(y)$ and $f(a) = f(x)$ force $f(y) = f(a)$. Exchange $a$ with $y$. The frequency difference is 0, so the cost is unchanged, and $y$ becomes the sibling of $x$. The resulting tree is optimal.

In both cases an optimal tree has $x$ and $y$ as siblings. Their codewords then have the same length and differ in the last bit, because they share the path down to their parent and take opposite edges from that parent.

### The algorithm produces an optimal code

**Lemma (optimal substructure).** Let $x$ and $y$ be a pair of the kind in the sibling lemma, and let $C'$ be the alphabet obtained by removing $x$ and $y$ and adding a new symbol $z$ with $f(z) = f(x) + f(y)$. Let $T'$ be an optimal tree for $C'$. Let $T$ be $T'$ with the leaf $z$ replaced by an internal node whose children are $x$ and $y$. Then $T$ is optimal for the original alphabet.

**Proof.** The depth calculation in the cost-identity argument gives $B(T) = B(T') + f(x) + f(y)$, whether or not $T'$ came from the algorithm. Suppose, for a contradiction, that some tree $T^\*$ for the original alphabet has $B(T^\*) < B(T)$. While $T^\*$ has a node with exactly one child, contract that node as in the fullness lemma. Each contraction removes a positive frequency from the cost, so the resulting full tree $T_{\mathrm{full}}$ satisfies $B(T_{\mathrm{full}}) \le B(T^\*) < B(T)$. The exchange in the sibling proof did not use optimality except to know that the starting tree is full, and $T_{\mathrm{full}}$ is full. Applying that exchange produces a tree $T_2$ in which $x$ and $y$ are siblings and $B(T_2) \le B(T_{\mathrm{full}}) < B(T)$. Contract the common parent of $x$ and $y$ in $T_2$ into a leaf $z$ of frequency $f(x) + f(y)$. The depth calculation, read backwards, produces a tree for $C'$ whose cost is

$$
B(T_2) - f(x) - f(y) < B(T) - f(x) - f(y) = B(T').
$$

That contradicts the optimality of $T'$ for $C'$. Therefore no such $T^\*$ exists.

**Theorem (Huffman optimality).** The algorithm above returns an optimal prefix code.

**Proof.** Induct on $n$, the number of symbols. If $n = 1$, the single leaf has depth 0 and cost 0, which is optimal. If $n = 2$, the only merge joins those two symbols as siblings under a new root. A full tree on two leaves has that shape, and its cost is $f(x) + f(y)$. Swapping the two children changes bits and leaves the cost unchanged. This is the only minimum-pair sequence on two symbols, so every minimum-pair process is optimal for every alphabet of size at most 2.

The inductive claim is stronger than one run of the program, and the extra strength is what the tie rule needs. Assume that on every alphabet of fewer than $n$ symbols, every sequence of merges that always joins two trees of currently minimum frequency produces an optimal tree. The creation-id rule is one way to choose which minimum pair to join when several pairs share that frequency; the claim covers every such choice.

Now take $n \ge 3$. The first iteration extracts two symbols $x$ and $y$ of minimum frequency. They satisfy the hypothesis of the sibling lemma. After they have been replaced by $z$, the priority queue holds exactly the alphabet $C'$ of the substructure lemma, and every later iteration again joins two currently lightest trees. By the inductive claim, the tree $T'$ built for $C'$ is optimal for $C'$. The tree returned for the original alphabet is $T'$ with $z$ expanded back into $x$ and $y$. The substructure lemma says that tree is optimal. A fresh call of the procedure on $C'$ may break ties differently and may draw a different heap array. It is still a minimum-pair process, so the inductive claim applies to the process the original run actually continues, not only to one particular tie resolution.

The inductive step uses both lemmas. The sibling lemma is the exchange. The substructure lemma is the reason a correct solution on the smaller alphabet expands into a correct solution on the original one. The prefix-free property is the leaf-path lemma and does not by itself say the costs are minimal.

---

## Part 10 — Choosing among the array, the search tree, and the heap

The costs below are worst-case unless a cell says amortized or expected. The binary search tree is the unbalanced tree of Lecture 08: its height $h$ is $\Theta(n)$ in the worst case and $\Theta(\log n)$ in expectation when keys are inserted in random order, which is an assumption, not a guarantee. A balanced search tree from Lecture 09 replaces $h$ by $\Theta(\log n)$ and still builds in $\Theta(n \log n)$ time. Balance does not restore the linear build. The heap column is the binary heap of this lecture.

| Operation | Unsorted array | Binary search tree | Binary heap |
| --- | --- | --- | --- |
| `insert` | $\Theta(1)$ | $\Theta(h)$ | $O(\log n)$ sift; amortized $O(\log n)$ with geometric growth |
| `minimum` | $\Theta(n)$ | $\Theta(h)$ | $\Theta(1)$ |
| `extract-min` | $\Theta(n)$ | $\Theta(h)$ | $\Theta(\log n)$ worst case |
| `decrease-key` with a handle already in hand | $\Theta(1)$ to overwrite a slot, after $\Theta(n)$ to find it if the handle is only the key | $\Theta(h)$ to delete and reinsert | $\Theta(\log n)$ |
| `build` from $n$ keys | $\Theta(n)$ to copy them | $\Theta(n \log n)$ in the worst case | $\Theta(n)$ |
| search for an arbitrary key | $\Theta(n)$ | $\Theta(h)$ | $\Theta(n)$ |

Read the last row as the reason a heap is a bad symbol table. Heap order does not say whether a missing key would have lived on the left or on the right. The search has to look at every slot in the worst case.

Read the build row as the reason a search tree is a bad priority queue when the keys arrive all at once and the client only extracts minima afterward. The heap becomes ready in linear time. The search tree spends $\Theta(n \log n)$ establishing an order the client will never query except at the minimum.

Read the height as the reason an unbalanced search tree is a bad priority queue under adversarial insertion. Inserting keys in sorted order produces a path of $n$ nodes. Every later `minimum` or `extract-min` walks that path. The heap's height is $\lfloor \log n \rfloor$ on every insertion order, because the shape is complete by construction and does not depend on the key values.

A fair summary of the purchase: the heap sells logarithmic insert, logarithmic extract-min, logarithmic decrease-key, constant-time minimum, and linear build. It spends arbitrary search to buy them. Buy a heap when the operation mix is the one in the first four rows and the last row is absent. Buy a search tree when arbitrary search is present and a linear build is not required. Buy an unsorted array when the program inserts freely and extracts a minimum only a constant number of times.

Lecture 13 buys the heap, including the position map, because shortest paths and minimum spanning trees decrease the priority of a vertex many times and extract a minimum many times. They do not ask the queue to search by an unrelated key.

---

## Laboratory

The traces in Parts 4 through 9 are the guided traces. Cover the right-hand side of each table, produce the next array yourself, and then uncover it. Use these numbers, which the program checks.

1. Sift-up of 1 appended to $[3, 5, 4, 10]$ ends at $[1, 3, 4, 10, 5]$.
2. Sift-down of $[20, 4, 3, 5, 10, 8, 7]$ from the root visits $[3, 4, 20, 5, 10, 8, 7]$ and ends at $[3, 4, 7, 5, 10, 8, 20]$.
3. Inserting 4, 10, 3, 5, 1 yields the five arrays in the Part 5 table, with 4 swaps, and one extract-min leaves $[3, 5, 4, 10]$.
4. Build-heap on $[4, 10, 3, 5, 1]$ calls sift-down twice, swaps twice, and ends at $[1, 4, 3, 5, 10]$, which differs from the insertion heap.
5. Heapsort of $[4, 10, 3, 5, 1]$ passes through $[10, 5, 3, 4, 1]$, $[5, 4, 3, 1, 10]$, $[4, 1, 3, 5, 10]$, $[3, 1, 4, 5, 10]$, and $[1, 3, 4, 5, 10]$.
6. Heapsort of the records $(2, a)$ then $(2, b)$ returns $b$ then $a$.
7. Decrease-key of 10 to 2 on the insertion heap yields $[1, 2, 4, 3, 5]$ with the position map of Part 8.
8. The Huffman insertion order $f, e, c, b, d, a$ produces merge frequencies $14, 25, 30, 55, 100$, the codewords in the Part 9 table, cost 224, the encoding `100011001101` for `cafe`, and the encoding `110001001101` for `face`.

Do the following on paper before you read the program. Then run the program and confirm that your paper matches it.

1. Compute $S_4 = \sum_{k=1}^{4} k/2^k$ as one fraction, and compute $2 - (4+2)/2^4$.
2. For a heap of 10 keys, write the parent, left child, and right child of index 4, and write the leaf indexes.
3. On the built heap $[1, 4, 3, 5, 10]$, list the height of every index and add those heights. Compare the sum with $2^H S_H$ for $H = \lfloor \log 5 \rfloor$.

The program is deterministic. It throws if an assertion fails. After it prints `ALL TESTS PASSED`, change one expected array, run it again, watch the assertion throw, and restore the line. That is the check that the test is actually examining the heap.

## LABORATORY PROGRAM

```javascript
import assert from "node:assert/strict";

class MinHeap {
  constructor() {
    this.keys = [];
    this.position = new Map();
    this.swapCount = 0;
  }

  size() {
    return this.keys.length;
  }

  parent(i) {
    return Math.floor((i - 1) / 2);
  }

  left(i) {
    return 2 * i + 1;
  }

  right(i) {
    return 2 * i + 2;
  }

  swap(i, j) {
    const leftKey = this.keys[i];
    const rightKey = this.keys[j];
    this.keys[i] = rightKey;
    this.keys[j] = leftKey;
    this.position.set(rightKey, i);
    this.position.set(leftKey, j);
    this.swapCount += 1;
  }

  siftUp(i) {
    while (i > 0) {
      const p = this.parent(i);
      if (this.keys[p] <= this.keys[i]) {
        return;
      }
      this.swap(i, p);
      i = p;
    }
  }

  siftDown(i) {
    const n = this.keys.length;
    while (true) {
      let smallest = i;
      const l = this.left(i);
      const r = this.right(i);
      if (l < n && this.keys[l] < this.keys[smallest]) {
        smallest = l;
      }
      if (r < n && this.keys[r] < this.keys[smallest]) {
        smallest = r;
      }
      if (smallest === i) {
        return;
      }
      this.swap(i, smallest);
      i = smallest;
    }
  }

  insert(key) {
    if (this.position.has(key)) {
      throw new Error("duplicate key");
    }
    this.keys.push(key);
    const i = this.keys.length - 1;
    this.position.set(key, i);
    this.siftUp(i);
  }

  minimum() {
    if (this.keys.length === 0) {
      throw new Error("empty heap");
    }
    return this.keys[0];
  }

  extractMin() {
    if (this.keys.length === 0) {
      throw new Error("empty heap");
    }
    const min = this.keys[0];
    const last = this.keys.pop();
    this.position.delete(min);
    if (this.keys.length === 0) {
      return min;
    }
    this.keys[0] = last;
    this.position.set(last, 0);
    this.siftDown(0);
    return min;
  }

  decreaseKey(key, newKey) {
    if (!this.position.has(key)) {
      throw new Error("missing key");
    }
    if (!(newKey < key)) {
      throw new Error("new key must be smaller");
    }
    if (this.position.has(newKey)) {
      throw new Error("duplicate key");
    }
    const i = this.position.get(key);
    this.position.delete(key);
    this.keys[i] = newKey;
    this.position.set(newKey, i);
    this.siftUp(i);
  }
}

function assertMinHeap(heap) {
  const keys = heap.keys;
  for (let i = 1; i < keys.length; i += 1) {
    const p = Math.floor((i - 1) / 2);
    assert.ok(keys[p] <= keys[i]);
  }
  assert.equal(heap.position.size, keys.length);
  for (let i = 0; i < keys.length; i += 1) {
    assert.equal(heap.position.get(keys[i]), i);
  }
}

function buildMinHeap(source) {
  const heap = new MinHeap();
  heap.keys = source.slice();
  for (let i = 0; i < heap.keys.length; i += 1) {
    if (heap.position.has(heap.keys[i])) {
      throw new Error("duplicate key");
    }
    heap.position.set(heap.keys[i], i);
  }
  heap.swapCount = 0;
  let siftCalls = 0;
  const lastInternal = Math.floor((heap.keys.length - 2) / 2);
  for (let i = lastInternal; i >= 0; i -= 1) {
    heap.siftDown(i);
    siftCalls += 1;
  }
  heap.siftCalls = siftCalls;
  return heap;
}

function siftDownMinArray(keys, start) {
  const a = keys.slice();
  let i = start;
  const states = [a.slice()];
  while (true) {
    let smallest = i;
    const l = 2 * i + 1;
    const r = 2 * i + 2;
    if (l < a.length && a[l] < a[smallest]) {
      smallest = l;
    }
    if (r < a.length && a[r] < a[smallest]) {
      smallest = r;
    }
    if (smallest === i) {
      return states;
    }
    const tmp = a[i];
    a[i] = a[smallest];
    a[smallest] = tmp;
    i = smallest;
    states.push(a.slice());
  }
}

function heapSort(keys) {
  const states = [];
  function siftDown(i, size) {
    while (true) {
      let largest = i;
      const l = 2 * i + 1;
      const r = 2 * i + 2;
      if (l < size && keys[l] > keys[largest]) {
        largest = l;
      }
      if (r < size && keys[r] > keys[largest]) {
        largest = r;
      }
      if (largest === i) {
        return;
      }
      const tmp = keys[i];
      keys[i] = keys[largest];
      keys[largest] = tmp;
      i = largest;
    }
  }
  const lastInternal = Math.floor((keys.length - 2) / 2);
  for (let i = lastInternal; i >= 0; i -= 1) {
    siftDown(i, keys.length);
  }
  states.push(keys.slice());
  for (let size = keys.length; size > 1; size -= 1) {
    const tmp = keys[0];
    keys[0] = keys[size - 1];
    keys[size - 1] = tmp;
    siftDown(0, size - 1);
    states.push(keys.slice());
  }
  return states;
}

function heapSortRecords(records) {
  function siftDown(i, size) {
    while (true) {
      let largest = i;
      const l = 2 * i + 1;
      const r = 2 * i + 2;
      if (l < size && records[l].priority > records[largest].priority) {
        largest = l;
      }
      if (r < size && records[r].priority > records[largest].priority) {
        largest = r;
      }
      if (largest === i) {
        return;
      }
      const tmp = records[i];
      records[i] = records[largest];
      records[largest] = tmp;
      i = largest;
    }
  }
  const lastInternal = Math.floor((records.length - 2) / 2);
  for (let i = lastInternal; i >= 0; i -= 1) {
    siftDown(i, records.length);
  }
  for (let size = records.length; size > 1; size -= 1) {
    const tmp = records[0];
    records[0] = records[size - 1];
    records[size - 1] = tmp;
    siftDown(0, size - 1);
  }
}

class HuffNode {
  constructor(id, freq, symbol, left, right) {
    this.id = id;
    this.freq = freq;
    this.symbol = symbol;
    this.left = left;
    this.right = right;
  }
}

function huffman(pairs) {
  let nextId = 0;
  const heap = [];
  function comesBefore(x, y) {
    if (x.freq !== y.freq) {
      return x.freq < y.freq;
    }
    return x.id < y.id;
  }
  function siftUp(i) {
    while (i > 0) {
      const p = Math.floor((i - 1) / 2);
      if (!comesBefore(heap[i], heap[p])) {
        return;
      }
      const tmp = heap[i];
      heap[i] = heap[p];
      heap[p] = tmp;
      i = p;
    }
  }
  function siftDown(i) {
    const n = heap.length;
    while (true) {
      let smallest = i;
      const l = 2 * i + 1;
      const r = 2 * i + 2;
      if (l < n && comesBefore(heap[l], heap[smallest])) {
        smallest = l;
      }
      if (r < n && comesBefore(heap[r], heap[smallest])) {
        smallest = r;
      }
      if (smallest === i) {
        return;
      }
      const tmp = heap[i];
      heap[i] = heap[smallest];
      heap[smallest] = tmp;
      i = smallest;
    }
  }
  function insert(node) {
    heap.push(node);
    siftUp(heap.length - 1);
  }
  function extractMin() {
    if (heap.length === 0) {
      throw new Error("empty heap");
    }
    const min = heap[0];
    const last = heap.pop();
    if (heap.length === 0) {
      return min;
    }
    heap[0] = last;
    siftDown(0);
    return min;
  }
  for (let i = 0; i < pairs.length; i += 1) {
    insert(new HuffNode(nextId, pairs[i].freq, pairs[i].symbol, null, null));
    nextId += 1;
  }
  const merges = [];
  while (heap.length > 1) {
    const x = extractMin();
    const y = extractMin();
    const parent = new HuffNode(nextId, x.freq + y.freq, null, x, y);
    nextId += 1;
    merges.push(parent.freq);
    insert(parent);
  }
  const root = heap[0];
  const codes = {};
  function walk(node, code) {
    if (node.left === null && node.right === null) {
      codes[node.symbol] = code;
      return;
    }
    walk(node.left, code + "0");
    walk(node.right, code + "1");
  }
  walk(root, "");
  return { root, codes, merges };
}

function decodeHuffman(root, bits) {
  let text = "";
  let node = root;
  for (let i = 0; i < bits.length; i += 1) {
    if (bits[i] === "0") {
      node = node.left;
    } else if (bits[i] === "1") {
      node = node.right;
    } else {
      throw new Error("bad bit");
    }
    if (node.left === null && node.right === null) {
      text += node.symbol;
      node = root;
    }
  }
  if (node !== root) {
    throw new Error("dangling bits");
  }
  return text;
}

function floorLog2(n) {
  let h = 0;
  let power = 1;
  while (power * 2 <= n) {
    power *= 2;
    h += 1;
  }
  return h;
}

function treeHeight(n) {
  if (n === 0) {
    return -1;
  }
  function heightAt(i) {
    const l = 2 * i + 1;
    if (l >= n) {
      return 0;
    }
    const r = l + 1;
    const leftHeight = heightAt(l);
    const rightHeight = r < n ? heightAt(r) : -1;
    return 1 + Math.max(leftHeight, rightHeight);
  }
  return heightAt(0);
}

function seriesNumerator(n) {
  let numerator = 0;
  for (let k = 1; k <= n; k += 1) {
    numerator += k * 2 ** (n - k);
  }
  return numerator;
}

const inserted = new MinHeap();
const insertTrace = [];
for (const key of [4, 10, 3, 5, 1]) {
  inserted.insert(key);
  insertTrace.push(inserted.keys.slice());
  assertMinHeap(inserted);
}
assert.deepEqual(insertTrace, [
  [4],
  [4, 10],
  [3, 10, 4],
  [3, 5, 4, 10],
  [1, 3, 4, 10, 5],
]);
assert.equal(inserted.swapCount, 4);
assert.equal(inserted.minimum(), 1);
assert.equal(inserted.extractMin(), 1);
assert.deepEqual(inserted.keys.slice(), [3, 5, 4, 10]);
assertMinHeap(inserted);
assert.deepEqual(
  [0, 1, 2, 3].map((i) => inserted.position.get(inserted.keys[i])),
  [0, 1, 2, 3],
);

const built = buildMinHeap([4, 10, 3, 5, 1]);
assert.deepEqual(built.keys.slice(), [1, 4, 3, 5, 10]);
assert.equal(built.swapCount, 2);
assert.equal(built.siftCalls, 2);
assertMinHeap(built);
assert.notDeepEqual(built.keys.slice(), insertTrace[4]);

const siftStates = siftDownMinArray([20, 4, 3, 5, 10, 8, 7], 0);
assert.deepEqual(siftStates, [
  [20, 4, 3, 5, 10, 8, 7],
  [3, 4, 20, 5, 10, 8, 7],
  [3, 4, 7, 5, 10, 8, 20],
]);

const sortKeys = [4, 10, 3, 5, 1];
const sortStates = heapSort(sortKeys);
assert.deepEqual(sortKeys, [1, 3, 4, 5, 10]);
assert.deepEqual(sortStates, [
  [10, 5, 3, 4, 1],
  [5, 4, 3, 1, 10],
  [4, 1, 3, 5, 10],
  [3, 1, 4, 5, 10],
  [1, 3, 4, 5, 10],
]);

const records = [
  { priority: 2, id: "a" },
  { priority: 2, id: "b" },
];
heapSortRecords(records);
assert.deepEqual(records.map((record) => record.id), ["b", "a"]);

const withHandle = new MinHeap();
for (const key of [4, 10, 3, 5, 1]) {
  withHandle.insert(key);
}
withHandle.decreaseKey(10, 2);
assert.deepEqual(withHandle.keys.slice(), [1, 2, 4, 3, 5]);
assert.equal(withHandle.position.get(1), 0);
assert.equal(withHandle.position.get(2), 1);
assert.equal(withHandle.position.get(4), 2);
assert.equal(withHandle.position.get(3), 3);
assert.equal(withHandle.position.get(5), 4);
assertMinHeap(withHandle);
assert.equal(withHandle.position.has(10), false);

const coded = huffman([
  { symbol: "f", freq: 5 },
  { symbol: "e", freq: 9 },
  { symbol: "c", freq: 12 },
  { symbol: "b", freq: 13 },
  { symbol: "d", freq: 16 },
  { symbol: "a", freq: 45 },
]);
assert.deepEqual(coded.codes, {
  a: "0",
  b: "101",
  c: "100",
  d: "111",
  e: "1101",
  f: "1100",
});
assert.deepEqual(coded.merges, [14, 25, 30, 55, 100]);
assert.equal(decodeHuffman(coded.root, "100011001101"), "cafe");
assert.equal(decodeHuffman(coded.root, "110001001101"), "face");
const symbols = Object.keys(coded.codes);
for (let i = 0; i < symbols.length; i += 1) {
  for (let j = 0; j < symbols.length; j += 1) {
    if (i !== j) {
      assert.equal(coded.codes[symbols[j]].startsWith(coded.codes[symbols[i]]), false);
    }
  }
}
let weighted = 0;
for (const symbol of symbols) {
  const freq = { a: 45, b: 13, c: 12, d: 16, e: 9, f: 5 }[symbol];
  weighted += freq * coded.codes[symbol].length;
}
assert.equal(weighted, 224);

for (let n = 1; n <= 32; n += 1) {
  assert.equal(treeHeight(n), floorLog2(n));
}
for (let n = 1; n <= 20; n += 1) {
  assert.equal(seriesNumerator(n), 2 ** (n + 1) - (n + 2));
}

assert.equal(Math.floor((4 - 1) / 2), 1);
assert.equal(2 * 4 + 1, 9);
assert.equal(2 * 4 + 2, 10);

console.log("ALL TESTS PASSED");
```

---

## Common mistakes

1. **Wrong idea:** the parent of a 0-indexed slot $i$ is $\lfloor i/2 \rfloor$, the formula from a 1-indexed drawing. **Correction:** the parent is $\lfloor (i-1)/2 \rfloor$. For $i = 2$, $\lfloor 2/2 \rfloor = 1$, but the parent of index 2 is the root, index 0. The right child of the root is $2\cdot 0+2 = 2$.

2. **Wrong idea:** the heap array is sorted, or a min-heap is a binary search tree drawn in level order. **Correction:** heap order constrains each parent and its children. The array $[1, 4, 3, 5, 10]$ is a min-heap, it is not sorted, and the node 4 has left child 5.

3. **Wrong idea:** build-heap means insert the keys one by one, so its cost is linear because "heaps are logarithmic and the logarithms cancel." **Correction:** $n$ successive insertions are $\Theta(n \log n)$ in the worst case. The linear algorithm sifts down from the last internal node. The sum of node heights is what cancels the logarithm, and that sum is a different charging from $n$ full-height sifts.

4. **Wrong idea:** heapsort is linear because the build is linear. **Correction:** after the build, the algorithm extracts $n-1$ times from the root. That phase is $O(n \log n)$, and the comparison lower bound of Lecture 06 makes the worst case $\Theta(n \log n)$.

5. **Wrong idea:** heapsort is stable because the sift uses a strict comparison and therefore leaves equal keys alone. **Correction:** the strict comparison does leave equal keys unswapped during a sift. The swap that moves the root into the sorted suffix still reorders equal keys, as it does for $(2, a)$ followed by $(2, b)$.

6. **Wrong idea:** sift-down in a min-heap swaps with the larger child, by analogy with "the child that is out of order." **Correction:** the parent must become $\le$ both children, so it swaps with the smaller child. Swapping 20 with 4 in $[20, 4, 3, \ldots]$ leaves 4 above 3.

7. **Wrong idea:** decrease-key can remember the index from the last time it saw the key, and a later sift does not affect that memory. **Correction:** every swap changes two indexes. The position map has to be written inside the swap. Forgetting one direction sends the next decrease-key at a slot that now holds a different key.

8. **Wrong idea:** a code that gives frequent symbols short strings is prefix-free whenever the strings are distinct. **Correction:** distinct strings can still extend one another. The codewords $0$ and $01$ are distinct, and $0$ is a prefix of $01$. The leaf property is what forbids that extension. Assigning bits by sorting the frequencies and writing their ranks in binary does not build a tree and need not be prefix-free.

9. **Wrong idea:** a leaf has height 1, or the height of an $n$-node heap is $n$. **Correction:** a leaf has height 0, and the height of the complete tree is $\lfloor \log n \rfloor$. Using the wrong height turns the sift bound and the series into a different function.

10. **Wrong idea:** decrease-key on a min-heap sifts down, because the key "moves away from the minimum." **Correction:** a smaller key belongs closer to the root. The children remain larger than it. The parent may not. The repair is sift-up.

---

## Examination

Closed book. Ninety minutes. Write a full solution for each item. The answer key is the next section; do not open it until you have attempted the paper.

**1.** Define heap order for a min-heap, the height of a node, a handle, and a prefix-free code.

**2.** Name the four priority-queue operations this lecture implements for a minimum, and name one operation the binary heap does not provide in $o(n)$ time unless a handle is added.

**3.** A heap holds $n = 10$ keys in a 0-indexed array. For index 4, give the parent, the left child, and the right child. Which of those children occupy a slot? List every leaf index. Give the index of the last internal node. Prove the height is 3 by exhibiting $2^h \le 10 \le 2^{h+1}-1$.

**4.** The array $[9, 2, 5, 4, 3]$ has min-heap subtrees at both children of the root. Sift the root down. Write the array after each swap, and name the child index chosen at each swap.

**5.** Compute $S_5 = \sum_{k=1}^{5} k/2^k$ as a single fraction. Using the finite-series identity, compute $2 - (5+2)/2^5$ as a fraction and show the two results are equal. State the value of $\sum_{k=1}^{\infty} k/2^k$.

**6.** Heapsort the array $[3, 1, 4, 2]$ with the max-heap procedure of Part 7. Write the array after the build and after each extraction. Then heapsort the records $(2, a)$ followed by $(2, b)$ and use the result in one sentence that says why the sort is unstable. In a further sentence, say why the linear build does not make heapsort linear.

**7.** Build a Huffman code for the frequencies $a{:}2$, $b{:}3$, $c{:}4$, $d{:}10$. Insert the leaves in the order $a, b, c, d$. The first extracted node of a merge is the left child. Give every codeword, the cost $B(T)$, and the result of decoding `000101`.

**8.** Consider the tree

```text
        1
       / \
      4   3
     / \
    5  10
```

State whether it is a min-heap, and justify the answer with the parent-child comparisons. State whether it is a binary search tree, and name a comparison that fails. Then say why an unbalanced binary search tree is the wrong priority queue when keys arrive in sorted order and the client repeatedly extracts the minimum.

**9.** A min-heap is $[1, 3, 4, 10, 5]$, with the position map that sends each key to its index. Decrease 10 to 0. Write the array after each swap and the position map at the end. State why the repair sifts up.

**10.** Fill the worst-case costs of `insert`, `extract-min`, and `build` for an unsorted array, an unbalanced binary search tree, and a binary heap. One sentence: which of the three do you choose for a client that only inserts and extracts minima, on an adversarial key order, with $n$ large?

---

## Answer key

**1.** Heap order for a min-heap: every parent key is $\le$ each of its children. Equivalently, for every index $i \ge 1$, the key at $\lfloor (i-1)/2 \rfloor$ is $\le$ the key at $i$. The height of a node is the number of edges on a longest downward path from that node to a leaf; a leaf has height 0. A handle is the information that locates a stored key without a scan; in this lecture it is the position map from a unique key to its index, or, when keys may repeat, the identity of the node. A prefix-free code assigns each symbol a codeword so that no codeword is a prefix of a different codeword.

**2.** The four operations are `insert`, `minimum`, `extract-min`, and `decrease-key`. Without a handle, search for an arbitrary key is not available in $o(n)$ time. Predecessor, successor, and deletion of an arbitrary key fail for the same reason; naming search is enough.

**3.** The parent of 4 is $\lfloor (4-1)/2 \rfloor = \lfloor 1.5 \rfloor = 1$. The left child is $2\cdot 4+1 = 9$. The right child is $2\cdot 4+2 = 10$. Index 9 is a slot of an array of length 10. Index 10 is not. A node is a leaf when $2i+1 \ge 10$, so $i \ge 5$. The leaf indexes are 5, 6, 7, 8, and 9. The last internal index is $\lfloor (10-2)/2 \rfloor = 4$, which is also the parent of index 9. For the height, $2^3 = 8 \le 10 \le 15 = 2^4 - 1$. Part 3 proved that the unique integer $h$ in that range is the height, so the height is 3. The same statement is $h = \lfloor \log 10 \rfloor = 3$.

**4.** Children of the root are index 1 (value 2) and index 2 (value 5). The smaller child index is 1. Swap index 0 with index 1:

$$
[2, 9, 5, 4, 3].
$$

Children of index 1 are index 3 (value 4) and index 4 (value 3). The smaller child index is 4. Swap index 1 with index 4:

$$
[2, 3, 5, 4, 9].
$$

Index 4 has no child. The sift stops. Heap order: $2 \le 3$, $2 \le 5$, $3 \le 4$, and $3 \le 9$.

**5.** The five terms are $1/2$, $2/4$, $3/8$, $4/16$, and $5/32$. With denominator 32,

$$
\frac{16}{32} + \frac{16}{32} + \frac{12}{32} + \frac{8}{32} + \frac{5}{32} = \frac{57}{32}.
$$

The identity gives

$$
2 - \frac{7}{32} = \frac{64}{32} - \frac{7}{32} = \frac{57}{32}.
$$

The two fractions are equal. The infinite sum is 2, because $S_n = 2 - (n+2)/2^n$ and $(n+2)/2^n$ tends to 0, as proved from $2^n \ge n^2$ for $n \ge 4$.

**6.** Build. Sift index 1 in $[3, 1, 4, 2]$: the larger child of 1 is 2 at index 3, and $1 < 2$, so one swap produces $[3, 2, 4, 1]$. Sift index 0: the larger child of 3 is 4 at index 2, so one swap produces $[4, 2, 3, 1]$. Index 2 is a leaf. The max-heap is $[4, 2, 3, 1]$.

Extract with size 3 after the parking swap: swap index 0 with index 3 to get $[1, 2, 3, 4]$, then sift inside size 3. The larger child of 1 is 3 at index 2. Swap to get $[3, 2, 1, 4]$.

Extract with size 2: swap index 0 with index 2 to get $[1, 2, 3, 4]$, then sift inside size 2. The only child is 2, and $1 < 2$, so swap to get $[2, 1, 3, 4]$.

Extract with size 1: swap index 0 with index 1 to get $[1, 2, 3, 4]$. The array is sorted.

The records $(2, a)$ then $(2, b)$ build with no sift swap, because the child priority is not strictly greater. The extract swaps them, so the output order is $b$ then $a$. Equal keys reversed their input order, which is what instability means.

The build is $\Theta(n)$. The $n-1$ extractions that follow cost $O(n \log n)$ altogether, and a comparison sort requires $\Omega(n \log n)$ comparisons on some input. The linear term does not dominate the sum.

**7.** Insert order $a{:}2$, $b{:}3$, $c{:}4$, $d{:}10$ produces the opening heap $[a{:}2, b{:}3, c{:}4, d{:}10]$, because each inserted frequency is at least its parent's.

Extract $a$, then $b$. The heap after those two extractions is $[c{:}4, d{:}10]$. Insert $(5)$ with left $a$ and right $b$. Extract $c$, then $(5)$. Insert $(9)$ with left $c$ and right $(5)$. Extract $(9)$, then $d$. Insert $(19)$ with left $(9)$ and right $d$.

```text
              (19)
             /    \
           (9)    d:10
          /   \
       c:4    (5)
             /   \
          a:2    b:3
```

Codewords: $d = 1$, $c = 00$, $a = 010$, $b = 011$. The cost is

$$
10\cdot 1 + 4\cdot 2 + 2\cdot 3 + 3\cdot 3 = 10 + 8 + 6 + 9 = 33.
$$

The internal frequencies $5 + 9 + 19 = 33$ match. Decoding `000101` takes `00` to $c$, `010` to $a$, and `1` to $d$, so the message is `cad`.

**8.** The tree is a min-heap. The root 1 is $\le$ both 4 and 3. The node 4 is $\le$ both 5 and 10. The node 3 is a leaf.

It is not a binary search tree. At the node 4, the left child is 5, and $5 > 4$, so the left subtree is not confined to keys $\le 4$.

An unbalanced binary search tree that receives keys in sorted order becomes a single path of length $n-1$. Each `extract-min` then walks $\Theta(n)$ nodes. A heap on the same keys has height $\lfloor \log n \rfloor$ regardless of insertion order, so each extraction is $O(\log n)$. The search tree also spends $\Theta(n^2)$ time on that particular build, while the heap builds in $\Theta(n)$ time.

**9.** The key 10 sits at index 3. Write 0 there: $[1, 3, 4, 0, 5]$, and point the map entry for 0 at index 3. The parent index is 1, which holds 3. Because $0 < 3$, swap: $[1, 0, 4, 3, 5]$. The parent index is 0, which holds 1. Because $0 < 1$, swap: $[0, 1, 4, 3, 5]$. The sift is at the root and stops.

The position map is $0 \mapsto 0$, $1 \mapsto 1$, $4 \mapsto 2$, $3 \mapsto 3$, $5 \mapsto 4$. There is no entry for 10.

The new key is smaller than the old one, so every child, which was $\ge 10$, is still $\ge 0$. The parent may be larger than 0. The broken comparisons lie on the path to the root, and sift-up walks that path.

**10.**

| Operation | Unsorted array | Unbalanced BST | Binary heap |
| --- | --- | --- | --- |
| `insert` | $\Theta(1)$ | $\Theta(n)$ worst case | $O(\log n)$ worst-case sift |
| `extract-min` | $\Theta(n)$ | $\Theta(n)$ worst case | $\Theta(\log n)$ worst case |
| `build` | $\Theta(n)$ | $\Theta(n^2)$ on sorted insertion, $\Theta(n \log n)$ even when balanced | $\Theta(n)$ |

Choose the binary heap. The client never searches for an arbitrary key, the insertion order may be adversarial, and both insert and extract-min stay logarithmic while the build stays linear.

---

## Independent assignment

Write a single JavaScript program, with no libraries, that you can run under Node. Keep the file. Lecture 13 assumes you can still build an indexed heap.

The heap stores node objects `{ id, priority }`. The position map sends the object itself to its index, so two nodes may share a numeric priority. Order the heap by priority, and break equal priorities by the smaller `id`, so every run is deterministic. Implement `insert`, `minimum`, `extractMin`, `decreaseKey(node, newPriority)`, and `buildHeap`. `decreaseKey` requires the new priority to be strictly smaller and sifts up, updating the map inside every swap.

For each $n$ in $\{16, 64, 256, 1024\}$:

1. Build a min-heap from the priorities $n, n-1, \ldots, 1$ by sifting down from the last internal node. Record the number of swaps.
2. Insert those same priorities one by one into an empty min-heap, each new key a new minimum. Record the number of swaps. This number must equal $\sum_{k=1}^{n} \lfloor \log k \rfloor$, because the $k$-th insertion appends at index $k-1$ and swaps once for each edge on the path to the root.
3. Compute the sum of the node heights of the complete shape on $n$ nodes, and check that the sum is $\le 2n$.

Print one line per $n$ with the build-swap count, the insert-swap count, the sum of heights, and $2n$. The insert-swap count must be strictly larger than the build-swap count on each of these four inputs. In a comment, derive $\sum_{k=\lfloor n/2 \rfloor+1}^{n} \lfloor \log k \rfloor \ge (n/2)\,(\lfloor \log n \rfloor - 1)$ for $n = 1024$ and compare that lower bound with the insert-swap count you measured. That comparison is the concrete form of the claim that successive insertion is a different, superlinear algorithm.

Then run Huffman, with the same left-child and creation-id rules as the lecture, on the six frequencies of Part 9. Encode the string `cafe face`, decode the bits, and assert that the decoded string is the original. In a comment of at least 150 words, name the two rarest symbols, state the sibling lemma, and point at the two extractions and the assignment of the left and right children, which is the step the exchange argument licenses.

The artifact is the program, the four printed lines, and that comment. A correct program throws on a failed assertion and otherwise prints the table and then `ALL TESTS PASSED`.

---

## Glossary

**Binary heap.** A complete binary tree stored in a 0-indexed array and ordered by heap order. The course default in Parts 1 through 6 and Part 8 is a min-heap.

**Build-heap.** The construction that writes $n$ keys into the array and sifts down from the last internal node to the root. Its running time is $\Theta(n)$. It is not the algorithm that inserts $n$ times.

**Complete binary tree.** Every level except the last is full, and the last level is filled from the left. The occupied indexes are $0$ through $n-1$.

**Cost of a code tree.** $B(T) = \sum_c f(c)\, d_T(c)$, the number of bits needed to encode a file with those frequencies. In a full tree it also equals the sum of the internal-node frequencies.

**Decrease-key.** The priority-queue operation that replaces a stored key by a strictly smaller key and restores heap order, given a handle to the old key.

**Depth.** The number of edges from the root to the node. The root has depth 0.

**Extract-min.** Remove and return a smallest key. In a min-heap the smallest key is the root, the last leaf moves to the root, and sift-down restores heap order.

**Full binary tree.** Every node has 0 children or 2 children. An optimal Huffman tree is full. A heap is complete, and a complete tree need not be full, because the last internal node may have one child.

**Handle.** Information that locates a stored item without scanning. Here, a position map.

**Heap order.** In a min-heap, every parent is $\le$ its children. In a max-heap, every parent is $\ge$ its children.

**Heapsort.** Build a max-heap, then repeatedly swap the root into the end of the current heap and sift down inside the reduced size. In-place, unstable, worst-case $\Theta(n \log n)$.

**Height of a node.** The number of edges on a longest path from the node down to a leaf. A leaf has height 0. The empty tree has height $-1$.

**Huffman code.** The prefix code built by repeatedly merging the two lightest trees in a min-heap. Under the lecture's left-child convention it is one concrete optimal code; other conventions change bits and keep the cost.

**Increase-key.** The max-heap analogue of decrease-key, or, on a min-heap, a replacement by a larger key followed by sift-down.

**In-place.** The algorithm uses only a constant amount of memory beyond the input array.

**Insert.** Append the key at the next complete-tree slot and sift up.

**Last internal node.** The parent of index $n-1$, which is $\lfloor (n-2)/2 \rfloor$, when $n \ge 2$.

**Maximum / max-priority queue.** The priority queue whose extreme key is a largest key.

**Minimum.** A smallest key. In a min-heap, `minimum` reads index 0 and does not remove it.

**Min-heap.** A complete binary tree with min-heap order, stored at indexes $0$ through $n-1$.

**Position map.** The map from a unique key, or from a node object, to the index where that item currently sits. Every swap updates it.

**Prefix-free code.** A code in which no codeword is a prefix of another. Leaf codewords of a binary tree have this property.

**Priority queue.** The abstract data type supporting insert, access to an extreme key, extraction of an extreme key, and, with a handle, a decrease or an increase of a stored key.

**Sift-down.** Swap a key with its smaller child (min-heap) or larger child (max-heap) until heap order holds in its subtree. Worst-case $O(\log n)$.

**Sift-up.** Swap a key with its parent while the key violates heap order with that parent. Worst-case $O(\log n)$.

**Stable sort.** A sort that preserves the relative order of records whose sort keys are equal. Heapsort is not stable.

**Weighted external path length.** The cost $B(T)$.

---

## Lecture summary

A min-heap is a complete binary tree in a 0-indexed array, with every parent $\le$ its children. The parent of $i$ is $\lfloor (i-1)/2 \rfloor$, and the children are $2i+1$ and $2i+2$. The height is $\lfloor \log n \rfloor$, so one sift is $O(\log n)$. The root is the minimum even though the array is not sorted and the tree is not a search tree.

Insert appends and sifts up. Extract-min parks the last leaf at the root and sifts down. Decrease-key, given a position map that swaps keep honest, writes the smaller key and sifts up. The map assumes unique keys, or it assumes that the handle is a node identity rather than the priority value. Lecture 13 uses that handle.

Build-heap sifts down from the last internal node. The sum of node heights is at most $n \sum_{k \ge 1} k/2^k = 2n$, so the construction is $\Theta(n)$. Inserting $n$ times is a different algorithm and is $\Theta(n \log n)$ in the worst case.

Heapsort builds a max-heap and extracts the maximum into the end of the array. It is in-place and unstable. The linear build does not make it linear, because the extractions cost $\Theta(n \log n)$ in the worst case.

Huffman coding is the priority queue applied to trees. Merging the two lightest trees, with the first extraction on the left, produced the code $a{:}0$, $c{:}100$, $b{:}101$, $d{:}111$, $f{:}1100$, $e{:}1101$ for the frequencies in Part 9, at cost 224. The exchange argument shows that some optimal tree makes the two rarest symbols siblings, and the inductive expansion of that merge shows the algorithm's tree is optimal. The code is prefix-free because symbols occupy leaves.

### Five principles

1. Heap order is a comparison between a parent and its children. It puts the extreme key at the root and leaves the array unsorted.
2. The complete shape fixes both the index formulas and the height $\lfloor \log n \rfloor$, and that height is the length of a sift.
3. Build from the bottom. The sum of heights is linear, and $n$ successive insertions are a slower algorithm.
4. Decrease-key is a sift only when a handle already names the slot. The swap that moves the key has to move the handle.
5. Huffman’s exchange seats the two rarest symbols as siblings, and the leaf paths are what make the code prefix-free.

---

## References

1. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapter 6 (heaps, the linear build, heapsort, and the priority queue) and Chapter 15, in particular the Huffman-code section.
2. Robert Sedgewick and Kevin Wayne. *Algorithms*. 4th edition. Addison-Wesley, 2011. Section 2.4 (priority queues, binary heaps, and heapsort) and Section 5.5 (Huffman compression). The book numbers heap slots from 1. This course numbers them from 0.
3. Michael T. Goodrich, Roberto Tamassia, and Michael H. Goldwasser. *Data Structures and Algorithms in Java*. 6th edition. Wiley, 2014. Chapter 9 (priority queues and heaps). The analysis transfers; the code in this lecture is JavaScript.
4. Mark Allen Weiss. *Data Structures and Algorithm Analysis in C++*. 4th edition. Pearson, 2014. Chapter 6 (priority queues and heaps).
5. J. W. J. Williams. "Algorithm 232: Heapsort." *Communications of the ACM*, volume 7, issue 6, 1964.
6. Robert W. Floyd. "Algorithm 245: Treesort 3." *Communications of the ACM*, volume 7, issue 12, 1964. The linear bottom-up construction.
7. David A. Huffman. "A Method for the Construction of Minimum-Redundancy Codes." *Proceedings of the IRE*, volume 40, issue 9, 1952.
