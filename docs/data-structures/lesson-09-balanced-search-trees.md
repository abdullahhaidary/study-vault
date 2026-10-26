# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 09 — BALANCED SEARCH TREES

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 09 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 10 hours
**Prerequisites:** Lecture 07 — Trees, Binary Trees, and Traversals; Lecture 08 — Binary Search Trees
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapters 12, 13, 17, and 18; Knuth, *The Art of Computer Programming*, Volume 3, 2nd edition, Section 6.2.3; Weiss, *Data Structures and Algorithm Analysis in C++*, 4th edition, Chapter 4

**This lecture owns:** AVL trees, the shape of red–black insertion, B-trees and 2–3–4 trees, and augmenting a tree with subtree sizes.
**This lecture does not teach:** hashing, heaps, k-d trees, or a red–black deletion procedure. Hashing is Lecture 11. Heaps are Lecture 10. Lecture 08 owns the binary-search-tree search property and the unbalanced insert and delete. This lecture adds the balance invariant and the multiway trees that keep a search path logarithmic.

---

## Learning objectives

After this lecture you should be able to do the following.

1. Draw the tree produced by a left rotation and by a right rotation, including the subtree whose parent changes, and name the parent and child pointers that move.
2. Prove that a rotation preserves the binary-search-tree property by placing every subtree's keys relative to the two nodes that the rotation rewires.
3. Given an insertion into an AVL tree, name the imbalance LL, RR, LR, or RL, apply the one or two rotations that repair it, and write the balance factors before and after.
4. Derive the minimum-node recurrence $N(h) = 1 + N(h-1) + N(h-2)$ and prove from it that every AVL tree on $n$ nodes has height $\Theta(\log n)$, so that search, insert, and delete are $\Theta(\log n)$ in the worst case.
5. Delete a key from an AVL tree by the binary-search-tree deletion of Lecture 08 and then rebalance every node on the path back to the root, including a case that needs a rotation.
6. State the five red–black properties, say what a nil sentinel is, and prove that the height is $O(\log n)$ from the black-height.
7. Insert a key into a red–black tree by hand, distinguishing the uncle-red recoloring from the triangle rotation and the line rotation, and say which case moves the violation up the tree.
8. Insert into a 2–3–4 tree by splitting 4-nodes on the way down, insert into a B-tree of a stated minimum degree including a split, and state the height bound $h \le \log_t((n+1)/2)$.
9. Maintain a subtree-size field through a rotation, then compute select and rank from those fields and prove both from the size invariant and the search property.
10. Choose among an AVL tree, a red–black tree, a B-tree, a sorted array, and a hash table by naming the guarantee each structure actually gives.

---

## Purpose

Lecture 08 builds a binary search tree and proves that search, insert, and delete follow one root-to-leaf path. The length of that path is the height. Nothing in the search property limits the height. This lecture adds a second invariant whose only job is to keep the height $\Theta(\log n)$ in the worst case, and it shows three ways to keep such an invariant: a numeric balance factor repaired by rotations (the AVL tree), a color constraint repaired by recoloring and the same rotations (the red–black tree), and a multiway node that splits before it overflows (the 2–3–4 tree and the B-tree). The last part stores one extra integer in each node, the subtree size, and uses it to answer order-statistic queries without giving up the logarithmic bound.

The lecture deliberately stops short of four neighboring topics. It does not teach hash tables, except as one row of the final comparison, because Lecture 11 owns the hashing assumption. It does not teach heaps. It does not re-teach the binary-search-tree deletion cases; it uses them. It describes red–black deletion and B-tree deletion only far enough to say why the cases exist and where they are written out. The laboratory implements AVL insertion and deletion, red–black insertion, 2–3–4 and B-tree insertion, and select and rank. It does not implement red–black deletion or B-tree deletion, and the prose does not pretend that it does.

Keys in this lecture are distinct numbers. An insertion of a key that is already present leaves the tree unchanged. The search property is the one from Lecture 08: every key in the left subtree of a node is strictly smaller than the node's key, and every key in the right subtree is strictly larger. Arrays and strings are not the subject here. Where a bound is written $\Theta$, it is tight. $\log$ means $\log_2$. The empty tree has height $-1$. A leaf has height $0$. The root has depth $0$. The AVL balance factor of a node is $\mathrm{height}(\mathrm{left}) - \mathrm{height}(\mathrm{right})$, and the node is balanced when that integer lies in $\{-1, 0, 1\}$.

JavaScript numbers are IEEE floating-point values. Every key and every subtree size in this lecture is an integer whose absolute value is far below $2^{53}$, so the arithmetic is exact. The same algorithms on a size near $2^{53}$ would need a different integer type; that limit is a property of the language, not of the tree.

---

## 1. Why Lecture 08 is not enough

A binary search tree stores a set so that searching for a key inspects one path. Each step throws away one subtree. If both subtrees of every node are about the same size, the path has length about $\log n$ and the search is cheap. The search property does not force the subtrees to be the same size. It only forces keys on the left to be smaller and keys on the right to be larger.

Insert the keys $1, 2, 3, 4$ in that order into an empty binary search tree, using the insertion of Lecture 08 and no rotation.

```text
1
 \
  2
   \
    3
     \
      4
```

The tree is a chain. Its course height is $3$, which is $n - 1$. Searching for $4$ inspects all four nodes. Inserting $5$ adds one more link on the same chain. After the sorted sequence $1, 2, \ldots, n$, the course height is $n - 1$, and the worst-case search, insertion, and deletion are $\Theta(n)$ rather than $\Theta(\log n)$.

The balance factors, under this lecture's definition, show the failure as soon as the chain is long enough to measure. The leaf $4$ has height $0$ and balance factor $0$. Node $3$ has a null left child, height $-1$, and a right child of height $0$, so its balance factor is $-1 - 0 = -1$. Node $2$ has left height $-1$ and right height $1$, so its balance factor is $-2$. Node $1$ has left height $-1$ and right height $2$, so its balance factor is $-3$. The invariant $\{-1, 0, 1\}$ is already false at node $2$.

Balance is an extra invariant, stacked on top of the search property. The search property makes the path a correct search. The balance invariant makes every such path short. For the AVL tree the invariant is local and numeric: every node has balance factor in $\{-1, 0, 1\}$. For the red–black tree the invariant is a coloring. For the B-tree the invariant is a minimum and maximum number of keys in a node, together with the rule that all leaves sit at the same depth. Each of these implies a height bound of the form $O(\log n)$. None of them is implied by the search property alone.

The operations stay proportional to the height because each of them walks a root-to-leaf path, does a constant amount of work at each node, and then walks back toward the root doing a constant amount of repair at each node. Once the height is $\Theta(\log n)$, the operations are $\Theta(\log n)$ in the worst case. The rest of the lecture proves the height bound and shows the repair. A slogan that "balanced trees are logarithmic" is not that proof.

---

## 2. Rotations

A rotation is a constant-time rewrite of two nodes and one subtree. It preserves the set of keys and the inorder sequence. It changes the height. Balance uses it as the repair step. The rewrite itself does not require the node to be unbalanced. The balance factor decides when to rotate. The pointer rules decide what the rotation does.

### 2.1 Right rotation

Let $y$ be a node whose left child $x$ exists. Write $A$ for the left subtree of $x$, $B$ for the right subtree of $x$, and $C$ for the right subtree of $y$. Any of $A$, $B$, and $C$ may be empty. The subtree $B$ is the middle subtree. It is the one that changes parent.

```text
        y                         x
       / \                       / \
      x   C      right          A   y
     / \        ------->           / \
    A   B                         B   C
```

The pointer steps are exactly these.

1. Remember $x = y.\mathrm{left}$ and $B = x.\mathrm{right}$.
2. Set $x.\mathrm{right} = y$. The old parent $y$ becomes the right child of $x$.
3. Set $y.\mathrm{left} = B$. The middle subtree moves from the right of $x$ to the left of $y$.
4. Recompute the height and the subtree size of $y$ first, then of $x$. The size of $x$ reads the size of $y$, so $y$ must be current before $x$ is.
5. Return $x$ to the caller. The parent of $y$, or the tree's root pointer if $y$ was the root, now points at $x$.

$A$ and $C$ are not rewritten. Their internal pointers stay as they were.

Here is the same rewrite with keys. The middle subtree is the node $4$.

```text
        6                         3
       / \                       / \
      3   8      right          1   6
     / \        ------->           / \
    1   4                         4   8
```

Before the rotation the subtree sizes are $1$ at the leaves $1$, $4$, and $8$, size $3$ at node $3$, and size $5$ at node $6$. After the rotation they are size $5$ at node $3$, size $3$ at node $6$, and size $1$ at $1$, $4$, and $8$. The inorder sequence is $1, 3, 4, 6, 8$ on both sides. The laboratory checks those sizes and that sequence.

### 2.2 Left rotation

A left rotation is the mirror image. It requires a right child. Let $x$ have right child $y$, let $A$ be the left subtree of $x$, let $B$ be the left subtree of $y$, and let $C$ be the right subtree of $y$. Again $B$ is the middle subtree, the one that changes parent.

```text
      x                           y
     / \                         / \
    A   y        left           x   C
       / \      ------->       / \
      B   C                   A   B
```

The pointer steps are these.

1. Remember $y = x.\mathrm{right}$ and $B = y.\mathrm{left}$.
2. Set $y.\mathrm{left} = x$.
3. Set $x.\mathrm{right} = B$.
4. Recompute the height and the subtree size of $x$ first, then of $y$.
5. Return $y$ to the caller.

On the keyed picture, a left rotation at $3$ undoes the right rotation at $6$ and restores the first drawing. The two rotations are inverses when each is applied to the node the other one produced.

### 2.3 The search property is preserved

**Theorem.** A left rotation and a right rotation preserve the binary-search-tree property. The inorder sequence of keys is unchanged.

**Proof.** Consider a right rotation at $y$ with left child $x$, and with subtrees $A$, $B$, and $C$ as drawn above. Before the rotation the search property at $x$ and at $y$ says four things.

- Every key of $A$ is less than $x$, because $A$ is the left subtree of $x$.
- Every key of $B$ is greater than $x$, because $B$ is the right subtree of $x$.
- Every key of $A$, every key of $B$, and the key $x$ itself are less than $y$, because all of them lie in the left subtree of $y$. In particular every key of $B$ is less than $y$.
- Every key of $C$ is greater than $y$, because $C$ is the right subtree of $y$.

Chaining these comparisons gives the five-region order: every key of $A$ is less than $x$, $x$ is less than every key of $B$, every key of $B$ is less than $y$, and $y$ is less than every key of $C$. In symbols, writing a subtree name for "every key in that subtree",

$$
A < x < B < y < C.
$$

The rotation does not modify $A$, $B$, or $C$ internally, so each of them remains a search tree. After the rotation, $x$ has left subtree $A$ and right subtree $y$, and $y$ has left subtree $B$ and right subtree $C$. The order $A < x < B < y < C$ is exactly the search property at $x$ and at $y$ in the new tree. The set of keys in the whole subtree is unchanged, so the parent of the old node $y$, which compared its own key with that set, is still a correct parent of the new root $x$. By induction on the path to the root, the whole tree remains a search tree.

The inorder walk visits a left subtree, then the node, then a right subtree. Before the rotation it visits $A$, $x$, $B$, $y$, $C$. After the rotation it visits $A$, $x$, $B$, $y$, $C$. The sequence is the same.

A left rotation is the same argument read in the other direction. The five-region order $A < x < B < y < C$ is the hypothesis before the left rotation as well, because that is the search property of the left-hand drawing in Section 2.2. After the left rotation, $y$ has left subtree $x$ and right subtree $C$, and $x$ has left subtree $A$ and right subtree $B$, which is again the same order. $\square$

The height is not preserved. That is the point of rotating. In the keyed right rotation, node $6$ before the rotation has left height $1$ and right height $0$, so its height is $2$ and its balance factor is $+1$. After the rotation, node $3$ has two children of height $1$, so its height is $2$ and its balance factor is $0$. On a taller unbalanced tree the height of the subtree drops. Section 3 uses that drop.

### 2.4 Where the fields are recomputed

Each node stores `height` and `size`. The empty tree contributes height $-1$ and size $0$. A node's own fields are defined from its children only:

$$
\mathrm{height}(u) = 1 + \max(\mathrm{height}(u.\mathrm{left}), \mathrm{height}(u.\mathrm{right})),
$$

$$
\mathrm{size}(u) = 1 + \mathrm{size}(u.\mathrm{left}) + \mathrm{size}(u.\mathrm{right}).
$$

A rotation moves a child pointer and therefore invalidates the stored fields of both participating nodes. The node that ends up lower must be recomputed first, because the higher node's size and height read the lower node's stored fields. In a right rotation the lower node is $y$ and the higher node is $x$. In a left rotation the lower node is $x$ and the higher node is $y$. Recomputing the higher node first stores a size that still describes the old child. Select and rank then return the wrong key, even though the search property is true. The laboratory checks the sizes after the keyed rotation above, and again after every AVL rotation in the insertion traces.

The runnable form of both rotations is in the laboratory program. The control flow is the five steps above, and nothing else.

---

## 3. AVL trees

### 3.1 Definition

An **AVL tree** is a binary search tree in which every node has balance factor in $\{-1, 0, 1\}$, where

$$
\mathrm{balance}(u) = \mathrm{height}(u.\mathrm{left}) - \mathrm{height}(u.\mathrm{right})
$$

and the height of a null child is $-1$. A leaf has height $0$, because both children are null and $\max(-1, -1) + 1 = 0$. Its balance factor is $(-1) - (-1) = 0$. The name records Adelson-Velsky and Landis, who introduced the structure in 1962.

The invariant is checked at every node, not only at the root. A root with balance factor $0$ can still hide a chain deeper down. The insertion and deletion algorithms restore the invariant on the way back to the root, so a public operation returns only when every node on the modified path is balanced and, by induction, every node off the path was already balanced and was not touched.

### 3.2 Insertion, and the first imbalance

AVL insertion is binary-search-tree insertion followed by a walk from the new leaf back to the root. At each node on the way up, recompute the height, the size, and the balance factor. If the balance factor is in $\{-1, 0, 1\}$, continue upward. If it is $+2$ or $-2$, this node is the lowest imbalance, because every descendant was already repaired or was never unbalanced. Repair it with the rotation named by the shape below, then continue upward so that sizes stay correct. For insertion, the repair restores the subtree to the height it had before the new key arrived, so no ancestor becomes unbalanced. There is at most one repair. The walk still continues, because each ancestor contains one more key in its subtree and its size field must say so.

A single insertion changes the height of a node by at most $1$, and only on the path to the new leaf. A balance factor therefore changes by at most $1$. A node whose balance factor becomes $+2$ or $-2$ had balance factor $+1$ or $-1$ before the insertion, leaning toward the side where the key was placed, and that side grew.

### 3.3 The four shapes

Throughout the figures, the labels are the balance factors at the moment before the repairing rotation, after the recursive insertion has returned and the heights have been recomputed. $T_1, T_2, T_3, T_4$ are search trees, possibly empty, whose heights are stated in the case.

**LL, a single right rotation.** The new key landed in the left subtree of the left child. The node $z$ has balance factor $+2$. Its left child $y$ has balance factor $+1$.

```text
          z (+2)                      y (0)
         / \                         / \
     y (+1)  T3        right     T1     z (0)
       / \            ------->        / \
     T1   T2                        T2   T3
```

Let $h$ be the height of $T_2$ and of $T_3$. Then $T_1$ has height $h + 1$, $y$ has height $h + 2$, and the balance factor of $z$ is $(h + 2) - h = +2$. The right rotation of Section 2.1, applied to $z$, produces the right-hand tree. Node $z$ now has two subtrees of height $h$, so its height is $h + 1$ and its balance factor is $0$. Node $y$ has two subtrees of height $h + 1$, so its height is $h + 2$ and its balance factor is $0$.

Before this insertion, $T_1$ had height $h$. A left insertion increases the height of $y$ only when the left side was already at least as tall as the right side, and the first time the height actually grows, the new left height is exactly one more than the right height. So $y$ had height $h + 1$ and $z$ had height $h + 2$ before the key was inserted. The repaired subtree has height $h + 2$. Ancestors see the same child height they saw before the insertion. Their balance factors do not change.

**RR, a single left rotation.** The mirror of LL. The new key landed in the right subtree of the right child. The node has balance factor $-2$ and its right child has balance factor $-1$. One left rotation repairs it. Negating every balance factor and swapping the words "left" and "right" turns the LL proof into the RR proof.

The smallest RR trace is the sorted pair that Lecture 08 would have left as a chain. Insert $10$, then $20$, then $30$.

```text
after 10 and 20                after 30, before rotation

    10 (bf -1)                      10 (bf -2)
      \                               \
      20 (bf 0)                       20 (bf -1)
                                        \
                                        30 (bf 0)
```

Node $10$ is the first imbalance. The shape is RR. A left rotation at $10$ yields

```text
        20 (bf 0, height 1)
       /  \
     10    30          both leaves, balance factor 0, height 0
```

**LR, a left rotation then a right rotation.** The new key landed in the right subtree of the left child. The node $z$ has balance factor $+2$. Its left child $y$ has balance factor $-1$. One rotation is not enough, because a right rotation at $z$ would move the tall side of $y$ into the wrong place. First left-rotate $y$, which straightens the path into an LL shape. Then right-rotate $z$.

```text
        z (+2)                 z (+2)                 x
       / \                    / \                   / \
   y (-1)  T4              x     T4               y     z
     / \       left        / \       right       / \   / \
   T1   x    ------->   y     C    ------->    T1  B  C  T4
       / \              / \
      B   C           T1   B
```

The middle subtrees of the two rotations are $B$ and then the subtree that ends up between $x$ and $z$. Both moves are the middle-subtree move of Section 2.

Let $h$ be the height of $T_1$ at the moment before either rotation, which is also the height of $T_4$. The right child $x$ of $y$ has height $h + 1$, because $y$ has balance factor $-1$ and its height has just grown on the right. Write $B$ and $C$ for the left and right subtrees of $x$. Then $\max(\mathrm{height}(B), \mathrm{height}(C)) = h$. After the double rotation, $y$ has left subtree $T_1$ of height $h$ and right subtree $B$ of height at most $h$, so $y$ has height $h + 1$. Node $z$ has right subtree $T_4$ of height $h$ and left subtree $C$ of height at most $h$, so $z$ has height $h + 1$. Node $x$ has two children of height $h + 1$, so $x$ has height $h + 2$.

Before the insertion, $x$ had height $h$, so $y$ had height $h + 1$ and $z$ had height $h + 2$. The repaired subtree has height $h + 2$. Again the ancestors see no height change. The intermediate tree, after the left rotation and before the right rotation, is not a finished AVL tree. Its balance factor at $z$ is still $+2$, and the node that was $x$ may itself show a balance factor outside $\{-1, 0, 1\}$ for that one instant. The second rotation runs immediately. The intermediate picture is not a tree the algorithm returns.

**RL, a right rotation then a left rotation.** The mirror of LR. The new key landed in the left subtree of the right child. The node has balance factor $-2$ and its right child has balance factor $+1$. Right-rotate the right child, then left-rotate the node.

The four names are the two sides of the path from the unbalanced node down to the new key. LL means left then left. LR means left then right. RR means right then right. RL means right then left. The first letter names the child of the unbalanced node. The second letter names the side of that child that grew. A single rotation repairs a straight path, LL or RR. A double rotation repairs a bent path, LR or RL.

On deletion, the heavy child may have balance factor $0$ rather than $+1$ or $-1$. That case is still repaired by the single rotation, and it is discussed in Section 5. It does not occur on insertion, because a child whose height just grew has a nonzero balance factor.

### 3.4 A numeric LL trace

Insert $50, 30, 70, 20, 40$ into an empty AVL tree. No balance factor leaves $\{-1, 0, 1\}$. The tree is

```text
            50 (bf 0, height 2, size 5)
           /  \
         30    70
        /  \     both 30 and 70 have balance factor 0
      20    40   20, 40, and 70 are leaves
```

Node $30$ has height $1$. Node $50$ has left height $1$ and right height $0$, so its balance factor is $+1$ after $20$ is inserted and returns to $0$ when $40$ fills the other side of $30$. Now insert $10$, which goes left of $20$.

Recompute on the way up. Node $10$ is a leaf: balance factor $0$, height $0$, size $1$. Node $20$ had balance factor $0$; its left height is now $0$ and its right height is $-1$, so its balance factor is $+1$, its height is $1$, and its size is $2$. Node $30$ had balance factor $0$; its left height is now $1$ and its right height is $0$, so its balance factor is $+1$, its height is $2$, and its size is $4$. Node $50$ had balance factor $0$; its left height is now $2$ and its right height is $0$, so its balance factor is $+2$. This is the first imbalance. The left child $30$ has balance factor $+1$. The shape is LL.

```text
before the rotation                         after the right rotation at 50

        50 (bf +2, h 3, size 6)                 30 (bf 0, h 2, size 6)
       /  \                                    /  \
     30    70 (bf 0, h 0, size 1)            20    50 (bf 0, h 1, size 3)
     bf +1, h 2, size 4                     /     /  \
    / \                                   10    40    70
  20   40 (bf 0, h 0, size 1)             bf 0  bf 0  bf 0
  bf +1, h 1, size 2                            all size 1
 /
10 (bf 0, h 0, size 1)
```

The middle subtree is the node $40$. It was the right child of $30$ and becomes the left child of $50$. The inorder sequence $10, 20, 30, 40, 50, 70$ is unchanged. Node $20$ keeps balance factor $+1$: the rotation did not touch it, and a balance factor of $+1$ is legal. The subtree height is $2$. Before $10$ was inserted, node $50$ also had height $2$. The height seen by any ancestor would be unchanged. There is no ancestor here. The laboratory records this rotation as LL at $50$, with child balance factor $+1$, and checks every field in the two pictures.

This picture matches the general LL height count with $h = 0$. The subtree $T_1$ is the node $20$ together with $10$, and that subtree has height $1 = h + 1$. The subtrees $T_2$ and $T_3$ are the leaves $40$ and $70$, both of height $0$.

### 3.5 A numeric LR trace

Insert $40, 20, 50, 10, 30$. The tree is balanced:

```text
            40 (bf +1, height 2, size 5)
           /  \
         20    50 (bf 0, height 0, size 1)
        / \
      10   30     20 has balance factor 0 and height 1
```

Insert $25$. It becomes the left child of $30$. On the way up, $30$ gets balance factor $+1$ and height $1$. Node $20$ has left height $0$ and right height $1$, so its balance factor is $-1$ and its height is $2$. Node $40$ has left height $2$ and right height $0$, so its balance factor is $+2$. The first imbalance is $40$. Its left child $20$ has balance factor $-1$. The shape is LR.

```text
before either rotation

              40 (bf +2, h 3, size 6)
             /  \
           20    50 (bf 0, h 0, size 1)
           bf -1, h 2, size 4
          / \
        10   30 (bf +1, h 1, size 2)
        bf 0  /
             25 (bf 0, h 0, size 1)
```

Left-rotate $20$. The middle subtree of this first rotation is the node $25$, which moves from the left of $30$ to the right of $20$.

```text
after the left rotation at 20, before the right rotation at 40

              40 (bf +2, h 3, size 6)
             /  \
           30    50
           bf +2, h 2, size 4
          /
        20 (bf 0, h 1, size 3)
        / \
      10   25
```

Node $30$ has balance factor $+2$ in this intermediate tree: its left height is $1$ and its right height is $-1$. That is legal only because the algorithm has not finished the repair. The shape at $40$ is now LL. Right-rotate $40$. The middle subtree of the second rotation is empty, because $30$ has no right child, so the left child of $40$ becomes null and $40$ keeps its right child $50$.

```text
after the right rotation at 40

              30 (bf 0, h 2, size 6)
             /  \
           20    40 (bf -1, h 1, size 2)
           bf 0  \
           h 1    50 (bf 0, h 0, size 1)
          / \
        10   25     both balance factor 0, height 0, size 1
```

Node $20$ has size $3$. The inorder sequence $10, 20, 25, 30, 40, 50$ is unchanged. Before $25$ was inserted, the tree had height $2$. After the repair, the tree has height $2$. In the general counting of Section 3.3, this trace is the case $h = 0$: $T_1$ is the leaf $10$, $T_4$ is the leaf $50$, $B$ is the new leaf $25$, and $C$ is empty. The laboratory checks the before picture, the intermediate picture, and the after picture, including the intermediate balance factor $+2$ at node $30$.

### 3.6 What the implementation does on the way up

The insertion function returns the root of the subtree it was given, which may be a different object after a rotation. The caller stores that pointer:

```text
if key < node.key:
    node.left = insert(node.left, key)
else if key > node.key:
    node.right = insert(node.right, key)
else:
    return node unchanged
return rebalance(node)
```

`rebalance` recomputes height and size. If the balance factor is greater than $1$ and the left child's balance factor is negative, it left-rotates the left child and then right-rotates the node. If the balance factor is greater than $1$ and the left child's balance factor is not negative, it only right-rotates the node. The negative tests are the mirror for a balance factor less than $-1$. A duplicate key returns before `rebalance`, so a rejected duplicate does not change sizes.

There is no parent pointer. The assignment `node.left = insert(...)` is the parent link. A rotation returns the new subtree root, and that assignment publishes it. Section 7 uses explicit parent pointers because the red–black repair is written as a loop starting at the new node and walking up, which is the shape of the algorithm in CLRS Chapter 13. Both styles perform the same rotations.

---

## 4. The height of an AVL tree

### 4.1 The minimum number of nodes

Let $N(h)$ be the minimum number of nodes in an AVL tree of height $h$. The goal is a lower bound on $n$ in terms of $h$. Turned around, it is an upper bound on $h$ in terms of $n$.

A tree of height $0$ is a single node, so $N(0) = 1$. The empty tree has height $-1$ and no nodes, so $N(-1) = 0$. Those two values are the base of the recurrence.

Consider an AVL tree of height $h \ge 1$ with as few nodes as possible. The root has height $h$, so the taller child has height $h - 1$. The balance factor is in $\{-1, 0, 1\}$, so the shorter child has height $h - 1$ or $h - 2$. The shorter child of height $h - 1$ has at least $N(h - 1)$ nodes, and the child of height $h - 2$ has at least $N(h - 2)$ nodes. Since $N(h - 1) > N(h - 2)$ once the recurrence is running, the minimum is achieved by making one subtree a minimum tree of height $h - 1$ and the other a minimum tree of height $h - 2$. Counting the root,

$$
N(h) = 1 + N(h - 1) + N(h - 2),
$$

with $N(0) = 1$ and $N(-1) = 0$.

The first values are

$$
\begin{align*}
N(1) &= 1 + N(0) + N(-1) = 2, \\
N(2) &= 1 + 2 + 1 = 4, \\
N(3) &= 1 + 4 + 2 = 7, \\
N(4) &= 1 + 7 + 4 = 12, \\
N(5) &= 1 + 12 + 7 = 20, \\
N(6) &= 1 + 20 + 12 = 33.
\end{align*}
$$

A tree of height $h$ may have more nodes than $N(h)$. It cannot have fewer. Therefore every AVL tree of height $h$ has $n \ge N(h)$ nodes, and every AVL tree of $n$ nodes has a height $h$ satisfying $N(h) \le n$.

### 4.2 The Fibonacci relation

Define the Fibonacci sequence by $F_0 = 0$, $F_1 = 1$, and $F_m = F_{m-1} + F_{m-2}$ for $m \ge 2$. Then $F_2 = 1$, $F_3 = 2$, $F_4 = 3$, $F_5 = 5$, $F_6 = 8$, $F_7 = 13$, $F_8 = 21$, $F_9 = 34$.

**Lemma.** $N(h) = F_{h+3} - 1$ for every $h \ge -1$.

**Proof.** For $h = -1$, $F_2 - 1 = 0$. For $h = 0$, $F_3 - 1 = 1$. Assume the claim for every value smaller than $h$, where $h \ge 1$. Then

$$
N(h) = 1 + (F_{h+2} - 1) + (F_{h+1} - 1) = F_{h+2} + F_{h+1} - 1 = F_{h+3} - 1.
$$

The inductive step uses the Fibonacci recurrence and the two base cases. $\square$

In particular $N(4) = F_7 - 1 = 12$ and $N(6) = F_9 - 1 = 33$, which matches the table above.

### 4.3 A fully proved bound, $h \le 2 \log n$

**Lemma.** $N(h) \ge 2^{h/2}$ for every $h \ge 0$.

**Proof.** For $h = 0$, $N(0) = 1 = 2^0$. For $h = 1$, $N(1) = 2 \ge 2^{1/2}$. For $h \ge 2$, the inductive hypothesis on the two preceding values and the inequality $N(h - 1) \ge N(h - 2)$ give

$$
N(h) = 1 + N(h - 1) + N(h - 2) \ge 1 + 2^{(h-1)/2} + 2^{(h-2)/2}.
$$

The sum of the two powers is $2^{(h-2)/2}(\sqrt{2} + 1)$. Since $\sqrt{2} + 1 > 2$,

$$
N(h) > 2 \cdot 2^{(h-2)/2} = 2^{h/2}.
$$

The inequality is strict for $h \ge 2$, and the base cases are non-strict, so $N(h) \ge 2^{h/2}$ holds for all $h \ge 0$. $\square$

**Theorem.** Every AVL tree with $n \ge 1$ nodes has course height

$$
h \le 2 \log n.
$$

**Proof.** The tree has some height $h$, and $n \ge N(h) \ge 2^{h/2}$. Taking $\log_2$ of both sides, $\log n \ge h/2$, so $h \le 2 \log n$. For $n = 1$ the right side is $0$ and the only possible height is $0$. $\square$

This is an argument from the recurrence, not a name for the word "balanced". The constant $2$ is convenient and loose. The next subsection replaces it by a smaller constant that comes from the same Fibonacci relation.

### 4.4 The golden-ratio bound, proved, and Knuth's cited form

Let $\varphi = (1 + \sqrt{5})/2$. This is the positive root of $x^2 = x + 1$, so $\varphi^2 = \varphi + 1$, and $\varphi > 1$. Numerically $\varphi \approx 1.61803$. The change-of-base formula gives

$$
\log_\varphi x = \frac{\log x}{\log \varphi}, \qquad \frac{1}{\log \varphi} \approx 1.44042.
$$

The second decimal is $1 / \log_2 \varphi$, with $\log_2 \varphi \approx 0.69424$. It is the same constant that appears in the classical AVL bound.

**Lemma.** $F_m \ge \varphi^{m-2}$ for every $m \ge 2$.

**Proof.** $F_2 = 1 = \varphi^0$ and $F_3 = 2 \ge \varphi$. If the claim holds for the two preceding indexes, then

$$
F_m = F_{m-1} + F_{m-2} \ge \varphi^{m-3} + \varphi^{m-4} = \varphi^{m-4}(\varphi + 1) = \varphi^{m-4} \cdot \varphi^2 = \varphi^{m-2}.
$$

$\square$

**Theorem.** Every AVL tree with $n \ge 1$ nodes has course height

$$
h \le \log_\varphi (n + 1) - 1 = \frac{\log (n + 1)}{\log \varphi} - 1.
$$

**Proof.** By the Fibonacci lemma, $n \ge N(h) = F_{h+3} - 1$. For $h \ge 0$ the index $h + 3$ is at least $3$, so the previous lemma applies:

$$
F_{h+3} \ge \varphi^{(h+3)-2} = \varphi^{h+1}.
$$

Hence $n \ge \varphi^{h+1} - 1$, so $n + 1 \ge \varphi^{h+1}$. Taking $\log_\varphi$, which is increasing, gives $h + 1 \le \log_\varphi(n + 1)$, and therefore $h \le \log_\varphi(n + 1) - 1$. $\square$

Since $1 / \log \varphi < 1.441$,

$$
h < 1.441 \log (n + 1) - 1
$$

for every $n \ge 1$, with the understanding that the precise coefficient available from this proof is $1 / \log \varphi \approx 1.44042$. For $n = 1$ the right side is $\log_\varphi 2 - 1 \approx 0.440$, and the height is $0$.

Knuth's Theorem A in Section 6.2.3 of Volume 3 states a sharper numerical form, and it uses a different height. Knuth's height is the number of edges on the longest path from the root to an external node. For a nonempty tree that quantity is exactly one more than this course's height, because the course stops at the last internal node and Knuth takes one more step to the external null. Knuth's balance factor is also the negation of this course's factor: he subtracts the left height from the right height. The shape of his trees is the same. The sign in a diagram copied from that section must be flipped before it can be compared with a balance factor in this lecture.

Under his height $h_K = h + 1$, Theorem A says

$$
\log(n + 1) \le h_K \le 1.4404 \log(n + 2) - 0.3277.
$$

The additive constant is the one in his statement. It comes from the closed form $F_m = (\varphi^m - \psi^m) / \sqrt{5}$, where $\psi = (1 - \sqrt{5})/2$ and $|\psi| < 1$, together with the relation $n \ge F_{h_K+2} - 1$. The algebra that produces a constant near $-0.328$ is the change of base applied to a bound of the shape $\log_\varphi(\sqrt{5}\,(n + 2)) - 2$:

$$
\log_\varphi(\sqrt{5}\,(n + 2)) - 2 = \frac{\log(n + 2)}{\log \varphi} + \log_\varphi(\sqrt{5}) - 2.
$$

Here $\log_\varphi(\sqrt{5}) \approx 1.67228$, so the constant term is about $1.67228 - 2 = -0.32772$, and the coefficient of the logarithm is again about $1.44042$. Knuth's theorem is the cited source for the specific pair $1.4404$ and $0.3277$. Translating into course height subtracts $1$ from his upper bound:

$$
h \le 1.4404 \log(n + 2) - 1.3277.
$$

The laboratory does not need that cited form. It checks the two bounds this section proved in full: $h \le 2 \log n$ and $h \le \log_\varphi(n + 1) - 1$.

### 4.5 Every AVL height is $\Theta(\log n)$, so the operations are too

The upper bound is only half of a tight bound. The matching lower bound is true of every binary tree, balanced or not.

**Lemma.** Any binary tree with $n \ge 1$ nodes has course height $h \ge \log(n + 1) - 1$.

**Proof.** A binary tree of height $h$ has at most $1 + 2 + \cdots + 2^h = 2^{h+1} - 1$ nodes, because level $d$ has at most $2^d$ nodes and the root is level $0$. So $n \le 2^{h+1} - 1$, hence $n + 1 \le 2^{h+1}$, hence $h + 1 \ge \log(n + 1)$. $\square$

Combine the lemmas. For an AVL tree,

$$
\log(n + 1) - 1 \le h \le \frac{\log(n + 1)}{\log \varphi} - 1.
$$

Both sides are constant multiples of $\log(n + 1)$, up to the additive $-1$. Therefore $h = \Theta(\log n)$. The lower bound says the tree cannot be shorter than a perfect tree. The upper bound says the AVL invariant prevents it from being much taller. For $n = 12$, the minimum-node tree has height $4$ because $N(4) = 12$ and $N(5) = 20 > 12$. The proved upper bound is $\log_\varphi 13 - 1 \approx 4.330$. The height $4$ meets it within one unit. The looser bound $2 \log 12 \approx 7.170$ also holds and is not close.

**Theorem.** In an AVL tree, the worst-case costs of search, insert, and delete are $\Theta(\log n)$.

**Proof.** A search compares the target with the key of the current node and steps to one child. That is $\Theta(1)$ work in the RAM model of Lecture 01. The search stops after at most $h + 1$ nodes. If the target is a deepest leaf, or the search falls off a deepest leaf, it inspects $h + 1$ nodes. The worst-case search cost is therefore $\Theta(h)$. Since $h = \Theta(\log n)$, the worst-case search cost is $\Theta(\log n)$.

An insertion walks down the same kind of path, allocates one node, and walks back up. At each of the $O(h)$ nodes on the path it recomputes two integers. It performs at most one repair, and that repair is one rotation or two. A rotation rewrites a constant number of pointers. The worst-case insertion cost is $\Theta(h) = \Theta(\log n)$. The rotation is not the expensive part. The walk is.

A deletion, specified in the next section, walks down to the deleted node, possibly continues to its successor, and walks back to the root, doing a constant amount of work at each node and a constant number of rotations at each node. The successor lies in the subtree of the deleted node, so the whole walk is still $O(h)$ nodes. The worst case is $\Theta(h) = \Theta(\log n)$. $\square$

A successful search for the root is $\Theta(1)$. The $\Theta(\log n)$ claim is a worst-case claim over the choice of the key and over the shape of the AVL tree. It is not an average over random trees. Lecture 08's average for a randomly built unbalanced tree is a different theorem and uses a different hypothesis. The AVL bound does not need that hypothesis. The sorted insertion that opened this lecture is a worst-case input for the unbalanced tree and an ordinary input for the AVL tree. Inserting $1, 2, \ldots, 31$ into an empty AVL tree produces a tree of height $4$, which is the minimum possible height of any binary tree on $31$ nodes, since $2^5 - 1 = 31$. The bound $\log_\varphi(32) - 1 \approx 6.202$ allows height $6$. The tree's height $4$ satisfies it. The laboratory checks the height and every balance factor on that sequence.

---

## 5. AVL deletion

### 5.1 The procedure

Deletion removes a key by the rule of Lecture 08 and then repairs balance factors on the way to the root.

1. Search for the key. If it is absent, stop. The tree is unchanged.
2. If the node has no left child, replace it by its right child. If it has no right child, replace it by its left child. A missing child is a legal replacement: the parent pointer now holds null or the surviving subtree, and that subtree was already an AVL tree.
3. If the node has two children, copy the successor's key into the node. The successor is the minimum node of the right subtree, so it has no left child. Delete the successor by rule 2. Copying the key does not change the size or the height of the node. The size drops when the successor is unlinked.
4. From the parent of the removed node back to the root, recompute height and size. If a balance factor has absolute value $2$, repair it with the same four shapes as insertion, with one extra possibility: the heavy child's balance factor may be $0$.

The walk does not stop at the first rotation. A deletion can decrease the height of the repaired subtree, and an ancestor that was leaning the other way can then reach balance factor $\pm 2$. Insertion cannot do that, because Section 3 showed that the insertion repair restores the old height. Deletion has no such restoration theorem. The implementation therefore rebalances at every node on the path, exactly as the recursive return in Section 3.6 already does.

When the heavy child has balance factor $0$, the shape is still the straight one, LL or RR, and the repair is a single rotation. The resulting balance factors are not all zero. One side of the rotation was equally tall, so the node that moves down keeps a nonzero legal balance factor, and the subtree height may fall by only one or may stay the same depending on the surrounding heights. The worked example is the case that stays instructive and small.

### 5.2 A worked deletion that rotates

Build the tree by inserting $30, 20, 40, 10, 25$, in that order. No rotation occurs. The fields are

```text
              30 (bf +1, height 2, size 5)
             /  \
           20    40 (bf 0, height 0, size 1)
           bf 0, height 1, size 3
          / \
        10   25     both balance factor 0, height 0, size 1
```

Delete $40$, a leaf and the right child of the root. The binary-search-tree step replaces the right child of $30$ by null. Recompute $30$ before any rotation: the left height is $1$ and the right height is $-1$, so the balance factor is $+2$ and the height is $2$. The left child $20$ has balance factor $0$. This is the deletion form of LL. A single right rotation at $30$ repairs it. The middle subtree is the node $25$.

```text
just after 40 is unlinked                 after the right rotation at 30

        30 (bf +2, h 2, size 4)              20 (bf -1, h 2, size 4)
       /                                    /  \
     20 (bf 0, h 1, size 3)               10    30 (bf +1, h 1, size 2)
    / \                                         /
  10   25                                     25
```

Node $30$ after the rotation has balance factor $+1$, not $0$, because its right child is null and its left child $25$ is a leaf. Node $20$ has balance factor $-1$. Both are legal. The inorder sequence was $10, 20, 25, 30, 40$ and is now $10, 20, 25, 30$. The size of the root drops from $5$ to $4$. The laboratory records this repair as an LL rotation whose child balance factor is $0$, and it checks the picture.

The same program deletes keys from trees built in sorted order and in a fixed pseudorandom order, and after every deletion it checks the search property, every balance factor, every size, and the inorder sequence against the set of keys that remain. That is the sense in which the lecture's program deletes. A hand trace of one rotation, without those checks, would not be enough to claim it.

### 5.3 Cost

The walk down is $O(h)$. The successor walk, when it happens, is $O(h)$ and stays inside the subtree. The walk up visits $O(h)$ nodes and performs $O(1)$ rotations at each, hence $O(h)$ rotations in total. Section 4 showed $h = \Theta(\log n)$. The worst-case cost is $\Theta(\log n)$.

---

## 6. Red–black trees

An AVL tree stores a height or a balance factor and rotates as soon as a node leans by two. A red–black tree stores one bit, the color, and allows a taller tree in exchange for a repair that, on insertion, rotates at most twice. The search property is unchanged. The new invariant is the coloring. The height proof is the reason the coloring is worth maintaining.

### 6.1 The five properties

A red–black tree is a binary search tree whose nodes are colored red or black and that satisfies the five properties used by CLRS Chapter 13.

1. Every node is red or black.
2. The root is black.
3. Every leaf is black. The leaves in this definition are the nil children, not the internal nodes that happen to have no key-bearing child.
4. A red node has black children. Equivalently, a red node is never the parent of a red node.
5. For every node, every simple path from that node down to a leaf contains the same number of black nodes.

Property 5 is what forces the tree to be short. Property 4 is what keeps a red node from stretching a path without adding a black node. Property 3 makes the nil children participate in the count. Property 2 removes one special case from the repair. Property 1 is the claim that the color field is total.

The **black-height** of a node $u$, written $\mathrm{bh}(u)$, is the number of black nodes on any simple path from $u$ down to a leaf, not including $u$ itself. Property 5 says this number does not depend on which path is chosen. The black-height of a nil leaf is $0$, because the path from a leaf to itself contains no node below the leaf. If $u$ is black, the black-height of $u$ is not increased by $u$'s own color. The color of $u$ is counted in the black-height of the parent of $u$.

### 6.2 Nil sentinels

CLRS uses one shared sentinel object $T.\mathrm{nil}$. Every missing child pointer refers to that object. The sentinel is black, its parent pointer is unused, and it has no key. Sharing one object saves a node per missing child and gives every real node a non-null child pointer, which simplifies a few boundary tests.

The laboratory uses `null` instead of a sentinel object. The reading rule is the same: a null child is a black leaf, and code must test for null before it reads a color. The black-height of null is $0$. A red node whose children are both null satisfies property 4, because null is black. The root's parent is null, and the insertion loop treats a null parent as "stop", not as a red parent. These conventions implement the five properties. They do not implement a different kind of tree.

An internal node with two null children is a leaf of the course-height convention: its course height is $0$. In the red–black convention that same node has two black leaves under it, and the CLRS height, defined next, counts the edge down to those leaves.

### 6.3 The height is at most $2 \log(n + 1)$

Two height words are in play, and the proof is false if they are mixed.

The **CLRS height** of a node is the number of edges on the longest simple path from the node down to a nil leaf. A single black node has CLRS height $1$, because the path reaches a nil child. The **course height** of that same tree is $0$. For every nonempty red–black tree the course height equals the CLRS height minus $1$. The theorem below bounds the CLRS height. The course height is then at most $2 \log(n + 1) - 1$.

**Lemma.** The subtree rooted at any node $u$ contains at least $2^{\mathrm{bh}(u)} - 1$ internal nodes.

**Proof.** Induction on the course height of the subtree, which is well-founded because every child has smaller course height and a nil leaf has no internal nodes.

If $u$ is nil, then $\mathrm{bh}(u) = 0$ and the number of internal nodes is $0 = 2^0 - 1$.

If $u$ is internal, each child $v$ has black-height $\mathrm{bh}(u)$ when $v$ is red and black-height $\mathrm{bh}(u) - 1$ when $v$ is black, including when $v$ is nil. In both situations $\mathrm{bh}(v) \ge \mathrm{bh}(u) - 1$. The inductive hypothesis gives each child subtree at least $2^{\mathrm{bh}(u) - 1} - 1$ internal nodes. Adding $u$ itself,

$$
1 + 2\left(2^{\mathrm{bh}(u) - 1} - 1\right) = 2^{\mathrm{bh}(u)} - 1.
$$

$\square$

Apply the lemma to the root. If the tree has $n$ internal nodes and the root has black-height $\mathrm{bh}$, then $n \ge 2^{\mathrm{bh}} - 1$, so

$$
\mathrm{bh} \le \log(n + 1).
$$

**Theorem.** A red–black tree with $n$ internal nodes has CLRS height at most $2 \log(n + 1)$.

**Proof.** Let $h_{\mathrm{CLRS}}$ be the CLRS height of the root, and consider a longest simple path from the root down to a nil leaf. That path has $h_{\mathrm{CLRS}}$ edges and therefore $h_{\mathrm{CLRS}}$ nodes strictly below the root, the last of which is nil. Among those $h_{\mathrm{CLRS}}$ nodes, exactly $\mathrm{bh}$ are black, by the definition of black-height.

At least half of those nodes are black. The root is black by property 2, but the root is not in this count. Property 4 says a red node has black children, so no two red nodes are adjacent. The nil at the end of the path is black. On a path that starts just below a black root and ends at a black nil, every red node is followed by a black node. The red nodes can therefore be injected into the black nodes among these $h_{\mathrm{CLRS}}$ nodes, and the number of red nodes is at most the number of black nodes. Hence the number of black nodes is at least half the length of this list:

$$
\mathrm{bh} \ge \frac{h_{\mathrm{CLRS}}}{2}.
$$

Combined with $\mathrm{bh} \le \log(n + 1)$,

$$
h_{\mathrm{CLRS}} \le 2\,\mathrm{bh} \le 2 \log(n + 1).
$$

$\square$

The same counting says the course height is at most $2 \log(n + 1) - 1$. Any binary tree also has course height at least $\log(n + 1) - 1$, by the lemma in Section 4.5. A red–black tree therefore has course height $\Theta(\log n)$, and search is $\Theta(\log n)$ in the worst case by the same walk argument as in the AVL theorem. Insertion will be $\Theta(\log n)$ as well, once Section 7 shows that the repair walks at most one path and does a constant amount of work per node.

The bound is about twice the perfect-tree height. An AVL tree is tighter. The red–black tree buys the looser bound with a one-bit field and, on insertion, at most two rotations.

---

## 7. Red–black insertion

### 7.1 The binary-search-tree step

Insertion begins as in Lecture 08. Walk down by key comparison. A duplicate key leaves the tree unchanged. A missing key becomes a new node in the null position where the walk fell off. Color the new node red. A red node does not change the black-height of any ancestor, because black-height does not count red nodes. Properties 1, 2, 3, and 5 still hold, except that if the new node is the root it is red and property 2 fails, which the last line of the repair corrects by painting the root black. The only property that can fail in the middle of the tree is property 4: the new red node may have a red parent.

If the parent is black, property 4 holds and the algorithm stops, after painting the root black if the new node is the root. If the parent is red, the parent is not the root, because the root is black, so the grandparent exists and is black. The repair loop below removes the red-red pair. The loop invariant is that there is at most one red-red pair, it involves the current node $z$ and its parent, the root is the only node that might still need to be painted black, and properties 1, 3, and 5 hold.

### 7.2 The three cases

Write $p$ for the parent of $z$ and $g$ for the grandparent. The **uncle** is the sibling of $p$, the other child of $g$. A null uncle is black. The cases are symmetric. The writeup takes $p$ as the left child of $g$. The other side swaps left and right and swaps the direction of each rotation.

**Case 1: the uncle is red.** Paint $p$ black, paint the uncle black, and paint $g$ red. Set $z$ to $g$ and repeat the loop. This is recoloring. No pointer changes.

The black-height is preserved. Any path through $g$ previously counted exactly one of $p$ and the uncle as black below $g$, because both were red and are now black, while $g$ itself has changed from black to red and is not counted in its own black-height. Paths that do not go through $g$ are untouched. The red-red violation, if it still exists, is now between $g$ and the parent of $g$, two levels higher. The loop moves up. If $g$ is the root, the loop condition fails because the root has no parent, and the final line paints the root black.

**Case 2: the uncle is black, and $z$ is the right child of $p$.** This is the triangle. The path $g, p, z$ bends. Left-rotate $p$, and set $z$ to the old parent, which is now the left child of the node that rotated up. The uncle of the new $z$ is still black. The configuration is now the line of Case 3. The algorithm does not go back to the top of the loop. It falls through into Case 3. This is the CLRS arrangement, and it is the arrangement in the laboratory program.

**Case 3: the uncle is black, and $z$ is the left child of $p$.** This is the line. Paint $p$ black, paint $g$ red, and right-rotate $g$. The old parent $p$ is now black and is the parent of $z$, so property 4 holds at $z$. The node $p$ is black, so the loop condition fails if the loop were entered again at $z$. The algorithm terminates this loop. A Case 2 that fell through into Case 3 performs two rotations. A pure Case 3 performs one. No later iteration adds another rotation.

The symmetric three cases, with $p$ the right child of $g$, use a right rotation for the triangle and a left rotation for the line.

After the loop, paint the root black. If the root was already black this does nothing. If Case 1 propagated a red color to the root, this restores property 2. Painting the root black increases the black-height of the whole tree by one and increases every root-to-leaf black count by the same one, so property 5 survives.

**Rotation count.** Case 1 rotates zero times and moves $z$ up. Case 2 rotates once and falls into Case 3. Case 3 rotates once and stops. One insertion therefore performs at most two rotations. It may recolor along the whole path, so the repair is still $\Theta(h)$ in the worst case, which is $\Theta(\log n)$ by Section 6. The initial walk down is also $\Theta(h)$ in the worst case. Red–black insertion is $\Theta(\log n)$ in the worst case.

The laboratory implements this insertion and checks the five properties after every insertion of several sequences, including the trace in this section. It does not contain a red–black deletion. CLRS Chapter 13.4 enumerates the deletion cases. They are longer than insertion because deleting a black node changes a black-height, and the fixup has to restore the count with its own recoloring and rotations. Describing that list without an implementation that the laboratory checks would only pretend to specify the algorithm. The cases exist, and that chapter is the reference.

### 7.3 A short trace that uses the line

Insert $1$, then $2$, then $3$.

After $1$, the new red root is painted black.

```text
1 B
```

After $2$, the new node is red and its parent is black. The loop does not run.

```text
    1 B
     \
      2 R
```

After $3$, the new node is red and its parent $2$ is red. The grandparent is $1$. The uncle, the left child of $1$, is null and therefore black. Node $3$ is the right child of $2$, and $2$ is the right child of $1$, so this is a line on the right side, the symmetric Case 3, not a triangle. Paint $2$ black, paint $1$ red, and left-rotate $1$.

```text
        2 B
       / \
     1 R   3 R
```

The root is already black. Both red nodes have black children, counting null as black. The path $2, 1, \mathrm{nil}$ has, below the root, one red node and one black nil, so $\mathrm{bh}(2) = 1$. The right path $2, 3, \mathrm{nil}$ has the same black count. The tree is a black node with two red children. Section 8 will call that shape a 4-node.

### 7.4 A full trace, the CLRS insertion sequence

Insert $11, 2, 14, 1, 7, 15, 5, 8, 4$, in that order. Colors are written after the repair of that insertion. B is black and R is red.

Insert $11$. Paint the root black. The tree is `11 B`.

Insert $2$ and then $14$. Both parents are black.

```text
         11 B
        /    \
      2 R    14 R
```

Insert $1$, as the left child of $2$, colored red. The parent $2$ is red. The uncle $14$ is red. Case 1: paint $2$ and $14$ black, paint $11$ red, move $z$ to $11$. The parent of $11$ is null, so the loop stops. Paint the root black.

```text
         11 B
        /    \
      2 B    14 B
     /
   1 R
```

Insert $7$, the right child of $2$. The parent is black. No repair.

```text
         11 B
        /    \
      2 B    14 B
     / \
   1 R  7 R
```

Insert $15$, the right child of $14$. The parent is black. No repair.

```text
         11 B
        /    \
      2 B    14 B
     / \       \
   1 R  7 R    15 R
```

Insert $5$, the left child of $7$, colored red. The parent $7$ is red. The grandparent is $2$. The uncle is $1$, which is red. Case 1: paint $7$ and $1$ black, paint $2$ red, move $z$ to $2$. The parent of $2$ is $11$, which is black, so the loop stops. The root stays black.

```text
          11 B
         /    \
       2 R    14 B
      / \       \
    1 B  7 B    15 R
        /
      5 R
```

Insert $8$, the right child of $7$. The parent $7$ is black. No repair.

```text
          11 B
         /    \
       2 R    14 B
      / \       \
    1 B  7 B    15 R
        / \
      5 R  8 R
```

Every red node has black children. The black-height of $11$ is $2$. One path is $11, 2, 1, \mathrm{nil}$: below $11$ the black nodes are $1$ and nil. Another path is $11, 14, 15, \mathrm{nil}$: below $11$ the black nodes are $14$ and nil. Another is $11, 2, 7, 5, \mathrm{nil}$: below $11$ the black nodes are $7$ and nil.

Insert $4$, the left child of $5$, colored red. The parent $5$ is red. The uncle $8$ is red. Case 1: paint $5$ and $8$ black, paint $7$ red, move $z$ to $7$.

```text
          11 B
         /    \
       2 R    14 B
      / \       \
    1 B  7 R    15 R
        / \
      5 B  8 B
     /
   4 R
```

Now $z$ is $7$, and its parent $2$ is red. The grandparent is $11$. The uncle is $14$, which is black. Node $7$ is the right child of the left child $2$. This is the triangle, Case 2. Left-rotate the parent $2$, and set $z$ to the old parent $2$.

```text
            11 B
           /    \
         7 R    14 B
        / \       \
      2 R  8 B    15 R
     / \
   1 B  5 B
       /
     4 R
```

The current $z$ is $2$, the left child of $7$, and $7$ is the left child of $11$. The uncle of this $z$ is still $14$, black. This is the line, Case 3, reached by falling through. Paint $7$ black, paint $11$ red, and right-rotate $11$.

```text
              7 B
            /     \
         2 R       11 R
        / \       /    \
      1 B  5 B  8 B    14 B
          /              \
        4 R              15 R
```

The root is already black. Check the properties on this final tree, because the trace is the one the laboratory rebuilds.

- Every node is red or black by construction.
- The root $7$ is black.
- Every null child is treated as a black leaf.
- The red nodes are $2, 11, 4, 15$. The children of $2$ are $1$ and $5$, both black. The children of $11$ are $8$ and $14$, both black. The children of $4$ and of $15$ are null, hence black.
- The black-height of $7$ is $2$. The path $7, 2, 1, \mathrm{nil}$ has black nodes $1$ and nil below the root. The path $7, 2, 5, 4, \mathrm{nil}$ has black nodes $5$ and nil. The path $7, 11, 8, \mathrm{nil}$ has black nodes $8$ and nil. The path $7, 11, 14, 15, \mathrm{nil}$ has black nodes $14$ and nil.

The inorder sequence is $1, 2, 4, 5, 7, 8, 11, 14, 15$. The laboratory checks that sequence, this shape, and the black-height.

This insertion used Case 1 three times ($1$, then $5$, then the first step of $4$), and it used Case 2 followed by Case 3 once, at the end. The loop moved up on each Case 1. The triangle did not move the problem to an ancestor above the old grandparent. It straightened the path and the line rotation finished the repair.

Sedgewick and Wayne, Section 3.3, present a different red–black insertion, the left-leaning variant, in which a red node is always a left child and the cases are written as local transformations on the way down or at the current node. That algorithm maintains a red–black tree. It is not the loop above, and a trace of one is not a trace of the other. This lecture follows CLRS.

---

## 8. 2–3–4 trees and B-trees

Rotations repair a binary node after it leans too far. A multiway node can instead refuse to become too full. The 2–3–4 tree is the smallest interesting version. The B-tree is the same idea with a tunable width, aimed at a disk page.

### 8.1 2–3–4 trees

A **2–3–4 tree** is a search tree with three kinds of node.

- A **2-node** holds one key and two children.
- A **3-node** holds two keys and three children.
- A **4-node** holds three keys and four children.

The keys inside a node are sorted. Between the keys, the subtrees obey the search property. If a node holds keys $k_1 < k_2 < \cdots$ and its children are $c_0, c_1, c_2, \ldots$, then every key in $c_0$ is less than $k_1$, every key in $c_i$ lies strictly between $k_i$ and $k_{i+1}$, and every key in the last child is greater than the last key. Every leaf is at the same depth. An empty child does not occur in the middle of the tree: a leaf has no children, and an internal node has one more child than it has keys. A single-node tree is a leaf and has course height $0$, which matches the height convention of the course. The height of a 2–3–4 tree is the number of edges from the root to a leaf.

Search compares the target with the keys of the current node and either stops or steps into one child. The path has length equal to the height.

### 8.2 The correspondence with red–black trees

There is a standard structural correspondence between 2–3–4 trees and red–black trees.

- A 2-node is a black node whose children, in the red–black tree, are black.
- A 3-node is a black node with exactly one red child. The black node holds one of the two keys and the red child holds the other. The red child may be on the left or on the right, so one 3-node has two red–black drawings.
- A 4-node is a black node with two red children. If the 4-node holds keys $A < B < C$, the black node holds $B$, the left red child holds $A$, and the right red child holds $C$.

The tree of Section 7.3, a black root with two red children, is the 4-node $[1, 2, 3]$ under this reading. Gluing each red node to its black parent, and letting each black node be one level, turns the red–black tree into a 2–3–4 tree whose leaves are at equal depth. The equal depth is property 5. The absence of a red-red edge is what makes every glued piece a 2-node, a 3-node, or a 4-node rather than a node with more keys.

The correspondence is a relation between shapes. It is not a claim that the CLRS insertion loop of Section 7 executes the splits of the next subsection one for one. Those splits are a top-down procedure. The CLRS loop is a bottom-up procedure. Both maintain their own invariant. A top-down red–black insertion that recolors a black node with two red children before descending is the near relative of the 2–3–4 split. This lecture does not switch the traced red–black algorithm to that variant.

### 8.3 Insertion by splitting 4-nodes on the way down

A 4-node has no room for another key. The insertion rule is: while walking down to the leaf where the new key belongs, split every 4-node you meet before you step into it. Splitting a 4-node $[A, B, C]$ replaces it by two 2-nodes $[A]$ and $[C]$, and inserts the middle key $B$ into the parent, in order. The children move with their keys: the two children to the left of $B$ stay under $[A]$, and the two children to the right of $B$ stay under $[C]$.

The parent has room for $B$ because of the order of the walk. If the parent had been a 4-node, it would have been split when the walk stood there, before the walk descended. The root is the exception that has no parent. If the root is a 4-node, the split creates a new root holding the middle key, and the tree grows by one level at the top. Growing at the top is what keeps the leaves level.

After the walk reaches a leaf, that leaf is not a 4-node, so the new key can be inserted into it in order. A duplicate key is rejected and causes no split.

**Trace.** Insert $1, 2, 3, 4, 5, 6, 7, 8$ into an empty 2–3–4 tree.

Insert $1$, then $2$, then $3$. The root becomes the 4-node $[1, 2, 3]$.

Insert $4$. The root is a 4-node, so split it before inserting. The middle key $2$ becomes a new root. The left node is $[1]$. The right node is $[3]$. Then $4$ is greater than $2$, and the right node is a 2-node, so it becomes $[3, 4]$.

```text
        [2]
       /   \
     [1]   [3, 4]
```

Insert $5$. The root is not a 4-node. The right child is a 3-node, not a 4-node. Insert into it.

```text
        [2]
       /   \
     [1]   [3, 4, 5]
```

Insert $6$. The right child is a 4-node. Split it before descending. The middle key $4$ moves up into the root, which had room and becomes $[2, 4]$. The split children are $[3]$ and $[5]$. Then $6$ belongs in $[5]$, which becomes $[5, 6]$.

```text
          [2, 4]
        /    |    \
     [1]   [3]   [5, 6]
```

Insert $7$. The node $[5, 6]$ is a 3-node. It becomes $[5, 6, 7]$.

```text
          [2, 4]
        /    |    \
     [1]   [3]   [5, 6, 7]
```

Insert $8$. The root $[2, 4]$ is a 3-node, so it is not split. The child $[5, 6, 7]$ is a 4-node. Split it. The middle key $6$ moves up, and the root becomes the 4-node $[2, 4, 6]$. The split children are $[5]$ and $[7]$. Then $8$ belongs in $[7]$, which becomes $[7, 8]$.

```text
            [2, 4, 6]
          /   |   |   \
       [1]  [3]  [5]  [7, 8]
```

The height is $1$. All four children are leaves. The inorder sequence is $1, 2, 3, 4, 5, 6, 7, 8$. The laboratory rebuilds this tree after every insertion and checks this final shape.

Temporary 4-nodes are allowed. The root at the end is a 4-node, and the root after inserting $3$ was a 4-node. The rule splits a 4-node when a later insertion walks through it, not in the same breath as the insertion that filled it.

### 8.4 B-trees, and why the node is wide

A B-tree of **minimum degree** $t \ge 2$ generalizes the 2–3–4 tree. The integer $t$ is fixed for the tree.

- Every node holds at most $2t - 1$ keys. A node with $2t - 1$ keys is **full**.
- Every node other than the root holds at least $t - 1$ keys.
- The root holds at least one key if the tree is nonempty, and at most $2t - 1$ keys.
- A leaf has no children. An internal node with $k$ keys has $k + 1$ children.
- All leaves are at the same depth.
- The keys inside a node are sorted, and the children between them obey the same search property as in a 2–3–4 tree.

For $t = 2$, the minimum number of keys in a non-root node is $1$ and the maximum is $3$. The legal nodes are exactly 2-nodes, 3-nodes, and 4-nodes. A 2–3–4 tree is a B-tree of minimum degree $2$. The laboratory uses one implementation, parameterized by $t$, and the trace of Section 8.3 is the case $t = 2$.

The width is the point. A binary tree of a million keys has height near $20$ if it is perfectly balanced, and each step is one node. If the nodes live on a disk, each step can cost a page read. A B-tree puts many keys in one node so that one page read examines many keys, and the height is logarithmic in $n$ with base $t$ rather than with base $2$. If $t = 100$, then $\log_{100}(10^6) = 3$, so a tree of a million keys has height at most a small integer once the precise bound below is applied. The number $100$ is an illustration of the base of the logarithm, not a measurement of a particular disk. The cost model that matters for that motivation is the number of nodes touched, because that is the number of page reads if each node is stored as a page. In the RAM model the same algorithm also spends time looking at the keys inside a node.

Search starts at the root. Inside a node, scan the sorted keys until the target is found or the correct child is identified. A linear scan looks at $O(t)$ keys. A binary search inside the node looks at $O(\log t)$ keys. The walk visits $O(h)$ nodes. With a linear scan the RAM cost is $O(t h)$. With binary search inside the node it is $O(h \log t) = O(\log n)$ when the height bound below is in force, because $h \log t$ is proportional to $\log n$. The page-read cost is $\Theta(h)$ in the worst case either way, for a fixed layout of one node per page. The laboratory scans linearly, which is the right cost for the small values of $t$ it tests, and the prose does not pretend the scan is free.

### 8.5 Insertion with a split

B-tree insertion is the 2–3–4 rule with the width changed. On the way down, if the current node is full, split it before descending. The median key moves up. For a full node the keys are indexed $0, 1, \ldots, 2t - 2$ in the laboratory, which is 0-indexed. The median is the key at index $t - 1$. The left node keeps the $t - 1$ keys before the median. The right node keeps the $t - 1$ keys after the median. The children split the same way: the left node keeps the first $t$ children, and the right node keeps the remaining $t$ children. If the full node is the root, create a new root whose only child is the old root, then split that child. The new root receives the median and is not full.

For $t = 3$ a node holds at most $5$ keys and, unless it is the root, at least $2$ keys. The median of a full node is the key at index $2$, the third key.

**Trace.** Insert $10, 20, 30, 40, 50, 60, 25, 35, 70, 80$ into an empty B-tree of minimum degree $3$.

The first five keys fit in the root. A root may hold $5$ keys. After $50$ the tree is the single node

```text
[10, 20, 30, 40, 50]
```

Insert $60$. The root is full. Split it. The median is $30$. The new root is $[30]$. The left child is $[10, 20]$. The right child is $[40, 50]$. The key $60$ belongs on the right, and that child is not full, so it becomes $[40, 50, 60]$.

```text
            [30]
           /    \
     [10, 20]   [40, 50, 60]
```

Insert $25$. It belongs on the left. The left child is not full.

```text
              [30]
             /    \
     [10, 20, 25]  [40, 50, 60]
```

Insert $35$. It belongs on the right and lands before $40$.

```text
              [30]
             /    \
     [10, 20, 25]  [35, 40, 50, 60]
```

Insert $70$. The right child has four keys and can hold five. It becomes $[35, 40, 50, 60, 70]$. It is now full. The split waits until an insertion walks through it.

Insert $80$. The root $[30]$ is not full. The right child is full, so split it before descending. The median of $[35, 40, 50, 60, 70]$ is $50$. The median moves up, and the root becomes $[30, 50]$. The left half is $[35, 40]$. The right half is $[60, 70]$. The key $80$ belongs in the right half, which becomes $[60, 70, 80]$.

```text
                 [30, 50]
               /     |     \
     [10, 20, 25]  [35, 40]  [60, 70, 80]
```

The height is $1$. The root has two keys, which is legal for a root and would also be legal for a non-root when $t = 3$. Each non-root node has at least $2$ keys. No node has more than $5$. The inorder sequence is $10, 20, 25, 30, 35, 40, 50, 60, 70, 80$. Searching for $70$ examines the root, sees that $70 > 50$, and examines the right child, where $70$ is present. Two nodes, which is one more than the height.

The laboratory checks this tree after every insertion.

### 8.6 The height bound

**Theorem.** A nonempty B-tree of minimum degree $t \ge 2$ with $n$ keys has height

$$
h \le \log_t \frac{n + 1}{2}.
$$

**Proof.** The shortest possible tree of height $h$ is the one that overflows as late as possible. The root has at least one key. It has at least two children if $h \ge 1$. Every node below the root has at least $t - 1$ keys, and an internal node with the minimum number of keys has $t$ children. Counting level by level, the minimum number of keys is

$$
n \ge 1 + (t - 1)\bigl(2 + 2t + 2t^2 + \cdots + 2t^{h-1}\bigr)
$$

when $h \ge 1$. The sum in parentheses is a geometric series:

$$
2(1 + t + \cdots + t^{h-1}) = 2 \cdot \frac{t^h - 1}{t - 1}.
$$

Multiply by $t - 1$:

$$
n \ge 1 + 2(t^h - 1) = 2t^h - 1.
$$

The same formula $n \ge 2t^h - 1$ holds for $h = 0$, because a single node has at least one key and $2t^0 - 1 = 1$. Therefore

$$
n + 1 \ge 2t^h, \qquad \frac{n + 1}{2} \ge t^h, \qquad h \le \log_t \frac{n + 1}{2}.
$$

$\square$

For fixed $t$ this is $O(\log n)$. The base is $t$, so increasing the minimum degree shortens the bound. For the final tree of the trace, $n = 10$ and $t = 3$, so the bound is $\log_3(11/2) = \log_3 5.5 \approx 1.551$, and the actual height $1$ satisfies it. For the single full root before any split, $n = 5$ and $h = 0$, and the bound is $\log_3(3) = 1$.

### 8.7 Deletion, described and not implemented

B-tree deletion has to remove a key and then restore the minimum occupancy. The cases, written out in CLRS Chapter 18.3, are these in outline.

- If the key is in a leaf and the leaf still has at least $t$ keys after the removal, delete it from the leaf.
- If the key is in an internal node, the algorithm replaces it with the predecessor or the successor, which lives in a leaf, and deletes that copy from the leaf, or it merges children when both neighbors are too sparse to give up a key.
- If a node would be left with fewer than $t - 1$ keys, the algorithm borrows a key from an immediate sibling, through the parent, or merges the node with a sibling and pulls a key down from the parent. A merge can make the parent too small, so the repair continues upward. The root is allowed to become empty of keys only in the sense that a root with a single child and no key is replaced by that child, and the height drops.

A 2–3–4 deletion is the same list with $t = 2$. The laboratory does not implement these cases. The insertion traces and the occupancy checks are what the program stands behind. Deletion is specified by the case list in CLRS, not by code in this lecture.

---

## 9. Augmenting a tree with subtree sizes

CLRS develops, in the fourth edition's Chapter 17 and in the third edition's Chapter 14, a discipline for adding a field to a search tree without losing the logarithmic bound. The field in this lecture is the subtree size. The operations it buys are the order statistics select and rank. The part that fails in a careless implementation is the rotation, not the search.

### 9.1 The field and the invariant

Every node stores `size`, the number of nodes in its subtree, including itself. The invariant is

$$
\mathrm{size}(u) = 1 + \mathrm{size}(u.\mathrm{left}) + \mathrm{size}(u.\mathrm{right}),
$$

with $\mathrm{size}(\mathrm{null}) = 0$. A leaf has size $1$. The root's size is $n$.

The field is determined by the node and its children. Recomputing it is $\Theta(1)$ once the children are correct. CLRS isolates that fact because it is the condition under which insert and delete remain $O(\log n)$: the existing algorithm already visits $O(\log n)$ nodes, and it does $O(1)$ extra work at each. A field that required a walk of the whole subtree would destroy the bound. Size does not.

The AVL implementation of Sections 3 and 5 already recomputes size in `update`, and it does so after every child-pointer change, including both nodes of every rotation, lower node first. That is the augmentation. The tree does not need a second copy of the rotation code. It needs the existing rotation to tell the truth about size. The laboratory checks sizes after the standalone rotation of Section 2, after the LL and LR traces, and after every insertion and deletion in the stress sequence.

### 9.2 Select

The **order statistic** of rank $k$, for $1 \le k \le n$, is the $k$-th smallest key. Rank $1$ is the minimum. Rank $n$ is the maximum. `select(k)` returns that key. It does not list the tree.

At a node $u$, let $i = \mathrm{size}(u.\mathrm{left}) + 1$. The search property says the left subtree is exactly the set of keys in this subtree that are smaller than $u.\mathrm{key}$. There are $\mathrm{size}(u.\mathrm{left})$ of them. Therefore $u.\mathrm{key}$ is the $i$-th smallest key in the subtree rooted at $u$.

- If $k = i$, return $u.\mathrm{key}$.
- If $k < i$, the answer lies in the left subtree. Recur there with the same $k$.
- If $k > i$, the answer lies in the right subtree, and the $i$ keys consisting of the left subtree plus $u$ itself are smaller than every key on the right. Recur on the right with $k - i$.

If $k$ is outside $1, \ldots, \mathrm{size}(u)$, the call fails. There is no such order statistic.

**Theorem.** `select(k)` returns the $k$-th smallest key of the subtree.

**Proof.** Induction on the size of the subtree. If the size is $1$, then $k = 1$ and $i = 1$, and the single key is the answer. If the size is larger, the invariant says $i = \mathrm{size}(\mathrm{left}) + 1$ is the inorder position of the root inside this subtree. The three branches above send the search to the unique region that contains the $k$-th key, and the inductive hypothesis applies to a strictly smaller subtree. The search property is what makes "smaller than the root" coincide with "in the left subtree". The size invariant is what makes the count equal to $i$. Either hypothesis alone is not enough. $\square$

The walk has length $O(h)$. In the AVL tree, that is $O(\log n)$.

### 9.3 Rank

`rank(key)` returns the 1-based inorder position of `key`, which is one plus the number of keys strictly smaller than `key`. The key must be present. An absent key is a failed search, not a rank.

- If `key` equals the node's key, return $\mathrm{size}(\mathrm{left}) + 1$.
- If `key` is smaller, the rank inside the whole tree is the rank inside the left subtree.
- If `key` is larger, every key in the left subtree is smaller than it, and so is the node's own key. Return $\mathrm{size}(\mathrm{left}) + 1$ plus the rank of `key` inside the right subtree.

**Theorem.** If `key` is present, `rank(key)` is its 1-based inorder position.

**Proof.** Induction on the length of the search path. At the node where the key is found, the left subtree is exactly the set of keys in this subtree that are smaller, so the position inside this subtree is $\mathrm{size}(\mathrm{left}) + 1$. Each time the search steps to the right, the formula adds the keys that the search property declares smaller than everything in that right subtree. Each time the search steps to the left, no keys outside that left subtree are smaller than the target, so the position is unchanged. Summing these contributions produces the position in the whole tree. $\square$

On the LL tree of Section 3.4, the inorder sequence is $10, 20, 30, 40, 50, 70$. So `select(1) = 10`, `select(4) = 40`, `select(6) = 70`, `rank(10) = 1`, and `rank(40) = 4`. The size of node $50$ after the rotation is $3$, which is why `select` at the root, asked for rank $5$, computes $i = \mathrm{size}(20) + 1 = 3$ at the root $30$, steps right with $5 - 3 = 2$, and finds $40$ as the second key in the subtree of $50$. The laboratory checks these calls.

### 9.4 What must be updated, and what this does not do

Any algorithm that changes a child pointer must recompute size on every node whose subtree changed. For AVL insertion and deletion that set is the path back to the root, plus the two nodes inside each rotation, which already lie on that path or are created by it. The lower-then-higher order inside the rotation is mandatory.

The same idea supports other fields. A subtree sum of the keys is maintained by the same discipline, with $\mathrm{sum}(u) = u.\mathrm{key} + \mathrm{sum}(u.\mathrm{left}) + \mathrm{sum}(u.\mathrm{right})$. This lecture implements size, select, and rank. It does not implement subtree sums. The independent assignment does.

Select and rank do not sort the tree. The inorder sequence is already the sorted order. The size fields are a way to jump to the $k$-th position in that sequence in $O(\log n)$ time. A sorted array answers the same queries in $O(1)$ time after $O(\log n)$ binary search for the rank, but it does not support insertion in $O(\log n)$ time. The augmented tree is the structure that supports both.

---

## 10. What each structure guarantees

The table compares guarantees. It does not compare benchmark timings. The hash-table row is a forward pointer to Lecture 11. This lecture does not derive it.

| Structure | Order of keys | Worst-case search | Worst-case insert and delete | The guarantee you are buying | A reason to refuse it |
| --- | --- | --- | --- | --- | --- |
| AVL tree | Sorted | $\Theta(\log n)$ | $\Theta(\log n)$. Insertion rotates at most twice. Deletion may rotate at several nodes on the path. | Every balance factor lies in $\{-1, 0, 1\}$, and the course height satisfies $h \le \log_\varphi(n + 1) - 1$. | A workload that rotates constantly and would tolerate the looser red–black height. |
| Red–black tree | Sorted | $\Theta(\log n)$ | Insertion is $\Theta(\log n)$ and rotates at most twice. Deletion is specified by CLRS Chapter 13.4, which proves an $O(\log n)$ bound; this lecture does not prove or implement those cases. | The five color properties, and CLRS height at most $2 \log(n + 1)$. | You need the stricter AVL height bound, or you need the deletion proof from CLRS rather than from this lecture. |
| B-tree of minimum degree $t$ | Sorted | $\Theta(\log n)$ key comparisons when each node is binary-searched; $\Theta(h)$ nodes touched, with $h \le \log_t((n + 1)/2)$ | The same bound for insertion. Deletion has the same height bound when it is implemented as in CLRS Chapter 18.3; this lecture does not implement it. | Node occupancy between $t - 1$ and $2t - 1$ keys, except the root, and all leaves at one depth. A 2–3–4 tree is the case $t = 2$. | The set fits in a binary tree and the extra keys per node buy nothing, or $t$ is so large that a linear scan of one node dominates. |
| Sorted array | Sorted | $\Theta(\log n)$ by binary search | $\Theta(n)$, because insertion and deletion shift a suffix of the array | Contiguous sorted keys and $O(1)$ extra memory per key beyond the array | Updates are frequent. |
| Hash table | Not sorted | Lecture 11: expected $\Theta(1)$ under the hashing assumption of that lecture. This lecture does not prove it. The worst case is not a logarithmic guarantee. | The same forward pointer. | Membership without order | You need successor, range reporting, inorder, select, or a worst-case logarithmic bound. |

An AVL tree and a red–black tree answer the same dictionary operations with the same asymptotic worst-case bound. The difference is the constant hidden by $\Theta$ and the strictness of the height. A B-tree answers them with a bound whose base is the page capacity. A sorted array answers search and refuses fast update. A hash table answers membership and refuses order. The wrong choice is the structure whose guarantee is not the operation you perform.

---

## Laboratory

The traces you have already read are the guided traces. Do them again with the drawings covered: the right rotation of Section 2.1, the LL tree of Section 3.4, the LR tree of Section 3.5, the deletion of Section 5.2, the red–black sequence of Section 7.4, the 2–3–4 insertions of Section 8.3, and the B-tree split of Section 8.5. Then do the following problems before you read the program. The program checks the lecture's traces. It does not print answers to these problems.

1. Insert $9, 8, 7, 6$ into an empty AVL tree. After each insertion, write every balance factor. Name each rotation.
2. Compute $N(7)$ from the recurrence. Using $h \le \log_\varphi(n + 1) - 1$ and $\log_\varphi(51) \approx 8.171$, decide whether an AVL tree of $50$ nodes can have height $10$.
3. Insert $9$ into the final 2–3–4 tree of Section 8.3. Draw the tree, including the split of the root.
4. Insert $5$ into the final B-tree of Section 8.5. Say whether any node splits, and write the node that receives $5$.
5. On the LL tree after the rotation in Section 3.4, compute `select(5)` by writing $i = \mathrm{size}(\mathrm{left}) + 1$ at each node you visit. Check yourself against the inorder sequence only after the descent.

The next heading contains the only program. Run it with Node.js. It must print `ALL TESTS PASSED`. Then change one expected balance factor, confirm that the program throws, and restore the line.

## LABORATORY PROGRAM

```javascript
import assert from "node:assert/strict";

function heightOf(node) {
  return node === null ? -1 : node.height;
}

function sizeOf(node) {
  return node === null ? 0 : node.size;
}

function update(node) {
  node.height = 1 + Math.max(heightOf(node.left), heightOf(node.right));
  node.size = 1 + sizeOf(node.left) + sizeOf(node.right);
}

class AVLNode {
  constructor(key) {
    this.key = key;
    this.left = null;
    this.right = null;
    this.height = 0;
    this.size = 1;
  }
}

function rotateRight(y) {
  const x = y.left;
  const middle = x.right;
  x.right = y;
  y.left = middle;
  update(y);
  update(x);
  return x;
}

function rotateLeft(x) {
  const y = x.right;
  const middle = y.left;
  y.left = x;
  x.right = middle;
  update(x);
  update(y);
  return y;
}

function snapshot(node) {
  if (node === null) {
    return null;
  }
  return {
    key: node.key,
    bf: heightOf(node.left) - heightOf(node.right),
    height: node.height,
    size: node.size,
    left: snapshot(node.left),
    right: snapshot(node.right),
  };
}

function rebalance(node, trace) {
  update(node);
  const balance = heightOf(node.left) - heightOf(node.right);
  if (balance > 1) {
    const childBalance = heightOf(node.left.left) - heightOf(node.left.right);
    const before = trace ? snapshot(node) : null;
    if (childBalance < 0) {
      node.left = rotateLeft(node.left);
      const mid = trace ? snapshot(node) : null;
      const rotated = rotateRight(node);
      if (trace) {
        trace.push({ kind: "LR", before, mid, after: snapshot(rotated) });
      }
      return rotated;
    }
    const rotated = rotateRight(node);
    if (trace) {
      trace.push({ kind: "LL", before, after: snapshot(rotated), childBf: childBalance });
    }
    return rotated;
  }
  if (balance < -1) {
    const childBalance = heightOf(node.right.left) - heightOf(node.right.right);
    const before = trace ? snapshot(node) : null;
    if (childBalance > 0) {
      node.right = rotateRight(node.right);
      const mid = trace ? snapshot(node) : null;
      const rotated = rotateLeft(node);
      if (trace) {
        trace.push({ kind: "RL", before, mid, after: snapshot(rotated) });
      }
      return rotated;
    }
    const rotated = rotateLeft(node);
    if (trace) {
      trace.push({ kind: "RR", before, after: snapshot(rotated), childBf: childBalance });
    }
    return rotated;
  }
  return node;
}

function insert(node, key, trace) {
  if (node === null) {
    return new AVLNode(key);
  }
  if (key < node.key) {
    node.left = insert(node.left, key, trace);
  } else if (key > node.key) {
    node.right = insert(node.right, key, trace);
  } else {
    return node;
  }
  return rebalance(node, trace);
}

function minimumNode(node) {
  let current = node;
  while (current.left !== null) {
    current = current.left;
  }
  return current;
}

function remove(node, key, trace) {
  if (node === null) {
    return null;
  }
  if (key < node.key) {
    node.left = remove(node.left, key, trace);
  } else if (key > node.key) {
    node.right = remove(node.right, key, trace);
  } else if (node.left === null) {
    return node.right;
  } else if (node.right === null) {
    return node.left;
  } else {
    const successor = minimumNode(node.right);
    node.key = successor.key;
    node.right = remove(node.right, successor.key, trace);
  }
  return rebalance(node, trace);
}

function inorder(node, out) {
  if (node === null) {
    return out;
  }
  inorder(node.left, out);
  out.push(node.key);
  inorder(node.right, out);
  return out;
}

function select(node, k) {
  if (node === null || k < 1 || k > sizeOf(node)) {
    throw new Error("select: rank out of range");
  }
  const index = sizeOf(node.left) + 1;
  if (k === index) {
    return node.key;
  }
  if (k < index) {
    return select(node.left, k);
  }
  return select(node.right, k - index);
}

function rank(node, key) {
  if (node === null) {
    throw new Error("rank: absent key");
  }
  if (key < node.key) {
    return rank(node.left, key);
  }
  if (key > node.key) {
    return sizeOf(node.left) + 1 + rank(node.right, key);
  }
  return sizeOf(node.left) + 1;
}

function assemble(key, left, right) {
  const node = new AVLNode(key);
  node.left = left;
  node.right = right;
  update(node);
  return node;
}

function assertValidAVL(node, lower, upper) {
  if (node === null) {
    return -1;
  }
  if (lower !== null && node.key <= lower) {
    throw new Error("search property violated below " + node.key);
  }
  if (upper !== null && node.key >= upper) {
    throw new Error("search property violated above " + node.key);
  }
  const leftHeight = assertValidAVL(node.left, lower, node.key);
  const rightHeight = assertValidAVL(node.right, node.key, upper);
  const expectedHeight = 1 + Math.max(leftHeight, rightHeight);
  const expectedSize = 1 + sizeOf(node.left) + sizeOf(node.right);
  if (node.height !== expectedHeight) {
    throw new Error("height mismatch at " + node.key);
  }
  if (node.size !== expectedSize) {
    throw new Error("size mismatch at " + node.key);
  }
  const balance = leftHeight - rightHeight;
  if (balance < -1 || balance > 1) {
    throw new Error("balance factor " + balance + " at " + node.key);
  }
  return expectedHeight;
}

function phiBound(n) {
  const phi = (1 + Math.sqrt(5)) / 2;
  return Math.log(n + 1) / Math.log(phi) - 1;
}

function assertHeightBound(node) {
  const n = sizeOf(node);
  const h = heightOf(node);
  if (n === 0) {
    return;
  }
  if (h > 2 * Math.log2(n) + 1e-9) {
    throw new Error("height exceeds 2 log n");
  }
  if (h > phiBound(n) + 1e-9) {
    throw new Error("height exceeds the golden-ratio bound");
  }
}

function assertOrderStatistics(node) {
  const keys = inorder(node, []);
  assert.equal(keys.length, sizeOf(node));
  for (let k = 1; k <= keys.length; k += 1) {
    assert.equal(select(node, k), keys[k - 1]);
    assert.equal(rank(node, keys[k - 1]), k);
  }
  assert.throws(() => select(node, 0));
  assert.throws(() => select(node, keys.length + 1));
}

function insertAll(keys) {
  let root = null;
  for (const key of keys) {
    root = insert(root, key);
  }
  return root;
}

const rotation = assemble(
  6,
  assemble(3, assemble(1, null, null), assemble(4, null, null)),
  assemble(8, null, null),
);
assert.deepEqual(inorder(rotation, []), [1, 3, 4, 6, 8]);
assert.equal(rotation.size, 5);
assert.equal(rotation.left.size, 3);
assert.equal(rotation.left.right.key, 4);
const rotatedRight = rotateRight(rotation);
assert.equal(rotatedRight.key, 3);
assert.equal(rotatedRight.right.key, 6);
assert.equal(rotatedRight.right.left.key, 4);
assert.equal(rotatedRight.size, 5);
assert.equal(rotatedRight.right.size, 3);
assert.equal(rotatedRight.left.size, 1);
assert.equal(rotatedRight.right.left.size, 1);
assert.equal(rotatedRight.right.right.size, 1);
assert.deepEqual(inorder(rotatedRight, []), [1, 3, 4, 6, 8]);
const rotatedLeft = rotateLeft(rotatedRight);
assert.equal(rotatedLeft.key, 6);
assert.equal(rotatedLeft.left.right.key, 4);
assert.deepEqual(inorder(rotatedLeft, []), [1, 3, 4, 6, 8]);
assert.equal(rotatedLeft.size, 5);

const llTrace = [];
let llRoot = null;
for (const key of [50, 30, 70, 20, 40, 10]) {
  llRoot = insert(llRoot, key, llTrace);
}
assert.equal(llTrace.length, 1);
assert.equal(llTrace[0].kind, "LL");
assert.equal(llTrace[0].childBf, 1);
assert.equal(llTrace[0].before.key, 50);
assert.equal(llTrace[0].before.bf, 2);
assert.equal(llTrace[0].before.height, 3);
assert.equal(llTrace[0].before.size, 6);
assert.equal(llTrace[0].before.left.key, 30);
assert.equal(llTrace[0].before.left.bf, 1);
assert.equal(llTrace[0].before.left.height, 2);
assert.equal(llTrace[0].before.left.size, 4);
assert.equal(llTrace[0].before.left.left.key, 20);
assert.equal(llTrace[0].before.left.left.bf, 1);
assert.equal(llTrace[0].before.left.left.left.key, 10);
assert.equal(llTrace[0].before.left.right.key, 40);
assert.equal(llTrace[0].before.right.key, 70);
assert.equal(llTrace[0].after.key, 30);
assert.equal(llTrace[0].after.bf, 0);
assert.equal(llTrace[0].after.height, 2);
assert.equal(llTrace[0].after.size, 6);
assert.equal(llTrace[0].after.left.key, 20);
assert.equal(llTrace[0].after.left.bf, 1);
assert.equal(llTrace[0].after.left.size, 2);
assert.equal(llTrace[0].after.right.key, 50);
assert.equal(llTrace[0].after.right.bf, 0);
assert.equal(llTrace[0].after.right.size, 3);
assert.equal(llTrace[0].after.right.left.key, 40);
assert.equal(llTrace[0].after.right.right.key, 70);
assert.deepEqual(inorder(llRoot, []), [10, 20, 30, 40, 50, 70]);
assert.equal(select(llRoot, 1), 10);
assert.equal(select(llRoot, 4), 40);
assert.equal(select(llRoot, 5), 50);
assert.equal(select(llRoot, 6), 70);
assert.equal(rank(llRoot, 10), 1);
assert.equal(rank(llRoot, 40), 4);
assertValidAVL(llRoot, null, null);
assertHeightBound(llRoot);

const lrTrace = [];
let lrRoot = null;
for (const key of [40, 20, 50, 10, 30, 25]) {
  lrRoot = insert(lrRoot, key, lrTrace);
}
assert.equal(lrTrace.length, 1);
assert.equal(lrTrace[0].kind, "LR");
assert.equal(lrTrace[0].before.key, 40);
assert.equal(lrTrace[0].before.bf, 2);
assert.equal(lrTrace[0].before.left.key, 20);
assert.equal(lrTrace[0].before.left.bf, -1);
assert.equal(lrTrace[0].before.left.right.key, 30);
assert.equal(lrTrace[0].before.left.right.bf, 1);
assert.equal(lrTrace[0].before.left.right.left.key, 25);
assert.equal(lrTrace[0].before.right.key, 50);
assert.equal(lrTrace[0].mid.key, 40);
assert.equal(lrTrace[0].mid.bf, 2);
assert.equal(lrTrace[0].mid.left.key, 30);
assert.equal(lrTrace[0].mid.left.bf, 2);
assert.equal(lrTrace[0].mid.left.left.key, 20);
assert.equal(lrTrace[0].mid.left.left.left.key, 10);
assert.equal(lrTrace[0].mid.left.left.right.key, 25);
assert.equal(lrTrace[0].after.key, 30);
assert.equal(lrTrace[0].after.bf, 0);
assert.equal(lrTrace[0].after.height, 2);
assert.equal(lrTrace[0].after.size, 6);
assert.equal(lrTrace[0].after.left.key, 20);
assert.equal(lrTrace[0].after.left.bf, 0);
assert.equal(lrTrace[0].after.left.size, 3);
assert.equal(lrTrace[0].after.right.key, 40);
assert.equal(lrTrace[0].after.right.bf, -1);
assert.equal(lrTrace[0].after.right.size, 2);
assert.equal(lrTrace[0].after.right.right.key, 50);
assert.deepEqual(inorder(lrRoot, []), [10, 20, 25, 30, 40, 50]);
assertValidAVL(lrRoot, null, null);

const rrTrace = [];
let rrRoot = null;
for (const key of [10, 20, 30]) {
  rrRoot = insert(rrRoot, key, rrTrace);
}
assert.equal(rrTrace.length, 1);
assert.equal(rrTrace[0].kind, "RR");
assert.equal(rrTrace[0].before.key, 10);
assert.equal(rrTrace[0].before.bf, -2);
assert.equal(rrTrace[0].childBf, -1);
assert.equal(rrRoot.key, 20);
assert.equal(rrRoot.left.key, 10);
assert.equal(rrRoot.right.key, 30);
assert.equal(heightOf(rrRoot.left) - heightOf(rrRoot.right), 0);
assertValidAVL(rrRoot, null, null);

const rlTrace = [];
let rlRoot = null;
for (const key of [40, 60, 30, 70, 50, 55]) {
  rlRoot = insert(rlRoot, key, rlTrace);
}
assert.equal(rlTrace.length, 1);
assert.equal(rlTrace[0].kind, "RL");
assert.equal(rlTrace[0].before.key, 40);
assert.equal(rlTrace[0].before.bf, -2);
assert.equal(rlRoot.key, 50);
assert.deepEqual(inorder(rlRoot, []), [30, 40, 50, 55, 60, 70]);
assertValidAVL(rlRoot, null, null);
assertOrderStatistics(rlRoot);

let deleteRoot = null;
for (const key of [30, 20, 40, 10, 25]) {
  deleteRoot = insert(deleteRoot, key);
}
assert.equal(deleteRoot.key, 30);
assert.equal(heightOf(deleteRoot.left) - heightOf(deleteRoot.right), 1);
assert.equal(deleteRoot.size, 5);
const deleteTrace = [];
deleteRoot = remove(deleteRoot, 40, deleteTrace);
assert.equal(deleteTrace.length, 1);
assert.equal(deleteTrace[0].kind, "LL");
assert.equal(deleteTrace[0].childBf, 0);
assert.equal(deleteRoot.key, 20);
assert.equal(heightOf(deleteRoot.left) - heightOf(deleteRoot.right), -1);
assert.equal(deleteRoot.height, 2);
assert.equal(deleteRoot.size, 4);
assert.equal(deleteRoot.left.key, 10);
assert.equal(deleteRoot.right.key, 30);
assert.equal(deleteRoot.right.left.key, 25);
assert.equal(heightOf(deleteRoot.right.left) - heightOf(deleteRoot.right.right), 1);
assert.equal(deleteRoot.right.size, 2);
assert.deepEqual(inorder(deleteRoot, []), [10, 20, 25, 30]);
assertValidAVL(deleteRoot, null, null);
assert.equal(remove(deleteRoot, 99).key, 20);

let sorted = null;
for (let key = 1; key <= 31; key += 1) {
  sorted = insert(sorted, key);
}
assert.equal(sorted.height, 4);
assert.equal(sorted.size, 31);
assertValidAVL(sorted, null, null);
assertHeightBound(sorted);
assertOrderStatistics(sorted);
const duplicate = insert(sorted, 15);
assert.equal(duplicate, sorted);
assert.equal(sorted.size, 31);

function permutation(n, seed) {
  const keys = [];
  for (let i = 1; i <= n; i += 1) {
    keys.push(i);
  }
  let state = seed;
  for (let i = n - 1; i > 0; i -= 1) {
    state = (1664525 * state + 1013904223) % 4294967296;
    const j = state % (i + 1);
    const tmp = keys[i];
    keys[i] = keys[j];
    keys[j] = tmp;
  }
  return keys;
}

let stress = null;
const buildOrder = permutation(64, 1);
const present = [];
for (const key of buildOrder) {
  stress = insert(stress, key);
  present.push(key);
  present.sort((a, b) => a - b);
  assert.deepEqual(inorder(stress, []), present);
  assertValidAVL(stress, null, null);
  assertHeightBound(stress);
}
assertOrderStatistics(stress);
const deleteOrder = permutation(64, 2);
for (const key of deleteOrder) {
  stress = remove(stress, key);
  const index = present.indexOf(key);
  present.splice(index, 1);
  assert.deepEqual(inorder(stress, []), present);
  if (stress !== null) {
    assertValidAVL(stress, null, null);
    assertHeightBound(stress);
    assertOrderStatistics(stress);
  }
}
assert.equal(stress, null);

function minimumNodes(h) {
  if (h === -1) {
    return 0;
  }
  if (h === 0) {
    return 1;
  }
  return 1 + minimumNodes(h - 1) + minimumNodes(h - 2);
}

function fibonacci(m) {
  if (m === 0) {
    return 0;
  }
  let previous = 0;
  let current = 1;
  for (let i = 2; i <= m; i += 1) {
    const next = previous + current;
    previous = current;
    current = next;
  }
  return current;
}

for (let h = 0; h <= 8; h += 1) {
  assert.equal(minimumNodes(h), fibonacci(h + 3) - 1);
}
assert.deepEqual(
  [0, 1, 2, 3, 4, 5, 6].map((h) => minimumNodes(h === 0 ? 0 : h)),
  [1, 2, 4, 7, 12, 20, 33],
);
const golden = (1 + Math.sqrt(5)) / 2;
for (let m = 2; m <= 20; m += 1) {
  assert.ok(fibonacci(m) + 1e-9 >= golden ** (m - 2));
}

const RED = "red";
const BLACK = "black";

class RBNode {
  constructor(key) {
    this.key = key;
    this.color = RED;
    this.left = null;
    this.right = null;
    this.parent = null;
  }
}

function leftRotateRB(tree, x) {
  const y = x.right;
  x.right = y.left;
  if (y.left !== null) {
    y.left.parent = x;
  }
  y.parent = x.parent;
  if (x.parent === null) {
    tree.root = y;
  } else if (x === x.parent.left) {
    x.parent.left = y;
  } else {
    x.parent.right = y;
  }
  y.left = x;
  x.parent = y;
}

function rightRotateRB(tree, y) {
  const x = y.left;
  y.left = x.right;
  if (x.right !== null) {
    x.right.parent = y;
  }
  x.parent = y.parent;
  if (y.parent === null) {
    tree.root = x;
  } else if (y === y.parent.left) {
    y.parent.left = x;
  } else {
    y.parent.right = x;
  }
  x.right = y;
  y.parent = x;
}

function rbInsertFixup(tree, z) {
  while (z.parent !== null && z.parent.color === RED) {
    if (z.parent === z.parent.parent.left) {
      const uncle = z.parent.parent.right;
      if (uncle !== null && uncle.color === RED) {
        z.parent.color = BLACK;
        uncle.color = BLACK;
        z.parent.parent.color = RED;
        z = z.parent.parent;
      } else {
        if (z === z.parent.right) {
          z = z.parent;
          leftRotateRB(tree, z);
        }
        z.parent.color = BLACK;
        z.parent.parent.color = RED;
        rightRotateRB(tree, z.parent.parent);
      }
    } else {
      const uncle = z.parent.parent.left;
      if (uncle !== null && uncle.color === RED) {
        z.parent.color = BLACK;
        uncle.color = BLACK;
        z.parent.parent.color = RED;
        z = z.parent.parent;
      } else {
        if (z === z.parent.left) {
          z = z.parent;
          rightRotateRB(tree, z);
        }
        z.parent.color = BLACK;
        z.parent.parent.color = RED;
        leftRotateRB(tree, z.parent.parent);
      }
    }
  }
  tree.root.color = BLACK;
}

function rbInsert(tree, key) {
  const z = new RBNode(key);
  let parent = null;
  let current = tree.root;
  while (current !== null) {
    parent = current;
    if (key < current.key) {
      current = current.left;
    } else if (key > current.key) {
      current = current.right;
    } else {
      return;
    }
  }
  z.parent = parent;
  if (parent === null) {
    tree.root = z;
  } else if (key < parent.key) {
    parent.left = z;
  } else {
    parent.right = z;
  }
  rbInsertFixup(tree, z);
}

function rbShape(node) {
  if (node === null) {
    return ".";
  }
  const color = node.color === BLACK ? "b" : "r";
  return node.key + color + "(" + rbShape(node.left) + "," + rbShape(node.right) + ")";
}

function blackHeight(node) {
  if (node === null) {
    return 0;
  }
  const left = blackHeight(node.left);
  const right = blackHeight(node.right);
  const fromLeft = left + (node.left === null || node.left.color === BLACK ? 1 : 0);
  const fromRight = right + (node.right === null || node.right.color === BLACK ? 1 : 0);
  if (fromLeft !== fromRight) {
    throw new Error("black-height mismatch at " + node.key);
  }
  return fromLeft;
}

function assertRedBlack(tree) {
  if (tree.root === null) {
    return;
  }
  if (tree.root.color !== BLACK) {
    throw new Error("root is not black");
  }
  if (tree.root.parent !== null) {
    throw new Error("root parent is not null");
  }
  const keys = [];
  function walk(node, lower, upper) {
    if (node === null) {
      return;
    }
    if (node.color !== RED && node.color !== BLACK) {
      throw new Error("missing color");
    }
    if (lower !== null && node.key <= lower) {
      throw new Error("red-black search property");
    }
    if (upper !== null && node.key >= upper) {
      throw new Error("red-black search property");
    }
    if (node.left !== null && node.left.parent !== node) {
      throw new Error("left parent pointer");
    }
    if (node.right !== null && node.right.parent !== node) {
      throw new Error("right parent pointer");
    }
    if (node.color === RED) {
      if (node.left !== null && node.left.color === RED) {
        throw new Error("red node with red left child");
      }
      if (node.right !== null && node.right.color === RED) {
        throw new Error("red node with red right child");
      }
    }
    keys.push(node.key);
    walk(node.left, lower, node.key);
    walk(node.right, node.key, upper);
  }
  walk(tree.root, null, null);
  blackHeight(tree.root);
  keys.sort((a, b) => a - b);
  assert.deepEqual(inorder(tree.root, []), keys);
}

const line = { root: null };
for (const key of [1, 2, 3]) {
  rbInsert(line, key);
}
assert.equal(rbShape(line.root), "2b(1r(.,.),3r(.,.))");
assert.equal(blackHeight(line.root), 1);
assertRedBlack(line);

const traced = { root: null };
for (const key of [11, 2, 14, 1, 7, 15, 5, 8]) {
  rbInsert(traced, key);
}
assert.equal(
  rbShape(traced.root),
  "11b(2r(1b(.,.),7b(5r(.,.),8r(.,.))),14b(.,15r(.,.)))",
);
rbInsert(traced, 4);
assert.equal(
  rbShape(traced.root),
  "7b(2r(1b(.,.),5b(4r(.,.),.)),11r(8b(.,.),14b(.,15r(.,.))))",
);
assert.equal(blackHeight(traced.root), 2);
assert.deepEqual(inorder(traced.root, []), [1, 2, 4, 5, 7, 8, 11, 14, 15]);
assertRedBlack(traced);
const beforeDuplicate = rbShape(traced.root);
rbInsert(traced, 7);
assert.equal(rbShape(traced.root), beforeDuplicate);

for (const seed of [1, 2, 3]) {
  const tree = { root: null };
  for (const key of permutation(40, seed)) {
    rbInsert(tree, key);
    assertRedBlack(tree);
  }
  for (let key = 1; key <= 40; key += 1) {
    rbInsert(tree, key);
  }
  assertRedBlack(tree);
  assert.equal(inorder(tree.root, []).length, 40);
}

class BNode {
  constructor(keys, children) {
    this.keys = keys;
    this.children = children;
  }
}

function splitChild(tree, parent, index) {
  const degree = tree.t;
  const full = parent.children[index];
  if (full.keys.length !== 2 * degree - 1) {
    throw new Error("split of a node that is not full");
  }
  const rightChildren = full.children.length === 0 ? [] : full.children.slice(degree);
  const right = new BNode(full.keys.slice(degree), rightChildren);
  const median = full.keys[degree - 1];
  full.keys = full.keys.slice(0, degree - 1);
  if (full.children.length !== 0) {
    full.children = full.children.slice(0, degree);
  }
  parent.keys.splice(index, 0, median);
  parent.children.splice(index + 1, 0, right);
}

function insertNonFull(tree, node, key) {
  let index = 0;
  while (index < node.keys.length && key > node.keys[index]) {
    index += 1;
  }
  if (index < node.keys.length && node.keys[index] === key) {
    return;
  }
  if (node.children.length === 0) {
    node.keys.splice(index, 0, key);
    return;
  }
  if (node.children[index].keys.length === 2 * tree.t - 1) {
    splitChild(tree, node, index);
    if (key === node.keys[index]) {
      return;
    }
    if (key > node.keys[index]) {
      index += 1;
    }
  }
  insertNonFull(tree, node.children[index], key);
}

function bInsert(tree, key) {
  if (tree.root === null) {
    tree.root = new BNode([key], []);
    return;
  }
  if (tree.root.keys.length === 2 * tree.t - 1) {
    const grown = new BNode([], [tree.root]);
    tree.root = grown;
    splitChild(tree, grown, 0);
  }
  insertNonFull(tree, tree.root, key);
}

function bSearch(node, key) {
  if (node === null) {
    return false;
  }
  let index = 0;
  while (index < node.keys.length && key > node.keys[index]) {
    index += 1;
  }
  if (index < node.keys.length && node.keys[index] === key) {
    return true;
  }
  if (node.children.length === 0) {
    return false;
  }
  return bSearch(node.children[index], key);
}

function bInorder(node, out) {
  if (node.children.length === 0) {
    out.push(...node.keys);
    return out;
  }
  for (let i = 0; i < node.keys.length; i += 1) {
    bInorder(node.children[i], out);
    out.push(node.keys[i]);
  }
  bInorder(node.children[node.keys.length], out);
  return out;
}

function bHeight(node) {
  if (node.children.length === 0) {
    return 0;
  }
  return 1 + bHeight(node.children[0]);
}

function dumpB(node) {
  return { keys: node.keys.slice(), children: node.children.map(dumpB) };
}

function assertBTree(tree, expectedCount) {
  const degree = tree.t;
  const maximum = 2 * degree - 1;
  const minimum = degree - 1;
  let count = 0;
  let leafDepth = null;
  function walk(node, isRoot, depth, lower, upper) {
    if (node.keys.length < 1 || node.keys.length > maximum) {
      throw new Error("key count out of range");
    }
    if (!isRoot && node.keys.length < minimum) {
      throw new Error("non-root below the minimum occupancy");
    }
    for (let i = 1; i < node.keys.length; i += 1) {
      if (node.keys[i] <= node.keys[i - 1]) {
        throw new Error("keys inside a node are not sorted");
      }
    }
    for (const key of node.keys) {
      if (lower !== null && key <= lower) {
        throw new Error("B-tree search property");
      }
      if (upper !== null && key >= upper) {
        throw new Error("B-tree search property");
      }
    }
    count += node.keys.length;
    if (node.children.length === 0) {
      if (leafDepth === null) {
        leafDepth = depth;
      } else if (leafDepth !== depth) {
        throw new Error("leaves are not at the same depth");
      }
      return;
    }
    if (node.children.length !== node.keys.length + 1) {
      throw new Error("a node does not have one more child than keys");
    }
    for (let i = 0; i < node.children.length; i += 1) {
      const childLower = i === 0 ? lower : node.keys[i - 1];
      const childUpper = i === node.keys.length ? upper : node.keys[i];
      walk(node.children[i], false, depth + 1, childLower, childUpper);
    }
  }
  walk(tree.root, true, 0, null, null);
  assert.equal(count, expectedCount);
  const height = bHeight(tree.root);
  const limit = Math.log((count + 1) / 2) / Math.log(degree);
  if (height > limit + 1e-9) {
    throw new Error("B-tree height exceeds log_t((n+1)/2)");
  }
}

const twoThreeFour = { t: 2, root: null };
const twoThreeFourShapes = [];
for (let key = 1; key <= 8; key += 1) {
  bInsert(twoThreeFour, key);
  twoThreeFourShapes.push(JSON.stringify(dumpB(twoThreeFour.root)));
  assertBTree(twoThreeFour, key);
  assert.equal(bSearch(twoThreeFour.root, key), true);
}
assert.deepEqual(twoThreeFourShapes, [
  '{"keys":[1],"children":[]}',
  '{"keys":[1,2],"children":[]}',
  '{"keys":[1,2,3],"children":[]}',
  '{"keys":[2],"children":[{"keys":[1],"children":[]},{"keys":[3,4],"children":[]}]}',
  '{"keys":[2],"children":[{"keys":[1],"children":[]},{"keys":[3,4,5],"children":[]}]}',
  '{"keys":[2,4],"children":[{"keys":[1],"children":[]},{"keys":[3],"children":[]},{"keys":[5,6],"children":[]}]}',
  '{"keys":[2,4],"children":[{"keys":[1],"children":[]},{"keys":[3],"children":[]},{"keys":[5,6,7],"children":[]}]}',
  '{"keys":[2,4,6],"children":[{"keys":[1],"children":[]},{"keys":[3],"children":[]},{"keys":[5],"children":[]},{"keys":[7,8],"children":[]}]}',
]);
assert.deepEqual(bInorder(twoThreeFour.root, []), [1, 2, 3, 4, 5, 6, 7, 8]);
assert.equal(bHeight(twoThreeFour.root), 1);
bInsert(twoThreeFour, 4);
assert.equal(bInorder(twoThreeFour.root, []).length, 8);

const bee = { t: 3, root: null };
const beeShapes = [];
for (const key of [10, 20, 30, 40, 50, 60, 25, 35, 70, 80]) {
  bInsert(bee, key);
  beeShapes.push(JSON.stringify(dumpB(bee.root)));
  assertBTree(bee, beeShapes.length);
}
assert.deepEqual(beeShapes[4], '{"keys":[10,20,30,40,50],"children":[]}');
assert.deepEqual(
  beeShapes[5],
  '{"keys":[30],"children":[{"keys":[10,20],"children":[]},{"keys":[40,50,60],"children":[]}]}',
);
assert.deepEqual(
  beeShapes[9],
  '{"keys":[30,50],"children":[{"keys":[10,20,25],"children":[]},{"keys":[35,40],"children":[]},{"keys":[60,70,80],"children":[]}]}',
);
assert.equal(bSearch(bee.root, 70), true);
assert.equal(bSearch(bee.root, 15), false);
assert.equal(bHeight(bee.root), 1);
assert.deepEqual(bInorder(bee.root, []), [10, 20, 25, 30, 35, 40, 50, 60, 70, 80]);

console.log("ALL TESTS PASSED");
```

---

## Common mistakes

1. **Wrong idea:** The balance factor is the right height minus the left height, because that is the sign in Knuth's figures. **Correction:** In this course the balance factor is $\mathrm{height}(\mathrm{left}) - \mathrm{height}(\mathrm{right})$. A positive factor means the left subtree is taller. Knuth's Section 6.2.3 uses the opposite sign. Copying a sign from that section without flipping it names the wrong rotation.

2. **Wrong idea:** A rotation moves only the two nodes, and the subtrees stay where they were drawn. **Correction:** The middle subtree changes parent. In a right rotation it moves from the right of $x$ to the left of $y$. Forgetting it either drops those keys or leaves them on the wrong side of the search property.

3. **Wrong idea:** A leaf has balance factor $0 - 0$, and a null child has height $0$. **Correction:** A null child has height $-1$. A leaf has height $0$ and balance factor $(-1) - (-1) = 0$. Using height $0$ for null makes every leaf look unbalanced.

4. **Wrong idea:** After a rotation, update the higher node's size first. **Correction:** The higher node's size is computed from the lower node's size. Update the node that moved down, then the node that moved up. The other order stores a stale size, and select returns the wrong key even though the inorder sequence is correct.

5. **Wrong idea:** An AVL insertion may rotate at every ancestor, and the walk can stop at the first rotation because nothing above it changes. **Correction:** Insertion repairs only the lowest imbalance, because that repair restores the subtree's old height, so ancestors do not become unbalanced. The walk still continues to the root, because every ancestor's size increased by one. Deletion is the operation that may rotate more than once, because a deletion can reduce a subtree's height.

6. **Wrong idea:** The heavy child in an LL repair always has balance factor $+1$, so a child with balance factor $0$ needs a double rotation. **Correction:** On insertion the heavy child has balance factor $+1$ or $-1$. On deletion it may be $0$. Balance factor $0$ on the heavy child is still a single rotation. The worked deletion of $40$ is that case, and the resulting root has balance factor $-1$, not $0$.

7. **Wrong idea:** A new red–black node should be black so that it does not violate the red-parent rule. **Correction:** A new node is red. Painting it black would change the black-height on one path only. The red-red violation is what the fixup loop is built to remove. The root is painted black at the end, not at allocation, except that a red root is corrected by that same final line.

8. **Wrong idea:** Black-height includes the node itself and ignores nil, and it is the same number as the course height. **Correction:** Black-height excludes the node and includes the black nil leaves. The CLRS height counts edges down to nil. The course height stops at the last internal node and is one less than the CLRS height on a nonempty tree. Mixing them makes the bound $2 \log(n + 1)$ apply to the wrong quantity.

9. **Wrong idea:** A 4-node must be split as soon as it becomes full, and the CLRS insertion loop is that split written in colors. **Correction:** A 2–3–4 insertion splits a 4-node when a later walk passes through it. The root of the trace in Section 8.3 is allowed to be a 4-node at the end. The CLRS loop of Section 7 is a bottom-up repair. The red–black shape of a 4-node is a correspondence between trees, not a claim that the two procedures execute the same steps.

10. **Wrong idea:** `select(k)` may walk the inorder sequence and count to $k$, and a size field is only a cache of $n$ at the root. **Correction:** Select uses $i = \mathrm{size}(\mathrm{left}) + 1$ at the current node and throws away one subtree. That is correct only while every node, including both nodes of every rotation, stores the size of its own subtree.

---

## Examination

Close the lecture. Two hours. Write full solutions. The answer key is the next section. Do not read it first.

### A. Definitions

1. Define an AVL tree. Include the balance factor, the height of the empty tree, and the height of a leaf.
2. State the five red–black properties and the definition of black-height.
3. Define a B-tree of minimum degree $t$. State how many keys the root may hold and how many keys every other node may hold.
4. Define subtree size, `select(k)`, and `rank(key)` as this lecture uses them. State the range of $k$ and what happens if the key is absent.

### B. Short answers

5. A right rotation is performed at $y$, whose left child is $x$. The middle subtree is $B$, the right subtree of $x$. State the inequality that places every key of $B$ relative to $x$ and relative to $y$, and say why each half of that inequality is true before the rotation.
6. For each of LL, RR, LR, and RL, state whether the repair is one rotation or two, which node is rotated, and which rotation comes first when there are two. Use this lecture's sign convention for the balance factor.
7. Why does an AVL insertion structurally repair only the lowest unbalanced node, while an AVL deletion may rotate at more than one node? Why does the insertion walk still return all the way to the root when sizes are stored?
8. Why is a nil child black? What property fails if a red node has a red child, and which part of the height proof uses that property?
9. Under the standard correspondence, what red–black shape is a 4-node? Why does splitting 4-nodes on the way down, rather than on the way up, guarantee that the parent has room for the middle key?

### C. Quantitative problems

10. Complete the left rotation. The tree below is a binary search tree. Left-rotate the node $12$. Draw the resulting tree, including every key that is shown. State where the subtree rooted at $15$ sits after the rotation, and write the key inequalities that justify that place. The subtree rooted at $15$ is the middle subtree.

```text
          12
         /  \
        8    20
            /  \
          15    25
         /  \
       13    18
```

11. AVL insertion. The tree below is the AVL tree produced by inserting $20$, then $10$, then $30$, then $5$. The balance factors are already correct. Insert $3$. Draw the tree at the moment the lowest balance factor leaves $\{-1, 0, 1\}$, before that node is rotated. Name the shape. Draw the tree after the repair, with every balance factor. State whether node $20$ is rotated, and what its balance factor is after the insertion returns.

```text
              20 (bf +1, height 2)
             /  \
           10    30 (bf 0, height 0)
           bf +1, height 1
          /
         5 (bf 0, height 0)
```

12. Black-height. The tree below has six internal nodes. Nil children are black and are not drawn.

```text
              10 B
             /    \
           5 R     15 B
          / \        \
        2 B   7 B     20 R
```

(a) Compute the black-height of the root by listing the black nodes, excluding the root and including nil, on the path through $2$ and on the path through $20$.

(b) Prove that any node of black-height $\mathrm{bh}$ is the root of a subtree with at least $2^{\mathrm{bh}} - 1$ internal nodes, and conclude that a red–black tree on $n$ internal nodes has CLRS height at most $2 \log(n + 1)$.

(c) For this tree, $n = 6$ and $\log 7 \approx 2.807$. Evaluate the bound $2 \log(n + 1)$. State the CLRS height and the course height of this tree.

13. B-tree split. The minimum degree is $t = 3$. The tree is a single full root

```text
[10, 20, 30, 40, 50]
```

Insert $25$. Draw every node of the resulting tree. Name the median that moved up. The resulting tree has $n = 6$ keys. Using $\ln 3.5 \approx 1.253$ and $\ln 3 \approx 1.099$, evaluate $\log_3((n + 1) / 2)$ and state the height of the tree you drew.

14. Select and rank. The numbers under the nodes are subtree sizes. Compute `select(2)` and `select(5)` by writing $i = \mathrm{size}(\mathrm{left}) + 1$ at every node the search visits. Compute `rank(15)` and `rank(35)` the same way. You may check the answers against the inorder sequence after the descents, not instead of them.

```text
                 20
               size 6
             /        \
          10            30
        size 3        size 2
        /    \            \
      4      15           35
    size 1  size 1      size 1
```

15. Minimum nodes. Compute $N(0), N(1), N(2), N(3), N(4)$ from $N(h) = 1 + N(h - 1) + N(h - 2)$, with $N(0) = 1$ and $N(-1) = 0$. An AVL tree has $n = 12$ nodes. What is the largest course height the balance invariant allows? You may use $\log 12 \approx 3.585$ and $\log_\varphi 13 \approx 5.330$. Show the arithmetic that turns these into the bounds $2 \log n$ and $\log_\varphi(n + 1) - 1$, and compare both with the largest allowed height.

---

## Answer key

### 1

An AVL tree is a binary search tree in which every node $u$ satisfies

$$
\mathrm{balance}(u) = \mathrm{height}(u.\mathrm{left}) - \mathrm{height}(u.\mathrm{right}) \in \{-1, 0, 1\}.
$$

The empty tree has height $-1$. A leaf has height $0$. A null child contributes height $-1$ to its parent, so a leaf has balance factor $(-1) - (-1) = 0$.

### 2

1. Every node is red or black.
2. The root is black.
3. Every leaf is black. The leaves are the nil children.
4. A red node has black children.
5. Every simple path from a given node down to a leaf contains the same number of black nodes.

The black-height of a node $u$ is the number of black nodes on any simple path from $u$ down to a leaf, not including $u$. The black-height of nil is $0$.

### 3

A B-tree of minimum degree $t \ge 2$ is a search tree in which every node holds at most $2t - 1$ keys, every node other than the root holds at least $t - 1$ keys, the root of a nonempty tree holds at least one key and at most $2t - 1$ keys, an internal node with $k$ keys has $k + 1$ children, the keys in a node are sorted, the subtrees between those keys obey the search property, and all leaves are at the same depth.

### 4

The subtree size of a node is the number of nodes in its subtree, including itself: $\mathrm{size}(u) = 1 + \mathrm{size}(u.\mathrm{left}) + \mathrm{size}(u.\mathrm{right})$, and the size of null is $0$. `select(k)` returns the $k$-th smallest key, for $k$ from $1$ through $n$. A call with $k$ outside that range fails. `rank(key)` returns the 1-based inorder position of a key that is present, which is one plus the number of keys strictly smaller than it. An absent key is a failed search. The function does not return an insertion index for a missing key.

### 5

Every key of $B$ is greater than $x$ and less than $y$. The first half holds because $B$ is the right subtree of $x$ before the rotation. The second half holds because $B$ lies in the left subtree of $y$ before the rotation, so every one of its keys is less than $y$. Together with the symmetric facts for the other subtrees, this is why $B$ can become the left subtree of $y$ and why the subtree rooted at $y$ can become the right subtree of $x$.

### 6

LL: the node has balance factor $+2$ and its left child has balance factor $+1$ on insertion. One right rotation, at the unbalanced node.

RR: the node has balance factor $-2$ and its right child has balance factor $-1$ on insertion. One left rotation, at the unbalanced node.

LR: the node has balance factor $+2$ and its left child has balance factor $-1$. Two rotations. First left-rotate the left child. Then right-rotate the unbalanced node.

RL: the node has balance factor $-2$ and its right child has balance factor $+1$. Two rotations. First right-rotate the right child. Then left-rotate the unbalanced node.

On deletion the heavy child may have balance factor $0$. That is still the single-rotation case, LL or RR.

### 7

An insertion increases some subtree height by at most one. The lowest node whose balance factor reaches $\pm 2$ was leaning toward the insertion, and the repair of Section 3 returns that subtree to the height it had before the insertion. Ancestors therefore see the same child height as before, and their balance factors do not change. A deletion can decrease a subtree's height. After a rotation the parent may then reach balance factor $\pm 2$, so the walk must rebalance every node up to the root. Sizes change on the entire path even when the height does not: the inserted key belongs to every ancestor's subtree. The size update is why the insertion returns to the root after the single structural repair.

### 8

A nil child is a leaf in the red–black definition, and property 3 says every leaf is black. If nil were red, property 4 would be awkward to state and the black-height would not count a black node at the end of every path. A red node with a red child violates property 4. The height proof uses that property to show that, on a path from just below the root down to a nil leaf, the red nodes are no more numerous than the black nodes, so the CLRS height is at most twice the black-height.

### 9

A 4-node holding $A < B < C$ corresponds to a black node holding $B$ with a red left child holding $A$ and a red right child holding $C$. Splitting on the way down means a 4-node parent is split before the walk descends into a child. When a lower 4-node later sends its middle key upward, the parent has already been reduced to a 2-node or a 3-node and has a free key slot. The root has no parent. If the root is a 4-node it splits into a new root, and the tree grows at the top.

### 10

Left-rotating $12$ uses $20$ as the right child. The middle subtree is the subtree rooted at $15$. It moves from the left of $20$ to the right of $12$.

```text
            20
           /  \
         12    25
        /  \
       8    15
           /  \
         13    18
```

Every key in the subtree of $15$ is $13, 15, 18$. Before the rotation that subtree was the left subtree of $20$, so every one of those keys is less than $20$, and it was inside the right subtree of $12$, so every one of those keys is greater than $12$. After the rotation the subtree sits as the right child of $12$ and remains in the left subtree of $20$, which is the unique place consistent with $12 < 13, 15, 18 < 20$. The inorder sequence $8, 12, 13, 15, 18, 20, 25$ is unchanged.

### 11

Inserting $3$ places it as the left child of $5$. Recompute upward. Node $5$ gets balance factor $+1$ and height $1$. Node $10$ has left height $1$ and right height $-1$, so its balance factor is $+2$. This is the lowest imbalance. Node $20$ has not been repaired yet and is not the node that is rotated.

```text
              20
             /  \
           10    30
           bf +2
          /
         5 (bf +1)
        /
       3 (bf 0)
```

The left child of $10$ has balance factor $+1$. The shape is LL. Right-rotate $10$. The middle subtree is empty, because $5$ had no right child.

```text
              20 (bf +1, height 2)
             /  \
           5     30 (bf 0, height 0)
           bf 0, height 1
          / \
         3   10     both balance factor 0 and height 0
```

Node $20$ is not rotated. Before the insertion its left subtree had height $1$. After the repair the subtree rooted at $5$ has height $1$. The balance factor of $20$ stays $+1$, which was its value before the insertion. The LL height restoration of Section 3 is this arithmetic with $h = -1$ in the sense that the right subtree of $10$ was empty: the repaired subtree has the same height the left subtree of $20$ had before $3$ arrived.

### 12

(a) The path through $2$ is $10, 5, 2, \mathrm{nil}$. Excluding $10$, the nodes are $5$ (red), $2$ (black), and nil (black). The black nodes are $2$ and nil. The path through $20$ is $10, 15, 20, \mathrm{nil}$. Excluding $10$, the black nodes are $15$ and nil. Both paths have two black nodes, so the black-height of the root is $2$.

(b) Proceed by induction on the course height of the subtree. If $u$ is nil, then $\mathrm{bh}(u) = 0$ and the subtree contains $0 = 2^0 - 1$ internal nodes. If $u$ is internal, each child $v$ has black-height at least $\mathrm{bh}(u) - 1$: a black child, including nil, has black-height $\mathrm{bh}(u) - 1$, and a red child has black-height $\mathrm{bh}(u)$. The inductive hypothesis gives each child subtree at least $2^{\mathrm{bh}(u) - 1} - 1$ internal nodes. The total is

$$
1 + 2\left(2^{\mathrm{bh}(u) - 1} - 1\right) = 2^{\mathrm{bh}(u)} - 1.
$$

At the root, $n \ge 2^{\mathrm{bh}} - 1$, so $\mathrm{bh} \le \log(n + 1)$. On a longest path from the root down to nil there are $h_{\mathrm{CLRS}}$ nodes strictly below the root, exactly $\mathrm{bh}$ of them black. Property 4 forbids two adjacent red nodes, and the path ends at a black nil, so each red node on that list is followed by a distinct black node. The number of red nodes is at most the number of black nodes, and therefore $\mathrm{bh} \ge h_{\mathrm{CLRS}} / 2$. Hence $h_{\mathrm{CLRS}} \le 2\,\mathrm{bh} \le 2 \log(n + 1)$.

(c) $2 \log(n + 1) = 2 \log 7 \approx 2 \times 2.807 = 5.614$. The longest root-to-nil path in the drawing has three edges, for example $10$ to $5$ to $2$ to nil, so the CLRS height is $3$, and $3 \le 5.614$. The deepest internal node has course height $0$, and the root has course height $2$, which is the CLRS height minus $1$. The lemma's minimum for black-height $2$ is $2^2 - 1 = 3$ internal nodes. This tree has $6$, which is at least $3$.

### 13

The root has $2t - 1 = 5$ keys, so it is full. The median is the key at index $t - 1 = 2$, which is $30$. Split the root. The new root is $[30]$. The left node is $[10, 20]$. The right node is $[40, 50]$. The key $25$ is less than $30$ and belongs in the left node, which has room.

```text
            [30]
           /    \
     [10, 20, 25]   [40, 50]
```

The median that moved up is $30$. The height is $1$, because the root's children are leaves.

$$
\log_3 \frac{n + 1}{2} = \log_3 \frac{7}{2} = \log_3 3.5 = \frac{\ln 3.5}{\ln 3} \approx \frac{1.253}{1.099} \approx 1.140.
$$

The height $1$ satisfies $1 \le 1.140$.

### 14

Inorder, used only as a check at the end, is $4, 10, 15, 20, 30, 35$.

`select(2)` starts at $20$. The left subtree has size $3$, so $i = 3 + 1 = 4$. Since $2 < 4$, step left to $10$ with the same rank $2$. At $10$, the left subtree has size $1$, so $i = 2$. Since $k = i$, return $10$.

`select(5)` starts at $20$, where $i = 4$. Since $5 > 4$, step right to $30$ with rank $5 - 4 = 1$. At $30$, the left subtree is empty, so $i = 0 + 1 = 1$. Since $k = i$, return $30$.

`rank(15)` starts at $20$. The key $15$ is smaller, so step left and keep the same formula. At $10$, the key $15$ is larger, so add $\mathrm{size}(\mathrm{left}) + 1 = 1 + 1 = 2$ and continue in the right subtree. At $15$, return $\mathrm{size}(\mathrm{left}) + 1 = 1$. The total is $2 + 1 = 3$.

`rank(35)` starts at $20$. The key is larger, so add $\mathrm{size}(\mathrm{left}) + 1 = 4$ and continue at $30$. At $30$ the key is larger, so add $\mathrm{size}(\mathrm{left}) + 1 = 1$ and continue at $35$. At $35$, add $\mathrm{size}(\mathrm{left}) + 1 = 1$. The total is $4 + 1 + 1 = 6$.

The check: positions are $4$ at rank $1$, $10$ at rank $2$, $15$ at rank $3$, $20$ at rank $4$, $30$ at rank $5$, and $35$ at rank $6$.

### 15

$$
\begin{align*}
N(0) &= 1, \\
N(1) &= 1 + N(0) + N(-1) = 1 + 1 + 0 = 2, \\
N(2) &= 1 + 2 + 1 = 4, \\
N(3) &= 1 + 4 + 2 = 7, \\
N(4) &= 1 + 7 + 4 = 12.
\end{align*}
$$

$N(5) = 1 + 12 + 7 = 20$, which is already greater than $12$. A tree of height $5$ needs at least $20$ nodes, so an AVL tree of $12$ nodes has height at most $4$. Height $4$ is achievable, because $N(4) = 12$ is the size of a minimum tree of that height.

$$
2 \log 12 \approx 2 \times 3.585 = 7.170, \qquad \log_\varphi(12 + 1) - 1 \approx 5.330 - 1 = 4.330.
$$

The largest allowed height is $4$, and $4 \le 4.330 \le 7.170$. Both proved upper bounds hold. The golden-ratio bound is within one of the Fibonacci tree. The factor-of-two bound is true and loose.

---

## Independent assignment

This assignment takes several hours. The artifact is a program and a one-page note.

Extend the AVL tree from the laboratory so that every node also stores the sum of the keys in its subtree, with $\mathrm{sum}(\mathrm{null}) = 0$ and

$$
\mathrm{sum}(u) = u.\mathrm{key} + \mathrm{sum}(u.\mathrm{left}) + \mathrm{sum}(u.\mathrm{right}).
$$

Maintain the sum everywhere the laboratory maintains the size, including both nodes of every rotation, lower node first. Implement `rangeSum(lo, hi)`, the sum of the keys $k$ that satisfy $lo \le k \le hi$. Keys remain distinct numbers inside the safe integer range.

Write a proof, separate from the program, that `rangeSum` returns that sum. The proof should use the search property and the sum invariant, by induction on the subtree, and it should name the keys that are thrown away when the walk steps left or right. A test that compares `rangeSum` with the sum of an inorder scan is evidence. It is not the proof.

Then count rotations. A rotation is one call to a left rotation or a right rotation, so a double rotation counts as two. Use two sequences of $n = 2000$ distinct keys.

- The sorted sequence $1, 2, \ldots, 2000$.
- A permutation built by Fisher–Yates. Start from the array $[1, 2, \ldots, 2000]$ and from the seed $s_0 = 1$. For $i$ from $1999$ down to $1$, set $s \leftarrow (1664525 s + 1013904223) \bmod 2^{32}$ and swap index $i$ with index $s \bmod (i + 1)$. The product stays below $2^{53}$, so the seed update is an exact integer in JavaScript.

For each sequence, insert the keys into an empty AVL tree and into an empty red–black tree, using the insertion procedures of this lecture. Record the number of rotations and the final height of each tree. Do not implement red–black deletion.

The note should compare the four counts with the guarantees in Section 10. In particular it should say whether the red–black insertion ever exceeded two rotations in a single insertion, what the AVL height was against $\log_\varphi(n + 1) - 1$, and why a larger rotation count for the AVL tree does not contradict the shared $\Theta(\log n)$ bound. Keep the program. Lecture 14 assumes you can still build this tree.

---

## Glossary

**Augmentation.** A field added to every node of a search tree, recomputed from the node and its children in constant time, so that the existing logarithmic walks remain logarithmic.

**AVL tree.** A binary search tree in which every balance factor lies in $\{-1, 0, 1\}$.

**Balance factor.** $\mathrm{height}(\mathrm{left}) - \mathrm{height}(\mathrm{right})$, using height $-1$ for a missing child.

**Black-height.** The number of black nodes on a path from a node down to a nil leaf, excluding the node itself. It is the same on every such path in a red–black tree.

**B-tree.** A search tree of minimum degree $t$ whose nodes hold between $t - 1$ and $2t - 1$ keys, except the root, with all leaves at the same depth.

**Course height.** The height convention of this course: the empty tree has height $-1$, a leaf has height $0$, and the height of a node is one plus the maximum height of its children.

**CLRS height.** The number of edges on the longest path from a node down to a nil leaf. On a nonempty tree it is the course height plus one.

**Double rotation.** The LR or RL repair: a rotation at the child, then a rotation at the unbalanced node.

**Fibonacci sequence.** $F_0 = 0$, $F_1 = 1$, and $F_m = F_{m-1} + F_{m-2}$ for $m \ge 2$. The minimum AVL size satisfies $N(h) = F_{h+3} - 1$.

**First imbalance.** The lowest node whose balance factor leaves $\{-1, 0, 1\}$ during an update. AVL insertion repairs this node and no higher node.

**Full node.** A B-tree node that already holds $2t - 1$ keys.

**Golden ratio.** $\varphi = (1 + \sqrt{5}) / 2$. It is the base of the proved AVL height bound $h \le \log_\varphi(n + 1) - 1$.

**Left rotation.** The constant-time rewrite that raises the right child and moves that child's left subtree onto the old node.

**Line case.** The red–black insertion case in which the uncle is black and the current node and its parent are both left children or both right children. The repair recolors and rotates the grandparent.

**LL.** The imbalance in which the inserted key, or the tall side, lies in the left subtree of the left child. One right rotation repairs an insertion of this shape.

**LR.** The imbalance in which the tall side lies in the right subtree of the left child. A left rotation at the child, then a right rotation at the node.

**Middle subtree.** The subtree that changes parent during a rotation: the right subtree of the left child in a right rotation, and the left subtree of the right child in a left rotation.

**Minimum degree.** The integer $t \ge 2$ that fixes the occupancy rules of a B-tree.

**$N(h)$.** The minimum number of nodes in an AVL tree of height $h$. It satisfies $N(h) = 1 + N(h - 1) + N(h - 2)$, with $N(0) = 1$ and $N(-1) = 0$.

**Nil sentinel.** The black leaf that represents a missing child. CLRS uses one shared object. This lecture's program uses null and treats null as that black leaf.

**Order statistic.** The $k$-th smallest key. Rank $1$ is the minimum.

**Rank.** The 1-based inorder position of a key that is present.

**Recoloring.** The red–black insertion case in which the uncle is red. The parent and the uncle become black, the grandparent becomes red, and the loop moves to the grandparent. No pointer changes.

**Red–black tree.** A binary search tree satisfying the five color properties of Section 6.1.

**Right rotation.** The constant-time rewrite that raises the left child and moves that child's right subtree onto the old node.

**RL.** The mirror of LR. A right rotation at the right child, then a left rotation at the node.

**RR.** The mirror of LL. One left rotation.

**Select.** The operation that returns the key of a given 1-based rank, using subtree sizes.

**Split.** The B-tree and 2–3–4 operation that moves the median key of a full node up into the parent and leaves two nodes of the minimum occupancy.

**Subtree size.** The number of nodes in a subtree, including its root. Null has size $0$.

**Triangle case.** The red–black insertion case in which the uncle is black and the path from the grandparent to the current node bends. One rotation straightens it into the line case.

**2-node, 3-node, 4-node.** The nodes of a 2–3–4 tree, holding one, two, or three keys, and therefore two, three, or four children when they are internal.

**2–3–4 tree.** A B-tree of minimum degree $2$: every non-root node holds one, two, or three keys, and all leaves are at the same depth.

**Uncle.** The sibling of a node's parent. A null uncle is black.

---

## Lecture summary

A binary search tree from Lecture 08 searches correctly and can still be a chain. Sorted insertions of $1, 2, \ldots, n$ produce course height $n - 1$. Balance is a second invariant whose job is to keep every search path of length $\Theta(\log n)$.

A rotation preserves the search property because the five regions of keys stay in the order $A < x < B < y < C$. The middle region $B$ is the subtree that changes parent. The inorder sequence does not change. The height does. Sizes and heights must be recomputed on the lower node before the higher node.

An AVL tree demands a balance factor in $\{-1, 0, 1\}$ at every node. LL and RR are single rotations. LR and RL are double rotations. Insertion walks back to the root, repairs the lowest imbalance, and restores that subtree's previous height, so no second repair occurs. The walk still updates sizes all the way up. Deletion uses the binary-search-tree removal and then rebalances the whole path, because the height may fall. The deletion of $40$ from the tree in Section 5.2 is a single rotation whose heavy child has balance factor $0$. The laboratory implements both operations and checks them.

The minimum size of an AVL tree of height $h$ is $N(h) = 1 + N(h - 1) + N(h - 2) = F_{h+3} - 1$. From $N(h) \ge 2^{h/2}$ one gets $h \le 2 \log n$. From $F_m \ge \varphi^{m-2}$ one gets the tighter proved bound $h \le \log_\varphi(n + 1) - 1$. Knuth's Theorem A states the related numerical form $1.4404 \log(n + 2) - 0.3277$ for the height measured out to an external node. Every binary tree has height at least $\log(n + 1) - 1$, so an AVL height is $\Theta(\log n)$. Search, insert, and delete walk a constant amount of work per level, so their worst-case costs are $\Theta(\log n)$.

A red–black tree replaces the numeric factor by five color properties. Nil leaves are black. A tree of black-height $\mathrm{bh}$ has at least $2^{\mathrm{bh}} - 1$ internal nodes, and at most half the nodes below the root on a root-to-leaf path are red, so the CLRS height is at most $2 \log(n + 1)$. Insertion colors the new node red and repairs an uncle-red violation by recoloring and moving up, or a black-uncle violation by one or two rotations that stop. The laboratory implements that insertion and checks the five properties. It does not implement deletion. CLRS Chapter 13.4 is the reference for the deletion cases.

A 2–3–4 tree splits 4-nodes on the way down so the leaf that receives the key is never full. A 4-node corresponds to a black node with two red children. The correspondence is structural. The CLRS loop is not a line-by-line simulation of those splits. A B-tree of minimum degree $t$ is the same idea with nodes of $t - 1$ to $2t - 1$ keys. The case $t = 2$ is the 2–3–4 tree. The height satisfies $h \le \log_t((n + 1) / 2)$. The laboratory inserts and searches. It does not delete.

Subtree size turns the inorder position into a local computation. Select and rank are correct because the left subtree is exactly the set of smaller keys and the size field counts that set. The field is true after a rotation only if the lower node is updated first. The AVL tree is the place those rotations already happen, and the laboratory checks the sizes.

### Five principles

1. The search property chooses the path. A balance invariant is what keeps the path short, and the height bound has to be derived from that invariant.
2. A rotation preserves inorder because the middle subtree's keys lie strictly between the two nodes. The rotation is useful because it changes height, not because it changes order.
3. AVL insertion repairs one lowest imbalance and still walks to the root to maintain subtree fields. AVL deletion may repair more than once because the height can fall.
4. Red–black insertion spends rotations sparingly and allows about twice the perfect height. A B-tree spends splits to pack a wide node, and its logarithm is in the minimum degree.
5. An augmented field is part of the invariant. If a rotation does not recompute it from the children upward, select and rank are no longer the operations you proved.

---

## References

1. G. M. Adelson-Velsky and E. M. Landis. "An algorithm for the organization of information." *Doklady Akademii Nauk SSSR* 146 (1962), 263–266. English translation in *Soviet Mathematics* 3 (1962), 1259–1263. The original AVL tree, as cited by Knuth in the section below.

2. R. Bayer and E. McCreight. "Organization and maintenance of large ordered indexes." *Acta Informatica* 1 (1972), 173–189. The B-tree paper.

3. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapter 12 for binary search trees, Chapter 13 for red–black trees and their deletion, Chapter 17 for augmenting a data structure and dynamic order statistics, and Chapter 18 for B-trees. The third edition places the augmenting chapter as Chapter 14. The material this lecture calls "Chapter 14 style" is that order-statistic augmentation. The fourth edition numbers it Chapter 17.

4. Leo J. Guibas and Robert Sedgewick. "A dichromatic framework for balanced trees." *Proceedings of the 19th Annual Symposium on Foundations of Computer Science*, 1978. The paper that introduced red–black trees.

5. Donald E. Knuth. *The Art of Computer Programming, Volume 3: Sorting and Searching*. 2nd edition. Addison-Wesley, 1998. Section 6.2.3, Theorem A, for the external-node height bound $1.4404 \log(n + 2) - 0.3277$. Knuth's balance factor is the negation of the factor used in this lecture.

6. Robert Sedgewick and Kevin Wayne. *Algorithms*. 4th edition. Addison-Wesley, 2011. Section 3.3 presents left-leaning red–black trees. That insertion is a different procedure from the CLRS loop traced here.

7. Mark Allen Weiss. *Data Structures and Algorithm Analysis in C++*. 4th edition. Pearson, 2014. Chapter 4 for AVL trees and rotations.
