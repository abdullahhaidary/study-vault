# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 08 — BINARY SEARCH TREES

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 08 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 8 hours
**Prerequisites:** Lecture 05 — Recursion, Induction, and Divide-and-Conquer; Lecture 06 — Sorting and Order Statistics; Lecture 07 — Trees, Binary Trees, and Traversals
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapter 12; the same authors, 3rd edition, Section 12.4; Sedgewick and Wayne, *Algorithms*, 4th edition, Section 3.2; Bentley, *Communications of the ACM*, 1975

**This lecture owns:** the binary-search-tree property, search, insert, delete, successor, the cost of a skewed tree against a randomly built tree, and a bounded introduction to k-d trees.
**This lecture does not teach:** AVL rotations, red–black trees, B-trees, 2–3–4 trees, heaps, hashing, range trees, or fractional cascading.

---

# Learning objectives

After this lecture you should be able to do all of the following without looking back at an outside source.

1. State the search property for every node, apply this lecture's duplicate policy, and decide whether a drawn binary tree satisfies the property, naming a witness key when it does not.
2. Prove by induction on the tree, from Lecture 07's inorder definition, that an inorder walk of a binary search tree emits keys in sorted order.
3. Execute iterative and recursive search, write the search invariant, and say where an unsuccessful search stops.
4. Insert a key, draw the changed tree, and justify that the search property still holds.
5. Compute the minimum, the maximum, the successor, and the predecessor, both with parent pointers and without them, and name which of the successor's two cases applies.
6. Delete a key in each of the three child cases, including a two-child deletion that copies the successor and then deletes the successor, and state the invariant that holds when the call returns.
7. Give the height and the search cost of a tree built by sorted insertion, give the best-case height $\lfloor \log n \rfloor$, and state the expected-height theorem for a randomly built tree together with the assumption it uses.
8. Compare a binary search tree with a sorted array that stores the same set, operation by operation.
9. Insert a two-dimensional point into a k-d tree, run an exact-match search, and run an orthogonal range query, pruning a side whose splitting plane misses the query rectangle.
10. Name an operation mix for which a binary search tree is the wrong tool and name the later lecture that owns the replacement.

---

# Purpose of this lecture

Lecture 07 gave you the shape of a binary tree: root, children, height, and the four walks. It deliberately stopped before any rule about the keys. This lecture adds one rule, the search property, and then builds the ordered-set operations on top of it.

An ordered set stores distinct keys from a totally ordered universe and supports search, insertion, deletion, and the neighboring-key queries minimum, maximum, successor, and predecessor. A binary search tree is one implementation. Every one of those operations follows a root-to-leaf path, or a short climb from a node to an ancestor, so the cost is proportional to the height of the tree that happens to be in memory. The height is not a function of $n$ alone. The same $n$ keys can sit in a short tree or in a chain. That is the fact this lecture exists to make precise, and it is why Lecture 09 will add balance.

The duplicate policy is fixed here and used for every structure in the lecture, including the k-d tree. **A key already present is rejected.** Insertion returns false and does not change the tree. A k-d tree rejects a point that is already present, meaning both coordinates equal. Because of this policy every tree built by the public operations has distinct keys, and the inequalities in the search property are strict. The definition itself is stated with the weak inequalities, because that is the property you must be able to check on a drawing even before you remember the policy.

Keys in the JavaScript code are ordinary numbers. IEEE-754 comparison agrees with integer order for every integer in the closed range from $-(2^{53}-1)$ to $2^{53}-1$, which is `Number.MAX_SAFE_INTEGER` at the top end. Every key in this lecture lies far inside that range. The cost arguments count key comparisons and pointer writes. They do not depend on a particular engine's optimizer.

What this lecture refuses to do is equally part of the purpose. It does not rotate a tree to restore balance. It does not color a node red or black. It does not teach range trees or fractional cascading. The k-d tree section is a bounded extension of the same idea to two coordinates, and it stops once insert, exact search, and one orthogonal range query are correct. When the chapter has shown that sorted insertion produces a chain of height $n-1$, it points to Lecture 09 rather than repairing the chain itself.

---

# Part 1. The search property

## 1.1 Why the keys need a rule

A binary tree from Lecture 07 can hold keys in any arrangement. Finding a key then requires looking at every node in the worst case, which is a walk of $\Theta(n)$ nodes and no better than scanning an unsorted array. The reason to impose a rule on the keys is to make one comparison throw away an entire subtree.

The rule has to be strong enough to survive recursion. It is not enough that the left child is smaller than the node and the right child is larger. A grandchild can still sit on the wrong side of the root, and a search that trusted only the children would walk into a subtree that cannot contain the key and miss the key that is actually there, or report a hit that the rest of the tree contradicts.

## 1.2 Definition

**Definition (binary search tree).** A binary search tree is a binary tree in which every node $x$ satisfies the search property: every key in the left subtree of $x$ is $\le x.\mathrm{key}$, and every key in the right subtree of $x$ is $\ge x.\mathrm{key}$. An empty subtree has no keys, so the property holds there with nothing to check.

The quantifier is every node, and the keys it talks about are every key in the subtree, at any depth. The children of $x$ are the special case in which the subtree is a single node.

**Duplicate policy.** `insert` rejects a key that is already stored. The call returns false, and the pointers, the size, and the keys stay as they were. This policy is in force for the binary search tree and for the k-d tree.

**Theorem (strict form).** In every tree produced by this lecture's `insert` and `delete`, all keys are distinct. Therefore every key in the left subtree of $x$ is $< x.\mathrm{key}$, and every key in the right subtree of $x$ is $> x.\mathrm{key}$.

**Proof.** `insert` refuses to add a key that search already finds, so a newly created node has a key different from every key already in the tree. `delete` removes one stored key and, in the two-child case, writes an existing key onto a node only after the node that previously held it is unlinked, so the live tree never contains that key twice. By induction on the number of successful updates, the live keys are distinct. Distinctness upgrades $\le$ to $<$ and $\ge$ to $>$. $\square$

The weak statement remains the definition you use when someone hands you a drawing and asks whether it is a binary search tree. The strict statement is what our operations maintain, and it is what the laboratory checker enforces.

## 1.3 The child test is weaker than the property

Consider this tree.

```text
      5
     /
    3
   /
  7
```

The only child relationships are $3 \le 5$ and $7 \le 3$. A check that looks only at children accepts the tree. The search property at the root does not: $7$ is in the left subtree of $5$, and $7 > 5$. The tree is not a binary search tree. Its inorder walk, using the definition in Part 2, is $7, 3, 5$, which is not sorted. You will use this kind of witness on the examination: a key, the node whose subtree contains it, and the inequality that fails.

## 1.4 Subtrees inherit the property

**Lemma (subtree).** Every subtree of a binary search tree is a binary search tree.

**Proof.** Take a node $y$ in a subtree $T'$ of a binary search tree $T$. The left and right subtrees of $y$ in $T'$ are the same nodes as the left and right subtrees of $y$ in $T$, because a subtree is cut off by keeping one node and everything below it. The search property at $y$ in $T$ is a statement about those keys. The same statement is the search property at $y$ in $T'$. This holds for every $y$ in $T'$. $\square$

The lemma is the license for recursion. A recursive search, insert, or delete may assume that the child it walks into is itself a binary search tree.

## 1.5 The ordered-set operations

The structure implements an ordered set. There is no separate satellite value in the code. If you later store a value beside the key, every place that copies a key in deletion must copy the value with it. The operations are these.

| Operation | Behavior |
| --- | --- |
| `search(k)` | Return the node whose key is $k$, or `null` if no such node exists. |
| `insert(k)` | If $k$ is present, return false and change nothing. Otherwise add one node with key $k$ and return true. |
| `delete(k)` | If $k$ is absent, return false. Otherwise remove that key and return true. |
| `minimum`, `maximum` | Return the smallest or largest key, or `null` on the empty tree. |
| `successor`, `predecessor` | Return the next or previous key in sorted order, or `null` at the end of the order. |
| `inorder` | Return the keys in nondecreasing order. Under the policy, the order is strictly increasing. |

A node stores `key`, `left`, `right`, and `parent`. An absent child or an absent parent is `null`. The root's parent is `null`. The integer `size` is the number of live nodes.

**Invariant.** After every public operation the following are all true. The strict search property holds at every live node. For every live node other than the root, exactly one of `parent.left` and `parent.right` is that node, and the root's parent is `null`. Following child pointers from the root reaches each live node once and never returns to a node already seen. `size` equals the number of live nodes. The inorder sequence of the live keys is strictly increasing.

Part 6 checks this invariant on the tree that remains after a two-child deletion, which is the update most likely to break a parent or a child pointer.

---

# Part 2. Inorder yields sorted order

## 2.1 The walk, as Lecture 07 defined it

Lecture 07 fixes the inorder walk of a binary tree $T$.

- If $T$ is empty, the walk produces the empty sequence.
- Otherwise the walk is the inorder walk of the left subtree, followed by the root key, followed by the inorder walk of the right subtree.

Nothing in that definition mentions the search property. The theorem of this part is the place where the two meet. The same walk on a binary tree that is not a search tree has no reason to be sorted. The tree in Section 1.3 is a counterexample.

```javascript
inorder(node = this.root, out = []) {
  if (node === null) return out;
  this.inorder(node.left, out);
  out.push(node.key);
  this.inorder(node.right, out);
  return out;
}
```

The empty tree returns the array it was given, which the first call creates as `[]`. A leaf pushes its key between two empty walks.

## 2.2 The theorem

**Theorem (inorder of a binary search tree).** The inorder walk of a binary search tree produces keys in nondecreasing order. Under this lecture's duplicate policy the order is strictly increasing.

**Proof.** Induction on $n$, the number of nodes.

Base case. If $n = 0$, the tree is empty and the walk produces the empty sequence. The empty sequence is sorted.

Inductive hypothesis. Assume $n \ge 1$ and assume that every binary search tree with fewer than $n$ nodes has an inorder walk in nondecreasing order.

Inductive step. Let $T$ have $n$ nodes, root $x$, left subtree $L$, and right subtree $R$. The root is in neither subtree, so $|L| < n$ and $|R| < n$. By the subtree lemma, $L$ and $R$ are binary search trees. The inductive hypothesis says that the inorder sequence $A$ of $L$ and the inorder sequence $B$ of $R$ are each nondecreasing.

The search property at $x$ says that every key in $A$ is $\le x.\mathrm{key}$ and every key in $B$ is $\ge x.\mathrm{key}$. The inorder sequence of $T$ is $A$, then $x.\mathrm{key}$, then $B$. Take any two consecutive positions in that concatenation. If both lie in $A$, they are in order because $A$ is. If both lie in $B$, they are in order because $B$ is. If they are the last key of $A$ and $x.\mathrm{key}$, the search property gives the inequality. If they are $x.\mathrm{key}$ and the first key of $B$, the search property gives the inequality. A sequence whose consecutive pairs are in order is sorted, so the walk of $T$ is nondecreasing.

That is the inductive step. By induction the claim holds for every $n$.

Under the duplicate policy the keys are distinct, so every inequality used above is strict, and the walk is strictly increasing. $\square$

The proof uses the search property at the root of the tree under consideration, and the inductive hypothesis applies it inside $L$ and $R$. Checking the property only at the root of the whole tree would not be enough, because the inductive step has to call the hypothesis on the subtrees. The subtree lemma is what makes those calls legal.

## 2.3 The converse

**Theorem (converse).** Let $T$ be a binary tree whose keys are distinct. Then $T$ satisfies the strict search property if and only if its inorder walk is strictly increasing.

**Proof.** The forward direction is the previous theorem. For the reverse, suppose the inorder walk of $T$ is strictly increasing. Consider an arbitrary node $x$, with left subtree $L$ and right subtree $R$. By the definition of inorder, the walk finishes the whole of a subtree before it returns to the parent, so the inorder walk of the subtree rooted at $x$ is a contiguous segment of the inorder walk of $T$. A contiguous segment of a strictly increasing sequence is strictly increasing. That segment is the inorder walk of $L$, then $x.\mathrm{key}$, then the inorder walk of $R$. Every key of $L$ therefore occurs before $x.\mathrm{key}$ in a strictly increasing sequence, and every key of $R$ occurs after it. This is the strict search property at $x$. The node $x$ was arbitrary. $\square$

The laboratory uses both directions. After every update it checks the strict property by walking with exclusive bounds, and it checks that the inorder array equals the same keys sorted by numeric order. Either check can fail while a buggy pointer update still produces a tree-shaped object. The bound walk is the one that names the broken node. The inorder check is the one that matches the theorem you just proved.

The bound walk implements the strict property directly. On entry to a subtree, every key in it must be $> \mathit{lower}$ and $< \mathit{upper}$, with a `null` bound meaning that side is unconstrained. At a node $x$ the left child is entered with upper bound $x.\mathrm{key}$, and the right child is entered with lower bound $x.\mathrm{key}$. If a key crosses a bound, the property fails at that key.

---

# Part 3. Search

## 3.1 The decision

Search answers one question: does this key occur? At a node $x$ there are three possible answers, and the search property makes two of them immediate.

- If $x.\mathrm{key} = k$, the node is the unique occurrence, because keys are distinct.
- If $k < x.\mathrm{key}$, then $k$ is not $x$ and $k$ is not in the right subtree, because every key there is $> x.\mathrm{key}$. If $k$ occurs at all, it occurs in the left subtree.
- If $k > x.\mathrm{key}$, the symmetric sentence puts $k$ in the right subtree or nowhere.

An empty tree cannot contain $k$. Reaching `null` is the unsuccessful search. There is no sentinel node standing for "absent." The absent link is `null`, and the algorithm stops there.

## 3.2 The invariant

**Search invariant.** At the start of each iteration of the iterative loop, and at the entry of each recursive call, if $k$ occurs in the original tree then $k$ occurs in the subtree rooted at the current node.

Initialization. The current node is the root, so the subtree is the whole tree.

Maintenance. Suppose the invariant holds and the current node $x$ is non-null and $x.\mathrm{key} \ne k$. If $k < x.\mathrm{key}$, the decision of Section 3.1 says $k$ is not in the right subtree. Combined with the invariant, $k$ is in the left subtree if it occurs at all. The assignment `current = x.left` restores the invariant. The case $k > x.\mathrm{key}$ is symmetric.

Termination. The loop ends because each step moves to a child, and a finite tree has no cycle of child pointers. It ends on `current === null` or on `current.key === k`. In the equal case the node is the hit. In the `null` case the invariant says that if $k$ occurred it would occur in the empty subtree, which is impossible, so the search is unsuccessful.

The recursive form is the same argument with the call stack storing the current node. It performs the same comparisons. It uses $\Theta(h)$ stack frames on a tree of height $h$. The iterative form stores one local variable. A chain long enough to exceed the engine's stack will fail in the recursive form and succeed in the iterative form. The laboratory chains are short. The iterative form is the one to keep when the tree may be skewed. The stack limit is a property of the JavaScript engine, not of the search invariant.

```javascript
search(key) {
  let current = this.root;
  while (current !== null && current.key !== key) {
    if (key < current.key) current = current.left;
    else current = current.right;
  }
  return current;
}
```

```javascript
searchRecursive(key) {
  const walk = (node) => {
    if (node === null || node.key === key) return node;
    if (key < node.key) return walk(node.left);
    return walk(node.right);
  };
  return walk(this.root);
}
```

## 3.3 A trace on the working tree

The working tree of this lecture is built by inserting, in this order:

$$
10,\ 4,\ 15,\ 2,\ 12,\ 8,\ 6,\ 7.
$$

Parts 4 and 6 use the same object. After all eight insertions it is this tree. The construction of the last three nodes is the insert trace in Part 4.

```text
            10
          /    \
        4        15
       / \      /
      2   8    12
         /
        6
         \
          7
```

Successful search for $6$.

| Step | Current key | Comparison | Next |
| --- | --- | --- | --- |
| 1 | $10$ | $6 < 10$ | left child $4$ |
| 2 | $4$ | $6 > 4$ | right child $8$ |
| 3 | $8$ | $6 < 8$ | left child $6$ |
| 4 | $6$ | equal | return that node |

The path of keys compared is $10, 4, 8, 6$.

Unsuccessful search for $9$. The comparisons follow $10$, then $4$, then $8$. At $8$, the key $9$ is greater, and the right child of $8$ is `null`. The algorithm stops on that `null` and returns `null`. It does not wrap around, and it does not start a second search. The nodes compared are $10, 4, 8$.

Two further misses, used again by the laboratory: search for $1$ compares $10, 4, 2$ and then takes the left `null` of $2$. Search for $14$ compares $10, 15, 12$ and then takes the right `null` of $12$. Search for $15$ compares $10, 15$ and hits.

## 3.4 The same decision as binary search, and a different insert

Lecture 05's binary search keeps a closed index interval on a sorted array and replaces one endpoint by the midpoint. The decision at the midpoint is the same three-way comparison: equal, go left, or go right. A binary search tree makes that decision at the root of the current subtree and replaces the subtree by one child.

The probes are the same sequence when the tree is the complete tree whose root is the middle key and whose subtrees are built the same way. Insert $4, 2, 6, 1, 3, 5, 7$.

```text
        4
      /   \
     2     6
    / \   / \
   1   3 5   7
```

The height is $2$. A leaf has height $0$, its parent has height $1$, and the root has height $1 + 1 = 2$. Also $\lfloor \log 7 \rfloor = 2$, since $2^2 = 4 \le 7$ and $2^3 = 8 > 7$.

Search for $5$ in this tree compares $4$ (go right), $6$ (go left), and $5$ (hit). The sorted array of the same keys is $[1, 2, 3, 4, 5, 6, 7]$, with indexes $0$ through $6$.

| $\mathit{lo}$ | $\mathit{hi}$ | mid $\lfloor (\mathit{lo}+\mathit{hi})/2 \rfloor$ | key at mid | decision |
| --- | --- | --- | --- | --- |
| $0$ | $6$ | $3$ | $4$ | $5 > 4$, so $\mathit{lo} \leftarrow 4$ |
| $4$ | $6$ | $5$ | $6$ | $5 < 6$, so $\mathit{hi} \leftarrow 4$ |
| $4$ | $4$ | $4$ | $5$ | hit at index $4$ |

The probe sequence is $4, 6, 5$, the same three keys. On a chain the probes are not the binary-search probes. The decision rule is still the same rule. What changes is which key is offered next.

The cost that separates the two structures is insertion. Binary search on a sorted array of $n$ keys uses $O(\log n)$ comparisons. Inserting a new key at a known index must open a slot, and opening a slot at the front moves all $n$ existing entries one position to the right. That move is $\Theta(n)$ in the worst case. The laboratory inserts $0$ into $[1, 2, 3, 4, 5, 6, 7]$ and moves $7$ entries.

Insertion into the binary search tree walks the same kind of path as an unsuccessful search and then writes one child pointer and one parent pointer. On this tree of height $2$, inserting a new minimum writes the left child of $1$. No other key moves. The comparison count is the length of the path. The price of that cheap write is the height, which Part 7 shows can be $n-1$.

---

# Part 4. Insert

## 4.1 Where the new node goes

An unsuccessful search ends at a `null` child pointer of some node, or at the root when the tree is empty. That `null` is the unique place the search property allows the missing key to be attached. Every ancestor already forced the search onto this side. A new leaf hung on that pointer extends each of those ancestor subtrees on the side the comparison required.

If the key is already present, the policy says to return false before any pointer is written. The equality test sits inside the walk, next to the comparison, so a duplicate never falls through into a child.

```javascript
insert(key) {
  let parent = null;
  let current = this.root;
  while (current !== null) {
    parent = current;
    if (key === current.key) return false;
    if (key < current.key) current = current.left;
    else current = current.right;
  }
  const node = new BSTNode(key);
  node.parent = parent;
  if (parent === null) this.root = node;
  else if (key < parent.key) parent.left = node;
  else parent.right = node;
  this.size += 1;
  return true;
}
```

## 4.2 Why the property survives

**Theorem (insert maintains the search property).** If the tree satisfies the strict search property and `insert(k)` either rejects $k$ or adds one leaf, the resulting tree satisfies the strict search property.

**Proof.** A rejection writes nothing. The property is unchanged. Suppose $k$ is new. The walk visits $x_0, x_1, \ldots, x_m$ where $x_0$ is the root and $x_{i+1}$ is the left child of $x_i$ when $k < x_i.\mathrm{key}$ and the right child when $k > x_i.\mathrm{key}$. The new node $z$ replaces the `null` child at the end of this walk. Both subtrees of $z$ are empty, so the property holds at $z$ vacuously, and $z.\mathrm{key}$ equals no existing key.

Consider an old node $x_i$ on the walk. If the walk went left at $x_i$, then $k < x_i.\mathrm{key}$ and $z$ lies in the left subtree of $x_i$. Every key that was already in that subtree was already $< x_i.\mathrm{key}$. Adding $k$ preserves the strict inequality. If the walk went right, the symmetric sentence applies. A node off the walk keeps the same subtrees it had, because the new leaf hangs inside the subtree the walk entered and not inside the subtree it skipped. The property already held there. $\square$

Size grows by one only on the success path, after the node is linked. A rejected duplicate leaves `size` alone.

## 4.3 Three insertions that change the shape

Start from the tree formed by $10, 4, 15, 2, 12$.

```text
            10
          /    \
        4        15
       /        /
      2        12
```

Insertion of $8$. Compare $8 < 10$, go left. Compare $8 > 4$, go right. The right child of $4$ is `null`. Link a new node $8$ there, with parent $4$.

```text
            10
          /    \
        4        15
       / \      /
      2   8    12
```

The shape change is local: $4$ gains a right child. Every earlier key stays where it was.

Insertion of $6$. The walk is $10$ (left), $4$ (right), $8$ (left). The left child of $8$ is `null`. Link $6$ as the left child of $8$.

```text
            10
          /    \
        4        15
       / \      /
      2   8    12
         /
        6
```

Insertion of $7$. The walk is $10$ (left), $4$ (right), $8$ (left), $6$ (right). Link $7$ as the right child of $6$.

```text
            10
          /    \
        4        15
       / \      /
      2   8    12
         /
        6
         \
          7
```

A fourth call, `insert(8)`, finds $8$ already stored and returns false. The drawing does not change, and `size` stays $8$.

The inorder sequence is now $2, 4, 6, 7, 8, 10, 12, 15$. The minimum is $2$, the leftmost node. The maximum is $15$, reached by going right from $10$ and stopping because $15$ has no right child. The height is $4$: the node $7$ is a leaf and has height $0$, $6$ has height $1$, $8$ has height $2$, $4$ has height $3$, and $10$ has height $4$. Part 7 will compare $4$ with the best possible height of an $8$-node tree, which is $\lfloor \log 8 \rfloor = 3$, and with the worst, which is $7$.

---

# Part 5. Minimum, maximum, successor, and predecessor

## 5.1 Minimum and maximum

**Theorem.** In a nonempty binary search tree the minimum key is the key of the node reached by following left children from the root until the left child is `null`. The maximum is the key reached by following right children until the right child is `null`.

**Proof.** Let $z$ be the node where the left walk stops. Every step went left, so $z$ is in the left subtree of each ancestor on the walk, and the search property makes $z.\mathrm{key}$ smaller than each of those ancestors. Any other node $y$ is either on this walk, or in a right subtree of some node $x$ on this walk. A node on the walk other than $z$ is an ancestor of $z$, so its key is larger. A node in the right subtree of such an $x$ has a key $> x.\mathrm{key}$, and $x.\mathrm{key} \ge z.\mathrm{key}$, so that key is also larger. Thus $z.\mathrm{key}$ is the minimum. The maximum argument replaces "left" by "right" and reverses every inequality. $\square$

On the working tree the left walk is $10, 4, 2$ and the minimum is $2$. The right walk is $10, 15$ and the maximum is $15$. Both walks are $O(h)$ and $\Theta(h)$ in the worst case, which is a chain that runs entirely to one side.

## 5.2 Successor with parent pointers

The successor of a node $x$ is the node whose key is the smallest key strictly greater than $x.\mathrm{key}$, or `null` if $x$ holds the maximum. There are two cases.

**Case 1.** $x$ has a right child. The successor is the minimum of the right subtree.

**Case 2.** $x$ has no right child. Climb parents while the current node is the right child of its parent. The parent at which the climb stops, which may be `null`, is the successor.

```javascript
successor(node) {
  if (node === null) return null;
  if (node.right !== null) return this.minimumNode(node.right);
  let current = node;
  let parent = node.parent;
  while (parent !== null && current === parent.right) {
    current = parent;
    parent = parent.parent;
  }
  return parent;
}
```

**Theorem (successor).** On a binary search tree of distinct keys, `successor(x)` returns the least key strictly greater than $x.\mathrm{key}$, or `null` if $x$ holds the maximum.

**Proof of case 1.** Every key in the right subtree of $x$ is $> x.\mathrm{key}$. The minimum $z$ of that subtree is the least of them. It remains to show that no key outside that subtree lies strictly between $x.\mathrm{key}$ and $z.\mathrm{key}$. The left subtree of $x$ contains only keys $< x.\mathrm{key}$. Consider an ancestor $y$ of $x$. If $x$ is in the right subtree of $y$, then $y.\mathrm{key} < x.\mathrm{key}$, so $y$ is too small. If $x$ is in the left subtree of $y$, then $y.\mathrm{key} > x.\mathrm{key}$. Every key in the right subtree of $y$ is $> y.\mathrm{key}$, so it is even larger than $y$. The keys that sit properly between $x$ and $y$ in the tree would have to be in the right subtree of $x$, which is exactly the subtree whose minimum is $z$, and $z$ is the smallest key there. In particular $z.\mathrm{key} \le y.\mathrm{key}$ whenever $y$ is a strict ancestor with $x$ on its left, because $z$ is itself in the left subtree of $y$. So no ancestor and no node off this path is strictly between $x.\mathrm{key}$ and $z.\mathrm{key}$.

**Proof of case 2.** The climb moves from $x$ through every ancestor that contains the current node in its right subtree, and it stops at the first parent $p$ that contains the current node in its left subtree. That parent is the lowest ancestor of $x$ such that $x$ lies in the left subtree of the ancestor. If the climb runs off the root, every ancestor contains $x$ in its right subtree, so every ancestor key is $< x.\mathrm{key}$, the right subtree of $x$ is empty, and $x$ holds the maximum. The return value `null` is correct.

Now suppose the climb stops at $p$. Then $x$ is in the left subtree of $p$, so $p.\mathrm{key} > x.\mathrm{key}$. The path from $p$ down to $x$ takes the left child of $p$ and afterward takes only right children, because those are the links the climb reversed. Let $y$ be any node on that path other than $p$. The node $x$ is $y$ or lies in the right subtree of $y$, so $y.\mathrm{key} \le x.\mathrm{key}$, and the inequality is strict when $y \ne x$. Every left subtree hanging off this path consists of keys smaller than the node it hangs from, hence $< x.\mathrm{key}$. The right subtree of $x$ is empty. Therefore every key in the left subtree of $p$, other than $x$ itself, is $< x.\mathrm{key}$. No key in that subtree lies strictly between $x.\mathrm{key}$ and $p.\mathrm{key}$.

Every key in the right subtree of $p$ is $> p.\mathrm{key}$. Consider an ancestor $a$ of $p$. If $p$ lies in the left subtree of $a$, then $a.\mathrm{key} > p.\mathrm{key}$. If $p$ lies in the right subtree of $a$, then $x$ does too, so $a.\mathrm{key} < x.\mathrm{key}$. No ancestor key lies strictly between $x.\mathrm{key}$ and $p.\mathrm{key}$. Hence $p$ is the successor. $\square$

The case 2 paragraph is the one to re-read with the trace in front of you. The operational rule is short: keep climbing while you arrived from the right; the first parent that contains you on its left is the successor.

Predecessor is the order reversed.

**Case 1.** If $x$ has a left child, the predecessor is the maximum of the left subtree.

**Case 2.** If $x$ has no left child, climb while the current node is the left child of its parent. The parent where the climb stops is the predecessor.

```javascript
predecessor(node) {
  if (node === null) return null;
  if (node.left !== null) return this.maximumNode(node.left);
  let current = node;
  let parent = node.parent;
  while (parent !== null && current === parent.left) {
    current = parent;
    parent = parent.parent;
  }
  return parent;
}
```

The proof is the successor proof with the order reversed: exchange left with right, and exchange $<$ with $>$.

## 5.3 Two traces

Both traces use the working tree. The inorder sequence is $2, 4, 6, 7, 8, 10, 12, 15$, so the successor relation is completely determined before you run the algorithm. Use that list to check the result, and use the algorithm to see which case fired.

Successor of $4$, case 1. The node $4$ has a right child $8$. The minimum of that subtree follows left children: $8$ has left child $6$, and $6$ has no left child. The successor is $6$. The right child $7$ of $6$ is larger than $6$ and is not the minimum.

Successor of $7$, case 2. The node $7$ has no right child. Its parent is $6$, and $7$ is the right child of $6$, so the climb continues. Set the current node to $6$ and the parent to $8$. The node $6$ is the left child of $8$, so the loop stops. The successor is $8$.

The same algorithm on the other nodes:

| Node | Case | Result | Why |
| --- | --- | --- | --- |
| $6$ | 1 | $7$ | minimum of the right subtree, which is the leaf $7$ |
| $8$ | 2 | $10$ | climb from right child of $4$ to $4$, then $4$ is the left child of $10$ |
| $2$ | 2 | $4$ | $2$ is already the left child of $4$, so the climb does not move |
| $12$ | 2 | $15$ | $12$ is the left child of $15$ |
| $15$ | 2 | `null` | $15$ is the right child of $10$, and $10$ is the root |

Predecessor of $7$, case 2. The node $7$ has no left child. It is the right child of $6$, so the climb condition fails immediately and the predecessor is $6$. Predecessor of $6$ climbs once, from the left child of $8$ up to $8$, and $8$ is the right child of $4$, so the predecessor is $4$. Predecessor of $8$, case 1, is the maximum of the subtree rooted at $6$, which is $7$. Predecessor of $2$ climbs to the root and returns `null`.

## 5.4 Successor without parent pointers

Parent pointers are part of this lecture's node because successor and deletion become direct. They are not free: every link update has to write the parent as well as the child, and that is a common place to leave a stale pointer. A tree that stores only child pointers can still answer successor, by searching from the root and remembering the candidate.

The candidate is the most recent node at which the search stepped left. If the target has a right subtree, the candidate is discarded and the successor is the minimum of that subtree, which is case 1. If the target has no right subtree, the candidate is the successor, which is case 2 expressed as "the last ancestor that contains the target in its left subtree." If the search never stepped left, the target is the maximum along this path and the successor is `null`. If the key is absent, the function returns `null` rather than a ceiling. Successor in this lecture is defined for a key that is present.

```javascript
successorByKey(key) {
  let current = this.root;
  let candidate = null;
  while (current !== null) {
    if (key < current.key) {
      candidate = current;
      current = current.left;
    } else if (key > current.key) {
      current = current.right;
    } else if (current.right !== null) {
      return this.minimumNode(current.right).key;
    } else {
      return candidate === null ? null : candidate.key;
    }
  }
  return null;
}
```

Trace successor of $7$ without using parent pointers.

| Current | Comparison | Candidate after the step |
| --- | --- | --- |
| $10$ | $7 < 10$, step left | $10$ |
| $4$ | $7 > 4$, step right | $10$ |
| $8$ | $7 < 8$, step left | $8$ |
| $6$ | $7 > 6$, step right | $8$ |
| $7$ | equal, and $7$ has no right child | return $8$ |

The candidate $10$ was overwritten when the search stepped left at $8$. That overwrite is the whole algorithm: a later left step is a closer ancestor.

Trace successor of $4$. The search steps left at $10$, so the candidate becomes $10$, then finds $4$. The node $4$ has a right subtree, so case 1 returns the minimum of that subtree, which is $6$. The candidate is not used.

Predecessor without parents is the mirror. The candidate is the most recent node at which the search stepped right. The laboratory checks both functions on present keys and on the missing key $9$, which must return `null`.

---

# Part 6. Delete

## 6.1 The three cases

Deletion removes one key and leaves a binary search tree. The shape of the repair depends on how many children the node $z$ has. Count children that are non-null. A missing child is `null` and does not count.

**No child.** $z$ is a leaf. The parent's pointer to $z$ becomes `null`. If $z$ is the root, the root becomes `null`.

**One child.** The parent of $z$ takes that child in place of $z$. The child keeps its own subtree. If $z$ is the root, the child becomes the root.

**Two children.** Do not try to hang both subtrees off the parent. The parent has only one pointer where $z$ stood. Instead replace the key of $z$ by the key of its successor $s$, then delete $s$. The successor is the minimum of the right subtree, so $s$ has no left child. Therefore $s$ has at most one child, the right child, and deleting $s$ falls into the no-child case or the one-child case. It does not fall into the two-child case again.

The node object that remains in the two-child case is the original object $z$, now storing the successor's key. The node object that leaves the tree is $s$. If a value were stored beside the key, the value would be copied with the key. Callers in this lecture address the set by key. They do not hold a node pointer across a deletion. A caller that did hold a pointer to $s$ would see a detached node, and a caller that held a pointer to $z$ would see a live node whose key had changed. CLRS, 3rd edition, splices the successor node into the place of $z$; the chapter notes say that the earlier editions copied the key, and that a caller holding a pointer to the named node would otherwise observe a changed key. This course copies the key. The laboratory asserts the identity that copy produces: after deleting $4$, the node object that used to hold $4$ holds $6$, and the node object that used to hold $6$ is unreachable.

`transplant(u, v)` is the pointer surgery shared by all three cases. It puts $v$ where $u$ currently sits and tells $v$ its new parent. It does not modify the children of $u$. The caller is responsible for the fact that $v$ is the correct subtree to leave behind.

```javascript
transplant(u, v) {
  if (u.parent === null) this.root = v;
  else if (u === u.parent.left) u.parent.left = v;
  else u.parent.right = v;
  if (v !== null) v.parent = u.parent;
}

detach(u) {
  u.left = null;
  u.right = null;
  u.parent = null;
}

deleteNode(z) {
  if (z.left === null && z.right === null) {
    this.transplant(z, null);
    this.detach(z);
    return;
  }
  if (z.left === null) {
    this.transplant(z, z.right);
    this.detach(z);
    return;
  }
  if (z.right === null) {
    this.transplant(z, z.left);
    this.detach(z);
    return;
  }
  const successor = this.minimumNode(z.right);
  z.key = successor.key;
  this.transplant(successor, successor.right);
  this.detach(successor);
}
```

`detach` runs after `transplant`. The live links have already been rewritten. Clearing the detached node's fields makes a stale pointer fail a parent check instead of looking as if it still sits in the tree. `delete` finds the node by key, calls `deleteNode`, and decrements `size` once. A missing key returns false and does not change `size`.

The order inside the two-child branch is load-bearing. The successor is found while the keys are still unique. Then `z.key` is overwritten, and for a moment the key of $s$ occurs twice, once in $z$ and once in $s$. The next statement unlinks $s$ by surgery on pointers, not by searching for the key. A search for that key at this moment could find $z$ first and unlink the wrong node. That bug is written out in the common-mistakes section. Do not "simplify" the two-child branch into a recursive call on the key until you are inside a routine that starts its search in the right subtree, which is what the recursive form below does.

## 6.2 The recursive form, and the assignment you must not forget

The same three cases can be written so that each call returns the root of the repaired subtree. The caller writes that pointer back into `node.left` or `node.right`. Forgetting the assignment is the usual pointer error in this style: the recursive call deletes a leaf and returns `null`, and the parent still holds the old child.

```javascript
deleteRecursive(key) {
  const remove = (node, target) => {
    if (node === null) return null;
    if (target < node.key) {
      node.left = remove(node.left, target);
      if (node.left !== null) node.left.parent = node;
      return node;
    }
    if (target > node.key) {
      node.right = remove(node.right, target);
      if (node.right !== null) node.right.parent = node;
      return node;
    }
    if (node.left === null) return node.right;
    if (node.right === null) return node.left;
    const successor = this.minimumNode(node.right);
    node.key = successor.key;
    node.right = remove(node.right, successor.key);
    if (node.right !== null) node.right.parent = node;
    return node;
  };
  if (this.search(key) === null) return false;
  this.root = remove(this.root, key);
  if (this.root !== null) this.root.parent = null;
  this.size -= 1;
  return true;
}
```

When the target is found and the left child is `null`, the function returns the right child, which may itself be `null`. That covers the leaf and the only-right-child cases. Returning the left child covers the only-left-child case. The two-child branch copies the successor's key and then removes that key from the right subtree only. The search for the successor key starts at `node.right`, so it cannot land on `node`, which now holds the same key but is not inside that subtree. After the recursive return, the parent of the surviving right child is rewritten, because the child may have been promoted from deeper in the subtree.

The laboratory runs this recursive deletion through the same three cases as the pointer-surgery deletion and checks the invariant afterward.

## 6.3 Full trace of the two-child case

Delete $4$ from the working tree. The node $z$ is the node holding $4$. It has a left child $2$ and a right child $8$, so this is the two-child case.

The successor $s$ is the minimum of the subtree at $8$. Follow left children: $8$ to $6$, and $6$ has no left child. So $s$ is the node holding $6$. That node has no left child and one right child, the node holding $7$. The "at most one child" claim is visible here: the right child is $7$, and there is no left child to dispose of.

Copy the key. The node object that held $4$ now holds $6$. The tree temporarily contains two nodes labeled $6$: this one, and $s$.

Unlink $s$. `transplant(s, s.right)` sees that $s$ is the left child of $8$ and writes the node $7$ into `8.left`. It then sets the parent of $7$ to $8$. `detach` clears the fields of $s$.

The live tree is:

```text
            10
          /    \
        6        15
       / \      /
      2   8    12
         /
        7
```

Read the pointers, because this is the check that catches a swapped child.

- The root is still the same node object, key $10$, parent `null`, left child the node that used to hold $4$ and now holds $6$, right child $15$.
- That node has key $6$, parent $10$, left child $2$, right child $8$.
- The node $2$ has parent equal to that same node.
- The node $8$ has parent equal to that same node, left child $7$, right child `null`.
- The node $7$ has parent $8$ and two `null` children.
- The old node object of $6$ has parent `null` and is not reachable from the root.
- `size` is $7$.
- The inorder sequence is $2, 6, 7, 8, 10, 12, 15$.

**Invariant after the call.** The strict search property holds: the left subtree of the new key $6$ is $\{2\}$, and $2 < 6$; the right subtree is $\{8, 7\}$, both $> 6$; the rest of the tree was already legal and lost only the key $4$, which was smaller than $10$ and smaller than every key that remains on the right of $10$. Parent pointers on the live nodes match the child pointers. The detached successor is not a live node. `size` equals the live node count. Inorder is strictly increasing. The key $4$ is absent, and every other original key is present exactly once.

**Theorem (two-child deletion maintains the strict property).** After the copy and the unlinking of $s$, the live tree satisfies the strict search property.

**Proof.** Write $z$ for the surviving node and $k$ for the key it held before the copy. The new key is $s.\mathrm{key}$. The left subtree of $z$ is unchanged, and every key there was $< k$. Case 1 of the successor theorem says $s.\mathrm{key}$ is the least key $> k$, so every left-subtree key is $< s.\mathrm{key}$. The right subtree of $z$, with $s$ removed, used to have $s$ as its minimum, so every remaining key there is $> s.\mathrm{key}$.

Consider an ancestor $a$ that contained $z$ in its left subtree, so $a.\mathrm{key} > k$. The key $a.\mathrm{key}$ cannot lie strictly between $k$ and $s.\mathrm{key}$, because $s$ is the successor of the old node. It also cannot equal $s.\mathrm{key}$, because keys are distinct and $s$ is in the right subtree of $z$, not at $a$. Thus $a.\mathrm{key} > s.\mathrm{key}$, and $z$ is still legally in the left subtree of $a$. Consider an ancestor $a$ that contained $z$ in its right subtree, so $a.\mathrm{key} < k < s.\mathrm{key}$. The node $z$ remains in that right subtree and is still legally there. Subtrees that do not contain $z$ are unchanged. $\square$

## 6.4 The other two cases, on the tree the two-child deletion left behind

The laboratory continues on the same tree so that each case is a concrete pointer change.

**No child.** Delete $12$. The node $12$ is a leaf, and it is the left child of $15$. `transplant` writes `null` into `15.left`. The node $15$ now has two `null` children. Inorder is $2, 6, 7, 8, 10, 15$. Size is $6$.

```text
            10
          /    \
        6        15
       / \
      2   8
         /
        7
```

**One child, and the child is a left child.** Delete $8$. The node $8$ has a left child $7$ and a `null` right child. `transplant` sees that $8$ is the right child of the node holding $6$, and it writes $7$ into that right-child pointer. It sets the parent of $7$ to the node holding $6$. Inorder is $2, 6, 7, 10, 15$. Size is $5$.

```text
            10
          /    \
        6        15
       / \
      2   7
```

**One child, and the child is a right child.** This side is a different branch of the code, the branch `z.left === null`. The laboratory builds $5, 3, 4$.

```text
    5
   /
  3
   \
    4
```

Delete $3$. The only child is the right child $4$. `transplant` writes $4$ into `5.left` and sets the parent of $4$ to $5$. The result is $5$ with left child $4$. A bug that always promotes `z.left` would write `null` here and lose $4$.

**The root.** Deleting the only node of a one-node tree sets the root to `null` and the height to $-1$. Deleting the root of a tree whose root has one child makes that child the root, with parent `null`. Deleting the root when it has two children copies the successor onto the root object and unlinks the successor. The laboratory's instance is the insertion order $9, 7, 11, 8$.

```text
      9
     / \
    7   11
     \
      8
```

The successor of $9$ is the minimum of the right subtree, which is $11$ itself, a leaf. After the copy, the root object holds $11$, its right child is `null`, and its left subtree $7$ with right child $8$ is untouched. Inorder is $7, 8, 11$. This is the subcase in which the successor is the right child, so `transplant` writes `successor.right`, which is `null`, directly into `z.right`.

## 6.5 Cost

Finding the node is a search, $\Theta(h)$ in the worst case on that tree. Finding the successor from a node is $O(h)$. The pointer writes are a constant number. Deletion is therefore $\Theta(h)$ in the worst case on a tree of height $h$. It is $\Theta(n)$ on a chain and $\Theta(\log n)$ on a tree whose height is $\lfloor \log n \rfloor$. Part 7 says which trees those are.

---

# Part 7. Skewed height, best-case height, and a randomly built tree

## 7.1 Height, carried forward from Lecture 07

The empty tree has height $-1$. A leaf has height $0$. The height of a nonempty node is one plus the larger height of its two subtrees. The depth of the root is $0$. These conventions are mandatory in the rest of the course. In particular, a chain of $n$ nodes has height $n-1$, because each added child increases the height by one, and the single-node tree starts at height $0$.

```javascript
height(node = this.root) {
  if (node === null) return -1;
  return 1 + Math.max(this.height(node.left), this.height(node.right));
}
```

## 7.2 How many nodes a given height can hold

**Theorem (maximum nodes).** A binary tree of height $h$ has at most $2^{h+1} - 1$ nodes.

**Proof.** Strong induction on $h$. If $h = -1$, the tree is empty and has $0$ nodes, and $2^{0} - 1 = 0$. Suppose $h \ge 0$ and the claim holds for every height strictly less than $h$. A tree of height $h$ is a root plus two subtrees of height at most $h - 1$. A subtree of height $t \le h - 1$ has at most $2^{t+1} - 1$ nodes by the inductive hypothesis, and $2^{t+1} - 1 \le 2^{h} - 1$. Each subtree therefore has at most $2^{h} - 1$ nodes. The total is at most

$$
1 + 2(2^{h} - 1) = 2^{h+1} - 1.
$$

$\square$

**Theorem (best-case height).** Every binary tree with $n \ge 1$ nodes has height at least $\lfloor \log n \rfloor$, and this bound is tight.

**Proof.** Let $h$ be the height. The previous theorem gives $n \le 2^{h+1} - 1$, so $2^{h+1} \ge n + 1$, so $h + 1 \ge \log(n + 1)$, so $h \ge \lceil \log(n + 1) \rceil - 1$. The identity $\lceil \log(n + 1) \rceil - 1 = \lfloor \log n \rfloor$ for every integer $n \ge 1$ finishes the lower bound. Let $k = \lfloor \log n \rfloor$, which means $2^{k} \le n \le 2^{k+1} - 1$. Then $2^{k} + 1 \le n + 1 \le 2^{k+1}$. If $n = 2^{k+1} - 1$, then $n + 1 = 2^{k+1}$ and $\lceil \log(n + 1) \rceil - 1 = k$. If $2^{k} \le n \le 2^{k+1} - 2$, then $k < \log(n + 1) < k + 1$, so the ceiling is $k + 1$ and the ceiling minus one is $k$.

The bound is achieved by building a complete tree: repeatedly insert the middle key of the remaining interval, then the middle of each side. For $n = 7$ the order $4, 2, 6, 1, 3, 5, 7$ has height $2 = \lfloor \log 7 \rfloor$. $\square$

A search on a tree of height $h$ compares at most $h + 1$ keys, because a root-to-node path contains at most $h + 1$ nodes. On a tree whose height is $\lfloor \log n \rfloor$, that quantity is $\Theta(\log n)$.

## 7.3 Sorted insertion produces a chain

Insert $1, 2, 3, 4, 5$ into an empty tree, in that order. Each new key is larger than every key already stored, so each search goes right at every node and attaches a right child.

```text
1
 \
  2
   \
    3
     \
      4
       \
        5
```

The tree is a right spine. There are $5$ nodes. The leaf $5$ has height $0$, and each parent adds one, so the height is $4 = 5 - 1$. In the general case, inserting $1, 2, \ldots, n$ in increasing order produces a right spine of $n$ nodes and height $n - 1$.

Search for $5$ compares $1, 2, 3, 4, 5$. That is $n$ comparisons. Search for $6$, which is larger than every key, compares the same five nodes and then follows the right `null` of $5$. Search for $0$ compares $1$ and follows the left `null` of the root. The worst-case search on this tree is $\Theta(n)$. Inserting $6$ performs five comparisons and one pointer write, also $\Theta(n)$. The best-case height for $n = 5$ is $\lfloor \log 5 \rfloor = 2$, and this tree does not have that height.

This example is the reason a binary search tree, by itself, does not guarantee logarithmic search. The operations are $\Theta(h)$, and $h$ is a property of the insertion history. Sorted insertion is a legal history. Lecture 09 owns the repairs that keep $h = O(\log n)$ after every insertion: AVL rotations, and the red–black insertion that Lecture 09 also teaches. This lecture stops at the chain and does not rotate it.

Decreasing insertion produces a left spine of the same height. Any insertion order that always extends the current longest path can reach height $n - 1$. The sorted order is simply the one you can see at a glance.

## 7.4 Random insertion

The chain is the worst case. The complete tree is the best case. The average over insertion orders sits much closer to the best case, under a model that has to be stated before the bound is used.

**Definition (randomly built).** A randomly built binary search tree on $n$ distinct keys is the tree produced by inserting those keys into an empty tree in random order, where each of the $n!$ permutations is equally likely. The model contains insertions only. It does not contain deletions.

This is a statement about the input order. It is not the statement that every distinct tree shape is equally likely. Those two distributions differ, and the theorem below uses the permutation model.

**Theorem (stated, CLRS).** The expected height of a randomly built binary search tree on $n$ distinct keys is $O(\log n)$.

The source is Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 3rd edition, Section 12.4, "Randomly built binary search trees." They write $\lg$ for the base-2 logarithm; this course writes $\log$. The 4th edition's Chapter 12 still specifies the binary search tree and its operations, and the 4th edition's preface records that the randomly built analysis was removed from the main text. This lecture does not reproduce the $O(\log n)$ argument. There is no short substitute hiding in the examples above. Inventing a two-line "proof" that the average height is logarithmic would skip the step that makes the claim true.

The matching lower bound is not that argument. It is the best-case theorem of Section 7.2 applied inside the expectation.

**Theorem.** The expected height of a randomly built binary search tree on $n \ge 1$ distinct keys is $\Theta(\log n)$.

**Proof of the direction this lecture owns, and citation of the other.** Let $H$ be the height. Section 7.2 shows $H \ge \lfloor \log n \rfloor$ for every binary tree, so $E[H] \ge \lfloor \log n \rfloor$, and therefore $E[H] = \Omega(\log n)$. The $O(\log n)$ bound on $E[H]$ is the theorem stated from CLRS and is not proved here. An expectation that is both $O(\log n)$ and $\Omega(\log n)$ is $\Theta(\log n)$. $\square$

Two remarks keep the theorem inside its hypothesis.

First, the height is the maximum depth. The average depth of a node, which governs the average cost of a successful search, is a smaller quantity and is also $\Theta(\log n)$. Sedgewick and Wayne, Section 3.2, state that a successful search in a tree built from random distinct keys uses about $2 \ln n$ comparisons, which is about $1.39 \log n$. That average-depth result is cited, not proved, in this lecture. Reed, *Journal of the ACM*, 2003, gives a sharper asymptotic for the expected height itself, of the form $\alpha \ln n - \beta \ln \ln n + O(1)$. That proof is outside this course. Both refinements agree with the $\Theta(\log n)$ bound. Neither turns it into a worst-case bound.

Second, CLRS notes that once deletions are mixed with insertions, this analysis no longer describes the height. A single deletion on a randomly built tree cannot increase the height, so one deletion still costs $O(H)$ with $E[H] = \Theta(\log n)$. A long sequence of arbitrary insertions and deletions is a different process. Do not quote the theorem for that process. If the application needs $O(\log n)$ after every update, including adversarial ones, the structure is the balanced tree of Lecture 09.

On the working tree, $n = 8$ and the height is $4$. The best-case height is $\lfloor \log 8 \rfloor = 3$. The sorted-insertion height is $7$. The tree you get depends on the order, and $4$ is simply what this order did.

---

# Part 8. The sorted array as the same map

## 8.1 The representation

The inorder sequence of a binary search tree is the sorted list of its keys. Storing that list in an array, and keeping the array sorted after every update, implements the same ordered set. Lecture 05 supplies binary search. Lecture 02 supplies the fact that opening a hole in a contiguous array moves every later entry.

The laboratory class `SortedArraySet` stores the keys in an array. Search keeps the closed interval from `lo` to `hi` and probes `mid = Math.floor((lo + hi) / 2)`. Insertion binary-searches, rejects a hit, and otherwise splices the key at the insertion index. The number of moved entries is the number of keys that sat at that index or to its right.

On the keys $1, 2, 3, 4, 5, 6, 7$, binary search for $5$ probes $4, 6, 5$, matching the balanced tree. Inserting $0$ moves $7$ entries and yields $[0, 1, 2, 3, 4, 5, 6, 7]$. Inserting a duplicate $4$ is rejected.

## 8.2 The comparison

Heights and expectations below use the definitions of Part 7. The column "expected, random insertion" applies to a binary search tree built by the permutation model, insertions only. It does not apply to a mixed delete workload, and it does not apply to the sorted array, whose shape does not depend on insertion order.

| Operation | Sorted array, worst case | BST, on a tree of height $h$ | BST, worst tree | BST, expected under random insertion |
| --- | --- | --- | --- | --- |
| search | $\Theta(\log n)$ | $\Theta(h)$ | $\Theta(n)$ | $\Theta(\log n)$ |
| insert | $\Theta(n)$ | $\Theta(h)$ | $\Theta(n)$ | $\Theta(\log n)$ |
| delete | $\Theta(n)$ | $\Theta(h)$ | $\Theta(n)$ | $\Theta(\log n)$ for one deletion on a randomly built tree |
| minimum | $\Theta(1)$ | $\Theta(h)$ | $\Theta(n)$ | $\Theta(\log n)$ |
| maximum | $\Theta(1)$ | $\Theta(h)$ | $\Theta(n)$ | $\Theta(\log n)$ |
| successor, given a located key | $\Theta(1)$ | $\Theta(h)$ | $\Theta(n)$ | $\Theta(\log n)$ |
| inorder listing of all keys | $\Theta(n)$ | $\Theta(n)$ | $\Theta(n)$ | $\Theta(n)$ |

Reading the table as a design choice: if the set is built once and then only searched, the sorted array gives $\Theta(\log n)$ search with a tiny constant and $\Theta(1)$ minimum. If the set is updated by inserting arbitrary keys and the insertion order is not adversarial, the tree inserts in expected $\Theta(\log n)$ and the array inserts in $\Theta(n)$. If the insertion order may be sorted, the tree falls back to $\Theta(n)$ and the guarantee has to come from Lecture 09, or you keep the array and pay $\Theta(n)$ per insert on purpose because the code is simpler and $n$ is small.

Successor makes the representation difference sharp. Given a node, the tree successor climbs or takes a minimum, and the cost follows the height. Given an index in the sorted array, the successor is the next index, which is $\Theta(1)$. Finding that index from a key is binary search, $\Theta(\log n)$. The ordered-set operation "successor of this key" is therefore $\Theta(\log n)$ in the array as well, unless the caller already holds the index.

---

# Part 9. k-d trees

## 9.1 What is being generalized

A binary search tree cuts the line of keys at one value. A point in the plane has two coordinates, and a query is often a rectangle rather than a single key. A k-d tree, introduced by Bentley in 1975, keeps the binary-tree walk and changes the comparison. The coordinate that is compared alternates with the depth. This section builds the two-dimensional case only. It implements insert, exact-match search, and an orthogonal range query. It does not balance the tree, and it does not teach range trees or fractional cascading.

**Duplicate policy, continued.** A point equal in both coordinates is rejected. Points that share one coordinate and differ in the other are different keys and are both stored.

## 9.2 The alternating cut

The depth of the root is $0$. At a node of even depth the cutting coordinate is $x$. At a node of odd depth the cutting coordinate is $y$. In $d$ dimensions the cutting coordinate would be $\mathrm{depth} \bmod d$. This lecture keeps $d = 2$, so the test is $\mathrm{depth} \bmod 2$.

The child rule matches the binary search tree, with the chosen coordinate in place of the key.

- If the new point's cutting coordinate is $<$ the node's cutting coordinate, the point goes left.
- If the new point's cutting coordinate is $\ge$ the node's cutting coordinate, the point goes right.
- If both coordinates equal the node's point, insertion returns false.

The left subtree therefore contains only points whose cutting coordinate is strictly less than the node's. The right subtree contains only points whose cutting coordinate is greater than or equal to the node's. Equal cutting coordinates go right, which is what makes exact search deterministic: when the cutting coordinates match and the points do not, there is exactly one side left to search.

A node stores `x`, `y`, `left`, and `right`. It does not store a parent. Depth is computed from the walk, not stored, so a node moved to a different depth would be interpreted with the wrong axis. This lecture never moves a k-d node after insertion.

## 9.3 Insert and exact search

```javascript
insert(x, y) {
  if (this.root === null) {
    this.root = new KDNode(x, y);
    this.size = 1;
    return true;
  }
  let node = this.root;
  let depth = 0;
  while (true) {
    if (node.x === x && node.y === y) return false;
    const axis = depth % 2;
    const nodeCoord = axis === 0 ? node.x : node.y;
    const pointCoord = axis === 0 ? x : y;
    if (pointCoord < nodeCoord) {
      if (node.left === null) {
        node.left = new KDNode(x, y);
        this.size += 1;
        return true;
      }
      node = node.left;
    } else {
      if (node.right === null) {
        node.right = new KDNode(x, y);
        this.size += 1;
        return true;
      }
      node = node.right;
    }
    depth += 1;
  }
}
```

Exact search uses the same walk. At each node it tests both coordinates first. If the cutting coordinates are equal and the points differ, the `>=` rule sends the search right.

```javascript
contains(x, y) {
  let node = this.root;
  let depth = 0;
  while (node !== null) {
    if (node.x === x && node.y === y) return true;
    const axis = depth % 2;
    const nodeCoord = axis === 0 ? node.x : node.y;
    const pointCoord = axis === 0 ? x : y;
    node = pointCoord < nodeCoord ? node.left : node.right;
    depth += 1;
  }
  return false;
}
```

**Theorem (exact search).** `contains(x, y)` returns true if and only if that point was inserted and not rejected as a duplicate.

**Proof.** Insertion places a new point at the end of the unique walk determined by the coordinate tests, so the point occupies one node on that walk. Search follows the same tests. When it is sitting on the node, both coordinates match and it returns true. Suppose the point is not at the current node. If the query's cutting coordinate is $<$ the node's, every point in the right subtree has cutting coordinate $\ge$ the node's and therefore $>$ the query's cutting coordinate, so the query point is not in the right subtree. If the query's cutting coordinate is $>$ the node's, every point in the left subtree has cutting coordinate $<$ the node's and the query point is not there. If the cutting coordinates are equal and the full points differ, every point in the left subtree has a strictly smaller cutting coordinate, so the query point is not on the left; the insertion rule placed every later point with this cutting coordinate on the right. In every non-hit case the search steps to the only side that can still hold the point, or to `null`, which correctly reports absence. $\square$

## 9.4 The traced point set

Insert, in this order, $(7, 2)$, $(5, 4)$, $(9, 6)$, $(2, 3)$, $(4, 7)$, $(8, 1)$.

| Point | Walk | Where it lands | Depth | Axis at the new node |
| --- | --- | --- | --- | --- |
| $(7, 2)$ | empty tree | root | $0$ | $x$ |
| $(5, 4)$ | at $(7, 2)$, $x$: $5 < 7$ | left of the root | $1$ | $y$ |
| $(9, 6)$ | at $(7, 2)$, $x$: $9 > 7$ | right of the root | $1$ | $y$ |
| $(2, 3)$ | $x$ at $(7, 2)$ goes left; $y$ at $(5, 4)$: $3 < 4$ | left of $(5, 4)$ | $2$ | $x$ |
| $(4, 7)$ | left at the root; $y$ at $(5, 4)$: $7 > 4$ | right of $(5, 4)$ | $2$ | $x$ |
| $(8, 1)$ | right at the root; $y$ at $(9, 6)$: $1 < 6$ | left of $(9, 6)$ | $2$ | $x$ |

```text
                  (7,2) x
                 /      \
          (5,4) y        (9,6) y
          /     \        /
   (2,3) x   (4,7) x  (8,1) x
```

A second insertion of $(5, 4)$ hits that node and returns false. Size stays $6$.

Exact search for $(4, 7)$: at $(7, 2)$ compare $x$, $4 < 7$, go left; at $(5, 4)$ compare $y$, $7 > 4$, go right; at $(4, 7)$ both coordinates match. Hit.

Exact search for $(4, 5)$, a miss that shares an $x$-coordinate with a stored point: left at $(7, 2)$ because $4 < 7$; right at $(5, 4)$ because $y$ gives $5 > 4$; at $(4, 7)$ the cutting coordinate $x$ is equal and the point is not $(4, 5)$, so the rule goes right. The right child is `null`. Miss. The search must not also explore the left child of $(4, 7)$. That child would contain points with $x < 4$, and the query has $x = 4$.

Exact search for $(9, 0)$: right at $(7, 2)$; at $(9, 6)$ compare $y$, $0 < 6$, go left; at $(8, 1)$ compare $x$, $9 > 8$, go right; `null`. Miss.

## 9.5 Orthogonal range search and the prune

A query is an axis-aligned closed rectangle $[x_{\mathrm{lo}}, x_{\mathrm{hi}}] \times [y_{\mathrm{lo}}, y_{\mathrm{hi}}]$. The algorithm visits a node, reports the point when both coordinates lie inside the rectangle, and then decides the two children from the cutting plane alone.

The cutting plane of a node is the vertical line $x = \mathrm{node}.x$ at even depth and the horizontal line $y = \mathrm{node}.y$ at odd depth. The left child owns the open half-plane of points whose cutting coordinate is $<$ the node's. The right child owns the closed half-plane of points whose cutting coordinate is $\ge$ the node's.

**Pruning rule.** If that half-plane misses the query rectangle, skip that child. Do not look at the keys stored below it. They cannot lie in the rectangle.

Let the cutting coordinate of the node be $c$, and let $[\ell, h]$ be the query interval on that same axis. The left half-plane meets $[\ell, h]$ exactly when $\ell < c$. The right half-plane meets $[\ell, h]$ exactly when $h \ge c$. The inequality on the right is not strict. A query that ends on the plane still has to search the right child, because points with cutting coordinate equal to $c$ were stored on the right, and a closed rectangle includes the plane.

The implementation records the prune decision before it descends, then walks the left side that survived, then the right side. The reported points come out in that visit order. The order is part of the laboratory's assertion, so a walk that swaps the children will fail even if the set of points is right.

```javascript
rangeQuery(xLo, xHi, yLo, yHi) {
  const points = [];
  const visited = [];
  const prunes = [];
  const walk = (node, depth) => {
    if (node === null) return;
    visited.push({ x: node.x, y: node.y });
    if (node.x >= xLo && node.x <= xHi && node.y >= yLo && node.y <= yHi) {
      points.push({ x: node.x, y: node.y });
    }
    const axis = depth % 2;
    const coord = axis === 0 ? node.x : node.y;
    const lo = axis === 0 ? xLo : yLo;
    const hi = axis === 0 ? xHi : yHi;
    const searchLeft = lo < coord;
    const searchRight = hi >= coord;
    if (!searchLeft) prunes.push({ x: node.x, y: node.y, side: "left", depth });
    if (!searchRight) prunes.push({ x: node.x, y: node.y, side: "right", depth });
    if (searchLeft) walk(node.left, depth + 1);
    if (searchRight) walk(node.right, depth + 1);
  };
  walk(this.root, 0);
  return { points, visited, prunes };
}
```

**Theorem (range correctness).** The points reported are exactly the stored points that lie in the closed rectangle.

**Proof.** Induction on the size of the subtree. The empty subtree reports nothing. At a node, the node's own point is reported exactly when it lies in the rectangle. Consider a stored point that lies in the rectangle and in the left subtree. Its cutting coordinate is $< c$. It also lies in $[\ell, h]$, so $\ell < c$ (a number cannot be both $\ge c$ and $< c$). The algorithm therefore searches the left subtree, and the inductive hypothesis reports the point. A stored point in the rectangle and in the right subtree has cutting coordinate $\ge c$ and $\le h$, so $h \ge c$ and the right subtree is searched. A point reported from a child subtree is in the rectangle by the inductive hypothesis. A point that is not in the rectangle is not the node's point and is not reported by either child. Skipping a side cannot drop a point in the rectangle, because such a point would force $\ell < c$ on the left or $h \ge c$ on the right. $\square$

The running time is proportional to the number of nodes visited. In the worst case the rectangle meets every plane that is tested and the walk visits every node, which is $\Theta(n)$. Pruning makes some queries visit fewer nodes. This lecture does not claim an $O(\sqrt{n})$ bound. That classical bound belongs to a balanced two-dimensional k-d tree, and the tree built here is not balanced.

## 9.6 A range trace that prunes a nonempty side

Query $[0, 3] \times [0, 4]$ on the traced tree. The only stored point inside it is $(2, 3)$. Check the others now so the trace has something to disagree with: $(7, 2)$ has $x = 7$, $(5, 4)$ has $x = 5$, $(9, 6)$ is outside both intervals, $(4, 7)$ has $y = 7$, and $(8, 1)$ has $x = 8$.

| Step | Node | Depth | Axis | $c$ | In the rectangle? | Left | Right |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | $(7, 2)$ | $0$ | $x$ | $7$ | no, $7 > 3$ | search, because $0 < 7$ | prune, because $3 \ge 7$ is false |
| 2 | $(5, 4)$ | $1$ | $y$ | $4$ | no, $5 > 3$ | search, because $0 < 4$ | search, because $4 \ge 4$ |
| 3 | $(2, 3)$ | $2$ | $x$ | $2$ | yes, report | $0 < 2$, child is `null` | $3 \ge 2$, child is `null` |
| 4 | $(4, 7)$ | $2$ | $x$ | $4$ | no | $0 < 4$, child is `null` | prune, because $3 \ge 4$ is false |

The right child of the root is $(9, 6)$, and $(8, 1)$ sits under it. Both are skipped because the plane $x = 7$ misses $[0, 3]$: the right half-plane is $x \ge 7$, and the query wants $x \le 3$. The nodes visited are $(7, 2)$, $(5, 4)$, $(2, 3)$, $(4, 7)$. The prune list, recorded before each descent, is the right side of $(7, 2)$ and then the right side of $(4, 7)$.

A second rectangle, $[4, 9] \times [1, 6]$, reports $(7, 2)$, $(5, 4)$, $(9, 6)$, and $(8, 1)$, in that visit order. It prunes the left side of $(2, 3)$ and the left side of $(4, 7)$. Those children are `null`, so the prune does not save a visit. The first rectangle is the one that shows the rule earning its keep.

## 9.7 The closed plane, on a one-coordinate tie

Insert $(0, 0)$, then $(0, 1)$. At the root the cutting coordinate is $x$. The second point has $x \ge 0$, so it becomes the right child. Exact search for $(0, 1)$ finds it. Exact search for $(0, -1)$ matches $x$ at the root, rejects the full point, goes right, and at $(0, 1)$ compares $y$: $-1 < 1$, goes left, and hits `null`.

The range query $[0, 0] \times [0, 1]$ contains both points. At the root, $\ell = 0$ and $c = 0$, so $\ell < c$ is false and the left side is pruned. The right side is searched because $h = 0 \ge 0$. The point $(0, 1)$ is reported. Replacing the right-hand test by $h > c$ would prune that side and lose a point that lies on the splitting plane. The laboratory asserts both points and the left prune.

## 9.8 The curse of dimensionality, in one paragraph

A k-d tree built by insertion has no balance guarantee. Sorted insertion by the first coordinate produces a chain, and exact search on that chain is linear, for the same reason as in Part 7. Orthogonal range search skips a child only when the query interval misses that child's half-plane, and each node cuts only one axis. In a higher dimension the algorithm alternates among more axes, so a query region that is small in every coordinate still crosses the cutting plane at many nodes and is sent down both children. Nearest-neighbor search, which this lecture does not implement, has the same weakness: more dimensions give the current best distance more cells that it cannot yet reject. The walk tends toward a scan of the whole set as the dimension grows. That degradation is the curse of dimensionality. The structure in this section is a correct two-dimensional search tree with a prune rule. It is not a balanced worst-case structure, and it is not the remedy for high-dimensional nearest neighbor.

---

# Part 10. When a binary search tree is the wrong tool

The operations of this lecture cost $\Theta(h)$ on the tree you have. Choose a different structure when the operation mix is not the one a binary search tree buys.

**You need $O(\log n)$ after every insertion, including sorted insertion.** The chain of Part 7 is a legal input. The repair is a balanced search tree. Lecture 09 owns AVL rotations, red–black insertion, and the B-tree and 2–3–4 families. Do not add a rotation in the code of this lecture and call the problem solved. The invariant of a balanced tree is a different invariant.

**You need only the minimum, or only the maximum, and you do not need successor or an inorder listing.** A binary heap, Lecture 10, returns the minimum in $\Theta(1)$ after the root is read and restores the heap in $O(\log n)$. It does not keep the search property, and an inorder walk of a heap is not the sorted order. Paying for a search tree in order to read one extreme is the wrong purchase.

**The keys are hashable and no operation uses the order.** You never ask for a successor, a range, or the minimum. Lecture 11's hash table, under the simple uniform hashing assumption, supports search and insert in expected constant time. A binary search tree spends comparisons on an order the client does not use. If the client later asks for the keys in sorted order, the hash table cannot answer from its structure, and the search tree, or the sorted array, becomes the right tool again.

A short set that is built once and searched many times can stay in the sorted array of Part 8. A two-dimensional rectangle query on a few dozen points can use the k-d tree of Part 9. A high-dimensional nearest-neighbor workload should not expect that k-d tree to stay fast, for the reason in Section 9.8.

---

# Laboratory

Work the traces with a pencil before you read the program. The program checks these same numbers and throws if a pointer differs.

## Guided trace A — the working tree

Build the tree by inserting $10, 4, 15, 2, 12$, then $8$, then $6$, then $7$. After $8$, the right child of $4$ is $8$. After $6$, the left child of $8$ is $6$. After $7$, the right child of $6$ is $7$. Inorder is $2, 4, 6, 7, 8, 10, 12, 15$. Search for $6$ compares $10, 4, 8, 6$. Search for $9$ compares $10, 4, 8$ and stops at `null`.

Successor of $4$ is $6$, by case 1. Successor of $7$ is $8$, by case 2: climb from the right child of $6$ to the left child of $8$.

## Guided trace B — delete $4$, then a leaf, then a one-child node

Copy $6$ onto the node that holds $4$. Unlink the old node $6$ by making $7$ the left child of $8$. The node object of $4$ now holds $6$. Its left child is $2$ and its right child is $8$. The old node $6$ is unreachable. Inorder is $2, 6, 7, 8, 10, 12, 15$.

Delete the leaf $12$. The left child of $15$ becomes `null`. Delete $8$, which has only the left child $7$. The right child of the node holding $6$ becomes $7$, and the parent of $7$ becomes that node. Inorder is $2, 6, 7, 10, 15$.

## Guided trace C — the chain and the balanced probes

Insert $1, 2, 3, 4, 5$ in order. Height is $4$. Search for $5$ compares all five keys. Search for $6$ compares all five and stops at `null`. Search for $0$ compares $1$ and stops at `null`.

Insert $4, 2, 6, 1, 3, 5, 7$. Height is $2$. Search for $5$ compares $4, 6, 5$. Binary search on $[1, 2, 3, 4, 5, 6, 7]$ probes the same three keys. Inserting $0$ into that array moves $7$ entries.

## Guided trace D — the k-d rectangle

On the points of Part 9, the rectangle $[0, 3] \times [0, 4]$ reports $(2, 3)$ only. It visits $(7, 2)$, $(5, 4)$, $(2, 3)$, $(4, 7)$. It prunes the right side of $(7, 2)$ and the right side of $(4, 7)$. It does not visit $(9, 6)$ or $(8, 1)$.

## Problems to do before you read the program

The program does not contain these three answers. Check them against the definitions, then optionally add assertions of your own.

1. Into the original eight-key working tree, insert $11$. Name its parent and which child it is. Write the new inorder sequence.
2. From that same original tree, delete $15$. Draw the tree and write the inorder sequence. Which of the three deletion cases is this?
3. On the traced k-d tree, take the rectangle $[6, 8] \times [0, 2]$. Does the pruning rule skip the left subtree of the root? List the points the query reports.

Save the program under the next heading as `lesson-08-lab.mjs` and run `node lesson-08-lab.mjs`. It prints `ALL TESTS PASSED` or throws.

## LABORATORY PROGRAM

```javascript
import assert from "node:assert/strict";

class BSTNode {
  constructor(key) {
    this.key = key;
    this.left = null;
    this.right = null;
    this.parent = null;
  }
}

class BinarySearchTree {
  constructor() {
    this.root = null;
    this.size = 0;
  }

  search(key) {
    let current = this.root;
    while (current !== null && current.key !== key) {
      if (key < current.key) current = current.left;
      else current = current.right;
    }
    return current;
  }

  searchPath(key) {
    const path = [];
    let current = this.root;
    while (current !== null) {
      path.push(current.key);
      if (key === current.key) return { found: true, path };
      current = key < current.key ? current.left : current.right;
    }
    return { found: false, path };
  }

  searchRecursive(key) {
    const walk = (node) => {
      if (node === null || node.key === key) return node;
      if (key < node.key) return walk(node.left);
      return walk(node.right);
    };
    return walk(this.root);
  }

  insert(key) {
    let parent = null;
    let current = this.root;
    while (current !== null) {
      parent = current;
      if (key === current.key) return false;
      if (key < current.key) current = current.left;
      else current = current.right;
    }
    const node = new BSTNode(key);
    node.parent = parent;
    if (parent === null) this.root = node;
    else if (key < parent.key) parent.left = node;
    else parent.right = node;
    this.size += 1;
    return true;
  }

  minimumNode(node) {
    let current = node;
    while (current.left !== null) current = current.left;
    return current;
  }

  maximumNode(node) {
    let current = node;
    while (current.right !== null) current = current.right;
    return current;
  }

  minimum() {
    if (this.root === null) return null;
    return this.minimumNode(this.root).key;
  }

  maximum() {
    if (this.root === null) return null;
    return this.maximumNode(this.root).key;
  }

  successor(node) {
    if (node === null) return null;
    if (node.right !== null) return this.minimumNode(node.right);
    let current = node;
    let parent = node.parent;
    while (parent !== null && current === parent.right) {
      current = parent;
      parent = parent.parent;
    }
    return parent;
  }

  predecessor(node) {
    if (node === null) return null;
    if (node.left !== null) return this.maximumNode(node.left);
    let current = node;
    let parent = node.parent;
    while (parent !== null && current === parent.left) {
      current = parent;
      parent = parent.parent;
    }
    return parent;
  }

  successorByKey(key) {
    let current = this.root;
    let candidate = null;
    while (current !== null) {
      if (key < current.key) {
        candidate = current;
        current = current.left;
      } else if (key > current.key) {
        current = current.right;
      } else if (current.right !== null) {
        return this.minimumNode(current.right).key;
      } else {
        return candidate === null ? null : candidate.key;
      }
    }
    return null;
  }

  predecessorByKey(key) {
    let current = this.root;
    let candidate = null;
    while (current !== null) {
      if (key > current.key) {
        candidate = current;
        current = current.right;
      } else if (key < current.key) {
        current = current.left;
      } else if (current.left !== null) {
        return this.maximumNode(current.left).key;
      } else {
        return candidate === null ? null : candidate.key;
      }
    }
    return null;
  }

  transplant(u, v) {
    if (u.parent === null) this.root = v;
    else if (u === u.parent.left) u.parent.left = v;
    else u.parent.right = v;
    if (v !== null) v.parent = u.parent;
  }

  detach(u) {
    u.left = null;
    u.right = null;
    u.parent = null;
  }

  deleteNode(z) {
    if (z.left === null && z.right === null) {
      this.transplant(z, null);
      this.detach(z);
      return;
    }
    if (z.left === null) {
      this.transplant(z, z.right);
      this.detach(z);
      return;
    }
    if (z.right === null) {
      this.transplant(z, z.left);
      this.detach(z);
      return;
    }
    const successor = this.minimumNode(z.right);
    z.key = successor.key;
    this.transplant(successor, successor.right);
    this.detach(successor);
  }

  delete(key) {
    const node = this.search(key);
    if (node === null) return false;
    this.deleteNode(node);
    this.size -= 1;
    return true;
  }

  deleteRecursive(key) {
    const remove = (node, target) => {
      if (node === null) return null;
      if (target < node.key) {
        node.left = remove(node.left, target);
        if (node.left !== null) node.left.parent = node;
        return node;
      }
      if (target > node.key) {
        node.right = remove(node.right, target);
        if (node.right !== null) node.right.parent = node;
        return node;
      }
      if (node.left === null) return node.right;
      if (node.right === null) return node.left;
      const successor = this.minimumNode(node.right);
      node.key = successor.key;
      node.right = remove(node.right, successor.key);
      if (node.right !== null) node.right.parent = node;
      return node;
    };
    if (this.search(key) === null) return false;
    this.root = remove(this.root, key);
    if (this.root !== null) this.root.parent = null;
    this.size -= 1;
    return true;
  }

  height(node = this.root) {
    if (node === null) return -1;
    return 1 + Math.max(this.height(node.left), this.height(node.right));
  }

  inorder(node = this.root, out = []) {
    if (node === null) return out;
    this.inorder(node.left, out);
    out.push(node.key);
    this.inorder(node.right, out);
    return out;
  }
}

function strictSearchProperty(node, lower, upper) {
  if (node === null) return true;
  if (lower !== null && node.key <= lower) return false;
  if (upper !== null && node.key >= upper) return false;
  return (
    strictSearchProperty(node.left, lower, node.key) &&
    strictSearchProperty(node.right, node.key, upper)
  );
}

function assertInvariant(tree) {
  if (tree.root !== null) assert.equal(tree.root.parent, null);
  const seen = new Set();
  const walk = (node, parent) => {
    if (node === null) return;
    assert.equal(node.parent, parent);
    assert.equal(seen.has(node), false);
    seen.add(node);
    walk(node.left, node);
    walk(node.right, node);
  };
  walk(tree.root, null);
  assert.equal(seen.size, tree.size);
  assert.equal(strictSearchProperty(tree.root, null, null), true);
  const keys = tree.inorder();
  const sorted = [...keys].sort((a, b) => a - b);
  assert.deepEqual(keys, sorted);
  for (let i = 1; i < keys.length; i += 1) assert.ok(keys[i - 1] < keys[i]);
}

function reachable(tree, target) {
  const walk = (node) => {
    if (node === null) return false;
    if (node === target) return true;
    return walk(node.left) || walk(node.right);
  };
  return walk(tree.root);
}

function build(keys) {
  const tree = new BinarySearchTree();
  for (const key of keys) assert.equal(tree.insert(key), true);
  return tree;
}

const empty = new BinarySearchTree();
assert.equal(empty.search(1), null);
assert.equal(empty.minimum(), null);
assert.equal(empty.maximum(), null);
assert.equal(empty.delete(1), false);
assert.equal(empty.height(), -1);
assert.deepEqual(empty.inorder(), []);
assert.equal(empty.size, 0);

const shape = new BinarySearchTree();
for (const key of [10, 4, 15, 2, 12]) assert.equal(shape.insert(key), true);
assert.equal(shape.insert(8), true);
assert.equal(shape.search(4).right.key, 8);
assert.equal(shape.search(8).parent.key, 4);
assert.equal(shape.insert(6), true);
assert.equal(shape.search(8).left.key, 6);
assert.equal(shape.search(6).parent.key, 8);
assert.equal(shape.insert(7), true);
assert.equal(shape.search(6).right.key, 7);
assert.equal(shape.search(7).parent.key, 6);
assert.equal(shape.insert(8), false);
assert.equal(shape.size, 8);
assertInvariant(shape);

const tree = shape;
assert.deepEqual(tree.inorder(), [2, 4, 6, 7, 8, 10, 12, 15]);
assert.equal(tree.minimum(), 2);
assert.equal(tree.maximum(), 15);
assert.equal(tree.height(), 4);

const hit = tree.searchPath(6);
assert.deepEqual(hit, { found: true, path: [10, 4, 8, 6] });
assert.equal(tree.searchRecursive(6).key, 6);
const miss = tree.searchPath(9);
assert.deepEqual(miss, { found: false, path: [10, 4, 8] });
assert.equal(tree.search(9), null);
assert.equal(tree.searchRecursive(9), null);
assert.deepEqual(tree.searchPath(1), { found: false, path: [10, 4, 2] });
assert.deepEqual(tree.searchPath(14), { found: false, path: [10, 15, 12] });
assert.deepEqual(tree.searchPath(15), { found: true, path: [10, 15] });

const node2 = tree.search(2);
const node4 = tree.search(4);
const node6 = tree.search(6);
const node7 = tree.search(7);
const node8 = tree.search(8);
const node10 = tree.search(10);
const node12 = tree.search(12);
const node15 = tree.search(15);

assert.equal(tree.successor(node4), node6);
assert.equal(tree.successor(node6), node7);
assert.equal(tree.successor(node7), node8);
assert.equal(tree.successor(node8), node10);
assert.equal(tree.successor(node2), node4);
assert.equal(tree.successor(node12), node15);
assert.equal(tree.successor(node15), null);
assert.equal(tree.successorByKey(4), 6);
assert.equal(tree.successorByKey(7), 8);
assert.equal(tree.successorByKey(8), 10);
assert.equal(tree.successorByKey(15), null);
assert.equal(tree.successorByKey(9), null);
assert.equal(tree.predecessor(node7), node6);
assert.equal(tree.predecessor(node6), node4);
assert.equal(tree.predecessor(node8), node7);
assert.equal(tree.predecessor(node2), null);
assert.equal(tree.predecessorByKey(7), 6);
assert.equal(tree.predecessorByKey(6), 4);
assert.equal(tree.predecessorByKey(2), null);
assert.equal(tree.predecessorByKey(9), null);

assert.equal(tree.delete(4), true);
assert.equal(node4.key, 6);
assert.equal(tree.search(4), null);
assert.equal(node4.left, node2);
assert.equal(node4.right, node8);
assert.equal(node2.parent, node4);
assert.equal(node8.parent, node4);
assert.equal(node8.left, node7);
assert.equal(node7.parent, node8);
assert.equal(node7.left, null);
assert.equal(node7.right, null);
assert.equal(reachable(tree, node6), false);
assert.equal(node6.parent, null);
assert.equal(tree.size, 7);
assert.deepEqual(tree.inorder(), [2, 6, 7, 8, 10, 12, 15]);
assertInvariant(tree);

assert.equal(tree.delete(12), true);
assert.equal(node15.left, null);
assert.equal(node15.right, null);
assert.equal(reachable(tree, node12), false);
assert.equal(node12.parent, null);
assert.equal(tree.size, 6);
assert.deepEqual(tree.inorder(), [2, 6, 7, 8, 10, 15]);
assertInvariant(tree);

assert.equal(tree.delete(8), true);
assert.equal(node4.right, node7);
assert.equal(node7.parent, node4);
assert.equal(node7.left, null);
assert.equal(reachable(tree, node8), false);
assert.equal(tree.size, 5);
assert.deepEqual(tree.inorder(), [2, 6, 7, 10, 15]);
assertInvariant(tree);

assert.equal(tree.delete(99), false);
assert.equal(tree.size, 5);

const rightOnly = build([5, 3, 4]);
const rightParent = rightOnly.search(5);
const rightMiddle = rightOnly.search(3);
const rightChild = rightOnly.search(4);
assert.equal(rightOnly.delete(3), true);
assert.equal(rightParent.left, rightChild);
assert.equal(rightChild.parent, rightParent);
assert.equal(rightChild.right, null);
assert.equal(reachable(rightOnly, rightMiddle), false);
assert.deepEqual(rightOnly.inorder(), [4, 5]);
assertInvariant(rightOnly);

const lone = build([9]);
assert.equal(lone.height(), 0);
assert.equal(lone.delete(9), true);
assert.equal(lone.root, null);
assert.equal(lone.size, 0);
assert.equal(lone.height(), -1);
assertInvariant(lone);

const rootOne = build([9, 8]);
assert.equal(rootOne.delete(9), true);
assert.equal(rootOne.root.key, 8);
assert.equal(rootOne.root.parent, null);
assert.deepEqual(rootOne.inorder(), [8]);
assertInvariant(rootOne);

const rootTwo = build([9, 7, 11, 8]);
const oldRoot = rootTwo.search(9);
const successorLeaf = rootTwo.search(11);
assert.equal(rootTwo.delete(9), true);
assert.equal(oldRoot.key, 11);
assert.equal(rootTwo.root, oldRoot);
assert.equal(oldRoot.parent, null);
assert.equal(oldRoot.left.key, 7);
assert.equal(oldRoot.right, null);
assert.equal(reachable(rootTwo, successorLeaf), false);
assert.deepEqual(rootTwo.inorder(), [7, 8, 11]);
assertInvariant(rootTwo);

const chain = build([1, 2, 3, 4, 5]);
assert.equal(chain.height(), 4);
assert.deepEqual(chain.searchPath(5), { found: true, path: [1, 2, 3, 4, 5] });
assert.deepEqual(chain.searchPath(6), { found: false, path: [1, 2, 3, 4, 5] });
assert.deepEqual(chain.searchPath(0), { found: false, path: [1] });
assert.equal(chain.insert(3), false);
assert.deepEqual(chain.inorder(), [1, 2, 3, 4, 5]);
assertInvariant(chain);

const balanced = build([4, 2, 6, 1, 3, 5, 7]);
assert.equal(balanced.height(), 2);
assert.equal(Math.floor(Math.log2(7)), 2);
assert.deepEqual(balanced.searchPath(5), { found: true, path: [4, 6, 5] });
assert.deepEqual(balanced.inorder(), [1, 2, 3, 4, 5, 6, 7]);
assertInvariant(balanced);

const recursive = build([10, 4, 15, 2, 8, 12, 6, 7]);
assert.equal(recursive.deleteRecursive(4), true);
assert.equal(recursive.deleteRecursive(12), true);
assert.equal(recursive.deleteRecursive(8), true);
assert.deepEqual(recursive.inorder(), [2, 6, 7, 10, 15]);
assert.equal(recursive.size, 5);
assertInvariant(recursive);
assert.equal(recursive.deleteRecursive(15), true);
assert.equal(recursive.root.right, null);
assert.deepEqual(recursive.inorder(), [2, 6, 7, 10]);
assertInvariant(recursive);
const recursiveRoot = build([9, 7, 11, 8]);
assert.equal(recursiveRoot.deleteRecursive(9), true);
assert.equal(recursiveRoot.root.key, 11);
assert.equal(recursiveRoot.root.right, null);
assert.deepEqual(recursiveRoot.inorder(), [7, 8, 11]);
assertInvariant(recursiveRoot);
assert.equal(recursive.deleteRecursive(100), false);

const violator = new BSTNode(5);
violator.left = new BSTNode(3);
violator.left.parent = violator;
violator.left.left = new BSTNode(7);
violator.left.left.parent = violator.left;
assert.equal(strictSearchProperty(violator, null, null), false);

class SortedArraySet {
  constructor() {
    this.keys = [];
  }

  search(key) {
    const path = [];
    let lo = 0;
    let hi = this.keys.length - 1;
    while (lo <= hi) {
      const mid = Math.floor((lo + hi) / 2);
      path.push(this.keys[mid]);
      if (this.keys[mid] === key) return { found: true, index: mid, path };
      if (key < this.keys[mid]) hi = mid - 1;
      else lo = mid + 1;
    }
    return { found: false, index: lo, path };
  }

  insert(key) {
    const place = this.search(key);
    if (place.found) return { inserted: false, moved: 0 };
    const moved = this.keys.length - place.index;
    this.keys.splice(place.index, 0, key);
    return { inserted: true, moved };
  }
}

const arraySet = new SortedArraySet();
for (const key of [4, 2, 6, 1, 3, 5, 7]) {
  assert.equal(arraySet.insert(key).inserted, true);
}
assert.deepEqual(arraySet.keys, [1, 2, 3, 4, 5, 6, 7]);
assert.deepEqual(arraySet.search(5), { found: true, index: 4, path: [4, 6, 5] });
const insertZero = arraySet.insert(0);
assert.deepEqual(insertZero, { inserted: true, moved: 7 });
assert.deepEqual(arraySet.keys, [0, 1, 2, 3, 4, 5, 6, 7]);
assert.equal(arraySet.insert(4).inserted, false);

class KDNode {
  constructor(x, y) {
    this.x = x;
    this.y = y;
    this.left = null;
    this.right = null;
  }
}

class KDTree {
  constructor() {
    this.root = null;
    this.size = 0;
  }

  insert(x, y) {
    if (this.root === null) {
      this.root = new KDNode(x, y);
      this.size = 1;
      return true;
    }
    let node = this.root;
    let depth = 0;
    while (true) {
      if (node.x === x && node.y === y) return false;
      const axis = depth % 2;
      const nodeCoord = axis === 0 ? node.x : node.y;
      const pointCoord = axis === 0 ? x : y;
      if (pointCoord < nodeCoord) {
        if (node.left === null) {
          node.left = new KDNode(x, y);
          this.size += 1;
          return true;
        }
        node = node.left;
      } else {
        if (node.right === null) {
          node.right = new KDNode(x, y);
          this.size += 1;
          return true;
        }
        node = node.right;
      }
      depth += 1;
    }
  }

  contains(x, y) {
    let node = this.root;
    let depth = 0;
    while (node !== null) {
      if (node.x === x && node.y === y) return true;
      const axis = depth % 2;
      const nodeCoord = axis === 0 ? node.x : node.y;
      const pointCoord = axis === 0 ? x : y;
      node = pointCoord < nodeCoord ? node.left : node.right;
      depth += 1;
    }
    return false;
  }

  rangeQuery(xLo, xHi, yLo, yHi) {
    const points = [];
    const visited = [];
    const prunes = [];
    const walk = (node, depth) => {
      if (node === null) return;
      visited.push({ x: node.x, y: node.y });
      if (node.x >= xLo && node.x <= xHi && node.y >= yLo && node.y <= yHi) {
        points.push({ x: node.x, y: node.y });
      }
      const axis = depth % 2;
      const coord = axis === 0 ? node.x : node.y;
      const lo = axis === 0 ? xLo : yLo;
      const hi = axis === 0 ? xHi : yHi;
      const searchLeft = lo < coord;
      const searchRight = hi >= coord;
      if (!searchLeft) prunes.push({ x: node.x, y: node.y, side: "left", depth });
      if (!searchRight) prunes.push({ x: node.x, y: node.y, side: "right", depth });
      if (searchLeft) walk(node.left, depth + 1);
      if (searchRight) walk(node.right, depth + 1);
    };
    walk(this.root, 0);
    return { points, visited, prunes };
  }
}

const kd = new KDTree();
const tracedPoints = [
  [7, 2],
  [5, 4],
  [9, 6],
  [2, 3],
  [4, 7],
  [8, 1],
];
for (const [x, y] of tracedPoints) assert.equal(kd.insert(x, y), true);
assert.equal(kd.insert(5, 4), false);
assert.equal(kd.size, 6);
assert.equal(kd.root.x, 7);
assert.equal(kd.root.y, 2);
assert.equal(kd.root.left.x, 5);
assert.equal(kd.root.left.y, 4);
assert.equal(kd.root.right.x, 9);
assert.equal(kd.root.right.y, 6);
assert.equal(kd.root.left.left.x, 2);
assert.equal(kd.root.left.left.y, 3);
assert.equal(kd.root.left.right.x, 4);
assert.equal(kd.root.left.right.y, 7);
assert.equal(kd.root.right.left.x, 8);
assert.equal(kd.root.right.left.y, 1);
assert.equal(kd.root.right.right, null);
assert.equal(kd.root.left.left.left, null);
assert.equal(kd.root.left.right.left, null);

for (const [x, y] of tracedPoints) assert.equal(kd.contains(x, y), true);
assert.equal(kd.contains(4, 5), false);
assert.equal(kd.contains(9, 0), false);
assert.equal(kd.contains(1, 1), false);

const rangeLow = kd.rangeQuery(0, 3, 0, 4);
assert.deepEqual(rangeLow.points, [{ x: 2, y: 3 }]);
assert.deepEqual(rangeLow.visited, [
  { x: 7, y: 2 },
  { x: 5, y: 4 },
  { x: 2, y: 3 },
  { x: 4, y: 7 },
]);
assert.deepEqual(rangeLow.prunes, [
  { x: 7, y: 2, side: "right", depth: 0 },
  { x: 4, y: 7, side: "right", depth: 2 },
]);

const rangeWide = kd.rangeQuery(4, 9, 1, 6);
assert.deepEqual(rangeWide.points, [
  { x: 7, y: 2 },
  { x: 5, y: 4 },
  { x: 9, y: 6 },
  { x: 8, y: 1 },
]);
assert.deepEqual(rangeWide.prunes, [
  { x: 2, y: 3, side: "left", depth: 2 },
  { x: 4, y: 7, side: "left", depth: 2 },
]);

const ties = new KDTree();
assert.equal(ties.insert(0, 0), true);
assert.equal(ties.insert(0, 1), true);
assert.equal(ties.root.right.x, 0);
assert.equal(ties.root.right.y, 1);
assert.equal(ties.root.left, null);
assert.equal(ties.contains(0, 1), true);
assert.equal(ties.contains(0, -1), false);
const onPlane = ties.rangeQuery(0, 0, 0, 1);
assert.deepEqual(onPlane.points, [
  { x: 0, y: 0 },
  { x: 0, y: 1 },
]);
assert.deepEqual(onPlane.prunes, [{ x: 0, y: 0, side: "left", depth: 0 }]);

console.log("ALL TESTS PASSED");
```

---

# Common mistakes

**Wrong idea.** The search property is the comparison between a node and its two children.
**Correction.** The property quantifies over every key in the subtree. The tree with root $5$, left child $3$, and $7$ under $3$ passes a child check and fails at the root, because $7 > 5$ sits in the left subtree. The witness is the key $7$ at the node $5$.

**Wrong idea.** The empty tree has height $0$, so a chain of $n$ nodes has height $n$.
**Correction.** Lecture 07 sets the empty height at $-1$ and the leaf height at $0$. A chain of $n$ nodes has height $n - 1$. The one-node tree is a leaf and has height $0$, which the laboratory checks on the tree that holds only $9$.

**Wrong idea.** Deleting a node with two children means attaching both subtrees to the parent.
**Correction.** The parent has one pointer where the node sat. Copy the successor's key onto the node, then delete the successor. The successor has no left child, so that second deletion has at most one child.

**Wrong idea.** After copying the successor's key, delete by searching for that key from the root.
**Correction.** The key now occurs twice, and the search can find the node you just wrote onto. Unlink the successor by `transplant` on its pointer, or run the recursive deletion starting at the right subtree. The laboratory's two-child assertion checks that the original node object survives with the new key and that the successor object is unreachable.

**Wrong idea.** In the recursive deletion, the recursive call updates the tree by itself, so the returned pointer need not be stored.
**Correction.** The call returns the new root of that subtree. The parent stores it with `node.left = remove(...)` or `node.right = remove(...)`, and the outer call stores it in `this.root`. A leaf deletion returns `null`. If the assignment is missing, the parent still points at the leaf.

**Wrong idea.** The successor of a node with no right child is its parent.
**Correction.** The parent is the successor only when the node is the left child. If the node is the right child, the parent's key is smaller. Climb while the current node is a right child, and stop at the first parent that contains the current node on its left. On the working tree the successor of $7$ is $8$, not $6$. The node $6$ is the predecessor.

**Wrong idea.** A duplicate may be inserted on the right, or on either side, because the weak search property allows equal keys in both subtrees.
**Correction.** This lecture rejects duplicates. `insert` returns false on an equal key and writes no pointer. The k-d tree rejects a point with both coordinates equal. Allowing equals on both sides would make the successor ambiguous and would break the strict inorder theorem this lecture proves under the policy.

**Wrong idea.** A k-d tree compares $x$ at every node, and a range query may skip the right child whenever the query's high endpoint is $\le$ the cutting coordinate.
**Correction.** The axis is $\mathrm{depth} \bmod 2$: $x$ at even depth, $y$ at odd depth. The right child stores cutting coordinates $\ge c$, so it is skipped only when the query interval ends strictly below $c$, that is when $h \ge c$ is false. The query $[0, 0] \times [0, 1]$ on the points $(0, 0)$ and $(0, 1)$ must search the right child and report both points.

**Wrong idea.** Random insertion proves that every binary search tree has height $\Theta(\log n)$.
**Correction.** The $\Theta(\log n)$ result is an expectation over the $n!$ insertion orders, insertions only, as stated from CLRS. Sorted insertion produces height $n - 1$ on a particular input. A guarantee for every input is Lecture 09.

---

# Examination

Attempt this examination closed, without the answer key and without running the laboratory program. Write full solutions. The height convention is the one used all lecture: the empty tree has height $-1$, and a leaf has height $0$.

1. State the search property as this lecture defines it. State the duplicate policy, and state the strict inequalities that the policy adds.

2. State the height of the empty tree, the height of a leaf, and the depth of the root. State Lecture 07's definition of the inorder walk.

3. State the search invariant. Where does an unsuccessful search stop?

4. The following drawing is a binary tree of distinct keys. For each node, say whether the search property holds at that node. When it fails, give one witness key.

```text
            20
          /    \
        10      30
       /  \       \
      5    25      28
          /
         15
```

5. Insert $12, 5, 18, 9, 15, 2$ into an empty binary search tree, in that order, using this lecture's duplicate policy. Draw the final tree. For each key, name the parent and whether the node is a left child, a right child, or the root.

6. From the tree of question 5, before any deletion, give the successor of $5$, of $12$, of $9$, and of $18$. For each, name case 1 or case 2 and show the walk. Then delete $5$. Draw the tree after the deletion and write its inorder sequence. Say which node object keeps which key if the successor is copied.

7. Insert the keys $1, 2, 3, 4, 5, 6, 7, 8$ in increasing order into an empty binary search tree.
   (a) Describe the shape.
   (b) Give the height.
   (c) Give the number of key comparisons in a successful search for $8$.
   (d) Give the number of key comparisons in an unsuccessful search for $0$.
   (e) Give the number of key comparisons in an unsuccessful search for $9$.
   (f) Give the best-case height of any binary tree on $8$ nodes.
   (g) Say which lecture supplies a structure whose height stays logarithmic on this input.

8. Show that a binary tree of height $2$ has at most $7$ nodes, by using $2^{h+1} - 1$ with $h = 2$. Conclude the minimum height of a binary tree on $8$ nodes, and check it against $\lfloor \log 8 \rfloor$.

9. Let the sorted array be $[1, 2, 3, 4, 5, 6, 7, 8]$, indexed from $0$.
   (a) Run binary search for $8$. Write each triple $(\mathit{lo}, \mathit{hi}, \mathrm{mid})$ and the key at `mid`.
   (b) How many entries move when $0$ is inserted at the front of this eight-key array?
   (c) On the chain of question 7, how many key comparisons does an insertion of $9$ perform before the pointer write?

10. Use the six-point k-d tree from the lecture, built by inserting $(7, 2)$, $(5, 4)$, $(9, 6)$, $(2, 3)$, $(4, 7)$, $(8, 1)$. The query rectangle is $[8, 10] \times [0, 7]$.
    (a) Which stored points are reported?
    (b) Which nodes are visited?
    (c) Name the nonempty side that is pruned at the root, and justify it with the query interval and the half-plane.

11. Define a randomly built binary search tree. State the expected-height result, including which direction this lecture proves and which direction it cites. State the hypothesis the result does not cover.

12. Give three operation mixes for which a binary search tree is the wrong tool. For each, name the lecture that owns the structure you would use instead, and name the cost you are buying.

---

# Answer key

**1.** For every node $x$, every key in the left subtree of $x$ is $\le x.\mathrm{key}$, and every key in the right subtree of $x$ is $\ge x.\mathrm{key}$. The duplicate policy rejects a key that is already present: `insert` returns false and writes nothing. The k-d tree rejects a point already present with both coordinates equal. Under that policy the live keys are distinct, so every left-subtree key is $< x.\mathrm{key}$ and every right-subtree key is $> x.\mathrm{key}$.

**2.** The empty tree has height $-1$. A leaf has height $0$. The root has depth $0$. The inorder walk of an empty tree is the empty sequence. The inorder walk of a nonempty tree is the inorder walk of the left subtree, then the root key, then the inorder walk of the right subtree.

**3.** If the key occurs in the original tree, then it occurs in the subtree rooted at the current node. An unsuccessful search stops when the current node is `null`.

**4.** Keys in the left subtree of $20$ are $10, 5, 25, 15$. The key $25$ is $> 20$, so the property fails at $20$, and $25$ is a witness. The keys $10, 5, 15$ are all $\le 20$ and are not witnesses. The right subtree of $20$ is $\{30, 28\}$, both $\ge 20$, so the right side of $20$ holds.

At $10$, the left subtree is $\{5\}$ and $5 \le 10$. The right subtree is $\{25, 15\}$, both $\ge 10$. The property holds at $10$. The key $15$ is allowed there even though it also sits in the left subtree of $20$.

At $25$, the left subtree is $\{15\}$ and $15 \le 25$, and the right subtree is empty. The property holds. At $5$, at $15$, and at $28$ the node is a leaf and the property holds.

At $30$, the right subtree is $\{28\}$ and $28 \ge 30$ is false. The property fails at $30$, and the witness is $28$.

A check of children alone finds the failure at $30$, because $28$ is the right child, and misses the failure at $20$, because the children $10$ and $30$ lie on legal sides of $20$. The grandchild $25$ is the witness the child check does not see.

**5.** The insertions land as follows. $12$ is the root. $5 < 12$ becomes the left child of $12$. $18 > 12$ becomes the right child of $12$. $9 < 12$ and $9 > 5$, so $9$ is the right child of $5$. $15 > 12$ and $15 < 18$, so $15$ is the left child of $18$. $2 < 12$ and $2 < 5$, so $2$ is the left child of $5$.

```text
            12
          /    \
        5        18
       / \      /
      2   9    15
```

**6.** Inorder of that tree is $2, 5, 9, 12, 15, 18$.

Successor of $5$, case 1. The right subtree is the node $9$, which has no left child, so the minimum is $9$.

Successor of $12$, case 1. The minimum of the right subtree follows the left child of $18$ to $15$, and $15$ has no left child. The successor is $15$.

Successor of $9$, case 2. The node $9$ has no right child. It is the right child of $5$, so the climb moves to $5$. The node $5$ is the left child of $12$, so the climb stops. The successor is $12$.

Successor of $18$, case 2. The node $18$ has no right child. It is the right child of $12$, so the climb moves to $12$, whose parent is `null`. The successor is `null`. The node $18$ is the maximum.

Delete $5$. Both children exist. The successor is $9$, and $9$ is a leaf and is the right child of $5$. Copy $9$ onto the node object that held $5$. Unlink the old node $9$ by writing `null` into the right child of that object. The left child $2$ stays.

```text
            12
          /    \
        9        18
       /        /
      2        15
```

Inorder is $2, 9, 12, 15, 18$. The node object that used to hold $5$ now holds $9$. The node object that used to hold $9$ is detached.

**7.** (a) Each new key is larger than every stored key, so each insertion attaches a right child. The tree is a right spine $1, 2, 3, 4, 5, 6, 7, 8$.

(b) There are $8$ nodes. The height is $8 - 1 = 7$.

(c) Search for $8$ compares $1, 2, 3, 4, 5, 6, 7, 8$. That is $8$ comparisons.

(d) Search for $0$ compares $1$ and takes the left `null`. That is $1$ comparison.

(e) Search for $9$ compares all $8$ nodes and takes the right `null` of $8$. That is $8$ comparisons.

(f) $\lfloor \log 8 \rfloor = 3$, because $2^3 = 8$.

(g) Lecture 09.

**8.** For $h = 2$, the maximum number of nodes is $2^{2+1} - 1 = 2^{3} - 1 = 8 - 1 = 7$. A tree of $8$ nodes cannot have height $2$, so its height is at least $3$. And $\lfloor \log 8 \rfloor = 3$, which matches.

**9.** (a) The array is indexed from $0$.

| $\mathit{lo}$ | $\mathit{hi}$ | mid | key |
| --- | --- | --- | --- |
| $0$ | $7$ | $\lfloor 7/2 \rfloor = 3$ | $4$, and $8 > 4$, so $\mathit{lo} \leftarrow 4$ |
| $4$ | $7$ | $\lfloor 11/2 \rfloor = 5$ | $6$, and $8 > 6$, so $\mathit{lo} \leftarrow 6$ |
| $6$ | $7$ | $\lfloor 13/2 \rfloor = 6$ | $7$, and $8 > 7$, so $\mathit{lo} \leftarrow 7$ |
| $7$ | $7$ | $\lfloor 14/2 \rfloor = 7$ | $8$, hit |

Four probes: $4, 6, 7, 8$.

(b) All $8$ entries move one slot to the right.

(c) Insertion of $9$ walks the right spine and compares $1, 2, 3, 4, 5, 6, 7, 8$, which is $8$ comparisons, then writes one right-child pointer.

**10.** (a) $(9, 6)$ and $(8, 1)$. The point $(7, 2)$ has $x = 7$, which is outside $[8, 10]$. The root splits on $x$, so every point in its left subtree has $x < 7$. Those points are $(5, 4)$, $(2, 3)$, and $(4, 7)$.

(b) Visit $(7, 2)$. The left half-plane is $x < 7$. The query wants $x \ge 8$, and $8 < 7$ is false, so the left side is pruned and those three nodes are not visited. The right half-plane is $x \ge 7$, and $10 \ge 7$, so visit $(9, 6)$. The point $(9, 6)$ lies in the rectangle because $8 \le 9 \le 10$ and $0 \le 6 \le 7$. Its axis is $y$ and $c = 6$. The $y$-interval $[0, 7]$ meets both the left and the right of that plane, and the only child is the left child $(8, 1)$. Visit $(8, 1)$, which lies in the rectangle because $x = 8$ and $y = 1$. Its children are `null`.

The nodes visited are $(7, 2)$, $(9, 6)$, $(8, 1)$.

(c) The nonempty pruned side is the left subtree of $(7, 2)$, which contains $(5, 4)$, $(2, 3)$, and $(4, 7)$. The left half-plane is $x < 7$. The query interval on $x$ is $[8, 10]$. Their intersection is empty because every query $x$ is $\ge 8$ and every left-subtree $x$ is $< 7$.

**11.** A randomly built binary search tree on $n$ distinct keys is the tree obtained by inserting those keys into an empty tree in an order chosen uniformly from the $n!$ permutations. The model is insertions only. The expected height is $\Theta(\log n)$. This lecture proves the $\Omega(\log n)$ side, because every binary tree has height at least $\lfloor \log n \rfloor$ and an expectation is at least that large. The $O(\log n)$ side is cited from CLRS, 3rd edition, Section 12.4, and is not proved here. The result does not describe a process that mixes deletions with insertions.

**12.** Sorted or adversarial insertions, when every operation must stay $O(\log n)$: Lecture 09, a balanced search tree, buying height $O(\log n)$ after every update. Repeated access to the minimum or the maximum alone, with no successor and no inorder listing: Lecture 10, a binary heap, buying $\Theta(1)$ access to the extreme and $O(\log n)$ restoration. Hashable keys with no order-dependent operation: Lecture 11, a hash table, buying expected constant-time search and insert under the simple uniform hashing assumption.

---

# Independent assignment

Produce two artifacts and keep them. Budget several hours. Do not copy the laboratory program into the file; you may use it as a specification after you have a draft.

**Artifact 1, a program.** Write a single JavaScript file, run with Node, with no libraries. It contains your own binary search tree, with parent pointers, `insert` that rejects duplicates, `delete` for all three child cases, `successor`, and `height` under the $-1$ / $0$ convention.

The program then does three deterministic checks.

1. Generate every permutation of $\{1, 2, 3, 4, 5, 6\}$. There are $720$. For each permutation, insert the keys in that order into an empty tree, assert that inorder equals $1, 2, 3, 4, 5, 6$, and record the height. Print a histogram: for each height from $0$ through $5$, print how many permutations produced it. Print the average height as a reduced fraction or as a ratio of two integers, not as a rounded display. The chain height for $n = 6$ is $5$, and $\lfloor \log 6 \rfloor = 2$. Your histogram must show both that some permutations reach height $5$ and that the average is closer to $2$ than to $5$.
2. Run $200$ updates from a fixed linear congruential generator: start with seed $1$, and replace the seed $s$ by $(1103515245 \cdot s + 12345) \bmod 2^{31}$ at every step. On each step, if the low bit of the seed is $0$, insert $(s \bmod 50)$; if the low bit is $1$, delete $(s \bmod 50)$. After every step, check the strict search property, the parent links, the size, and the sorted inorder. The generator is deterministic. The run either always passes or always fails for a given bug.
3. Implement `floor(k)`, the greatest stored key that is $\le k$, or `null` if every stored key is $> k$, and `ceiling(k)`, the least stored key that is $\ge k$, or `null` if every stored key is $< k$. Test both on the working tree of the lecture, including a key that is present, a key that falls between two stored keys, a key below the minimum, and a key above the maximum.

**Artifact 2, a note of about one page.** Explain, from your histogram, what the random-insertion model measures and why the height-$5$ permutations do not contradict the $\Theta(\log n)$ expectation. Record one bug you actually hit in deletion or in the parent pointers, the wrong behavior it produced, and the invariant check that caught it. If your first draft had no bug, perturb one assignment in `transplant`, confirm that check 2 fails, restore it, and write about that perturbation.

---

# Glossary

**Best-case height.** The minimum height of any binary tree on $n$ nodes, equal to $\lfloor \log n \rfloor$ under this course's height convention.

**Binary search tree.** A binary tree in which every node satisfies the search property.

**Candidate ancestor.** During a parent-free successor search, the most recent node at which the walk stepped left. If the target has no right subtree, the candidate is the successor.

**Case 1 (successor).** The node has a right subtree, and the successor is that subtree's minimum.

**Case 2 (successor).** The node has no right subtree, and the successor is the nearest ancestor that contains the node in its left subtree, or `null` if no such ancestor exists.

**Curse of dimensionality.** The loss of pruning power as the number of coordinates grows: each node cuts one axis, so a small high-dimensional query is forced down both children at many nodes, and nearest-neighbor search tends toward a full scan.

**Cutting coordinate.** In a two-dimensional k-d tree, $x$ at even depth and $y$ at odd depth.

**Detach.** Clearing `left`, `right`, and `parent` of a node after it has been unlinked, so a stale pointer does not still appear to sit in the tree.

**Duplicate policy.** The rule, used everywhere in this lecture, that `insert` rejects a key or a point that is already present.

**Exact-match search.** A k-d search that reports whether one full point is stored.

**Half-plane (k-d).** The set of points whose cutting coordinate is $< c$, stored on the left, or $\ge c$, stored on the right.

**Height.** Empty tree $-1$, leaf $0$, otherwise one plus the larger child height. Fixed in Lecture 07.

**Inorder walk.** Left subtree, then the node, then the right subtree. Empty tree produces the empty sequence. Fixed in Lecture 07.

**k-d tree.** A binary tree on multi-dimensional points that cycles the comparison coordinate by depth. This lecture uses two dimensions.

**Maximum.** The key reached by following right children until the right child is `null`.

**Minimum.** The key reached by following left children until the left child is `null`.

**No-child deletion.** The deleted node is a leaf. The parent's pointer becomes `null`.

**One-child deletion.** The parent's pointer to the deleted node is replaced by that node's only child.

**Ordered set.** A set of distinct keys from a totally ordered universe, with search, insert, delete, minimum, maximum, successor, predecessor, and inorder.

**Orthogonal range query.** A query for every stored point inside an axis-aligned rectangle.

**Predecessor.** The node with the greatest key strictly less than a given key, or `null` if that key is the minimum.

**Pruning rule.** In a k-d range query, skip a child when its half-plane misses the query rectangle.

**Randomly built binary search tree.** The tree produced by inserting $n$ distinct keys in an order drawn uniformly from the $n!$ permutations, with insertions only.

**Right spine.** The chain produced by inserting keys in increasing order: every node is the right child of its parent. Height $n - 1$.

**Search hit.** A search that returns the node holding the key.

**Search invariant.** If the key occurs in the tree, it occurs in the subtree rooted at the current node.

**Search miss.** A search that reaches `null` and reports that the key is absent.

**Search property.** For every node $x$, every key in the left subtree is $\le x.\mathrm{key}$ and every key in the right subtree is $\ge x.\mathrm{key}$.

**Sorted-array set.** The same ordered set stored as a sorted array, with binary search and with $\Theta(n)$ insertion in the worst case.

**Splitting plane.** The line through a k-d node perpendicular to its cutting axis: $x = c$ or $y = c$.

**Successor.** The node with the least key strictly greater than a given key, or `null` if that key is the maximum.

**Transplant.** The pointer update that puts a subtree $v$ in the place of a node $u$, including the root case and the parent pointer of $v$.

**Two-child deletion.** Copy the successor's key onto the node, then delete the successor, which has at most one child.

**Working tree.** The binary search tree built by inserting $10, 4, 15, 2, 12, 8, 6, 7$, used for the traces in this lecture.

---

# Lecture summary

A binary search tree is a binary tree plus one rule: at every node, the left subtree's keys are $\le$ the node's key and the right subtree's keys are $\ge$ it. This lecture rejects duplicate keys, so the inequalities in every tree the operations build are strict. Lecture 07's inorder walk then emits the keys in increasing order, and the converse holds as well: a binary tree of distinct keys is a binary search tree exactly when that walk is strictly increasing.

Search, insert, minimum, maximum, successor, predecessor, and delete all run in $\Theta(h)$ worst-case time on the tree in hand. Search stops at `null` when the key is absent. Insert hangs one new leaf at the end of that same walk, or refuses the key. Successor is the minimum of the right subtree when the right child exists, and otherwise the nearest ancestor reached by climbing out of right children. Delete has three shapes. A leaf is replaced by `null`. A node with one child is replaced by that child. A node with two children receives its successor's key, and the successor, which has no left child, is deleted by one of the first two shapes. After that call the strict property, the parent links, the size, and the sorted inorder all hold, and the successor node is the object that left the tree.

None of this pins $h$ to $\log n$. Sorted insertion of $n$ keys builds a right spine of height $n - 1$ and makes search $\Theta(n)$. The best possible height is $\lfloor \log n \rfloor$. The expected height of a tree built by a uniform random permutation of insertions is $\Theta(\log n)$, where the $O(\log n)$ direction is cited from CLRS and the $\Omega(\log n)$ direction is the universal lower bound. Lecture 09 is what you open when the chain is not acceptable.

A sorted array implements the same ordered set with $\Theta(\log n)$ search and $\Theta(n)$ insert. A two-dimensional k-d tree alternates the cutting axis by depth, inserts and searches by that axis, and answers a rectangle query by skipping any child whose half-plane misses the rectangle. It is not balanced, and in higher dimensions the prune loses force.

## Five principles

1. The search property is a statement about every key in the subtree of every node. The two children are not enough.
2. Under the reject-duplicates policy, inorder is strictly increasing if and only if the tree is a binary search tree.
3. Every ordered-set operation on the tree costs $\Theta(h)$ in the worst case on that tree, and an unsuccessful search is the operation that stops at `null`.
4. Sorted insertion makes $h = n - 1$. Random insertion makes the expected height $\Theta(\log n)$ only in the permutation model with insertions only. A guarantee for every update is Lecture 09.
5. A k-d tree cuts one alternating coordinate at each depth and prunes a side only when the splitting plane misses the query rectangle. It does not guarantee balance, and higher dimension weakens the prune.

---

# References

1. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapter 12, "Binary Search Trees." The operations and the search-tree property. The preface of this edition records that the randomly built analysis was removed from the main text.

2. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 3rd edition. MIT Press, 2009. Section 12.4, "Randomly built binary search trees." The $O(\log n)$ expected-height theorem and the insertion-only permutation model. This lecture cites that theorem and does not reproduce the proof.

3. Robert Sedgewick and Kevin Wayne. *Algorithms*. 4th edition. Addison-Wesley, 2011. Section 3.2, "Binary Search Trees." The ordered-set operations and the stated average search cost of about $2 \ln n$ comparisons in a tree built from random distinct keys. The course site is [https://algs4.cs.princeton.edu/32bst/](https://algs4.cs.princeton.edu/32bst/).

4. Jon Louis Bentley. "Multidimensional Binary Search Trees Used for Associative Searching." *Communications of the ACM*, volume 18, number 9, 1975. The k-d tree.

5. Bruce Reed. "The height of a random binary search tree." *Journal of the ACM*, volume 50, number 3, 2003. The sharper expected-height asymptotic, cited as further reading and not used in the examination.
