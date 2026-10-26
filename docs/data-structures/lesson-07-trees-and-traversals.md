# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 07 — TREES, BINARY TREES, AND TRAVERSALS

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 07 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 8 hours
**Prerequisites:** Lecture 01 — Models, ADTs, and Asymptotic Analysis; Lecture 04 — Stacks, Queues, and Deques; Lecture 05 — Recursion, Induction, and Divide-and-Conquer
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Section 10.3; Goodrich, Tamassia, and Goldwasser, *Data Structures and Algorithms in Java*, 6th edition, Chapter 8; Weiss, *Data Structures and Algorithm Analysis in C++*, 4th edition, Sections 4.1 and 4.2; Knuth, *The Art of Computer Programming*, Volume 1, 3rd edition, Section 2.3.1

**This lecture owns:** Tree vocabulary, the course height convention, binary-tree representations, and the four standard traversals.
**This lecture does not teach:** The binary-search-tree property, rotations, or heap order. Lecture 08 adds a search order on the linked shape taught here, and Lecture 10 adds heap order on the complete-tree array taught here.

---

## Learning objectives

By the end of this lecture you should be able to do the following without notes.

1. Define a rooted tree and compute parent, children, root, leaf, internal node, edge, path, ancestor, descendant, subtree, degree, depth, and height on a drawn tree.
2. Use the locked convention in every calculation: the empty tree has height $-1$, a leaf has height $0$, and the root has depth $0$.
3. Prove that, in a nonempty tree, the height of the root equals the maximum depth of a node.
4. Classify a binary tree as full, perfect, complete, or none of these, and draw an example of each class.
5. Prove that a perfect binary tree of height $h$ has $n = 2^{h+1} - 1$ nodes, conclude that this height is $\Theta(\log n)$, and contrast it with a skewed tree of height $n - 1$.
6. Represent a binary tree with element, left, and right links; state the space and the maintenance cost of an optional parent pointer.
7. Compute the parent and the children of an index in the 0-based array layout of a complete binary tree: parent $\lfloor (i-1)/2 \rfloor$, left child $2i+1$, right child $2i+2$.
8. Produce the preorder, inorder, postorder, and level-order sequences of one tree, including an explicit-stack preorder and a queue-based level order.
9. Build an expression tree, print the fully parenthesized inorder form and the postfix form, and evaluate the tree by a postorder fold.
10. Write the recurrences for size, height, and leaf count, and state that an exhaustive walk is $\Theta(n)$ time on every shape.
11. Reconstruct a binary tree with distinct labels from preorder plus inorder, and give a two-node counterexample showing that preorder plus postorder does not determine a unique binary tree.
12. Implement the laboratory program, then complete the mid-course checkpoint from the specification in the assignment.

---

## Purpose

A tree is the first structure in this course whose shape is a hierarchy rather than a line. Lists, stacks, and queues answer "what is next?" A tree answers "what is under this node?" File directories, arithmetic expressions, and the later search trees and heaps are all that question with an extra rule. This lecture fixes the vocabulary and the walks. It does not add the extra rule.

The height convention is locked for the rest of the course. The empty tree has height $-1$. A leaf has height $0$. The root has depth $0$. Lecture 09's balance factor is $\mathrm{height}(\mathrm{left}) - \mathrm{height}(\mathrm{right})$, and that subtraction is wrong if a missing child is treated as height $0$. Every formula below uses the locked convention. Weiss, Sections 4.1 and 4.2, measures height by edges and takes the height of an empty subtree to be $-1$. Goodrich, Tamassia, and Goldwasser, Chapter 8, likewise take the height of a nonempty tree to be the maximum depth of a node. Read those chapters for the vocabulary. Do not read Weiss from Section 4.3 onward in this week: that material is the search property and the rotations, which belong to Lectures 08 and 09.

This lecture deliberately does not teach the binary-search-tree property, rotations, or heap order. A binary tree here stores an element and two ordered child positions. It does not require the left subtree to hold smaller keys, and it does not require a parent to be ordered relative to its children. Those are invariants added later to the same shapes. The array indexes are taught here because they are a fact about complete binary trees. Lecture 10 will store a heap in that array; the order on the values is not part of this lecture.

The place a bare binary tree is the wrong choice is any operation that asks about a key. Without an order invariant, "does this element occur?" and "what is the minimum element?" are exhaustive walks, $\Theta(n)$ time. A search tree or a hash table exists to avoid that. This lecture still needs the walks, because every later tree algorithm is one of these walks plus a test at the node.

---

## Part 1 — Rooted trees

### 1.1 Definition

A **rooted tree** is a finite set of **nodes** together with a parent relation that satisfies three rules.

1. Exactly one node is the **root**. Its parent is absent.
2. Every other node has exactly one parent, and that parent is a node of the tree.
3. Following parents from any node reaches the root after a finite number of steps, and no node repeats on that walk.

Rule 3 is what makes the structure a tree rather than a node with a cycle of parent links. If a parent walk repeated a node, it would loop and never reach the root.

The **element** of a node is the value stored there. The structure theorems in this lecture do not depend on what the element is. Traversals report elements in a determined order. The element may be a number, a string, or any other value the program can store.

A **child** of a node $u$ is a node whose parent is $u$. The children of $u$ are unordered in a general rooted tree. Part 2 will order them. Two nodes with the same parent are **siblings**.

### 1.2 The words used on every picture

Take the tree drawn below. It is the single example used for the definitions, the height arithmetic, and all four traversals. Later parts call it the trace tree.

```text
        A
       / \
      B   C
     / \   \
    D   E   F
       /
      G
```

- The root is $A$. The parent of $A$ is absent.
- The children of $A$ are $B$ and $C$. The children of $B$ are $D$ and $E$. The only child of $C$ is $F$. The only child of $E$ is $G$.
- $D$ and $E$ are siblings. $B$ and $C$ are siblings. $G$ has no sibling.
- A **leaf** is a node with no children. The leaves are $D$, $G$, and $F$. Some books say **external node** for a leaf. This lecture says leaf.
- An **internal node** is a node that is not a leaf. The internal nodes are $A$, $B$, $C$, and $E$.
- An **edge** joins a parent to one child. The edges are $A\!-\!B$, $A\!-\!C$, $B\!-\!D$, $B\!-\!E$, $E\!-\!G$, and $C\!-\!F$. There are $6$ edges and $7$ nodes.

The **degree** of a node, in this lecture, is the number of children. $\mathrm{degree}(A) = 2$, $\mathrm{degree}(B) = 2$, $\mathrm{degree}(C) = 1$, $\mathrm{degree}(E) = 1$, and every leaf has degree $0$. Lecture 12's graph degree counts every incident edge, including the edge up to the parent. A non-root leaf then has graph degree $1$ and rooted degree $0$. The two numbers are not interchangeable. This course uses rooted degree until a section is explicitly about graphs.

A **downward path** is a sequence of nodes in which each step goes from a parent to one of its children. $A, B, E, G$ is a downward path. A **simple path** in the underlying undirected tree is a sequence in which each consecutive pair is joined by an edge and no node repeats. $D, B, A, C$ is a simple path and is not downward.

**Theorem (unique simple path).** In a rooted tree there is exactly one simple path between any two nodes.

**Proof.** Existence: from any node, the parent walk reaches the root, so every node is connected to the root and therefore to every other node. Uniqueness: suppose two distinct simple paths joined $u$ and $v$. Walking one path from $u$ to $v$ and returning on the other would repeat no edge until the walk closed, and the first return to an already visited node would be a cycle. A cycle cannot exist: along a cycle, parent pointers cannot all point toward a single root, because rule 3 gives every node a unique parent chain and that chain does not repeat a node. So the simple path is unique. Depth, defined next, is well-defined because the path from the root to a node is unique.

An **ancestor** of a node $v$ is a node on the simple path from the root to $v$, including $v$. A **proper ancestor** is an ancestor other than $v$. A **descendant** of $u$ is a node that has $u$ as an ancestor, including $u$. A **proper descendant** excludes $u$. The parent of $v$, when $v$ is not the root, is the proper ancestor whose depth is one less than the depth of $v$.

The **subtree** rooted at $v$ is the rooted tree whose node set is $v$ together with all descendants of $v$, with the same parent relation, except that $v$ has no parent inside that subtree. The subtree rooted at $E$ contains $E$ and $G$. The subtree rooted at $B$ contains $B$, $D$, $E$, and $G$.

**Theorem ($n - 1$ edges).** A rooted tree with $n$ nodes has exactly $n - 1$ edges.

**Proof.** Every node other than the root has exactly one parent, and each such parent link is one edge. The root contributes no parent edge. That is $n - 1$ edges. The trace tree has $n = 7$ and $7 - 1 = 6$ edges, which matches the list above.

### 1.3 Depth and height

The **depth** of a node is the number of edges on the unique simple path from the root to that node.

$$
\mathrm{depth}(\mathrm{root}) = 0
$$

$$
\mathrm{depth}(v) = \mathrm{depth}(\mathrm{parent}(v)) + 1 \quad \text{when } v \text{ is not the root}
$$

On the trace tree:

| Node | Path from the root | Depth |
| --- | --- | --- |
| $A$ | $A$ | $0$ |
| $B$ | $A, B$ | $1$ |
| $C$ | $A, C$ | $1$ |
| $D$ | $A, B, D$ | $2$ |
| $E$ | $A, B, E$ | $2$ |
| $F$ | $A, C, F$ | $2$ |
| $G$ | $A, B, E, G$ | $3$ |

A **level** is the set of all nodes at one depth. Level $0$ is $\{A\}$, level $1$ is $\{B, C\}$, level $2$ is $\{D, E, F\}$, and level $3$ is $\{G\}$. Levels are numbered from $0$ because the root has depth $0$. A book that calls the root level $1$ is using a different numbering. Translate it before you use a formula from this course.

The **height of a node** $v$ is the number of edges on a longest downward path from $v$ to a leaf.

- If $v$ is a leaf, that path has no edges, so $\mathrm{height}(v) = 0$.
- If $v$ has children, $\mathrm{height}(v) = 1 + \max \{\mathrm{height}(c) : c \text{ is a child of } v\}$.

The **height of a tree** is the height of its root. The **height of the empty tree**, the tree with no nodes, is $-1$. The empty tree is not a node. The value $-1$ is the height of a missing subtree, and it is what makes the one-line recurrence agree with "a leaf has height $0$":

$$
\mathrm{height}(\mathrm{null}) = -1
$$

$$
\mathrm{height}(v) = 1 + \max(\mathrm{height}(\mathrm{left}), \mathrm{height}(\mathrm{right}))
$$

The second line is the binary-tree form. For a leaf both children are missing, so the value is $1 + \max(-1, -1) = 0$.

Apply the recurrence from the leaves upward on the trace tree.

- $\mathrm{height}(D) = 0$, $\mathrm{height}(G) = 0$, $\mathrm{height}(F) = 0$.
- $\mathrm{height}(E) = 1 + \max(\mathrm{height}(G), \mathrm{height}(\mathrm{null})) = 1 + \max(0, -1) = 1$.
- $\mathrm{height}(B) = 1 + \max(\mathrm{height}(D), \mathrm{height}(E)) = 1 + \max(0, 1) = 2$.
- $\mathrm{height}(C) = 1 + \max(-1, \mathrm{height}(F)) = 1 + \max(-1, 0) = 1$.
- $\mathrm{height}(A) = 1 + \max(\mathrm{height}(B), \mathrm{height}(C)) = 1 + \max(2, 1) = 3$.

The longest downward path from the root is $A, B, E, G$, which has $3$ edges. The height of the tree is $3$. The maximum depth in the table above is also $3$, the depth of $G$. The next theorem says that agreement is not an accident of this picture.

### 1.4 Height is the maximum depth

**Theorem (height equals maximum depth).** Let $T$ be a nonempty rooted tree. The height of the root of $T$ equals the maximum depth of a node of $T$.

The empty tree is excluded on purpose. Its height is $-1$, and it has no node, so there is no depth to maximize. This course does not repair that by declaring the maximum of the empty set to be $-1$. The equality is a statement about trees that contain a root.

**Proof.** Induct on $n$, the number of nodes. The inductive hypothesis is the theorem itself for every nonempty rooted tree with fewer than $n$ nodes.

Base case, $n = 1$. The only node is the root, and it is a leaf. Its height is $0$ and its depth is $0$.

Inductive step, $n > 1$. The root $r$ is not a leaf: if it were, $n$ would be $1$. Let the subtrees rooted at the children of $r$ be $T_1, \ldots, T_k$ with $k \geq 1$. Each $T_i$ is nonempty and has fewer than $n$ nodes, and the sizes sum to $n - 1$. Write $h_i$ for the height of the root of $T_i$. By the inductive hypothesis, $h_i$ equals the maximum depth of a node inside $T_i$, where that depth is measured from the root of $T_i$. Each $T_i$ is nonempty, so $h_i \geq 0$. The value $-1$ does not appear as a subtree height in this step.

By the definition of height,

$$
\mathrm{height}(r) = 1 + \max_i h_i.
$$

A node at depth $d$ inside $T_i$ has depth $d + 1$ in $T$, because the unique path from $r$ adds the one edge from $r$ into the root of $T_i$. The depth of $r$ itself is $0$. Therefore the maximum depth in $T$ is

$$
\max\left(0,\ \max_i (1 + h_i)\right).
$$

Since some $h_i \geq 0$, the quantity $1 + \max_i h_i$ is at least $1$, so the outer maximum with $0$ does not change it. The maximum depth equals $1 + \max_i h_i$, which is $\mathrm{height}(r)$.

By induction the claim holds for every nonempty rooted tree.

On the trace tree the maximum depth is $3$ and the height is $3$. A single-node tree has height $0$ and maximum depth $0$. Both sit on the theorem. A missing child of $E$ contributes the sentinel $-1$ inside the recurrence and is not itself a node whose depth is $-1$.

---

## Part 2 — Binary trees, and three shape words

### 2.1 What makes a tree binary

A **binary tree** is a rooted tree in which every node has at most two children, and the two child positions are ordered. One position is the **left child**. The other is the **right child**. Either position may be empty.

The order is part of the data. The following two trees both have two nodes and one edge. They are different binary trees.

```text
   A          A
  /            \
 B              B
```

In a general rooted tree, "one child" does not say which side the child occupies. In a binary tree it does. Part 9 uses that fact: preorder plus postorder cannot see the difference between these two pictures.

A binary tree may be defined recursively, and the recursive definition is the one the programs follow. A binary tree is either empty, or a root together with a left binary tree and a right binary tree. The empty tree has height $-1$ and size $0$. A root whose left and right trees are both empty is a leaf of height $0$.

There is no search rule. The element in the left subtree is not required to be smaller than the element at the root. Comparing keys is Lecture 08.

### 2.2 Full, perfect, and complete

The three names are not stable across textbooks. One book uses "full" for a tree this course calls perfect. Another uses "proper" for a tree this course calls full. Later lectures use the three definitions below and no others. Goodrich, Tamassia, and Goldwasser use **proper binary tree** for the first of them.

A binary tree is **full** (also called **proper**) when every node has $0$ children or $2$ children. No node has exactly one child.

A binary tree is **perfect** when every internal node has two children and every leaf has the same depth. Equivalently, every level from depth $0$ through the height is completely filled.

A binary tree is **complete** when every level except possibly the last is completely filled, and the nodes on the last level occupy the leftmost positions. In the level numbering of Part 5, the nodes of a complete binary tree occupy indexes $0, 1, \ldots, n - 1$ with no holes. Goodrich, Chapter 8, uses that characterization.

Every perfect binary tree is full, and every perfect binary tree is complete. The converses are false, and full plus complete still does not imply perfect. The pictures below separate the words. Empty trees and single-node trees satisfy all three definitions: there is no node of degree $1$, the only leaf is at one depth, and there is no hole. The interesting separations start at larger sizes.

**Perfect, hence also full and complete.** Height $2$. Every internal node has two children. Every leaf is at depth $2$.

```text
      A
     / \
    B   C
   / \ / \
  D  E F  G
```

**Full and complete, but not perfect.** Every node has $0$ or $2$ children, and the last level holds the leftmost positions $D$ and $E$. It is not perfect because $C$ is a leaf at depth $1$ while $D$ and $E$ are leaves at depth $2$. Height is $1 + \max(\mathrm{height}(B), \mathrm{height}(C)) = 1 + \max(1, 0) = 2$.

```text
      A
     / \
    B   C
   / \
  D   E
```

**Full, and neither perfect nor complete.** Every node has $0$ or $2$ children. Leaves sit at depths $1$ ($C$), $2$ ($D$), and $3$ ($F$ and $G$), so the tree is not perfect. Level $2$ is not full, and level $3$ is not empty, so a non-last level fails to be full. The tree is not complete. Its height is $3$.

```text
      A
     / \
    B   C
   / \
  D   E
     / \
    F   G
```

**Complete, and neither full nor perfect.** Levels $0$ and $1$ are full. The last level contains only the leftmost node $D$. Node $B$ has one child, so the tree is not full. Leaves sit at depths $2$ and $1$, so the tree is not perfect. Height is $2$. Size is $4$.

```text
      A
     / \
    B   C
   /
  D
```

**None of the three.** Node $B$ has one child, so the tree is not full and not perfect. The missing child is the left child, while the right child $D$ is present, so the last level is not filled from the left. The tree is not complete.

```text
      A
     / \
    B   C
     \
      D
```

The trace tree of Part 1 is also none of the three. Node $C$ has only a right child, and node $E$ has only a left child. One of those already blocks full, perfect, and complete.

A **skewed** binary tree is a binary tree in which every node has at most one child. The nodes form a single path. With $n$ nodes that path has $n - 1$ edges, so the height is $n - 1$. A right spine is the skewed tree in which every existing child is a right child.

```text
A
 \
  B
   \
    C
     \
      D
```

This spine has size $4$ and height $3$.

---

## Part 3 — How many nodes, and why the height can be linear

### 3.1 The perfect-tree count

**Theorem (nodes in a perfect binary tree).** A perfect binary tree of height $h \geq 0$ has

$$
n = 2^{h+1} - 1
$$

nodes. The empty tree has height $-1$ and $2^{(-1)+1} - 1 = 0$ nodes, so the same algebraic expression fits the sentinel, but the induction below is stated for perfect trees of height at least $0$.

The inductive shape used in the proof is equivalent to the definition in Part 2. A perfect binary tree of height $0$ is a single node. A perfect binary tree of height $h \geq 1$ is a root whose left subtree and right subtree are both perfect binary trees of height $h - 1$. That forces every internal node to have two children, and it forces every leaf to sit at depth $h$. In the other direction, if every internal node has two children and every leaf has depth $h$, the two subtrees of the root are perfect of height $h - 1$.

**Proof.** Induct on $h$.

Base case, $h = 0$. A single node has $n = 1$, and $2^{0+1} - 1 = 1$.

Inductive step, $h \geq 1$. Assume every perfect binary tree of height $h - 1$ has $2^{(h-1)+1} - 1 = 2^{h} - 1$ nodes. A perfect binary tree of height $h$ is a root plus two such subtrees, so

$$
n = 1 + 2(2^{h} - 1) = 1 + 2^{h+1} - 2 = 2^{h+1} - 1.
$$

By induction the formula holds for every height $h \geq 0$.

The same count is the sum of the level sizes. Level $d$ of a perfect binary tree has $2^{d}$ nodes: level $0$ has $1$, and every node on level $d$ has two children, so level $d + 1$ has twice as many nodes. Therefore

$$
n = \sum_{d=0}^{h} 2^{d}.
$$

**Lemma (geometric sum).** For every integer $h \geq 0$,

$$
\sum_{d=0}^{h} 2^{d} = 2^{h+1} - 1.
$$

**Proof.** Let $S$ be the sum. Then $2S = \sum_{d=1}^{h+1} 2^{d} = S - 2^{0} + 2^{h+1} = S - 1 + 2^{h+1}$. Subtracting $S$ from both sides yields $S = 2^{h+1} - 1$.

The two proofs agree. For height $2$, the levels have $1 + 2 + 4 = 7$ nodes, and $2^{3} - 1 = 7$. The perfect picture in Part 2 is that tree.

**Corollary (leaves and internal nodes).** A perfect binary tree of height $h$ has $2^{h}$ leaves and $2^{h} - 1$ internal nodes.

**Proof.** The leaves are exactly the nodes on level $h$, and that level has $2^{h}$ nodes. The internal nodes are the rest:

$$
n - 2^{h} = (2^{h+1} - 1) - 2^{h} = 2^{h} - 1.
$$

For $h = 2$ there are $4$ leaves and $3$ internal nodes.

### 3.2 Height in terms of $n$

Solve the node formula for the height. From $n = 2^{h+1} - 1$,

$$
n + 1 = 2^{h+1}, \qquad h + 1 = \log(n + 1), \qquad h = \log(n + 1) - 1.
$$

Here $\log$ is base $2$, as in the rest of the course. For a perfect tree the height is exactly $\log(n + 1) - 1$, which is $\Theta(\log n)$.

A complete binary tree is as short as a binary tree on $n$ nodes can be. It has at least the nodes of a perfect tree of height $h - 1$, namely $2^{h} - 1$, plus at least one node on level $h$ when $h \geq 1$, so $n \geq 2^{h}$. It has at most the nodes of a perfect tree of height $h$, so $n \leq 2^{h+1} - 1$. Those two inequalities are exactly

$$
2^{h} \leq n \leq 2^{h+1} - 1,
$$

which is the statement $h = \lfloor \log n \rfloor$ for $n \geq 1$. The same integer is $\lceil \log(n + 1) \rceil - 1$. Indeed, if $h = \lfloor \log n \rfloor$, then $2^{h} \leq n < 2^{h+1}$, so $2^{h} < n + 1 \leq 2^{h+1}$. Taking $\log$ and then the ceiling gives $\lceil \log(n + 1) \rceil = h + 1$.

A skewed binary tree of $n$ nodes has height $n - 1$, which is $\Theta(n)$.

So the height of a binary tree on $n$ nodes can be as small as $\lfloor \log n \rfloor$ and as large as $n - 1$. For $n = 7$ the minimum is $2$, achieved by the perfect tree, and the maximum is $6$, achieved by any spine. The number of nodes does not determine the height. The shape does.

An exhaustive walk, proved linear in Part 8, costs $\Theta(n)$ on both shapes. The height changes a different cost: the depth of recursion, and, in Lectures 08 and 09, the cost of a search that follows one path. Lecture 09 will force the height of a search tree to stay $\Theta(\log n)$. This lecture does not rotate or rebalance anything.

JavaScript numbers represent every integer from $-2^{53} + 1$ through $2^{53} - 1$ exactly, and `Number.MAX_SAFE_INTEGER` is $2^{53} - 1$. The formula $2^{h+1} - 1$ is a safe integer for $-1 \leq h \leq 52$, since the largest such value is $2^{53} - 1$. The mathematical formula continues to hold for larger $h$. A JavaScript number does not store $2^{54} - 1$ exactly, so the laboratory function refuses heights above $52$ rather than returning a rounded value and calling it a node count.

---

## Part 4 — The linked representation

### 4.1 The node

The representation that matches an arbitrary binary tree is a node object with three fields: the element, the left child, and the right child. An absent child is `null`, not a sentinel node and not a missing property.

The reason to store children as links, rather than as indexes into an array, is that a binary tree may have holes. The right-child-only tree in Part 2 is a legal binary tree. A link representation stores four nodes and three edges and wastes nothing on the empty left positions. Part 5 shows what those holes cost in an array.

A parent pointer is optional. The four traversals and the structural recurrences use only left and right. The pointer is worth adding when the algorithm must step from a node to its parent in constant time. It is not free.

Without a parent pointer, the parent of a node is found by searching from the root, which takes $\Theta(n)$ time in the worst case. With the pointer, that query is $\Theta(1)$. The space cost is one extra reference on every node. The whole tree occupies $\Theta(n)$ words either way; the constant factor on the link storage grows from two child links to three links. The time cost is maintenance. Every write to a child link must keep the following invariant true.

**Parent invariant.** `parent` of the root is `null`. If `left` of $u$ is a node $v$, then `parent` of $v$ is $u$, and likewise for `right`. No node is the child of two different parents. Following `parent` reaches `null` without repetition, and following `left` or `right` never returns to an ancestor.

The constructor and the setters in the laboratory program maintain that invariant. Setting a child detaches the previous child by clearing its parent, rejects a child that already has a different parent, and rejects a child that is the node itself or one of its ancestors. The ancestor test is a walk up parent pointers, $\Theta(h)$ time, which is $\Theta(n)$ on a spine and $\Theta(\log n)$ on a perfect tree. Forgetting the parent update leaves a child whose parent is `null` or, worse, still points at a node that no longer points back. Traversals that ignore `parent` still run. Any later algorithm that trusts `parent` walks off the tree.

The linked tree uses $\Theta(n)$ space for $n$ nodes. Building it by linking existing nodes is $\Theta(1)$ per link. This lecture does not keep a cached size or a cached height. Each call recomputes them by a walk, so each call is $\Theta(n)$ time. Lecture 09 stores a height in the node because rotations need it after a local change. That cache is a later choice, and it brings its own invariant. It is not required to define height.

### 4.2 The abstract data type

The binary-tree ADT in this lecture is positional. The caller says which child link to write. The structure does not choose a position from the element.

| Operation | Behavior | Cost in the linked representation |
| --- | --- | --- |
| `isEmpty` | True when the root is `null` | $\Theta(1)$ |
| `size` | Number of nodes | $\Theta(n)$ time, $\Theta(h)$ stack space |
| `height` | Height of the root, or $-1$ if empty | $\Theta(n)$ time, $\Theta(h)$ stack space |
| `left`, `right` | The child, or `null` | $\Theta(1)$ |
| `parent` | The parent, or `null` if the pointer is stored; otherwise a search from the root | $\Theta(1)$ with the pointer, $\Theta(n)$ without it |
| `setLeft`, `setRight` | Replace that child and restore the parent invariant | $\Theta(h)$ for the ancestor check, $\Theta(1)$ link writes |
| four traversals | The sequences defined in Part 6 | $\Theta(n)$ time; stack or queue space as stated there |

There is no `insert(key)`. A method of that name would have to invent a position, and the honest inventions are the search rules of later lectures.

JavaScript arrays already grow as dynamic arrays. The output of a traversal is such an array, and appending $n$ results is $\Theta(n)$ total work at that abstraction, as proved for geometric growth in Lecture 02. That cost is absorbed in the $\Theta(n)$ bound of the walk. It is not a claim about one engine's allocator.

---

## Part 5 — The array representation of a complete binary tree

### 5.1 Why completeness removes the holes

Number the possible positions of a binary tree in level order, starting at $0$. The root has number $0$. The left child of position $i$ has number $2i + 1$. The right child has number $2i + 2$. This numbering is a property of positions, including positions that happen to be empty. Goodrich, Tamassia, and Goldwasser, Section 8.3.2, call it a level numbering and give these three formulas for a root numbered $0$.

If the tree is complete, the occupied positions are exactly $0, 1, \ldots, n - 1$. Store the elements in an array $A$ of length $n$:

$$
A[i] = \text{the element of the node at level-number } i.
$$

The parent and the children are then arithmetic, provided the index exists.

$$
\mathrm{parent}(i) = \left\lfloor \frac{i - 1}{2} \right\rfloor \quad (i > 0)
$$

$$
\mathrm{left}(i) = 2i + 1, \qquad \mathrm{right}(i) = 2i + 2
$$

A child index is a real node only when it is strictly less than $n$. The root has no parent.

Nothing in these formulas compares elements. Lecture 10 stores a binary heap in this layout and adds heap order. This lecture stops at the layout.

A 1-based numbering, with the root at $1$, uses parent $\lfloor i / 2 \rfloor$ and children $2i$ and $2i + 1$. That is a different convention. Mixing it with a 0-based array reads the wrong cells. This course is 0-based.

### 5.2 Proof of the index formulas

**Theorem (child indexes).** In the 0-based level numbering, the left child of $i$ is $2i + 1$ and the right child is $2i + 2$. If the tree is complete and has $n$ nodes, those children exist exactly when the index is strictly less than $n$, and the parent of $i > 0$ is $\lfloor (i - 1) / 2 \rfloor$.

**Proof.** The nodes at depth less than $d$ form a perfect binary tree of height $d - 1$. By Part 3 that tree has $2^{d} - 1$ nodes, so they occupy indexes $0$ through $2^{d} - 2$. The first index at depth $d$ is $2^{d} - 1$.

Let node $i$ lie at depth $d$ and be the $k$-th node on that level, with $k$ starting at $0$. Then $i = (2^{d} - 1) + k$. The children of level $d$ begin at index $2^{d+1} - 1$. The $k$ nodes to the left of this node each have two child positions, which occupy $2k$ indexes. The left child is therefore at

$$
(2^{d+1} - 1) + 2k = 2(2^{d} - 1 + k) + 1 = 2i + 1.
$$

The right child is the next index, $2i + 2$.

For the parent, take $i > 0$. If $i$ is a left child, then $i = 2p + 1$, so $p = (i - 1) / 2$ exactly. If $i$ is a right child, then $i = 2p + 2$, so $i - 1 = 2p + 1$ and $\lfloor (i - 1) / 2 \rfloor = p$. Both cases are $\lfloor (i - 1) / 2 \rfloor$.

Completeness is the hypothesis that makes $A$ a packed array of length $n$. Without it, the numbering still names positions, but empty positions become holes and the array must be long enough for the largest occupied index.

### 5.3 A packed example, and the cost of a spine

The perfect tree of height $2$ is complete. Its level-order array is

```text
index:    0  1  2  3  4  5  6
element:  A  B  C  D  E  F  G
```

Check the formulas against the picture.

- Parent of $E$, index $4$: $\lfloor (4 - 1) / 2 \rfloor = \lfloor 3 / 2 \rfloor = 1$, which holds $B$.
- Left of $B$, index $1$: $2 \cdot 1 + 1 = 3$, which holds $D$. Right: $2 \cdot 1 + 2 = 4$, which holds $E$.
- Left of $C$, index $2$: $5$, which holds $F$. Right: $6$, which holds $G$.
- Parent of $G$, index $6$: $\lfloor 5 / 2 \rfloor = 2$, which holds $C$.
- Parent of the root is undefined. The formula is stated for $i > 0$.

Now take a right spine of $n$ nodes. The index of the node at depth $d$ satisfies $i_0 = 0$ and $i_d = 2 i_{d-1} + 2$. Then $i_d + 2 = 2(i_{d-1} + 2)$, so $i_d + 2 = 2^{d} \cdot (i_0 + 2) = 2^{d+1}$, and $i_d = 2^{d+1} - 2$. The deepest node has depth $n - 1$ and index $2^{n} - 2$. The array that reaches that index has length $2^{n} - 1$. A left spine is smaller but still exponential: the left-child recurrence $i_d = 2 i_{d-1} + 1$ gives $i_d = 2^{d} - 1$, so $n$ nodes require length $2^{n-1}$. Either spine uses exponential space to store a linear number of nodes. The linked representation stores that spine in $\Theta(n)$ words. Use the array when the tree is complete, or when you are willing to keep the holes of a nearly complete tree. Use links when the shape is arbitrary.

The rightmost position at depth $d$ is the expensive one, index $2^{d+1} - 2$. A perfect tree of height $h$ has $n = 2^{h+1} - 1$ and array length $n$, with no holes. The exponential waste comes from height that is linear in $n$, not from perfection.

---

## Part 6 — The four traversals

### 6.1 What a traversal is

A traversal visits each node exactly once and performs a stated action at the visit. In this lecture the action appends the element to an output sequence. The same control structure computes size, height, and the expression value; only the action changes. Knuth, Volume 1, Section 2.3.1, isolates the three depth-first orders by the position of the visit relative to the two subtrees. Goodrich, Tamassia, and Goldwasser, Section 8.4, add the breadth-first order, which this lecture calls level order. Graph breadth-first search is Lecture 12. On a tree, with the queue started at the root and the edges restricted to child links, the visit order is level order.

Throughout this part the tree is the trace tree, repeated here so the tables can be checked against one picture.

```text
        A
       / \
      B   C
     / \   \
    D   E   F
       /
      G
```

### 6.2 Preorder, inorder, and postorder

The three recursive definitions differ only in when the node itself is visited. On the empty tree, each walk does nothing.

**Preorder:** visit the node, then walk the left subtree, then walk the right subtree.

**Inorder:** walk the left subtree, then visit the node, then walk the right subtree.

**Postorder:** walk the left subtree, then walk the right subtree, then visit the node.

The names say where the node sits relative to its subtrees: before them, between them, or after them. Left is always walked before right. Swapping that convention would produce different sequences. This course does not swap it.

Compute preorder of the trace tree by expanding the definition.

- Visit $A$. Walk the left subtree, which is rooted at $B$.
- Visit $B$. Walk $D$. $D$ is a leaf, so its walk is the single visit $D$.
- Walk $E$. Visit $E$, then walk $G$. Visit $G$. $E$ has no right child.
- The left subtree of $A$ is finished. Walk the right subtree. Visit $C$. $C$ has no left child. Visit $F$.

The preorder sequence is $A, B, D, E, G, C, F$.

Inorder expands in the other rhythm.

- The left subtree of $A$ produces the inorder of $B$'s tree: inorder of $D$, then $B$, then inorder of $E$.
- Inorder of $D$ is $D$. Inorder of $E$ is inorder of $G$, then $E$, which is $G, E$.
- Then visit $A$. Then the inorder of $C$'s tree: $C$ has no left child, so visit $C$, then $F$.

The inorder sequence is $D, B, G, E, A, C, F$.

Postorder visits a node only after both subtrees.

- Postorder of $D$ is $D$. Postorder of $E$ is $G$, then $E$. Then visit $B$. So $B$'s subtree yields $D, G, E, B$.
- Postorder of $C$'s subtree is $F$, then $C$.
- Then visit $A$.

The postorder sequence is $D, G, E, B, F, C, A$.

### 6.3 Preorder with an explicit stack

The recursive preorder uses the call stack of Lecture 05. The same order can be produced with an explicit stack, which makes the pending right subtrees visible. The reason the right child is pushed before the left child is that a stack pops the most recent push first, and preorder must walk the left child next.

```text
if the root is null, the output is empty
push the root
while the stack is not empty:
    pop a node and visit it
    if it has a right child, push that child
    if it has a left child, push that child
```

The stack is written from bottom to top, so the rightmost name is the top. The trace tree starts with $A$ on the stack.

| Step | Pop and visit | Then push | Stack, bottom to top | Output |
| --- | --- | --- | --- | --- |
| 0 |  | $A$ | $A$ |  |
| 1 | $A$ | $C$, then $B$ | $C\ B$ | $A$ |
| 2 | $B$ | $E$, then $D$ | $C\ E\ D$ | $A\ B$ |
| 3 | $D$ |  | $C\ E$ | $A\ B\ D$ |
| 4 | $E$ | $G$ | $C\ G$ | $A\ B\ D\ E$ |
| 5 | $G$ |  | $C$ | $A\ B\ D\ E\ G$ |
| 6 | $C$ | $F$ | $F$ | $A\ B\ D\ E\ G\ C$ |
| 7 | $F$ |  | empty | $A\ B\ D\ E\ G\ C\ F$ |

The output is the preorder sequence. Pushing the left child before the right child would pop the right child first and would not be preorder. That is a mechanical error, not a second convention.

The explicit stack holds the nodes that have been seen but whose left-then-right expansion is not finished. Its maximum size is $\Theta(h)$: the deepest chain of pending nodes follows a root-to-leaf path, which has $h$ edges. On this tree $h = 3$. On a spine it is $\Theta(n)$. It is $\Theta(\log n)$ only when the height is.

### 6.4 Inorder with an explicit stack

Inorder cannot visit a node when it first sees it. It must finish the left subtree first. The stack stores the nodes whose left subtrees are being walked and that have not been visited yet.

```text
stack is empty
node is the root
while the stack is not empty or node is not null:
    while node is not null:
        push node
        node is the left child
    pop node and visit it
    node is the right child
```

| Step | Action | Stack, bottom to top | Output |
| --- | --- | --- | --- |
| 1 | descend $A$, $B$, $D$ | $A\ B\ D$ |  |
| 2 | pop $D$, right child is null | $A\ B$ | $D$ |
| 3 | pop $B$, right child is $E$ | $A$ | $D\ B$ |
| 4 | descend $E$, $G$ | $A\ E\ G$ | $D\ B$ |
| 5 | pop $G$, right child is null | $A\ E$ | $D\ B\ G$ |
| 6 | pop $E$, right child is null | $A$ | $D\ B\ G\ E$ |
| 7 | pop $A$, right child is $C$ | empty | $D\ B\ G\ E\ A$ |
| 8 | descend $C$; it has no left child | $C$ | $D\ B\ G\ E\ A$ |
| 9 | pop $C$, right child is $F$ | empty | $D\ B\ G\ E\ A\ C$ |
| 10 | descend $F$ | $F$ | $D\ B\ G\ E\ A\ C$ |
| 11 | pop $F$, right child is null | empty | $D\ B\ G\ E\ A\ C\ F$ |

The output is $D, B, G, E, A, C, F$, the inorder sequence. The stack depth is again $\Theta(h)$.

### 6.5 Postorder with two stacks

Postorder is the awkward one for a single stack, because a node must be visited after both children, so the algorithm has to remember that the right subtree has already been expanded. Two stacks make the memory explicit. The first stack produces node, then right subtree, then left subtree. That is preorder with the children swapped. The second stack reverses that sequence. The reverse of "node, right, left" is "left, right, node", which is postorder.

```text
push the root on the first stack
while the first stack is not empty:
    pop a node and push it on the second stack
    if it has a left child, push that child on the first stack
    if it has a right child, push that child on the first stack
then pop the second stack until it is empty, visiting each popped node
```

On the trace tree the second stack, written bottom to top, ends as $A\ C\ F\ B\ E\ G\ D$. Popping it visits $D, G, E, B, F, C, A$. That is the postorder sequence already computed from the recursive definition. The laboratory program checks the two procedures against each other. The maximum extra space is $\Theta(n)$, because the second stack holds every node. The recursive postorder uses only $\Theta(h)$ stack frames. Prefer the recursive form when the height is known to be small; prefer the explicit form when you need the pending nodes in variables rather than in the call stack. Both are correct on every shape, including a spine, provided the call stack or the explicit stacks can hold $\Theta(n)$ frames or nodes.

### 6.6 Level order, with the queue from Lecture 04

Level order visits nodes in order of increasing depth, and from left to right inside a level. The data structure that matches "the first node discovered is the first node expanded" is a queue. Use a queue whose enqueue and dequeue are $\Theta(1)$ time. The linked queue in the laboratory program is that structure: a head, a tail, and a length. `Array.prototype.shift` on a dense JavaScript array moves every later element, so $n$ shifts cost $\Theta(n^{2})$ and do not meet the bound claimed here.

```text
if the root is null, the output is empty
enqueue the root
while the queue is not empty:
    dequeue a node and visit it
    if it has a left child, enqueue that child
    if it has a right child, enqueue that child
```

The queue is written from front to back.

| Step | Dequeue and visit | Enqueue | Queue, front to back | Output |
| --- | --- | --- | --- | --- |
| 0 |  | $A$ | $A$ |  |
| 1 | $A$ | $B$, $C$ | $B\ C$ | $A$ |
| 2 | $B$ | $D$, $E$ | $C\ D\ E$ | $A\ B$ |
| 3 | $C$ | $F$ | $D\ E\ F$ | $A\ B\ C$ |
| 4 | $D$ |  | $E\ F$ | $A\ B\ C\ D$ |
| 5 | $E$ | $G$ | $F\ G$ | $A\ B\ C\ D\ E$ |
| 6 | $F$ |  | $G$ | $A\ B\ C\ D\ E\ F$ |
| 7 | $G$ |  | empty | $A\ B\ C\ D\ E\ F\ G$ |

The level-order sequence is $A, B, C, D, E, F, G$.

The four sequences of the trace tree, collected in one place because the laboratory asserts these lists:

| Order | Sequence |
| --- | --- |
| Preorder | $A, B, D, E, G, C, F$ |
| Inorder | $D, B, G, E, A, C, F$ |
| Postorder | $D, G, E, B, F, C, A$ |
| Level order | $A, B, C, D, E, F, G$ |

### 6.7 Time and extra space

Each of the four walks does a constant amount of work per node and follows each child link a constant number of times. Part 8 proves that any such walk is $\Theta(n)$ time on every shape. Balance does not make a traversal $\Theta(\log n)$. Balance shortens the height. The walk still touches every node.

Extra space, beyond the output of $n$ elements:

| Walk | Extra space |
| --- | --- |
| Recursive preorder, inorder, or postorder | $\Theta(h)$ call-stack frames |
| Explicit-stack preorder or inorder | $\Theta(h)$ |
| Two-stack postorder | $\Theta(n)$ |
| Level order | $\Theta(w)$, where $w$ is the maximum number of nodes on one level |

**Theorem (width).** In a binary tree of $n$ nodes, the width $w$ satisfies $w \leq (n + 1) / 2$.

**Proof.** The empty tree has width $0$. For a nonempty tree, the width is at most the maximum of $1$ and $w_L + w_R$, where $w_L$ and $w_R$ are the widths of the left and right subtrees. A level below the root is a level of the left subtree beside a level of the right subtree, so it cannot be wider than the sum of the two widths, even if the widest levels of the two subtrees sit at different depths. Induct on $n$. The inductive hypothesis gives $w_L \leq (n_L + 1) / 2$ and $w_R \leq (n_R + 1) / 2$, with the empty width $0$. Then

$$
w_L + w_R \leq \frac{n_L + n_R + 2}{2} = \frac{(n - 1) + 2}{2} = \frac{n + 1}{2},
$$

and $1 \leq (n + 1) / 2$ for $n \geq 1$. So $w \leq (n + 1) / 2$.

The bound is tight for a perfect tree: the last level has $2^{h}$ nodes and $n = 2^{h+1} - 1$, so $w = (n + 1) / 2$. Level order therefore uses $\Theta(n)$ queue space on some trees, and $O(n)$ queue space on all of them. The trace tree has width $3$, the size of level $2$.

---

## Part 7 — Expression trees

### 7.1 The shape of an expression

An **expression tree** is a binary tree whose leaves are **operands** and whose internal nodes are **operators**. This lecture uses the binary operators addition, subtraction, multiplication, and division. A binary operator node has two children. A leaf has none. That is the full-binary-tree shape restricted to the operators that need two arguments. Unary minus is a different tree, with one child, and it is not used in the worked example.

The tree records the order of operations by its shape. Operator precedence is not consulted while the tree is evaluated. Precedence matters only when a linear notation has to be turned into a tree, which is the job of the shunting-yard algorithm in Lecture 04. Here the tree is given.

The worked tree represents $(3 + 5) \times 2 - (8 / 4)$, with multiplication written `*` and division written `/`.

```text
        -
       / \
      *   /
     / \ / \
    +   2 8  4
   / \
  3   5
```

The leaves $3$, $5$, $2$, $8$, and $4$ are operands. The internal nodes `+`, `*`, `/`, and `-` are operators.

### 7.2 Inorder prints the expression only with parentheses

The raw inorder sequence visits left, node, right, so it writes

$$
3,\ +,\ 5,\ *,\ 2,\ -,\ 8,\ /,\ 4.
$$

Joined by spaces, that is `3 + 5 * 2 - 8 / 4`. Under ordinary precedence this string is $3 + (5 \cdot 2) - (8 / 4) = 3 + 10 - 2 = 11$. The tree does not mean $11$. The tree means: add $3$ and $5$ first, multiply by $2$, divide $8$ by $4$, then subtract. The raw inorder string dropped the shape.

The **fully parenthesized inorder** puts a pair of parentheses around every operator, after the two subtrees have been printed:

```text
if the node is a leaf, print the operand
otherwise print "(", then the left subtree, then the operator,
then the right subtree, then ")"
```

Expand it from the inside.

- The `+` node prints `(3 + 5)`.
- The `*` node prints `((3 + 5) * 2)`.
- The `/` node prints `(8 / 4)`.
- The root prints `(((3 + 5) * 2) - (8 / 4))`.

Every operator is wrapped, including the root. The parentheses are the result, not decoration. They are what makes the string determine the tree.

### 7.3 Postorder is postfix

Postorder visits both operands before the operator that combines them. Expanding the definition:

- Postorder of `+` is $3$, $5$, `+`.
- Postorder of `*` is $3$, $5$, `+`, $2$, `*`.
- Postorder of `/` is $8$, $4$, `/`.
- Postorder of the root is $3$, $5$, `+`, $2$, `*`, $8$, $4$, `/`, `-`.

The postfix string is `3 5 + 2 * 8 4 / -`. No parentheses are required. The operator sits after its operands, so the shape is recoverable by the stack evaluation of Lecture 04, repeated in the next section because the pop order is the entire correctness argument.

### 7.4 Evaluation is a postorder fold

A **fold** here means: compute a value for each child, then combine those values at the node. That is postorder. The recursive evaluation is the fold written as a function.

```text
if the node is a leaf, return the operand
otherwise return operator(evaluate(left), evaluate(right))
```

The same arithmetic on the worked tree, from the leaves upward:

| Subtree | Left value | Right value | Combination | Result |
| --- | --- | --- | --- | --- |
| `+` | $3$ | $5$ | $3 + 5$ | $8$ |
| `*` | $8$ | $2$ | $8 \cdot 2$ | $16$ |
| `/` | $8$ | $4$ | $8 / 4$ | $2$ |
| `-` | $16$ | $2$ | $16 - 2$ | $14$ |

The value of the tree is $14$.

The postfix string produces the same number with an explicit stack. Scan tokens from left to right. Push an operand. On an operator, pop the right operand first, then pop the left operand, apply the operator, and push the result.

| Token | Stack after the token, bottom to top |
| --- | --- |
| $3$ | $3$ |
| $5$ | $3,\ 5$ |
| `+` | $8$ |
| $2$ | $8,\ 2$ |
| `*` | $16$ |
| $8$ | $16,\ 8$ |
| $4$ | $16,\ 8,\ 4$ |
| `/` | $16,\ 2$ |
| `-` | $14$ |

The first pop is the right operand. At the last step the stack holds $16$ under $2$. Pop $2$ as the right operand and $16$ as the left operand, and compute $16 - 2 = 14$. If the first pop were treated as the left operand, that step would compute $2 - 16 = -14$, which is a safe integer and is the wrong value. Subtraction and division are the operators that expose the mistake. Addition and multiplication hide it.

The laboratory evaluator uses JavaScript numbers and accepts a result only when it is a safe integer. Every division in a tree it evaluates must come out exact. `8 / 4` is the integer $2$. `1 / 2` is the JavaScript number $0.5$, which is not a safe integer, so the function throws rather than returning a float and calling it the value of an integer expression. Division by zero throws. The mathematical fold is defined for the rational numbers; the program is the restriction of that fold to safe integers, and the restriction is stated so that a later reader does not treat a rounded `Number` as an exact node count or an exact quotient.

---

## Part 8 — Structural recursion

### 8.1 Size, height, and leaves

The functions in this part do not look at the element, except when a later action needs it. They look at the shape. Each is defined by the empty tree and by a rule that combines the two subtrees. That is structural recursion. The call stack of Lecture 05 is the mechanism. The recurrence is the cost.

**Size.**

$$
\mathrm{size}(\mathrm{null}) = 0
$$

$$
\mathrm{size}(v) = 1 + \mathrm{size}(\mathrm{left}(v)) + \mathrm{size}(\mathrm{right}(v))
$$

On the trace tree, $\mathrm{size}(G) = 1$, $\mathrm{size}(E) = 1 + 1 + 0 = 2$, $\mathrm{size}(D) = 1$, $\mathrm{size}(B) = 1 + 1 + 2 = 4$, $\mathrm{size}(F) = 1$, $\mathrm{size}(C) = 1 + 0 + 1 = 2$, and $\mathrm{size}(A) = 1 + 4 + 2 = 7$.

**Height.** The recurrence is the one locked in Part 1: $-1$ on `null`, and $1 + \max$ of the two children on a node. The value returned for the trace tree is $3$. The time required to obtain that value is not $3$. The next theorem separates the number being computed from the cost of computing it.

**Leaf count.**

$$
\mathrm{leaves}(\mathrm{null}) = 0
$$

$$
\mathrm{leaves}(v) = 1 \quad \text{when both children are null}
$$

$$
\mathrm{leaves}(v) = \mathrm{leaves}(\mathrm{left}(v)) + \mathrm{leaves}(\mathrm{right}(v)) \quad \text{otherwise}
$$

A node with one child contributes no leaf of its own. Its leaves are the leaves of the child that exists. The trace tree has three leaves, $D$, $G$, and $F$.

### 8.2 An exhaustive walk is linear on every shape

Call a procedure an **exhaustive walk** (a full walk of the node set) when it does $\Theta(1)$ work at each node it is called on, it is called on every subtree including the empty ones, and the work outside the recursive calls is a constant. Size, height, leaf count, and the three recursive traversals are exhaustive walks. The constant hidden by $\Theta(1)$ may include appending an element or comparing two heights. It must not include another walk.

**Theorem (exhaustive walks).** Let $T(0) = c$ and, for $n \geq 1$,

$$
T(n) = T(n_L) + T(n_R) + d,
$$

where $c > 0$, $d > 0$, and $n_L + n_R = n - 1$ with $n_L, n_R \geq 0$. Then $T(n) = (c + d)\, n + c$ for every $n \geq 0$, on every way of splitting $n$ into $n_L$ and $n_R$. In particular $T(n) = \Theta(n)$.

**Proof.** Induct on $n$. The base $n = 0$ is $T(0) = c = (c + d) \cdot 0 + c$.

Assume the closed form holds for every tree smaller than $n$. Then

$$
T(n) = \bigl((c + d)\, n_L + c\bigr) + \bigl((c + d)\, n_R + c\bigr) + d
$$

$$
= (c + d)(n_L + n_R) + 2c + d = (c + d)(n - 1) + 2c + d
$$

$$
= (c + d)\, n - c - d + 2c + d = (c + d)\, n + c.
$$

The split $n_L, n_R$ cancelled. A spine and a perfect tree of the same size have the same $T(n)$. Balance is irrelevant to this bound.

The closed form has a direct count. A binary tree of $n$ nodes has $2n$ child fields, and $n - 1$ of them point at nodes, so $n + 1$ of them are `null`. The recurrence charges $c$ for each call on `null` and $d$ for each call on a node. There are $n$ calls on nodes and $n + 1$ calls on `null` (the $n + 1$ missing children; the initial call is on the root when the tree is nonempty, and the algebra still matches because total calls are $2n + 1 = n + (n + 1)$). The cost is $d n + c(n + 1) = (c + d)\, n + c$.

Therefore size, height, leaf count, and the recursive traversals run in $\Theta(n)$ time. The extra space is the recursion depth $\Theta(h)$, plus the output when the walk builds a sequence.

Height is the example that most often gets the wrong bound. The number stored as the answer is an integer between $-1$ and $n - 1$. The work to discover it is $\Theta(n)$, because every node can change the maximum. Reading only one path would compute a depth, not the height, unless the tree is known to be perfect and the path is known to be a longest one.

### 8.3 Testing perfect and complete

**Perfect.** A binary tree is perfect when its two subtrees are perfect and have the same height. The empty tree is perfect of height $-1$. A leaf has two empty subtrees, both of height $-1$, so a leaf is perfect of height $0$. Return both facts from one walk, because the height is needed to compare the siblings and the Boolean is needed to reject a subtree that is already imperfect.

```text
perfectInfo(null) = (perfect: true, height: -1)
otherwise:
    left = perfectInfo(left child)
    right = perfectInfo(right child)
    perfect = left.perfect and right.perfect and left.height = right.height
    height = 1 + max(left.height, right.height)
```

The height line is the ordinary height recurrence, so it remains correct when `perfect` is false. On the trace tree the procedure returns perfect false and height $3$. On the perfect picture of Part 2 it returns perfect true and height $2$. On the full-and-complete tree that is not perfect, the subtree heights under the root are $1$ and $0$, so the Booleans of the subtrees can be true while the heights differ, and the root is not perfect.

The walk is exhaustive, so it is $\Theta(n)$ time and $\Theta(h)$ stack space.

**Complete.** Use the level numbering. Occupied positions are a prefix $0, 1, \ldots, n - 1$ exactly when, in the left-to-right sequence of child slots, every empty slot is followed only by empty slots. A queue can emit those slots in order. The queue holds nodes and also holds `null` for a missing child. Those `null` values are data. They are not the end of the queue. The linked queue distinguishes "the value dequeued was `null`" from "the queue has no cell left."

```text
if the root is null, the tree is complete
enqueue the root
seenNull = false
while the queue is not empty:
    dequeue x
    if x is null:
        seenNull = true
    otherwise, if seenNull is already true:
        return false
    otherwise:
        enqueue the left child of x, even if it is null
        enqueue the right child of x, even if it is null
return true
```

On the complete-but-not-full picture, the first `null` dequeued is the right child of $B$, and every slot after that one is `null`. The procedure returns true. On the "none" picture, the left child of $B$ is `null` and the right child of $B$ is $D$, so a real node appears after a `null`. The procedure returns false.

Each of the $n$ nodes is enqueued once as a node, and each node enqueues two child slots. The total number of enqueues is $1 + 2n$ when the root is counted, which is $\Theta(n)$. Each enqueue and dequeue of the linked queue is $\Theta(1)$, so the test is $\Theta(n)$ time. The queue holds $O(n)$ entries.

**Full.** A tree is full when no node has exactly one child. The check is an exhaustive walk: a node with one child returns false; a node with zero or two children returns the conjunction of the two subtrees. The empty tree is full. The cost is $\Theta(n)$.

---

## Part 9 — Reconstruction from preorder and inorder

### 9.1 Why these two sequences

Preorder names the root first and then lists the left subtree before the right subtree, but it does not say where the left subtree ends. Inorder lists every node of the left subtree, then the root, then every node of the right subtree, but it does not say which node is the root. Together, and only when the labels are distinct, each supplies the fact the other lacks.

The assumption is **distinct labels**. If a label repeats, the inorder position of the root is not unique. The two sequences `A A` as preorder and `A A` as inorder are shared by the left-child tree and the right-child tree. The laboratory program rejects a repeated label.

**Algorithm.** Build a map from each inorder label to its index. That map is $\Theta(n)$ to create and $\Theta(1)$ to query, using a JavaScript `Map`. Then:

```text
build(preStart, inStart, length):
    if length is 0, return null
    the root label is preorder[preStart]
    find its index inPos in the inorder map
    if inPos lies outside inStart .. inStart + length - 1, the sequences are not a binary tree
    leftLength = inPos - inStart
    left = build(preStart + 1, inStart, leftLength)
    right = build(preStart + 1 + leftLength, inPos + 1, length - leftLength - 1)
    return a node with that label, that left child, and that right child
```

The root of the whole tree is `build(0, 0, n)`.

Correctness is an induction on `length`. The first preorder label in the segment is the root of that segment, because preorder visits the root before either subtree. Distinct labels put that root at one inorder index. Every label to its left in the inorder segment is the left subtree, and the next `leftLength` preorder labels after the root are exactly the preorder of that subtree, because preorder finishes the left subtree before it enters the right. The remaining labels are the right subtree. The range check rejects a preorder label that does not sit in the current inorder segment, which is how inconsistent input fails instead of building a wrong tree.

### 9.2 A full trace on the trace tree

Preorder, with indexes:

```text
index:  0  1  2  3  4  5  6
label:  A  B  D  E  G  C  F
```

Inorder, with indexes:

```text
index:  0  1  2  3  4  5  6
label:  D  B  G  E  A  C  F
```

| Call `(preStart, inStart, length)` | Root | `inPos` | Left length | Left call | Right call |
| --- | --- | --- | --- | --- | --- |
| $(0, 0, 7)$ | $A$ | $4$ | $4$ | $(1, 0, 4)$ | $(5, 5, 2)$ |
| $(1, 0, 4)$ | $B$ | $1$ | $1$ | $(2, 0, 1)$ | $(3, 2, 2)$ |
| $(2, 0, 1)$ | $D$ | $0$ | $0$ | empty | empty |
| $(3, 2, 2)$ | $E$ | $3$ | $1$ | $(4, 2, 1)$ | $(5, 4, 0)$ empty |
| $(4, 2, 1)$ | $G$ | $2$ | $0$ | empty | empty |
| $(5, 5, 2)$ | $C$ | $5$ | $0$ | empty | $(6, 6, 1)$ |
| $(6, 6, 1)$ | $F$ | $6$ | $0$ | empty | empty |

Read the row for $A$. Its inorder index is $4$, so the left subtree has the four inorder labels $D, B, G, E$ and the next four preorder labels $B, D, E, G$. The right subtree has inorder $C, F$ and preorder $C, F$.

The row for $E$ is the one that is easy to mis-count. Its right call is $(5, 4, 0)$. The length is $0$, so the call returns `null` and does not consume preorder index $5$. The right subtree of $A$ starts at preorder index $5$ with a different inorder window, $(5, 5, 2)$. The same preorder index appears in two rows, and only the row whose length is positive consumes it.

The nodes created are $A$ with children $B$ and $C$, $B$ with children $D$ and $E$, $E$ with left child $G$, and $C$ with right child $F$. That is the trace tree. Its postorder is $D, G, E, B, F, C, A$, which matches Part 6. The laboratory program rebuilds the tree from these two arrays and checks the shape, not only one of the input sequences. Checking only the preorder of the result would pass for a wrong tree that happened to share that preorder.

### 9.3 One sequence is not enough, and preorder plus postorder is not enough

Inorder alone does not name the root. The inorder sequence $A, B$ is the inorder of a root $A$ with a right child $B$, and it is also the inorder of a root $B$ with a left child $A$.

Preorder alone does not split the children. The preorder sequence $A, B$ is the preorder of both two-node trees drawn in Part 2.

Postorder has the same ambiguity. Both of those trees have postorder $B, A$.

**Counterexample (preorder plus postorder).** The left-child tree and the right-child tree below have the same preorder and the same postorder.

```text
   A          A
  /            \
 B              B
```

| Tree | Preorder | Inorder | Postorder |
| --- | --- | --- | --- |
| Left child | $A, B$ | $B, A$ | $B, A$ |
| Right child | $A, B$ | $A, B$ | $B, A$ |

Preorder plus postorder does not determine a unique binary tree. The missing fact is which side the single child occupies. This lecture does not claim that the pair always suffices, and it does not develop a reconstruction from that pair. If a problem also states that the tree is full, a single child cannot occur, and the two-node ambiguity disappears. That extra promise is not assumed here.

The inorder sequence is what records the side. In the table, the two trees disagree in inorder and agree in the other two orders. That is why the algorithm of this part asks for preorder and inorder rather than for preorder and postorder.

### 9.4 Running time

With the label-to-index map, each call does $\Theta(1)$ work besides the recursive calls and allocates one node. There are $n$ nodes and $n + 1$ empty calls, the same shape as an exhaustive walk, so the construction is $\Theta(n)$ time after the $\Theta(n)$ map is built. The stack depth is $\Theta(h)$.

Without the map, a call that scans its inorder segment from one end to find the root costs time linear in the length of that segment. A left spine makes the root the last label of the segment at every level. Preorder of a left spine $A, B, C, D$ is $A, B, C, D$. Inorder is $D, C, B, A$. Each segment search walks the whole remaining segment, the lengths are $n, n - 1, \ldots, 1$, and the total is $\Theta(n^{2})$. A right spine is the cheap case for that scan, because the root is the first inorder label. The worst-case cost of the scanning version is $\Theta(n^{2})$. The laboratory program is the map version, and its cost comment is $\Theta(n)$.

An inconsistent pair such as preorder $A, B, C$ and inorder $C, A, B$ fails the range check. The root $A$ has inorder index $1$, so the left segment is the single label $C$, but the next preorder label is $B$, which is not inside that segment. The program throws. It does not invent a tree.

---

## Laboratory

The traces above are the ones the program checks. Work the four problems after the checklist, then read the program. The problems are not answered in this section.

### Guided traces the program checks

Trace tree, height $3$, size $7$, six edges, three leaves. Depth of $G$ is $3$. Height of $E$ is $1$, of $B$ is $2$, of $C$ is $1$. Parent of $G$ is $E$.

| Check | Value |
| --- | --- |
| Preorder, recursive and explicit stack | $A, B, D, E, G, C, F$ |
| Inorder, recursive and explicit stack | $D, B, G, E, A, C, F$ |
| Postorder, recursive and two stacks | $D, G, E, B, F, C, A$ |
| Level order | $A, B, C, D, E, F, G$ |
| Reconstruction from that preorder and that inorder | the same shape, the same four sequences, height $3$, size $7$ |

Expression tree: fully parenthesized inorder `(((3 + 5) * 2) - (8 / 4))`, postfix `3 5 + 2 * 8 4 / -`, value $14$ by the recursive fold and by the postfix stack.

Also checked, from the same definitions: empty height $-1$; a single node has height $0$ and depth $0$; the perfect tree of height $2$ has $7$ nodes; a right spine of $4$ nodes has height $3$; the shape pictures of Part 2 classify as stated; parent and child indexes on the perfect array; the two-node preorder-plus-postorder collision; division by zero and a non-integer quotient.

### Problems

Do these on paper before you read the program. They use the definitions, on new pictures.

1. Draw the tree with root $P$, left child $Q$, right child $R$, left child $S$ of $Q$, and children $T$ and $U$ of $R$. Write the four traversal sequences and the height. Say whether the tree is full, perfect, or complete.

2. Build the expression tree for $(9 + 4) - 3$, with the subtraction at the root. Write the fully parenthesized inorder string, the postfix string, and the value, showing the fold.

3. Reconstruct the tree with preorder $K, M, J, L$ and inorder $J, M, L, K$. Draw it and write its postorder.

4. How many nodes does a perfect binary tree of height $3$ have? What is the height of a skewed binary tree with that many nodes?

## LABORATORY PROGRAM

```javascript
import assert from "node:assert/strict";

class TreeNode {
  constructor(element, left = null, right = null) {
    this.element = element;
    this.left = null;
    this.right = null;
    this.parent = null;
    if (left !== null) {
      this.setLeft(left);
    }
    if (right !== null) {
      this.setRight(right);
    }
  }

  setLeft(child) {
    this.attach("left", child);
  }

  setRight(child) {
    this.attach("right", child);
  }

  attach(side, child) {
    if (side !== "left" && side !== "right") {
      throw new Error("side");
    }
    if (child !== null) {
      if (child === this) {
        throw new Error("cycle");
      }
      let cursor = this.parent;
      while (cursor !== null) {
        if (cursor === child) {
          throw new Error("cycle");
        }
        cursor = cursor.parent;
      }
      if (child.parent !== null && child.parent !== this) {
        throw new Error("node already has a parent");
      }
    }
    const previous = this[side];
    if (previous === child) {
      return;
    }
    if (previous !== null) {
      previous.parent = null;
    }
    this[side] = child;
    if (child !== null) {
      child.parent = this;
    }
  }
}

class Queue {
  constructor() {
    this.head = null;
    this.tail = null;
    this.length = 0;
  }

  enqueue(value) {
    const node = { value, next: null };
    if (this.tail === null) {
      this.head = node;
      this.tail = node;
    } else {
      this.tail.next = node;
      this.tail = node;
    }
    this.length += 1;
  }

  dequeue() {
    if (this.length === 0) {
      throw new Error("empty queue");
    }
    const value = this.head.value;
    this.head = this.head.next;
    if (this.head === null) {
      this.tail = null;
    }
    this.length -= 1;
    return value;
  }

  isEmpty() {
    return this.length === 0;
  }
}

class BinaryTree {
  constructor(root = null) {
    this.root = root;
  }

  isEmpty() {
    return this.root === null;
  }

  size() {
    return sizeOf(this.root);
  }

  height() {
    return heightOf(this.root);
  }

  leafCount() {
    return leafCountOf(this.root);
  }

  preorder() {
    const out = [];
    preorderWalk(this.root, out);
    return out;
  }

  inorder() {
    const out = [];
    inorderWalk(this.root, out);
    return out;
  }

  postorder() {
    const out = [];
    postorderWalk(this.root, out);
    return out;
  }

  levelOrder() {
    return levelOrderOf(this.root);
  }

  preorderIterative() {
    return preorderIterativeOf(this.root);
  }

  inorderIterative() {
    return inorderIterativeOf(this.root);
  }

  postorderIterative() {
    return postorderIterativeOf(this.root);
  }

  isFull() {
    return isFullTree(this.root);
  }

  isPerfect() {
    return perfectInfo(this.root).perfect;
  }

  isComplete() {
    return isCompleteTree(this.root);
  }
}

function sizeOf(node) {
  if (node === null) {
    return 0;
  }
  return 1 + sizeOf(node.left) + sizeOf(node.right);
}

function heightOf(node) {
  if (node === null) {
    return -1;
  }
  return 1 + Math.max(heightOf(node.left), heightOf(node.right));
}

function leafCountOf(node) {
  if (node === null) {
    return 0;
  }
  if (node.left === null && node.right === null) {
    return 1;
  }
  return leafCountOf(node.left) + leafCountOf(node.right);
}

function preorderWalk(node, out) {
  if (node === null) {
    return;
  }
  out.push(node.element);
  preorderWalk(node.left, out);
  preorderWalk(node.right, out);
}

function inorderWalk(node, out) {
  if (node === null) {
    return;
  }
  inorderWalk(node.left, out);
  out.push(node.element);
  inorderWalk(node.right, out);
}

function postorderWalk(node, out) {
  if (node === null) {
    return;
  }
  postorderWalk(node.left, out);
  postorderWalk(node.right, out);
  out.push(node.element);
}

function preorderIterativeOf(root) {
  const out = [];
  if (root === null) {
    return out;
  }
  const stack = [root];
  while (stack.length > 0) {
    const node = stack.pop();
    out.push(node.element);
    if (node.right !== null) {
      stack.push(node.right);
    }
    if (node.left !== null) {
      stack.push(node.left);
    }
  }
  return out;
}

function inorderIterativeOf(root) {
  const out = [];
  const stack = [];
  let node = root;
  while (stack.length > 0 || node !== null) {
    while (node !== null) {
      stack.push(node);
      node = node.left;
    }
    node = stack.pop();
    out.push(node.element);
    node = node.right;
  }
  return out;
}

function postorderIterativeOf(root) {
  const out = [];
  if (root === null) {
    return out;
  }
  const first = [root];
  const second = [];
  while (first.length > 0) {
    const node = first.pop();
    second.push(node);
    if (node.left !== null) {
      first.push(node.left);
    }
    if (node.right !== null) {
      first.push(node.right);
    }
  }
  while (second.length > 0) {
    out.push(second.pop().element);
  }
  return out;
}

function levelOrderOf(root) {
  const out = [];
  if (root === null) {
    return out;
  }
  const queue = new Queue();
  queue.enqueue(root);
  while (!queue.isEmpty()) {
    const node = queue.dequeue();
    out.push(node.element);
    if (node.left !== null) {
      queue.enqueue(node.left);
    }
    if (node.right !== null) {
      queue.enqueue(node.right);
    }
  }
  return out;
}

function isFullTree(node) {
  if (node === null) {
    return true;
  }
  const children = (node.left === null ? 0 : 1) + (node.right === null ? 0 : 1);
  if (children === 1) {
    return false;
  }
  return isFullTree(node.left) && isFullTree(node.right);
}

function perfectInfo(node) {
  if (node === null) {
    return { perfect: true, height: -1 };
  }
  const left = perfectInfo(node.left);
  const right = perfectInfo(node.right);
  return {
    perfect: left.perfect && right.perfect && left.height === right.height,
    height: 1 + Math.max(left.height, right.height),
  };
}

function isCompleteTree(root) {
  if (root === null) {
    return true;
  }
  const queue = new Queue();
  queue.enqueue(root);
  let seenNull = false;
  while (!queue.isEmpty()) {
    const node = queue.dequeue();
    if (node === null) {
      seenNull = true;
    } else if (seenNull) {
      return false;
    } else {
      queue.enqueue(node.left);
      queue.enqueue(node.right);
    }
  }
  return true;
}

function depthOf(node) {
  let depth = 0;
  let current = node;
  while (current.parent !== null) {
    current = current.parent;
    depth += 1;
  }
  return depth;
}

function edgeCount(node) {
  if (node === null) {
    return 0;
  }
  const leftEdges = node.left === null ? 0 : 1 + edgeCount(node.left);
  const rightEdges = node.right === null ? 0 : 1 + edgeCount(node.right);
  return leftEdges + rightEdges;
}

function parentIndex(i) {
  if (!Number.isInteger(i) || i <= 0) {
    throw new Error("no parent");
  }
  return Math.floor((i - 1) / 2);
}

function leftIndex(i) {
  if (!Number.isInteger(i) || i < 0) {
    throw new Error("index");
  }
  return 2 * i + 1;
}

function rightIndex(i) {
  if (!Number.isInteger(i) || i < 0) {
    throw new Error("index");
  }
  return 2 * i + 2;
}

function perfectNodeCount(height) {
  if (!Number.isInteger(height) || height < -1 || height > 52) {
    throw new Error("height out of range for a safe integer count");
  }
  return 2 ** (height + 1) - 1;
}

function applyOperator(operator, left, right) {
  let value;
  if (operator === "+") {
    value = left + right;
  } else if (operator === "-") {
    value = left - right;
  } else if (operator === "*") {
    value = left * right;
  } else if (operator === "/") {
    if (right === 0) {
      throw new Error("division by zero");
    }
    value = left / right;
  } else {
    throw new Error("unknown operator");
  }
  if (!Number.isSafeInteger(value)) {
    throw new Error("result is not a safe integer");
  }
  return value;
}

function evaluate(node) {
  if (node === null) {
    throw new Error("empty expression");
  }
  if (node.left === null && node.right === null) {
    if (!Number.isSafeInteger(node.element)) {
      throw new Error("operand must be a safe integer");
    }
    return node.element;
  }
  if (node.left === null || node.right === null) {
    throw new Error("operator needs two operands");
  }
  const left = evaluate(node.left);
  const right = evaluate(node.right);
  return applyOperator(node.element, left, right);
}

function toInfix(node) {
  if (node === null) {
    throw new Error("empty expression");
  }
  if (node.left === null && node.right === null) {
    return String(node.element);
  }
  if (node.left === null || node.right === null) {
    throw new Error("operator needs two operands");
  }
  return "(" + toInfix(node.left) + " " + node.element + " " + toInfix(node.right) + ")";
}

function toPostfix(node) {
  if (node === null) {
    throw new Error("empty expression");
  }
  if (node.left === null && node.right === null) {
    return String(node.element);
  }
  if (node.left === null || node.right === null) {
    throw new Error("operator needs two operands");
  }
  return toPostfix(node.left) + " " + toPostfix(node.right) + " " + node.element;
}

function evaluatePostfix(tokens) {
  const stack = [];
  for (const token of tokens) {
    if (typeof token === "number") {
      if (!Number.isSafeInteger(token)) {
        throw new Error("operand must be a safe integer");
      }
      stack.push(token);
    } else {
      if (stack.length < 2) {
        throw new Error("malformed postfix");
      }
      const right = stack.pop();
      const left = stack.pop();
      stack.push(applyOperator(token, left, right));
    }
  }
  if (stack.length !== 1) {
    throw new Error("malformed postfix");
  }
  return stack[0];
}

function reconstruct(preorder, inorder) {
  if (preorder.length !== inorder.length) {
    throw new Error("length mismatch");
  }
  const index = new Map();
  for (let i = 0; i < inorder.length; i += 1) {
    if (index.has(inorder[i])) {
      throw new Error("duplicate label");
    }
    index.set(inorder[i], i);
  }
  for (const label of preorder) {
    if (!index.has(label)) {
      throw new Error("label missing from inorder");
    }
  }

  function build(preStart, inStart, length) {
    if (length === 0) {
      return null;
    }
    const label = preorder[preStart];
    const inPos = index.get(label);
    if (inPos < inStart || inPos >= inStart + length) {
      throw new Error("preorder label outside inorder range");
    }
    const leftLength = inPos - inStart;
    const left = build(preStart + 1, inStart, leftLength);
    const right = build(preStart + 1 + leftLength, inPos + 1, length - leftLength - 1);
    return new TreeNode(label, left, right);
  }

  return new BinaryTree(build(0, 0, preorder.length));
}

function shapeOf(tree) {
  const lines = [];
  function walk(node) {
    if (node === null) {
      return;
    }
    const left = node.left === null ? "-" : node.left.element;
    const right = node.right === null ? "-" : node.right.element;
    lines.push(node.element + ":" + left + "," + right);
    walk(node.left);
    walk(node.right);
  }
  walk(tree.root);
  return lines;
}

function traceTree() {
  return new BinaryTree(
    new TreeNode(
      "A",
      new TreeNode(
        "B",
        new TreeNode("D"),
        new TreeNode("E", new TreeNode("G"), null),
      ),
      new TreeNode("C", null, new TreeNode("F")),
    ),
  );
}

function perfectTree() {
  return new BinaryTree(
    new TreeNode(
      "A",
      new TreeNode("B", new TreeNode("D"), new TreeNode("E")),
      new TreeNode("C", new TreeNode("F"), new TreeNode("G")),
    ),
  );
}

function fullNotPerfect() {
  return new BinaryTree(
    new TreeNode(
      "A",
      new TreeNode(
        "B",
        new TreeNode("D"),
        new TreeNode("E", new TreeNode("F"), new TreeNode("G")),
      ),
      new TreeNode("C"),
    ),
  );
}

function completeNotFull() {
  return new BinaryTree(
    new TreeNode(
      "A",
      new TreeNode("B", new TreeNode("D"), null),
      new TreeNode("C"),
    ),
  );
}

function noneOfTheThree() {
  return new BinaryTree(
    new TreeNode(
      "A",
      new TreeNode("B", null, new TreeNode("D")),
      new TreeNode("C"),
    ),
  );
}

function fullAndCompleteNotPerfect() {
  return new BinaryTree(
    new TreeNode(
      "A",
      new TreeNode("B", new TreeNode("D"), new TreeNode("E")),
      new TreeNode("C"),
    ),
  );
}

function rightSpine(labels) {
  let node = null;
  for (let i = labels.length - 1; i >= 0; i -= 1) {
    node = new TreeNode(labels[i], null, node);
  }
  return new BinaryTree(node);
}

function expressionTree() {
  return new BinaryTree(
    new TreeNode(
      "-",
      new TreeNode(
        "*",
        new TreeNode("+", new TreeNode(3), new TreeNode(5)),
        new TreeNode(2),
      ),
      new TreeNode("/", new TreeNode(8), new TreeNode(4)),
    ),
  );
}

const empty = new BinaryTree(null);
assert.strictEqual(empty.height(), -1);
assert.strictEqual(empty.size(), 0);
assert.strictEqual(empty.leafCount(), 0);
assert.deepStrictEqual(empty.preorder(), []);
assert.deepStrictEqual(empty.inorder(), []);
assert.deepStrictEqual(empty.postorder(), []);
assert.deepStrictEqual(empty.levelOrder(), []);
assert.strictEqual(empty.isFull(), true);
assert.strictEqual(empty.isPerfect(), true);
assert.strictEqual(empty.isComplete(), true);
assert.strictEqual(perfectNodeCount(-1), 0);

const single = new BinaryTree(new TreeNode("X"));
assert.strictEqual(single.height(), 0);
assert.strictEqual(single.size(), 1);
assert.strictEqual(depthOf(single.root), 0);
assert.strictEqual(single.leafCount(), 1);
assert.deepStrictEqual(single.preorder(), ["X"]);
assert.deepStrictEqual(single.inorder(), ["X"]);
assert.deepStrictEqual(single.postorder(), ["X"]);
assert.deepStrictEqual(single.levelOrder(), ["X"]);
assert.strictEqual(single.isFull(), true);
assert.strictEqual(single.isPerfect(), true);
assert.strictEqual(single.isComplete(), true);
assert.strictEqual(perfectNodeCount(0), 1);

const traced = traceTree();
assert.strictEqual(traced.size(), 7);
assert.strictEqual(traced.height(), 3);
assert.strictEqual(edgeCount(traced.root), 6);
assert.strictEqual(traced.leafCount(), 3);
assert.strictEqual(heightOf(traced.root), 3);
assert.strictEqual(heightOf(traced.root.left), 2);
assert.strictEqual(heightOf(traced.root.left.left), 0);
assert.strictEqual(heightOf(traced.root.left.right), 1);
assert.strictEqual(heightOf(traced.root.left.right.left), 0);
assert.strictEqual(heightOf(traced.root.right), 1);
assert.strictEqual(heightOf(traced.root.right.right), 0);
assert.strictEqual(depthOf(traced.root), 0);
assert.strictEqual(depthOf(traced.root.left), 1);
assert.strictEqual(depthOf(traced.root.right), 1);
assert.strictEqual(depthOf(traced.root.left.left), 2);
assert.strictEqual(depthOf(traced.root.left.right), 2);
assert.strictEqual(depthOf(traced.root.left.right.left), 3);
assert.strictEqual(depthOf(traced.root.right.right), 2);
assert.strictEqual(traced.root.left.right.left.parent.element, "E");
assert.strictEqual(traced.root.parent, null);

const preorder = ["A", "B", "D", "E", "G", "C", "F"];
const inorder = ["D", "B", "G", "E", "A", "C", "F"];
const postorder = ["D", "G", "E", "B", "F", "C", "A"];
const levelOrder = ["A", "B", "C", "D", "E", "F", "G"];
assert.deepStrictEqual(traced.preorder(), preorder);
assert.deepStrictEqual(traced.preorderIterative(), preorder);
assert.deepStrictEqual(traced.inorder(), inorder);
assert.deepStrictEqual(traced.inorderIterative(), inorder);
assert.deepStrictEqual(traced.postorder(), postorder);
assert.deepStrictEqual(traced.postorderIterative(), postorder);
assert.deepStrictEqual(traced.levelOrder(), levelOrder);
assert.strictEqual(traced.isFull(), false);
assert.strictEqual(traced.isPerfect(), false);
assert.strictEqual(traced.isComplete(), false);

const rebuilt = reconstruct(preorder, inorder);
assert.deepStrictEqual(rebuilt.preorder(), preorder);
assert.deepStrictEqual(rebuilt.inorder(), inorder);
assert.deepStrictEqual(rebuilt.postorder(), postorder);
assert.deepStrictEqual(rebuilt.levelOrder(), levelOrder);
assert.deepStrictEqual(shapeOf(rebuilt), shapeOf(traced));
assert.strictEqual(rebuilt.height(), 3);
assert.strictEqual(rebuilt.size(), 7);

assert.throws(
  () => reconstruct(["A", "B", "C"], ["C", "A", "B"]),
  /preorder label outside inorder range/,
);
assert.throws(() => reconstruct(["A", "A"], ["A", "A"]), /duplicate label/);
assert.throws(() => reconstruct(["A"], ["A", "B"]), /length mismatch/);
assert.throws(() => reconstruct(["A", "B"], ["A", "C"]), /label missing from inorder/);

const leftChild = new BinaryTree(new TreeNode("A", new TreeNode("B"), null));
const rightChild = new BinaryTree(new TreeNode("A", null, new TreeNode("B")));
assert.deepStrictEqual(leftChild.preorder(), ["A", "B"]);
assert.deepStrictEqual(rightChild.preorder(), ["A", "B"]);
assert.deepStrictEqual(leftChild.postorder(), ["B", "A"]);
assert.deepStrictEqual(rightChild.postorder(), ["B", "A"]);
assert.deepStrictEqual(leftChild.inorder(), ["B", "A"]);
assert.deepStrictEqual(rightChild.inorder(), ["A", "B"]);
assert.strictEqual(leftChild.root.left.element, "B");
assert.strictEqual(leftChild.root.right, null);
assert.strictEqual(rightChild.root.left, null);
assert.strictEqual(rightChild.root.right.element, "B");

const perfect = perfectTree();
assert.strictEqual(perfect.size(), 7);
assert.strictEqual(perfect.height(), 2);
assert.strictEqual(perfect.leafCount(), 4);
assert.strictEqual(perfectNodeCount(2), 7);
assert.strictEqual(perfectNodeCount(perfect.height()), perfect.size());
assert.strictEqual(perfect.isFull(), true);
assert.strictEqual(perfect.isPerfect(), true);
assert.strictEqual(perfect.isComplete(), true);
assert.deepStrictEqual(perfect.levelOrder(), ["A", "B", "C", "D", "E", "F", "G"]);
assert.strictEqual(parentIndex(4), 1);
assert.strictEqual(leftIndex(1), 3);
assert.strictEqual(rightIndex(1), 4);
assert.strictEqual(leftIndex(2), 5);
assert.strictEqual(rightIndex(2), 6);
assert.strictEqual(parentIndex(6), 2);
assert.strictEqual(parentIndex(3), 1);
assert.throws(() => parentIndex(0), /no parent/);

const fullOnly = fullNotPerfect();
assert.strictEqual(fullOnly.isFull(), true);
assert.strictEqual(fullOnly.isPerfect(), false);
assert.strictEqual(fullOnly.isComplete(), false);
assert.strictEqual(fullOnly.height(), 3);

const completeOnly = completeNotFull();
assert.strictEqual(completeOnly.isFull(), false);
assert.strictEqual(completeOnly.isPerfect(), false);
assert.strictEqual(completeOnly.isComplete(), true);
assert.strictEqual(completeOnly.height(), 2);
assert.strictEqual(completeOnly.size(), 4);

const none = noneOfTheThree();
assert.strictEqual(none.isFull(), false);
assert.strictEqual(none.isPerfect(), false);
assert.strictEqual(none.isComplete(), false);

const bothNotPerfect = fullAndCompleteNotPerfect();
assert.strictEqual(bothNotPerfect.isFull(), true);
assert.strictEqual(bothNotPerfect.isComplete(), true);
assert.strictEqual(bothNotPerfect.isPerfect(), false);
assert.strictEqual(bothNotPerfect.height(), 2);
assert.strictEqual(bothNotPerfect.size(), 5);

const spine = rightSpine(["A", "B", "C", "D"]);
assert.strictEqual(spine.size(), 4);
assert.strictEqual(spine.height(), 3);
assert.deepStrictEqual(spine.preorder(), ["A", "B", "C", "D"]);
assert.deepStrictEqual(spine.inorder(), ["A", "B", "C", "D"]);
assert.deepStrictEqual(spine.postorder(), ["D", "C", "B", "A"]);
assert.strictEqual(spine.height(), spine.size() - 1);

assert.strictEqual(perfectNodeCount(3), 15);
assert.strictEqual(perfectNodeCount(4), 31);
assert.strictEqual(perfectNodeCount(52), 2 ** 53 - 1);
assert.throws(() => perfectNodeCount(53), /height out of range/);

const expression = expressionTree();
assert.strictEqual(evaluate(expression.root), 14);
assert.strictEqual(toInfix(expression.root), "(((3 + 5) * 2) - (8 / 4))");
assert.strictEqual(toPostfix(expression.root), "3 5 + 2 * 8 4 / -");
assert.deepStrictEqual(expression.inorder(), [3, "+", 5, "*", 2, "-", 8, "/", 4]);
assert.deepStrictEqual(expression.postorder(), [3, 5, "+", 2, "*", 8, 4, "/", "-"]);
assert.strictEqual(
  evaluatePostfix([3, 5, "+", 2, "*", 8, 4, "/", "-"]),
  14,
);

const dividedByZero = new TreeNode("/", new TreeNode(1), new TreeNode(0));
assert.throws(() => evaluate(dividedByZero), /division by zero/);
const half = new TreeNode("/", new TreeNode(1), new TreeNode(2));
assert.throws(() => evaluate(half), /result is not a safe integer/);

const parentDemo = new TreeNode("A", new TreeNode("B"), null);
const extra = new TreeNode("C");
parentDemo.left.setRight(extra);
assert.strictEqual(extra.parent.element, "B");
assert.strictEqual(parentDemo.left.right.element, "C");
assert.throws(() => parentDemo.setLeft(extra), /node already has a parent/);
assert.throws(() => parentDemo.left.setLeft(parentDemo), /cycle/);

const info = perfectInfo(perfect.root);
assert.strictEqual(info.perfect, true);
assert.strictEqual(info.height, 2);
const tracedInfo = perfectInfo(traced.root);
assert.strictEqual(tracedInfo.perfect, false);
assert.strictEqual(tracedInfo.height, 3);

console.log("ALL TESTS PASSED");
```

Copy the program into a file and run it with Node. On success it prints `ALL TESTS PASSED` and nothing else. An assertion failure throws. Change one expected sequence, confirm that the run throws, and restore it. The program does not read the network, the filesystem, or `process.argv`.

---

## Common mistakes

**Leaf height $1$, or empty height $0$.** The wrong idea is that height counts nodes, so a single node has height $1$ and a missing child has height $0$. The correction is the locked convention: a missing subtree has height $-1$, a leaf has height $0$, and the root has depth $0$. Under the wrong convention the perfect-tree formula and the later balance factor both shift by one.

**Using $n = 2^{h} - 1$ with this course's $h$.** The wrong idea imports a formula from a book that counts levels, or that gives a leaf height $1$, and pairs it with edge-count height. The correction is $n = 2^{h+1} - 1$. For $h = 2$ that is $7$, not $3$.

**Treating full, complete, and perfect as synonyms.** The wrong idea is that "every level looks full" is one property with three names. The correction is the three definitions in Part 2. A tree can be full and complete and still have leaves at two depths, so it is not perfect. A node with only a right child is none of the three.

**One-based index formulas on a zero-based array.** The wrong idea computes the parent of $i$ as $\lfloor i / 2 \rfloor$ and the children as $2i$ and $2i + 1$ while the root sits at index $0$. The correction is parent $\lfloor (i - 1) / 2 \rfloor$, left child $2i + 1$, right child $2i + 2$. On the perfect array, the parent of index $4$ is $1$, not $2$.

**Pushing the left child before the right child in explicit preorder.** The wrong idea follows the phrase "left then right" as the push order. A stack reverses that order. Push the right child, then the left child, so the left child is popped next.

**Calling `Array.prototype.shift` a constant-time dequeue.** The wrong idea treats every method of a JavaScript array as $\Theta(1)$. Shifting a dense array moves the later elements. $n$ dequeues of that kind are $\Theta(n^{2})$. Level order in this lecture uses a linked queue with a head and a tail.

**Believing preorder plus postorder always determines the tree.** The wrong idea is that two different orders are always enough. The left-child tree and the right-child tree on $\{A, B\}$ share preorder $A, B$ and postorder $B, A$. Inorder is what records the side.

**Printing inorder without parentheses and calling it the expression.** The wrong idea is that the visit order already contains the shape. The raw inorder of the worked expression is `3 + 5 * 2 - 8 / 4`, which ordinary precedence evaluates as $11$. The tree's value is $14$. The fully parenthesized form is the print that matches the tree.

**Popping the left operand first in postfix evaluation.** The wrong idea is that the first pop is the left operand because the left operand was pushed first. The first pop is the right operand. At the root of the worked example the wrong pop computes $2 - 16 = -14$ instead of $16 - 2 = 14$.

**Bounding a traversal by the height.** The wrong idea is that a short tree makes every tree algorithm $\Theta(\log n)$. An exhaustive walk visits every node, so it is $\Theta(n)$ on a perfect tree and on a spine. The height bounds the stack depth, not the number of visits.

**Returning $0$ for the height of `null`.** The wrong idea writes the leaf base case on the missing child. A leaf then has height $1 + \max(0, 0) = 1$, and every later formula that subtracts heights is off by the same shift. Return $-1$ for `null` and let the leaf fall out as $0$.

**Reconstructing when a label repeats.** The wrong idea takes the first match in the inorder array and continues. Two nodes labeled $A$ make the root's inorder index ambiguous. The algorithm of this lecture requires distinct labels and rejects a duplicate.

---

## Examination

Closed notes. Ninety minutes is an appropriate limit. Write full solutions. Do not read the answer key until you have attempted every item.

The height convention of the lecture is in force: the empty tree has height $-1$, a leaf has height $0$, and the root has depth $0$. $\log$ is base $2$.

**1.** State the height of the empty tree, the height of a leaf, and the depth of the root. Define the depth of a non-root node and the height of a node that has children. Write the recurrence that uses the empty-tree value, and apply it to a leaf to show that the value returned is $0$.

**2.** Define, as this lecture uses the words: parent, child, root, leaf, internal node, edge, downward path, ancestor, proper descendant, subtree, and degree. State how this degree differs from the graph degree used in Lecture 12.

**3.** Prove that in a nonempty rooted tree the height of the root equals the maximum depth of a node. State why the empty tree is excluded from the claim.

**4.** For each tree, say whether it is full, whether it is perfect, and whether it is complete. Justify each negative answer in one sentence.

```text
(a)       (b)       (c)       (d)
  4         4         4         4
 / \       / \       / \       / \
2   7     2   7     2   7     2   7
/ \       / \ / \   /           \
1  3     1  3 6  8 1             3
```

**5.** State the number of nodes in a perfect binary tree of height $h$, and prove the formula by induction on $h$. Then compute, for $h = 4$, the number of nodes, the number of leaves, and the number of internal nodes. For a binary tree of $1000$ nodes, give the minimum possible height and the maximum possible height. Show the powers of two you use for the minimum.

**6.** On the tree below, give the depth of $E$, the height of $H$, the height of the tree, and the preorder, inorder, postorder, and level-order sequences.

```text
        M
       / \
      H   T
     / \ /
    C   K R
     \
      E
```

**7.** On the expression tree below, write the fully parenthesized inorder string, the postfix string, and the value. Show every arithmetic step of the postorder fold. State which traversal the evaluation is.

```text
       *
      / \
     +   -
    / \ / \
   7   1 8  3
```

**8.** Reconstruct the binary tree with preorder $F, B, A, D, C, E, G, I, H$ and inorder $A, B, C, D, E, F, G, H, I$. Draw the tree and write its postorder. Then explain why both sequences are used. Include the two-node counterexample that shows preorder plus postorder does not determine a unique binary tree.

**9.** A complete binary tree is stored in a 0-based array of length $20$, so the legal indexes are $0$ through $19$. For index $6$ and for index $11$, give the parent index and the left and right child indexes. Say whether each child exists.

**10.** Give the running time and the extra space of each of the following. Name the shape that forces the last reconstruction to take $\Theta(n^{2})$ time. Separately, state the space cost of an optional parent pointer and the query that becomes $\Theta(1)$ when the pointer is stored.

- Computing the height of a binary tree of $n$ nodes.
- Level order.
- Reconstruction from preorder and inorder using a label-to-index map.
- Reconstruction that finds the root by scanning the current inorder segment at every call.

---

## Answer key

**1.** The empty tree has height $-1$. A leaf has height $0$. The root has depth $0$. The depth of a non-root node is the depth of its parent plus $1$, which is the number of edges from the root to the node. The height of a node with children is $1$ plus the maximum height of a child. The recurrence is $\mathrm{height}(\mathrm{null}) = -1$ and $\mathrm{height}(v) = 1 + \max(\mathrm{height}(\mathrm{left}), \mathrm{height}(\mathrm{right}))$. A leaf has two missing children, so its height is $1 + \max(-1, -1) = 1 + (-1) = 0$.

**2.** The parent of a non-root node is the unique node that points to it along the parent relation; the root has none. A child of $u$ is a node whose parent is $u$. The root is the unique node with no parent. A leaf is a node with no children. An internal node is a node that is not a leaf. An edge joins a parent to one child. A downward path is a sequence of nodes in which each step goes to a child. An ancestor of $v$ lies on the path from the root to $v$, including $v$. A proper descendant of $u$ is a descendant other than $u$ itself. The subtree rooted at $v$ contains $v$ and all of its descendants. The degree of a node is the number of children. Lecture 12's graph degree also counts the edge to the parent, so a non-root leaf has graph degree $1$ and rooted degree $0$.

**3.** Induct on $n$, the number of nodes. If $n = 1$, the root is a leaf, its height is $0$, and its depth is $0$. If $n > 1$, the root has $k \geq 1$ nonempty subtrees, each smaller than $n$. By the inductive hypothesis the height $h_i$ of subtree $i$ equals the maximum depth inside that subtree, measured from the subtree root, and $h_i \geq 0$. The height of the whole tree is $1 + \max_i h_i$. A node at depth $d$ inside subtree $i$ has depth $d + 1$ in the whole tree, and the root has depth $0$, so the maximum depth is $\max(0, 1 + \max_i h_i) = 1 + \max_i h_i$. The empty tree is excluded because its height is $-1$ and it contains no node whose depth could be maximized.

**4.** (a) Full: every node has $0$ or $2$ children. Not perfect: the leaf $7$ is at depth $1$, while $1$ and $3$ are at depth $2$. Complete: levels $0$ and $1$ are full, and the last level holds the leftmost positions. (b) Full, perfect, and complete: every internal node has two children, every leaf is at depth $2$, and every level is full. Height $2$, and $2^{3} - 1 = 7$ nodes. (c) Not full: node $2$ has one child. Not perfect: leaves occur at depth $1$ and depth $2$. Complete: the only node on the last level is the leftmost child. (d) Not full and not perfect: node $2$ has one child. Not complete: that child is a right child, so the last level is not filled from the left.

**5.** The formula is $n = 2^{h+1} - 1$ for height $h \geq 0$. Base $h = 0$: one node, and $2^{1} - 1 = 1$. Assume height $h - 1$ has $2^{h} - 1$ nodes. Height $h$ is a root plus two such subtrees, so $n = 1 + 2(2^{h} - 1) = 1 + 2^{h+1} - 2 = 2^{h+1} - 1$.

For $h = 4$, $n = 2^{5} - 1 = 32 - 1 = 31$. Leaves are the last level, $2^{4} = 16$. Internal nodes are $31 - 16 = 15$, which is also $2^{4} - 1$.

A binary tree of $1000$ nodes has maximum height $1000 - 1 = 999$, the spine. The minimum is the complete height. A perfect tree of height $8$ has $2^{9} - 1 = 512 - 1 = 511$ nodes, and $511 < 1000$, so height $8$ is impossible. A perfect tree of height $9$ has $2^{10} - 1 = 1024 - 1 = 1023$ nodes, and $1023 \geq 1000$, so height $9$ is possible. The minimum height is $9$. Equivalently $\lfloor \log 1000 \rfloor = 9$ because $2^{9} = 512 \leq 1000 < 1024 = 2^{10}$.

**6.** The path $M, H, C, E$ has three edges, so the depth of $E$ is $3$. Node $K$ is a leaf, height $0$. Node $C$ has only the child $E$, so $\mathrm{height}(C) = 1 + \max(-1, 0) = 1$. Then $\mathrm{height}(H) = 1 + \max(1, 0) = 2$. Node $R$ is a leaf. $\mathrm{height}(T) = 1 + \max(0, -1) = 1$. $\mathrm{height}(M) = 1 + \max(2, 1) = 3$. The height of the tree is $3$.

Preorder: $M, H, C, E, K, T, R$.

Inorder: $C, E, H, K, M, R, T$.

Postorder: $E, C, K, H, R, T, M$.

Level order: $M, H, T, C, K, R, E$.

**7.** The evaluation is a postorder fold. Fully parenthesized inorder: `((7 + 1) * (8 - 3))`. Postfix: `7 1 + 8 3 - *`.

The fold: $7 + 1 = 8$; $8 - 3 = 5$; $8 \cdot 5 = 40$. The value is $40$.

**8.** Preorder starts at $F$, and $F$ sits in the middle of the inorder sequence, with $A, B, C, D, E$ on the left and $G, H, I$ on the right. The left subtree has preorder $B, A, D, C, E$. Its root is $B$, with left subtree $A$ and right subtree whose preorder is $D, C, E$ and whose inorder is $C, D, E$. That subtree is $D$ with left $C$ and right $E$. The right subtree of $F$ has preorder $G, I, H$ and inorder $G, H, I$, so the root is $G$, it has no left child, and its right subtree is $I$ with left child $H$.

```text
        F
       / \
      B   G
     / \   \
    A   D   I
       / \ /
      C   E H
```

Postorder: $A, C, E, D, B, H, I, G, F$.

Preorder names the root and then concatenates the subtrees, but it does not say how long the left subtree is. Inorder splits the remaining labels into the left subtree and the right subtree once the root is known. Either sequence alone leaves at least the two-node ambiguity. Preorder plus postorder leaves it as well: a root $A$ with left child $B$, and a root $A$ with right child $B$, both have preorder $A, B$ and postorder $B, A$.

**9.** Parent of $i$ is $\lfloor (i - 1) / 2 \rfloor$. Left child is $2i + 1$. Right child is $2i + 2$. A child exists when its index is strictly less than $20$.

Index $6$: parent $\lfloor 5 / 2 \rfloor = 2$. Left child $13$, which exists. Right child $14$, which exists.

Index $11$: parent $\lfloor 10 / 2 \rfloor = 5$. Left child $23$, which does not exist. Right child $24$, which does not exist.

**10.** Height is an exhaustive walk: $\Theta(n)$ time and $\Theta(h)$ extra stack space. Level order is $\Theta(n)$ time and $\Theta(w)$ queue space, with $w \leq (n + 1) / 2$. Reconstruction with a label-to-index map is $\Theta(n)$ time and $\Theta(h)$ stack space, plus $\Theta(n)$ space for the map and the new nodes. Scanning the inorder segment at every call is $\Theta(n^{2})$ on a left spine, because each root sits at the end of its segment and the segment lengths sum to $\Theta(n^{2})$. A parent pointer costs one extra reference per node, so the tree remains $\Theta(n)$ space and the constant on the links grows by one. The parent query becomes $\Theta(1)$. Every child-link write must update the pointer, or the invariant fails.

---

## Independent assignment

This is the mid-course checkpoint. It is one program, written from a blank file, that re-implements five structures and prints `CHECKPOINT PASSED`. Do not open the code of Lectures 02, 03, 04, or 06 while you do it. Do not copy the laboratory program of this lecture. The specifications below are the whole contract. Budget several hours. Keep the file. Later lectures assume you can still write these structures.

Write a comment containing the cost next to every public operation. The costs below are the ones the comment must state, including the case: worst, or amortized.

### Dynamic array

Implement `DynamicArray`. The storage is a JavaScript array used as a fixed block of length `capacity`. Grow and shrink by allocating a new array and copying. Do not call `push`, `pop`, or `splice` on the storage to change its length. You may read and write `storage[i]`.

Start at capacity $8$ and size $0$. `append(value)`: if `size === capacity`, allocate an array of length `2 * capacity`, copy the `size` elements, and then store the new value at index `size` and increment `size`. `pop()`: throw if `size === 0`; otherwise decrement `size`, and if `capacity > 8` and `size <= capacity / 4`, allocate an array of length `capacity / 2` and copy the `size` live elements. `get(i)` and `set(i, value)` throw when `i < 0` or `i >= size`.

Costs to write beside the methods: `get` and `set` are $\Theta(1)$ worst case; `size` and `capacity` are $\Theta(1)$ worst case; `append` is amortized $\Theta(1)$ and $\Theta(n)$ worst case when a copy happens; `pop` is amortized $\Theta(1)$ and $\Theta(n)$ worst case when a shrink copies. Beside `append`, also write the aggregate reason in a comment: over $n$ appends starting from empty, the copied elements form a geometric series bounded by $2n$, so the total copy work is $O(n)$ and the average over that worst-case sequence is $O(1)$. Call the bound amortized. It is not an average over random inputs.

The program must check all of the following. Append the integers $0$ through $19$. Then `get(0) === 0`, `get(19) === 19`, `size() === 20`, and `capacity() === 32`. Pop once: the value is $19$, the size is $19$, and the capacity stays $32$. Pop until the size is $8$: the capacity is then $16$. Pop until the size is $4$: the capacity is then $8$. One further `pop` on an empty array throws. The live prefix after the first pop is the integers $0$ through $18$.

### Singly linked list

Implement `SinglyLinkedList` with nodes `{ element, next }` and fields `head`, `tail`, and `size`. Do not use a sentinel. The invariant, written as a comment, is: size $0$ means `head` and `tail` are `null`; size $1$ means `head === tail`, `head` is not `null`, and `head.next` is `null`; `tail` is `null` or `tail.next` is `null`; walking `next` from `head` visits exactly `size` nodes and ends at `tail`.

`pushFront(x)` and `pushBack(x)` are $\Theta(1)$ worst case. `pushBack` uses `tail`. An empty list updates both `head` and `tail`. `popFront()` is $\Theta(1)$ worst case and throws if the list is empty; if the list becomes empty, `tail` becomes `null`. `popBack()` is $\Theta(n)$ worst case, because the predecessor of `tail` is found by a walk from `head`, and it throws if the list is empty. `get(i)` is $\Theta(i)$ and throws if `i` is outside $0, \ldots, \mathrm{size} - 1$. `insertAfter(i, x)` walks to index `i` and splices a new node after it; the public cost is $\Theta(i)$, and a splice after the current tail updates `tail`. Write one further comment: a singly linked list cannot unlink a node given only a pointer to that node, because the predecessor's `next` must change, so this list does not offer that operation.

Check: `pushFront(2)`, `pushFront(1)`, `pushBack(3)` yields the sequence $1, 2, 3$. `insertAfter(0, 9)` yields $1, 9, 2, 3$. `popFront()` returns $1$ and leaves $9, 2, 3$. `popBack()` returns $3$ and leaves $9, 2$. `get(1) === 2`.

### Circular queue

Implement `CircularQueue` with a fixed capacity given to the constructor. Storage is an array of that length. Keep a `head` index and a `size`. Distinguish empty from full by `size`. Do not treat `head === tail` as the test, because that equality cannot mean both conditions. The slot written by enqueue is index `(head + size) mod capacity`.

`enqueue(x)` is $\Theta(1)$ worst case and throws if `size === capacity`. `dequeue()` is $\Theta(1)$ worst case, throws if `size === 0`, returns `storage[head]`, and sets `head = (head + 1) mod capacity`. `front()` is $\Theta(1)$ worst case and throws if empty. `isEmpty` and `isFull` are $\Theta(1)$ worst case.

Check a queue of capacity $3$. Enqueue `a`, `b`, `c`. `isFull()` is true, and enqueue of `d` throws. Dequeue returns `a`. Enqueue `d`. The following dequeues return `b`, then `c`, then `d`. `isEmpty()` is true, and another dequeue throws. This sequence wraps: after the first dequeue, `d` is stored at index $0$.

### Mergesort

Implement `mergeSort(array)` so that it returns a new array and does not mutate the input. Do not call `Array.prototype.sort`. If the length is at most $1$, return a copy. Otherwise split at $\lfloor n / 2 \rfloor$, sort the halves recursively, and merge. The merge is stable: when the two heads compare equal, take the element from the left half. Use an auxiliary array. The extra space is $\Theta(n)$.

Beside the function, write the recurrence $T(n) = 2T(\lfloor n / 2 \rfloor) + \Theta(n)$ with $T(1) = \Theta(1)$, and state that the Master Theorem's case $a = 2$, $b = 2$, $f(n) = \Theta(n) = \Theta(n^{\log_b a})$ gives $T(n) = \Theta(n \log n)$ in the worst case. Comparisons and element moves are both $\Theta(n \log n)$.

Stable means that equal keys keep the relative order they had in the input. Check objects compared only by `key`: the input `[{key:2, tag:"b"}, {key:1, tag:"a"}, {key:2, tag:"a"}]` sorts to `[{key:1, tag:"a"}, {key:2, tag:"b"}, {key:2, tag:"a"}]`. Also sort `[5, 1, 4, 2, 8, 5, 3]` to `[1, 2, 3, 4, 5, 5, 8]`, and assert that the input array is unchanged.

### Binary tree

Implement a node with `element`, `left`, and `right`, and the four traversals, `size`, and `height`, from the definitions in this lecture. A parent pointer is optional. If you omit it, the comment must say that a parent query is not $\Theta(1)$. Build this tree with links, not by copying the laboratory source:

```text
        A
       / \
      B   C
     / \   \
    D   E   F
       /
      G
```

The checks are: size $7$; height $3$; preorder $A, B, D, E, G, C, F$; inorder $D, B, G, E, A, C, F$; postorder $D, G, E, B, F, C, A$; level order $A, B, C, D, E, F, G$.

Costs: each of the three recursive traversals is $\Theta(n)$ time and $\Theta(h)$ extra stack space; level order is $\Theta(n)$ time and $\Theta(w)$ queue space, and the queue operations you use are $\Theta(1)$ each; `size` and `height` are $\Theta(n)$ time. Write one sentence that a skewed tree of $n$ nodes has height $n - 1$, so the recursive stack is $\Theta(n)$ in that case, and a perfect tree has height $\Theta(\log n)$.

The linked queue inside this lecture's laboratory is a legal queue, and it is not the structure this checkpoint asks for. The checkpoint queue is the circular buffer specified above.

When every check holds, print exactly `CHECKPOINT PASSED`.

---

## Glossary

**Ancestor.** A node on the unique path from the root to a given node, including that node.

**Array representation.** The packed 0-based level-order array of a complete binary tree, with parent $\lfloor (i - 1) / 2 \rfloor$ and children $2i + 1$ and $2i + 2$.

**Binary tree.** A rooted tree in which each node has a left child position and a right child position, either of which may be empty.

**Child.** A node whose parent is the given node.

**Complete binary tree.** Every level except possibly the last is full, and the last level is filled from the left. The occupied level numbers are $0$ through $n - 1$.

**Degree.** The number of children of a node.

**Depth.** The number of edges from the root to the node. The root has depth $0$.

**Descendant.** A node that has the given node as an ancestor, including the node itself.

**Distinct labels.** The hypothesis that no two nodes carry the same element, required for the preorder-plus-inorder reconstruction.

**Downward path.** A path that steps only from parent to child.

**Edge.** The link from a parent to one child. A rooted tree of $n$ nodes has $n - 1$ edges.

**Empty tree.** The tree with no nodes. Its height is $-1$ and its size is $0$.

**Exhaustive walk.** A procedure that does $\Theta(1)$ work at every node and follows every child link a constant number of times. Its running time is $\Theta(n)$.

**Expression tree.** A binary tree whose leaves are operands and whose internal nodes are operators.

**Full binary tree.** Every node has $0$ or $2$ children. Also called proper.

**Fully parenthesized inorder.** The inorder print that wraps every operator in a pair of parentheses.

**Height of a node.** The number of edges on a longest downward path from the node to a leaf. A leaf has height $0$.

**Height of a tree.** The height of the root. It equals the maximum depth of a node when the tree is nonempty.

**Inorder.** The walk that visits the left subtree, then the node, then the right subtree.

**Internal node.** A node that is not a leaf.

**Leaf.** A node with no children.

**Level.** The set of nodes at one depth. Level $0$ contains the root.

**Level numbering.** The position numbers used by the array representation, starting at $0$ for the root.

**Level order.** The walk that visits nodes of depth $0$, then depth $1$, and so on, from left to right inside each depth. Implemented with a queue.

**Linked representation.** A node storing an element, a left link, and a right link, with `null` for an absent child.

**Operand.** A leaf of an expression tree.

**Operator.** An internal node of an expression tree.

**Parent.** The unique node of which the given node is a child. The root has none.

**Parent pointer.** An optional link from a child back to its parent. One extra reference per node; the parent query becomes $\Theta(1)$.

**Path.** A sequence of nodes in which each consecutive pair is joined by an edge. A simple path does not repeat a node.

**Perfect binary tree.** Every internal node has two children, and every leaf has the same depth. It has $2^{h+1} - 1$ nodes.

**Postfix.** The postorder print of an expression tree. Operators follow their operands.

**Postorder.** The walk that visits the left subtree, then the right subtree, then the node.

**Postorder fold.** A computation that evaluates the children and then combines the results at the node. Expression evaluation is this fold.

**Preorder.** The walk that visits the node, then the left subtree, then the right subtree.

**Proper ancestor.** An ancestor other than the node itself.

**Proper descendant.** A descendant other than the node itself.

**Reconstruction.** Building the unique binary tree determined by a preorder sequence and an inorder sequence of distinct labels.

**Root.** The unique node with no parent.

**Rooted tree.** A finite set of nodes with one root, one parent for every other node, and parent chains that reach the root without repetition.

**Sibling.** A node with the same parent as another node.

**Simple path.** A path that does not repeat a node. A tree has exactly one simple path between any two nodes.

**Skewed binary tree.** A binary tree in which every node has at most one child. Its height is $n - 1$.

**Subtree.** The rooted tree consisting of a node and all of its descendants.

**Width.** The maximum number of nodes on one level. In a binary tree, $w \leq (n + 1) / 2$.

---

## Lecture summary

A rooted tree gives every node except the root one parent, and the parent chains reach the root. Depth counts edges down from the root, so the root has depth $0$. Height counts edges down to a leaf, so a leaf has height $0$, and a missing subtree is recorded as height $-1$ so that the recurrence $1 + \max$ agrees with that leaf. In a nonempty tree those two measures meet: the height of the root is the maximum depth of a node.

A binary tree distinguishes a left child from a right child even when one of them is missing. Full, perfect, and complete are three different restrictions of that shape. A perfect tree of height $h$ has $2^{h+1} - 1$ nodes and height $\Theta(\log n)$. A skewed tree has height $n - 1$. The linked representation stores an arbitrary shape in $\Theta(n)$ space. The array representation packs a complete shape into indexes $0$ through $n - 1$ with parent $\lfloor (i - 1) / 2 \rfloor$ and children $2i + 1$ and $2i + 2$.

Preorder, inorder, and postorder are one recursion with the visit in three positions. Level order is the same child relation served by a queue. All four are $\Theta(n)$ time. An expression tree uses the same walks: parenthesized inorder prints the expression, postorder is postfix, and evaluation is the postorder fold. Preorder plus inorder rebuilds one binary tree when labels are distinct. Preorder plus postorder does not, already on two nodes.

### Five principles

1. Height counts edges. The empty tree is $-1$, a leaf is $0$, and the root's depth is $0$. Under that convention the height of a nonempty tree is the maximum depth of a node.
2. An exhaustive walk visits every node, so it costs $\Theta(n)$ on every shape. Balance changes the height, and therefore the stack depth and the later search cost. It does not change the cost of reading the whole tree.
3. Left and right are different data. A missing left child is not a missing right child, which is why one traversal sequence, and why preorder together with postorder, need not determine the tree.
4. The formulas parent $\lfloor (i - 1) / 2 \rfloor$ and children $2i + 1$, $2i + 2$ are the level numbering of a complete binary tree. They do not order the values. Heap order is a later invariant on the same array.
5. Inorder splits a tree around a node, preorder names the root first, and postorder combines the children before the node. Expression evaluation is that postorder combination, and reconstruction is preorder's root together with inorder's split.

---

## References

Cormen, Thomas H., Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Section 10.3, "Representing rooted trees," is the linked representation of a rooted tree, including left and right children. This lecture does not use the search property developed in Chapter 12.

Goodrich, Michael T., Roberto Tamassia, and Michael H. Goldwasser. *Data Structures and Algorithms in Java*. 6th edition. Wiley, 2014. Chapter 8, "Trees," especially the binary-tree definitions, the linked structure, the 0-based level numbering and array representation in Section 8.3.2, and the traversals in Section 8.4. Their word "proper" is this lecture's "full." Their complete binary tree is the packed level numbering $0$ through $n - 1$. The code in this course is JavaScript.

Weiss, Mark Allen. *Data Structures and Algorithm Analysis in C++*. 4th edition. Pearson, 2014. Sections 4.1 and 4.2 cover tree definitions, the linked representation, traversals, and expression trees, and they take the height of an empty subtree to be $-1$. Sections 4.3 through 4.7 are binary search trees, AVL trees, and B-trees; those are Lectures 08 and 09.

Knuth, Donald E. *The Art of Computer Programming, Volume 1: Fundamental Algorithms*. 3rd edition. Addison-Wesley, 1997. Section 2.3.1, "Traversing Binary Trees," is the source of the preorder, inorder, and postorder discipline used in Part 6.
