# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 03 — LINKED LISTS

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 03 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 8 hours
**Prerequisites:** Lecture 01 — Models, ADTs, and Asymptotic Analysis; Lecture 02 — Arrays, Dynamic Arrays, and Amortized Analysis
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapter 10, Section 10.2; Goodrich, Tamassia, and Goldwasser, *Data Structures and Algorithms in Java*, 6th edition, Chapter 3, Sections 3.2–3.4; Knuth, *The Art of Computer Programming*, Volume 1, 3rd edition, Sections 2.2.3–2.2.5

**This lecture owns:** Singly linked lists, doubly linked lists, circular lists, and sentinel nodes, including the pointer updates and their costs.
**This lecture does not teach:** Stacks, queues, deques, and skip lists. A stack can be a list restricted to one end; that abstract data type is Lecture 04.

---

# 1. Learning objectives

After this lecture you should be able to do each of the following on paper and in a short JavaScript program.

1. Separate the cost of locating a node from the cost of splicing at a node you already hold, and state both costs for `pushFront`, `pushBack`, `popFront`, `popBack`, `insertAfter`, `deleteAfter`, `find`, and `get`.
2. Draw every `next` assignment for insertion at the head, insertion after a middle node, deletion at the head, and deletion after a middle node, on one fixed list.
3. Show why `popBack` on a singly linked list is $\Theta(n)$ in the worst case when the list stores a tail reference, and compute the exact number of `next` reads.
4. Update `prev` and `next` so that deleting a known node, `pushBack`, and `popBack` on a doubly linked list are $\Theta(1)$ in the worst case, and draw those updates.
5. Draw the empty circular list and the one-node circular list as different structures, and move a cursor once around a three-node circle by rewriting no node pointer.
6. Rewrite front insertion and known-node deletion with a sentinel head, and with a sentinel head plus a sentinel tail, so the empty-list branch is gone, and state what `size` counts.
7. Fill a cost table that compares these lists with the dynamic array of Lecture 02 on get, insertion at the front, insertion at the end, insertion at a known position, scan, extra memory, and locality, with the case of each bound named.
8. State the representation invariants and reject a picture that breaks `size`, a `prev`/`next` pair, acyclicity, or `tail.next`.
9. Reverse a singly linked list in place, give the loop invariant, and finish the trace for the lecture's running list.
10. Given a splice that overwrites `next` too early, name the nodes that become unreachable from the head.

---

# 2. Purpose of this lecture

Lecture 02 stores elements in a contiguous block. The address of the element at index $i$ is computed from the base address and $i$, so `get(i)` is $\Theta(1)$ in the RAM model of Lecture 01. Inserting at the front of that block moves every later element, so that insertion is $\Theta(n)$ in the worst case. Inserting at the end is $\Theta(1)$ amortized when the capacity grows by a constant factor greater than $1$, and $\Theta(n)$ in the worst case on the insertion that copies the block into a larger one. This lecture uses those results and does not prove them again.

A linked list stores elements in nodes that refer to one another. The reason to add that indirection is narrow: once a node reference is in hand, a constant number of reference assignments can insert or remove an element there, and the other elements stay where they are. The walk that produced the reference is a different operation, with its own bound. Keeping those two costs apart is the point of the lecture.

The same running list is used in every trace and in the laboratory:

```text
head
  |
  v
[10 | next] -> [20 | next] -> [30 | next] -> [40 | null]
                                                 ^
                                                tail
size = 4
```

Indexes are $0$-based. The element $10$ is at index $0$. $\log$ is not needed in this lecture. $\Theta$ means a tight bound, $O$ an upper bound, and $\Omega$ a lower bound. A reference assignment, a comparison, an addition to `size`, and following one link are each one RAM step. JavaScript numbers are IEEE floating-point values; every count in this lecture is an integer at most `Number.MAX_SAFE_INTEGER`, which is $2^{53}-1$. A list that this course asks you to build sits inside that limit. Absent links are `null`. The implementation language is JavaScript, using `class`, with no libraries.

A stack can be a list restricted to one end; that abstract data type is Lecture 04.

---

# 3. Why a link exists

## 3.1 The operation we want to make cheap

Consider the block from Lecture 02 holding $10, 20, 30, 40$, and suppose the caller already knows that the new element $25$ belongs between $20$ and $30$. The index of that slot may be known. The elements $30$ and $40$ still occupy the slots where $25$ and $30$ must sit, so the implementation moves them. The move examines a number of elements proportional to the length of the suffix. Knowing the index removed the search. It did not remove the movement.

A node reference is a different kind of "known position." It names the record that should stand immediately before the new element. If that record stores a link to its successor, the insertion can attach a new record to that link. The records holding $10$, $30$, and $40$ are not copied. Their addresses do not change.

That is the whole reason for a link. The link is not a faster way to reach index $i$ from the start of the list. Reaching index $i$ from the head follows $i$ links. The link is what makes the local edit cheap after the node has been found.

## 3.2 Two costs, added only when both happen

**Definition.** A *splice* is a constant-length sequence of reference assignments that attaches a node, detaches a node, or both, using node references the caller already holds.

**Definition.** A *walk* (or a search) follows `next`, and on a doubly linked list sometimes `prev`, from a named entry node until a stated node, index, or element is reached, or until the search fails.

The splice does not include the walk. The walk does not include the splice. An algorithm that must do both pays the sum.

| Caller already holds | Work left | Worst-case cost on the singly linked list of this lecture |
| --- | --- | --- |
| Nothing but the list, and an index $i$ | Walk $i$ links, then splice | $\Theta(i)$, which is $\Theta(n)$ when $i = n-1$ |
| Nothing but the list, and a value to find | Walk until the value or the end, then maybe splice | $\Theta(n)$ for the walk |
| A reference to the node after which the edit belongs | Splice only | $\Theta(1)$ |

**Theorem.** `insertAfter` on a node reference the caller already holds takes $\Theta(1)$ worst-case time on the singly linked representation of Section 5.

**Proof.** The procedure allocates one fixed-size node, writes the new node's `next`, writes the known node's `next`, updates `tail` when the known node is the tail, and adds $1$ to `size`. There is no loop and no recursive call. Each of those steps is $\Theta(1)$ in the RAM model. A constant number of $\Theta(1)$ steps is $\Theta(1)$. The length $n$ does not appear in the procedure. $\square$

**Theorem.** A search from the head for a value that is absent, or that occurs only in the last node, takes $\Theta(n)$ worst-case time.

**Proof.** The search starts at `head` and follows `next`. In the case just named it examines all $n$ nodes, which is $\Omega(n)$ link follows and element comparisons. It stops at `null` or at a match, so it examines at most $n$ nodes and is $O(n)$. Therefore the worst case is $\Theta(n)$. $\square$

The second theorem is the cost of `find`. It is not a hidden part of the first theorem. When a later paragraph says that insertion after a known node is $\Theta(1)$, the word "known" means the reference is already in a variable. When the caller has only an index or a value, add the walk.

---

# 4. The node

**Definition.** A *node* is a record that stores one list *element* and one or more links to nodes.

A singly linked node stores two fields.

| Field | Meaning |
| --- | --- |
| `element` | The value stored at this position. This lecture uses numbers. |
| `next` | The successor node, or `null` when this node has no successor. |

A doubly linked node stores a third field.

| Field | Meaning |
| --- | --- |
| `prev` | The predecessor node, or `null` when this node has no predecessor. |

`null` means the link is absent. It is not an element of the list, and it is not a node. Reading `null.element` or `null.next` is a fault. Every procedure in this lecture tests for `null` before it follows a link that might be absent, or it maintains a representation in which the link it follows is never `null`.

The element and the node are different objects. The list $10, 20, 30, 40$ contains four elements and four nodes. A later sentinel representation adds nodes that are not elements. Operations that return an element return the number. Operations that splice return or accept the node, because the caller must hold the record in order to avoid a walk.

In JavaScript the node is an object and a link is a reference to an object. Two variables can refer to the same node. Assignment copies the reference. It does not copy the successor chain. That fact is what makes a splice possible, and it is what makes an early overwrite lose a chain: the overwritten field may have been the only reference to the suffix.

A node does not store its index. The index is the number of `next` links from the first element to the node. It changes when a splice happens in front of the node. Stored indexes would have to be rewritten on that splice, which would spend the linear work the link was introduced to avoid.

---

# 5. The singly linked list

## 5.1 Representation

**Definition.** A *singly linked list*, in the representation this lecture analyzes first, is an object with three fields:

| Field | Meaning |
| --- | --- |
| `head` | The first node, or `null` when the list is empty. |
| `tail` | The last node, or `null` when the list is empty. |
| `size` | The number of nodes, which is the number of elements in this representation. |

Each node has `element` and `next`. The last node's `next` is `null`. There is no `prev`.

The empty list is `head = null`, `tail = null`, and `size = 0`. A one-node list holding $10$ has `head` and `tail` referring to that same node, and that node's `next` is `null`.

```text
empty

head = null
tail = null
size = 0

one node

head
  |
  v
[10 | null]
  ^
 tail
size = 1
```

The running four-node list is the diagram in Section 2. `head` refers to the node holding $10$. `tail` refers to the node holding $40$. Following `next` visits $10, 20, 30, 40$ and then `null`.

## 5.2 Behavior of the operations

The behavior is the abstract specification. The costs in Section 5.4 belong to this representation, not to the specification.

Let the sequence of elements be $a_0, a_1, \ldots, a_{n-1}$.

| Operation | Behavior |
| --- | --- |
| `pushFront(x)` | The sequence becomes $x, a_0, \ldots, a_{n-1}$. |
| `popFront()` | Requires $n \ge 1$. Returns $a_0$. The sequence becomes $a_1, \ldots, a_{n-1}$. |
| `pushBack(x)` | The sequence becomes $a_0, \ldots, a_{n-1}, x$. |
| `popBack()` | Requires $n \ge 1$. Returns $a_{n-1}$. The sequence becomes $a_0, \ldots, a_{n-2}$. |
| `insertAfter(node, x)` | `node` refers to a node that is currently in this list. If that node holds $a_k$, the sequence becomes $a_0, \ldots, a_k, x, a_{k+1}, \ldots, a_{n-1}$. |
| `deleteAfter(node)` | `node` refers to a node that is currently in this list and is not the tail. If that node holds $a_k$, remove $a_{k+1}$ and return it. |
| `find(x)` | Return the first node whose element is $x$, using `===`, or `null` if no such node exists. |
| `get(i)` | Requires $0 \le i < n$. Return $a_i$. |

`insertAfter` and `deleteAfter` are specified on a node, not on an index. A caller who has an index and wants those operations walks first, then splices.

`popFront` on an empty list, `popBack` on an empty list, `get` on an index outside $[0, n)$, and `deleteAfter` on the tail are errors. The laboratory throws. An error is not a $\Theta$ case; the bounds below are for calls that meet the preconditions.

## 5.3 The procedures

Pseudocode, written as the JavaScript the laboratory runs:

```text
pushFront(element):
    created = new node(element, head)
    head = created
    if tail = null:
        tail = created
    size = size + 1
    return created

popFront():
    if head = null: error empty
    removed = head
    head = removed.next
    size = size - 1
    if head = null:
        tail = null
    removed.next = null
    return removed.element

pushBack(element):
    created = new node(element, null)
    if tail = null:
        head = created
        tail = created
    else:
        tail.next = created
        tail = created
    size = size + 1
    return created

popBack():
    if head = null: error empty
    if head = tail:
        element = head.element
        head = null
        tail = null
        size = 0
        return element
    previous = head
    repeat:
        successor = previous.next
        if successor = tail: break
        previous = successor
    element = tail.element
    previous.next = null
    tail = previous
    size = size - 1
    return element

insertAfter(node, element):
    created = new node(element, node.next)
    node.next = created
    if tail = node:
        tail = created
    size = size + 1
    return created

deleteAfter(node):
    if node.next = null: error no successor
    removed = node.next
    node.next = removed.next
    if tail = removed:
        tail = node
    size = size - 1
    removed.next = null
    return removed.element

find(element):
    current = head
    while current != null:
        if current.element = element: return current
        current = current.next
    return null

get(index):
    if index is not an integer in [0, size): error
    current = head
    repeat index times:
        current = current.next
    return current.element
```

The order inside `insertAfter` is the order that keeps the suffix. `created.next` receives `node.next` while `node.next` still refers to the suffix. Only then is `node.next` overwritten. Section 14 shows the opposite order.

The order inside `deleteAfter` saves the successor in `removed` before `node.next` is swung. After the swing, `removed.next` is cleared so the detached node does not retain a reference into the list. Clearing that field is $\Theta(1)$ and is not required for the walk from `head` to be correct. It is part of leaving the detached node with no list links.

`popFront` that removes the final node sets `tail` to `null`. Leaving `tail` on the detached node would make `head = null` and `tail` non-null together, which Section 12 forbids.

## 5.4 Costs

All of these bounds are worst-case bounds in the RAM model, for calls that meet the preconditions. $n$ is `size` before the call.

| Operation | Exact link follows from the head | Bound |
| --- | --- | --- |
| `pushFront` | $0$ | $\Theta(1)$ |
| `popFront` | $0$ beyond the `head` reference already held | $\Theta(1)$ |
| `pushBack` | $0$; the new node is attached to `tail` | $\Theta(1)$ |
| `popBack`, $n = 1$ | $0$ | $\Theta(1)$ on this one input |
| `popBack`, $n \ge 2$ | $n - 1$ reads of `next` | $\Theta(n)$ |
| `insertAfter` a held node | $0$ | $\Theta(1)$ |
| `deleteAfter` a held node | $0$ | $\Theta(1)$ |
| `find` when the match is at index $i$, or when it is absent | $i + 1$ nodes examined on a hit at index $i$; $n$ nodes examined when absent | $\Theta(n)$ worst case |
| `get(i)` | $i$ follows of `next` | $\Theta(i)$, hence $\Theta(n)$ worst case |

`pushFront`, `popFront`, `pushBack`, `insertAfter`, and `deleteAfter` contain no loop whose bound depends on $n$. Each is a fixed straight-line sequence of RAM steps, so each is $\Theta(1)$. The theorems in Section 3.2 already record the argument for `insertAfter` and for a full search. `get(i)` is the same walk with the target identified by a count rather than by a value: the loop body runs $i$ times, each time $\Theta(1)$, and $i \le n - 1$.

There is no average-case claim in that table. An average successful `find` would require a distribution on the match position. This lecture does not assume one.

## 5.5 Why the tail reference does not make `popBack` constant

`pushBack` is $\Theta(1)$ because the node that must change is the node `tail` already names. The procedure writes `tail.next` and then moves `tail` forward to the new node. No earlier node changes.

`popBack` must make a different node change. After removing $40$ from the running list, the node holding $30$ must be the tail, and its `next` must be `null`. The reference stored in `tail` names the node holding $40$. The field `tail.next` is `null`. The node holding $40$ stores no reference to the node holding $30$. The only reference to the node holding $30$ that a walk can follow from a list entry point is the chain `head` → $10$ → $20$ → $30$.

**Theorem.** On this representation, for every $n \ge 2$, `popBack` reads `next` exactly $n - 1$ times before it rewrites the predecessor.

**Proof.** The procedure in Section 5.3 starts `previous` at `head`. Each iteration reads `previous.next` once. It stops when that successor is `tail`. The nodes visited as `previous` are the first $n - 1$ nodes: every node except `tail`. That is $n - 1$ reads. The read of the predecessor's `next` is included; it is the read that observes `tail` and stops the loop. The tail node's own `next` is not read. After the loop, `previous.next` is assigned `null` without a further read. $\square$

Check the formula on the running list. Here $n = 4$, so the formula says $4 - 1 = 3$ reads.

| Read | `previous` holds | `previous.next` holds | Decision |
| --- | --- | --- | --- |
| 1 | $10$ | $20$ | $20$ is not the tail; advance |
| 2 | $20$ | $30$ | $30$ is not the tail; advance |
| 3 | $30$ | $40$ | $40$ is the tail; stop |

Then `previous.next` is set to `null`, `tail` becomes the node holding $30$, and `size` becomes $3$. The sequence is $10, 20, 30$.

For $n = 1$ the procedure takes the branch `head = tail`. It does not read `next`. The worst-case bound is determined by the family of inputs with $n \ge 2$, whose cost $n - 1$ is $\Theta(n)$. The one-node input does not pull that worst case down to $\Theta(1)$.

**Theorem.** Any procedure that, given only `head`, `tail`, `size`, and nodes storing `element` and `next`, updates the predecessor of the tail, follows $\Omega(n)$ links in the worst case.

**Proof.** Let $n \ge 2$, and let $p$ be the predecessor of the tail, defined by $p.\mathrm{next} = \mathrm{tail}$. The variables `head` and `tail` refer to $p$ only in the one-node list, which is excluded by $n \ge 2$. `tail.next` is `null`, so it does not refer to $p$. The unique chain of `next` links from `head` to $p$ has $n - 2$ hops, because $p$ sits at index $n - 2$. A procedure that starts from the stored entry references and reaches $p$ by following stored links has nowhere to start except `head`: starting at `tail` provides no backward link. Reaching $p$ and reading $p.\mathrm{next}$ to confirm the predecessor is $\Omega(n)$ link operations. $\square$

A tail reference identifies the last node. It does not identify the predecessor of the last node. Adding the tail reference changed `pushBack` from a walk of length $n$ into a constant splice. It left `popBack` as a walk. The representation that stores the missing predecessor explicitly is the doubly linked list of Section 8.

---

# 6. Pointer traces on one list

Every trace in this section starts from the same list, not from the result of the previous trace.

```text
head
  |
  v
[10 | next] -> [20 | next] -> [30 | next] -> [40 | null]
                                                 ^
                                                tail
size = 4
```

Call the four nodes $u_{10}$, $u_{20}$, $u_{30}$, and $u_{40}$.

## 6.1 Insert at the head

Operation: `pushFront(5)`.

**Assignment 1.** Allocate $u_5$ with element $5$ and with `next` equal to the current `head`, which is $u_{10}$. `head` is still $u_{10}$. The walk from `head` is still $10, 20, 30, 40$.

```text
[5 | next] --+
             |
             v
head ----> [10 | next] -> [20 | next] -> [30 | next] -> [40 | null]
                                                            ^
                                                           tail
```

$u_5$ is not yet on the walk from `head`. Its `next` already names the suffix that must follow it.

**Assignment 2.** `head = u_5`. If `tail` were `null` it would become $u_5$; here `tail` is $u_{40}$ and stays there. `size` becomes $5$.

```text
head
  |
  v
[5 | next] -> [10 | next] -> [20 | next] -> [30 | next] -> [40 | null]
                                                               ^
                                                              tail
size = 5
```

The sequence is $5, 10, 20, 30, 40$. The node $u_{10}$ was not copied. Its address is unchanged. One reference, `head`, moved.

## 6.2 Insert in the middle

Operation: `insertAfter(u_{20}, 25)`.

**Assignment 1.** Allocate $u_{25}$ with element $25$ and with `next` equal to `u_{20}.next`, which is $u_{30}$. Do not write `u_{20}.next` yet.

```text
head -> [10] -> [20] -> [30] -> [40] -> null
                         ^          ^
                         |         tail
                        [25]
```

Both `u_{20}.next` and `u_{25}.next` refer to $u_{30}$. The walk from `head` is still $10, 20, 30, 40$, because nothing points at $u_{25}$ yet. The suffix $30, 40$ is reachable in two ways: from $u_{20}$, and from $u_{25}$.

**Assignment 2.** `u_{20}.next = u_{25}`. `tail` is $u_{40}$, which is not $u_{20}$, so `tail` stays. `size` becomes $5$.

```text
head -> [10] -> [20] -> [25] -> [30] -> [40] -> null
                                          ^
                                         tail
size = 5
```

The sequence is $10, 20, 25, 30, 40$. The reference that used to be the only link from $u_{20}$ to $u_{30}$ was copied into $u_{25}$ before it was overwritten. Section 14 reverses these two writes and loses $u_{30}$ and $u_{40}$.

If the known node had been the tail, assignment 2 would also execute `tail = created`. Inserting $50$ after $u_{40}$ produces $10, 20, 30, 40, 50$ with `tail` equal to the new node and that node's `next` equal to `null`.

## 6.3 Delete at the head

Operation: `popFront()`.

**Assignment 1.** `removed = head`, so `removed` is $u_{10}$.

**Assignment 2.** `head = removed.next`, so `head` is $u_{20}$. `size` becomes $3$. `head` is not `null`, so `tail` stays $u_{40}$. Then `removed.next` is set to `null`.

```text
[10 | null]          detached

head
  |
  v
[20 | next] -> [30 | next] -> [40 | null]
                                  ^
                                 tail
size = 3
```

The sequence is $20, 30, 40$. The returned element is $10$. No node after the old head was moved. Deleting the head does not need a predecessor node, because `head` itself is the reference that must change. That is a special case of the predecessor problem in Section 7: the predecessor slot of the first node is the variable `head`, which the list object stores.

If the list had held only $10$, assignment 2 would set `head` to `null` and the following test would set `tail` to `null`.

## 6.4 Delete in the middle

Operation: `deleteAfter(u_{20})`. This removes the successor of $20$, which is $30$, not $20$ itself.

**Assignment 1.** `removed = u_{20}.next`, so `removed` is $u_{30}$. The picture is still the original list. `removed.next` is $u_{40}$.

**Assignment 2.** `u_{20}.next = removed.next`, so `u_{20}.next` is $u_{40}$. `tail` is $u_{40}$, which is not `removed`, so `tail` stays. `size` becomes $3$. Then `removed.next` is set to `null`.

```text
head -> [10] -> [20] -> [40] -> null
                          ^
                         tail
size = 3

[30 | null]    detached, unreachable from head
```

The sequence is $10, 20, 40$. The returned element is $30$. The procedure followed no link from `head`. It used the predecessor the caller passed in.

If the caller had passed $u_{30}$ instead, `deleteAfter` would remove $u_{40}$, set `u_{30}.next` to `null`, and set `tail` to $u_{30}$, because `tail` was the removed node. The sequence would be $10, 20, 30$. The middle-delete trace and the delete-last-by-`deleteAfter` trace are different calls. `popBack` is the second situation when the caller does not already hold $u_{30}$.

---

# 7. The predecessor problem

**Definition.** The *predecessor* of a node $u$ is the node $p$ such that $p.\mathrm{next} = u$. The first node has no predecessor node; the variable `head` occupies that role.

**Definition.** The *predecessor problem* on a singly linked list is the need to change $p.\mathrm{next}$ when the caller holds $u$ and does not hold $p$. The node $u$ stores no reference to $p$.

`deleteAfter(p)` is easy because the caller holds $p$. The reference that must change is `p.next`, and the node to detach is `p.next`. Section 6.4 is that case.

Deleting the node $u$ when the caller holds $u$ and not $p$ is a different operation. The assignment that removes $u$ from the chain is `p.next = u.next`. Producing $p$ requires a walk from `head` until `current.next` is $u$. On the running list, deleting $u_{30}$ given only $u_{30}$ walks $u_{10}$, then $u_{20}$, and stops because $u_{20}.\mathrm{next}$ is $u_{30}$. The walk is the same shape as the walk in `popBack`, and it is $\Theta(n)$ in the worst case, when $u$ is the tail or sits a constant number of nodes before the tail.

Deleting $u_{10}$ given $u_{10}$ is the cheap special case: the predecessor slot is the variable `head`, so `head = u_{10}.next` is $\Theta(1)$. Every later node has its predecessor slot inside another node.

This is why `insertAfter` and `deleteAfter` are the primitive splices on a singly linked list, and why a method `delete(u)` on a singly linked list is not $\Theta(1)$ for an arbitrary held node. The doubly linked representation exists to store $p$ in `u.prev`, which makes `delete(u)` a constant splice for every node, including the middle and the tail.

A method that receives an index has the predecessor problem even when a `prev` field exists, until a walk converts the index into a node. The field removes the problem for a held node. It does not remove the walk from the head.

---

# 8. The doubly linked list

## 8.1 Representation without sentinels

**Definition.** A *doubly linked list* stores, in each node, an element, a `next` reference, and a `prev` reference.

The non-sentinel form in this section stores `head`, `tail`, and `size`, as the singly linked list did. For the running list the links in both directions are:

```text
null <- [10] <-> [20] <-> [30] <-> [40] -> null
         ^                          ^
        head                       tail
size = 4
```

The notation $a \leftrightarrow b$ means `a.next` is $b$ and `b.prev` is $a$. Both directions are stored. Section 12 requires them to agree.

`head.prev` is `null` and `tail.next` is `null` whenever the list is non-empty. The empty list has `head` and `tail` equal to `null`. A one-node list has `head` and `tail` equal to that node, and both of its links equal to `null`.

The operations `pushFront`, `popFront`, `insertAfter`, `find`, and `get` have the same element sequences as in Section 5.2. Two further operations become constant splices:

| Operation | Behavior |
| --- | --- |
| `deleteNode(node)` | `node` is in the list. Remove that node's element from the sequence and return it. |
| `popBack()` | Requires $n \ge 1$. Return the last element and remove it. |
| `pushBack(x)` | Append $x$. |

`get(i)` is still a walk. From the head it follows `next` exactly $i$ times. Because `prev` exists, a walk may instead start at the tail when $i$ is nearer the end, and follow `prev` exactly $n - 1 - i$ times. The shorter of the two walks has length

$$
\min(i,\ n - 1 - i) \le \lfloor (n - 1) / 2 \rfloor
$$

which is $\Theta(n)$ in the worst case. The shorter direction improves the constant factor inside the $\Theta(n)$ bound. It does not make index access $\Theta(1)$. Address arithmetic on a contiguous block is what makes `get(i)` $\Theta(1)$, and these nodes are not a contiguous block.

## 8.2 Delete a known node in constant time

**Theorem.** `deleteNode` on a node reference the caller already holds takes $\Theta(1)$ worst-case time on a doubly linked list.

**Proof.** `node.prev` and `node.next` are fields of the held node, so both neighbors are obtained in $\Theta(1)$ time without a walk from `head`. The procedure then performs a constant number of reference assignments, listed below, and adds $-1$ to `size`. There is no loop. A constant number of RAM steps is $\Theta(1)$. $\square$

On the non-sentinel representation the assignments have branches, because the missing neighbor of the first node is the variable `head` rather than a node, and the missing neighbor of the last node is the variable `tail`.

```text
deleteNode(node):
    if node.prev = null:
        head = node.next
    else:
        node.prev.next = node.next
    if node.next = null:
        tail = node.prev
    else:
        node.next.prev = node.prev
    node.prev = null
    node.next = null
    size = size - 1
    return node.element
```

The branches are $\Theta(1)$. They do not walk. They exist because the ends are represented differently from the middle. Section 10 removes the branches by making the ends look like the middle.

Trace, on the original running list, the deletion of the held node $u_{30}$. This is a middle node, so both neighbors exist.

| Step | Assignment | Values |
| --- | --- | --- |
| 1 | read `u_{30}.prev` | $u_{20}$ |
| 2 | read `u_{30}.next` | $u_{40}$ |
| 3 | `u_{20}.next = u_{40}` | the forward link skips $30$ |
| 4 | `u_{40}.prev = u_{20}` | the backward link skips $30$ |
| 5 | `u_{30}.prev = null` | detached |
| 6 | `u_{30}.next = null` | detached |

`head` remains $u_{10}$. `tail` remains $u_{40}$. `size` becomes $3$. The sequence is $10, 20, 40$.

```text
null <- [10] <-> [20] <-> [40] -> null
         ^                   ^
        head                tail
size = 3

[30] with prev = null and next = null
```

The procedure never read `head`. A counter that charges one step to each of the six link reads and writes above charges $6$ on this list and $6$ on a list of $32$ nodes. The laboratory asserts that equality. The $6$ is a property of this procedure, not of $n$. Any correct constant procedure would do; this one is the one the tests run. Finding $u_{30}$ by value is not part of the six. If the test searches first, the search counter and the delete counter are separate.

Deleting the held tail $u_{40}$ takes the `node.next = null` branch: `u_{30}.next` becomes `null`, and `tail` becomes `u_{30}`. Deleting the held head $u_{10}$ takes the `node.prev = null` branch: `head` becomes $u_{20}$, and `u_{20}.prev` becomes `null`. Same procedure. Still no walk.

## 8.3 `pushBack` and `popBack` in constant time

`pushBack(50)` from the original running list:

```text
pushBack(element):
    created = new node(element, prev = tail, next = null)
    if tail = null:
        head = created
        tail = created
    else:
        tail.next = created
        tail = created
    size = size + 1
```

| Step | Result |
| --- | --- |
| Allocate $u_{50}$ | `prev` is $u_{40}$, `next` is `null` |
| `u_{40}.next = u_{50}` | the old tail points forward at the new node |
| `tail = u_{50}` | the list names the new last node |
| `size = 5` | sequence $10, 20, 30, 40, 50$ |

```text
null <- [10] <-> [20] <-> [30] <-> [40] <-> [50] -> null
         ^                                    ^
        head                                 tail
size = 5
```

No earlier node was visited. The predecessor of the new node was already stored in `tail`.

`popBack()` from the original running list, not from the list that just received $50$:

| Step | Result |
| --- | --- |
| `removed = tail` | $u_{40}$ |
| `predecessor = u_{40}.prev` | $u_{30}$, one field read |
| `u_{30}.next = null` | the new last node ends the list |
| `tail = u_{30}` | |
| clear `u_{40}` and set `size = 3` | sequence $10, 20, 30$ |

```text
null <- [10] <-> [20] <-> [30] -> null
         ^                   ^
        head                tail
size = 3
```

The predecessor was sitting in the tail node. That is the field Section 5.5 proved was missing from the singly linked representation. With it, `popBack` is $\Theta(1)$ in the worst case, including the last-node case and the one-node case. On a one-node list, `prev` is `null`, so the procedure sets both `head` and `tail` to `null`.

The singly linked `popBack` read $n - 1$ links on this four-node list. The doubly linked `popBack` read one `prev` field. Both return $40$ and leave $10, 20, 30$. The element sequences match. The costs do not.

---

# 9. Circular lists

**Definition.** A *circular singly linked list* is a list in which the last node's `next` refers to the first node. There is one external reference, `head`. The empty list has no node.

This section uses that one-head representation. It does not add a tail field. `insertAfter` a held node is still $\Theta(1)$. Finding the last node from `head`, if a caller needs it and does not already hold it, is a walk of $n$ links that stops when `current.next` is `head`.

## 9.1 The empty list and the one-node list are different pictures

```text
empty

head = null
size = 0
no node exists
```

```text
one node, element 10

head
  |
  v
+------------------+
|                  |
+--> [10 | next] --+

head.next = head
size = 1
```

In the one-node list, `head.next` is `head`. The circle has length $1$. Following `next` once returns to the start. There is no `null` on this circle.

A list that sets the only node's `next` to `null` is the non-circular one-node list of Section 5.1. It is not this structure. A walk that stops at `null` will stop. A walk that stops on returning to `head` will follow `null` and fault. Section 14 draws that mistake.

Creating the first node is the operation that establishes the circle:

```text
addFirst(element):
    created = new node(element, null)
    created.next = created
    head = created
    size = 1
    return created
```

The self-reference is written before, or at least by the time, `head` is published. `insertAfter` is defined once a node exists:

```text
insertAfter(node, element):
    created = new node(element, node.next)
    node.next = created
    size = size + 1
    return created
```

The two assignments are the same pair as in Section 6.2. On a circle, `node.next` is never `null` when the representation invariant holds, so the new node's `next` receives a real node. Inserting $20$ after the only node $10$ yields:

```text
head -> [10 | next] -> [20 | next] --+
          ^                           |
          +---------------------------+
size = 2
```

`u_{10}.next` is $u_{20}$, and `u_{20}.next` is $u_{10}$.

## 9.2 A three-node circle and a cursor

Start from the one-node list holding $10$, `insertAfter` $20$ after $10$, then `insertAfter` $30$ after $20$.

```text
head
  |
  v
[10 | next] -> [20 | next] -> [30 | next] --+
  ^                                          |
  +------------------------------------------+
size = 3
```

Following `next` from `head` visits $10, 20, 30$, and the next follow returns to $10$. The laboratory checks that the node reached after exactly `size` follows is `head` again, and that the `size` nodes visited are distinct.

**Definition.** A *cursor* is a reference to one node of the circle, stored beside `head`. *Advancing* the cursor means replacing it with `cursor.next`.

Advancing is $\Theta(1)$ and rewrites no node's `next`. It rewrites the external cursor variable. On the three-node circle, three advances return the cursor to the node where it started, because the circle length is `size`.

*Rotate* moves which node is the head:

```text
rotate():
    if head = null: error empty
    head = head.next
```

Apply `rotate` once to the three-node circle. No node's `next` changes. `head` moves from $u_{10}$ to $u_{20}$. The old head's `next` already referred to $u_{20}$, and $u_{30}.\mathrm{next}$ already referred to $u_{10}$, so $u_{10}$ is now the last node on the walk that starts at the new head and runs for `size - 1` steps.

```text
head
  |
  v
[20 | next] -> [30 | next] -> [10 | next] --+
  ^                                          |
  +------------------------------------------+
size = 3
```

The sequence read from `head` is $20, 30, 10$. One further rotate makes it $30, 10, 20$. One more returns it to $10, 20, 30$. Each rotate is $\Theta(1)$ and writes zero node fields.

That cursor is a reason to use a circle. A client that must visit every element and then visit the first element again, repeating, can advance one reference. The stopping rule is "this is the node I started from" or "I have advanced `size` times," because `null` is not on the circle. The queue abstract data type that can be built from a related idea is Lecture 04. This lecture stops at the cursor and the rotate.

The empty circle cannot be rotated: there is no node for `head` to name. The one-node circle can be rotated, and `head = head.next` leaves `head` on that same node.

---

# 10. Sentinel nodes

**Definition.** A *sentinel* (dummy node) is a node that belongs to the representation and does not store a list element. It is not counted by `size`. It is not returned by `get` or by a walk over the elements.

The sentinel's own `element` field is unused. In the laboratory it is `null`, and the tests never treat that `null` as data. A list element is allowed to be any value the caller stores in a real node, including values that happen to be `null`; the audit distinguishes sentinels by their identity, the two sentinel objects, rather than by the contents of `element`. This lecture's examples store numbers in real nodes.

A sentinel is a device so that the predecessor slot of the first element, and on a doubly linked list the successor slot of the last element, always live in a node. The empty-list branch of insertion compares a reference with `null` and takes a different path. With a sentinel, that reference refers to a node even when no element exists, so the path is the same.

Cormen, Leiserson, Rivest, and Stein also use a sentinel as a search stopper by writing the target key into it. This lecture does not do that. The sentinels here are boundary markers only.

## 10.1 A sentinel head on a singly linked list

The list object holds `sentinel` and `tail`. The sentinel's `next` is the first real node, or `null` when there is no element. Convention: `tail` refers to the last real node when `size ≥ 1`, and `tail` refers to the sentinel when `size = 0`. Then `tail.next` is `null` in both cases.

```text
empty

sentinel
  |
  v
[sentinel | null]
  ^
 tail
size = 0

running list

sentinel
  |
  v
[sentinel | next] -> [10] -> [20] -> [30] -> [40 | null]
                                                ^
                                               tail
size = 4
```

The walk over elements starts at `sentinel.next` and stops at `null`. It does not yield the sentinel. `size` is $4$.

`insertAfter` is the procedure from Section 5.3, including the tail update `if tail = node then tail = created`. `pushFront(x)` is `insertAfter(sentinel, x)`. `pushBack(x)` is `insertAfter(tail, x)`.

Run `pushFront(10)` on the empty sentinel list with those same statements.

| Step | Values |
| --- | --- |
| `created.next = sentinel.next` | `created.next` is `null` |
| `sentinel.next = created` | the new node is the first real node |
| `tail = sentinel`, so `tail = created` | the new node is the tail |
| `size = 1` | sequence $10$ |

Run `pushFront(5)` on a sentinel list that already holds $10, 20, 30, 40$. `tail` names $u_{40}$, which is not the sentinel, so the tail assignment does not run. `sentinel.next` becomes $u_5$, and `u_5.next` is $u_{10}$. The sequence is $5, 10, 20, 30, 40$. The statements were the same four lines. The empty input and the non-empty input did not take different branches inside `pushFront`, because `pushFront` has no branch. The only conditional is the one inside `insertAfter` that asks whether the spliced node was the tail. On an empty list the sentinel is the tail, so the conditional updates `tail`. On a front insertion into a non-empty list the spliced node is the sentinel and is not the tail, so `tail` stays. One procedure covers both.

`popFront` on an empty sentinel list is still an error: there is no element at `sentinel.next`. The sentinel removed the empty branch from insertion at the front. It did not invent an element to delete.

Compare the non-sentinel `pushFront`, which tests `tail = null` to handle emptiness, with the sentinel `pushFront`, which is a single call to `insertAfter`. The empty case of front insertion has disappeared as a separate block of code. The representation still has an empty state. The state is `sentinel.next = null`, `tail = sentinel`, and `size = 0`, and the insertion code does not special-case it.

## 10.2 A sentinel head and a sentinel tail on a doubly linked list

This is the representation the laboratory implements as `DoublyLinkedList`.

Two sentinel nodes exist for the lifetime of the list. Call them `headSentinel` and `tailSentinel`. They are distinct objects. `headSentinel.prev` is `null`. `tailSentinel.next` is `null`. Real nodes, when any exist, sit strictly between them.

```text
empty

null <- [headSentinel] <-> [tailSentinel] -> null
size = 0

running list

null <- [headSentinel] <-> [10] <-> [20] <-> [30] <-> [40] <-> [tailSentinel] -> null
size = 4
```

Every real node's `prev` and `next` refer to nodes, never to `null`. The first real node's `prev` is `headSentinel`. The last real node's `next` is `tailSentinel`. In the empty list the two sentinels refer to each other.

`size` counts real nodes. In the running picture `size` is $4$, while the number of node objects is $6$. An audit that counts objects and expects `size` will reject a correct list. The audit counts nodes strictly between the sentinels.

Insertion before a held node, which is always a real node or the tail sentinel, uses one straight-line splice:

```text
insertBefore(node, element):
    created = new node(element, prev = node.prev, next = node)
    node.prev.next = created
    node.prev = created
    size = size + 1
    return created

pushBack(element):
    return insertBefore(tailSentinel, element)

pushFront(element):
    return insertBefore(headSentinel.next, element)

deleteNode(node):
    if node is either sentinel: error
    previous = node.prev
    following = node.next
    previous.next = following
    following.prev = previous
    node.prev = null
    node.next = null
    size = size - 1
    return node.element

popBack():
    if size = 0: error empty
    return deleteNode(tailSentinel.prev)

popFront():
    if size = 0: error empty
    return deleteNode(headSentinel.next)
```

`deleteNode` is the six link operations from Section 8.2: read `prev`, read `next`, write `previous.next`, write `following.prev`, clear `node.prev`, clear `node.next`. There is no test of the form `prev = null`. For a real node that test would be false, because a sentinel occupies the end. The procedure rejects a sentinel argument so that a bug cannot detach the boundary and so that `size` cannot be charged for a non-element.

**Empty `pushBack(10)`, same four assignments.** `node` is `tailSentinel`. `node.prev` is `headSentinel`.

| Assignment | Effect |
| --- | --- |
| `created.prev = headSentinel`, `created.next = tailSentinel` | the new node sits between the sentinels |
| `headSentinel.next = created` | this is `node.prev.next = created` |
| `tailSentinel.prev = created` | this is `node.prev = created` |
| `size = 1` | one element, three node objects |

```text
null <- [headSentinel] <-> [10] <-> [tailSentinel] -> null
size = 1
```

**`pushBack(50)` on the running four-element sentinel list, same four assignments.** `node` is `tailSentinel`. `node.prev` is $u_{40}$.

| Assignment | Effect |
| --- | --- |
| `created.prev = u_{40}`, `created.next = tailSentinel` | |
| `u_{40}.next = u_{50}` | |
| `tailSentinel.prev = u_{50}` | |
| `size = 5` | sequence $10, 20, 30, 40, 50$ |

No branch distinguished this call from the empty call. The empty-list case of `pushBack` has disappeared.

**`deleteNode(u_{30})` on the running sentinel list.** `u_{30}.prev` is $u_{20}$ and `u_{30}.next` is $u_{40}$, both non-null. The two rewires produce `headSentinel ↔ 10 ↔ 20 ↔ 40 ↔ tailSentinel`, and `size` becomes $3$. The same two rewires delete the only element of a one-element list: `previous` is `headSentinel`, `following` is `tailSentinel`, and the result is the empty picture. The same two rewires delete the first element or the last element. The four positional cases of the non-sentinel `deleteNode` in Section 8.2 are one case here.

The code got shorter in a specific way. Non-sentinel `deleteNode` contained two conditionals, one for a missing `prev` and one for a missing `next`. Sentinel `deleteNode` contains neither. Non-sentinel `pushBack` contained a branch for `tail = null`. Sentinel `pushBack` contains no branch. The empty list remains representable. It is the mutual link between the two sentinels, with `size = 0`. Emptiness is still tested by `popFront` and `popBack`, because removing an element that is not there has no correct result. The test reads `size` or compares `headSentinel.next` with `tailSentinel`. It is not a second implementation of the splice.

---

# 11. Comparison with the dynamic array

The dynamic array is the structure from Lecture 02: elements in contiguous slots, capacity grown by a constant factor greater than $1$ when an append needs a slot and none remain. `get(i)` computes an address and is $\Theta(1)$ in the worst case. Insertion at index $i$ moves the elements in slots $i, \ldots, n-1$. Insertion at the end is $\Theta(1)$ amortized under that growth rule, and $\Theta(n)$ in the worst case on a resize. This table uses those bounds as stated results. It does not re-prove the amortized argument, and it records no measured times.

"Known position" means a node reference the caller already holds, for either list, and an index the caller already holds, for the dynamic array. The walk that turns an index into a node is the `get` row, not the known-position row.

| | Dynamic array | Singly linked list with `head`, `tail`, and `size` | Doubly linked list |
| --- | --- | --- | --- |
| `get` by index, worst case | $\Theta(1)$ | $\Theta(n)$ | $\Theta(n)$ |
| Insert at the front, worst case | $\Theta(n)$ | $\Theta(1)$ | $\Theta(1)$ |
| Insert at the end | $\Theta(1)$ amortized; $\Theta(n)$ worst case on a resize | $\Theta(1)$ worst case, because `tail` is stored | $\Theta(1)$ worst case |
| Insert at a known position, worst case | $\Theta(n)$. The index is known, and the later elements still move. | $\Theta(1)$. `insertAfter` the held node. | $\Theta(1)$. Insert or delete at the held node. |
| Scan $n$ elements, worst case | $\Theta(n)$ | $\Theta(n)$ | $\Theta(n)$ |
| Extra memory | Unused capacity: $0$ when `size` equals capacity, and $\Theta(n)$ immediately after a geometric expansion. | $\Theta(n)$ `next` references, plus `head`, `tail`, and `size`. | $\Theta(n)$ `prev` references and $\Theta(n)$ `next` references. The sentinel form adds two nodes. |
| Locality | Element $i+1$ occupies the address of element $i$ plus one element stride. | The address of the successor is the contents of `next`. It is not a fixed stride from the predecessor. | Same as the singly linked list. `prev` adds a second reference and does not place the nodes in order in memory. |

Extra memory is counted in references and slots in the RAM model, not in bytes measured on one engine. JavaScript object headers are engine-specific. They are real, and they are not part of these $\Theta$ expressions. Both structures use $\Theta(n)$ words for $n$ elements. The list pays $\Theta(n)$ link fields at every $n$. The dynamic array pays unused slots only when `capacity` exceeds `size`, and geometric growth keeps that surplus $\Theta(n)$ immediately after an expansion and $0$ immediately before the next one, when `size` has caught up with `capacity`. Asymptotically, a geometric dynamic array's reserved block is $\Theta(n)$ whenever capacity is a constant factor times `size`. The distinction to use when choosing is the one in the operation rows, together with locality, not a claim that one of them is $o(n)$ extra memory.

Locality does not change the RAM-model scan bound. A scan is $\Theta(n)$ on both structures because each performs $\Theta(n)$ element visits and the model charges $\Theta(1)$ for each visit and each link follow. On a machine with a cache, consecutive addresses are cheaper to stream than addresses scattered by allocation. That is a statement about a finer machine model. This course does not assign a $\Theta$ to it and does not treat it as a proof that the array scan is asymptotically faster. It is a reason, outside the RAM bound, to prefer the array when the mix is index access and long scans, and to prefer the list when the mix is splices at nodes the program already holds, especially at the front.

Insertion at a known index on a singly linked list is the sum of two rows: $\Theta(i)$ to walk, then $\Theta(1)$ to splice, which is $\Theta(i)$. Insertion at a known index on the dynamic array is $\Theta(n - i)$ element moves in the model of Lecture 02, which is $\Theta(n)$ in the worst case when $i$ is a constant. A program that splices often in the middle and does not already hold the node must pay for the walk every time. If it does not keep the node, the list's constant splice is not the cost of the call.

`popBack` is the operation the table's "insert at the end" row does not reveal. On the singly linked list with a tail it is $\Theta(n)$ worst case. On the doubly linked list it is $\Theta(1)$ worst case. On the dynamic array, removing the last element is $\Theta(1)$ worst case when it only decrements `size`; Lecture 02's occasional shrinking policy, if you use one, is an amortized question and is not re-opened here. The usual representation without shrinking charges $\Theta(1)$ worst case for pop at the end.

---

# 12. Invariants

An invariant is a predicate that is true of the representation after `construction` and after every public operation that returns, including operations that throw without modifying the list. The procedures above are written so that each of them restores the predicate before it returns. The laboratory's `audit` checks the predicate exactly, not up to a constant.

## 12.1 Non-circular singly linked list with `head`, `tail`, and `size`

Let $S$ be the set of nodes reachable from `head` by following `next`, not including `null`.

1. `size` is an integer, `size ≥ 0`, and `size = |S|`.
2. If `size = 0`, then `head = null` and `tail = null`.
3. If `size ≥ 1`, then `tail` is a node in $S$, `tail.next = null`, and the unique node in $S$ whose `next` is `null` is `tail`.
4. Following `next` from `head` visits `size` distinct nodes and then `null`. In particular the chain contains no cycle.

Condition 4 implies condition 1's count once the walk is required to agree with `size`. The audit walks at most `size` steps and rejects a repeat or an early `null` that disagrees with `tail`.

The tail reference on the running list satisfies condition 3 because `u_{40}.next` is `null` and $u_{40}$ is the node at the end of a $4$-node walk. A list whose chain is $10, 20, 30, 40$ while `tail` still names $u_{30}$ fails condition 3, because `tail.next` is $u_{40}$, not `null`.

## 12.2 Non-circular doubly linked list without sentinels

1. Conditions 1 through 4 of Section 12.1 hold for `head`, `tail`, `size`, and `next`.
2. If `size ≥ 1`, then `head.prev = null`.
3. For every node $u$ in the chain, if `u.next ≠ null` then `u.next.prev = u`, and if `u.prev ≠ null` then `u.prev.next = u`.
4. Following `prev` from `tail` visits the same `size` nodes in reverse order and then `null`.

Condition 3 is the agreement of each stored pair. It fails if `u_{20}.next` is $u_{30}$ while `u_{30}.prev` is $u_{10}$. A forward walk and a backward walk would then disagree about the sequence, and `deleteNode(u_{30})` would rewire $u_{10}$ rather than $u_{20}$.

## 12.3 Circular singly linked list

1. `size = 0` if and only if `head = null`. When `size = 0`, there is no node.
2. If `size = 1`, then `head.next = head`.
3. If `size ≥ 1`, following `next` from `head` visits `size` distinct nodes and the next node after those is `head` again.
4. No node's `next` is `null`.

The one-node condition is not implied by a casual reading of "the last node points at the head" unless the only node is recognized as both the first and the last. Condition 2 writes that case down so it cannot be confused with condition 1.

## 12.4 Sentinel doubly linked list

1. `headSentinel` and `tailSentinel` are distinct nodes, they are not elements, and `size` does not count them.
2. `headSentinel.prev = null` and `tailSentinel.next = null`.
3. `size` equals the number of nodes strictly between the sentinels on the `next` chain.
4. For every node $u$ from `headSentinel` through `tailSentinel` inclusive, the successor and predecessor links that exist agree: `u.next.prev = u` whenever `u` is not `tailSentinel`, and `u.prev.next = u` whenever `u` is not `headSentinel`.
5. The forward walk from `headSentinel` reaches `tailSentinel` in exactly `size + 1` follows and does not repeat a node. The backward walk from `tailSentinel` reaches `headSentinel` in exactly `size + 1` follows.

On the running sentinel list, `size + 1 = 5`: `headSentinel` to $10$, to $20$, to $30$, to $40$, to `tailSentinel`. The number of real nodes is $4$, which equals `size`. Counting six node objects and storing `6` in `size` fails condition 1 and condition 3.

The non-circular condition "`tail.next` is `null`" applies to the data tail of the representations in Sections 12.1 and 12.2. In Section 12.4 the data tail is `tailSentinel.prev`, and that node's `next` is `tailSentinel`, not `null`. The `null` sits on `tailSentinel.next`. Applying the non-sentinel sentence to the sentinel representation without that translation will make a correct sentinel list look broken.

## 12.5 What the operations must restore

Each public operation may temporarily break a condition in the middle of a splice. `insertAfter` allocates a node that is not yet linked from its predecessor. The invariant is required when the operation returns, not between two of its assignments. A caller must not observe the list, or follow an arbitrary node into it, in the middle of an operation. The traces in Section 6 are observations made by the teacher between assignments; the implementation does not publish those intermediate states.

`size` changes by $+1$ on every insertion of a real node and by $-1$ on every deletion of a real node, and it does not change on `reverse`, `find`, `get`, `rotate`, or cursor advance. After `reverse`, the singly linked invariant holds for the reversed sequence, with the old head as the new tail.

---

# 13. Reverse in place

**Definition.** *Reversing in place* rewrites the `next` fields of the existing singly linked nodes so that the element sequence $a_0, a_1, \ldots, a_{n-1}$ becomes $a_{n-1}, \ldots, a_1, a_0$. The procedure allocates no new node and builds no second list. It uses a constant number of additional references.

```text
reverse():
    previous = null
    current = head
    originalHead = head
    while current != null:
        following = current.next
        current.next = previous
        previous = current
        current = following
    head = previous
    tail = originalHead
    if head = null:
        tail = null
```

The running list enters the procedure as `head` = $u_{10}$, `tail` = $u_{40}$, and `u_{10} → u_{20} → u_{30} → u_{40} → null`.

## 13.1 The loop invariant

Let the nodes in their original order be $x_0, x_1, \ldots, x_{n-1}$. If $n = 0$, there are no nodes and `head` is `null`.

**Invariant.** At the start of each iteration of the `while` condition, and also when the condition is tested and fails, there is an integer $k$ with $0 \le k \le n$ such that all of the following hold.

1. `current` is $x_k$ when $k < n$, and `current` is `null` when $k = n$.
2. `previous` is `null` when $k = 0$, and `previous` is $x_{k-1}$ when $k \ge 1$.
3. When $k \ge 1$, following `next` from `previous` visits $x_{k-1}, x_{k-2}, \ldots, x_0$ and then `null`. When $k = 0$, that chain is empty.
4. When $k < n$, following `next` from `current` visits $x_k, x_{k+1}, \ldots, x_{n-1}$ and then `null`.
5. The two chains are disjoint, and every node of the list is on exactly one of them.
6. `size` is still $n$. The variables `head` and `tail` still hold their values from before the call. The loop does not assign them.

**Initialization.** The procedure sets `previous = null` and `current = head` before the loop. That is $k = 0$. If $n = 0$, `current` is already `null`, which is the termination case $k = n$. If $n \ge 1$, `current` is $x_0$ and the suffix chain is the whole original list. The reversed chain is empty. All six clauses hold.

**Maintenance.** Assume the invariant holds at the start of an iteration with some $k < n$, so the condition `current ≠ null` is true and `current` is $x_k$. The body reads `following = current.next`. By clause 4, `following` is $x_{k+1}$ when $k + 1 < n$, and `following` is `null` when $k = n - 1$. The assignment `current.next = previous` makes $x_k$ point at $x_{k-1}$ when $k \ge 1$, and makes $x_k$ point at `null` when $k = 0$. That is the step that extends the reversed chain by one node. The assignment `previous = current` makes `previous` name $x_k$. The assignment `current = following` makes `current` name $x_{k+1}$, or `null` when the suffix is exhausted. The new index is $k + 1$. The node $x_k$ has left the suffix and joined the reversed chain, so the chains remain disjoint and still cover every node. `size`, `head`, and `tail` were not written. The six clauses hold for $k + 1$.

**Termination.** The condition fails only when `current` is `null`. By clause 1, $k = n$. By clause 2, `previous` is `null` when $n = 0$, and `previous` is $x_{n-1}$ when $n \ge 1$. By clause 3, the chain from `previous` is $x_{n-1}, \ldots, x_0$ followed by `null`. The procedure then sets `head = previous` and `tail = originalHead`. The saved original head is $x_0$ when $n \ge 1$. The first iteration, which handled $k = 0$, set `x_0.next = null`, so the new tail's `next` is `null`. When $n = 0$, `originalHead` is `null` and the final test sets `tail` to `null` as well. `size` is unchanged. The Section 12.1 invariant holds for the reversed sequence.

The loop body is $\Theta(1)$ work and runs once per node, hence $n$ times. The procedure allocates no node. The extra memory is the four references `previous`, `current`, `following`, and `originalHead`, which is $\Theta(1)$. The running time is $\Theta(n)$ in the worst case, and also $\Theta(n)$ on every input of size $n$, because every node is rewired.

Saving `originalHead` before the loop is required for the tail. After the loop, `head` still holds $x_0$ until the assignment `head = previous`. The procedure in the box saves `originalHead` at entry, so the later assignment to `head` cannot lose $x_0$. Assigning `head = previous` first, and only afterwards reading `head` in the hope of finding the new tail, would read $x_{n-1}$ and would store the wrong tail.

## 13.2 Trace on $10, 20, 30, 40$

$x_0 = u_{10}$, $x_1 = u_{20}$, $x_2 = u_{30}$, $x_3 = u_{40}$, and $n = 4$. Each row is the start of an iteration.

| $k$ | `previous` chain | `current` chain |
| --- | --- | --- |
| $0$ | empty (`previous` is `null`) | $10 \to 20 \to 30 \to 40 \to \mathrm{null}$ |
| $1$ | $10 \to \mathrm{null}$ | $20 \to 30 \to 40 \to \mathrm{null}$ |
| $2$ | $20 \to 10 \to \mathrm{null}$ | $30 \to 40 \to \mathrm{null}$ |
| $3$ | $30 \to 20 \to 10 \to \mathrm{null}$ | $40 \to \mathrm{null}$ |

At termination, $k = 4$, `previous` names $u_{40}$, and `current` is `null`:

```text
previous
  |
  v
[40] -> [30] -> [20] -> [10] -> null
```

Then `head` becomes $u_{40}$ and `tail` becomes $u_{10}$.

```text
head
  |
  v
[40 | next] -> [30 | next] -> [20 | next] -> [10 | null]
                                                 ^
                                                tail
size = 4
```

The sequence is $40, 30, 20, 10$. A second reverse restores $10, 20, 30, 40$.

One node $10$ is the case $n = 1$. The single iteration sets that node's `next` from `null` to `null`, because `previous` started as `null`. `head` and `tail` both remain that node. The empty list does not enter the body; `head` and `tail` stay `null`.

---

# 14. Four bugs, on the same numbers

## 14.1 Overwriting `next` before the suffix is saved

The correct first write of a middle insert copies `u_{20}.next` into the new node. The following procedure swaps the writes. The call is `buggyInsertAfter(u_{20}, 25)` on the running list.

```text
buggyInsertAfter(node, element):
    created = new node(element, null)
    node.next = created
    created.next = node.next
```

**After the allocation.** `created` is $u_{25}$ with `next` equal to `null`. The list is still $10 \to 20 \to 30 \to 40 \to \mathrm{null}$. The only reference from the list to $u_{30}$ is `u_{20}.next`.

**After `node.next = created`.** `u_{20}.next` is $u_{25}$. No field in the reachable list refers to $u_{30}$. The node $u_{30}$ still refers to $u_{40}$, and $u_{40}$ still refers to `null`, but a walk from `head` cannot reach them.

```text
head -> [10] -> [20] -> [25 | null]

unreachable from head:

[30] -> [40] -> null
```

The lost nodes are $u_{30}$ and $u_{40}$. Their elements are $30$ and $40$.

**After `created.next = node.next`.** `node.next` has already been changed, so `node.next` is `created`. The assignment stores `created` into `created.next`.

```text
head -> [10] -> [20] -> [25] -+
                         ^    |
                         +----+

[30] -> [40] -> null     unreachable from head
```

The walk from `head` is $10, 20$, and then $25$ forever. `size` would become $5$ if the procedure updated it, which already disagrees with any finite walk that stops at `null`. The cycle is the one-node cycle on $u_{25}$. The lost suffix is the original successor of the splice point and every node that was reachable from that successor.

The repair is the order in Section 6.2: write `created.next = node.next` while `node.next` still names $u_{30}$, and only then write `node.next = created`.

## 14.2 An off-by-one tail

Start from the running list and insert $50$ after the tail, but omit the assignment `tail = created`.

The chain is $10 \to 20 \to 30 \to 40 \to 50 \to \mathrm{null}$. `tail` still names $u_{40}$. `size` is $5$ if it was incremented. Condition 3 of Section 12.1 fails: `tail.next` is $u_{50}$, not `null`.

Now call the correct `pushBack(60)`, which trusts `tail`:

| Step | Effect |
| --- | --- |
| Allocate $u_{60}$ with `next = null` | |
| `tail.next = u_{60}` | this writes `u_{40}.next`, overwriting the reference to $u_{50}$ |
| `tail = u_{60}` | |

```text
head -> [10] -> [20] -> [30] -> [40] -> [60] -> null
                                         ^
                                        tail

[50] unreachable from head
```

The lost node is $u_{50}$. The off-by-one error was a tail that named the second-to-last node. The next append used that stale tail as if it were last and destroyed the true suffix. The repair is the conditional already in `insertAfter`: when the node that was spliced after is `tail`, move `tail` to the new node before the operation returns. The related one-node error on `popFront` is the same invariant: when the removed head was the last node, set `tail` to `null` before returning.

## 14.3 The one-node circular list left open

A procedure adds the first element $10$ of a circular list by writing `head = created` and leaving `created.next` equal to `null`.

```text
head -> [10 | null]
size = 1
```

That picture satisfies the non-circular one-node invariant and fails Section 12.3. The empty picture is `head = null` and no node. These are not interchangeable. `rotate` on the broken one-node list sets `head = head.next`, so `head` becomes `null`, and the element $10$ is lost. `advance` of a cursor does the same. A later `insertAfter` computes `created.next = node.next` and obtains `null`, so the structure grows as a line and never returns to `head`.

The repair is `created.next = created` before the one-node list is published. After that, `rotate` is `head = head.next` and the cursor stays on $u_{10}$. The empty list is still represented by `head = null`, and `rotate` on it is an error rather than a self-loop on a node that does not exist.

## 14.4 Counting the sentinel in `size`

Take the sentinel doubly linked running list. The node objects are `headSentinel`, $u_{10}$, $u_{20}$, $u_{30}$, $u_{40}$, and `tailSentinel`. Suppose an insertion sets `size` to $6$ because it counted every object.

A loop that starts at `headSentinel` and follows `next` `size` times visits `headSentinel`, $10$, $20$, $30$, $40$, and `tailSentinel`. The two sentinels are not elements. The tail sentinel's unused `element` field is `null`. A sum of elements either adds that `null` or throws when it tries to use it as a number. A loop that starts at the first real node and runs `size` times walks $10, 20, 30, 40$, then `tailSentinel`, then `null`, and the sixth follow faults.

The repair is the rule in Section 10: `size` starts at $0$, increases by $1$ only inside the insertion of a real node, and decreases by $1$ only inside the deletion of a real node. On this picture `size` is $4$. The audit's forward walk takes `size + 1` follows to go from `headSentinel` to `tailSentinel`, and that count is $5$, not `size`.

---

# 15. Laboratory

Study time for this section is part of the 8 hours. Do the guided trace with a pencil, then the problems, before you read the program. The program checks the same numbers. Copy it to `linked-lists-lab.mjs` and run `node linked-lists-lab.mjs`. It prints `ALL TESTS PASSED` or throws. Then change one assertion so that it must fail, confirm that it fails, and restore it.

## 15.1 Guided trace

Cover Section 6.1 and rebuild `pushFront(5)` on the running list.

Start:

```text
head -> [10] -> [20] -> [30] -> [40] -> null
tail = node 40
size = 4
```

Write the two assignments yourself. After the first, the new node's `next` names $10$, and a walk from `head` is still $10, 20, 30, 40$. After the second, `head` names $5$, the walk is $5, 10, 20, 30, 40$, `tail` still names $40$, and `size` is $5$. Compare your picture with Section 6.1. The laboratory asserts this final picture.

## 15.2 Problems to finish before reading the program

Start each problem from $10, 20, 30, 40$ unless it says otherwise. Record the sequence, `head`'s element or `null`, `tail`'s element or `null`, and `size`.

1. `insertAfter` the node holding $20$, with element $25$. Include the intermediate moment when both the node $20$ and the new node refer to $30$, and the walk from `head` is still the original four elements.
2. `popFront`.
3. `deleteAfter` the node holding $20$.
4. Singly linked `popBack`. How many `next` reads occur for $n = 4$, for $n = 1$, and for $n = 7$?
5. `reverse`. Write the `previous` chain and the `current` chain at $k = 0, 1, 2, 3$, then the final `head` and `tail`.
6. Doubly linked sentinel form. `deleteNode` on the held node $30$. How many link reads and writes does the procedure perform, and what is that count on a list of $32$ real nodes?
7. Draw the empty circular list and the one-node circular list holding $10$. Rotate the circle $10 \to 20 \to 30 \to 10$ once and write the sequence read from `head`.
8. On the singly sentinel list, `pushFront(10)` starting from empty. State `size`, whether `tail` is the sentinel, and the element sequence. Then explain why `size` is not $1$ plus the sentinel.

---

## LABORATORY PROGRAM

```javascript
import assert from "node:assert/strict";

class StepCounter {
  constructor() {
    this.steps = 0;
  }

  tick() {
    this.steps += 1;
  }
}

class SinglyNode {
  constructor(element, next) {
    this.element = element;
    this.next = next;
  }
}

class SinglyLinkedList {
  constructor() {
    this.head = null;
    this.tail = null;
    this.size = 0;
  }

  static fromValues(values) {
    const list = new SinglyLinkedList();
    for (const value of values) {
      list.pushBack(value);
    }
    return list;
  }

  pushFront(element) {
    const created = new SinglyNode(element, this.head);
    this.head = created;
    if (this.tail === null) {
      this.tail = created;
    }
    this.size += 1;
    return created;
  }

  popFront() {
    if (this.head === null) {
      throw new Error("empty list");
    }
    const removed = this.head;
    this.head = removed.next;
    this.size -= 1;
    if (this.head === null) {
      this.tail = null;
    }
    removed.next = null;
    return removed.element;
  }

  pushBack(element) {
    const created = new SinglyNode(element, null);
    if (this.tail === null) {
      this.head = created;
      this.tail = created;
    } else {
      this.tail.next = created;
      this.tail = created;
    }
    this.size += 1;
    return created;
  }

  popBack(counter = null) {
    if (this.head === null) {
      throw new Error("empty list");
    }
    if (this.head === this.tail) {
      const element = this.head.element;
      this.head = null;
      this.tail = null;
      this.size = 0;
      return element;
    }
    let previous = this.head;
    let reads = 0;
    while (true) {
      const successor = previous.next;
      if (counter !== null) {
        counter.tick();
      }
      reads += 1;
      if (successor === this.tail) {
        break;
      }
      if (successor === null || reads > this.size) {
        throw new Error("tail is not on the chain");
      }
      previous = successor;
    }
    const element = this.tail.element;
    previous.next = null;
    this.tail = previous;
    this.size -= 1;
    return element;
  }

  insertAfter(node, element) {
    if (node === null) {
      throw new Error("missing node");
    }
    const created = new SinglyNode(element, node.next);
    node.next = created;
    if (this.tail === node) {
      this.tail = created;
    }
    this.size += 1;
    return created;
  }

  deleteAfter(node) {
    if (node === null || node.next === null) {
      throw new Error("no successor");
    }
    const removed = node.next;
    node.next = removed.next;
    if (this.tail === removed) {
      this.tail = node;
    }
    this.size -= 1;
    removed.next = null;
    return removed.element;
  }

  find(element) {
    let current = this.head;
    while (current !== null) {
      if (current.element === element) {
        return current;
      }
      current = current.next;
    }
    return null;
  }

  get(index) {
    if (!Number.isInteger(index) || index < 0 || index >= this.size) {
      throw new RangeError("index out of range");
    }
    let current = this.head;
    for (let step = 0; step < index; step += 1) {
      current = current.next;
    }
    return current.element;
  }

  reverse() {
    const trace = [];
    let previous = null;
    let current = this.head;
    const originalHead = this.head;
    while (current !== null) {
      trace.push({
        previous: previous === null ? null : previous.element,
        current: current.element,
      });
      const following = current.next;
      current.next = previous;
      previous = current;
      current = following;
    }
    this.head = previous;
    this.tail = originalHead;
    if (this.head === null) {
      this.tail = null;
    }
    return trace;
  }

  toArray() {
    const values = [];
    let current = this.head;
    const seen = new Set();
    while (current !== null) {
      if (seen.has(current)) {
        throw new Error("cycle on a non-circular list");
      }
      seen.add(current);
      values.push(current.element);
      current = current.next;
      if (values.length > this.size) {
        throw new Error("walk exceeded size");
      }
    }
    return values;
  }

  audit() {
    if (!Number.isInteger(this.size) || this.size < 0) {
      throw new Error("size is not a non-negative integer");
    }
    if (this.size === 0) {
      if (this.head !== null || this.tail !== null) {
        throw new Error("empty list must have null head and tail");
      }
      return;
    }
    if (this.head === null || this.tail === null || this.tail.next !== null) {
      throw new Error("tail.next must be null");
    }
    let current = this.head;
    let count = 0;
    const seen = new Set();
    while (current !== null) {
      if (seen.has(current)) {
        throw new Error("cycle on a non-circular list");
      }
      seen.add(current);
      count += 1;
      if (current.next === null && current !== this.tail) {
        throw new Error("a node other than tail has a null next");
      }
      current = current.next;
      if (count > this.size) {
        throw new Error("walk exceeded size");
      }
    }
    if (count !== this.size) {
      throw new Error("size does not match the chain");
    }
  }
}

class SinglySentinelList {
  constructor() {
    this.sentinel = new SinglyNode(null, null);
    this.tail = this.sentinel;
    this.size = 0;
  }

  insertAfter(node, element) {
    const created = new SinglyNode(element, node.next);
    node.next = created;
    if (this.tail === node) {
      this.tail = created;
    }
    this.size += 1;
    return created;
  }

  pushFront(element) {
    return this.insertAfter(this.sentinel, element);
  }

  pushBack(element) {
    return this.insertAfter(this.tail, element);
  }

  toArray() {
    const values = [];
    let current = this.sentinel.next;
    while (current !== null) {
      values.push(current.element);
      current = current.next;
      if (values.length > this.size) {
        throw new Error("walk exceeded size");
      }
    }
    return values;
  }

  audit() {
    if (this.sentinel.next === null) {
      if (this.tail !== this.sentinel || this.size !== 0) {
        throw new Error("empty sentinel list");
      }
      return;
    }
    if (this.tail === this.sentinel || this.tail.next !== null) {
      throw new Error("tail must be the last real node");
    }
    let current = this.sentinel.next;
    let count = 0;
    while (current !== null) {
      count += 1;
      if (current.next === null && current !== this.tail) {
        throw new Error("tail is not the last real node");
      }
      current = current.next;
      if (count > this.size) {
        throw new Error("walk exceeded size");
      }
    }
    if (count !== this.size) {
      throw new Error("size counted a sentinel or missed a node");
    }
  }
}

class DoublyNode {
  constructor(element, prev, next) {
    this.element = element;
    this.prev = prev;
    this.next = next;
  }
}

class DoublyLinkedList {
  constructor() {
    this.headSentinel = new DoublyNode(null, null, null);
    this.tailSentinel = new DoublyNode(null, this.headSentinel, null);
    this.headSentinel.next = this.tailSentinel;
    this.size = 0;
  }

  static fromValues(values) {
    const list = new DoublyLinkedList();
    for (const value of values) {
      list.pushBack(value);
    }
    return list;
  }

  insertBefore(node, element) {
    const created = new DoublyNode(element, node.prev, node);
    node.prev.next = created;
    node.prev = created;
    this.size += 1;
    return created;
  }

  pushFront(element) {
    return this.insertBefore(this.headSentinel.next, element);
  }

  pushBack(element) {
    return this.insertBefore(this.tailSentinel, element);
  }

  deleteNode(node, counter = null) {
    if (node === this.headSentinel || node === this.tailSentinel) {
      throw new Error("cannot delete a sentinel");
    }
    const previous = node.prev;
    const following = node.next;
    if (previous === null || following === null) {
      throw new Error("node is not linked between the sentinels");
    }
    if (counter !== null) {
      counter.tick();
      counter.tick();
    }
    previous.next = following;
    following.prev = previous;
    if (counter !== null) {
      counter.tick();
      counter.tick();
    }
    node.prev = null;
    node.next = null;
    if (counter !== null) {
      counter.tick();
    }
    if (counter !== null) {
      counter.tick();
    }
    this.size -= 1;
    return node.element;
  }

  popFront() {
    if (this.size === 0) {
      throw new Error("empty list");
    }
    return this.deleteNode(this.headSentinel.next);
  }

  popBack() {
    if (this.size === 0) {
      throw new Error("empty list");
    }
    return this.deleteNode(this.tailSentinel.prev);
  }

  find(element, counter = null) {
    let current = this.headSentinel.next;
    while (current !== this.tailSentinel) {
      if (counter !== null) {
        counter.tick();
      }
      if (current.element === element) {
        return current;
      }
      current = current.next;
    }
    return null;
  }

  toArray() {
    const values = [];
    let current = this.headSentinel.next;
    while (current !== this.tailSentinel) {
      values.push(current.element);
      current = current.next;
      if (values.length > this.size) {
        throw new Error("walk exceeded size");
      }
    }
    return values;
  }

  audit() {
    if (!Number.isInteger(this.size) || this.size < 0) {
      throw new Error("size is not a non-negative integer");
    }
    if (this.headSentinel === this.tailSentinel) {
      throw new Error("sentinels must be distinct");
    }
    if (this.headSentinel.prev !== null || this.tailSentinel.next !== null) {
      throw new Error("outer sentinel links must be null");
    }
    let forward = this.headSentinel;
    let steps = 0;
    const seen = new Set();
    while (forward !== this.tailSentinel) {
      if (seen.has(forward)) {
        throw new Error("cycle");
      }
      seen.add(forward);
      if (forward.next === null || forward.next.prev !== forward) {
        throw new Error("prev/next pair disagrees");
      }
      forward = forward.next;
      steps += 1;
      if (steps > this.size + 1) {
        throw new Error("forward walk failed to reach the tail sentinel");
      }
    }
    if (steps !== this.size + 1) {
      throw new Error("size does not match the real nodes");
    }
    let backward = this.tailSentinel;
    let backSteps = 0;
    while (backward !== this.headSentinel) {
      if (backward.prev === null || backward.prev.next !== backward) {
        throw new Error("prev/next pair disagrees");
      }
      backward = backward.prev;
      backSteps += 1;
      if (backSteps > this.size + 1) {
        throw new Error("backward walk failed to reach the head sentinel");
      }
    }
    if (backSteps !== this.size + 1) {
      throw new Error("backward walk does not match size");
    }
  }
}

class CircularSinglyList {
  constructor() {
    this.head = null;
    this.cursor = null;
    this.size = 0;
  }

  addFirst(element) {
    if (this.head !== null) {
      throw new Error("use insertAfter once the circle exists");
    }
    const created = new SinglyNode(element, null);
    created.next = created;
    this.head = created;
    this.cursor = created;
    this.size = 1;
    return created;
  }

  insertAfter(node, element) {
    if (node === null || this.head === null) {
      throw new Error("missing node");
    }
    const created = new SinglyNode(element, node.next);
    node.next = created;
    this.size += 1;
    return created;
  }

  advance() {
    if (this.cursor === null) {
      throw new Error("empty list");
    }
    this.cursor = this.cursor.next;
    return this.cursor;
  }

  rotate() {
    if (this.head === null) {
      throw new Error("empty list");
    }
    this.head = this.head.next;
    return this.head;
  }

  toArray() {
    if (this.head === null) {
      return [];
    }
    const values = [];
    let current = this.head;
    const seen = new Set();
    for (let step = 0; step < this.size; step += 1) {
      if (seen.has(current) || current === null) {
        throw new Error("circular audit failed during the walk");
      }
      seen.add(current);
      values.push(current.element);
      current = current.next;
    }
    if (current !== this.head) {
      throw new Error("walk of length size did not return to head");
    }
    return values;
  }

  audit() {
    if (this.size === 0) {
      if (this.head !== null || this.cursor !== null) {
        throw new Error("empty circular list");
      }
      return;
    }
    if (this.size === 1 && this.head.next !== this.head) {
      throw new Error("one-node circle must refer to itself");
    }
    const values = this.toArray();
    if (values.length !== this.size) {
      throw new Error("size does not match the circle");
    }
  }
}

function assertSinglyShape(list, values, headElement, tailElement) {
  list.audit();
  assert.deepEqual(list.toArray(), values);
  assert.equal(list.size, values.length);
  if (headElement === null) {
    assert.equal(list.head, null);
  } else {
    assert.equal(list.head.element, headElement);
  }
  if (tailElement === null) {
    assert.equal(list.tail, null);
  } else {
    assert.equal(list.tail.element, tailElement);
    assert.equal(list.tail.next, null);
  }
}

function testInsertAtHead() {
  const list = SinglyLinkedList.fromValues([10, 20, 30, 40]);
  const created = list.pushFront(5);
  assert.equal(created, list.head);
  assert.equal(created.next.element, 10);
  assertSinglyShape(list, [5, 10, 20, 30, 40], 5, 40);
}

function testInsertInMiddle() {
  const list = SinglyLinkedList.fromValues([10, 20, 30, 40]);
  const node = list.find(20);
  const created = new SinglyNode(25, node.next);
  assert.equal(created.next.element, 30);
  assert.deepEqual(list.toArray(), [10, 20, 30, 40]);
  node.next = created;
  if (list.tail === node) {
    list.tail = created;
  }
  list.size += 1;
  assert.equal(node.next, created);
  assert.equal(created.next.element, 30);
  assertSinglyShape(list, [10, 20, 25, 30, 40], 10, 40);

  const again = SinglyLinkedList.fromValues([10, 20, 30, 40]);
  const throughMethod = again.insertAfter(again.find(20), 25);
  assert.equal(throughMethod.next.element, 30);
  assertSinglyShape(again, [10, 20, 25, 30, 40], 10, 40);
}

function testDeleteAtHead() {
  const list = SinglyLinkedList.fromValues([10, 20, 30, 40]);
  assert.equal(list.popFront(), 10);
  assertSinglyShape(list, [20, 30, 40], 20, 40);
}

function testDeleteInMiddle() {
  const list = SinglyLinkedList.fromValues([10, 20, 30, 40]);
  assert.equal(list.deleteAfter(list.find(20)), 30);
  assertSinglyShape(list, [10, 20, 40], 10, 40);
}

function testPushBackAndPopEnds() {
  const list = SinglyLinkedList.fromValues([10, 20, 30, 40]);
  list.pushBack(50);
  assertSinglyShape(list, [10, 20, 30, 40, 50], 10, 50);

  const popped = SinglyLinkedList.fromValues([10, 20, 30, 40]);
  assert.equal(popped.popFront(), 10);
  assert.equal(popped.popBack(), 40);
  assertSinglyShape(popped, [20, 30], 20, 30);

  const single = SinglyLinkedList.fromValues([10]);
  assert.equal(single.popFront(), 10);
  assertSinglyShape(single, [], null, null);

  const emptyPush = new SinglyLinkedList();
  emptyPush.pushBack(10);
  assertSinglyShape(emptyPush, [10], 10, 10);
}

function testPopBackReads() {
  const four = SinglyLinkedList.fromValues([10, 20, 30, 40]);
  const fourCounter = new StepCounter();
  assert.equal(four.popBack(fourCounter), 40);
  assert.equal(fourCounter.steps, 4 - 1);
  assertSinglyShape(four, [10, 20, 30], 10, 30);

  const seven = SinglyLinkedList.fromValues([1, 2, 3, 4, 5, 6, 7]);
  const sevenCounter = new StepCounter();
  assert.equal(seven.popBack(sevenCounter), 7);
  assert.equal(sevenCounter.steps, 7 - 1);
  assert.equal(seven.tail.element, 6);

  const one = SinglyLinkedList.fromValues([10]);
  const oneCounter = new StepCounter();
  assert.equal(one.popBack(oneCounter), 10);
  assert.equal(oneCounter.steps, 0);
  assertSinglyShape(one, [], null, null);
}

function testFindAndGet() {
  const list = SinglyLinkedList.fromValues([10, 20, 30, 40]);
  assert.equal(list.find(10), list.head);
  assert.equal(list.find(40), list.tail);
  assert.equal(list.find(30).element, 30);
  assert.equal(list.find(99), null);
  assert.equal(list.get(0), 10);
  assert.equal(list.get(2), 30);
  assert.equal(list.get(3), 40);
  assert.throws(() => list.get(-1), RangeError);
  assert.throws(() => list.get(4), RangeError);
  assert.throws(() => new SinglyLinkedList().popFront(), /empty list/);
  assert.throws(() => list.deleteAfter(list.tail), /no successor/);
}

function testReverseTrace() {
  const list = SinglyLinkedList.fromValues([10, 20, 30, 40]);
  const trace = list.reverse();
  assert.deepEqual(trace, [
    { previous: null, current: 10 },
    { previous: 10, current: 20 },
    { previous: 20, current: 30 },
    { previous: 30, current: 40 },
  ]);
  assertSinglyShape(list, [40, 30, 20, 10], 40, 10);
  list.reverse();
  assertSinglyShape(list, [10, 20, 30, 40], 10, 40);

  const one = SinglyLinkedList.fromValues([10]);
  assert.deepEqual(one.reverse(), [{ previous: null, current: 10 }]);
  assertSinglyShape(one, [10], 10, 10);
  assert.equal(one.head.next, null);

  const empty = new SinglyLinkedList();
  assert.deepEqual(empty.reverse(), []);
  assertSinglyShape(empty, [], null, null);
}

function testSinglySentinel() {
  const list = new SinglySentinelList();
  list.audit();
  assert.equal(list.size, 0);
  assert.equal(list.tail, list.sentinel);
  assert.equal(list.sentinel.next, null);
  list.pushFront(10);
  list.audit();
  assert.deepEqual(list.toArray(), [10]);
  assert.equal(list.size, 1);
  assert.notEqual(list.tail, list.sentinel);
  list.pushBack(20);
  list.pushBack(30);
  list.pushBack(40);
  list.pushFront(5);
  list.audit();
  assert.deepEqual(list.toArray(), [5, 10, 20, 30, 40]);
  assert.equal(list.size, 5);
  assert.equal(list.tail.element, 40);
  assert.equal(list.tail.next, null);
}

function testDoublyTracesAndRoundTrip() {
  const list = DoublyLinkedList.fromValues([10, 20, 30, 40]);
  list.audit();
  assert.equal(list.size, 4);
  assert.deepEqual(list.toArray(), [10, 20, 30, 40]);
  assert.equal(list.headSentinel.next.element, 10);
  assert.equal(list.tailSentinel.prev.element, 40);
  assert.notEqual(list.size, 6);

  list.pushBack(50);
  list.audit();
  assert.deepEqual(list.toArray(), [10, 20, 30, 40, 50]);
  assert.equal(list.tailSentinel.prev.element, 50);
  assert.equal(list.size, 5);

  const popped = DoublyLinkedList.fromValues([10, 20, 30, 40]);
  assert.equal(popped.popBack(), 40);
  popped.audit();
  assert.deepEqual(popped.toArray(), [10, 20, 30]);
  assert.equal(popped.tailSentinel.prev.element, 30);
  assert.equal(popped.size, 3);

  const front = DoublyLinkedList.fromValues([10, 20, 30, 40]);
  front.pushFront(5);
  front.audit();
  assert.deepEqual(front.toArray(), [5, 10, 20, 30, 40]);

  const empty = new DoublyLinkedList();
  empty.audit();
  assert.equal(empty.size, 0);
  assert.equal(empty.headSentinel.next, empty.tailSentinel);
  assert.equal(empty.tailSentinel.prev, empty.headSentinel);
  empty.pushBack(10);
  empty.audit();
  assert.deepEqual(empty.toArray(), [10]);
  assert.equal(empty.popBack(), 10);
  empty.audit();
  assert.equal(empty.headSentinel.next, empty.tailSentinel);
  assert.equal(empty.size, 0);
}

function testDeleteKnownMiddleIsConstant() {
  const shortList = DoublyLinkedList.fromValues([10, 20, 30, 40]);
  const shortFind = new StepCounter();
  const middle = shortList.find(30, shortFind);
  assert.equal(shortFind.steps, 3);
  const shortDelete = new StepCounter();
  assert.equal(shortList.deleteNode(middle, shortDelete), 30);
  assert.equal(shortDelete.steps, 6);
  shortList.audit();
  assert.deepEqual(shortList.toArray(), [10, 20, 40]);
  assert.equal(shortList.size, 3);
  assert.equal(middle.prev, null);
  assert.equal(middle.next, null);

  const values = [];
  for (let value = 0; value < 32; value += 1) {
    values.push(value);
  }
  const longList = DoublyLinkedList.fromValues(values);
  const longFind = new StepCounter();
  const last = longList.find(31, longFind);
  assert.equal(longFind.steps, 32);
  const held = longList.find(16);
  const longDelete = new StepCounter();
  assert.equal(longList.deleteNode(held, longDelete), 16);
  assert.equal(longDelete.steps, 6);
  assert.equal(longDelete.steps, shortDelete.steps);
  longList.audit();
  assert.equal(longList.size, 31);
  assert.equal(longList.find(16), null);
  assert.equal(last.element, 31);

  assert.throws(
    () => shortList.deleteNode(shortList.headSentinel),
    /sentinel/,
  );
}

function testCircularCases() {
  const empty = new CircularSinglyList();
  empty.audit();
  assert.equal(empty.head, null);
  assert.deepEqual(empty.toArray(), []);
  assert.throws(() => empty.rotate(), /empty list/);

  const one = new CircularSinglyList();
  one.addFirst(10);
  one.audit();
  assert.equal(one.head.next, one.head);
  assert.equal(one.size, 1);
  assert.deepEqual(one.toArray(), [10]);
  one.rotate();
  assert.equal(one.head.element, 10);
  assert.equal(one.head.next, one.head);

  const circle = new CircularSinglyList();
  const first = circle.addFirst(10);
  const second = circle.insertAfter(first, 20);
  circle.insertAfter(second, 30);
  circle.audit();
  assert.deepEqual(circle.toArray(), [10, 20, 30]);
  const start = circle.cursor;
  circle.advance();
  circle.advance();
  circle.advance();
  assert.equal(circle.cursor, start);
  circle.rotate();
  circle.audit();
  assert.deepEqual(circle.toArray(), [20, 30, 10]);
  assert.equal(circle.head.element, 20);
}

function testInsertAfterTailUpdatesTail() {
  const list = SinglyLinkedList.fromValues([10, 20, 30, 40]);
  list.insertAfter(list.tail, 50);
  assertSinglyShape(list, [10, 20, 30, 40, 50], 10, 50);
  list.deleteAfter(list.find(40));
  assertSinglyShape(list, [10, 20, 30, 40], 10, 40);
}

testInsertAtHead();
testInsertInMiddle();
testDeleteAtHead();
testDeleteInMiddle();
testPushBackAndPopEnds();
testPopBackReads();
testFindAndGet();
testReverseTrace();
testSinglySentinel();
testDoublyTracesAndRoundTrip();
testDeleteKnownMiddleIsConstant();
testCircularCases();
testInsertAfterTailUpdatesTail();

console.log("ALL TESTS PASSED");
```

---

# 16. Common mistakes

**Wrong idea:** The cost of inserting after a node is the cost of finding that node, so a linked list makes middle insertion $\Theta(1)$ for a caller who has only an index.

**Correction:** `insertAfter` on a held reference is $\Theta(1)$ worst case. `get(i)` is $\Theta(i)$ worst case. A caller who has $i$ and not the node pays $\Theta(i)$ and then $\Theta(1)$. Quote both numbers. The constant splice is the reason the link exists; it begins only when the reference is in hand.

**Wrong idea:** Overwriting `next` with the new node, and then setting the new node's `next` from `node.next`, attaches the suffix.

**Correction:** The second read sees the new node, not the suffix. On `buggyInsertAfter` of $25$ after $20$ in $10, 20, 30, 40$, the assignment `node.next = created` drops the only reachable reference to $30$. The nodes holding $30$ and $40$ are unreachable from `head`. The following assignment makes $25$ point at itself. Save `node.next` in the new node's `next` before writing `node.next`.

**Wrong idea:** A stored tail makes every operation at the back $\Theta(1)$ on a singly linked list.

**Correction:** `pushBack` writes `tail.next` and moves `tail`. That is $\Theta(1)$. `popBack` must write the predecessor's `next`. The tail node does not store its predecessor, so the procedure reads `next` exactly $n - 1$ times for $n \ge 2$. On the running list that is $3$ reads. A `prev` field, not a more careful tail, is what removes those reads.

**Wrong idea:** After `insertAfter` the tail node, the new node is last because its `next` is `null`, so `tail` will catch up later.

**Correction:** `tail` moves only when some assignment moves it. Leaving `tail` on $40$ after appending $50$ makes `tail.next` equal $50$, which already breaks the invariant. The next correct `pushBack(60)` writes `u_{40}.next` and the node holding $50$ becomes unreachable. When the spliced node is `tail`, the operation sets `tail` to the new node before it returns. When `popFront` removes the only node, it sets `tail` to `null`.

**Wrong idea:** A circular list with one element is `head` referring to a node whose `next` is `null`, and the empty list is the same picture with `size = 0`.

**Correction:** The empty circular list has `head = null` and no node. The one-node circular list has `head.next = head`. `rotate` on the broken open node sets `head` to `null` and loses the element. `rotate` on a correct one-node circle stays on that node and writes no node field.

**Wrong idea:** `size` counts every node object, so a sentinel doubly linked list holding $10, 20, 30, 40$ has `size` $6$.

**Correction:** The two sentinels are not elements. `size` is $4$. A walk that treats `size` as an object count will read both sentinels, or will follow `tailSentinel.next`, which is `null`. Increase `size` only when a real node is inserted.

**Wrong idea:** `prev` makes `get(i)` $\Theta(1)$, because the list can walk backward.

**Correction:** Walking from the nearer end takes at most $\lfloor (n - 1) / 2 \rfloor$ link follows. That quantity is $\Theta(n)$. Constant-time index access is the address calculation of the dynamic array. `prev` makes `deleteNode` on a held node $\Theta(1)$, which is a different operation from `get`.

---

# 17. Examination

Close the lecture and write full solutions. The answer key is Section 18. Definitions should be one or two sentences each, in the form this lecture uses. Bounds must name the case. The running list, whenever a question says "the running list," is the singly linked list $10 \to 20 \to 30 \to 40 \to \mathrm{null}$ with `tail` on $40$ and `size` $4$, unless the question states the doubly linked or sentinel form of those same four elements.

## 17.1 Definitions

1. Define node, element, and `next`.
2. Define splice and walk, and say when a cost may add them.
3. Define the predecessor of a node on a singly linked list, and state the predecessor problem.
4. Define a sentinel. State what `size` counts when sentinels are present.
5. Define the circular singly linked list used in this lecture, including how the empty list and the one-node list differ.

## 17.2 Short answers

6. `pushFront` on the non-sentinel singly linked list is $\Theta(1)$ worst case, and `get(i)` is not. Name the step that `pushFront` avoids and the step that `get(i)` performs.
7. Why is `pushBack` $\Theta(1)$ worst case on the singly linked list with a tail, while `popBack` is $\Theta(n)$ worst case on that same representation?
8. Why is `deleteNode` on a held middle node $\Theta(1)$ worst case on a doubly linked list and $\Theta(n)$ worst case on a singly linked list that is given the same held node and no predecessor?
9. A sentinel doubly linked `pushBack` uses the same assignments on an empty list and on the running list. What does the empty representation look like, so that those assignments have a node to write?

## 17.3 Pointer updates

10. Trace `pushFront(5)` on the running list. After each assignment, state what the new node's `next` refers to, what `head` refers to, what `tail` refers to, and what `size` is. Finish with the element sequence.
11. Trace `insertAfter` of $25$ after the node holding $20$. Show the two `next` assignments in order. After the first, what is the walk from `head`, and which node does the new node refer to? After the second, give the sequence, `head`, `tail`, and `size`.
12. Trace `popFront` on the running list. Give the sequence, the element of `head`, the element of `tail`, `size`, and the returned value.
13. Trace `deleteAfter` the node holding $20$ on the running list. Give the sequence, `head`, `tail`, `size`, and the returned value. Which reference was the caller required to hold, and why?
14. On the non-sentinel doubly linked running list, delete the held node $30$. List the six link reads and writes in order. Give the resulting sequence. How many nodes does this procedure visit by following links from `head`?
15. From the non-sentinel doubly linked running list, trace `pushBack(50)` and, as a separate trace from the original list, `popBack`. For each, give the sequence and the element of `tail`.

## 17.4 Cost table

16. Fill every cell. For the dynamic array, use Lecture 02's bounds and name amortized where it applies. For the lists, use worst-case bounds. "Known position" means a held node reference for a list and a held index for the dynamic array.

| | Dynamic array | Singly linked, with head and tail | Doubly linked |
| --- | --- | --- | --- |
| `get` by index | | | |
| Insert at the front | | | |
| Insert at the end | | | |
| Insert at a known position | | | |
| Scan $n$ elements | | | |
| Extra memory | | | |
| Locality | | | |

17. A singly linked list has a tail. `popBack` is not in the table. Give its worst-case bound and the exact number of `next` reads when $n = 9$ and $n \ge 2$.

## 17.5 Invariants

18. State the four invariant conditions of the non-circular singly linked list with `head`, `tail`, and `size`.
19. Each picture starts from a list that was meant to represent $10, 20, 30, 40$ in the non-circular singly linked representation, except (c), which is doubly linked, and (d), which is circular. Name the invariant condition that fails.

(a) The chain is $10 \to 20 \to 30 \to \mathrm{null}$, `tail` names $30$, and `size` is $4$.

(b) The chain is $10 \to 20 \to 30 \to 10$, the representation is the non-circular one, and `size` is $3$.

(c) `u_{20}.next` is $u_{30}$ and `u_{30}.prev` is $u_{10}$.

(d) A circular list with `size` $1$ has `head` naming a node that holds $10$ and whose `next` is `null`.

## 17.6 Find the bug

20. The running list is $10 \to 20 \to 30 \to 40 \to \mathrm{null}$. The call is `buggyInsertAfter` on the node holding $20$, with element $25$.

```text
buggyInsertAfter(node, element):
    created = new node(element, null)
    node.next = created
    created.next = node.next
```

After the call, what does a walk from `head` do? Which original nodes are unreachable from `head`? Name their elements. What cycle exists, and which assignment created it?

## 17.7 Reverse and quantitative checks

21. Trace `reverse` on the running list. Give the `previous` chain and the `current` chain at the start of each iteration. State `head`, `tail`, and the sequence after the procedure returns. State the worst-case time and the extra memory.
22. State the loop invariant of `reverse`, including what $k$ counts.
23. A sentinel doubly linked list holds the six elements $10, 20, 30, 40, 50, 60$. How many node objects exist, including sentinels? What is `size`? How many `next` follows does the forward audit take to travel from the head sentinel to the tail sentinel?
24. `get(5)` on a singly linked list whose `size` is at least $6$ follows `next` how many times? `find` of a missing value on a list of $n$ nodes examines how many nodes in the worst case?

---

# 18. Answer key

## 18.1 Definitions

1. A node is a record holding one element and one or more links. The element is the value stored in the node; in this lecture's examples it is a number. `next` is the successor node, or `null` when the node has no successor.

2. A splice is a constant-length sequence of reference assignments that attaches or detaches a node using references the caller already holds. A walk follows links from an entry node until it reaches a stated node, index, or element, or until it fails. Add the costs only when the algorithm performs both. A splice on a reference already in hand does not include a walk.

3. The predecessor of a node $u$ is the node $p$ with `p.next = u`. The first node has no predecessor node; `head` is the slot that refers to it. The predecessor problem is that a singly linked node $u$ does not store $p$, so changing `p.next` requires a walk from `head` unless the caller already holds $p$ or $u$ is the head.

4. A sentinel is a node that belongs to the representation and is not an element. `size` counts real nodes only. It does not count a sentinel head, and it does not count a sentinel tail.

5. A circular singly linked list has one external `head`, and the last node's `next` refers to the first node. The empty list is `head = null` and no node, with `size` $0$. The one-node list is a node whose `next` refers to itself, and `head` refers to that node, with `size` $1$.

## 18.2 Short answers

6. `pushFront` avoids a walk and avoids moving the existing elements. It allocates a node whose `next` is the old `head`, then points `head` at that node. `get(i)` performs the walk: it follows `next` exactly $i$ times from `head`, because a node does not store an index and the nodes are not in a contiguous addressable block.

7. `pushBack` changes the node that `tail` already names: it writes `tail.next` and then moves `tail` to the new node. No earlier node participates, so the worst case is $\Theta(1)$. `popBack` must change the predecessor of the tail. `tail` names the last node, and `tail.next` is `null`, so neither field is that predecessor. The procedure follows `next` from `head` until it sees the tail. For $n \ge 2$ that is $n - 1$ reads, which is $\Theta(n)$ in the worst case.

8. On the doubly linked list the held node stores `prev` and `next`, so both neighbors are available in $\Theta(1)$ time and a constant number of assignments rewires them. There is no loop. On the singly linked list the held middle node stores `next` and does not store `prev`. The assignment that removes it is `predecessor.next = node.next`, and producing the predecessor walks from `head`. That walk is $\Theta(n)$ in the worst case.

9. The empty sentinel doubly linked list is the pair of distinct sentinels with `headSentinel.next = tailSentinel`, `tailSentinel.prev = headSentinel`, `headSentinel.prev = null`, `tailSentinel.next = null`, and `size = 0`. `pushBack` calls `insertBefore(tailSentinel)`. The assignment `node.prev.next = created` writes `headSentinel.next` when the list is empty, because `tailSentinel.prev` is `headSentinel`. The predecessor slot is a node in both the empty list and the running list, so the procedure has no `null` branch.

## 18.3 Pointer updates

10. Assignment 1 allocates a node holding $5$ whose `next` is the node holding $10$. `head` still names $10$. `tail` still names $40$. `size` is still $4$. The walk from `head` is $10, 20, 30, 40$. Assignment 2 sets `head` to the new node. `tail` stays on $40$ because `tail` was not `null`. `size` becomes $5$. The new node's `next` still names $10$. The sequence is $5, 10, 20, 30, 40$.

11. Assignment 1 allocates a node holding $25$ whose `next` is the node holding $30$. The walk from `head` is still $10, 20, 30, 40$, because the node holding $20$ still points at $30$ and nothing points at $25$ yet. Assignment 2 sets the `next` of $20$ to the new node. `tail` stays on $40$ because the spliced node was not the tail. `size` becomes $5$. The sequence is $10, 20, 25, 30, 40$. `head` names $10$.

12. `removed` is the node holding $10$. `head` becomes the node holding $20$. `size` becomes $3$. `head` is not `null`, so `tail` stays on $40$. The detached node's `next` is set to `null`. The sequence is $20, 30, 40$. The returned value is $10$.

13. `removed` is the successor of $20$, the node holding $30$. The `next` of $20$ becomes the `next` of $30$, which is the node holding $40$. `tail` names $40$, which is not the removed node, so `tail` stays. `size` becomes $3$. The removed node's `next` is cleared. The sequence is $10, 20, 40$. `head` names $10$. The returned value is $30$. The caller had to hold the predecessor, the node $20$. The node $30$ does not store a reference to $20$, and `deleteAfter` rewrites the predecessor's `next`.

14. Read `prev` of $30$, which is $20$. Read `next` of $30$, which is $40$. Write `next` of $20$ so that it names $40$. Write `prev` of $40$ so that it names $20$. Write `prev` of $30$ as `null`. Write `next` of $30$ as `null`. The sequence is $10, 20, 40$. `head` stays on $10$ and `tail` stays on $40$. The procedure follows zero links from `head`. The six operations use fields of the held node and of its immediate neighbors.

15. `pushBack(50)` allocates a node whose `prev` is $40$ and whose `next` is `null`, writes the `next` of $40$ to that node, and sets `tail` to it. The sequence is $10, 20, 30, 40, 50$. `tail` holds $50$. Separately, `popBack` from the original list reads `prev` of $40$, which is $30$, sets the `next` of $30$ to `null`, and sets `tail` to $30$. The sequence is $10, 20, 30$. `tail` holds $30$.

## 18.4 Cost table

16.

| | Dynamic array | Singly linked, with head and tail | Doubly linked |
| --- | --- | --- | --- |
| `get` by index | $\Theta(1)$ worst case | $\Theta(n)$ worst case | $\Theta(n)$ worst case |
| Insert at the front | $\Theta(n)$ worst case | $\Theta(1)$ worst case | $\Theta(1)$ worst case |
| Insert at the end | $\Theta(1)$ amortized under geometric growth; $\Theta(n)$ worst case on a resize | $\Theta(1)$ worst case | $\Theta(1)$ worst case |
| Insert at a known position | $\Theta(n)$ worst case: the index is known and the later elements move | $\Theta(1)$ worst case: `insertAfter` the held node | $\Theta(1)$ worst case: insert or delete at the held node |
| Scan $n$ elements | $\Theta(n)$ worst case | $\Theta(n)$ worst case | $\Theta(n)$ worst case |
| Extra memory | Unused capacity, $0$ when size equals capacity and $\Theta(n)$ just after a geometric expansion | $\Theta(n)$ `next` references, plus the list fields | $\Theta(n)$ `prev` and $\Theta(n)$ `next` references; two extra nodes if sentinels are used |
| Locality | Successive elements differ by one stride | Successor address is the contents of `next`, not a stride | Same as the singly linked list |

The locality row is not a RAM-model timing. Scans remain $\Theta(n)$ in that model on all three structures.

17. `popBack` is $\Theta(n)$ in the worst case. For $n \ge 2$ the exact number of `next` reads is $n - 1$. For $n = 9$ that is $9 - 1 = 8$.

## 18.5 Invariants

18. `size` is a non-negative integer equal to the number of nodes reachable from `head` by `next`. If `size` is $0$, then `head` and `tail` are both `null`. If `size` is at least $1$, then `tail.next` is `null` and `tail` is the only node on the chain whose `next` is `null`. Following `next` from `head` visits `size` distinct nodes and then `null`; the non-circular list has no cycle.

19. (a) `size` does not equal the number of nodes on the chain: the chain has $3$ nodes and `size` is $4$. (b) The non-circular list contains a cycle, so the walk does not reach `null` after `size` distinct nodes, and there is no tail whose `next` is `null`. (c) The pair disagrees: `u_{20}.next` is $u_{30}$ requires `u_{30}.prev` to be $u_{20}$, and it is $u_{10}$ instead. (d) The one-node circular invariant requires `head.next` to be `head`. A `null` `next` is the non-circular one-node picture.

## 18.6 Find the bug

20. After `node.next = created`, the node holding $20$ refers to the new node holding $25$, and the walk from `head` can reach $10$, $20$, and $25$. The original nodes holding $30$ and $40$ are unreachable from `head`. Those are the lost nodes. Their elements are $30$ and $40$. The node holding $30$ still refers to the node holding $40$ if nothing else cleared it, but that chain is not reachable from `head`. The assignment `created.next = node.next` then reads the `next` that was just overwritten, so it reads the new node itself and writes a one-node cycle: $25$ points at $25$. A walk from `head` is $10, 20$, then $25$ forever. The repair writes `created.next = node.next` before `node.next = created`.

## 18.7 Reverse and quantitative checks

21. At $k = 0$, `previous` is empty and `current` is $10 \to 20 \to 30 \to 40 \to \mathrm{null}$. At $k = 1$, `previous` is $10 \to \mathrm{null}$ and `current` is $20 \to 30 \to 40 \to \mathrm{null}$. At $k = 2$, `previous` is $20 \to 10 \to \mathrm{null}$ and `current` is $30 \to 40 \to \mathrm{null}$. At $k = 3$, `previous` is $30 \to 20 \to 10 \to \mathrm{null}$ and `current` is $40 \to \mathrm{null}$. After the loop, `head` names $40$ and `tail` names $10$. The sequence is $40, 30, 20, 10$, and `size` is $4$. The worst-case time is $\Theta(n)$, here $4$ iterations of $\Theta(1)$ work. The extra memory is $\Theta(1)$ references: `previous`, `current`, `following`, and the saved original head. No new node is allocated.

22. $k$ is the number of nodes already moved onto the reversed chain. At the start of each test of the loop condition, `current` is $x_k$ or `null` when $k = n$; `previous` is $x_{k-1}$ or `null` when $k = 0$; the chain from `previous` is the reversed prefix $x_{k-1}, \ldots, x_0$; the chain from `current` is the untouched suffix; the two chains partition the nodes; `size`, `head`, and `tail` still have their original values.

23. Two sentinels plus six real nodes is $2 + 6 = 8$ node objects. `size` is $6$, because a sentinel is not an element. The forward audit follows `next` once per step from the head sentinel to the tail sentinel, which is `size + 1 = 7` follows.

24. `get(5)` follows `next` $5$ times: from index $0$ to index $5$ is five hops, and the element is then read. A search for a missing value examines all $n$ nodes in the worst case, which is also the only case, because absence is known only at `null` after the last node.

---

# 19. Independent assignment

Budget about four hours. The artifact is one JavaScript file, `circular-cursor.js`, with no imports except `node:assert/strict`. It must run under `node` and print `ALL TESTS PASSED`.

Build a circular singly linked list with `head`, `cursor`, and `size`, using the representation in Section 9. Implement `addFirst`, `insertAfter`, `deleteAfter`, `advance`, and `rotate`. `deleteAfter` on a circle must handle three situations correctly: more than two nodes, exactly two nodes, and exactly one node. Deleting the only node returns the list to `head = null`, `cursor = null`, and `size = 0`. Deleting the node that `head` or `cursor` names must move that external reference to the surviving successor before the deleted node is unlinked. Keep a one-node circle as a self-loop until that deletion, not as a node whose `next` is `null`.

Implement `audit`. It checks the four circular invariant conditions of Section 12.3, and it checks that a non-null cursor refers to a node on the circle. Call `audit` after every public operation in the tests.

The tests must use the elements $10, 20, 30, 40$ at least once. Include: the empty picture; the one-node picture after `addFirst(10)`, including `head.next === head`; the circle $10, 20, 30$ and the sequence $20, 30, 10$ after one `rotate`; a cursor that advances `size` times and returns to its start node; `deleteAfter` that removes $30$ from $10, 20, 30, 40$ and leaves a circle of the remaining three; deletion of the final remaining node. Assert `size` and the sequence after each of those operations.

At the top of the file, in comments, write a short argument of about $500$ words that does all of the following. State the circular invariant in your own sentences. Show, with the formula $n - 1$, why singly linked `popBack` with a tail is $\Theta(n)$ for $n \ge 2$, using $n = 4$ as the arithmetic check. State one operation mix for which the dynamic array of Lecture 02 is the better structure, and one operation mix for which a linked list is the better structure, using only costs proved in that lecture and in this one. Do not implement a queue, a deque, or a skip list. Do not import a list from the language library.

---

# 20. Glossary

**Advance.** The assignment `cursor = cursor.next` on a circular list.

**Circular singly linked list.** A list whose last node's `next` refers to the first node, with a single external `head`. The empty state has no node.

**Cursor.** An external reference to one node of a circular list, used to mark the current position of a repeating scan.

**Doubly linked list.** A list whose nodes each store `next` and `prev`.

**Element.** The value stored in a real node. It is not the node itself, and it is not a sentinel.

**Head.** The external reference to the first node of a non-sentinel list, or the first real node's predecessor when that predecessor is a sentinel. Empty non-sentinel lists store `null`.

**In place.** Using only a constant amount of extra memory and rewriting the existing nodes, rather than allocating a second chain of $n$ nodes.

**Invariant.** A predicate on the representation that holds after construction and after every public operation returns.

**Known node.** A reference, already held by the caller, to a node that is currently in the list. Costs quoted for a known node do not include a search for it.

**Link.** A field that stores a node reference or `null`. In this lecture the link fields are `next` and `prev`.

**Locality.** The relationship between the addresses of successively visited elements. Contiguous slots differ by a stride. Linked successors sit at whatever address `next` holds.

**Loop invariant.** A predicate that holds every time a loop tests its condition, used to prove that the state after the loop is the intended one.

**Node.** A record holding one element and one or more links. Sentinel nodes are records of the same kind that do not hold list elements.

**Null.** The reference value that means a link is absent. It is not a node and not an element.

**Predecessor.** The node $p$ such that `p.next` is the node in question. On a doubly linked node it is also the node stored in `prev`, when the pair agrees.

**Predecessor problem.** The need, on a singly linked list, to obtain $p$ by a walk before a splice can change `p.next`, when the caller holds the successor and does not hold $p$.

**Rotate.** The assignment `head = head.next` on a non-empty circular list. It rewrites no node field.

**Sentinel.** A dummy node that is part of the representation, is not an element, and is not counted by `size`.

**Singly linked list.** A list whose nodes store `next` and do not store `prev`.

**Size.** The number of elements, which is the number of real nodes. Sentinels are excluded.

**Splice.** A constant-length sequence of reference assignments that attaches or detaches a node through references already in hand.

**Tail.** The external reference to the last real node of a non-circular non-sentinel list, or to the sentinel when a singly linked sentinel list is empty. On a non-circular list of real nodes, `tail.next` is `null`.

**Walk.** Following `next` or `prev` from an entry node until a target is reached or the search ends.

---

# 21. Lecture summary

A link exists so that a splice at a node the caller already holds can insert or delete without moving the other elements and without walking from the head. The walk that finds the node is a separate cost. On the singly linked list with `head`, `tail`, and `size`, `pushFront`, `popFront`, `pushBack`, `insertAfter`, and `deleteAfter` are $\Theta(1)$ in the worst case, `get(i)` is $\Theta(i)$, `find` is $\Theta(n)$ in the worst case, and `popBack` reads `next` exactly $n - 1$ times whenever $n \ge 2$. The tail names the last node and does not name its predecessor.

Storing `prev` makes `deleteNode` on a held node, `pushBack`, and `popBack` $\Theta(1)$ in the worst case. It leaves index access at $\Theta(n)$. A circular list uses one `head`, points the last node at the first, and represents emptiness by `null` and the one-node list by a self-loop. A cursor advances in $\Theta(1)$. A sentinel is not an element. A sentinel head, and a sentinel head together with a sentinel tail, give the end slots a node to write, so the empty branch disappears from the splice even though emptiness remains a representable state and `size` still ignores the sentinels.

Against the dynamic array, the list wins constant-time splices at held nodes and constant-time insertion at the front. The array wins constant-time index access and contiguous locality. Both scan in $\Theta(n)$ in the RAM model. The representation is correct only while `size` matches the real nodes, paired links agree, a non-circular chain is acyclic, and the non-circular tail's `next` is `null`. Reverse rewrites `next` in one $\Theta(n)$ pass under a prefix/suffix invariant. The bug that writes `node.next` before saving it loses the suffix; on the running insert of $25$ after $20$, the lost elements are $30$ and $40$.

## Five principles

1. Quote the walk and the splice as separate bounds, and add them only when the call performs both.
2. A singly linked node can name its successor. The predecessor is either held by the caller, stored in `head`, or found by a walk.
3. A tail reference supports `pushBack` in $\Theta(1)$ and leaves singly linked `popBack` at $n - 1$ link reads for $n \ge 2$.
4. A sentinel occupies a node object and is excluded from `size`. It exists so the splice at an end uses the same assignments as a splice in the middle.
5. Save every reference you still need, then overwrite the field. The order is part of the correctness argument, not a style choice.

---

# 22. References

1. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapter 10, Section 10.2. Linked lists, deletion given a node on a doubly linked list, and sentinel nodes.

2. Michael T. Goodrich, Roberto Tamassia, and Michael H. Goldwasser. *Data Structures and Algorithms in Java*. 6th edition. Wiley, 2014. Chapter 3, Sections 3.2 through 3.4. Singly linked lists, the cost of removing at the tail, circularly linked lists, and doubly linked lists.

3. Donald E. Knuth. *The Art of Computer Programming, Volume 1: Fundamental Algorithms*. 3rd edition. Addison-Wesley, 1997. Sections 2.2.3 through 2.2.5. Linked allocation, circular lists, and doubly linked lists.
