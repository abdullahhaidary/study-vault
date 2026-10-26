# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 14 — TRIES, STRINGS, AND COURSE SYNTHESIS

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 14 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 8 hours
**Prerequisites:** Lecture 01 — Models, ADTs, and Asymptotic Analysis; Lecture 02 — Arrays, Dynamic Arrays, and Amortized Analysis; Lecture 03 — Linked Lists; Lecture 04 — Stacks, Queues, and Deques; Lecture 05 — Recursion, Induction, and Divide-and-Conquer; Lecture 06 — Sorting and Order Statistics; Lecture 07 — Trees, Binary Trees, and Traversals; Lecture 08 — Binary Search Trees; Lecture 09 — Balanced Search Trees; Lecture 10 — Heaps and Priority Queues; Lecture 11 — Hash Tables; Lecture 12 — Graphs: Representation, BFS, and DFS; Lecture 13 — Shortest Paths, Spanning Trees, and Disjoint Sets
**Primary references:** Sedgewick and Wayne, *Algorithms*, 4th edition, Section 5.2; Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapters 6, 7, 10, 11, 12, 16, 19, 20, 21, and 22, with Chapters 14, 24, and 34 used only to name the boundary; Knuth, *The Art of Computer Programming*, Volume 3, 2nd edition, Section 6.3; Fredkin, *Communications of the ACM*, 1960; Manber and Myers, *SIAM Journal on Computing*, 1993

**This lecture owns:** Prefix trees, an honest naive suffix array, a decision procedure for choosing a structure, the boundary with the next course, and the cumulative examination.
**This lecture does not teach:** A second presentation of Lectures 01 through 13, Ukkonen's algorithm, any linear-time suffix-array construction, or the methods of dynamic programming, maximum flow, and NP-completeness.

---

## LEARNING OBJECTIVES

After this lecture you can:

1. Carry out insert, exact search, prefix search, and pruning deletion on a child-array trie for a word of length $L$, and state the $\Theta(L)$ worst-case bound.
2. Compare the space of a child array of alphabet size $\sigma$ with the space of a child map on the same set of words, and attach the correct worst-case or expected bound to each.
3. Draw the compressed trie of a dictionary by collapsing chains of one-child nodes that are not ends of words, and explain why a terminal node remains.
4. Build a suffix array by sorting suffix start indices with a character-by-character comparison, bound the character inspections by $O(n^2 \log n)$, and binary-search a pattern on that array.
5. Given a list of operations, select one structure from this course, name the worst-case, expected, or amortized cost, and name the assumption that cost uses.
6. Say, in two or three sentences each, what problem dynamic programming, maximum flow, and NP-completeness address, and why each one is outside a data-structures chapter.
7. Solve the cumulative examination from the definitions, traces, and quoted mechanics in this lecture.

---

## PURPOSE

A data structure is selected by the operations it must support and by the kind of bound those operations are allowed to have. The first thirteen lectures built the instruments. This lecture adds the one instrument they do not contain, the prefix tree, together with an honest first treatment of the suffix array, and then it uses every earlier instrument by name.

The string-set problem is the reason the trie exists. Exact membership is already solved by the chained hash table of Lecture 11, in expected constant time under simple uniform hashing, and by the AVL tree of Lecture 09, in worst-case logarithmic time. Neither representation shares the characters of a common prefix, and the hash of a prefix is unrelated to the hash of a longer key. Prefix search is a different operation, and it gets its own tree.

The suffix array is a sorted table of the suffixes of one text. The construction taught here sorts the start indices with mergesort. Each comparison may read $\Theta(n)$ characters of a text of length $n$, so the character cost is $O(n^2 \log n)$. Linear-time constructions exist. They are named, and they are not taught. A construction that claims linear time without a correct argument will not appear here.

The second half of the lecture is synthesis. It does not rebuild a heap, a hash table, or a graph search. It records the operation, the cost, and the assumption in the form fixed by the course, then asks you to choose. The cumulative examination is the final paper of the course. The answer key is at the end so that you can write the paper before you read it.

What this lecture deliberately leaves alone: the proofs of path compression, red–black insertion, the potential method in full, Lomuto's analysis beyond the partition steps the paper uses, and every algorithm whose home is the next course. When a cost is quoted, the quantifier is the one the earlier lecture earned. Worst-case, expected, and amortized are not synonyms.

---

## NOTATION

Arrays and strings are 0-indexed. $\log$ means $\log_2$. $\ln$ is the natural logarithm. A bound written $\Theta(f)$ is tight. A bound written $O(f)$ is only an upper bound. A bound written $\Omega(f)$ is only a lower bound.

Three size variables are easy to confuse, so they are split.

- In the trie, $L$ is the length of the word or prefix in the operation, $n$ is the number of stored words, $N$ is the number of nodes, and $\sigma$ is the alphabet size.
- In the suffix array, $n$ is the length of the text and $m$ is the length of the pattern.
- When an earlier structure is quoted, $n$ is the number of elements in that structure. A graph has $V$ vertices and $E$ edges.

The empty tree has height $-1$. A leaf has height $0$. The root of a nonempty tree has depth $0$. The AVL balance factor is $\mathrm{height}(\mathrm{left}) - \mathrm{height}(\mathrm{right})$, and a node is balanced when the factor lies in $\{-1, 0, 1\}$. A binary heap is stored in a 0-indexed array: the parent of $i$ is $\lfloor (i-1)/2 \rfloor$, and the children of $i$ are $2i+1$ and $2i+2$. Quicksort's worked partition is Lomuto's. Graphs are stored as adjacency lists. Dijkstra requires nonnegative weights and uses an indexed binary heap with a position map. Union-find uses union by rank and path compression. An absent link is `null`.

JavaScript numbers used as indexes, lengths, and the small frequencies in the examples are ordinary integers, far below the safe-integer limit $2^{53}-1$. The laboratory does not depend on an engine-specific representation of arrays. A child table of length $26$ is used as a fixed table of that length. The dynamic array of Lecture 02 is a different structure, and it is quoted where an append cost is needed.

---

## PART I — THE STRING-SET PROBLEM

### The abstract data type

A **string set** stores words over an alphabet $\Sigma$. The operations this lecture takes as the specification are:

- $\mathrm{insert}(w)$ adds the word $w$. Inserting a word that is already present leaves the set unchanged.
- $\mathrm{search}(w)$ returns true exactly when $w$ is in the set.
- $\mathrm{startsWith}(p)$ returns true exactly when at least one stored word has $p$ as a prefix.
- $\mathrm{delete}(w)$ removes $w$ if it is present.

A **prefix** of a word $w$ of length $L$ is any $w[0..k)$ for $0 \le k \le L$, including the empty prefix and $w$ itself. Exact search asks whether $w$ itself is stored. Prefix search asks whether any stored word begins with a given string. Those are different questions, and a structure that answers one of them has not automatically answered the other.

### What a hash table answers

A chained hash table places each word in a list selected by a hash function. Under the simple uniform hashing assumption of Lecture 11, with the load factor kept bounded by a constant, exact search examines an expected constant number of words. Comparing two words of length $L$ may still read $O(L)$ characters, so the character cost of one exact search is expected $O(L)$ once the slot has been chosen. That is a strong answer to exact membership.

It is not an answer to prefix search. The slot of a prefix $p$ is computed from $p$ alone. The slot of a longer word that begins with $p$ is computed from the whole word. Nothing in the hashing assumption forces those two slots to be related. The procedure that does answer the prefix question, given only a hash table, walks every stored word and tests the prefix. That scan is $\Theta(n)$ word examinations in the worst case, and $\Theta(n L)$ character inspections when every word is long and the mismatch is at the end.

### What a binary search tree answers

A binary search tree orders whole keys by the search property of Lecture 08. Successor, predecessor, and the sorted order of the keys are the operations that property buys. Words that share a prefix do form a contiguous range of that sorted order, so a range walk can list them after the first key of the range has been found. The cost of finding the start of the range follows the height. The height is $\Theta(n)$ in the worst case, and it is expected $\Theta(\log n)$ only when the tree was built by inserting distinct keys in random order.

The tree still stores each word's characters inside that word. A comparison of two keys may read all $L$ characters, and two keys that share a long prefix each carry their own copy of it. The search path does not spell the prefix once. The BST answers order. It does not share prefixes.

The trie is the structure whose path spells the prefix, so the shared characters are stored once and the walk for a key of length $L$ has length $L$.

---

## PART II — THE TRIE

### Definition

A **trie**, or prefix tree, is a rooted tree in which each edge is labeled by a character. The root represents the empty prefix. The prefix represented by any other node is the sequence of labels on the unique path from the root to that node. Fredkin named the structure in 1960; the word is pronounced like "try" because it was taken from retrieval.

This lecture uses the 26 lowercase English letters as the alphabet, so $\sigma = 26$. A character $c$ has child index $c - \mathtt{a}$, which is an integer in $\{0, 1, \ldots, 25\}$ and is computed in $\Theta(1)$ time. No other alphabet is used in the traces or the laboratory.

**Invariant.** After every public operation:

1. The nodes and edges form a tree rooted at the root.
2. The path from the root to a node spells that node's prefix, and the root's prefix is empty.
3. A string is in the set if and only if the node that spells it exists and is marked as an end of a word.
4. Every non-root node is an end of a word, or has at least one child, or both. The root may be unmarked and childless.
5. The child count stored in a node equals the number of its non-null children.

The end mark is part of the invariant because the shape of the path does not by itself say whether the prefix is a stored word. Part III uses that fact. The child count is part of the representation so that "this node has no children" is a $\Theta(1)$ test. Scanning all $\sigma$ slots to discover emptiness would make each level of a deletion $\Theta(\sigma)$.

### The child array

In the **child-array** trie, every node stores an array of $\sigma$ child links, initially `null`, a boolean end mark, and an integer child count.

```text
indexOf(c):
    i = code(c) - code('a')
    if i is outside 0 .. σ-1: return -1
    return i

insert(w):
    node = root
    for each character c of w:
        i = indexOf(c)
        if node.child[i] is null:
            node.child[i] = a new node
            node.childCount = node.childCount + 1
        node = node.child[i]
    node.isEnd = true

walk(s):
    node = root
    for each character c of s:
        i = indexOf(c)
        if i is invalid or node.child[i] is null:
            return null
        node = node.child[i]
    return node

search(w):
    node = walk(w)
    return node is not null and node.isEnd

startsWith(p):
    return walk(p) is not null
```

`search` requires the end mark. `startsWith` requires only that the walk arrive. The empty prefix walks zero characters and arrives at the root, so `startsWith` of the empty string is true for every trie, including an empty one.

**Theorem.** In a child-array trie with a fixed alphabet, `insert` of a word of length $L$, a successful `search` of a word of length $L$, `startsWith` on a string of length $L$, and `delete` of a present word of length $L$ each run in $\Theta(1 + L)$ worst-case time. For every word in the traced dictionary, $L \ge 1$, so the same bound is $\Theta(L)$. An unsuccessful walk is $O(1 + L)$, and the worst case is still $\Theta(1 + L)$ because the missing child may be the last character.

**Proof.** `indexOf` is $\Theta(1)$ by arithmetic on the character code. `insert` executes the loop body exactly $L$ times. Each iteration either follows an existing link or writes one new link and increments a counter, both $\Theta(1)$, then moves to that child. The final end-mark write is $\Theta(1)$. The loop contributes $\Theta(L)$ and the work outside the loop contributes $\Theta(1)$, so the total is $\Theta(1+L)$. A successful search and a `startsWith` that reads all $L$ characters do the same walk without the writes. Deletion, specified in Part III, recurses once per character and does $\Theta(1)$ work at each level because the child count answers emptiness without a scan. An unsuccessful walk stops at the first missing child, so it performs at most $L$ iterations and can be forced to perform all $L$ of them. Whenever $L \ge 1$, $\Theta(1+L)$ is the same statement as $\Theta(L)$. $\square$

The number of stored words $n$ does not appear in the bound. A search reads the characters of its argument. It does not scan the other words. The price is paid in space, which the next subsection counts.

### The child map, and the space tradeoff

A **child map** stores, at each node, a dictionary from character to child node, with an entry only for a child that exists. Two dictionaries are worth distinguishing, because they buy different bounds. This course does not treat the engine's `Map` object as a proved hash table. The bounds below are bounds on the dictionary you choose.

- If the dictionary is a chained hash table on the character, a child step is expected $\Theta(1)$ under simple uniform hashing, and the walk is expected $\Theta(L)$. The worst-case walk is $\Theta(L \cdot \sigma)$ if every character collides, which for $\sigma = 26$ is still linear in $L$ with a larger constant, and is a worst case rather than the expected case.
- If the dictionary is a balanced search tree of the existing children, a child step is $\Theta(\log \sigma)$ worst-case, and the walk is $\Theta(L \log \sigma)$ worst-case. For $\sigma = 26$, $\log_2 26 < 5$, so each step is a handful of comparisons. The dependence on $\sigma$ becomes the point when the alphabet is large.

Space is where the representations separate for the English alphabet.

**Theorem.** A child-array trie with $N$ nodes and alphabet size $\sigma$ stores $\Theta(\sigma N)$ child slots. A child-map trie stores $\Theta(N)$ nodes and $\Theta(N)$ map entries.

**Proof.** Every child-array node allocates an array of length $\sigma$, including the slots that remain `null`. That is $\sigma N$ slots, and the end mark and the child count are $\Theta(1)$ further fields per node, so the space is $\Theta(\sigma N)$. In a tree, the number of edges is $N-1$ once the root is counted among the $N$ nodes. A child map stores one entry per edge and one node record per node, which is $\Theta(N)$. $\square$

For the dictionary traced below, $N = 9$ and $\sigma = 26$, so the arrays contain $9 \cdot 26 = 234$ slots, and $8$ of those slots are non-null. The map representation stores those $8$ edges and does not store the $226$ nulls. The array representation buys a worst-case $\Theta(1)$ child step. The map representation buys space proportional to the nodes that exist. For a fixed alphabet of $26$ letters the array's wasted slots are a constant factor of $26$, which the $\Theta$ notation of a single node absorbs only after you have agreed to treat $\sigma$ as a constant. This lecture keeps $\sigma$ visible in the space bound and treats it as a constant in the $\Theta(L)$ time bound, because the index arithmetic does not loop over the alphabet. The laboratory implements the array.

### Trace: inserting car, cat, cart, and dog

An end of a word is drawn as `*`. Nodes are created only for prefixes that some inserted word actually uses.

Insert `car`. The root gains the path `c`, `a`, `r`, and `r` is marked.

```text
(root)
└── c
    └── a
        └── r*
```

Four nodes: the root, `c`, `a`, and `r`. Three edges.

Insert `cat`. The walk reuses `c` and `a`. The new child is `t`, and that `t` is marked. The node `a` now has two children.

```text
(root)
└── c
    └── a
        ├── r*
        └── t*
```

Five nodes.

Insert `cart`. The walk reuses `c`, `a`, and `r`. The node `r` is already an end, because `car` is a word. The new child of `r` is `t`, marked as the end of `cart`. One path now represents two words. The end mark on `r` is what keeps `car` present.

```text
(root)
└── c
    └── a
        ├── r*
        │   └── t*
        └── t*
```

Six nodes. The two nodes written `t*` are different nodes. One is the child of `a` and spells `cat`. The other is the child of `r` and spells `cart`.

Insert `dog`. This word shares nothing with the earlier prefixes, so the root gains a second child.

```text
(root)
├── c
│   └── a
│       ├── r*
│       │   └── t*
│       └── t*
└── d
    └── o
        └── g*
```

Nine nodes: the root, `c`, `a`, `r`, the `t` under `r`, the `t` under `a`, `d`, `o`, and `g`. Eight edges. The child arrays hold $9 \cdot 26 = 234$ slots.

The stored words, collected by a left-to-right walk of the children `a` through `z`, are `car`, `cart`, `cat`, `dog`.

Now the queries that the laboratory checks:

- `search("car")`, `search("cat")`, `search("cart")`, and `search("dog")` walk a marked node and return true.
- `search("ca")` arrives at `a`, and `a` is not marked, so the result is false. The prefix exists. The word does not.
- `search("carp")` follows `c`, `a`, `r`, and then finds a null child for `p`, so the result is false.
- `startsWith("ca")` and `startsWith("car")` arrive, so both return true.
- `startsWith("do")` returns true. `startsWith("z")` fails at the root and returns false.
- `startsWith("")` returns true without leaving the root.

A failed `delete("missing")` changes nothing: the walk dies on a null child and no mark is cleared.

---

## PART III — END MARKS, VALUES, AND DELETION

### Why a boolean is not the same thing as a child

The path for `cart` passes through the node that spells `car`. If presence were inferred from "this node exists", then inserting `cart` would insert `car`, and there would be no way to store one without the other. The end mark separates those facts. The node `r` can be marked, unmarked, or marked while also having children. All three states occur in the trace of this part.

A stored **value** is the same idea with a payload. The node that spells a word holds the payload, and a missing payload means the prefix is not a word. The boolean is the payload "present". The capstone at the end of the lecture stores a frequency in that position. Deletion clears the payload and then asks whether the node is still needed. The laboratory stores the boolean, because the traced dictionary is a set.

The empty word is the root. `insert("")` marks the root and creates no edge. Deleting the empty word clears that mark and does not remove the root, because the root is not a child of anything. The laboratory checks this beside `dog`: after the empty word is deleted, `dog` is still found, and the node count is $4$ (the root, `d`, `o`, and `g`).

### Deletion

Deletion of a present word clears its end mark and then removes nodes that the invariant no longer allows to stay. A node may be unlinked from its parent only when it is not an end and its child count is zero. The root is never unlinked.

```text
delete(w):
    recurse(node, i):
        if node is null:
            return false
        if i = length(w):
            if node.isEnd is false:
                return false
            node.isEnd = false
            return node.childCount = 0
        i-th child step:
            unlink = recurse(node.child[indexOf(w[i])], i + 1)
            if unlink is false:
                return false
            node.child[index] = null
            node.childCount = node.childCount - 1
            return node.isEnd is false and node.childCount = 0
    recurse(root, 0)
```

The value returned to a parent means "unlink me". The value returned about the root is discarded.

**Theorem.** If `delete(w)` is run on a trie that satisfies the invariant, the trie still satisfies the invariant, $w$ is absent, and every other word that was present remains present. A present word of length $L$ is deleted in $\Theta(1+L)$ worst-case time, which is $\Theta(L)$ when $L \ge 1$. An absent word changes nothing.

**Proof.** If some character of $w$ has no child, the recursive call receives `null` and returns false. No assignment runs, so the trie is unchanged and $w$ was already absent. If the walk arrives and the end mark is already false, the procedure returns false before any write, so a proper prefix that is not itself a word is not damaged.

If the mark is true, it is cleared. That removes $w$ from the set. The call then returns true only when the child count is zero. The parent, on receiving true, nulls that one child pointer and decrements its own count. The parent returns true only when it too is unmarked and has become childless. By induction on the way back up the path, a node is unlinked only when it is unmarked and childless, which is exactly when invariant 4 would be false if the node stayed. Nodes off the path are not visited. A marked node on the path returns false, so its parent keeps it, and the words that end at those marks stay. A node that still has a child returns false for the same reason, so extensions of the prefix stay.

The root is the starting argument, not a child slot, so a true result at the root does not erase the root object. The depth of the recursion is at most $L$, and each frame performs a constant amount of arithmetic and a constant number of field writes. A present word forces all $L$ frames to run, plus the constant work of the call, so the time is $\Theta(1+L)$. $\square$

### Trace: deleting from the dictionary

Start from the nine-node trie of Part II. Words: `car`, `cart`, `cat`, `dog`.

**Delete `car`, which is a prefix of `cart`.** The walk reaches `r`. The mark is cleared. The child count of `r` is $1$, because `t` is still there, so the procedure does not unlink `r`. No ancestor is unlinked. The node count stays $9$.

```text
(root)
├── c
│   └── a
│       ├── r
│       │   └── t*
│       └── t*
└── d
    └── o
        └── g*
```

`search("car")` is false. `search("cart")` is true. `startsWith("car")` is true, because the path still exists for `cart`. The remaining words are `cart`, `cat`, and `dog`.

**Delete `cart`.** The final `t` is marked and has no children. Its mark is cleared and it asks to be unlinked. The node `r` loses that child. Now `r` is unmarked and its child count is $0$, so `r` asks to be unlinked as well. The node `a` loses `r` and still has the child `t` of `cat`, and `a` is not an end, but its child count is $1$, so `a` stays. The node count is $7$: the root, `c`, `a`, the `t` of `cat`, `d`, `o`, and `g`.

```text
(root)
├── c
│   └── a
│       └── t*
└── d
    └── o
        └── g*
```

`startsWith("car")` is now false. `startsWith("ca")` is true. `search("cat")` is true.

**Delete `cat`.** The `t` under `a` is removed. Then `a` is unmarked and childless, so `a` is removed. Then `c` is unmarked and childless, so `c` is removed. The root still has `d`. The node count is $4$.

```text
(root)
└── d
    └── o
        └── g*
```

`startsWith("c")` is false. `search("dog")` and `startsWith("do")` are true.

**Delete `dog`.** The same climb removes `g`, then `o`, then `d`. The root remains, unmarked and childless. The node count is $1$. `search("dog")` is false. `startsWith("")` is true.

**The other order, as a check on the mark.** From the original nine-node trie, delete `cart` first and do not delete `car`. The final `t` is unlinked. The node `r` is still marked, so it returns false and stays. The node count is $8$. The words are `car`, `cat`, and `dog`. `search("car")` is true and `search("cart")` is false. The laboratory builds this second trie and checks those three facts. The picture is the original picture with the `t` under `r` removed and the star on `r` kept.

---

## PART IV — THE COMPRESSED TRIE

### What compression changes

A **unary chain** is a path of nodes that each have exactly one child. In the uncompressed trie, `c` has only the child `a`, and neither `c` nor the intermediate spelling is a stored word until a branch or a mark appears. A **compressed trie**, also called a **radix tree**, collapses each maximal chain of one-child nodes that are not ends of words into a single edge whose label is the string those edges spelled.

Compression is a change of representation of the same set. It is not a new search problem. Ukkonen's algorithm constructs a suffix tree, which is a compressed trie of all suffixes of one text, in linear time. That algorithm is outside this lecture. The picture below is drawn by hand from the dictionary.

The rule that decides whether a node survives:

- A node with two or more children survives, because the labels diverge there.
- A node that is an end of a word survives, even if it has only one child, because the mark has to live on a node.
- A node that has exactly one child and is not an end is removed, and its character is appended to an edge label.
- The root survives even when it has one child.

Apply that rule to `car`, `cat`, `cart`, and `dog`. The node `c` has one child and is not an end, so `c` and `a` become the edge label `ca`, and the branch point that was `a` remains. The node `r` is an end, so it remains even though it has one child; the following `t` remains because it is an end. The nodes `d` and `o` are not ends and each has one child, so they collapse into the edge label `dog`, and the node that was `g` remains as the end.

```text
(root)
├── "ca" ──► P
│            ├── "r" ──► R  [end: car]
│            │            └── "t" ──► T  [end: cart]
│            └── "t" ──► C  [end: cat]
└── "dog" ──► D  [end: dog]
```

Six nodes remain: the root, $P$, $R$, $T$, $C$, and $D$. The uncompressed trie had nine. The three removed nodes are `c`, `d`, and `o`.

If `car` were not a word, $R$ would be unmarked and would have exactly one child. The rule would delete $R$ and the edge from $P$ to $T$ would be labeled `rt`. The star on $R$ is the reason that edge stays split. Compression must not swallow an end mark.

### How many nodes survive

**Theorem.** A compressed trie that stores $n \ge 1$ distinct nonempty words, built by the rule above from a trie that satisfied the invariant, has at most $3n$ nodes.

**Proof.** Every leaf is an end of a word: a leaf that was not an end would be unmarked and childless, and the invariant does not retain it. Distinct words end at distinct nodes, so the number $L$ of leaves is at most $n$. Every non-root node with exactly one child is an end, because an unmarked one-child node would have been collapsed. Let $U$ be the number of such unary non-root nodes. Then $U \le n$. Let $B$ be the number of nodes with at least two children.

If the root has at least two children, it is counted in $B$, and the node total is $N = U + B + L$. The $N - 1$ edges are at least $U + 2B$, because each unary node contributes one edge and each branching node contributes at least two. Substitute $U = N - B - L$:

$$
N - 1 \ge (N - B - L) + 2B = N + B - L
$$

which rearranges to $B \le L - 1$. Therefore

$$
N = U + B + L \le n + (L - 1) + L = n + 2L - 1 \le 3n - 1.
$$

If the root has exactly one child and is not an end, the root is in none of $U$, $B$, and $L$, so $N = U + B + L + 1$. The edges then satisfy $N - 1 \ge 1 + U + 2B$. The same substitution yields $B \le L - 1$, and

$$
N \le n + (L - 1) + L + 1 = n + 2L \le 3n.
$$

In both cases $N \le 3n$. $\square$

The bound is deliberately coarse. The traced dictionary has $n = 4$ and $N = 6$, while $3n = 12$. What the theorem is for is the comparison with the uncompressed trie, whose node count equals one plus the number of distinct nonempty prefixes and can be as large as one plus the total number of characters. Compression removes the unary non-terminals. It does not, by itself, reduce the number of characters that edge labels must remember. If each edge stores a freshly copied string, the characters can still occupy $\Theta$ of the total input length. If each edge stores a pair of indexes into one shared character buffer, the labels become $\Theta(1)$ extra words per edge. This lecture draws the labels as strings and does not build the shared buffer.

A search in the compressed trie still follows the characters of the key. The difference is that one edge may match several characters, and a mismatch can occur in the middle of a label. The $\Theta(L)$ character bound remains. The implementation in the laboratory is the uncompressed child array, which is the structure the trace executed.

PATRICIA, published by Morrison in 1968, is the binary form of this idea: a radix tree on bits, with unary paths skipped. It is a relative of the picture above. It is not the laboratory program.

---

## PART V — THE NAIVE SUFFIX ARRAY

### Suffixes and the array

Let $S$ be a string of length $n$. The **suffix** that starts at index $i$ is the string $S[i..n)$. There are $n$ suffixes, one per start index. A **suffix array** is the array $\mathrm{SA}[0..n)$ of those start indexes, sorted so that the suffix $S[\mathrm{SA}[0]..n)$ comes first in dictionary order and the suffix $S[\mathrm{SA}[n-1]..n)$ comes last.

Dictionary order compares characters from the left. If one suffix is a proper prefix of the other, the shorter one comes first. That is the same rule as placing an end-of-string marker, smaller than every character, after each suffix. Two different start indexes never name the same string, because the suffixes have different lengths, so the sorted order is unique.

Manber and Myers introduced the suffix array as a search structure in 1993, and they gave a construction whose comparison cost is $O(n \log n)$ by a method this lecture does not present. The construction below is the direct one: sort the start indexes with the mergesort of Lecture 06, and let each comparison walk characters until it can decide. It is the right first construction because every step is visible. It is the wrong last construction for a long text, and the section says so with the character count in plain view.

The comparator and the sort:

```text
suffixCompare(S, i, j):
    while i < n and j < n:
        if S[i] < S[j]: return -1
        if S[i] > S[j]: return +1
        i = i + 1
        j = j + 1
    if i = n and j = n: return 0
    if i = n: return -1
    return +1

build, by top-down mergesort of the index array:
    the initial array is [0, 1, ..., n - 1]
    sort the half [lo, mid) and the half [mid, hi)
    merge them, taking the smaller suffix first
    mid = floor((lo + hi) / 2)
```

When the comparator returns $0$, the two starts are equal. The merge may break a tie by taking the left half. No traced string in this lecture produces a tie.

This sort is our mergesort. It is not `Array.prototype.sort`. An engine may use a different sorting algorithm, and a bound proved from an engine's choice would not be a bound on a structure we control.

### The comparison bound

**Theorem.** Let $n = 2^k$ with $k \ge 0$. The mergesort above performs at most $n \log_2 n - n + 1$ suffix comparisons. Each comparison inspects at most $n$ characters. The number of character inspections is therefore at most

$$
n \,(n \log_2 n - n + 1),
$$

which is $O(n^2 \log n)$. For a general length $n$, the same construction performs $O(n \log n)$ comparisons and $O(n^2 \log n)$ character inspections.

**Proof.** Consider a pass that merges sorted runs of length $m$, where $n$ is a multiple of $2m$. There are $n/(2m)$ such merges. A merge of two lists of length $m$ performs at most $2m - 1$ comparisons: each comparison outputs one element, and once one list is empty the rest of the other list is copied with no comparison, so at least one element is copied free and at most $2m - 1$ comparisons occur. The pass therefore costs at most

$$
\frac{n}{2m}(2m - 1) = n - \frac{n}{2m}
$$

comparisons. The passes use $m = 1, 2, 4, \ldots, n/2$, that is $m = 2^j$ for $j = 0, 1, \ldots, k-1$. The total is

$$
\sum_{j=0}^{k-1} \left(n - \frac{n}{2^{j+1}}\right) = kn - n \sum_{j=0}^{k-1} \frac{1}{2^{j+1}}.
$$

The inner sum is a geometric series:

$$
\sum_{j=0}^{k-1} \frac{1}{2^{j+1}} = \frac{1}{2} \cdot \frac{1 - (1/2)^k}{1 - 1/2} = 1 - \frac{1}{n}.
$$

Hence the total is $kn - n(1 - 1/n) = n \log_2 n - n + 1$.

Each comparison's loop advances through characters of $S$ and stops by the time either index reaches $n$, so it inspects at most $n$ characters. Multiply the two upper bounds. For general $n$, Lecture 06 already bounds mergesort by $O(n \log n)$ comparisons on an array of $n$ elements, and the same per-comparison cap of $n$ characters multiplies through. $\square$

The product is an $O$ bound because both factors are upper bounds, and because many comparisons stop at the first character. A string of $n$ identical characters forces every comparison to read to the end of the shorter suffix, so the cost is not "usually a few characters" on every input. This lecture does not claim a matching $\Omega(n^2 \log n)$ for every mergesort execution, and it therefore does not write $\Theta$ for the character cost. Writing $O(n \log n)$ for this construction would count comparisons and hide the characters. That is the wrong unit.

For the examination's numeric case, $n = 8 = 2^3$:

$$
8 \cdot 3 - 8 + 1 = 17
$$

comparisons, and at most $17 \cdot 8 = 136$ character inspections.

### What is outside the course

A linear-time suffix-array construction exists. Kärkkäinen, Sanders, and Burkhardt gave one, the DC3 (skew) algorithm, by sorting a constant fraction of the suffixes recursively and merging. That algorithm is real, and it is not taught here. No simplified "linear" procedure is offered in its place. Ukkonen's on-line construction of a suffix tree is likewise outside this course. The operation this lecture implements is the mergesort above, and the binary search in the next subsection.

### Trace: the suffix array of banana

Number the characters of `banana`:

```text
index:  0  1  2  3  4  5
char:   b  a  n  a  n  a
```

The six suffixes are `banana`, `anana`, `nana`, `ana`, `na`, and `a`. The mergesort below uses $\mathrm{mid} = \lfloor (\mathrm{lo} + \mathrm{hi}) / 2 \rfloor$ on a half-open range, which is the laboratory's control flow.

Sort $[0, 6)$. The midpoint is $3$.

Left half, sort $[0, 3)$. The midpoint is $1$. The piece $[0, 1)$ is the single index $0$. Sort $[1, 3)$ at midpoint $2$: the pieces are $[1]$ and $[2]$. Compare start $1$ (`anana`) with start $2$ (`nana`). The first characters are `a` and `n`, so $1$ comes first. The merged piece is $[1, 2]$. Now merge $[0]$ with $[1, 2]$. Start $0$ (`banana`) is larger than start $1$ (`anana`) because `b > a`. Start $0$ is smaller than start $2$ (`nana`) because `b < n`. The left half becomes $[1, 0, 2]$.

Right half, sort $[3, 6)$. The midpoint is $4$. The piece $[3, 4)$ is $[3]$. Sort $[4, 6)$: compare start $4$ (`na`) with start $5$ (`a`). The first characters are `n` and `a`, so $5$ comes first, and the piece is $[5, 4]$. Merge $[3]$ with $[5, 4]$. Start $5$ (`a`) is a proper prefix of start $3$ (`ana`), so `a` comes first. Start $3$ (`ana`) begins with `a` and start $4$ (`na`) begins with `n`, so $3$ comes next. The right half becomes $[5, 3, 4]$.

Merge $[1, 0, 2]$ with $[5, 3, 4]$:

- Start $5$ (`a`) is smaller than start $1$ (`anana`). Take $5$.
- Start $3$ (`ana`) is a proper prefix of start $1$ (`anana`). Take $3$.
- Start $1$ (`anana`) begins with `a`, start $4$ (`na`) begins with `n`. Take $1$.
- Start $0$ (`banana`) begins with `b`, start $4$ (`na`) begins with `n`. Take $0$.
- Start $4$ (`na`) is a proper prefix of start $2$ (`nana`). Take $4$.
- One index remains. Take $2$.

The suffix array is

$$
\mathrm{SA} = [5, 3, 1, 0, 4, 2].
$$

Read as suffixes:

| position in SA | start | suffix |
| --- | --- | --- |
| 0 | 5 | a |
| 1 | 3 | ana |
| 2 | 1 | anana |
| 3 | 0 | banana |
| 4 | 4 | na |
| 5 | 2 | nana |

Two shorter checks, used by the laboratory and short enough to sort by eye:

- `cba` has suffixes `cba`, `ba`, `a`. Dictionary order is `a`, `ba`, `cba`, so the array is $[2, 1, 0]$.
- `papa` has suffixes `papa`, `apa`, `pa`, `a`. Order them as `a`, `apa`, `pa`, `papa`: `a` is a prefix of `apa`, `apa` begins with `a` while `pa` begins with `p`, and `pa` is a prefix of `papa`. The array is $[3, 1, 2, 0]$.

### Binary search for a pattern

A **pattern** $P$ of length $m$ occurs in $S$ exactly where some suffix of $S$ has $P$ as a prefix. Because the suffix array is sorted in dictionary order, those suffixes form one contiguous segment. The search compares $P$ only with the first $m$ characters of a suffix. If the suffix ends before $m$ characters, the suffix is smaller than $P$.

```text
prefixCompare(S, start, P):
    k = 0
    while k < m and start + k < n:
        if S[start + k] < P[k]: return -1
        if S[start + k] > P[k]: return +1
        k = k + 1
    if k = m: return 0
    return -1

lowerBound(P):
    lo = 0, hi = n
    while lo < hi:
        mid = floor((lo + hi) / 2)
        if prefixCompare(S, SA[mid], P) < 0:
            lo = mid + 1
        else:
            hi = mid
    return lo

upperBound(P):
    lo = 0, hi = n
    while lo < hi:
        mid = floor((lo + hi) / 2)
        if prefixCompare(S, SA[mid], P) <= 0:
            lo = mid + 1
        else:
            hi = mid
    return lo
```

`lowerBound` is the first position whose suffix is greater than or equal to $P$ in this prefix comparison. `upperBound` is the first position whose suffix is strictly greater. The matching start indexes are $\mathrm{SA}[\mathrm{lower}, \mathrm{upper})$, in suffix-array order.

**Theorem.** The loop of `lowerBound` terminates with the smallest index whose prefix comparison is nonnegative, or with $n$ if every suffix is strictly smaller than $P$. Each of the $O(\log n)$ iterations inspects at most $m$ characters, so finding the two bounds costs $O(m \log n)$ character inspections. Reporting $R$ matches then copies $R$ indexes.

**Proof.** `prefixCompare` returns a negative value exactly when the suffix is strictly smaller than $P$ in dictionary order. It returns zero exactly when $P$ is a prefix of the suffix, and a positive value exactly when the suffix is larger than every string that begins with $P$. In the suffix array those three groups occupy three contiguous segments, in that order, because the array is sorted in dictionary order and a longer suffix that begins with $P$ still lies after every suffix strictly smaller than $P$ and before every suffix that first differs by exceeding $P$.

Maintain the invariant that every index strictly less than $\mathrm{lo}$ has a negative comparison and every index greater than or equal to $\mathrm{hi}$ has a nonnegative comparison. Initially $\mathrm{lo} = 0$ and $\mathrm{hi} = n$, so the right-hand claim is vacuous. While $\mathrm{lo} < \mathrm{hi}$, the midpoint $\lfloor (\mathrm{lo}+\mathrm{hi})/2 \rfloor$ satisfies $\mathrm{lo} \le \mathrm{mid} < \mathrm{hi}$. If the comparison at $\mathrm{mid}$ is negative, every index at most $\mathrm{mid}$ is negative as well, because those suffixes are smaller still, and the assignment $\mathrm{lo} = \mathrm{mid}+1$ preserves the invariant. If the comparison at $\mathrm{mid}$ is nonnegative, every index at least $\mathrm{mid}$ is nonnegative, because those suffixes are at least as large as a suffix that is already at least $P$, and the assignment $\mathrm{hi} = \mathrm{mid}$ preserves the invariant. The positive integer $\mathrm{hi}-\mathrm{lo}$ decreases at every iteration, so the loop ends with $\mathrm{lo} = \mathrm{hi}$. That index is the first nonnegative position, or $n$ when every suffix is strictly smaller than $P$. The upper-bound loop is the same argument with the test "nonpositive" in place of "negative" and the test "positive" in place of "nonnegative". Each of the $O(\log n)$ iterations inspects at most $m$ characters. $\square$

The empty pattern has $m = 0$. The comparison returns $0$ immediately, every suffix matches, and the reported starts are the entire suffix array.

### Trace: searching banana

Search for `ana`.

Lower bound:

| lo | hi | mid | SA[mid] | suffix | comparison | move |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 6 | 3 | 0 | banana | $+1$, because `b > a` | hi $= 3$ |
| 0 | 3 | 1 | 3 | ana | $0$ | hi $= 1$ |
| 0 | 1 | 0 | 5 | a | $-1$, the suffix ends | lo $= 1$ |

$\mathrm{lo} = \mathrm{hi} = 1$. The lower bound is $1$.

Upper bound:

| lo | hi | mid | SA[mid] | suffix | comparison | move |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 6 | 3 | 0 | banana | $+1$ | hi $= 3$ |
| 0 | 3 | 1 | 3 | ana | $0$ | lo $= 2$ |
| 2 | 3 | 2 | 1 | anana | $0$, the first three characters match | lo $= 3$ |

The upper bound is $3$. The segment is positions $1$ and $2$, and the start indexes are $3$ and $1$. Both `ana` and `anana` begin with `ana`.

Search for `nan`. The lower-bound moves are: midpoint $3$ (`banana`) is smaller because `b < n`, so $\mathrm{lo} = 4$; midpoint $5$ (`nana`) matches on the first three characters, so $\mathrm{hi} = 5$; midpoint $4$ (`na`) ends after two characters, so $\mathrm{lo} = 5$. The upper bound then steps from $\mathrm{lo} = 4$ through the match at position $5$ and finishes at $6$. The only start index is $\mathrm{SA}[5] = 2$, the suffix `nana`.

The same procedure reports:

- `a` at starts $[5, 3, 1]$
- `ban` at start $[0]$
- `nana` at start $[2]$
- `n` at starts $[4, 2]$
- `xyz` and `bananana` at no start
- the empty pattern at $[5, 3, 1, 0, 4, 2]$

For `papa`, the pattern `pa` matches starts $2$ and $0$, and the pattern `a` matches starts $3$ and $1$.

---

## PART VI — THE DECISION PROCEDURE

Read the requirements in this order. Stop at the first question that matches the operations you were actually given. The cost written next to a structure is the cost of those operations, with the quantifier the course proved.

1. If the edits are only at one end, and the read is only at that end, the structure is a stack. If items leave in the order they arrived, the structure is a queue.
2. If the data are a sequence addressed by integer position, look at where elements are inserted. Inserts and deletes at the ends, together with indexing, select the dynamic array. Inserts and deletes beside a node you already hold, with indexing rare, select the doubly linked list.
3. If the data are a map from key to value, split on what a key is asked to do. Ordered operations with a guaranteed logarithm select the AVL tree. Equality operations, and an acceptance of the hashing assumption, select the chained hash table. Prefix operations on strings select the trie.
4. If the repeated operation is "remove the smallest" and the rest of the order is never queried, the structure is a binary heap.
5. If the data are a graph, split on the question. Fewest edges selects breadth-first search. Nonnegative weighted distance from one source selects Dijkstra. Weights that may be negative select Bellman–Ford. A minimum connecting set of edges selects a minimum spanning tree. Repeated "merge these two" and "are these two together" selects union-find.

### Ten scenarios

**Stack.** An editor records each change and undoes it by reversing the most recent change. The operations are push and pop at one end. A linked stack, with the head as the top, performs push, pop, and top in $\Theta(1)$ worst-case time. A stack laid on the dynamic array performs push in $\Theta(1)$ amortized time and pop in $\Theta(1)$ worst-case time.

**Indexable sequence, ends or middle.** A server log appends one line and later reads line $i$ by index. It does not insert between line $40$ and line $41$. The dynamic array answers the index in $\Theta(1)$ worst-case time and the append in $\Theta(1)$ amortized time under doubling. A doubly linked list would make the index read $\Theta(n)$ worst-case. The opposite workload is a text cursor that inserts a character beside a node the editor already holds and almost never asks for the millionth character by index. There the doubly linked splice is $\Theta(1)$ worst-case, and the array's middle insert is $\Theta(n)$ worst-case because the tail elements move. The log selects the array. The cursor selects the doubly linked list.

**Ordered map, guaranteed logarithm.** A directory maps an employee identifier to a record and must return the smallest identifier strictly greater than $x$. Identifiers can arrive already sorted. An unbalanced binary search tree then becomes a spine of height $n-1$, and search is $\Theta(n)$ worst-case. The AVL tree keeps the balance factor of every node in $\{-1, 0, 1\}$, and search, insert, delete, and successor are $\Theta(\log n)$ worst-case. The height bound used here is the one proved in Part IX: the height is at most $2 \log_2 n$.

**Unordered map, expected constant time.** A program counts how often each token occurs and never asks for the next token in sorted order. The chained hash table, with the load factor kept at most $1$ by doubling, performs an insertion or a lookup in expected $\Theta(1)$ time under simple uniform hashing. The worst case remains $\Theta(n)$, when one chain holds every key. Doubling amortizes the cost of rebuilding the table across a sequence of insertions. It does not convert that worst-case chain into a constant. Expectation and amortization are different averages: expectation averages over the hash values, and amortization averages over a sequence of operations on one table.

**Priority queue.** A scheduler always runs the pending job with the smallest page count, and jobs arrive over time. The binary min-heap, stored in a 0-indexed array, finds the minimum in $\Theta(1)$ worst-case time and inserts or extracts the minimum in $\Theta(\log n)$ worst-case time. Building a heap from $n$ jobs already in hand is $\Theta(n)$ worst-case. An AVL tree can also extract a minimum, and it maintains a total order the scheduler never queries. An unsorted array makes every extraction $\Theta(n)$.

**Prefix queries.** An address book returns every name that begins with a given string of length $L$. The child-array trie walks that string in $\Theta(L)$ worst-case time and then stands at the subtree of matches. The hash table of whole names does not group those names in one place. The binary search tree orders the whole names, so the matches form a range, and it still recopies and recompares the shared characters. The prefix walk is the operation that was missing from both.

**Unweighted distance.** A maze charges $1$ for every step. The distance from the entrance is the number of edges on a shortest path. Breadth-first search on an adjacency list computes it in $\Theta(V + E)$ worst-case time. Dijkstra with every weight equal to $1$ returns the same distances and spends a heap operation on the way, $\Theta((V + E) \log V)$ with an indexed binary heap. The unit weights are the reason the queue is enough.

**Nonnegative weighted distance.** Road times are positive numbers, and the question is the shortest time from home to every town. Dijkstra's algorithm, with nonnegative weights and an indexed binary heap plus a position map, runs in $\Theta((V + E) \log V)$ worst-case time. The position map makes decrease-key $\Theta(\log V)$ rather than a linear search of the heap. Breadth-first search is the wrong procedure once a path of several short roads can beat one long road. Bellman–Ford is correct on this input and costs $\Theta(VE)$ worst-case, which is the price of allowing negative weights, not a price this input requires.

**Negative weights.** Some edges are rebates and are stored as negative numbers. There is no promise that every weight is nonnegative. Bellman–Ford relaxes every edge $|V| - 1$ times and runs in $\Theta(VE)$ worst-case time. One further pass reports a negative cycle reachable from the source; if one exists, some distances are not defined as finite numbers. Dijkstra's reason for finalizing a vertex at extraction uses nonnegativity. A negative edge can improve a vertex that has already left the heap, so the indexed heap is not the algorithm on this input.

**Connectivity that merges.** Roads are proposed one at a time. For each road you ask whether its towns are already in the same component and, if they are not, you build it. Union-find with union by rank and path compression answers a sequence of $m$ operations on $n$ towns in $O(m \, \alpha(n))$ time, where $\alpha$ is the inverse Ackermann function. That bound is stated from Lecture 13 and CLRS Chapter 19; the potential argument is not re-proved here. The per-operation cost is amortized $O(\alpha(n))$. Rebuilding an adjacency-list search from scratch for every question would rescan the graph each time.

### A shortest-path tree and a spanning tree are different questions

The ten scenarios already separate "distance from a source" from "merge components". The numeric gap is small enough to compute by hand. Take vertices $A$, $B$, and $C$, and undirected edges $AB$ of weight $2$, $BC$ of weight $2$, and $AC$ of weight $3$.

Kruskal sorts by increasing weight, with the alphabet breaking the tie between the two edges of weight $2$, so the order is $AB$, $BC$, $AC$. Union-find accepts $AB$, accepts $BC$, and rejects $AC$ because $A$ and $C$ are already connected. The total weight is $2 + 2 = 4$.

Prim grows one component from $A$. The lightest edge leaving $\{A\}$ is $AB$. The lightest edge leaving $\{A, B\}$ is $BC$, of weight $2$, against $AC$ of weight $3$. The same two edges, the same total $4$. With an indexed binary heap the general cost is $\Theta((V + E) \log V)$.

Dijkstra from $A$ computes distances, not a minimum connector. The distance to $B$ is $2$. The distance to $C$ is $\min(3, 2 + 2) = 3$, so the direct edge wins. The shortest-path tree contains $AB$ and $AC$, and the sum of those tree edges is $5$. The edge $BC$ is absent from that tree even though every minimum spanning tree of this graph uses it. A question that asks for distances from $A$ wants the tree of weight $5$ in the distance sense, meaning distances $2$ and $3$. A question that asks for the cheapest set of edges that connects the three towns wants the tree of total weight $4$.

---

## PART VII — A COMPARISON OF THE COURSE

Worst-case cost is the maximum, over inputs of a given size, of the running time. Expected cost is the mean under a distribution that the claim has to name. Amortized cost is the average of one operation over a worst-case sequence of operations. It is not an average over random data. A cell below uses the word that the bound actually earned. Where one structure has two implementations, both bounds are in the cell.

| Structure | What it stores | Principal operations | Cost | Assumption |
| --- | --- | --- | --- | --- |
| Dynamic array | Elements in contiguous index order, plus a capacity | Index read and write; append; insert or delete at an index | Index: $\Theta(1)$ worst-case. Append: $\Theta(1)$ amortized. Insert or delete at an arbitrary index: $\Theta(n)$ worst-case | Contiguous memory. Capacity doubles, from an initial capacity of $1$, by the rule in Part IX |
| Singly linked list | Nodes with one forward link, a head, and a tail when append must be cheap | Insert or delete at the head; append; search; index | Head insert and head delete: $\Theta(1)$ worst-case. Append with a tail pointer: $\Theta(1)$ worst-case. Delete at the tail: $\Theta(n)$ worst-case. Search and index: $\Theta(n)$ worst-case | A pointer write is $\Theta(1)$. The predecessor of a node is not stored |
| Doubly linked list | Nodes with predecessor and successor links | Insert or delete at a node in hand; search; index | Splice at a known node: $\Theta(1)$ worst-case. Search and index: $\Theta(n)$ worst-case | Both neighbor pointers sit in the node, so the four writes of Part IX are enough |
| Stack | A sequence edited only at the top | Push, pop, top | Linked stack: $\Theta(1)$ worst-case for all three. Dynamic-array stack: push $\Theta(1)$ amortized; pop and top $\Theta(1)$ worst-case | The linked top is the head. The array form is the dynamic array |
| Queue | A sequence that inserts at the back and removes at the front | Enqueue, dequeue, front | Linked queue with head and tail, and a circular buffer that does not resize: $\Theta(1)$ worst-case. A circular buffer that doubles: enqueue $\Theta(1)$ amortized | FIFO. Two end pointers, or a circular pair of indexes |
| Binary search tree | Keys in a binary tree with the search property | Search, insert, delete, successor | $\Theta(n)$ worst-case, because the height can be $n-1$. Expected $\Theta(\log n)$ for a tree built by inserting $n$ distinct keys in random order | The expected bound assumes every insertion order is equally likely. The tree is not rebalanced |
| AVL tree | Keys in a search tree whose balance factors lie in $\{-1, 0, 1\}$ | Search, insert, delete, successor | $\Theta(\log n)$ worst-case | Balance factor $\mathrm{height}(\mathrm{left}) - \mathrm{height}(\mathrm{right})$. Height at most $2 \log_2 n$, proved in Part IX |
| Binary heap | A heap-ordered complete binary tree in a 0-indexed array | Find-min, insert, extract-min, decrease-key, build | Find-min: $\Theta(1)$ worst-case. Insert, extract-min, and decrease-key at a known index: $\Theta(\log n)$ worst-case. Build: $\Theta(n)$ worst-case. Finding an arbitrary key: $\Theta(n)$ worst-case | Parent $\lfloor (i-1)/2 \rfloor$, children $2i+1$ and $2i+2$. Decrease-key receives the index. Heap order is not the search property |
| Chained hash table | Keys in lists off an array of slots | Search, insert, delete | Expected $\Theta(1)$ when the load factor is bounded by a constant. Worst-case $\Theta(n)$. A doubling rebuild is amortized across insertions and is still expected under the hash assumption | Simple uniform hashing. The constant-time claim is an expectation, not an amortized worst case |
| Adjacency list | For each vertex, a list of neighbors and, when needed, a weight | Scan neighbors; BFS; DFS | Space $\Theta(V+E)$ worst-case. Scan of $v$: $\Theta(1+\deg(v))$ worst-case. BFS and DFS: $\Theta(V+E)$ worst-case | The course default. A matrix would make a traversal $\Theta(V^2)$ |
| Trie | A tree of characters, root at the empty prefix, end marks on words | Insert, exact search, prefix search, pruning deletion | Child array, fixed alphabet: $\Theta(L)$ worst-case. Space $\Theta(\sigma N)$ worst-case. Child hash map: expected $\Theta(L)$, space $\Theta(N)$. Child balanced map: $\Theta(L \log \sigma)$ worst-case | The laboratory alphabet is the $26$ lowercase letters, and a character maps to an index in $\Theta(1)$. The bound is in the key length $L$ |

The rows are the structures the course can implement from empty files. Red–black trees, B-trees, and 2–3–4 trees were taught as balanced search trees with the same $\Theta(\log n)$ search bound as AVL, and they are the right citation when an insertion trace specifically needs their balance rules. They are not extra rows here, because a choice problem that asks only for a guaranteed logarithm is already answered by the AVL row.

---

## PART VIII — THE BOUNDARY WITH THE NEXT COURSE

Three subjects appear next to this course in every syllabus that was used to draw the map. They use arrays, trees, and graphs. They are still not data-structure chapters, because the object being designed is a recurrence, a flow, or a reduction, and the container underneath is one this course already finished.

**Dynamic programming** computes an optimum by solving overlapping subproblems in an order that respects their dependencies. Matrix-chain ordering, edit distance, and the 0–1 knapsack problem are typical specimens: each one has a recurrence whose naive expansion repeats the same subproblem exponentially often, and the method fills a table so that each subproblem is solved once. The table is an array. The array's cost was settled in Lecture 02. What remains is the design of the recurrence and the proof that the order of filling is legal. That design is the next course. CLRS develops it in Chapter 14. This lecture does not derive a recurrence.

**Maximum flow** asks for the largest feasible shipment from a source to a sink in a directed graph whose edges have capacities. The max-flow min-cut theorem equates that value with the cheapest set of edges whose removal separates the source from the sink, and the algorithms that compute it, Ford–Fulkerson and its polynomial specializations, maintain a residual graph and search for an augmenting path. The search may be a breadth-first search, which this course has. The theorem, the residual update, and the reason the search terminates at the optimum are not "which container holds the vertices". CLRS develops the subject in Chapter 24. This lecture does not compute a flow.

**NP-completeness** asks whether a decision problem has a polynomial-time algorithm at all. A problem is in NP when every yes-instance has a certificate that a polynomial-time procedure can check. The NP-complete problems are the hardest of that class, in the sense that a polynomial-time algorithm for one of them would yield a polynomial-time algorithm for every problem in NP. Satisfiability is the classical specimen. A data-structure bound of $\Theta(n \log n)$ or expected $\Theta(1)$ lives inside the polynomial world and does not decide whether a newly stated combinatorial question has any polynomial algorithm. CLRS develops the theory in Chapter 34, and Garey and Johnson is the monograph that fixed the style of the reductions. This lecture does not prove a reduction.

Greedy choice was not deferred. Huffman codes, Dijkstra, Prim, and Kruskal are the places this course already used it, inside the structure that makes the choice cheap.

---

## PART IX — QUOTED MECHANICS FOR THE CUMULATIVE PAPER

The examination applies the rules in this part. They are the operational forms fixed by the earlier lectures, written so the paper can be answered from this file. They are not a second textbook chapter on those structures. Each rule is followed by a short example whose numbers are different from the examination's numbers.

### Dynamic array, aggregate doubling

Capacity starts at $1$ and size starts at $0$. An append does the following. If size equals capacity, allocate an array of capacity $2 \cdot \mathrm{capacity}$, copy the size existing elements into it, and install that capacity. Then write the new element at index size, and add one to size.

The copies performed while appending $n \ge 2$ elements are the powers of two that do not exceed $n - 1$:

$$
1 + 2 + 4 + \cdots + 2^{m} = 2^{m+1} - 1,
$$

where $2^m$ is the largest power of two less than or equal to $n - 1$, so $m = \lfloor \log_2 (n-1) \rfloor$ and the total is $2^{\lfloor \log_2 (n-1) \rfloor + 1} - 1$. Each such power is copied once, on the append that grows the array past that size. The total is $O(n)$, so the amortized number of copies per append is $O(1)$. The accounting method and the potential method of Lecture 02 produce the same amortized bound; the sum above is the aggregate method, and it is the one the examination computes.

Four appends, as a check of the rule: the first copies $0$ and leaves capacity $1$; the second copies $1$ and leaves capacity $2$; the third copies $2$ and leaves capacity $4$; the fourth copies $0$. The total is $3$. The formula gives $n - 1 = 3$, $\lfloor \log_2 3 \rfloor = 1$, and $2^{2} - 1 = 3$.

### Doubly linked splice

A node holds `prev` and `next`. To insert a new node $X$ between a node $P$ and its current successor, when that successor is reached only as `P.next`:

```text
X.prev = P
X.next = P.next
P.next.prev = X
P.next = X
```

The third assignment still sees the old successor, so it has to run before the fourth. The four writes are $\Theta(1)$ worst-case. On the two-node list $P \leftrightarrow Q$, the picture becomes $P \leftrightarrow X \leftrightarrow Q$, and $Q.prev$ is $X$.

### Lomuto partition

The course partitions a subarray $A[\mathrm{lo}..\mathrm{hi}]$ by Lomuto's rule. The pivot is the last element. Hoare's two-ended partition is the other classical method and is not the worked rule.

```text
i = lo - 1
pivot = A[hi]
for j from lo to hi - 1:
    if A[j] <= pivot:
        i = i + 1
        swap A[i] and A[j]
swap A[i + 1] and A[hi]
return i + 1
```

Elements at or left of the returned index that are not the pivot are $\le$ the pivot. Elements strictly to its right are $>$ the pivot. Equals travel to the left because the test is $\le$.

Example, $A = [3, 1, 2]$, so $\mathrm{lo} = 0$, $\mathrm{hi} = 2$, and the pivot value is $2$. Start with $i = -1$. At $j = 0$, $3 > 2$, so the array is unchanged. At $j = 1$, $1 \le 2$, so $i = 0$ and swapping positions $0$ and $1$ yields $[1, 3, 2]$. The final swap exchanges position $1$ with position $2$ and yields $[1, 2, 3]$. The returned index is $1$.

### AVL balance and one rotation

The balance factor is $\mathrm{height}(\mathrm{left}) - \mathrm{height}(\mathrm{right})$. A missing child has height $-1$. A leaf has height $0$. The height of a node is one plus the larger child height. A node is unbalanced when the factor is $+2$ or $-2$.

After an insertion, at most one repair is required, and it sits at the deepest unbalanced node. Lecture 09 owns the case analysis. The four repairs are:

- Factor $+2$, and the left child has factor $+1$: the insertion fell in the left subtree of the left child. A single right rotation repairs it.
- Factor $+2$, and the left child has factor $-1$: rotate the left child left, then rotate the unbalanced node right.
- Factor $-2$, and the right child has factor $-1$: a single left rotation repairs it.
- Factor $-2$, and the right child has factor $+1$: rotate the right child right, then rotate the unbalanced node left.

A right rotation at $y$ with left child $x$ sets `y.left = x.right` and `x.right = y`. A left rotation at $y$ with right child $x$ sets `y.right = x.left` and `x.left = y`.

Example, the right–right case, inserting $5$, then $8$, then $9$. After $9$ and before the rotation the tree is $5$ with right child $8$ with right child $9$. The leaf $9$ has balance factor $0$ and height $0$. The node $8$ has balance factor $(-1) - 0 = -1$ and height $1$. The node $5$ has balance factor $(-1) - 1 = -2$ and height $2$. One left rotation at $5$ produces $8$ with left child $5$ and right child $9$. Every balance factor is $0$, and the root height is $1$.

The height used in the table is not an appeal to a picture.

**Theorem.** Every AVL tree on $n \ge 1$ nodes has height at most $2 \log_2 n$. Search, insertion, and deletion therefore run in $\Theta(\log n)$ worst-case time.

**Proof.** Let $n(h)$ be the minimum number of nodes in an AVL tree of height $h$. Then $n(-1) = 0$, $n(0) = 1$, and $n(h) = 1 + n(h-1) + n(h-2)$ for $h \ge 1$, because the sparsest tree of height $h$ has a root and two AVL subtrees of heights $h-1$ and $h-2$. In particular $n(1) = 2$.

Claim: $n(h) \ge 2^{h/2}$ for every $h \ge 0$. The case $h = 0$ is $1 \ge 1$. The case $h = 1$ is $2 \ge 2^{1/2}$. For $h \ge 2$ the recurrence contributes an extra node beyond the two subtrees, and the inductive hypothesis applies to both preceding heights:

$$
n(h) = 1 + n(h-1) + n(h-2) > n(h-1) + n(h-2) \ge 2^{(h-1)/2} + 2^{(h-2)/2}.
$$

The sum of those two powers is

$$
2^{(h-2)/2} \cdot \sqrt{2} + 2^{(h-2)/2} = 2^{(h-2)/2}(\sqrt{2} + 1).
$$

Because $\sqrt{2} + 1 > 2$,

$$
2^{(h-2)/2}(\sqrt{2} + 1) > 2^{(h-2)/2} \cdot 2 = 2^{h/2}.
$$

Therefore $n(h) > 2^{h/2}$, which is stronger than the claim. Any AVL tree of $n$ nodes and height $h$ then satisfies $n \ge n(h) > 2^{h/2}$, so $h < 2 \log_2 n$, and in particular $h \le 2 \log_2 n$. A search walks at most $h + 1$ nodes. Insertion and deletion walk the same way and then perform $O(h)$ balance-factor updates and $O(1)$ rotations on insertion, or $O(h)$ rotations on deletion. The upper bound is $O(\log n)$. A complete binary tree is an AVL tree, because the heights of the two subtrees of any node differ by at most one, and its height is $\lfloor \log_2 n \rfloor$. A search that ends at a deepest leaf of that tree examines $\Omega(\log n)$ nodes. The worst-case cost is $\Theta(\log n)$. $\square$

### Binary heap indexes

For $i > 0$ the parent index is $\lfloor (i-1)/2 \rfloor$. The children of $i$ are $2i+1$ and $2i+2$, when those indexes are strictly less than $n$. The depth of index $i$ is $\lfloor \log_2 (i+1) \rfloor$. For $n \ge 1$ the root has height $\lfloor \log_2 n \rfloor$, where a single node has height $0$. Extract-min swaps the root with the last element and sifts down one path, so it performs at most $\lfloor \log_2 n \rfloor$ swaps, which is $\Theta(\log n)$ worst-case.

A min-heap satisfies $H[\lfloor (i-1)/2 \rfloor] \le H[i]$ for every $i > 0$. Checking the parent of every non-root index is a complete check.

### Chained hashing, head insertion

The examination uses $m$ slots and $h(k) = k \bmod m$ for integer keys. Each slot is a singly linked list. A new key is inserted at the head of its list. A search walks from that head and counts one comparison per key it looks at, stopping when the key matches.

Example, different from the paper: $m = 3$, keys $4$, then $1$, then $7$. All three have residue $1$. After head insertion the chain in slot $1$ is $7 \to 1 \to 4$. Searching for $1$ compares $7$ and then $1$, two comparisons. The load factor is $\alpha = n/m = 1$. This one table is a collision chain of length $n$; it illustrates the $\Theta(n)$ worst case. The expected $\Theta(1)$ bound is a statement about the average chain under simple uniform hashing when $\alpha$ is bounded, not a statement that this particular chain is short.

### Breadth-first search

Use a queue. Mark a vertex when it is enqueued, not when it is dequeued. Set the source distance to $0$, mark the source, and enqueue it. When $u$ is dequeued, scan `u`'s adjacency list in stored order. For each unmarked neighbor $v$, set the distance of $v$ to the distance of $u$ plus $1$, mark $v$, and enqueue $v$. On an unweighted graph the distance is the minimum number of edges from the source. On an adjacency list the scan examines each vertex once and each end of each edge once, which is $\Theta(V + E)$ worst-case.

Example: the path with lists $0: [1]$, $1: [0, 2]$, $2: [1]$, source $0$. Discovery order is $0, 1, 2$. The distance of $2$ is $2$.

### Dijkstra, Prim, Kruskal

Dijkstra, from Lecture 13, requires nonnegative weights. The frontier is an indexed binary heap keyed by tentative distance, with a position map so that decrease-key starts from a known index. Each vertex is extracted at most once and each edge causes at most one decrease-key, for $\Theta((V + E) \log V)$ worst-case time. A negative weight voids the reason an extracted distance is final.

Prim grows a component from a start vertex by the same indexed heap, always adding the lightest edge with one end inside the component, in $\Theta((V + E) \log V)$ worst-case time. The result is a minimum spanning tree of a connected undirected graph, not a table of distances from the start.

Kruskal sorts the edges by increasing weight with mergesort, in $\Theta(E \log E)$ worst-case time, then considers them in that order. An edge is accepted when its endpoints lie in different union-find components and rejected when they do not. The disjoint-set work is $O(E \, \alpha(V))$ with union by rank and path compression. The sort dominates, and the total is $\Theta(E \log E)$ worst-case. The worked triangle of Part VI is the numeric form of these three procedures.

Bellman–Ford is the choice when a weight may be negative. Its worst-case cost is $\Theta(VE)$.

---

## LABORATORY

The hand traces are Part II, Part III, and Part V. Do the four problems on paper before you read the program. Then run the program. It encodes those traces as assertions.

1. Repeat the mergesort of `banana` from the initial index array $[0, 1, 2, 3, 4, 5]$ through both halves to $[5, 3, 1, 0, 4, 2]$. Then run the lower and upper bounds for `ana` and confirm that the reported starts are $3$ and $1$.
2. From the nine-node trie, delete `car`, then `cart`, then `cat`, then `dog`. Record the node count after each deletion. The counts are $9$, $7$, $4$, and $1$. On a fresh trie, delete only `cart`, and record the count $8$ together with the fact that `car` is still a word.
3. Build the suffix array of `papa` and list the starts whose suffixes begin with `pa`, and the starts whose suffixes begin with `a`.
4. Run the program. Change one assertion so that it must fail, confirm that the process throws, and restore the assertion. The successful run prints exactly one line.

---

## LABORATORY PROGRAM

```javascript
import assert from "node:assert/strict";

const ALPHABET = 26;
const A_CODE = "a".charCodeAt(0);

class TrieNode {
  constructor() {
    this.children = new Array(ALPHABET).fill(null);
    this.isEnd = false;
    this.childCount = 0;
  }
}

class Trie {
  constructor() {
    this.root = new TrieNode();
  }

  indexOf(ch) {
    const index = ch.charCodeAt(0) - A_CODE;
    if (index < 0 || index >= ALPHABET) {
      return -1;
    }
    return index;
  }

  insert(word) {
    let node = this.root;
    for (let i = 0; i < word.length; i += 1) {
      const index = this.indexOf(word[i]);
      if (index < 0) {
        throw new Error("alphabet");
      }
      if (node.children[index] === null) {
        node.children[index] = new TrieNode();
        node.childCount += 1;
      }
      node = node.children[index];
    }
    node.isEnd = true;
  }

  walk(word) {
    let node = this.root;
    for (let i = 0; i < word.length; i += 1) {
      const index = this.indexOf(word[i]);
      if (index < 0 || node.children[index] === null) {
        return null;
      }
      node = node.children[index];
    }
    return node;
  }

  search(word) {
    const node = this.walk(word);
    return node !== null && node.isEnd;
  }

  startsWith(prefix) {
    return this.walk(prefix) !== null;
  }

  delete(word) {
    const recurse = (node, i) => {
      if (node === null) {
        return false;
      }
      if (i === word.length) {
        if (!node.isEnd) {
          return false;
        }
        node.isEnd = false;
        return node.childCount === 0;
      }
      const index = this.indexOf(word[i]);
      if (index < 0) {
        return false;
      }
      const unlink = recurse(node.children[index], i + 1);
      if (!unlink) {
        return false;
      }
      node.children[index] = null;
      node.childCount -= 1;
      return !node.isEnd && node.childCount === 0;
    };
    recurse(this.root, 0);
  }

  nodeCount() {
    const visit = (node) => {
      let count = 1;
      for (let i = 0; i < ALPHABET; i += 1) {
        if (node.children[i] !== null) {
          count += visit(node.children[i]);
        }
      }
      return count;
    };
    return visit(this.root);
  }

  words() {
    const found = [];
    const visit = (node, prefix) => {
      if (node.isEnd) {
        found.push(prefix);
      }
      for (let i = 0; i < ALPHABET; i += 1) {
        if (node.children[i] !== null) {
          const ch = String.fromCharCode(A_CODE + i);
          visit(node.children[i], prefix + ch);
        }
      }
    };
    visit(this.root, "");
    return found;
  }
}

function suffixCompare(text, i, j) {
  const n = text.length;
  while (i < n && j < n) {
    if (text[i] < text[j]) {
      return -1;
    }
    if (text[i] > text[j]) {
      return 1;
    }
    i += 1;
    j += 1;
  }
  if (i === n && j === n) {
    return 0;
  }
  if (i === n) {
    return -1;
  }
  return 1;
}

function prefixCompare(text, start, pattern) {
  const n = text.length;
  const m = pattern.length;
  let k = 0;
  while (k < m && start + k < n) {
    if (text[start + k] < pattern[k]) {
      return -1;
    }
    if (text[start + k] > pattern[k]) {
      return 1;
    }
    k += 1;
  }
  if (k === m) {
    return 0;
  }
  return -1;
}

class SuffixArray {
  constructor(text) {
    this.text = text;
    const n = text.length;
    const order = [];
    for (let i = 0; i < n; i += 1) {
      order.push(i);
    }
    const aux = new Array(n);
    const merge = (lo, mid, hi) => {
      let left = lo;
      let right = mid;
      let cursor = lo;
      while (left < mid && right < hi) {
        if (suffixCompare(text, order[left], order[right]) <= 0) {
          aux[cursor] = order[left];
          left += 1;
        } else {
          aux[cursor] = order[right];
          right += 1;
        }
        cursor += 1;
      }
      while (left < mid) {
        aux[cursor] = order[left];
        left += 1;
        cursor += 1;
      }
      while (right < hi) {
        aux[cursor] = order[right];
        right += 1;
        cursor += 1;
      }
      for (let t = lo; t < hi; t += 1) {
        order[t] = aux[t];
      }
    };
    const sortRange = (lo, hi) => {
      if (hi - lo <= 1) {
        return;
      }
      const mid = Math.floor((lo + hi) / 2);
      sortRange(lo, mid);
      sortRange(mid, hi);
      merge(lo, mid, hi);
    };
    sortRange(0, n);
    this.order = order;
  }

  lowerBound(pattern) {
    let lo = 0;
    let hi = this.order.length;
    while (lo < hi) {
      const mid = Math.floor((lo + hi) / 2);
      if (prefixCompare(this.text, this.order[mid], pattern) < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  upperBound(pattern) {
    let lo = 0;
    let hi = this.order.length;
    while (lo < hi) {
      const mid = Math.floor((lo + hi) / 2);
      if (prefixCompare(this.text, this.order[mid], pattern) <= 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  find(pattern) {
    const lo = this.lowerBound(pattern);
    const hi = this.upperBound(pattern);
    const starts = [];
    for (let i = lo; i < hi; i += 1) {
      starts.push(this.order[i]);
    }
    return starts;
  }
}

const trie = new Trie();
assert.equal(trie.startsWith(""), true);
assert.equal(trie.search(""), false);
assert.equal(trie.nodeCount(), 1);

trie.insert("car");
trie.insert("cat");
trie.insert("cart");
trie.insert("dog");

assert.deepEqual(trie.words(), ["car", "cart", "cat", "dog"]);
assert.equal(trie.nodeCount(), 9);
assert.equal(trie.search("car"), true);
assert.equal(trie.search("cat"), true);
assert.equal(trie.search("cart"), true);
assert.equal(trie.search("dog"), true);
assert.equal(trie.search("ca"), false);
assert.equal(trie.search("carp"), false);
assert.equal(trie.search("carpets"), false);
assert.equal(trie.startsWith("ca"), true);
assert.equal(trie.startsWith("car"), true);
assert.equal(trie.startsWith("do"), true);
assert.equal(trie.startsWith("z"), false);
assert.equal(trie.startsWith(""), true);

trie.delete("missing");
assert.deepEqual(trie.words(), ["car", "cart", "cat", "dog"]);
assert.equal(trie.nodeCount(), 9);

const alternate = new Trie();
alternate.insert("car");
alternate.insert("cat");
alternate.insert("cart");
alternate.insert("dog");
alternate.delete("cart");
assert.deepEqual(alternate.words(), ["car", "cat", "dog"]);
assert.equal(alternate.nodeCount(), 8);
assert.equal(alternate.search("car"), true);
assert.equal(alternate.search("cart"), false);

trie.delete("car");
assert.deepEqual(trie.words(), ["cart", "cat", "dog"]);
assert.equal(trie.nodeCount(), 9);
assert.equal(trie.search("car"), false);
assert.equal(trie.search("cart"), true);
assert.equal(trie.startsWith("car"), true);

trie.delete("cart");
assert.deepEqual(trie.words(), ["cat", "dog"]);
assert.equal(trie.nodeCount(), 7);
assert.equal(trie.search("cart"), false);
assert.equal(trie.startsWith("car"), false);
assert.equal(trie.startsWith("ca"), true);
assert.equal(trie.search("cat"), true);

trie.delete("cat");
assert.deepEqual(trie.words(), ["dog"]);
assert.equal(trie.nodeCount(), 4);
assert.equal(trie.startsWith("c"), false);
assert.equal(trie.search("dog"), true);
assert.equal(trie.startsWith("do"), true);

trie.delete("dog");
assert.deepEqual(trie.words(), []);
assert.equal(trie.nodeCount(), 1);
assert.equal(trie.search("dog"), false);
assert.equal(trie.startsWith(""), true);

const emptyWord = new Trie();
emptyWord.insert("");
emptyWord.insert("dog");
assert.equal(emptyWord.search(""), true);
assert.equal(emptyWord.search("dog"), true);
emptyWord.delete("");
assert.equal(emptyWord.search(""), false);
assert.equal(emptyWord.search("dog"), true);
assert.equal(emptyWord.nodeCount(), 4);

const banana = new SuffixArray("banana");
assert.deepEqual(banana.order, [5, 3, 1, 0, 4, 2]);
assert.deepEqual(banana.find("ana"), [3, 1]);
assert.deepEqual(banana.find("nan"), [2]);
assert.deepEqual(banana.find("a"), [5, 3, 1]);
assert.deepEqual(banana.find("ban"), [0]);
assert.deepEqual(banana.find("nana"), [2]);
assert.deepEqual(banana.find("n"), [4, 2]);
assert.deepEqual(banana.find("xyz"), []);
assert.deepEqual(banana.find("bananana"), []);
assert.deepEqual(banana.find(""), [5, 3, 1, 0, 4, 2]);
for (let i = 1; i < banana.order.length; i += 1) {
  assert.ok(suffixCompare("banana", banana.order[i - 1], banana.order[i]) < 0);
}

const cba = new SuffixArray("cba");
assert.deepEqual(cba.order, [2, 1, 0]);
assert.deepEqual(cba.find("b"), [1]);
assert.deepEqual(cba.find("c"), [0]);
assert.deepEqual(cba.find("a"), [2]);

const papa = new SuffixArray("papa");
assert.deepEqual(papa.order, [3, 1, 2, 0]);
assert.deepEqual(papa.find("pa"), [2, 0]);
assert.deepEqual(papa.find("a"), [3, 1]);
assert.deepEqual(papa.find("z"), []);

console.log("ALL TESTS PASSED");
```

---

## COMMON MISTAKES

**Treating a hash lookup as a prefix query.** The wrong idea is that `startsWith(p)` can hash `p` and look in one slot. The correction is that the slot of `p` is unrelated to the slots of the words that begin with `p`. Exact search is the operation the hash table answers, in expected $\Theta(1)$ word examinations under simple uniform hashing. Prefix search is the trie walk, in $\Theta(L)$ worst-case character steps for a child array.

**Inferring membership from the existence of a node.** The wrong idea is that every node on the path of `cart` is itself a stored word, or that `car` cannot be stored once `cart` is stored. The correction is the end mark, or a stored value. The mark on a node is independent of whether that node has children. Deleting `car` while `cart` remains clears the mark and leaves the node in place.

**Pruning the wrong node.** The wrong idea is either to unlink a node as soon as its word is deleted, or to clear marks and never unlink anything. The correction is the return value in Part III: unlink a node only when it is unmarked and its child count is zero, and never unlink the root. After `cart` is deleted while `car` remains, the node `r` stays because it is still marked.

**Calling the naive suffix array $O(n \log n)$.** The wrong idea is that mergesort's comparison bound is the whole cost. The correction is that each comparison may inspect $n$ characters, so the character cost of this construction is $O(n^2 \log n)$. The symbol $O$ is deliberate. Linear-time construction is a different algorithm, and it is outside this course.

**Collapsing an edge through an end mark.** The wrong idea is that any one-child chain becomes one label, including the node of `car` on the way to `cart`. The correction is that a terminal node survives. In the picture, the edge into $R$ and the edge into $T$ stay separate because $R$ stores the end of `car`.

**Swapping the three quantifiers.** The wrong idea is that a chained hash table is amortized $\Theta(1)$, or that a dynamic-array append is worst-case $\Theta(1)$, or that an AVL search is expected $\Theta(\log n)$ as if it needed a random shape. The correction is the table in Part VII. The hash bound is an expectation under simple uniform hashing. The append bound is amortized over a sequence. The AVL bound is a worst case, because the height is at most $2 \log_2 n$ for every tree the operations can produce.

**Using the 1-indexed heap formulas on a 0-indexed array.** The wrong idea is that the parent of $i$ is $\lfloor i/2 \rfloor$ and the children are $2i$ and $2i+1$. Those are the 1-indexed formulas. The correction is parent $\lfloor (i-1)/2 \rfloor$, left child $2i+1$, right child $2i+2$.

**Reversing the balance factor.** The wrong idea is to subtract the left height from the right height. The correction is $\mathrm{height}(\mathrm{left}) - \mathrm{height}(\mathrm{right})$. A missing child contributes $-1$, so a node with only a left leaf has factor $0 - (-1) = +1$.

**Answering a connector question with a distance algorithm, or a negative weight with Dijkstra.** The wrong idea is that every weighted-graph problem wants Dijkstra. The correction is the split in Part VI. Nonnegative distances from one source: Dijkstra, $\Theta((V+E)\log V)$, indexed heap. A negative weight: Bellman–Ford, $\Theta(VE)$. A minimum connecting set: Prim or Kruskal. The triangle with weights $2$, $2$, and $3$ has minimum connector $4$ and a shortest-path tree from $A$ whose tree edges sum to $5$.

**Forgetting Lomuto's final swap, or marking a BFS vertex only on dequeue.** The pivot has to move from the end into index $i+1$, or the returned index does not hold the pivot. A vertex has to be marked when it is enqueued, or a later neighbor enqueues it a second time before the first copy is dequeued.

---

## EXAMINATION

Write this paper closed. The traces and the rules you need are in the lecture. Do not read the answer key until you have finished.

**Question 1. Analysis.** This lecture builds a suffix array by mergesort. When $n = 2^k$, a pass that merges runs of length $m$ performs at most $n - n/(2m)$ comparisons.

(a) Sum that quantity for $m = 1, 2, 4, \ldots, n/2$ and show that it equals $n \log_2 n - n + 1$.

(b) Compute the value for $n = 8$.

(c) Each comparison inspects at most $8$ characters when $n = 8$. Compute the resulting upper bound on character inspections.

(d) State the character cost of this construction on a string of length $n$ in big-O notation, and name one linear-time suffix-array construction that this course does not teach.

**Question 2. Amortized array.** A dynamic array starts with capacity $1$ and size $0$. An append that finds size equal to capacity allocates twice the capacity, copies the existing elements, and only then writes the new element. Append $10$ elements.

(a) For each append, give the number of elements copied.

(b) Give the total number of copied elements.

(c) Give the amortized number of copies per append, as a reduced fraction.

(d) Give the number of copies performed by the single most expensive append, and state why that number is a worst-case fact about one operation while (c) is the amortized cost.

**Question 3. Pointer splice.** Nodes $A$, $B$, and $C$ form a doubly linked list: `A.next = B`, `B.prev = A`, `B.next = C`, `C.prev = B`. Insert a new node $X$ between $A$ and $B$. You may refer to $B$ only as `A.next`. Write the four pointer assignments in an order that does not lose $B$, and state the worst-case cost.

**Question 4. Sort trace.** Lomuto-partition the 0-indexed array $[4, 7, 2, 8, 1, 5]$. The pivot is the last element. Show the array after every swap that changes it, show the final array, and give the index returned.

**Question 5. AVL rotation.** Insert $30$, then $20$, then $10$ into an empty AVL tree. The balance factor is $\mathrm{height}(\mathrm{left}) - \mathrm{height}(\mathrm{right})$. A missing child has height $-1$. A leaf has height $0$.

(a) Give the balance factor of $30$, of $20$, and of $10$ immediately before the rotation.

(b) Draw the tree after the rotation and give each balance factor.

(c) State the worst-case cost of one AVL insertion, and the inequality $n(h) \ge 2^{h/2}$ that feeds the height bound.

**Question 6. Heap index.** The 0-indexed array $[1, 4, 2, 8, 5, 7, 3]$ is offered as a min-heap.

(a) Give the parent index of $6$, and the two child indexes of $1$.

(b) Check the heap-order inequalities at indexes $0$, $1$, and $2$, and say whether the array is a min-heap.

(c) Give the height of the root. For $n \ge 1$ that height is $\lfloor \log_2 n \rfloor$.

(d) State the worst-case cost of extract-min.

**Question 7. Hash probe.** A chained hash table has $m = 5$ slots and hash function $h(k) = k \bmod 5$. Insertion is at the head of the chain. Insert $12$, then $7$, then $22$, then $3$.

(a) Write the five chains, head at the left.

(b) Give the number of key comparisons performed by a search for $7$.

(c) Give the load factor as a reduced fraction.

(d) Name the assumption under which search is expected $\Theta(1)$ when the load factor is bounded by a constant, and give the worst-case cost of one search.

**Question 8. Breadth-first search.** The undirected graph has these adjacency lists. Mark a vertex when it is enqueued. Start at $0$.

```text
0: [1, 2]
1: [0, 3]
2: [0, 3]
3: [1, 2, 4]
4: [3]
```

(a) Give the discovery order.

(b) Give the distance of vertex $3$ and the distance of vertex $4$.

(c) Give $V$, $E$, and the number of neighbor examinations. Each undirected edge contributes two examinations.

(d) State the asymptotic cost of BFS on an adjacency list.

**Question 9. Spanning tree or shortest paths.** An undirected connected graph has vertices $A$, $B$, and $C$. The edges are $AB$ of weight $4$, $AC$ of weight $5$, and $BC$ of weight $3$. Every weight is positive. The required result is a set of edges that connects all three vertices and has minimum total weight.

(a) Run Kruskal. Give the edge order, the edges that are accepted, and the total weight. Name the disjoint-set discipline.

(b) Run Prim starting at $A$. Give the edges in the order they are added, and the total weight.

(c) Run Dijkstra from $A$. Give the two tree edges and the sum of their weights. Give the distance of $B$ and the distance of $C$.

(d) Say which results answer the question, and why the shortest-path tree is a different object. State the general worst-case cost of Prim with an indexed binary heap, and the general worst-case cost of Kruskal.

**Question 10. Trie prefix.** A child-array trie receives `car`, then `cat`, then `cart`, then `dog`.

(a) List every stored word that has prefix `ca`. Give the results of `search("ca")` and `startsWith("ca")`.

(b) From that trie, delete only `cart`. Which node is removed? Which words remain? What is the node count, including the root?

(c) Start over from the original four-word trie and delete only `car`. Does the node that spelled `car` remain? Which words remain? What does `startsWith("car")` return, and what is the node count?

(d) State the worst-case cost of deleting one present word of length $L$ when child counts are stored.

**Question 11. Choose the structure.** You store at most $n = 2^{20} = 1{,}048{,}576$ employee identifiers. The operations are insert, delete, and "the smallest identifier strictly greater than $x$". Identifiers may arrive already sorted.

Name the structure. State the worst-case cost of one such operation. Evaluate $\log_2 n$. Explain why a chained hash table fails the successor requirement, and why an unbalanced binary search tree fails the worst-case requirement.

**Question 12. Choose the structure.** A simulator holds $n = 1{,}024$ pending events. Each step either inserts one event or extracts the event with the smallest timestamp. Timestamps are plain numbers. There is no graph.

Name the structure. Compute the height of the root. State the worst-case cost of extract-min, and the maximum number of swaps that sift-down performs on this $n$. Explain why Dijkstra on an adjacency list is the wrong tool.

**Question 13. Definitions.**

(a) Define, in one or two sentences each: trie, end-of-word mark, suffix, suffix array, compressed trie.

(b) In two or three sentences each, say what problem dynamic programming addresses, what problem maximum flow addresses, and what problem NP-completeness addresses. For each, say why it is not a data-structure chapter of this course.

---

## ANSWER KEY

**Question 1.**

(a) The passes use $m = 2^j$ for $j = 0, 1, \ldots, k - 1$, and $n = 2^k$, so $\log_2 n = k$. Pass $j$ costs at most

$$
n - \frac{n}{2 \cdot 2^j} = n - \frac{n}{2^{j+1}}
$$

comparisons. Sum:

$$
\sum_{j=0}^{k-1} \left(n - \frac{n}{2^{j+1}}\right) = kn - n \sum_{j=0}^{k-1} \frac{1}{2^{j+1}}.
$$

The geometric sum is

$$
\frac{1}{2} + \frac{1}{4} + \cdots + \frac{1}{2^k} = 1 - \frac{1}{2^k} = 1 - \frac{1}{n}.
$$

The total is $kn - n(1 - 1/n) = kn - n + 1 = n \log_2 n - n + 1$.

(b) For $n = 8$, $k = 3$:

$$
8 \cdot 3 - 8 + 1 = 24 - 8 + 1 = 17.
$$

(c) At most $17 \cdot 8 = 136$ character inspections.

(d) The construction costs $O(n^2 \log n)$ character inspections, because it performs $O(n \log n)$ comparisons and each comparison inspects $O(n)$ characters. One linear-time construction that this course does not teach is the DC3 algorithm of Kärkkäinen, Sanders, and Burkhardt.

**Question 2.**

(a) The ten appends copy $0, 1, 2, 0, 4, 0, 0, 0, 8, 0$ elements.

The capacities behind that list: append 1 finds size $0 < 1$ and copies nothing, leaving size $1$ and capacity $1$. Append 2 finds size $1 = 1$, copies $1$ element, and leaves capacity $2$. Append 3 copies $2$ elements and leaves capacity $4$. Append 4 copies nothing. Append 5 finds size $4 = 4$, copies $4$ elements, and leaves capacity $8$. Appends 6, 7, and 8 copy nothing. Append 9 finds size $8 = 8$, copies $8$ elements, and leaves capacity $16$. Append 10 copies nothing.

(b) $0 + 1 + 2 + 0 + 4 + 0 + 0 + 0 + 8 + 0 = 15$. The closed form agrees: $n - 1 = 9$, $\lfloor \log_2 9 \rfloor = 3$, and $2^{3+1} - 1 = 16 - 1 = 15$.

(c) The amortized number is $15/10 = 3/2$.

(d) Append 9 copies $8$ elements. That is the worst single append in this sequence. The amortized cost $3/2$ is the total $15$ divided by the $10$ appends. It describes the sequence. It does not claim that every append copies $1.5$ elements.

**Question 3.** The four assignments, in this order:

```text
X.prev = A
X.next = A.next
A.next.prev = X
A.next = X
```

The second assignment saves $B$ inside `X.next` while `A.next` still points at $B$. The third assignment writes `B.prev` while `A.next` still points at $B$. The fourth assignment then swings `A.next` to $X$. Afterward, `A.next` is $X$, `X.prev` is $A$, `X.next` is $B$, and `B.prev` is $X$. The cost is $\Theta(1)$ worst-case.

**Question 4.** Start from $[4, 7, 2, 8, 1, 5]$, with $i = -1$ and pivot value $5$.

- $j = 0$: $4 \le 5$, so $i = 0$. Swapping position $0$ with itself leaves $[4, 7, 2, 8, 1, 5]$.
- $j = 1$: $7 > 5$. No swap.
- $j = 2$: $2 \le 5$, so $i = 1$. Swap positions $1$ and $2$: $[4, 2, 7, 8, 1, 5]$.
- $j = 3$: $8 > 5$. No swap.
- $j = 4$: $1 \le 5$, so $i = 2$. Swap positions $2$ and $4$: $[4, 2, 1, 8, 7, 5]$.

The final swap exchanges position $i + 1 = 3$ with position $5$: $[4, 2, 1, 5, 7, 8]$. The returned index is $3$. The pivot value $5$ sits at that index. To its left, $4$, $2$, and $1$ are all $\le 5$. To its right, $7$ and $8$ are both $> 5$.

**Question 5.**

(a) The leaf $10$ has balance factor $(-1) - (-1) = 0$. The node $20$ has only a left child, so its factor is $0 - (-1) = 1$. The node $30$ has left height $1$ and a missing right child, so its factor is $1 - (-1) = 2$.

(b) A single right rotation at $30$ produces

```text
    20
   /  \
 10    30
```

The balance factors are $0$, $0$, and $0$. Both children of $20$ are leaves of height $0$, so the factor of $20$ is $0 - 0 = 0$ and the height of the root is $1$.

(c) One AVL insertion is $\Theta(\log n)$ worst-case. The inequality $n(h) \ge 2^{h/2}$ says that an AVL tree of height $h$ has at least $2^{h/2}$ nodes, so a tree of $n$ nodes has height at most $2 \log_2 n$.

**Question 6.**

(a) The parent of index $6$ is $\lfloor (6-1)/2 \rfloor = \lfloor 5/2 \rfloor = 2$. The children of index $1$ are $2 \cdot 1 + 1 = 3$ and $2 \cdot 1 + 2 = 4$.

(b) At index $0$, the value $1$ is $\le 4$ and $\le 2$. At index $1$, the value $4$ is $\le 8$ and $\le 5$. At index $2$, the value $2$ is $\le 7$ and $\le 3$. Every parent is at most its children, so the array is a min-heap.

(c) $n = 7$ and $2^2 = 4 \le 7 < 8 = 2^3$, so $\lfloor \log_2 7 \rfloor = 2$. The root height is $2$.

(d) Extract-min is $\Theta(\log n)$ worst-case.

**Question 7.**

(a) $12 \bmod 5 = 2$, $7 \bmod 5 = 2$, $22 \bmod 5 = 2$, and $3 \bmod 5 = 3$. Head insertion produces:

- slot $0$: empty
- slot $1$: empty
- slot $2$: $22 \to 7 \to 12$
- slot $3$: $3$
- slot $4$: empty

(b) The search compares $22$, then $7$, and stops. It performs $2$ key comparisons.

(c) Four keys and five slots give $\alpha = 4/5$.

(d) The assumption is simple uniform hashing. Under that assumption, with $\alpha$ bounded by a constant, a search is expected $\Theta(1)$. The worst-case cost is $\Theta(n)$, which is the cost of walking a chain that contains every key.

**Question 8.**

(a) Enqueue $0$ with distance $0$. From $0$, enqueue $1$ and then $2$, both at distance $1$. From $1$, the neighbor $0$ is marked and the neighbor $3$ is new, so enqueue $3$ at distance $2$. From $2$, both neighbors are marked. From $3$, enqueue $4$ at distance $3$. The discovery order is $0, 1, 2, 3, 4$.

(b) The distance of $3$ is $2$. The distance of $4$ is $3$.

(c) $V = 5$ and $E = 5$. The neighbor examinations are $2 + 2 + 2 + 3 + 1 = 10$, and $2E = 10$.

(d) BFS on an adjacency list is $\Theta(V + E)$ worst-case.

**Question 9.**

(a) Sorted order: $BC$ of weight $3$, then $AB$ of weight $4$, then $AC$ of weight $5$. Kruskal accepts $BC$, accepts $AB$, and rejects $AC$ because $A$, $B$, and $C$ are already one component. The total weight is $3 + 4 = 7$. The disjoint-set discipline is union by rank with path compression.

(b) Prim from $A$ first sees $AB$ of weight $4$ and $AC$ of weight $5$, so it adds $AB$. From $\{A, B\}$ the lightest leaving edge is $BC$ of weight $3$, against $AC$ of weight $5$, so it adds $BC$. The total weight is $4 + 3 = 7$.

(c) Dijkstra from $A$ sets the distance of $B$ to $4$ and the distance of $C$ to $5$. The path $A \to B \to C$ has length $4 + 3 = 7$, which is worse than $5$, so the distance of $C$ stays $5$. The tree edges are $AB$ and $AC$, and the sum of their weights is $4 + 5 = 9$.

(d) Kruskal and Prim answer the question. Both produce a connecting set of total weight $7$. Dijkstra answers a different question, distances from $A$, and its tree edges sum to $9$ because the cheap edge $BC$ does not lie on a shortest path from $A$. Prim with an indexed binary heap is $\Theta((V + E) \log V)$ worst-case. Kruskal is $\Theta(E \log E)$ worst-case.

**Question 10.**

(a) The stored words with prefix `ca` are `car`, `cart`, and `cat`. `search("ca")` is false, because the node `a` is not an end. `startsWith("ca")` is true, because the walk arrives.

(b) Deleting `cart` removes the node `t` under `r`. The node `r` stays, because it is still the end of `car`. The remaining words are `car`, `cat`, and `dog`. The node count is $8$.

(c) Deleting `car` clears the mark on `r` and does not remove `r`, because `cart` still uses the child `t`. The node remains. The remaining words are `cart`, `cat`, and `dog`. `startsWith("car")` returns true. The node count stays $9$.

(d) The cost is $\Theta(1+L)$ worst-case. For a present word with $L \ge 1$, that is the same bound as $\Theta(L)$.

**Question 11.** The structure is an AVL tree. Insert, delete, and successor are $\Theta(\log n)$ worst-case. Here $\log_2 n = \log_2 (2^{20}) = 20$, and the height is at most $2 \cdot 20 = 40$. A chained hash table supports equality in expected $\Theta(1)$ time under simple uniform hashing and has no successor operation short of scanning keys. An unbalanced binary search tree supports successor, and sorted arrivals make its height $n - 1$, so the worst-case cost is $\Theta(n)$ rather than $\Theta(\log n)$.

**Question 12.** The structure is a binary min-heap. The root height is $\lfloor \log_2 1024 \rfloor = \lfloor \log_2 (2^{10}) \rfloor = 10$. Extract-min is $\Theta(\log n)$ worst-case, and sift-down performs at most $10$ swaps on this heap. Dijkstra computes distances in a graph with nonnegative edge weights. This simulator has timestamps and no edges, so the indexed-heap shortest-path algorithm is not the operation being asked for. The heap by itself is the priority queue.

**Question 13.**

(a) A trie is a rooted tree whose edges are characters; the root is the empty prefix, and a word is the spelling of a path that ends at a marked node. An end-of-word mark on a node says that the prefix spelled by that node is itself a stored word, whether or not the node has children. A suffix of a string $S$ of length $n$ is a tail $S[i..n)$ for some start $i$. A suffix array is the array of all $n$ start indexes sorted in dictionary order of those tails. A compressed trie is the same set of words with every chain of one-child, non-terminal nodes collapsed into one edge label.

(b) Dynamic programming computes an optimum from overlapping subproblems by filling a table in a legal order. The table is an array this course already knows how to cost; the design work is the recurrence, which is the next course. Maximum flow computes the largest feasible shipment from a source to a sink under edge capacities. Graph search is used inside the algorithms, and the content that remains is the residual graph and the max-flow min-cut theorem, which are not a choice of container. NP-completeness asks whether a decision problem has any polynomial-time algorithm, by certificates and reductions. A $\Theta(n \log n)$ structure bound assumes the problem is already inside the polynomial world and does not answer that question.

---

## INDEPENDENT ASSIGNMENT

### Capstone: an in-memory autocomplete index

This assignment is separate from the laboratory program. The laboratory already implements the set trie and the naive suffix array. Do not replace it with this program. Write a new program, and write one to two pages of justification beside it. Budget several hours. No solution program is provided.

**Design you will implement.** A child-array trie over the $26$ lowercase English letters, the trie of Part II, with one change of payload: the end mark is a positive integer frequency stored at the terminal node. A missing frequency means the prefix is not a word. Do not store a top-list on the ancestors. A query walks to the prefix and then explores that subtree, retaining the best $k$ completions in a binary min-heap. The heap is the 0-indexed heap of Lecture 10, implemented by you, with parent $\lfloor (i-1)/2 \rfloor$ and children $2i+1$ and $2i+2$.

A completion is a pair (frequency, word). In the min-heap, pair $A$ is worse than pair $B$ when $A$'s frequency is smaller, or the frequencies are equal and $A$'s word is lexicographically larger. The root is the worst of the pairs currently retained. If the heap holds fewer than $k$ pairs, push the new pair. If it holds $k$ pairs and the new pair is better than the root, replace the root and sift down. Reconstruct each word from the path you walked. Do not call a library heap, a library sort of the whole dictionary, or a hash map of the words.

**Operations.**

- `insert(word, frequency)` stores the word. If the word is already present, replace its frequency. The frequency is an integer from $1$ through $2^{53} - 1$ inclusive. Replacement does not add to the old frequency.
- `topCompletions(prefix, k)` returns up to $k$ stored words that have that prefix. The output order is decreasing frequency, and equal frequencies come out in increasing dictionary order. If fewer than $k$ words match, return all of them in that order. If $k \le 0$, or the prefix is absent, return an empty list. The empty prefix means the whole set. A stored word equal to the prefix is itself a completion.

**Costs the write-up must state, for this design.**

- Inserting or replacing a word of length $L$ is $\Theta(L)$ worst-case. Ancestors are not rewritten.
- `topCompletions(prefix, k)` walks the prefix in $\Theta(L)$ worst-case time and then visits every node of that subtree. If the subtree has $S$ nodes and $W \le S$ terminal words, the query is $\Theta(L + S \log k)$ worst-case, because each terminal does $O(\log k)$ heap work and the heap never holds more than $k$ pairs.
- The trie occupies $\Theta(26 N)$ child slots for $N$ nodes. The query heap occupies $O(k)$ additional slots and is discarded when the query returns.

**Justification the write-up must answer.** Why a chained hash table of whole words does not answer the prefix query. Why sorting all $n$ words on every query performs $\Theta(n \log n)$ key comparisons and is the wrong cost. Why the heap has size $k$ rather than sorting all $W$ matches at $\Theta(W \log W)$. Why storing a top-$k$ list on every ancestor would make insertion $\Theta(L k)$ rather than $\Theta(L)$.

**Acceptance tests.** Insert `car` at frequency $5$, `cat` at $3$, `cart` at $8$, `dog` at $1$, `card` at $4$, and `cab` at $5$. Then:

- `topCompletions("ca", 3)` returns `["cart", "cab", "car"]`.
- `topCompletions("car", 2)` returns `["cart", "car"]`.
- `topCompletions("car", 3)` returns `["cart", "car", "card"]`.
- `topCompletions("do", 5)` returns `["dog"]`.
- `topCompletions("z", 1)` returns `[]`.
- `topCompletions("", 2)` returns `["cart", "cab"]`.
- `topCompletions("c", 1)` returns `["cart"]`.
- `topCompletions("ca", 0)` returns `[]`.

The tie between `cab` and `car`, both at frequency $5$, is broken by dictionary order, so `cab` ranks ahead of `car`. Replacing the frequency of `dog` with $9$ and then calling `topCompletions("", 1)` returns `["dog"]`. Keep the program and the write-up. Later courses will assume you can still build the trie and the heap from a blank file.

---

## GLOSSARY

**Alphabet size.** The number of distinct characters the trie indexes, written $\sigma$. In this lecture $\sigma = 26$, the lowercase English letters.

**Child array.** The representation in which every trie node holds an array of $\sigma$ child links, including the links that are `null`.

**Child count.** The integer on a node that equals its number of non-null children, so emptiness is a $\Theta(1)$ test during deletion.

**Child map.** The representation in which a node stores a dictionary entry only for a child that exists. A hash-map child step is expected $\Theta(1)$ under simple uniform hashing. A balanced-tree child step is $\Theta(\log \sigma)$ worst-case.

**Compressed trie.** A trie in which every maximal chain of one-child nodes that are not ends of words has been collapsed into one edge label. Also called a radix tree.

**Decision procedure.** The ordered list of operation questions in Part VI. The first matching question selects the structure.

**Dynamic programming.** The method of computing an optimum from overlapping subproblems by filling a table. Named here as the next course, and not developed.

**End-of-word mark.** The boolean, or more generally the stored value, that says the prefix spelled by a node is itself a key. It is independent of the node's children.

**Inverse Ackermann function.** The extremely slow-growing function $\alpha$ in the union-find bound $O(m \, \alpha(n))$ quoted from Lecture 13. Its analysis is not re-proved here.

**Load factor.** The ratio $\alpha = n/m$ of stored keys to slots in a hash table, quoted from Lecture 11.

**Maximum flow.** The largest feasible shipment from a source to a sink in a capacity-constrained directed graph. Named here as the next course, and not computed.

**NP-completeness.** The theory of decision problems whose yes-answers have polynomial-time certificates, and of the hardest problems in that class. Named here as the next course, and not used in a reduction.

**Pattern.** The string sought as a prefix of some suffix, of length $m$, in the suffix-array search.

**Position map.** The array that tells an indexed binary heap where a given vertex currently sits, so decrease-key starts in $\Theta(1)$ and then costs $\Theta(\log V)$. Quoted from Lecture 13.

**Prefix.** A head of a word, $w[0..k)$ for some $k$, including the empty head and the whole word.

**Prefix comparison.** The comparison of a pattern with the first $m$ characters of a suffix. If the suffix ends first, the suffix is smaller.

**Radix tree.** Another name for the compressed trie of Part IV.

**Simple uniform hashing.** The assumption that each key is equally likely to fall in any slot, independently of the other keys. The expected $\Theta(1)$ chain cost uses it.

**Suffix.** The tail $S[i..n)$ of a string $S$ of length $n$.

**Suffix array.** The array of all suffix start indexes of $S$, sorted in dictionary order of the suffixes.

**Trie.** A rooted tree of character-labeled edges. The root is the empty prefix. A stored word is a path whose final node carries an end mark. Also called a prefix tree.

**Unary chain.** A path of nodes that each have exactly one child. Compression removes the nodes on that path that are not ends of words.

---

## LECTURE SUMMARY

The string set asks for insertion, exact search, and prefix search. A chained hash table answers exact search in expected constant time under simple uniform hashing, and it does not group the keys that share a prefix. A binary search tree answers the order of whole keys, in $\Theta(n)$ worst-case time or expected $\Theta(\log n)$ time for a random build, and it stores each copy of a shared prefix inside its own key. The trie stores the prefix once. With a child array of $26$ letters and a child count, insertion, exact search, prefix search, and pruning deletion are $\Theta(L)$ worst-case, and the space is $\Theta(26 N)$. A child map spends less space and gives up the worst-case constant child step. An end mark, or a stored value, is what makes `car` and `cart` simultaneously representable, and deletion unlinks a node only when that mark is gone and the node has no children. Compressing unary non-terminal chains preserves the set and leaves at most $3n$ nodes for $n$ nonempty words; it does not license an implementation of Ukkonen's algorithm. The suffix array of a text is the sorted list of suffix starts. Mergesort of those starts, comparing characters directly, costs $O(n^2 \log n)$ character inspections. Binary search then finds every occurrence of a pattern in $O(m \log n)$ character inspections plus the time to report the matches. Linear-time construction is a named result of Kärkkäinen, Sanders, and Burkhardt, and it is outside this course.

The rest of the lecture is a discipline of choice. Stack and queue answer end-only edits. The dynamic array answers indexing and amortized append. The doubly linked list answers a splice at a node in hand. The AVL tree answers ordered-map operations in $\Theta(\log n)$ worst-case time. The chained hash table answers equality in expected $\Theta(1)$ time under an assumption that must be stated. The binary heap answers repeated extract-min. The trie answers prefixes. Breadth-first search, Dijkstra with an indexed heap, Bellman–Ford, Prim, Kruskal, and union-find answer different graph questions, and the triangle of weights $2$, $2$, and $3$ is the small witness that a shortest-path tree and a minimum spanning tree are not the same set of edges. Dynamic programming, maximum flow, and NP-completeness are the next course because each one designs a recurrence, a flow, or a reduction on top of containers this course has already finished.

---

## FIVE PRINCIPLES

1. Select the structure from the operations and from the quantifier on the bound. Worst-case, expected, and amortized answer different questions, and the assumption is part of the claim.
2. A trie shares characters along a path of length $L$. A hash table and a binary search tree do not. The end mark is part of the key's identity, because a word may be a prefix of another word.
3. A comparison bound is not a character bound. The naive suffix array pays up to $n$ character inspections inside each of its $O(n \log n)$ comparisons, and the honest product is $O(n^2 \log n)$.
4. Graph problems that look alike split on the weights and on the question. Unweighted distance, nonnegative distance, negative weights, a minimum connector, and merging connectivity are five different answers, with five different costs.
5. A finished structure is allowed to sit underneath a later subject without turning that subject into a data-structure chapter. The array inside a dynamic-programming table does not make dynamic programming a lecture this course still owes.

---

## REFERENCES

1. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapters 6, 7, 10, 11, 12, 16, 19, 20, 21, and 22 are the sources of the quoted heap, partition, list, hash, search-tree, amortization, disjoint-set, traversal, spanning-tree, and shortest-path bounds. Chapters 14, 24, and 34 are cited only as the boundary: dynamic programming, maximum flow, and NP-completeness.

2. Robert Sedgewick and Kevin Wayne. *Algorithms*. 4th edition. Addison-Wesley, 2011. Section 5.2, Tries. The course site is [https://algs4.cs.princeton.edu/home/](https://algs4.cs.princeton.edu/home/).

3. Donald E. Knuth. *The Art of Computer Programming, Volume 3: Sorting and Searching*. 2nd edition. Addison-Wesley, 1998. Section 6.3, Digital Searching.

4. Edward Fredkin. "Trie Memory." *Communications of the ACM*, volume 3, number 9, 1960.

5. Donald R. Morrison. "PATRICIA—Practical Algorithm to Retrieve Information Coded in Alphanumeric." *Journal of the ACM*, volume 15, number 4, 1968.

6. Udi Manber and Gene Myers. "Suffix Arrays: A New Method for On-Line String Searches." *SIAM Journal on Computing*, volume 22, number 5, 1993. Cited for the data structure. Their construction is not the mergesort taught here.

7. Juha Kärkkäinen, Peter Sanders, and Stefan Burkhardt. "Linear Work Suffix Array Construction." *Journal of the ACM*, volume 53, number 6, 2006. Named as a linear-time construction that exists, and not taught.

8. Esko Ukkonen. "On-line Construction of Suffix Trees." *Algorithmica*, volume 14, 1995. Named in order to say that the algorithm is outside this course.

9. Michael R. Garey and David S. Johnson. *Computers and Intractability: A Guide to the Theory of NP-Completeness*. W. H. Freeman, 1979. Cited only as the boundary monograph.

10. Mark Allen Weiss. *Data Structures and Algorithm Analysis in C++*. 4th edition. Pearson, 2014. Used for the style of the AVL height argument quoted in Part IX.
