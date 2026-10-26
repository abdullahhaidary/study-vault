# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 04 — STACKS, QUEUES, AND DEQUES

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 04 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 8 hours
**Prerequisites:** Lecture 01 — Models, ADTs, and Asymptotic Analysis; Lecture 02 — Arrays, Dynamic Arrays, and Amortized Analysis; Lecture 03 — Linked Lists
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapters 10 and 17; Sedgewick and Wayne, *Algorithms*, 4th edition, Section 1.3; Goodrich, Tamassia, and Goldwasser, *Data Structures and Algorithms in Java*, 6th edition, Chapter 6; Dijkstra, *ALGOL 60 Translation*, Mathematisch Centrum, 1961

**This lecture owns:** the stack, queue, and deque abstract data types; their array and linked implementations; the circular buffer; and the shunting-yard algorithm.
**This lecture does not teach:** breadth-first search, depth-first search, or recursion as a topic. The call stack and the existence of a breadth-first queue are named and then left to Lectures 05 and 12.

---

## Learning objectives

After this lecture you should be able to do the following.

1. State the stack, queue, and deque specifications, including the order each one preserves and the access each one refuses.
2. Implement a stack on a dynamic array and on a singly linked list, and give the cost of `push`, `pop`, and `top` in each representation.
3. Draw the call-stack frames of one nested call, labeling the return address, the parameters, and the locals.
4. Show that a queue which removes the element at index $0$ spends $\Theta(n)$ time on that removal, and implement both honest repairs: a linked queue with head and tail, and a circular buffer.
5. Execute a circular-buffer trace through three wraps, check the modular invariant, and re-index the live elements when the buffer doubles.
6. Implement a growing circular deque and state the cost of each end operation for that representation and for a doubly linked deque.
7. Decide whether a string over `()[]{}` is balanced, name the failure when it is not, and justify the decision by the stack invariant.
8. Convert an infix expression to postfix with Dijkstra's shunting-yard algorithm and evaluate the postfix on a second stack, including precedence, left associativity, and parentheses.
9. Implement a queue with two stacks and prove, by the aggregate method, that `dequeue` has amortized cost $\Theta(1)$ and worst-case cost $\Theta(n)$.
10. Name two operation mixes for which a stack, queue, or deque is the wrong structure.

---

## Purpose

A stack, a queue, and a deque are small abstract data types. Each one supports insertion and removal at an end, and each one refuses everything else. The lecture separates that contract from the memory layout that meets it. The same stack contract is met by the end of a dynamic array and by the head of a singly linked list. The same queue contract is met by a linked list with two external pointers and by a circular buffer. The costs differ, and the difference is the reason to choose one layout.

Two applications use the stack as the whole algorithm. Balanced brackets are the pattern "the most recently opened thing is the only thing that may close." Shunting-yard is the pattern "an operator waits until a later operator of lower or equal precedence forces it out." Postfix evaluation is a second stack, of numbers rather than operators. A queue built from two stacks is the pattern that turns a worst-case linear move into an amortized constant, by the aggregate method of Lecture 02.

The lecture stops at those structures. A breadth-first traversal stores vertices in a queue, and a depth-first traversal stores vertices in a stack. Both traversals are Lecture 12. A recursive procedure pushes a frame on every call. Recursion as a method of definition and proof is Lecture 05. Dijkstra's shortest-path algorithm is Lecture 13. The shunting-yard algorithm in Part 9 is a different algorithm by the same author.

---

## Part 1. The contract, then the representation

Lecture 01 separated an abstract data type from any implementation. The abstract data type names the values, the operations, and the behavior of those operations. An implementation chooses a representation and must make every operation obey that behavior. Cost belongs to the implementation. Two correct implementations of one contract may have different costs, and the contract remains the same.

### The stack

A stack is a finite sequence together with these operations.

| Operation | Behavior |
| --- | --- |
| `push(x)` | Place $x$ at the top. $x$ becomes the most recently inserted element. |
| `pop()` | Remove the top element and return it. |
| `top()` | Return the top element and leave the stack unchanged. |
| `isEmpty()` | Return whether the stack contains no elements. |

`pop` and `top` on an empty stack are errors. This lecture calls that error **underflow**. The element domain may include `null`, so an empty stack must not signal emptiness by returning `null`. Emptiness is the Boolean from `isEmpty`.

The order is **last-in, first-out**. If the pushes in time order are $x_1, x_2, \ldots, x_k$ and nothing has been popped, the pops return $x_k, x_{k-1}, \ldots, x_1$. A later `push` sits above the elements that are still present. An element buried under another element cannot be read or removed until the elements above it have been popped.

The contract does not provide an operation "return the element at position $i$," an operation "search for this value," or an operation "remove the oldest element." A client that needs those operations does not have a stack problem.

Our implementations also expose `size()`, because they already store a count or a length. `size` is an observer. It is not required to state the last-in, first-out rule.

### The queue

A queue is a finite sequence together with these operations.

| Operation | Behavior |
| --- | --- |
| `enqueue(x)` | Place $x$ at the back. $x$ becomes the newest element. |
| `dequeue()` | Remove the front element and return it. The front is the oldest element still present. |
| `front()` | Return the front element and leave the queue unchanged. |
| `isEmpty()` | Return whether the queue contains no elements. |

`dequeue` and `front` on an empty queue raise underflow. The order is **first-in, first-out**. Enqueue order $x_1, x_2, \ldots, x_k$ on an empty queue produces dequeue order $x_1, x_2, \ldots, x_k$. The client can see and remove only the front. The back is where new elements arrive. There is no contract operation that reads the back, removes the newest element, or jumps to the middle.

### The deque

A **deque** (double-ended queue) is a finite sequence with insertion and removal at both ends.

| Operation | Behavior |
| --- | --- |
| `addFront(x)` | Insert $x$ at the front. $x$ becomes the new oldest-end element. |
| `addBack(x)` | Insert $x$ at the back. |
| `removeFront()` | Remove and return the front element. |
| `removeBack()` | Remove and return the back element. |
| `front()` | Return the front element. |
| `back()` | Return the back element. |
| `isEmpty()` | Return whether the deque contains no elements. |

Removal or inspection of an empty end raises underflow. Other books say `insertFirst`, `insertLast`, `deleteFirst`, and `deleteLast` for the same four updates. This lecture uses `addFront`, `addBack`, `removeFront`, and `removeBack` only.

A deque still has no index operation and no search. It is a stack if the client uses only one end. It is a queue if the client adds at the back and removes at the front. The extra contract is the permission to use both ends.

### What the three contracts refuse

All three contracts are end-only. After a sequence of updates, the client of a stack can name one element, the top. The client of a queue can name one element, the front. The client of a deque can name two elements, the front and the back. An element in the interior is real data, and it is unreachable until removals bring it to an accessible end. Part 11 records the designs that need the interior or a key.

A fixed-capacity implementation may also raise **overflow** when an insertion would exceed that capacity. Overflow is a property of a bounded representation. It is not part of the mathematical sequence. The growing implementations in this lecture replace overflow by allocating a larger buffer.

---

## Part 2. Two implementations of a stack

The stack contract says that every update touches the top. The representation should make the top the cheap end.

### A stack at the end of a dynamic array

Lecture 02 represents a dynamic array by a contiguous block and a length. Appending one element is $\Theta(1)$ amortized and $\Theta(n)$ in the worst case, because a full block is copied into a block of double the capacity. Removing the last element is $\Theta(1)$ in the worst case. Reading the last element is $\Theta(1)$.

A JavaScript array provides that dynamic-array contract. Engine layouts differ; the costs used here are the costs proved for the dynamic array in Lecture 02, not a measurement of one engine.

Place the top at the last occupied index. `push` appends. `pop` removes the last element. `top` reads it.

```javascript
class ArrayStack {
  constructor() {
    this.data = [];
  }

  push(value) {
    this.data.push(value);
  }

  pop() {
    if (this.data.length === 0) {
      throw new Error("stack underflow");
    }
    return this.data.pop();
  }

  top() {
    if (this.data.length === 0) {
      throw new Error("stack underflow");
    }
    return this.data[this.data.length - 1];
  }

  isEmpty() {
    return this.data.length === 0;
  }

  size() {
    return this.data.length;
  }
}
```

**Invariant.** If `data` holds $s_0, s_1, \ldots, s_{m-1}$, then $s_{m-1}$ is the top and $s_0$ is the oldest element still stored. `pop` returns $s_{m-1}$ and leaves $s_0, \ldots, s_{m-2}$.

**Costs.** `top`, `isEmpty`, `size`, and `pop` are $\Theta(1)$ worst case. `push` is $\Theta(1)$ amortized and $\Theta(n)$ worst case, by the geometric-growth argument of Lecture 02. Space is $\Theta(n)$ array slots after growth, with the same spare capacity a dynamic array keeps.

Trace of `push(1)`, `push(2)`, `push(3)`:

```text
index:   0   1   2
data:  [ 1,  2,  3 ]
                  ^
                 top
```

`pop` returns $3$, then $2$, then $1$. The next `pop` or `top` raises stack underflow. The laboratory runs this trace on `ArrayStack`.

Placing the top at index $0$ would make `push` and `pop` shift every element. Each of those operations would be $\Theta(n)$. The end is the top because the end is the cheap side of an array.

### A stack at the head of a singly linked list

Lecture 03 gives a singly linked list: each node stores a value and a `next` link, and the missing successor is `null`. Inserting or deleting at the head rewrites one link and is $\Theta(1)$ worst case. Reaching the tail, or deleting the tail, walks the chain and is $\Theta(n)$ unless extra structure is added. A singly linked list has no pointer to the predecessor of the tail, so deleting the tail is $\Theta(n)$ even if a tail pointer is stored.

The top is therefore the head. `push` inserts a new head. `pop` removes the head. `top` reads the head.

```javascript
class SinglyNode {
  constructor(value, next) {
    this.value = value;
    this.next = next;
  }
}

class LinkedStack {
  constructor() {
    this.head = null;
    this.count = 0;
  }

  push(value) {
    this.head = new SinglyNode(value, this.head);
    this.count += 1;
  }

  pop() {
    if (this.head === null) {
      throw new Error("stack underflow");
    }
    const value = this.head.value;
    this.head = this.head.next;
    this.count -= 1;
    return value;
  }

  top() {
    if (this.head === null) {
      throw new Error("stack underflow");
    }
    return this.head.value;
  }

  isEmpty() {
    return this.head === null;
  }

  size() {
    return this.count;
  }
}
```

**Invariant.** `head === null` exactly when the stack is empty. When the stack is nonempty, `head.value` is the top, and following `next` walks from the newest remaining element toward the oldest. `count` equals the number of nodes reachable from `head`.

After `push(1)`, `push(2)`, `push(3)`:

```text
head / top
  |
  v
+---+----+     +---+----+     +---+------+
| 3 |  *-+---->| 2 |  *-+---->| 1 | null |
+---+----+     +---+----+     +---+------+
```

`pop` returns $3$ and moves `head` to the node that holds $2$. The node that held $3$ is no longer linked. The observable sequence of pops is again $3, 2, 1$, the same sequence the array stack produces. The laboratory checks both objects on that sequence.

**Costs.** `push`, `pop`, `top`, `isEmpty`, and `size` are $\Theta(1)$ worst case. There is no resizing copy. Each element costs one node: a value and one link. The array stack has better locality because successive elements occupy successive indexes. The linked stack has a tighter worst-case bound on `push`. Both are correct stacks.

The tail is the wrong top. A pop at the tail of this list must find the predecessor, which takes $\Theta(n)$ time. Keeping a tail pointer does not remove that walk.

---

## Part 3. The call stack is a stack of frames

A running program keeps a stack of **frames**, one for each function call that has started and has not returned. The frame of the current function is the top. A call pushes a frame. A return pops it. This is the ordinary stack contract, with a particular kind of element.

A frame stores three kinds of information.

- The **return address**: where execution continues in the caller after this call returns.
- The **parameters**: the arguments the caller passed.
- The **locals**: variables allocated for this call.

The return value travels back to the caller as the frame is popped. The picture below draws the top frame toward the bottom of the page so that a push moves downward on the paper. That direction is a drawing choice. A machine may place successive frames at increasing or decreasing addresses. The abstract fact is the push and pop order.

Consider this nested call. It is one call inside another call. It is not a recursive algorithm; recursion is Lecture 05.

```javascript
function total(x, y) {
  const sum = x + y;
  return sum;
}

function report() {
  const value = total(2, 5);
  return value;
}
```

Walk the stack.

1. The caller of `report` pushes the `report` frame. Its return address is the continuation of that caller. Its local `value` is not yet assigned.
2. `report` calls `total(2, 5)`. The call pushes the `total` frame. Its return address is the assignment to `value` inside `report`. Its parameters are $x = 2$ and $y = 5$. Its local `sum` is about to be computed.
3. `total` sets `sum = 7`. This is the deepest moment. Both frames are live, and the `total` frame is the top.

```text
+------------------------------------------+
| report                                   |
|   return address: continuation of caller |
|   local value: not yet assigned          |
+------------------------------------------+
| total                          <-- top   |
|   return address: assignment to value    |
|   parameters: x = 2, y = 5               |
|   local sum = 7                          |
+------------------------------------------+
```

4. `return sum` hands $7$ to the caller and pops the `total` frame. Execution resumes at the return address, so `value` becomes $7$.
5. `report` returns $7$ and pops its own frame.

The frame that returns is the frame that was pushed last. That is last-in, first-out. A recursive function would push several frames whose code is the same function; the mechanism on this page is the mechanism it would use, and the subject of recursion remains Lecture 05.

Depth-first search uses a stack of vertices. Often that stack is this call stack. Breadth-first search uses a queue of vertices. Both searches are Lecture 12. This lecture does not describe their vertex rules.

---

## Part 4. The queue, and the cost of removing at index 0

A queue touches two ends: removal at the front, insertion at the back. A representation is honest when both ends are cheap.

### The naive array

Store the queue in a dynamic array with the front fixed at index $0$ and the back at the last occupied index. `enqueue` appends, which is $\Theta(1)$ amortized. `dequeue` removes index $0$.

Every element after index $0$ must move one slot toward the front. If the array currently holds $k$ elements, that move writes $k - 1$ entries. The cost of this `dequeue` is $\Theta(k)$.

Take the sequence of $n$ enqueues followed by $n$ dequeues, starting from empty, and count only the element moves inside `dequeue`. The first dequeue moves $n - 1$ elements, the next moves $n - 2$, and the last moves $0$.

$$
\sum_{k=0}^{n-1} k = \frac{(n-1)n}{2}
$$

That sum is $\Theta(n^2)$. The $n$ appends do not cancel the quadratic term. For $n = 6$ the move count is $5 + 4 + 3 + 2 + 1 + 0 = 15$, and $(5 \cdot 6) / 2 = 15$.

The behavior can still be first-in, first-out. The implementation is the wrong tool when the client needs a queue whose updates stay constant. JavaScript's `Array.prototype.shift` is this removal: it is a correct way to delete index $0$ and a poor way to dequeue.

### A singly linked queue with head and tail

Keep the front at the head and the back at the tail. `dequeue` unlinks the head, which is $\Theta(1)$. `enqueue` attaches a node after the tail and moves the tail, which is $\Theta(1)$, because the tail pointer removes the walk. Dequeue at the tail would again require the predecessor, so the oldest element must be the head and the newest element must be the tail.

```javascript
class LinkedQueue {
  constructor() {
    this.head = null;
    this.tail = null;
    this.count = 0;
  }

  enqueue(value) {
    const node = new SinglyNode(value, null);
    if (this.tail === null) {
      this.head = node;
      this.tail = node;
    } else {
      this.tail.next = node;
      this.tail = node;
    }
    this.count += 1;
  }

  dequeue() {
    if (this.head === null) {
      throw new Error("queue underflow");
    }
    const value = this.head.value;
    this.head = this.head.next;
    if (this.head === null) {
      this.tail = null;
    }
    this.count -= 1;
    return value;
  }

  front() {
    if (this.head === null) {
      throw new Error("queue underflow");
    }
    return this.head.value;
  }

  isEmpty() {
    return this.head === null;
  }

  size() {
    return this.count;
  }
}
```

**Invariant.** `head === null` if and only if `tail === null`, and both are null if and only if the queue is empty. When the queue is nonempty, `head.value` is the oldest element, `tail.value` is the newest, `tail.next === null`, and following `next` from `head` visits the elements from oldest to newest. `count` is the length of that chain.

The empty case of `dequeue` sets `tail` back to `null` when the removed node was the last node. If `tail` kept pointing at the unlinked node, the next `enqueue` would write `next` on a node that `head` no longer reaches, and the new element would be lost.

Trace, which the laboratory repeats.

```text
enqueue 10, 20, 30

head                              tail
  |                                 |
  v                                 v
+----+----+   +----+----+   +----+------+
| 10 |  *-+-->| 20 |  *-+-->| 30 | null |
+----+----+   +----+----+   +----+------+
```

`front` is $10$. `dequeue` returns $10$ and moves `head` to $20$. `enqueue(40)` attaches $40$ after $30$ and moves `tail` to $40$. The following dequeues return $20$, then $30$, then $40$. The structure is empty: `head` and `tail` are both `null`, and a further `dequeue` raises queue underflow. A later `enqueue(7)` is legal, `front` is $7$, and `dequeue` returns $7$.

**Costs.** `enqueue`, `dequeue`, `front`, `isEmpty`, and `size` are $\Theta(1)$ worst case. Space is one node per element, each node a value and one link.

The linked queue already solves the $\Theta(n)$ dequeue. The circular buffer is the array solution of the same problem. It keeps elements in a contiguous block, which the linked queue does not.

---

## Part 5. The circular buffer

The naive array is slow because `dequeue` moves elements. The circular buffer moves an index instead. The elements stay in their slots until a later enqueue overwrites a slot that is no longer live.

### Fixed capacity and the size counter

A circular buffer of capacity $C \geq 1$ is an array `data[0..C-1]`, an integer `frontIndex` in $\{0, 1, \ldots, C-1\}$, and an integer `count` with $0 \leq \mathrm{count} \leq C$. The lecture calls `count` the **size**. Capacity is fixed until Part 5's growth step. While the size equals the capacity, another enqueue raises overflow.

The live elements occupy `count` slots, starting at `frontIndex` and continuing in increasing index, wrapping to $0$ after $C-1$. Rank $0$ is the oldest element. Rank $\mathrm{count}-1$ is the newest.

$$
\mathrm{data}[(\mathrm{frontIndex} + i) \bmod C] = q_i
\qquad \text{for } 0 \leq i < \mathrm{count}
$$

The **back index** is the first slot after the newest element. It is the slot where the next enqueue writes.

$$
\mathrm{backIndex} = (\mathrm{frontIndex} + \mathrm{count}) \bmod C
$$

The mathematical remainder is the representative in $\{0, 1, \ldots, C-1\}$.

**Invariant I.** The `count` elements that begin at `frontIndex` and proceed in modular order are the queue from oldest to newest. Slots outside that set are unconstrained. A value left behind by `dequeue` is **stale**. It is not in the queue. The implementation in this lecture does not erase it, so a diagram can show the physical memory. Erasing it would also satisfy I. Correctness reads only the live residues.

**Theorem (free back slot).** If $\mathrm{count} < C$, the back index is not the index of any live element.

**Proof.** Suppose $(\mathrm{frontIndex} + \mathrm{count}) \equiv (\mathrm{frontIndex} + i) \pmod{C}$ for some $i$ with $0 \leq i < \mathrm{count}$. Then $\mathrm{count} \equiv i \pmod{C}$. Both integers lie in $\{0, 1, \ldots, C-1\}$ and $i < \mathrm{count}$, so they cannot be congruent. The back slot is free. If $\mathrm{count} = C$, every residue is live, and there is no free slot. That is the overflow condition.

`enqueue(x)` when the buffer is not full writes $x$ at the back index and increments `count`. `dequeue` reads `data[frontIndex]`, sets

$$
\mathrm{frontIndex} \leftarrow (\mathrm{frontIndex} + 1) \bmod C
$$

and decrements `count`. `front` reads `data[frontIndex]` and changes nothing.

**Theorem (circular queue).** Initialization and every `enqueue`, `dequeue`, and `front` restore I. `enqueue(x)` appends $x$. `dequeue` removes the oldest element. `front` returns the oldest element. Empty `dequeue` and empty `front` raise underflow and do not change the state.

**Proof.** Initialization uses `count = 0` and `frontIndex = 0`. The range of ranks is empty, so I holds for the empty sequence.

Consider `enqueue(x)` with $\mathrm{count} < C$. The free-slot theorem says the write at the back index does not replace any $q_i$. After the increment, the old ranks $0, \ldots, \mathrm{count}-1$ are unchanged and the new last rank holds $x$. The new sequence is the old sequence followed by $x$.

Consider `dequeue` with $\mathrm{count} > 0$. The value read is $q_0$. For each new rank $i$ with $0 \leq i < \mathrm{count}-1$,

$$
(\mathrm{frontIndex}' + i) \equiv (\mathrm{frontIndex} + 1 + i) \pmod{C}
$$

so the slot holds the old $q_{i+1}$. The new sequence is $q_1, \ldots, q_{\mathrm{count}-1}$.

`front` returns $q_0$ because I says rank $0$ sits at `frontIndex`.

### Three wraps, with the numbers the laboratory checks

Capacity $C = 4$. Empty slots are written `_`. Stale slots keep the number that used to be live. The logical queue is oldest to newest.

Start: `frontIndex = 0`, `count = 0`, physical buffer `[_ _, _, _]`.

Enqueue $10, 20, 30, 40$. No index has wrapped. The buffer is full.

```text
index:        0    1    2    3
            +----+----+----+----+
value:      | 10 | 20 | 30 | 40 |
            +----+----+----+----+
              ^
           frontIndex = 0, count = 4
logical: 10, 20, 30, 40
```

`dequeue` returns $10$. `dequeue` returns $20$. `frontIndex` is now $2$. The numbers $10$ and $20$ are stale.

```text
index:        0    1    2    3
            +----+----+----+----+
value:      | 10 | 20 | 30 | 40 |
            +----+----+----+----+
              stale stale ^
                     frontIndex = 2, count = 2
logical: 30, 40
```

**Wrap 1.** Enqueue $50$. The back index is $(2 + 2) \bmod 4 = 0$. The write lands in slot $0$, which is past the last index and back at the beginning.

```text
index:        0    1    2    3
            +----+----+----+----+
value:      | 50 | 20 | 30 | 40 |
            +----+----+----+----+
              ^    stale  ^
              |           frontIndex = 2
              write of 50
count = 3
logical: 30, 40, 50
```

**Wrap 2.** Enqueue $60$. The back index is $(2 + 3) \bmod 4 = 1$. The buffer is full again, and both newest elements sit to the left of the front.

```text
index:        0    1    2    3
            +----+----+----+----+
value:      | 50 | 60 | 30 | 40 |
            +----+----+----+----+
                        ^
                     frontIndex = 2, count = 4
logical: 30, 40, 50, 60
```

Check I on this picture. Rank $0$ is index $2$, value $30$. Rank $1$ is index $3$, value $40$. Rank $2$ is index $0$, value $50$. Rank $3$ is index $1$, value $60$. That is the logical queue.

**Wrap 3.** `dequeue` returns $30$ and sets `frontIndex` to $3$. `dequeue` returns $40$ and sets `frontIndex` to $(3 + 1) \bmod 4 = 0$. The front index itself has wrapped.

```text
index:        0    1    2    3
            +----+----+----+----+
value:      | 50 | 60 | 30 | 40 |
            +----+----+----+----+
              ^         stale stale
           frontIndex = 0, count = 2
logical: 50, 60
```

`front` is $50$. The laboratory asserts the physical buffer, the front index, the size, and the logical contents at each of these pictures.

### Growth doubles, then re-indexes in order

A growing circular queue uses the same formulas. When `enqueue` finds `count === capacity`, it grows before the write. The new capacity is twice the old capacity. The copy writes the live elements in logical order into indexes $0, 1, \ldots, \mathrm{count}-1$ of a new array, then sets `frontIndex` to $0$.

$$
\mathrm{next}[i] = \mathrm{data}[(\mathrm{frontIndex} + i) \bmod C]
\qquad \text{for } 0 \leq i < \mathrm{count}
$$

**Lemma (re-index).** After this copy, I holds for the same sequence with front index $0$ and the new capacity. The size is unchanged and is strictly less than the new capacity, because the old size equalled the old capacity and the new capacity is twice that.

The ordinary enqueue case then writes into a free back slot.

Continue from the full wrapped state of wrap 2, before the two dequeues that moved the front: physical buffer $[50, 60, 30, 40]$, `frontIndex = 2`, `count = 4`. Enqueue $70$ grows first.

| New index $i$ | Source index $(2+i) \bmod 4$ | Value |
| --- | --- | --- |
| $0$ | $2$ | $30$ |
| $1$ | $3$ | $40$ |
| $2$ | $0$ | $50$ |
| $3$ | $1$ | $60$ |

```text
index:     0    1    2    3    4   5   6   7
         +----+----+----+----+---+---+---+---+
value:   | 30 | 40 | 50 | 60 | _ | _ | _ | _ |
         +----+----+----+----+---+---+---+---+
           ^
        frontIndex = 0, count = 4, capacity = 8
```

The write of $70$ uses back index $(0 + 4) \bmod 8 = 4$.

```text
index:     0    1    2    3    4   5   6   7
         +----+----+----+----+----+---+---+---+
value:   | 30 | 40 | 50 | 60 | 70 | _ | _ | _ |
         +----+----+----+----+----+---+---+---+
           ^
        frontIndex = 0, count = 5, capacity = 8
logical: 30, 40, 50, 60, 70
```

The next `dequeue` returns $30$. The laboratory checks this grown state, including the five occupied slots.

**Theorem (growth preserves the queue).** The growing `enqueue` restores I and appends the new element.

**Proof.** If `count < capacity`, the fixed-capacity enqueue case applies. If `count === capacity`, the re-index lemma restores I with room to spare, and the fixed-capacity enqueue case then appends the element.

**Costs.** `dequeue`, `front`, `isEmpty`, and `size` are $\Theta(1)$ worst case. They never allocate. `enqueue` is $\Theta(1)$ worst case when no growth occurs, and $\Theta(n)$ worst case when it copies $n$ live elements. The copy sizes are $C, 2C, 4C, \ldots$ at the moments of growth. Over a sequence of $n$ enqueues from an empty buffer, each element is copied once per growth that occurs while it is live, and the geometric series of Lecture 02 bounds the total copying by less than $2n$ element writes. The aggregate method therefore gives $\Theta(1)$ amortized cost for `enqueue`. The modular index updates are $\Theta(1)$ arithmetic. They do not change the geometric sum.

Space after growth satisfies $n \leq \mathrm{capacity} < 2n$ once the buffer has grown at least once and before the next growth, up to the off-by-one that appears in the instant after a doubling: immediately after the copy, capacity is $2n$ and the following write makes the size $n+1$. The spare space is the same order as the dynamic array of Lecture 02.

A capacity that is not a positive integer is rejected. Capacity $0$ has no legal index.

```javascript
class CircularQueue {
  constructor(capacity = 4) {
    if (!Number.isInteger(capacity) || capacity < 1) {
      throw new Error("capacity must be a positive integer");
    }
    this.data = new Array(capacity);
    this.capacity = capacity;
    this.frontIndex = 0;
    this.count = 0;
  }

  size() {
    return this.count;
  }

  isEmpty() {
    return this.count === 0;
  }

  enqueue(value) {
    if (this.count === this.capacity) {
      this.grow();
    }
    const backIndex = (this.frontIndex + this.count) % this.capacity;
    this.data[backIndex] = value;
    this.count += 1;
  }

  dequeue() {
    if (this.count === 0) {
      throw new Error("queue underflow");
    }
    const value = this.data[this.frontIndex];
    this.frontIndex = (this.frontIndex + 1) % this.capacity;
    this.count -= 1;
    return value;
  }

  front() {
    if (this.count === 0) {
      throw new Error("queue underflow");
    }
    return this.data[this.frontIndex];
  }

  grow() {
    const nextCapacity = this.capacity * 2;
    const next = new Array(nextCapacity);
    for (let offset = 0; offset < this.count; offset += 1) {
      next[offset] = this.data[(this.frontIndex + offset) % this.capacity];
    }
    this.data = next;
    this.capacity = nextCapacity;
    this.frontIndex = 0;
  }

  toArray() {
    const values = [];
    for (let offset = 0; offset < this.count; offset += 1) {
      values.push(this.data[(this.frontIndex + offset) % this.capacity]);
    }
    return values;
  }

  bufferCopy() {
    const copy = [];
    for (let index = 0; index < this.capacity; index += 1) {
      copy.push(this.data[index]);
    }
    return copy;
  }
}
```

`toArray` and `bufferCopy` are inspectors. `toArray` materializes $q_0, \ldots, q_{\mathrm{count}-1}$. `bufferCopy` materializes the physical slots, stale values included. Neither is a queue operation.

In JavaScript the operator `%` keeps the sign of the dividend. The enqueue and dequeue updates on this class add a nonnegative quantity before the remainder, so the result is already the mathematical residue. The deque in Part 7 subtracts, and it must correct for the sign.

---

## Part 6. The wasted-slot convention

A second circular representation stores a front index and a back index and does not store a size. It leaves one array slot unused, so an array of length $C+1$ holds at most $C$ elements. Emptiness is `frontIndex === backIndex`. Fullness is $(\mathrm{backIndex} + 1) \bmod (C+1) = \mathrm{frontIndex}$. The unused slot is what keeps those two equations from describing the same memory state: with every slot available, `frontIndex === backIndex` would be true both of an empty buffer and of a buffer that had wrapped until it was exactly full. The size counter in Part 5 distinguishes those states directly, `count === 0` and `count === capacity`, and every slot can hold a live element. This lecture does not implement the wasted slot.

---

## Part 7. The deque

A deque must update either end in constant time. Two representations do that: a circular buffer that can grow, and a doubly linked list. This lecture implements the circular buffer completely and gives the link updates that justify the linked costs.

The logical sequence is still invariant I from Part 5. `addBack` is `enqueue`. `removeFront` is `dequeue`. `front` is the queue's `front`. The new operations are `addFront`, `removeBack`, and `back`.

The newest live index, when the deque is nonempty, is

$$
(\mathrm{frontIndex} + \mathrm{count} - 1) \bmod C
$$

`removeBack` reads that slot and decrements `count`. `back` reads it and changes nothing.

`addFront` needs the index immediately before the current front:

$$
\mathrm{frontIndex}' = (\mathrm{frontIndex} - 1) \bmod C
$$

The code computes the nonnegative residue. JavaScript evaluates `(-1) % C` as $-1$, which is not an index, so the expression adds $C$ before the remainder:

$$
(\mathrm{frontIndex} - 1 + C) \bmod C
$$

If the deque is full, `addFront` grows by the same re-index as Part 5 before it moves the front. Growth sets `frontIndex` to $0$, and the formula then yields $C' - 1$, the last slot of the new array.

**Theorem (deque ends).** On a circular deque that grows by doubling, `addFront`, `addBack`, `removeFront`, and `removeBack` restore I. `addFront(x)` places $x$ at the front of the logical sequence. `removeBack` removes the newest element.

**Proof.** `addBack` and `removeFront` are the queue operations already proved. `removeBack` reads $q_{\mathrm{count}-1}$ and leaves ranks $0, \ldots, \mathrm{count}-2$ on the same slots, so the new sequence drops the newest element.

For `addFront`, growth runs first when `count === capacity` and, by the re-index lemma, restores I with `count` strictly below the new capacity. The destination index is congruent to $\mathrm{frontIndex} - 1$. It is not live: a live index is congruent to $\mathrm{frontIndex} + i$ for some $0 \leq i < \mathrm{count}$, and $\mathrm{frontIndex} - 1 \equiv \mathrm{frontIndex} + i \pmod{C}$ forces $i \equiv C - 1 \pmod{C}$. Since $\mathrm{count} \leq C - 1$, no such $i$ exists. After the write, rank $0$ is $x$. For each old rank $j$, the new rank $j+1$ sits at

$$
(\mathrm{frontIndex}' + j + 1) \equiv (\mathrm{frontIndex} + j) \pmod{C}
$$

which held $q_j$. The new sequence is $x$ followed by the old sequence.

**Costs of the circular deque.** `removeFront`, `removeBack`, `front`, `back`, `isEmpty`, and `size` are $\Theta(1)$ worst case. `addFront` and `addBack` are $\Theta(1)$ amortized and $\Theta(n)$ worst case, by the same geometric copy bound as `enqueue`. This implementation does not shrink on removal.

**Costs of a doubly linked deque.** Each node stores a value, a `prev` link, and a `next` link. The structure stores `head` and `tail`. An empty deque has both equal to `null`. The four updates rewrite a constant number of links:

```text
addFront(x):
    node = Node(value=x, prev=null, next=head)
    if head is null:
        head = tail = node
    else:
        head.prev = node
        head = node

addBack(x):
    node = Node(value=x, prev=tail, next=null)
    if tail is null:
        head = tail = node
    else:
        tail.next = node
        tail = node

removeFront():
    node = head
    head = head.next
    if head is null:
        tail = null
    else:
        head.prev = null

removeBack():
    node = tail
    tail = tail.prev
    if tail is null:
        head = null
    else:
        tail.next = null
```

Each of `addFront`, `addBack`, `removeFront`, `removeBack`, `front`, and `back` is $\Theta(1)$ worst case. A singly linked list cannot support `removeBack` in $\Theta(1)$ time, because the predecessor of the tail is not available until the list is walked. The doubly linked deque spends the extra pointer to buy that bound. It uses more memory per element than the circular buffer, and successive elements are not in contiguous slots. The circular buffer has the weaker worst-case bound on insertion and the tighter layout.

| Operation | Growing circular buffer | Doubly linked list |
| --- | --- | --- |
| `addFront`, `addBack` | $\Theta(1)$ amortized, $\Theta(n)$ worst case | $\Theta(1)$ worst case |
| `removeFront`, `removeBack` | $\Theta(1)$ worst case | $\Theta(1)$ worst case |
| `front`, `back` | $\Theta(1)$ worst case | $\Theta(1)$ worst case |
| Space | $\Theta(n)$ contiguous slots, with spare capacity | $\Theta(n)$ nodes, two links each |

Trace of a capacity-$4$ circular deque. The laboratory asserts these states.

`addBack(1)`, `addBack(2)`: physical slots begin $[1, 2, \_, \_]$, `frontIndex = 0`, logical sequence $1, 2$.

`addFront(0)`: `frontIndex` becomes $(0 - 1 + 4) \bmod 4 = 3$. Slot $3$ receives $0$. Logical sequence $0, 1, 2$.

`addFront(-1)`: `frontIndex` becomes $(3 - 1 + 4) \bmod 4 = 2$. Slot $2$ receives $-1$.

```text
index:        0    1    2    3
            +----+----+----+----+
value:      |  1 |  2 | -1 |  0 |
            +----+----+----+----+
                        ^
                     frontIndex = 2, count = 4
logical: -1, 0, 1, 2
```

`front` is $-1$ and `back` is $2$. `removeBack` returns $2$ and leaves the logical sequence $-1, 0, 1$. `removeFront` returns $-1$, sets `frontIndex` to $(2 + 1) \bmod 4 = 3$, and leaves the logical sequence $0, 1$ with `count = 2`. `removeFront` or `removeBack` on an empty deque raises deque underflow.

Now the growth path, from the full picture above, before those removals. `addFront(8)` finds `count === 4` and re-indexes first:

| New index | Source $(2+i) \bmod 4$ | Value |
| --- | --- | --- |
| $0$ | $2$ | $-1$ |
| $1$ | $3$ | $0$ |
| $2$ | $0$ | $1$ |
| $3$ | $1$ | $2$ |

`frontIndex` is $0$ and the capacity is $8$. Then `addFront` sets `frontIndex` to $(0 - 1 + 8) \bmod 8 = 7$ and writes $8$ there. The logical sequence is $8, -1, 0, 1, 2$. Slots $0$ through $3$ hold $-1, 0, 1, 2$, and slot $7$ holds $8$.

```javascript
class ArrayDeque {
  constructor(capacity = 4) {
    if (!Number.isInteger(capacity) || capacity < 1) {
      throw new Error("capacity must be a positive integer");
    }
    this.data = new Array(capacity);
    this.capacity = capacity;
    this.frontIndex = 0;
    this.count = 0;
  }

  size() {
    return this.count;
  }

  isEmpty() {
    return this.count === 0;
  }

  addBack(value) {
    if (this.count === this.capacity) {
      this.grow();
    }
    const backIndex = (this.frontIndex + this.count) % this.capacity;
    this.data[backIndex] = value;
    this.count += 1;
  }

  removeFront() {
    if (this.count === 0) {
      throw new Error("deque underflow");
    }
    const value = this.data[this.frontIndex];
    this.frontIndex = (this.frontIndex + 1) % this.capacity;
    this.count -= 1;
    return value;
  }

  addFront(value) {
    if (this.count === this.capacity) {
      this.grow();
    }
    this.frontIndex = (this.frontIndex - 1 + this.capacity) % this.capacity;
    this.data[this.frontIndex] = value;
    this.count += 1;
  }

  removeBack() {
    if (this.count === 0) {
      throw new Error("deque underflow");
    }
    const index = (this.frontIndex + this.count - 1) % this.capacity;
    const value = this.data[index];
    this.count -= 1;
    return value;
  }

  front() {
    if (this.count === 0) {
      throw new Error("deque underflow");
    }
    return this.data[this.frontIndex];
  }

  back() {
    if (this.count === 0) {
      throw new Error("deque underflow");
    }
    const index = (this.frontIndex + this.count - 1) % this.capacity;
    return this.data[index];
  }

  grow() {
    const nextCapacity = this.capacity * 2;
    const next = new Array(nextCapacity);
    for (let offset = 0; offset < this.count; offset += 1) {
      next[offset] = this.data[(this.frontIndex + offset) % this.capacity];
    }
    this.data = next;
    this.capacity = nextCapacity;
    this.frontIndex = 0;
  }

  toArray() {
    const values = [];
    for (let offset = 0; offset < this.count; offset += 1) {
      values.push(this.data[(this.frontIndex + offset) % this.capacity]);
    }
    return values;
  }

  bufferCopy() {
    const copy = [];
    for (let index = 0; index < this.capacity; index += 1) {
      copy.push(this.data[index]);
    }
    return copy;
  }
}
```

---

## Part 8. Balanced brackets

Let the alphabet be

$$
\Sigma = \{\,(,\; ),\; [,\; ],\; \{,\; \} \,\}
$$

An **opener** is one of `(`, `[`, `{`. A **closer** is one of `)`, `]`, `}`. The pairs are `()` , `[]`, and `{}`.

**Definition.** The set $B$ of balanced strings is the smallest subset of $\Sigma^{*}$ such that:

1. The empty string $\varepsilon$ is in $B$.
2. If $w$ is in $B$, then $(w)$, $[w]$, and $\{w\}$ are in $B$.
3. If $u$ and $v$ are in $B$, then the concatenation $uv$ is in $B$.

Counting openers against closers is not this definition. The string `([)]` has one of each closer and one of each opener, and it is not in $B$: the closer `)` arrives while `[` is the most recently opened unmatched opener.

The algorithm reads left to right and keeps a stack of unmatched openers.

```text
classify(w):
    stack = empty
    for each character c of w, from left to right:
        if c is an opener:
            push c
        else c is a closer:
            if stack is empty:
                return "too many closers"
            if top is not the opener that matches c:
                return "wrong closer"
            pop
    if stack is not empty:
        return "leftovers"
    return "balanced"
```

A character outside $\Sigma$ is outside the problem. The implementation raises an error rather than skipping it.

```javascript
function classifyBrackets(text) {
  const stack = new ArrayStack();
  const closers = { ")": "(", "]": "[", "}": "{" };
  const openers = new Set(["(", "[", "{"]);
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    if (openers.has(character)) {
      stack.push(character);
    } else if (Object.hasOwn(closers, character)) {
      if (stack.isEmpty()) {
        return "too many closers";
      }
      if (stack.top() !== closers[character]) {
        return "wrong closer";
      }
      stack.pop();
    } else {
      throw new Error("character outside the bracket alphabet");
    }
  }
  if (!stack.isEmpty()) {
    return "leftovers";
  }
  return "balanced";
}

function isBalanced(text) {
  return classifyBrackets(text) === "balanced";
}
```

**Lemma (prefix decomposition).** Suppose the algorithm has read a prefix $p$ and has not returned a failure. Let the stack from bottom to top be $o_1, \ldots, o_m$. Then there exist strings $b_0, b_1, \ldots, b_m$ in $B$ such that

$$
p = b_0 \, o_1 \, b_1 \, o_2 \, \cdots \, o_m \, b_m
$$

**Proof**, by induction on the length $k$ of $p$.

If $k = 0$, then $p = \varepsilon$, $m = 0$, and $b_0 = \varepsilon$, which is in $B$.

Suppose the claim holds for the prefix of length $k$, and the next character $c$ does not cause a failure. If $c$ is an opener, append it as $o_{m+1}$ and take $b_{m+1} = \varepsilon$. The displayed concatenation gains $o_{m+1} b_{m+1}$.

If $c$ is a closer, failure was avoided, so the stack is nonempty and $o_m$ matches $c$. The prefix of length $k+1$ is

$$
b_0 \, o_1 \, \cdots \, o_{m-1} \, b_{m-1} \, o_m \, b_m \, c
$$

The string $o_m b_m c$ is one of $(b_m)$, $[b_m]$, $\{b_m\}$, hence is in $B$ by clause 2. Concatenate it with $b_{m-1}$. Clause 3 puts that concatenation in $B$. The new decomposition uses openers $o_1, \ldots, o_{m-1}$ and replaces $b_{m-1}$ by that concatenation. This is the inductive step.

**Theorem (bracket correctness).** `classifyBrackets(w)` returns `"balanced"` if and only if $w \in B$. On a string in $\Sigma^{*}$ that is not in $B$, it returns exactly one of `"wrong closer"`, `"too many closers"`, and `"leftovers"`.

**Proof.** First suppose the algorithm returns `"balanced"`. It did not fail, and the final stack is empty, so $m = 0$. The lemma gives $w = b_0$ with $b_0 \in B$.

Conversely, suppose $w \in B$. A stronger claim is proved by induction on $|w|$: processing $w$, starting from any stack $S$, does not fail, never pops an opener that was already on $S$, and finishes with the stack equal to $S$.

If $w = \varepsilon$, the loop does nothing.

If the first clause that places a nonempty $w$ into $B$ is clause 2, then $w$ is $(u)$, $[u]$, or $\{u\}$ for some $u \in B$ with $|u| < |w|$. For $w = (u)$ the algorithm pushes `(`. The inductive hypothesis on $u$ restores the stack to the state just after that push, so the outer `(` is still the top and is not popped while $u$ is read. The final `)` matches it and pops it. The stack is $S$ again. The other two wrappers are the same argument with their own openers.

If the first clause that places $w$ into $B$ is clause 3, then $w = uv$ for strings $u, v \in B$ that were placed earlier. Both are nonempty: an empty side would mean $w$ was already in $B$ before this clause. Therefore $|u| < |w|$ and $|v| < |w|$. The inductive hypothesis on $u$ restores $S$, and the inductive hypothesis on $v$ restores $S$ again.

Every nonempty string in $B$ has such a first clause. Starting from an empty stack, the algorithm therefore finishes with an empty stack and returns `"balanced"`.

The three failure returns are exactly the ways a run on a string in $\Sigma^{*}$ can avoid that success. A closer with an empty stack is "too many closers." A closer whose opener is not the top is "wrong closer." A finished stack that still holds openers is "leftovers."

The same induction shows why the top is the right opener to test. In the decomposition, $o_m$ is the most recent unmatched opener. Clause 2 wraps a balanced string, so the closer that completes a wrap must match that opener and no earlier one.

Traces the laboratory checks:

| String | Decision | Stack at the decision, bottom to top |
| --- | --- | --- |
| `""` | balanced | empty |
| `()[]{}` | balanced | empty at the end; each pair pushes and immediately pops |
| `{[()]}` | balanced | empty at the end |
| `([)]` | wrong closer | `(` then `[` when `)` arrives |
| `(]` | wrong closer | `(` when `]` arrives |
| `)` | too many closers | empty |
| `())` | too many closers | empty when the second `)` arrives |
| `(` | leftovers | `(` |
| `(()` | leftovers | `(` |
| `({[` | leftovers | `(`, `{`, `[` |

The string `(a)` contains `a`, which is outside $\Sigma$, so the classifier throws.

Work `{[()]}` in full, because it nests three pairs. `{` is pushed, `[` is pushed, `(` is pushed. `)` matches `(`. `]` matches `[`. `}` matches `{`. The stack is empty. The string is the clause-2 wrapping of a clause-2 wrapping of a clause-2 wrapping of $\varepsilon$.

Work `([)]`. `(` is pushed. `[` is pushed. `)` requires `(`, and the top is `[`. The algorithm returns "wrong closer" without looking at the final `]`. The lemma stops applying at the failure, and the string is not in $B$.

---

## Part 9. Shunting-yard and postfix evaluation

The input here is an arithmetic expression written in the ordinary way: $3 + 4 * 2$. That notation is **infix**, because each operator sits between its operands. **Postfix**, also called Reverse Polish notation, writes both operands before the operator. The infix expression $(8 - 3) - 2$ has postfix $8 \; 3 \; - \; 2 \; -$.

Dijkstra's shunting-yard algorithm converts infix to postfix. It uses an operator stack and an output list. A second stack evaluates the postfix. Dijkstra's shunting-yard algorithm, from his 1961 ALGOL 60 translator, is not Dijkstra's shortest-path algorithm; the shared name is the author, and shortest paths are Lecture 13.

### The expression language

Tokens are nonnegative integers and the symbols `+`, `-`, `*`, `/`, `(`, and `)`. The operator `-` is binary. A leading minus, or a minus immediately after `(`, is a unary minus, and this lecture does not accept it. Exponentiation is absent; the usual exponentiation operator is right-associative, and adding it would change the comparison below.

Precedence has two levels. Multiplication and division bind more tightly than addition and subtraction. All four operators are **left-associative**: $8 - 3 - 2$ means $(8 - 3) - 2$, and $20 / 4 / 5$ means $(20 / 4) / 5$. Parentheses group explicitly.

The grammar is the definition of that precedence and that associativity.

$$
\begin{aligned}
E &\to T \mid E + T \mid E - T \\
T &\to F \mid T * F \mid T / F \\
F &\to \mathrm{number} \mid (\, E \,)
\end{aligned}
$$

$E$ is an expression, $T$ is a term, and $F$ is a factor.

**Theorem (unique parse).** Every string derived from $E$ has exactly one derivation tree.

**Proof**, by induction on the length of the token string. A derived expression has balanced parentheses of the single pair `()`. That fact follows by induction on the derivation: a number has no parentheses, an operator production preserves the balance of its children, and $(E)$ adds one matched pair around a balanced string. The bracket theorem of Part 8, restricted to `()`, gives each `(` a unique matching `)`.

Call a token **top-level** when it is not inside any parentheses. In a string derived from $T$, every top-level operator is `*` or `/`, because `+` and `-` are introduced only by $E$. In a string derived from $E$ that is not a single term, the top-level `+` and `-` operators exist. The production $E \to E + T$ or $E \to E - T$ puts a term on the right, so the right piece contains no top-level additive operator. The split is therefore the rightmost top-level `+` or `-`. The left piece is shorter and is an expression; the right piece is shorter and is a term. The inductive hypothesis parses both uniquely.

A term that is not a single factor splits at its rightmost top-level `*` or `/`, by the same reasoning with $T \to T * F$ and $T \to T / F$. A factor is either a number or a parenthesized expression. If it begins with `(`, the matching `)` is unique, the inside is shorter, and the inductive hypothesis parses it as an expression. A number is a single token. Each case has one split, so the derivation tree is unique.

The **postfix** of a parse tree is defined with the tree.

- The postfix of a number $n$ is the token $n$.
- The postfix of $(E)$ is the postfix of $E$.
- The postfix of $E + T$ is the postfix of $E$, then the postfix of $T$, then `+`. The same pattern holds for `-`, `*`, and `/`.

The value of a tree is the same recursion with ordinary arithmetic in place of "append the operator." Because the tree is unique, the infix string has one postfix and one value under this grammar.

### Postfix evaluation

The evaluator uses a stack of numbers.

```text
evaluate(postfix):
    stack = empty
    for each token t:
        if t is a number:
            push t
        else t is an operator:
            pop right, then pop left
            push (left t right)
    the stack must hold exactly one number
    return that number
```

The right operand is popped first because it was pushed later. For subtraction and division the order is the value: `left - right`, `left / right`.

```javascript
const PRECEDENCE = { "+": 1, "-": 1, "*": 2, "/": 2 };

function isOperator(token) {
  return Object.hasOwn(PRECEDENCE, token);
}

function evaluatePostfix(tokens) {
  const stack = new ArrayStack();
  for (const token of tokens) {
    if (typeof token === "number") {
      stack.push(token);
      continue;
    }
    if (!isOperator(token)) {
      throw new Error("unrecognized token");
    }
    if (stack.size() < 2) {
      throw new Error("malformed postfix");
    }
    const right = stack.pop();
    const left = stack.pop();
    let value;
    if (token === "+") {
      value = left + right;
    } else if (token === "-") {
      value = left - right;
    } else if (token === "*") {
      value = left * right;
    } else if (right === 0) {
      throw new Error("division by zero");
    } else {
      value = left / right;
    }
    stack.push(value);
  }
  if (stack.size() !== 1) {
    throw new Error("malformed postfix");
  }
  return stack.pop();
}
```

JavaScript numbers are IEEE-754 doubles. Integer results are exact when every intermediate value is a safe integer, that is, an integer whose magnitude is at most $2^{53} - 1$. The traces in this lecture are far inside that range. The operator `/` is JavaScript division. The examples divide evenly, so the mathematical quotient and the computed number agree. Division by zero raises an error instead of producing an infinity. A postfix token sequence that is not a well-formed postfix expression leaves the wrong number of values on the stack, or asks for an operand that is not there, and the function raises "malformed postfix." The tokens `[2, "+"]` are malformed. The tokens `[1, 0, "/"]` divide by zero.

**Lemma (stack height).** Evaluating a well-formed postfix expression $P$, starting from a stack of height $h$, never pops an element that was already on the stack at height $h$ or below, finishes at height $h+1$, and leaves $\mathrm{value}(P)$ on top.

**Proof**, by induction on $P$. If $P$ is a number, the algorithm pushes it and does not pop. The height goes from $h$ to $h+1$, and the top is that number.

If $P$ is $P_1 \; P_2 \; \oplus$, the inductive hypothesis runs $P_1$ from height $h$ to height $h+1$ without reading below $h$, and the top is $v_1 = \mathrm{value}(P_1)$. It runs $P_2$ from height $h+1$ to height $h+2$ without reading below $h+1$, and the top is $v_2$. The operator pops $v_2$, then pops $v_1$. The second pop occurs at height $h+1$, so it does not read below $h$. The push of $v_1 \oplus v_2$ finishes at height $h+1$ with the value of $P$ on top.

**Theorem (postfix value).** On a well-formed postfix expression, `evaluatePostfix` returns the value of that expression.

**Proof.** Apply the height lemma at $h = 0$. The algorithm finishes with exactly one value, and that value is $\mathrm{value}(P)$. The final size check accepts it.

### The conversion

Shunting-yard reads infix tokens once. Numbers go straight to the output. Operators wait on a stack until a later token forces them out. A left parenthesis is a **barrier**: the `while` tests that pop operators stop when the top is `(`, and they stop when the stack is empty.

```text
shuntingYard(tokens):
    output = empty list
    operators = empty stack
    for each token t:
        if t is a number:
            append t to output
        if t is an operator:
            while operators is nonempty
                  and top is an operator
                  and precedence(top) >= precedence(t):
                pop top and append it to output
            push t
        if t is "(":
            push t
        if t is ")":
            while top is not "(":
                pop top and append it to output
            if no "(" was found:
                reject a mismatched parenthesis
            pop "(" and discard it
    while operators is nonempty:
        if top is "(":
            reject a mismatched parenthesis
        pop top and append it to output
    return output
```

The comparison is $\geq$ because every operator in this lecture is left-associative. An operator of equal precedence that is already on the stack was written earlier, and left associativity says the earlier operator is inside the parentheses of the parse. It must leave the stack before the new operator enters. A right-associative operator would stay when the precedences were equal, and the test for that operator would be strict $>$. This lecture does not implement that test.

```javascript
function shuntingYard(tokens) {
  const output = [];
  const operators = new ArrayStack();
  for (const token of tokens) {
    if (typeof token === "number") {
      output.push(token);
    } else if (isOperator(token)) {
      while (
        !operators.isEmpty() &&
        isOperator(operators.top()) &&
        PRECEDENCE[operators.top()] >= PRECEDENCE[token]
      ) {
        output.push(operators.pop());
      }
      operators.push(token);
    } else if (token === "(") {
      operators.push(token);
    } else if (token === ")") {
      while (!operators.isEmpty() && operators.top() !== "(") {
        output.push(operators.pop());
      }
      if (operators.isEmpty()) {
        throw new Error("mismatched parenthesis");
      }
      operators.pop();
    } else {
      throw new Error("unrecognized token");
    }
  }
  while (!operators.isEmpty()) {
    if (operators.top() === "(") {
      throw new Error("mismatched parenthesis");
    }
    output.push(operators.pop());
  }
  return output;
}

function tokenize(source) {
  const parts = source.split(" ").filter((part) => part.length > 0);
  return parts.map((part) => {
    if (/^[0-9]+$/.test(part)) {
      return Number(part);
    }
    return part;
  });
}
```

`tokenize` splits on spaces and turns a token made entirely of digits into a number. The expression strings below are written with a space between every token, including the parentheses.

**Lemma (increasing precedence).** After every token of a derived expression, within one parenthesis frame the operators from bottom to top have strictly increasing precedence. A frame is the portion of the stack above the most recent unmatched `(`, or the whole stack when there is none.

**Proof.** `(` opens a frame with no operators. Consider pushing an operator $t$ of precedence $p$. The loop first pops while the top is an operator of precedence at least $p$. When the loop stops, the top of the frame is absent or has precedence less than $p$. The push of $t$ restores a strict increase. `)` flushes the frame and discards the barrier, which returns the stack to the enclosing frame. That frame was already strictly increasing and was not modified while the inner frame existed.

For these two precedence levels the lemma is concrete: a frame holds at most one of `+` or `-`, at most one of `*` or `/`, and the multiplicative operator is above the additive operator when both are present. Two additive operators never sit in the same frame, because the second one pops the first.

**Theorem (shunting-yard).** On the token sequence of a string derived from $E$, `shuntingYard` returns the postfix of that string's unique parse tree.

The proof uses three claims. Let $h$ be the stack height at the moment the phrase begins. The $h$ tokens already on the stack are a prefix that the phrase does not pop. When the phrase is a factor, or an expression at the start of the input or immediately after a `(`, that prefix is a barrier: either $h = 0$, or the token at height $h$ is `(`. When the phrase is the term to the right of `+` or `-`, the token at height $h$ is that additive operator, and the term leaves it in place because it is waiting for the term as its right operand.

**Claim F.** After the tokens of a factor $F$, the output has gained $\mathrm{postfix}(F)$, and the stack height is $h$ again.

**Claim T.** After the tokens of a term $T$, the operators above height $h$ are the still-pending multiplicative operators of $T$, and appending those operators to the output that has already been gained produces $\mathrm{postfix}(T)$. The prefix of height $h$ is unchanged.

**Claim E.** After the tokens of an expression $E$, the operators above height $h$ are the still-pending operators of $E$, and flushing them onto the output produces $\mathrm{postfix}(E)$. The prefix of height $h$ is unchanged.

The three claims are proved together by induction on the length of the phrase.

A factor that is a number appends that number and does not touch the stack. Claim F holds, and $\mathrm{postfix}(F)$ is the number.

A factor $(E)$ pushes `(`. The inner expression begins at height $h+1$, with `(` as the barrier. Claim E, applied to that shorter expression, says the operators left above the barrier are the pending operators of $E$, and moving them to the output appends $\mathrm{postfix}(E)$. The handler for `)` does that move and then discards `(`. The stack returns to height $h$. The appended tokens are $\mathrm{postfix}(E)$, which is $\mathrm{postfix}(F)$.

A term that is a single factor uses Claim F. No operator remains above $h$, and the output gained is already $\mathrm{postfix}(T)$. Claim T holds.

A term $T_1 * F$, and the case $T_1 / F$, is the inductive step for terms. Claim T on the shorter term $T_1$ leaves only multiplicative operators above $h$. The new `*` has precedence $2$. The loop pops while the top has precedence at least $2$, so it pops exactly those pending operators and stops before an additive operator or a barrier in the prefix. By Claim T, the output is now $\mathrm{postfix}(T_1)$ and the height is $h$. The algorithm pushes `*`. Claim F on the following factor restores the stack to the height just after that push and appends $\mathrm{postfix}(F)$. The only operator above $h$ is `*`. Flushing it appends `*`. The tokens gained are $\mathrm{postfix}(T_1)$, $\mathrm{postfix}(F)$, `*`, which is $\mathrm{postfix}(T_1 * F)$.

An expression that is a single term uses Claim T. Flushing the pending multiplicative operators yields $\mathrm{postfix}(E)$. Claim E holds.

An expression $E_1 + T$, and the case $E_1 - T$, begins with Claim E on $E_1$. The new `+` has precedence $1$. Every operator has precedence at least $1$, so the loop flushes every operator above the barrier down to height $h$. The output is $\mathrm{postfix}(E_1)$. The algorithm pushes `+`. The following term starts with that `+` at the top of the prefix it must preserve. Inside the term, a multiplicative operator pops only precedence at least $2$, so it does not pop the `+`. Claim T says the operators above the `+` complete $\mathrm{postfix}(T)$. Flushing from the top down to height $h$ therefore appends the rest of $\mathrm{postfix}(T)$ and then `+`. The tokens gained are $\mathrm{postfix}(E_1)$, $\mathrm{postfix}(T)$, `+`.

Every production has been checked, and each recursive piece is shorter. At the start of a complete expression the height $h$ is $0$. Claim E says that flushing the remaining stack appends exactly the postfix of the expression. That flush is the final loop of the algorithm.

Parentheses that do not belong to a derived expression are rejected. A `)` whose frame has no `(` finds an empty stack during the search for the barrier. A `(` that is never closed is still on the stack in the final loop. The token sequences `( 2 + 3` and `2 + )` are the laboratory's mismatch checks. The theorem does not promise a classified error for every string outside the grammar. An operator with too few operands, such as a postfix produced from a malformed token list, fails later in `evaluatePostfix`.

### A full numeric trace

The expression is $3 + 4 * 2 / (1 - 5)$. Under the grammar this is the sum of the term $3$ and the term $4 * 2 / (1 - 5)$. The second term splits, by left associativity, as $(4 * 2) / (1 - 5)$. The value is

$$
3 + \frac{4 \cdot 2}{1 - 5} = 3 + \frac{8}{-4} = 3 + (-2) = 1
$$

The stack column is bottom to top. The output column is oldest token on the left.

| Token | Output | Operator stack |
| --- | --- | --- |
| $3$ | $3$ | empty |
| $+$ | $3$ | `+` |
| $4$ | $3 \; 4$ | `+` |
| $*$ | $3 \; 4$ | `+` `*` |
| $2$ | $3 \; 4 \; 2$ | `+` `*` |
| $/$ | $3 \; 4 \; 2 \; *$ | `+` `/` |
| `(` | $3 \; 4 \; 2 \; *$ | `+` `/` `(` |
| $1$ | $3 \; 4 \; 2 \; * \; 1$ | `+` `/` `(` |
| $-$ | $3 \; 4 \; 2 \; * \; 1$ | `+` `/` `(` `-` |
| $5$ | $3 \; 4 \; 2 \; * \; 1 \; 5$ | `+` `/` `(` `-` |
| `)` | $3 \; 4 \; 2 \; * \; 1 \; 5 \; -$ | `+` `/` |
| end | $3 \; 4 \; 2 \; * \; 1 \; 5 \; - \; /$ | `+` |
| end | $3 \; 4 \; 2 \; * \; 1 \; 5 \; - \; / \; +$ | empty |

The step at `/` pops `*` because the precedences are equal and the operator is left-associative. It does not pop `+`, because addition has lower precedence. The step at `-` pushes immediately, because the top is the barrier `(`. The step at `)` pops `-` and discards `(`. The final flush pops `/` before `+`, which is the unique parse: the quotient is computed before it is added to $3$.

Pending form just after the token `*`: the stack `+` `*` means the open expression $3 + (4 * \square)$, where the box is the missing right factor of `*`. The number $2$ fills that box, and the following `/` of equal precedence closes it, emitting `*`.

Postfix evaluation of $3 \; 4 \; 2 \; * \; 1 \; 5 \; - \; / \; +$:

| Token | Stack after the token, bottom to top |
| --- | --- |
| $3$ | $3$ |
| $4$ | $3 \; 4$ |
| $2$ | $3 \; 4 \; 2$ |
| $*$ | $3 \; 8$ |
| $1$ | $3 \; 8 \; 1$ |
| $5$ | $3 \; 8 \; 1 \; 5$ |
| $-$ | $3 \; 8 \; -4$ |
| $/$ | $3 \; -2$ |
| $+$ | $1$ |

The subtraction pops $5$ then $1$, and computes $1 - 5 = -4$. The division pops $-4$ then $8$, and computes $8 / -4 = -2$. The addition pops $-2$ then $3$, and computes $3 + (-2) = 1$.

### Three more expressions

These three are the rest of the laboratory's required set. Each one isolates a rule the main trace already used.

**Left associativity.** $8 - 3 - 2$.

| Token | Output | Operator stack |
| --- | --- | --- |
| $8$ | $8$ | empty |
| $-$ | $8$ | `-` |
| $3$ | $8 \; 3$ | `-` |
| $-$ | $8 \; 3 \; -$ | `-` |
| $2$ | $8 \; 3 \; - \; 2$ | `-` |
| end | $8 \; 3 \; - \; 2 \; -$ | empty |

The second `-` pops the first `-` before it is pushed. Evaluation: $8 - 3 = 5$, then $5 - 2 = 3$. The parse is $(8 - 3) - 2$. If the loop used a strict $>$ comparison, the two minuses would both remain and the final flush would emit $8 \; 3 \; 2 \; - \; -$, whose value is $8 - (3 - 2) = 7$. The $\geq$ test is the left-associativity rule.

**Parentheses.** $(2 + 3) * 4$.

| Token | Output | Operator stack |
| --- | --- | --- |
| `(` | empty | `(` |
| $2$ | $2$ | `(` |
| $+$ | $2$ | `(` `+` |
| $3$ | $2 \; 3$ | `(` `+` |
| `)` | $2 \; 3 \; +$ | empty |
| $*$ | $2 \; 3 \; +$ | `*` |
| $4$ | $2 \; 3 \; + \; 4$ | `*` |
| end | $2 \; 3 \; + \; 4 \; *$ | empty |

Evaluation: $2 + 3 = 5$, then $5 * 4 = 20$. The barrier lets `+` wait inside the parentheses and forces it out before `*` is pushed.

**Precedence across two products.** $2 * 3 + 4 * 5$.

| Token | Output | Operator stack |
| --- | --- | --- |
| $2$ | $2$ | empty |
| $*$ | $2$ | `*` |
| $3$ | $2 \; 3$ | `*` |
| $+$ | $2 \; 3 \; *$ | `+` |
| $4$ | $2 \; 3 \; * \; 4$ | `+` |
| $*$ | $2 \; 3 \; * \; 4$ | `+` `*` |
| $5$ | $2 \; 3 \; * \; 4 \; 5$ | `+` `*` |
| end | $2 \; 3 \; * \; 4 \; 5 \; * \; +$ | empty |

The `+` pops `*` and does not stay under it. The second `*` sits above `+` because its precedence is higher. Evaluation: $2 * 3 = 6$, $4 * 5 = 20$, $6 + 20 = 26$. The value is $(2 * 3) + (4 * 5)$.

---

## Part 10. A queue made from two stacks

A stack is last-in, first-out. Two of them can simulate first-in, first-out. Call the stacks the **inbox** and the **outbox**. Both stacks hold elements with the ordinary top at the end that `pop` removes.

```text
enqueue(x):
    push x onto inbox

dequeue():
    if outbox is empty:
        while inbox is not empty:
            pop inbox and push that element onto outbox
    if outbox is empty:
        raise underflow
    pop outbox and return it
```

`front` uses the same transfer and then reads the outbox top without popping it. The field `transfers` in the implementation counts elements moved from inbox to outbox. It is instrumentation for the aggregate argument. It is not a queue operation.

```javascript
class TwoStackQueue {
  constructor() {
    this.inbox = new ArrayStack();
    this.outbox = new ArrayStack();
    this.transfers = 0;
  }

  enqueue(value) {
    this.inbox.push(value);
  }

  transfer() {
    if (this.outbox.isEmpty()) {
      while (!this.inbox.isEmpty()) {
        this.outbox.push(this.inbox.pop());
        this.transfers += 1;
      }
    }
  }

  dequeue() {
    this.transfer();
    if (this.outbox.isEmpty()) {
      throw new Error("queue underflow");
    }
    return this.outbox.pop();
  }

  front() {
    this.transfer();
    if (this.outbox.isEmpty()) {
      throw new Error("queue underflow");
    }
    return this.outbox.top();
  }

  isEmpty() {
    return this.inbox.isEmpty() && this.outbox.isEmpty();
  }
}
```

Read a stack from top to bottom when the order of successive pops matters, and from bottom to top when the order of arrival in that stack matters.

**Invariant Q.** The queue from front to back is the outbox read from top to bottom, followed by the inbox read from bottom to top.

**Theorem (two-stack queue).** `enqueue` and `dequeue` preserve Q. `dequeue` returns the front element. `enqueue` appends at the back. Both stacks empty means the queue is empty.

**Proof.** The empty pair of stacks is the empty queue.

`enqueue(x)` pushes $x$ on the inbox. In bottom-to-top order, $x$ is a new last element of the inbox portion. The outbox portion is unchanged. Q gains $x$ at the back.

Suppose `dequeue` runs while the outbox is nonempty. The outbox top is the first element of "outbox top to bottom," which Q says is the front. Popping it removes the front. The inbox portion is unchanged.

Suppose `dequeue` runs while the outbox is empty and the inbox holds $x_1, \ldots, x_m$ from bottom to top. Then $x_1$ is the oldest. The transfer pops $x_m$ first and $x_1$ last, pushing each onto the outbox. The outbox, read top to bottom, is $x_1, \ldots, x_m$. The inbox is empty. Q is unchanged by the transfer, because the old inbox order has become the new outbox order. The following pop returns $x_1$. If both stacks were empty, the transfer moves nothing and `dequeue` raises underflow.

`front` performs the same transfer and reads the element `dequeue` would return.

### The worked sequence

Stacks are written bottom to top. The cost model used in the arithmetic counts one stack `push` or `pop` as one unit. A transfer of $t$ elements performs $t$ pops and $t$ pushes. A `dequeue` that transfers $t$ elements then pops the outbox, so its cost is $2t + 1$. A `front` that does not transfer performs one `top`.

| Operation | Inbox | Outbox | Result | $t$ | Dequeue cost |
| --- | --- | --- | --- | --- | --- |
| enqueue $1$ | $1$ | empty | | | |
| enqueue $2$ | $1 \; 2$ | empty | | | |
| enqueue $3$ | $1 \; 2 \; 3$ | empty | | | |
| dequeue | empty | $3 \; 2$ | $1$ | $3$ | $7$ |
| dequeue | empty | $3$ | $2$ | $0$ | $1$ |
| enqueue $4$ | $4$ | $3$ | | | |
| front | $4$ | $3$ | $3$ | $0$ | |
| dequeue | $4$ | empty | $3$ | $0$ | $1$ |
| dequeue | empty | empty | $4$ | $1$ | $3$ |

The first dequeue moves $3$, then $2$, then $1$ onto the outbox and pops $1$. The outbox left behind is $3, 2$ from bottom to top, so the top is $2$. The second dequeue pops $2$ and leaves $3$. After `enqueue(4)` the outbox still holds $3$, so `front` returns $3$ and does not transfer. The next dequeue pops $3$. The last dequeue finds an empty outbox, moves $4$, and pops $4$.

The transfer total is $3 + 0 + 0 + 1 = 4$, one move for each enqueued element. The dequeue costs sum to $7 + 1 + 1 + 3 = 12$. With $E = 4$ enqueues and $D_q = 4$ dequeues,

$$
2 \cdot (\text{sum of } t) + D_q = 2 \cdot 4 + 4 = 12
$$

The laboratory asserts the four returned values, the `front` value $3$, the transfer total $4$, and underflow on a further dequeue.

### The aggregate argument

The example is one sequence. The bound has to hold for every sequence.

**Theorem (amortized dequeue).** Start from an empty two-stack queue. Consider any sequence of $N$ operations, each an `enqueue`, a `dequeue`, or a `front`, with no dequeue or front of an empty queue. The total number of stack primitives used by the whole sequence is $O(N)$. The amortized cost of one operation is therefore $\Theta(1)$. In particular, `dequeue` has amortized cost $\Theta(1)$. The worst-case cost of a single `dequeue` is $\Theta(n)$, where $n$ is the number of elements in the inbox when the outbox is empty.

**Proof.** Count primitives as follows. `enqueue` performs one `push`. A transfer of one element performs one `pop` and one `push`. `dequeue` performs one additional `pop` after the transfer. `front` performs one `top` after the transfer. Empty tests are a constant amount of work per operation and are absorbed in the $O(N)$ term.

Each element is pushed onto the inbox once, at its `enqueue`. The transfer loop runs only when the outbox is empty, and it moves the entire inbox. After an element moves to the outbox, it stays there until `dequeue` pops it. It is never pushed onto the inbox again. Therefore each element is transferred at most once.

Let $E$ be the number of enqueues, let $D_q$ be the number of dequeues, and let $F$ be the number of fronts. Let $T$ be the total number of element transfers in the sequence. Then $T \leq E$. Also $E + D_q + F = N$, so $E \leq N$ and $D_q \leq N$.

The primitive count is

$$
E + 2T + D_q + F \leq E + 2E + D_q + F = 2E + (E + D_q + F) = 2E + N \leq 3N
$$

The total cost of the sequence is $O(N)$. Dividing by $N$ is the aggregate method of Lecture 02: the amortized cost per operation is $O(1)$. Every operation performs at least one stack primitive, so the amortized cost is also $\Omega(1)$, hence $\Theta(1)$.

That statement includes `dequeue`. It does not say that every individual `dequeue` is $\Theta(1)$. If the outbox is empty and the inbox holds $k$ elements, that one `dequeue` transfers $k$ elements and costs $\Theta(k)$. In a sequence whose inbox never holds more than $n$ elements, the worst-case cost of `dequeue` is $\Theta(n)$. The aggregate bound says the expensive dequeues are paid for across the sequence: the $2T$ transfer primitives are at most $2E$, and those enqueues are part of the $N$ operations.

The same inequality specializes to dequeues alone. Charge a dequeue that transfers $t$ elements the cost $2t + 1$. Summing over the sequence,

$$
\sum (2t + 1) = 2T + D_q \leq 2E + D_q \leq 3N
$$

The sum of the actual dequeue costs is linear in the length of the whole sequence. In the worked example, $N$ is larger than $8$ once `front` is counted: four enqueues, four dequeues, and one front give $N = 9$, and $3N = 27$. The twelve units spent inside dequeues, plus four enqueue pushes, plus one `top`, total $17$, which is within $3 \cdot 9 = 27$. The first dequeue alone cost $7$, which is not a constant, and the sequence total still is linear.

---

## Part 11. When an end-only structure is the wrong tool

Use a stack when the next read or deletion is always the most recently inserted surviving element: unmatched openers, operators waiting for precedence, function frames, and an undo history that discards the latest action first. Use a queue when the next removal is always the oldest surviving element: the two-stack simulation's own outbox is the consumer side, and a breadth-first layer in Lecture 12 will be a queue. Use a deque when both ends are real clients and the interior is not.

Two operation mixes fall outside all three contracts.

The client needs the middle element, or it needs element $i$ for an arbitrary $i$. A stack, queue, or deque can produce that element only by removing everything in front of it. On a sequence of length $n$ that cost is $\Theta(n)$, and it destroys the prefix. A dynamic array from Lecture 02 reads index $i$ in $\Theta(1)$ time and leaves the other elements in place. If the client also inserts and deletes at arbitrary positions often, the array's middle insertion is $\Theta(n)$, and a linked list from Lecture 03 inserts at a known node in $\Theta(1)$ after that node has been found.

The client needs search by key: "find the record whose identifier is $k$." None of the three contracts offers that operation. Draining a stack or a queue until the key appears is a linear scan that also destroys the container unless the client rebuilds it. The structures that own search by key are the binary search tree of Lecture 08 and the hash table of Lecture 11. Choosing them is justified when the operation mix contains lookup, not when it contains only end updates.

---

## LABORATORY PROGRAM

The program below is a complete Node.js script. It contains the array stack, the linked stack, the linked queue, the growing circular queue, the growing circular deque, the bracket classifier, shunting-yard, postfix evaluation, and the two-stack queue. Its assertions use the numbers from the hand traces.

Before you read the script, write down these predictions from the traces and then compare.

1. After wrap 1, wrap 2, and wrap 3, write the physical buffer, `frontIndex`, and `count` for the capacity-$4$ queue of $10, 20, 30, 40, 50, 60$.
2. After the growth enqueue of $70$, write the first five slots, the new front index, and the new capacity.
3. Classify `([)]`, `())`, and `(()`.
4. Write the postfix and the value of $3 + 4 * 2 / (1 - 5)$, of $8 - 3 - 2$, of $(2 + 3) * 4$, and of $2 * 3 + 4 * 5$.
5. For the two-stack sequence, write the four dequeued values and the transfer total.

Type the program and run it with `node`. It prints `ALL TESTS PASSED` when every assertion holds. Then change one asserted number, confirm that the process throws, and restore the number. The inspectors `toArray`, `bufferCopy`, and `transfers` exist so those assertions can see the representation; they are not extra abstract operations.

```javascript
"use strict";

import assert from "node:assert/strict";

class SinglyNode {
  constructor(value, next) {
    this.value = value;
    this.next = next;
  }
}

class ArrayStack {
  constructor() {
    this.data = [];
  }

  push(value) {
    this.data.push(value);
  }

  pop() {
    if (this.data.length === 0) {
      throw new Error("stack underflow");
    }
    return this.data.pop();
  }

  top() {
    if (this.data.length === 0) {
      throw new Error("stack underflow");
    }
    return this.data[this.data.length - 1];
  }

  isEmpty() {
    return this.data.length === 0;
  }

  size() {
    return this.data.length;
  }
}

class LinkedStack {
  constructor() {
    this.head = null;
    this.count = 0;
  }

  push(value) {
    this.head = new SinglyNode(value, this.head);
    this.count += 1;
  }

  pop() {
    if (this.head === null) {
      throw new Error("stack underflow");
    }
    const value = this.head.value;
    this.head = this.head.next;
    this.count -= 1;
    return value;
  }

  top() {
    if (this.head === null) {
      throw new Error("stack underflow");
    }
    return this.head.value;
  }

  isEmpty() {
    return this.head === null;
  }

  size() {
    return this.count;
  }
}

class LinkedQueue {
  constructor() {
    this.head = null;
    this.tail = null;
    this.count = 0;
  }

  enqueue(value) {
    const node = new SinglyNode(value, null);
    if (this.tail === null) {
      this.head = node;
      this.tail = node;
    } else {
      this.tail.next = node;
      this.tail = node;
    }
    this.count += 1;
  }

  dequeue() {
    if (this.head === null) {
      throw new Error("queue underflow");
    }
    const value = this.head.value;
    this.head = this.head.next;
    if (this.head === null) {
      this.tail = null;
    }
    this.count -= 1;
    return value;
  }

  front() {
    if (this.head === null) {
      throw new Error("queue underflow");
    }
    return this.head.value;
  }

  isEmpty() {
    return this.head === null;
  }

  size() {
    return this.count;
  }
}

class CircularQueue {
  constructor(capacity = 4) {
    if (!Number.isInteger(capacity) || capacity < 1) {
      throw new Error("capacity must be a positive integer");
    }
    this.data = new Array(capacity);
    this.capacity = capacity;
    this.frontIndex = 0;
    this.count = 0;
  }

  size() {
    return this.count;
  }

  isEmpty() {
    return this.count === 0;
  }

  enqueue(value) {
    if (this.count === this.capacity) {
      this.grow();
    }
    const backIndex = (this.frontIndex + this.count) % this.capacity;
    this.data[backIndex] = value;
    this.count += 1;
  }

  dequeue() {
    if (this.count === 0) {
      throw new Error("queue underflow");
    }
    const value = this.data[this.frontIndex];
    this.frontIndex = (this.frontIndex + 1) % this.capacity;
    this.count -= 1;
    return value;
  }

  front() {
    if (this.count === 0) {
      throw new Error("queue underflow");
    }
    return this.data[this.frontIndex];
  }

  grow() {
    const nextCapacity = this.capacity * 2;
    const next = new Array(nextCapacity);
    for (let offset = 0; offset < this.count; offset += 1) {
      next[offset] = this.data[(this.frontIndex + offset) % this.capacity];
    }
    this.data = next;
    this.capacity = nextCapacity;
    this.frontIndex = 0;
  }

  toArray() {
    const values = [];
    for (let offset = 0; offset < this.count; offset += 1) {
      values.push(this.data[(this.frontIndex + offset) % this.capacity]);
    }
    return values;
  }

  bufferCopy() {
    const copy = [];
    for (let index = 0; index < this.capacity; index += 1) {
      copy.push(this.data[index]);
    }
    return copy;
  }
}

class ArrayDeque {
  constructor(capacity = 4) {
    if (!Number.isInteger(capacity) || capacity < 1) {
      throw new Error("capacity must be a positive integer");
    }
    this.data = new Array(capacity);
    this.capacity = capacity;
    this.frontIndex = 0;
    this.count = 0;
  }

  size() {
    return this.count;
  }

  isEmpty() {
    return this.count === 0;
  }

  addBack(value) {
    if (this.count === this.capacity) {
      this.grow();
    }
    const backIndex = (this.frontIndex + this.count) % this.capacity;
    this.data[backIndex] = value;
    this.count += 1;
  }

  removeFront() {
    if (this.count === 0) {
      throw new Error("deque underflow");
    }
    const value = this.data[this.frontIndex];
    this.frontIndex = (this.frontIndex + 1) % this.capacity;
    this.count -= 1;
    return value;
  }

  addFront(value) {
    if (this.count === this.capacity) {
      this.grow();
    }
    this.frontIndex = (this.frontIndex - 1 + this.capacity) % this.capacity;
    this.data[this.frontIndex] = value;
    this.count += 1;
  }

  removeBack() {
    if (this.count === 0) {
      throw new Error("deque underflow");
    }
    const index = (this.frontIndex + this.count - 1) % this.capacity;
    const value = this.data[index];
    this.count -= 1;
    return value;
  }

  front() {
    if (this.count === 0) {
      throw new Error("deque underflow");
    }
    return this.data[this.frontIndex];
  }

  back() {
    if (this.count === 0) {
      throw new Error("deque underflow");
    }
    const index = (this.frontIndex + this.count - 1) % this.capacity;
    return this.data[index];
  }

  grow() {
    const nextCapacity = this.capacity * 2;
    const next = new Array(nextCapacity);
    for (let offset = 0; offset < this.count; offset += 1) {
      next[offset] = this.data[(this.frontIndex + offset) % this.capacity];
    }
    this.data = next;
    this.capacity = nextCapacity;
    this.frontIndex = 0;
  }

  toArray() {
    const values = [];
    for (let offset = 0; offset < this.count; offset += 1) {
      values.push(this.data[(this.frontIndex + offset) % this.capacity]);
    }
    return values;
  }

  bufferCopy() {
    const copy = [];
    for (let index = 0; index < this.capacity; index += 1) {
      copy.push(this.data[index]);
    }
    return copy;
  }
}

function classifyBrackets(text) {
  const stack = new ArrayStack();
  const closers = { ")": "(", "]": "[", "}": "{" };
  const openers = new Set(["(", "[", "{"]);
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    if (openers.has(character)) {
      stack.push(character);
    } else if (Object.hasOwn(closers, character)) {
      if (stack.isEmpty()) {
        return "too many closers";
      }
      if (stack.top() !== closers[character]) {
        return "wrong closer";
      }
      stack.pop();
    } else {
      throw new Error("character outside the bracket alphabet");
    }
  }
  if (!stack.isEmpty()) {
    return "leftovers";
  }
  return "balanced";
}

function isBalanced(text) {
  return classifyBrackets(text) === "balanced";
}

const PRECEDENCE = { "+": 1, "-": 1, "*": 2, "/": 2 };

function isOperator(token) {
  return Object.hasOwn(PRECEDENCE, token);
}

function shuntingYard(tokens) {
  const output = [];
  const operators = new ArrayStack();
  for (const token of tokens) {
    if (typeof token === "number") {
      output.push(token);
    } else if (isOperator(token)) {
      while (
        !operators.isEmpty() &&
        isOperator(operators.top()) &&
        PRECEDENCE[operators.top()] >= PRECEDENCE[token]
      ) {
        output.push(operators.pop());
      }
      operators.push(token);
    } else if (token === "(") {
      operators.push(token);
    } else if (token === ")") {
      while (!operators.isEmpty() && operators.top() !== "(") {
        output.push(operators.pop());
      }
      if (operators.isEmpty()) {
        throw new Error("mismatched parenthesis");
      }
      operators.pop();
    } else {
      throw new Error("unrecognized token");
    }
  }
  while (!operators.isEmpty()) {
    if (operators.top() === "(") {
      throw new Error("mismatched parenthesis");
    }
    output.push(operators.pop());
  }
  return output;
}

function evaluatePostfix(tokens) {
  const stack = new ArrayStack();
  for (const token of tokens) {
    if (typeof token === "number") {
      stack.push(token);
      continue;
    }
    if (!isOperator(token)) {
      throw new Error("unrecognized token");
    }
    if (stack.size() < 2) {
      throw new Error("malformed postfix");
    }
    const right = stack.pop();
    const left = stack.pop();
    let value;
    if (token === "+") {
      value = left + right;
    } else if (token === "-") {
      value = left - right;
    } else if (token === "*") {
      value = left * right;
    } else if (right === 0) {
      throw new Error("division by zero");
    } else {
      value = left / right;
    }
    stack.push(value);
  }
  if (stack.size() !== 1) {
    throw new Error("malformed postfix");
  }
  return stack.pop();
}

function tokenize(source) {
  const parts = source.split(" ").filter((part) => part.length > 0);
  return parts.map((part) => {
    if (/^[0-9]+$/.test(part)) {
      return Number(part);
    }
    return part;
  });
}

class TwoStackQueue {
  constructor() {
    this.inbox = new ArrayStack();
    this.outbox = new ArrayStack();
    this.transfers = 0;
  }

  enqueue(value) {
    this.inbox.push(value);
  }

  transfer() {
    if (this.outbox.isEmpty()) {
      while (!this.inbox.isEmpty()) {
        this.outbox.push(this.inbox.pop());
        this.transfers += 1;
      }
    }
  }

  dequeue() {
    this.transfer();
    if (this.outbox.isEmpty()) {
      throw new Error("queue underflow");
    }
    return this.outbox.pop();
  }

  front() {
    this.transfer();
    if (this.outbox.isEmpty()) {
      throw new Error("queue underflow");
    }
    return this.outbox.top();
  }

  isEmpty() {
    return this.inbox.isEmpty() && this.outbox.isEmpty();
  }
}

function exerciseStack(stack) {
  assert.equal(stack.isEmpty(), true);
  stack.push(1);
  stack.push(2);
  stack.push(3);
  assert.equal(stack.size(), 3);
  assert.equal(stack.top(), 3);
  assert.equal(stack.pop(), 3);
  assert.equal(stack.pop(), 2);
  assert.equal(stack.top(), 1);
  assert.equal(stack.pop(), 1);
  assert.equal(stack.isEmpty(), true);
  assert.equal(stack.size(), 0);
  assert.throws(() => stack.pop(), /stack underflow/);
  assert.throws(() => stack.top(), /stack underflow/);
}

exerciseStack(new ArrayStack());
exerciseStack(new LinkedStack());

const linked = new LinkedQueue();
linked.enqueue(10);
linked.enqueue(20);
linked.enqueue(30);
assert.equal(linked.front(), 10);
assert.equal(linked.dequeue(), 10);
linked.enqueue(40);
assert.equal(linked.dequeue(), 20);
assert.equal(linked.dequeue(), 30);
assert.equal(linked.dequeue(), 40);
assert.equal(linked.isEmpty(), true);
assert.throws(() => linked.dequeue(), /queue underflow/);
linked.enqueue(7);
assert.equal(linked.front(), 7);
assert.equal(linked.dequeue(), 7);

const queue = new CircularQueue(4);
queue.enqueue(10);
queue.enqueue(20);
queue.enqueue(30);
queue.enqueue(40);
assert.deepEqual(queue.bufferCopy(), [10, 20, 30, 40]);
assert.equal(queue.frontIndex, 0);
assert.equal(queue.count, 4);
assert.deepEqual(queue.toArray(), [10, 20, 30, 40]);
assert.equal(queue.front(), 10);

assert.equal(queue.dequeue(), 10);
assert.equal(queue.dequeue(), 20);
assert.deepEqual(queue.bufferCopy(), [10, 20, 30, 40]);
assert.equal(queue.frontIndex, 2);
assert.equal(queue.count, 2);
assert.deepEqual(queue.toArray(), [30, 40]);

queue.enqueue(50);
assert.deepEqual(queue.bufferCopy(), [50, 20, 30, 40]);
assert.equal(queue.frontIndex, 2);
assert.equal(queue.count, 3);
assert.deepEqual(queue.toArray(), [30, 40, 50]);

queue.enqueue(60);
assert.deepEqual(queue.bufferCopy(), [50, 60, 30, 40]);
assert.equal(queue.frontIndex, 2);
assert.equal(queue.count, 4);
assert.equal(queue.capacity, 4);
assert.deepEqual(queue.toArray(), [30, 40, 50, 60]);

assert.equal(queue.dequeue(), 30);
assert.equal(queue.dequeue(), 40);
assert.deepEqual(queue.bufferCopy(), [50, 60, 30, 40]);
assert.equal(queue.frontIndex, 0);
assert.equal(queue.count, 2);
assert.deepEqual(queue.toArray(), [50, 60]);
assert.equal(queue.front(), 50);

const growing = new CircularQueue(4);
growing.enqueue(10);
growing.enqueue(20);
growing.enqueue(30);
growing.enqueue(40);
assert.equal(growing.dequeue(), 10);
assert.equal(growing.dequeue(), 20);
growing.enqueue(50);
growing.enqueue(60);
growing.enqueue(70);
assert.equal(growing.capacity, 8);
assert.equal(growing.frontIndex, 0);
assert.equal(growing.count, 5);
assert.deepEqual(growing.toArray(), [30, 40, 50, 60, 70]);
assert.equal(growing.data[0], 30);
assert.equal(growing.data[1], 40);
assert.equal(growing.data[2], 50);
assert.equal(growing.data[3], 60);
assert.equal(growing.data[4], 70);
assert.equal(growing.dequeue(), 30);
assert.throws(() => new CircularQueue(0), /capacity/);

const deque = new ArrayDeque(4);
deque.addBack(1);
deque.addBack(2);
deque.addFront(0);
deque.addFront(-1);
assert.deepEqual(deque.bufferCopy(), [1, 2, -1, 0]);
assert.equal(deque.frontIndex, 2);
assert.equal(deque.count, 4);
assert.deepEqual(deque.toArray(), [-1, 0, 1, 2]);
assert.equal(deque.front(), -1);
assert.equal(deque.back(), 2);
assert.equal(deque.removeBack(), 2);
assert.equal(deque.removeFront(), -1);
assert.deepEqual(deque.toArray(), [0, 1]);
assert.equal(deque.frontIndex, 3);
assert.equal(deque.count, 2);

const growingDeque = new ArrayDeque(4);
growingDeque.addBack(1);
growingDeque.addBack(2);
growingDeque.addFront(0);
growingDeque.addFront(-1);
growingDeque.addFront(8);
assert.equal(growingDeque.capacity, 8);
assert.equal(growingDeque.frontIndex, 7);
assert.equal(growingDeque.count, 5);
assert.deepEqual(growingDeque.toArray(), [8, -1, 0, 1, 2]);
assert.equal(growingDeque.data[0], -1);
assert.equal(growingDeque.data[1], 0);
assert.equal(growingDeque.data[2], 1);
assert.equal(growingDeque.data[3], 2);
assert.equal(growingDeque.data[7], 8);
assert.throws(() => new ArrayDeque(0), /capacity/);
const emptyDeque = new ArrayDeque();
assert.throws(() => emptyDeque.removeFront(), /deque underflow/);
assert.throws(() => emptyDeque.removeBack(), /deque underflow/);

assert.equal(classifyBrackets(""), "balanced");
assert.equal(classifyBrackets("()[]{}"), "balanced");
assert.equal(classifyBrackets("{[()]}"), "balanced");
assert.equal(isBalanced("{[()]}"), true);
assert.equal(classifyBrackets("([)]"), "wrong closer");
assert.equal(classifyBrackets("(]"), "wrong closer");
assert.equal(classifyBrackets(")"), "too many closers");
assert.equal(classifyBrackets("())"), "too many closers");
assert.equal(classifyBrackets("("), "leftovers");
assert.equal(classifyBrackets("(()"), "leftovers");
assert.equal(classifyBrackets("({["), "leftovers");
assert.throws(() => classifyBrackets("(a)"), /bracket alphabet/);

const expressions = [
  {
    source: "3 + 4 * 2 / ( 1 - 5 )",
    postfix: [3, 4, 2, "*", 1, 5, "-", "/", "+"],
    value: 1,
  },
  {
    source: "8 - 3 - 2",
    postfix: [8, 3, "-", 2, "-"],
    value: 3,
  },
  {
    source: "( 2 + 3 ) * 4",
    postfix: [2, 3, "+", 4, "*"],
    value: 20,
  },
  {
    source: "2 * 3 + 4 * 5",
    postfix: [2, 3, "*", 4, 5, "*", "+"],
    value: 26,
  },
];

for (const expression of expressions) {
  const tokens = tokenize(expression.source);
  const postfix = shuntingYard(tokens);
  assert.deepEqual(postfix, expression.postfix);
  assert.equal(evaluatePostfix(postfix), expression.value);
}

assert.throws(() => shuntingYard(["(", 2, "+", 3]), /mismatched parenthesis/);
assert.throws(() => shuntingYard([2, "+", ")"]), /mismatched parenthesis/);
assert.throws(() => evaluatePostfix([2, "+"]), /malformed postfix/);
assert.throws(() => evaluatePostfix([1, 0, "/"]), /division by zero/);

const two = new TwoStackQueue();
two.enqueue(1);
two.enqueue(2);
two.enqueue(3);
assert.equal(two.dequeue(), 1);
assert.equal(two.dequeue(), 2);
two.enqueue(4);
assert.equal(two.front(), 3);
assert.equal(two.dequeue(), 3);
assert.equal(two.dequeue(), 4);
assert.equal(two.transfers, 4);
assert.equal(two.isEmpty(), true);
assert.throws(() => two.dequeue(), /queue underflow/);

console.log("ALL TESTS PASSED");
```

## Common mistakes

**Wrong idea:** The top of a singly linked stack is the tail, because the tail is the last node created.
**Correction:** The top is the end the contract reads, and the head is the end a singly linked list can change in $\Theta(1)$ time. Popping the tail walks the list and costs $\Theta(n)$.

**Wrong idea:** An array makes every removal cheap, so a queue may delete index $0$.
**Correction:** Deleting index $0$ moves every later element. $n$ such dequeues after $n$ enqueues cost $(n-1)n/2$ element moves. Move the front index, or unlink the head, instead of moving the elements.

**Wrong idea:** In a circular buffer, `frontIndex === backIndex` tells you the buffer is empty.
**Correction:** With a size counter and every slot usable, that equality holds for an empty buffer and also for a full buffer whose front has wrapped onto the back. Emptiness is `count === 0`. Fullness is `count === capacity`. The wasted-slot convention is the other repair, and this lecture does not use it.

**Wrong idea:** `(-1) % capacity` is a legal previous index.
**Correction:** In JavaScript that remainder is $-1$. The previous front index is $(\mathrm{frontIndex} - 1 + \mathrm{capacity}) \bmod \mathrm{capacity}$.

**Wrong idea:** A bracket string is balanced when each opener occurs as often as its closer.
**Correction:** `([)]` has equal counts and is a wrong closer. The stack stores the unmatched openers, and only the top may match the next closer.

**Wrong idea:** Shunting-yard should pop the operator stack only when the top has strictly greater precedence.
**Correction:** Equal precedence is left association for `+`, `-`, `*`, and `/`. The test is $\geq$. The strict test turns $8 - 3 - 2$ into $8 \; 3 \; 2 \; - \; -$, whose value is $7$ rather than $3$.

**Wrong idea:** Postfix evaluation pops the left operand first.
**Correction:** The right operand was pushed later, so it is on top. Pop the right operand, then the left, and compute left operator right. Reversing them changes subtraction and division.

**Wrong idea:** "Dijkstra" in this lecture means the shortest-path algorithm.
**Correction:** Part 9 is the shunting-yard translation from Dijkstra's 1961 ALGOL 60 report. Shortest paths are Lecture 13.

**Wrong idea:** Because the two-stack queue is amortized $\Theta(1)$, every `dequeue` is $\Theta(1)$ in the worst case.
**Correction:** A `dequeue` that finds an empty outbox and an inbox of $k$ elements costs $\Theta(k)$. The $\Theta(1)$ bound is the aggregate over a sequence: the sum of those transfers is at most the number of enqueues.

**Wrong idea:** After a linked queue dequeues its last element, only `head` needs to become `null`.
**Correction:** `tail` must become `null` as well. Otherwise the next `enqueue` attaches its node to an unlinked tail, and `head` never sees it.

---

## Examination

Write full solutions. Do not consult the answer key until you have attempted every question. The operations and formulas are those defined in the lecture.

**Question 1.** Specify the stack, the queue, and the deque. For each contract, name the operations, the order of removal, and one access the contract does not provide. State what `pop` does on an empty stack.

**Question 2.** A singly linked stack stores its top at the head. Explain why, and give the worst-case cost of `push`, `pop`, and `top`. Give the cost of `pop` if the tail were the top. For the dynamic-array stack, give the amortized cost and the worst-case cost of `push`, and the worst-case cost of `pop`.

**Question 3.** At the moment `inner` has assigned `total` and has not yet returned, list both frames. For each frame give the return address's destination, the parameters, and the locals, and say which frame is the top.

```javascript
function inner(a, b) {
  const total = a + b;
  return total;
}

function outer() {
  const value = inner(4, 6);
  return value;
}
```

**Question 4.** A queue is stored in an array with the front fixed at index $0$. `dequeue` moves every later element one slot left. Consider $n$ enqueues into an empty queue, followed by $n$ dequeues. Derive the number of element moves performed by the dequeues, as a closed form in $n$. Evaluate the form at $n = 6$ by writing the sum.

**Question 5.** A circular buffer has capacity $5$, `frontIndex` $0$, and `count` $0$. Perform `enqueue` of $1, 2, 3, 4, 5$, then `dequeue`, `dequeue`, `enqueue(6)`, `enqueue(7)`, `dequeue`. Use the size-counter formulas. After `enqueue(6)`, after `enqueue(7)`, and after the last `dequeue`, give the physical array, `frontIndex`, `count`, and the logical queue from oldest to newest. Give the value returned by the last `dequeue`. Stale values stay in the array.

**Question 6.** A full wrapped buffer has capacity $4$, physical contents $[8, 6, 2, 4]$, `frontIndex` $2$, and `count` $4$. It grows by doubling and re-indexes in logical order. Give the new capacity, the new `frontIndex`, and the eight physical slots after the copy and before the next write. Separately: a deque of capacity $8$ has `frontIndex` $0$, `count` $3$, and live values $a, b, c$ in slots $0, 1, 2$. It executes `addFront(9)` with no growth. Give the new `frontIndex`, the slot that receives $9$, and the logical sequence.

**Question 7.** State the circular-buffer invariant I, including the role of a stale slot.

**Question 8.** Classify each string. Name the failure or say that it is balanced, and give the stack from bottom to top at the moment of that decision.

1. `{[()]}`
2. `([)]`
3. `{[}`
4. `(()`

**Question 9.** Convert $2 * (3 + 4) - 5$ to postfix with shunting-yard. Give the output and the operator stack, bottom to top, after every token and after the final flush. Evaluate the postfix on a stack, showing the stack after every token, and give the value. State which grammar production makes the parentheses change the order relative to $2 * 3 + 4 - 5$. You do not need to convert $2 * 3 + 4 - 5$ fully; name the postfix operator order that the parentheses replaced.

**Question 10.** A two-stack queue starts empty. Perform `enqueue(10)`, `enqueue(20)`, `dequeue`, `enqueue(30)`, `enqueue(40)`, `dequeue`, `dequeue`, `dequeue`. Show the inbox and the outbox from bottom to top after each operation, the value returned by each `dequeue`, and the transfer count $t$ of each `dequeue`. Using cost $2t + 1$ per `dequeue`, add the four dequeue costs. Then, for a general sequence of $N$ enqueues, dequeues, and fronts on an initially empty queue, argue that the total number of transfers $T$ is at most the number of enqueues, and that the sum of all stack primitives in the sequence is at most $3N$.

**Question 11.** Name two client demands for which a stack, queue, or deque is the wrong structure. For each demand, name a structure from this course that provides the missing operation, and name the lecture that owns it.

---

## Answer key

**Question 1.** A stack provides `push(x)`, `pop()`, `top()`, and `isEmpty()`. Removal is last-in, first-out: `pop` returns the most recently pushed element that is still present. The contract does not provide access by index. `pop` on an empty stack raises underflow.

A queue provides `enqueue(x)`, `dequeue()`, `front()`, and `isEmpty()`. Removal is first-in, first-out: `dequeue` returns the oldest element still present. The contract does not provide removal of the newest element.

A deque provides `addFront(x)`, `addBack(x)`, `removeFront()`, `removeBack()`, `front()`, `back()`, and `isEmpty()`. Each removal takes the element at the named end. The contract does not provide search by key.

**Question 2.** A singly linked list inserts and deletes at the head by rewriting one link, in $\Theta(1)$ worst-case time. The stack's top is that head, so `push`, `pop`, and `top` are $\Theta(1)$ worst case. If the tail were the top, `pop` would need the predecessor of the tail. A singly linked list does not store that predecessor, so the walk from the head costs $\Theta(n)$.

On the dynamic-array stack the top is the last index. `push` is an append: $\Theta(1)$ amortized and $\Theta(n)$ worst case when the block doubles and is copied. `pop` removes the last element and is $\Theta(1)$ worst case.

**Question 3.** The `inner` frame is the top, because its call is the later push.

The `outer` frame has return address equal to the continuation of whoever called `outer`. It has no parameters in this definition. Its local `value` is not yet assigned, because the assignment is the return address of `inner`.

The `inner` frame has return address equal to the assignment `value = ...` inside `outer`. Its parameters are $a = 4$ and $b = 6$. Its local `total` is $4 + 6 = 10$.

**Question 4.** After $n$ enqueues the array holds $n$ elements. The dequeue that leaves $k$ elements still to move, for $k$ from $n-1$ down to $0$, moves $k$ elements.

$$
\sum_{k=0}^{n-1} k = \frac{(n-1)n}{2}
$$

At $n = 6$ the sum is $5 + 4 + 3 + 2 + 1 + 0 = 15$, and $(5 \cdot 6) / 2 = 15$. The closed form is $\Theta(n^2)$.

**Question 5.** Capacity $5$. Indexes are $0$ through $4$.

Five enqueues fill $[1, 2, 3, 4, 5]$ with `frontIndex` $0$ and `count` $5$. The first dequeue returns $1$ and sets `frontIndex` to $1$, `count` $4$. The second returns $2$ and sets `frontIndex` to $2$, `count` $3$. The logical queue is $3, 4, 5$. The physical array is still $[1, 2, 3, 4, 5]$, with $1$ and $2$ stale.

`enqueue(6)` writes at $(2 + 3) \bmod 5 = 0$.

- Physical array: $[6, 2, 3, 4, 5]$
- `frontIndex` $2$, `count` $4$
- Logical queue: $3, 4, 5, 6$

`enqueue(7)` writes at $(2 + 4) \bmod 5 = 1$.

- Physical array: $[6, 7, 3, 4, 5]$
- `frontIndex` $2$, `count` $5$
- Logical queue: $3, 4, 5, 6, 7$

The last `dequeue` returns the oldest element, $3$, and sets `frontIndex` to $3$, `count` $4$.

- Physical array: $[6, 7, 3, 4, 5]$
- `frontIndex` $3$, `count` $4$
- Logical queue: $4, 5, 6, 7$
- Returned value: $3$

The live ranks after that dequeue are index $3 \to 4$, index $4 \to 5$, index $0 \to 6$, and index $1 \to 7$.

**Question 6.** The live order before growth is index $(2+i) \bmod 4$ for $i = 0, 1, 2, 3$:

- $i = 0$ reads index $2$, value $2$
- $i = 1$ reads index $3$, value $4$
- $i = 2$ reads index $0$, value $8$
- $i = 3$ reads index $1$, value $6$

The new capacity is $8$. The new `frontIndex` is $0$. The physical slots are $[2, 4, 8, 6, \_, \_, \_, \_]$.

`addFront(9)` does not grow, because `count` is $3$ and the capacity is $8$. The new front index is $(0 - 1 + 8) \bmod 8 = 7$. Slot $7$ receives $9$. The logical sequence is $9, a, b, c$.

**Question 7.** Invariant I: if the logical queue from oldest to newest is $q_0, \ldots, q_{\mathrm{count}-1}$, then $\mathrm{data}[(\mathrm{frontIndex} + i) \bmod \mathrm{capacity}] = q_i$ for every $i$ with $0 \leq i < \mathrm{count}$, and $0 \leq \mathrm{count} \leq \mathrm{capacity}$, and `frontIndex` is a legal index. A stale slot holds a value left by an earlier removal. It is outside the set of live residues, so it is not an element of the queue.

**Question 8.**

1. `{[()]}` is balanced. The stack finishes empty. The intermediate stacks are `{`, then `{ [`, then `{ [ (`, then `{ [` after `)`, then `{` after `]`, then empty after `}`.
2. `([)]` is a wrong closer. After `(` and `[` the stack is `(`, `[`. The `)` requires `(`, and the top is `[`.
3. `{[}` is a wrong closer. After `{` and `[` the stack is `{`, `[`. The `}` requires `{`, and the top is `[`.
4. `(()` is leftovers. `(` pushes, the second `(` pushes, `)` pops once, and the final stack is `(`.

**Question 9.** Operator stack from bottom to top:

| Token | Output | Operator stack |
| --- | --- | --- |
| $2$ | $2$ | empty |
| $*$ | $2$ | `*` |
| `(` | $2$ | `*` `(` |
| $3$ | $2 \; 3$ | `*` `(` |
| $+$ | $2 \; 3$ | `*` `(` `+` |
| $4$ | $2 \; 3 \; 4$ | `*` `(` `+` |
| `)` | $2 \; 3 \; 4 \; +$ | `*` |
| $-$ | $2 \; 3 \; 4 \; + \; *$ | `-` |
| $5$ | $2 \; 3 \; 4 \; + \; * \; 5$ | `-` |
| end | $2 \; 3 \; 4 \; + \; * \; 5 \; -$ | empty |

At `)`, the top `+` is popped and `(` is discarded. At `-`, the top `*` has higher precedence, so `*` is popped before `-` is pushed.

Postfix evaluation, stack bottom to top:

| Token | Stack |
| --- | --- |
| $2$ | $2$ |
| $3$ | $2 \; 3$ |
| $4$ | $2 \; 3 \; 4$ |
| $+$ | $2 \; 7$ |
| $*$ | $14$ |
| $5$ | $14 \; 5$ |
| $-$ | $9$ |

The addition pops $4$ and $3$ and pushes $3 + 4 = 7$. The multiplication pops $7$ and $2$ and pushes $2 \cdot 7 = 14$. The subtraction pops $5$ and $14$ and pushes $14 - 5 = 9$.

The parentheses are the factor production $F \to (E)$. They force `+` to be emitted before `*`, so the postfix applies `+` and then `*`. Without those parentheses, $2 * 3 + 4 - 5$ emits `*` before the first `+`, and the postfix operator order ends $2 \; 3 \; * \; 4 \; + \; 5 \; -$.

**Question 10.** Stacks are bottom to top.

| Operation | Inbox | Outbox | Result | $t$ |
| --- | --- | --- | --- | --- |
| enqueue $10$ | $10$ | empty | | |
| enqueue $20$ | $10 \; 20$ | empty | | |
| dequeue | empty | $20$ | $10$ | $2$ |
| enqueue $30$ | $30$ | $20$ | | |
| enqueue $40$ | $30 \; 40$ | $20$ | | |
| dequeue | $30 \; 40$ | empty | $20$ | $0$ |
| dequeue | empty | $40$ | $30$ | $2$ |
| dequeue | empty | empty | $40$ | $0$ |

The first transfer pushes $20$ and then $10$, so the outbox top is $10$, and the pop returns $10$, leaving outbox $[20]$. The third dequeue transfers $40$ then $30$, pops $30$, and leaves $[40]$. The returned values are $10, 20, 30, 40$.

Dequeue costs: $2 \cdot 2 + 1 = 5$, $2 \cdot 0 + 1 = 1$, $2 \cdot 2 + 1 = 5$, $2 \cdot 0 + 1 = 1$. The sum is $5 + 1 + 5 + 1 = 12$. The transfer total is $2 + 0 + 2 + 0 = 4$, and $2 \cdot 4 + 4 = 12$.

In any legal sequence, a transfer runs only when the outbox is empty, and it moves each inbox element onto the outbox. An element is enqueued once and is transferred at most once, because after the transfer it sits on the outbox until a dequeue pops it. Therefore $T \leq E$.

`enqueue` costs one push, a transfer of one element costs one pop and one push, `dequeue` costs one further pop, and `front` costs one top. With $E + D_q + F = N$,

$$
E + 2T + D_q + F \leq E + 2E + D_q + F = 2E + N \leq 3N
$$

The sum of the stack primitives is at most $3N$.

**Question 11.** A client that needs the element at an arbitrary index needs a dynamic array, owned by Lecture 02. A client that needs search by key needs a binary search tree, owned by Lecture 08, or a hash table, owned by Lecture 11. Draining a stack or a queue until that element appears costs linear time and removes the elements in front of it.

---

## Independent assignment

Produce one JavaScript file, `end-structures-workbench.js`, and keep it. Budget several hours. The file must run under Node with no libraries and must print `ALL TESTS PASSED`.

1. Implement a doubly linked deque with `addFront`, `addBack`, `removeFront`, `removeBack`, `front`, `back`, and `isEmpty`, using `null` for a missing link. Include the empty-deque updates of both `head` and `tail`.
2. Check it against the circular `ArrayDeque` from this lecture on this fixed script, asserting that both structures return the same value on every removal and the same `front` and `back` after every addition: `addBack(1)`, `addBack(2)`, `addFront(0)`, `addFront(-1)`, `addFront(8)`, `removeBack`, `removeFront`, `addBack(9)`, `addBack(10)`, `removeBack`, `removeFront`, `removeFront`, `removeBack`, `removeFront`. The returned removals are $2$, $8$, $10$, $-1$, $0$, $9$, $1$. After that script both deques are empty, and one further removal on the linked deque throws.
3. Extend bracket classification so a failure report includes the index of the bad character and, for a wrong closer, the opener that was on top. Run it on `([)]`, `{[}`, `())`, and `(()`, and assert the index and the kind.
4. Implement a tracer that records the output list and the operator stack after every token of shunting-yard. Run it on the four lecture expressions and on eight further expressions you choose. At least two of the eight must nest parentheses two deep. At least two must be left-associative chains of three identical operators, one chain additive and one multiplicative. Assert the value of each expression by an independent parenthesization you write next to it. Reject a token list that uses a unary minus.
5. At the top of the file, in comments, give the aggregate tally of this operation sequence on an initially empty two-stack queue: enqueue $1$ through $6$, dequeue, dequeue, dequeue, enqueue $7$, dequeue, dequeue, enqueue $8$, dequeue, dequeue, dequeue. Show every inbox and outbox, every $t$, the sum of the dequeue costs $2t+1$, and the comparison of the primitive count with $3N$. The program runs the same sequence and asserts the returned values and the transfer total.

The artifact is the file: the linked deque, the failure indexes, the twelve traced expressions, and the written aggregate tally that the assertions agree with.

---

## Glossary

**Back.** The newest end of a deque. `back()` returns that element. `removeBack` removes it.

**Back index.** The array slot where the next `enqueue` or `addBack` writes, $(\mathrm{frontIndex} + \mathrm{count}) \bmod \mathrm{capacity}$.

**Balanced string.** A string in the smallest set $B$ that contains the empty string, is closed under wrapping with `()`, `[]`, and `{}`, and is closed under concatenation.

**Barrier.** A left parenthesis on the operator stack. Operator-popping loops stop at a barrier so that symbols inside parentheses are resolved before symbols outside them.

**Call stack.** The stack of frames of calls that have started and have not returned. The current call is the top.

**Capacity.** The number of slots in a circular buffer. The size ranges from $0$ to the capacity inclusive.

**Circular buffer.** An array queue or deque in which the live elements occupy a contiguous modular interval, so an index wraps from the last slot to slot $0$.

**Closer.** One of `)`, `]`, and `}`.

**Deque.** A double-ended queue: a sequence with insertion, removal, and inspection at both ends, and with no index operation.

**Dequeue.** The queue operation that removes and returns the oldest element.

**Enqueue.** The queue operation that inserts an element at the back.

**First-in, first-out.** The queue order: the oldest surviving element is the one `dequeue` returns.

**Frame.** The record pushed for one function call. It holds a return address, the parameters, and the locals.

**Front.** The oldest end of a queue or deque. `front()` returns that element and does not remove it.

**Front index.** The array slot that holds the oldest live element of a circular buffer.

**Inbox.** The stack of a two-stack queue that receives `enqueue`. Its top is the newest element that has not been transferred.

**Infix.** Notation in which a binary operator is written between its operands.

**Last-in, first-out.** The stack order: `pop` returns the most recently pushed element that is still present.

**Left-associative.** The rule that equal-precedence operators group to the left. $8 - 3 - 2$ means $(8 - 3) - 2$. In shunting-yard the operator test uses $\geq$.

**Leftovers.** The bracket failure in which the input has ended and the stack still holds openers.

**Opener.** One of `(`, `[`, and `{`.

**Operator stack.** The stack of operators and left parentheses waiting during shunting-yard.

**Outbox.** The stack of a two-stack queue from which `dequeue` pops. After a transfer, its top is the oldest element.

**Overflow.** The error a fixed-capacity buffer raises when an insertion would exceed its capacity. The growing buffers in this lecture allocate instead.

**Pop.** The stack operation that removes and returns the top.

**Postfix.** Notation in which both operands of an operator are written before the operator. Also called Reverse Polish notation.

**Precedence.** The binding strength of an operator. In this lecture, `*` and `/` have precedence $2$, and `+` and `-` have precedence $1$.

**Push.** The stack operation that inserts an element at the top.

**Queue.** A sequence whose insertion is at the back, whose removal and inspection are at the front, and whose order is first-in, first-out.

**Re-indexing.** The growth copy that writes live circular-buffer elements into indexes $0, 1, \ldots, \mathrm{count}-1$ of a doubled array and sets the front index to $0$.

**Return address.** The place in the caller where execution continues when this frame is popped.

**Reverse Polish notation.** Postfix notation.

**Shunting-yard algorithm.** Dijkstra's algorithm that converts an infix token sequence into postfix by sending numbers to the output and holding operators on a stack until precedence or a parenthesis forces them out.

**Size counter.** The integer `count` of live elements in a circular buffer. It distinguishes empty from full without leaving a slot unused.

**Stack.** A sequence whose insertion, removal, and inspection all occur at the top, in last-in, first-out order.

**Stale slot.** An array slot that still holds a value after that value has been dequeued or removed. Invariant I does not count it as an element.

**Token.** One number, operator, or parenthesis in an expression, already separated from its neighbors.

**Top.** The most recently pushed element that is still on a stack. `top()` returns it and leaves the stack unchanged.

**Transfer.** The move of every inbox element onto the outbox, performed when a dequeue or a front finds the outbox empty. Each element is transferred at most once.

**Two-stack queue.** A queue represented by an inbox stack and an outbox stack.

**Underflow.** The error raised by `pop`, `top`, `dequeue`, `front`, `removeFront`, `removeBack`, or `back` when the structure is empty.

**Wasted-slot convention.** A circular buffer that stores no size and leaves one array slot empty so that `frontIndex === backIndex` means empty and the next back index meeting the front means full. This lecture describes it and does not implement it.

**Wrap.** A modular index step that moves from the last array slot to slot $0$, or that writes in that way. The lecture's trace has two write wraps and one front-index wrap.

**Wrong closer.** The bracket failure in which a closer arrives while the stack is nonempty and the top opener is a different pair.

---

## Lecture summary

A stack, a queue, and a deque are end-only contracts. The stack implementation puts the top at the cheap end of the representation: the last index of a dynamic array, or the head of a singly linked list. The queue implementation keeps both ends cheap: head and tail of a singly linked list, or a front index and a size in a circular buffer. The deque uses that circular buffer at both ends, or a doubly linked list whose predecessor pointer makes `removeBack` constant. The call stack is the same stack contract applied to frames.

The circular buffer is correct because the live elements are exactly the size-many residues that begin at the front index. Growth copies those residues in order and only then writes the new element. Brackets are correct because the stack is the unmatched-opener spine of a balanced decomposition, proved by induction on the length of the string. Shunting-yard is correct because its output, once the pending operators of a grammar phrase are flushed, is the postfix of the unique precedence parse; the postfix machine then computes that value, proved by induction on the postfix expression. The two-stack queue is correct because a transfer reverses the inbox onto the outbox without changing front-to-back order, and its dequeue is amortized $\Theta(1)$ because each element is transferred at most once, so a sequence of $N$ operations performs at most $3N$ stack primitives.

### Five principles

1. State the operations and the order before choosing a layout. Cost is a fact about the layout.
2. Put the end the contract touches on the end the representation can change in constant time.
3. A circular buffer moves an index and leaves elements in place. The size counter keeps every slot usable and keeps empty distinct from full.
4. A stack remembers what is still open: an unmatched bracket, an operator waiting for precedence, or a function frame.
5. Amortized $\Theta(1)$ is a bound on a sequence. One two-stack dequeue may still move every waiting element, and the aggregate of those moves stays linear in the number of operations.

---

## References

1. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapter 10, Elementary Data Structures. Chapter 17, Amortized Analysis, for the aggregate method used in Part 10.
2. Robert Sedgewick and Kevin Wayne. *Algorithms*. 4th edition. Addison-Wesley, 2011. Section 1.3, Bags, Queues, and Stacks.
3. Michael T. Goodrich, Roberto Tamassia, and Michael H. Goldwasser. *Data Structures and Algorithms in Java*. 6th edition. Wiley, 2014. Chapter 6, Stacks, Queues, and Deques.
4. Mark Allen Weiss. *Data Structures and Algorithm Analysis in C++*. 4th edition. Pearson, 2014. Chapter 3, Lists, Stacks, and Queues.
5. Donald E. Knuth. *The Art of Computer Programming*. Volume 1, *Fundamental Algorithms*. 3rd edition. Addison-Wesley, 1997. Section 2.2.1, Stacks, Queues, and Deques.
6. Edsger W. Dijkstra. *ALGOL-60 Translation*. ALGOL Bulletin Supplement no. 10. Mathematisch Centrum, Amsterdam, November 1961. The report contains "Making a Translator for ALGOL 60," whose operator stack is the shunting-yard conversion. That conversion is not the shortest-path algorithm.
