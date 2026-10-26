# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 02 — ARRAYS, DYNAMIC ARRAYS, AND AMORTIZED ANALYSIS

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 02 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 8 hours
**Prerequisites:** Lecture 01 — Models, ADTs, and Asymptotic Analysis
**Primary references:** Cormen, Leiserson, Rivest, and Stein, 4th edition, Chapter 16 and Section 10.1; Sedgewick and Wayne, 4th edition, Section 1.3; Goodrich, Tamassia, and Goldwasser, 6th edition, Section 7.2; Knuth, Volume 1, 3rd edition, Section 2.2.6; Tarjan, 1985

**This lecture owns:** Contiguous storage, static and dynamic arrays, geometric resizing, and amortized analysis by the aggregate, accounting, and potential methods.
**This lecture does not teach:** Linked lists, and stacks or queues as abstract data types. A stack can sit on an array by using append as push and delete-at-end as pop; that sentence is the whole of the stack in this lecture. Linked lists are Lecture 03. The stack, queue, and deque ADTs are Lecture 04.

Sit with a pencil. When a table appears, cover the next row and produce it before you read it. The examination is closed-notes relative to any book; this file is the source you are learning, and you should attempt the examination before you read the answer key.

---

## LEARNING OBJECTIVES

After this lecture you can:

1. Compute the address of an array element from a base address, a zero-based index, and a fixed element width, and state the RAM-model cost of `get`, `set`, and `length`.
2. State the fixed-width assumption, and name a layout for which the closed-form address formula is false.
3. Explain, in terms of neighboring addresses, why a sequential scan of an array cooperates with a memory cache, without quoting a cycle count.
4. Insert and delete at a chosen index of a static array, count the element moves, and conclude that both operations are $\Theta(n)$ in the worst case.
5. Implement a dynamic array on a fixed-capacity store so that every resize copy is visible in a counter.
6. State the doubling rule and the quarter-capacity shrink rule, and prove that a growth and a shrinkage are separated by a linear number of operations.
7. Prove by the aggregate method that $n$ doubling appends, starting from capacity $1$, copy fewer than $2n$ elements, including when $n$ is not one past a power of two, and conclude that append is amortized $\Theta(1)$ and worst-case $\Theta(n)$.
8. Prove the same append bound by the accounting method, charging $3$ units and storing $2$ as credit, and show the credit stock never goes negative.
9. Prove the same append bound by the potential method with $\Phi = 2 \cdot \mathrm{size} - \mathrm{capacity}$, including nonnegativity and the telescope.
10. Compute the aggregate copy cost of the policy that adds one slot at a time, and state that amortized cost as $\Theta(n)$.
11. Map a row-major position $(i, j)$ to the flat index $i \cdot \mathrm{cols} + j$, and compare the address stride of a row walk with the address stride of a column walk.
12. Compute the number of code-unit copies performed by $n$ successive string concatenations, and implement a character buffer whose measured resize cost is linear.
13. Name an operation mix for which doubling does not make an update amortized $\Theta(1)$, and name the lecture that owns the structure built for frequent insertion at the front.

---

## PURPOSE

An array is the layout in which the $i$-th element lives at an address you can calculate. That single fact gives constant-time random access, and it is also the reason insertion in the middle has to move neighbors. A dynamic array keeps the address formula by allocating a new contiguous block when the old one is full. The cost of a single growth is proportional to the number of live elements. The cost of a long sequence of growths is not proportional to $n$ per operation, provided the block grows geometrically. Making that sentence a theorem, three different ways, is the analysis this lecture exists to teach.

Lecture 01 fixed the RAM model and the meanings of $O$, $\Omega$, and $\Theta$. This lecture uses those meanings. A bound written $\Theta(f(n))$ is tight. A bound written $O(f(n))$ is only an upper bound. $\log$ is base $2$. Indexes start at $0$.

The lecture deliberately stops before linked lists. When a later paragraph says that a pointer-based layout has no neighboring-address guarantee, it is talking about addresses, not about how to splice a node. When it says a stack can sit on this array, it is naming a representation, not defining the stack ADT.

---

## PART 1 — THE ARRAY ABSTRACT DATA TYPE

### 1.1 The specification

An **array** is a finite sequence $a_0, a_1, \ldots, a_{n-1}$ together with these operations.

| Operation | Precondition | Effect | Cost proved in this part |
| --- | --- | --- | --- |
| $\mathrm{length}()$ | none | returns $n$ | $\Theta(1)$ |
| $\mathrm{get}(i)$ | $0 \le i < n$ | returns $a_i$ | $\Theta(1)$ |
| $\mathrm{set}(i, x)$ | $0 \le i < n$ | replaces $a_i$ by $x$ | $\Theta(1)$ |

$n$ is the **size**, also called the length. The three operations are the array ADT. Insertion and deletion are extra sequence operations. They are specified in Part 3, and they are not constant-time operations.

`length` is a stored integer. It is not computed by walking the slots. A walk would be $\Theta(n)$.

### 1.2 Contiguous storage and the address formula

**Contiguous storage** means the elements occupy consecutive addresses, one after another, with no gaps and no per-element link.

Let $B$ be the **base address**, the address of element $0$. Let $w$ be the **element width**, the number of addressable units occupied by one element. The address of index $i$ is

$$
\mathrm{address}(i) = B + i \cdot w.
$$

**Fixed-width assumption.** $w$ is a constant. It does not depend on $i$, on $n$, or on the value stored at $i$.

**Theorem.** Under the fixed-width assumption, in the RAM model, `get` and `set` are $\Theta(1)$.

**Proof.** The formula uses one multiplication and one addition. Lecture 01 charges $\Theta(1)$ for each arithmetic operation on a word, and $\Theta(1)$ for a read or a write at a computed address. A failed precondition is rejected by comparing $i$ with $0$ and with $n$, which is also $\Theta(1)$. The matching lower bound is $\Omega(1)$ because the operation performs at least one memory access. The tight bound is $\Theta(1)$.

If the records had widths $w_0, w_1, \ldots$ that depended on the values, the address of index $i$ would be $B + \sum_{k=0}^{i-1} w_k$. That sum is not a constant-time formula. Fixed width is the assumption that removes the sum.

**Worked address.** Base $B = 1000$, width $w = 8$, index $3$.

$$
\mathrm{address}(3) = 1000 + 3 \cdot 8 = 1024.
$$

The laboratory program checks $1024$.

### 1.3 What a JavaScript slot actually holds

In this course the contiguous block stores JavaScript values in slots of one fixed width: the width of a reference. A number, a short string, and a reference to a large object each occupy one slot in the array. The large object itself may sit elsewhere. Indexing is constant-time because the slot width is constant, not because every object in the program has the same size.

The same arithmetic is exact only while the index, the width, and the address are safe integers. A JavaScript number is an exact integer for every integer in the closed range from $-(2^{53}-1)$ to $2^{53}-1$. That upper endpoint is `Number.MAX_SAFE_INTEGER`, the value $9007199254740991$. Past it, two different integers can round to the same number, and the address formula can name the wrong slot. Every implementation in this lecture throws when a capacity or an index would leave that range. Every concrete $n$ in the lecture is far below it.

---

## PART 2 — MEMORY LOCALITY

A sequential scan reads indexes $0, 1, 2, \ldots$. The address formula sends those reads to $B$, $B+w$, $B+2w$, and so on: neighboring addresses, a constant distance apart. A cache moves memory in blocks, so the block fetched for one element often already contains the next elements, and the scan reuses it. A layout that reaches its successor by reading a link and jumping to whatever address that link holds has no such promise, because the allocator may have placed the successor anywhere. The RAM model charges the same constant for every word access and does not contain caches, so this difference changes no $\Theta$ bound proved in that model. It is a fact about machines. This lecture assigns no cycle count to it. The fact you may use is the qualitative one: on a scan, contiguous storage is the layout whose successive addresses are neighbors.

---

## PART 3 — STATIC ARRAYS

### 3.1 Capacity

A **static array** has a fixed **capacity** $C$, chosen when the block is allocated. The size $n$ satisfies $0 \le n \le C$. Indexes $0$ through $n-1$ hold the sequence. Indexes $n$ through $C-1$ are unused. `get` and `set` still use the address formula, so they stay $\Theta(1)$. The new operations are the ones that change $n$ at an arbitrary position.

**Insert at index $k$**, with precondition $0 \le k \le n$ and $n < C$. The postcondition is the sequence $a_0, \ldots, a_{k-1}, x, a_k, \ldots, a_{n-1}$, and the size is $n+1$. If $n = C$, the static array has no free slot. That overflow is a failed precondition, not a resize. Resizing begins in Part 5.

**Delete at index $k$**, with precondition $0 \le k < n$. The postcondition is the sequence with $a_k$ removed and the later elements closed up. The size is $n-1$.

### 3.2 Why the elements must move

The address formula assigns each index a unique address. After an insertion at $k$, the old $a_k$ has to occupy the address that belongs to index $k+1$. Every later element has the same problem. The implementation moves them, one slot toward the high indexes, before it writes $x$. The loop runs from the old last element downward. Running it upward overwrites a value that has not yet been copied.

```javascript
function insertStatic(slots, size, index, value) {
  if (size >= slots.length) {
    throw new Error("overflow");
  }
  if (!Number.isInteger(index) || index < 0 || index > size) {
    throw new Error("index out of range");
  }
  let moves = 0;
  for (let i = size; i > index; i -= 1) {
    slots[i] = slots[i - 1];
    moves += 1;
  }
  slots[index] = value;
  return { size: size + 1, moves };
}
```

The loop body executes $n - k$ times. Each execution writes one element. Call that write a **move**. Deletion runs the other way and executes $n - 1 - k$ times:

```javascript
function deleteStatic(slots, size, index) {
  if (!Number.isInteger(index) || index < 0 || index >= size) {
    throw new Error("index out of range");
  }
  let moves = 0;
  for (let i = index; i < size - 1; i += 1) {
    slots[i] = slots[i + 1];
    moves += 1;
  }
  slots[size - 1] = null;
  return { size: size - 1, moves };
}
```

The tail slot is set to `null` so the deleted value is not retained in an unused slot. That one write is $\Theta(1)$.

**Theorem.** Insertion at an arbitrary index of a static array is $\Theta(n)$ in the worst case. Deletion at an arbitrary index is $\Theta(n)$ in the worst case.

**Proof.** Insertion performs $n - k$ moves and $n - k \le n$, so the cost is $O(n)$. The case $k = 0$ performs $n$ moves, so the cost is $\Omega(n)$. The tight bound is $\Theta(n)$. Deletion performs $n - 1 - k$ moves, which is $O(n)$, and the case $k = 0$ performs $n - 1$ moves, which is $\Omega(n)$. The case $k = n$ for insertion, and the case $k = n - 1$ for deletion, performs no moves and is $\Theta(1)$. The worst case is the bound this course quotes unless a sentence names a different case.

### 3.3 A numeric trace

Capacity $8$, size $6$, sequence $[10, 20, 30, 40, 50, 60]$. Insert $99$ at index $2$. Four elements sit at indexes $2$ through $5$, so the move count must be $6 - 2 = 4$. The loop copies from the right.

```text
index    0   1   2   3   4   5   6   7
start   10  20  30  40  50  60
i = 5   10  20  30  40  50  60  60
i = 4   10  20  30  40  50  50  60
i = 3   10  20  30  40  40  50  60
i = 2   10  20  30  30  40  50  60
write   10  20  99  30  40  50  60
```

Size is now $7$. Delete index $3$, which holds $30$. Three elements sit strictly after index $3$, so the move count must be $7 - 1 - 3 = 3$.

```text
index    0   1   2   3   4   5   6   7
start   10  20  99  30  40  50  60
i = 3   10  20  99  40  40  50  60
i = 4   10  20  99  40  50  50  60
i = 5   10  20  99  40  50  60  60
clear   10  20  99  40  50  60
```

Size is $6$. The live sequence is $[10, 20, 99, 40, 50, 60]$. The laboratory program asserts both arrays and both move counts.

---

## PART 4 — JAVASCRIPT ARRAYS AND THE STRUCTURE YOU IMPLEMENT

A JavaScript array already grows. An assignment past the end, and `Array.prototype.push`, are dynamic-array operations supplied by the language. Engines may store that array as a packed contiguous block, as a block with holes, or as a dictionary of properties, and they may change representation as the array is used. Those choices are engine-specific. A proof in this course does not rest on them, and a call to `push` is not an explanation of the cost.

You will implement a `DynamicArray` on top of a fixed-capacity store. The store is allocated with `new Array(capacity)` at a capacity you choose. Growth allocates a second store and copies live elements one index at a time. A field `copyCount` records those copies. The cost is then a number you can put next to a theorem. The language array used as the store is only a block of slots. It is not the structure under analysis, and the implementation never calls `push`.

---

## PART 5 — GEOMETRIC GROWTH AND A SHRINK POLICY

### 5.1 The representation invariant

A `DynamicArray` has:

- `slots`, a fixed store, or `null` when the capacity is $0$
- `capacity`, the number of slots
- `size`, the number of live elements
- `copyCount`, the number of live elements written during resizes
- `moveCount`, the number of live elements written during shifts

After every public operation the following hold.

1. $0 \le \mathrm{size} \le \mathrm{capacity}$.
2. The capacity is $0$ or a power of two.
3. The live sequence is `slots[0]` through `slots[size - 1]`.
4. If the capacity is at least $2$, then $\mathrm{size} > \lfloor \mathrm{capacity} / 4 \rfloor$. The store is never left in a state that still owes a shrink.

Empty starts at size $0$, capacity $0$, `slots === null`. The first insertion allocates capacity $1$ and copies nothing.

**Load factor.** When the capacity is positive, the load factor is $\alpha = \mathrm{size} / \mathrm{capacity}$.

### 5.2 Doubling

**Geometric growth** here means doubling. If an insertion of one element finds $\mathrm{size} = \mathrm{capacity}$, the new capacity is $1$ when the old capacity is $0$, and twice the old capacity otherwise. The live elements are copied, then the shift runs, then the new element is written. Growth happens before the shift, because the shift writes one past the old last index and needs a slot there.

The worst case of one append is $\Theta(n)$: the table can be full, and the copy loop writes $n$ elements. Parts 6 through 8 prove what a sequence of those appends costs. They do not change this worst case.

### 5.3 The shrink rule

Repeated deletion can leave a huge store holding a few elements. The **shrink rule** used in this lecture: after a deletion has decreased the size by $1$, if the capacity is at least $2$ and

$$
\mathrm{size} \le \left\lfloor \frac{\mathrm{capacity}}{4} \right\rfloor,
$$

allocate a store of half the capacity and copy the live elements. For every capacity this implementation actually reaches, that test is the load factor falling to $1/4$ or below. Capacity $2$ shrinks only when the size has become $0$, and the new capacity is $1$. The implementation halves once per deletion. The next theorem's counting shows that one halving restores invariant 4, because a deletion decreases the size by exactly $1$ and the previous operation left the invariant true.

Shrinking at load factor $1/2$ is the policy this lecture rejects. Doubling a full table of capacity $C$ leaves size $C+1$ and capacity $2C$, which is just over half full. One deletion then reaches half full. A shrink-at-half rule would copy everything back, and the next append would double again. Each of those operations would be $\Theta(n)$. That alternation is **thrashing**.

### 5.4 The operations

`append(x)` is `insertAt(size, x)`. Its shift loop does not run. `get`, `set`, and `length` do not resize and do not shift.

```javascript
class DynamicArray {
  constructor() {
    this.slots = null;
    this.capacity = 0;
    this.size = 0;
    this.copyCount = 0;
    this.moveCount = 0;
  }

  length() {
    return this.size;
  }

  get(index) {
    this.#checkLiveIndex(index);
    return this.slots[index];
  }

  set(index, value) {
    this.#checkLiveIndex(index);
    this.slots[index] = value;
  }

  append(value) {
    this.insertAt(this.size, value);
  }

  insertAt(index, value) {
    this.#checkIndex(index, this.size);
    this.#growIfNeeded();
    for (let i = this.size; i > index; i -= 1) {
      this.slots[i] = this.slots[i - 1];
      this.moveCount += 1;
    }
    this.slots[index] = value;
    this.size += 1;
  }

  deleteAt(index) {
    this.#checkLiveIndex(index);
    const removed = this.slots[index];
    for (let i = index; i < this.size - 1; i += 1) {
      this.slots[i] = this.slots[i + 1];
      this.moveCount += 1;
    }
    this.slots[this.size - 1] = null;
    this.size -= 1;
    this.#shrinkIfNeeded();
    return removed;
  }

  toArray() {
    const out = new Array(this.size);
    for (let i = 0; i < this.size; i += 1) {
      out[i] = this.slots[i];
    }
    return out;
  }

  #checkLiveIndex(index) {
    this.#checkIndex(index, this.size - 1);
  }

  #checkIndex(index, lastLegal) {
    if (!Number.isInteger(index) || index < 0 || index > lastLegal) {
      throw new Error("index out of range");
    }
  }

  #growIfNeeded() {
    if (this.size < this.capacity) {
      return;
    }
    let next;
    if (this.capacity === 0) {
      next = 1;
    } else if (this.capacity > Math.floor(Number.MAX_SAFE_INTEGER / 2)) {
      throw new Error("capacity exceeds the safe integer range");
    } else {
      next = this.capacity * 2;
    }
    this.#reallocate(next);
  }

  #shrinkIfNeeded() {
    if (this.capacity >= 2 && this.size <= Math.floor(this.capacity / 4)) {
      this.#reallocate(this.capacity / 2);
    }
  }

  #reallocate(nextCapacity) {
    const fresh = new Array(nextCapacity);
    for (let i = 0; i < this.size; i += 1) {
      fresh[i] = this.slots[i];
      this.copyCount += 1;
    }
    this.slots = fresh;
    this.capacity = nextCapacity;
  }
}
```

`reallocate` writes each live element once and increments `copyCount` once per write. It does not walk the unused tail. Those slots are not part of the sequence, and a second pass over them would be a different cost from the one the theorems count. `new Array(capacity)` provides the empty slots.

`insertAt` on a full array first doubles, then shifts inside the new store. Inserting $99$ at index $1$ of $[10, 20, 30, 40]$, which is full at capacity $4$, copies $4$ elements, then moves the $3$ elements at indexes $1, 2, 3$. The result is $[10, 99, 20, 30, 40]$, capacity $8$, and the copy counter rises from $3$ to $7$. The laboratory program asserts that trace. The earlier trace of $[10, 20, 30, 40, 50, 60]$ does not resize: after six appends the capacity is already $8$ and the size is $6$, the copy counter is $7$, and the four moves of the insertion are shifts.

### 5.5 The no-thrash theorem

**Theorem.** Use doubling on insertion of one element, and the quarter-capacity shrink rule on deletion of one element. Suppose an insertion has just grown the store from capacity $C \ge 1$ to capacity $2C$. The size is then $C + 1$. At least

$$
(C + 1) - \left\lfloor C / 2 \right\rfloor
$$

further one-element deletions are required before a shrink. Suppose a deletion has just shrunk the store from capacity $C \ge 2$ to capacity $C/2$, leaving size $\lfloor C / 4 \rfloor$. At least

$$
C/2 - \left\lfloor C / 4 \right\rfloor + 1
$$

further appends are required before the next growth. Both quantities are integers at least $2$. The operation immediately after a growth cannot shrink the store, and the operation immediately after a shrink cannot grow it. A single public operation does not both grow and shrink: insertion only grows, deletion only shrinks.

**Proof.** A growth from $C$ to $2C$ copies the $C$ live elements and then writes the new one, so the size is $C + 1$ and the capacity is $2C$. The shrink test on that state would require

$$
C + 1 \le \left\lfloor (2C) / 4 \right\rfloor = \left\lfloor C / 2 \right\rfloor,
$$

which is false for every integer $C \ge 1$. The size must fall to $\lfloor C / 2 \rfloor$ before the test becomes true. Falling from $C + 1$ to $\lfloor C / 2 \rfloor$ takes $(C + 1) - \lfloor C / 2 \rfloor$ deletions. That number is an integer, and $\lfloor C / 2 \rfloor \le C/2$, so it is at least $C/2 + 1$. For $C = 1$ the exact value is $2$. For $C \ge 2$ the bound $C/2 + 1$ is already at least $2$.

One deletion decreases the size by $1$, and invariant 4 says that before this deletion the shrink test was false. The size therefore crosses the threshold rather than jumping over it: the triggering deletion leaves size exactly $\lfloor C / 4 \rfloor$. The halving then sets the capacity to $C/2$, and that new state fails the shrink test, so one halving restores invariant 4. If $C = 2$, the new capacity is $1$, and the rule shrinks only when the capacity is at least $2$. If $C \ge 4$ and $C$ is a power of two, the new size is $C/4$ and the new threshold is $\lfloor (C/2) / 4 \rfloor = \lfloor C / 8 \rfloor$. Then $C/4 > \lfloor C / 8 \rfloor$, so the size is still strictly above the threshold.

After that shrink, the size is $\lfloor C / 4 \rfloor$ and the capacity is $C/2$. An append grows only when it finds the table full, which means the size must first climb to $C/2$. Reaching size $C/2$ takes $C/2 - \lfloor C / 4 \rfloor$ appends that do not grow, and the next append is the one that grows. The total is $C/2 - \lfloor C / 4 \rfloor + 1$. For $C = 2$ this is $2$. For $C = 4$ it is $2$. For $C \ge 8$ it is at least $C/4 + 1 \ge 3$.

The gap is linear in the capacity at the moment of the resize. After a growth the live size is $C + 1$, and the number of deletions before a shrink is at least half of that order. A policy that resized on every consecutive operation would make every operation $\Theta(n)$. This policy forbids that alternation.

**Worked gap.** Append $10, 20, 30, 40, 50$. The fifth append grows from capacity $4$ to capacity $8$, copies $4$, and leaves size $5$. Here $C = 4$, so the formula asks for $(4 + 1) - \lfloor 4 / 2 \rfloor = 3$ deletions before a shrink. Delete the last element three times.

| After | Size | Capacity | Copy count | Live sequence |
| --- | --- | --- | --- | --- |
| $5$ appends | $5$ | $8$ | $7$ | $[10, 20, 30, 40, 50]$ |
| $1$ deletion | $4$ | $8$ | $7$ | $[10, 20, 30, 40]$ |
| $2$ deletions | $3$ | $8$ | $7$ | $[10, 20, 30]$ |
| $3$ deletions | $2$ | $4$ | $9$ | $[10, 20]$ |

The third deletion finds size $2 = \lfloor 8 / 4 \rfloor$ and copies those $2$ elements into a store of capacity $4$. The copy count is $7 + 2 = 9$. From size $2$ and capacity $4$, the second formula asks for $4/2 - \lfloor 4 / 4 \rfloor + 1 = 3$ appends before the next growth. Append $60$, then $70$: the size becomes $4$ and the capacity stays $4$. Append $80$: the table is full, the copy count rises by $4$ to $13$, the capacity becomes $8$, and the sequence is $[10, 20, 60, 70, 80]$. The laboratory program asserts this entire trace.

### 5.6 What is proved so far, and what is only stated

Worst-case costs follow by inspecting the loops.

| Operation | Worst-case cost | Why |
| --- | --- | --- |
| `length`, `get`, `set` | $\Theta(1)$ | address arithmetic, or a stored integer, and no loop |
| `append` | $\Theta(n)$ | the copy loop can write $n$ elements |
| `insertAt(k)` | $\Theta(n)$ | up to $n$ shifts, and possibly a copy of $n$ elements |
| `deleteAt(k)` | $\Theta(n)$ | up to $n - 1$ shifts, and possibly a shrink copy |
| delete-at-end | $\Theta(n)$ | the shift loop is empty; a shrink can still copy $\Theta(n)$ elements |

**Theorem (stated).** Any sequence of $m$ operations, each an append or a delete-at-end, has total element-write cost $O(m)$ under doubling and the quarter-capacity shrink rule. The amortized cost of each operation in that mix is therefore $O(1)$.

What is missing is the case analysis of a potential that is zero near load factor $1/2$, large when the table is full, and large when the table is nearly empty. The no-thrash theorem is the reason the statement is believable: expensive resizes are separated by a linear number of cheap operations. It does not by itself add up the copies. The independent assignment is that case analysis. The three theorems in Parts 6, 7, and 8 are proved here, and they are about append.

A stack can be represented by this array, with append as push and delete-at-end as pop. The stack ADT is Lecture 04.

---

## PART 6 — AGGREGATE ANALYSIS OF APPENDING

### 6.1 What amortized cost means

**Worst-case cost** is the maximum cost of one call on an input of size $n$.

**Average-case cost** is the mean cost over a stated probability distribution on inputs. This lecture never assumes a distribution, so it proves no average-case bound.

**Amortized cost** is the cost per operation in a worst-case sequence. If every sequence of $n$ operations has total actual cost at most $T(n)$, the amortized cost is $T(n) / n$. One operation inside the sequence may cost much more. The definition does not say that every call is cheap. It says that the expensive calls are rare enough, in every sequence, that the total stays bounded.

The **aggregate method** computes that total directly and divides by $n$. It is the method of this part. The accounting method and the potential method are other ways to reach a total bound, taught in Parts 7 and 8 on the same structure.

### 6.2 The cost model

One **unit** is one write of a live element into a slot. A resize that copies $b$ live elements costs $b$ units. Placing the new element of an append costs $1$ unit. Index arithmetic outside those loops is a constant number of RAM steps per call. Once the element writes of $n$ appends are $O(n)$, that constant overhead is $O(n)$ as well, and the amortized cost remains $\Theta(1)$. The theorems below count element writes, because those are the writes that can be linear in $n$.

Shifts are a different counter, `moveCount`. Append does not shift. A bound on copies is not a bound on `insertAt` in the middle. Part 12 uses that distinction.

### 6.3 The copy sequence

Start with size $0$ and capacity $0$. The first append allocates capacity $1$ and copies nothing. An empty store that had already been allocated with capacity $1$ also copies nothing on the first append. Every later copy count in this part is the same for both starting states. The phrase "starting from capacity $1$" means: the first positive capacity is $1$, and the copy sizes that follow are $1, 2, 4, \ldots$.

An append copies elements exactly when it finds the table full. The full capacities are the powers of two. The append that raises the size from $2^k$ to $2^k + 1$ copies $2^k$ elements. That append is operation number $2^k + 1$. Among the first $n$ appends it occurs if and only if $2^k + 1 \le n$, that is $2^k \le n - 1$.

Let $C(n)$ denote the total number of element copies in $n$ appends. $C(0) = 0$ and $C(1) = 0$. For $n \ge 2$, if $2^m$ is the greatest power of two that is at most $n - 1$, then the copies are exactly $1, 2, 4, \ldots, 2^m$ and

$$
C(n) = \sum_{k=0}^{m} 2^k = 2^{m+1} - 1.
$$

There is no extra term when $n - 1$ is not itself a power of two. The series stops at $2^m$, and every append after that resize copies nothing until the size reaches the new capacity.

**The case $n = 10$, which is not one past a power of two.** Here $n - 1 = 9$. The greatest power of two at most $9$ is $8$, so $m = 3$ and $C(10) = 2^4 - 1 = 15$. The copies are $1 + 2 + 4 + 8$. There is no copy of $16$. Append $9$ is the one that copies $8$. Appends $6, 7, 8$ copy nothing even though $8$ is a power of two: the copy of a power $P$ happens on append $P + 1$, not on append $P$. Append $8$ only fills the store. The next table is the one the laboratory program checks, appending the values $10, 20, \ldots, 100$.

| Append $n$ | Value | Size | Capacity | Copies on this append | Total copies $C(n)$ |
| --- | --- | --- | --- | --- | --- |
| $1$ | $10$ | $1$ | $1$ | $0$ | $0$ |
| $2$ | $20$ | $2$ | $2$ | $1$ | $1$ |
| $3$ | $30$ | $3$ | $4$ | $2$ | $3$ |
| $4$ | $40$ | $4$ | $4$ | $0$ | $3$ |
| $5$ | $50$ | $5$ | $8$ | $4$ | $7$ |
| $6$ | $60$ | $6$ | $8$ | $0$ | $7$ |
| $7$ | $70$ | $7$ | $8$ | $0$ | $7$ |
| $8$ | $80$ | $8$ | $8$ | $0$ | $7$ |
| $9$ | $90$ | $9$ | $16$ | $8$ | $15$ |
| $10$ | $100$ | $10$ | $16$ | $0$ | $15$ |

Read the capacity column as $1, 2, 4, 4, 8, 8, 8, 8, 16, 16$. For $n = 6, 7, 8$ the total stays $7$. Those three values of $n$ are the whole point of the "not one past a power of two" case: $n = 8 = 2^3$ is a power of two, and $C(8) = 7$, not $1 + 2 + 4 + 8$. The copy of $8$ is append $9 = 8 + 1$.

### 6.4 The exact identity and the bound

**Theorem.** For every $n \ge 1$ after doubling appends with no deletion, the capacity is the least power of two that is at least $n$, and

$$
C(n) = \mathrm{capacity}(n) - 1.
$$

**Proof.** By induction on $n$. For $n = 1$ the capacity is $1$ and $C(1) = 0$. Suppose the claim holds for some $n \ge 1$, with capacity $C$. The inductive hypothesis says $C$ is the least power of two that is at least $n$, so $n > C/2$. For $C \ge 2$, $C/2$ is a smaller power of two, and $n \le C/2$ would contradict the hypothesis. For $C = 1$ the only possible $n$ is $1$, and $1 > 1/2$. If append $n + 1$ does not resize, then $n < C$, hence $n + 1 \le C$. Combined with $n > C/2$ this puts $n + 1$ in the half-open interval $(C/2, C]$, so the least power of two that is at least $n + 1$ is still $C$. The copy total is unchanged and remains $C - 1$. If append $n + 1$ resizes, the table was full, so $n = C$ and the inductive total is $C - 1$. The append copies $C$ elements. The new total is $2C - 1$ and the new capacity is $2C$. Since $n = C$ is itself a power of two, the least power of two that is at least $n + 1$ is $2C$, and $2C - 1 = (2C) - 1$.

**Theorem.** $C(n) < 2n$ for every $n \ge 1$. The total element-write cost of $n$ appends is $n + C(n) < 3n$. The amortized cost of append is $\Theta(1)$. The worst-case cost of one append remains $\Theta(n)$.

**Proof.** For $n = 1$, $C(1) = 0 < 2$. For $n \ge 2$, let $2^m$ be the greatest power of two that is at most $n - 1$, so the series of Part 6.3 gives $C(n) = 2^{m+1} - 1$. From $2^m \le n - 1$ it follows that $2^{m+1} \le 2(n - 1)$, and therefore

$$
C(n) = 2^{m+1} - 1 \le 2n - 3.
$$

Equality holds when $2^m = n - 1$, that is when $n$ is one past a power of two. When $2^m < n - 1$ the same derivation is strict, so $C(n) < 2n - 3$. In every case $C(n) < 2n$. The series and the identity name the same quantity: the series gives $C(n) = 2^{m+1} - 1$, and the identity gives $C(n) = \mathrm{capacity}(n) - 1$, so the capacity is $2^{m+1}$.

The loose envelope $1 + 2 + 4 + \cdots$ up through the greatest power of two that is at most $n$ equals $2^{\lfloor \log n \rfloor + 1} - 1 \le 2n - 1$, because that greatest power is at most $n$. Every term that actually occurs is a power of two at most $n - 1$, so the exact sum is at most the envelope, and the envelope is less than $2n$. The envelope is an upper bound. It is not the list of copies. For $n = 8$ the envelope through $8$ is $15$, and the exact copy count is $7$.

Each append also places its new element. The total number of element writes is

$$
n + C(n) < 3n.
$$

Dividing by $n$ gives an amortized element-write cost strictly less than $3$, which is $O(1)$. Each append writes at least that one new element, so the amortized cost is $\Omega(1)$. The tight bound is $\Theta(1)$.

The worst case of a single append is the append that copies $2^m$ elements with $2^m = \Theta(n)$. That append is operation $2^m + 1$, and its copy cost is $n - 1$ when $n = 2^m + 1$. Amortized $\Theta(1)$ and worst-case $\Theta(n)$ are both true.

For the running example, $C(10) = 15 < 20$, and $10 + 15 = 25 < 30$.

---

## PART 7 — THE ACCOUNTING METHOD

### 7.1 The charge

The **accounting method** assigns each operation a **charge**, in units of credit. The charge may be more than the actual cost. The surplus is stored as **credit**. A later operation may spend stored credit to pay an actual cost that exceeds its own charge. If the stock of credit is never required to go negative, then every unit of actual cost was paid by some charge. The total actual cost is then at most the total of the charges.

For doubling appends the charge is $3$ units per append.

- $1$ unit pays for writing the new element.
- $2$ units are stored as credit on this append.

A resize spends $1$ unit of stored credit for each live element it copies. The copy bill is paid before the new $2$ units are deposited. The order matters, because the bill has to be covered by credit that earlier appends already stored.

### 7.2 The stock never goes negative

**Theorem.** Under the charge above, the credit stock is nonnegative after every payment. The total element-write cost of $n$ appends is at most $3n$. The amortized cost is $O(1)$, and with the matching $\Omega(1)$ from Part 6 it is $\Theta(1)$.

**Proof.** Let $K$ be the stock, $s$ the size, and $C$ the capacity. The invariant is: $K = 0$ before any append, and after every append

$$
K = 2s - C + 1.
$$

The actual cost of an append that copies $b$ elements is $b + 1$. The charge pays the $1$. The stock pays $b$. If $K \ge b$ at the moment of payment, the stock stays nonnegative, and summing over the sequence gives total actual cost at most $3n$, because each unit spent was either the write-unit of some charge or credit deposited from charges. Credit left at the end is unused charge, so the inequality is $\le$.

Proceed by induction. The base stock is $0$.

On the first append, $b = 0$ and the new stock is $0 - 0 + 2 = 2$. The new state has $s = 1$, $C = 1$, and $2 \cdot 1 - 1 + 1 = 2$.

On a later append that does not resize, $b = 0$. The inductive stock $2s - C + 1$ increases by $2$, and the size increases by $1$, so the formula becomes $2(s + 1) - C + 1$. The stock stays positive.

On a resize, the table is full: $s = C \ge 1$ and $b = C$. The inductive stock is $2C - C + 1 = C + 1$. Paying the bill leaves $C + 1 - C = 1$, which is nonnegative. Depositing $2$ makes the stock $3$. The new size is $C + 1$ and the new capacity is $2C$, and $2(C + 1) - 2C + 1 = 3$. The invariant holds.

The stock is therefore an integer at least $0$ after every payment, and at least $1$ at the instant a resize has been paid and the new deposit has not yet been added. This completes the proof.

The invariant is one unit larger than $2s - C$. That extra unit is why a full table of capacity $C$ holds $C + 1$ units against a copy bill of $C$. The potential in Part 8 is the smaller function $2s - C$. Both are valid. They are not the same function, and the proofs do not treat them as interchangeable.

### 7.3 The accounting table for the ten appends

The same run as Part 6. "After the bill" means the stock after the copy has been paid and before the deposit of $2$. When $b = 0$ that column equals the previous stock.

| $n$ | $b$ | Stock before the bill | After the bill | Stock after the append | $2s - C + 1$ |
| --- | --- | --- | --- | --- | --- |
| $1$ | $0$ | $0$ | $0$ | $2$ | $2$ |
| $2$ | $1$ | $2$ | $1$ | $3$ | $3$ |
| $3$ | $2$ | $3$ | $1$ | $3$ | $3$ |
| $4$ | $0$ | $3$ | $3$ | $5$ | $5$ |
| $5$ | $4$ | $5$ | $1$ | $3$ | $3$ |
| $6$ | $0$ | $3$ | $3$ | $5$ | $5$ |
| $7$ | $0$ | $5$ | $5$ | $7$ | $7$ |
| $8$ | $0$ | $7$ | $7$ | $9$ | $9$ |
| $9$ | $8$ | $9$ | $1$ | $3$ | $3$ |
| $10$ | $0$ | $3$ | $3$ | $5$ | $5$ |

The smallest stock at a moment of payment is $1$, on appends $2, 3, 5, 9$. It is never negative. The laboratory program recomputes this stock for every prefix through $n = 64$ and checks the invariant, including the row $n = 10$, where the stock is $5$ and the capacity is $16$.

---

## PART 8 — THE POTENTIAL METHOD

### 8.1 The definition

The **potential method** stores the "prepaid cost" in a function of the whole state rather than in per-operation credits. Let $h$ be a state, with size $s(h)$ and capacity $C(h)$. Define

$$
\Phi(h) = 2\, s(h) - C(h)
$$

when you are using the usual arithmetic, and define $\Phi = 0$ for the starting state $s = 0$, $C = 0$, where the same arithmetic already yields $0$. If an implementation starts empty at capacity $1$, then $2 \cdot 0 - 1 = -1$. That starting value is negative. The proof in this part uses the capacity-$0$ start so that $\Phi$ begins at $0$ and stays nonnegative. After the first append the states, the copy counts, and the values of $\Phi$ agree with the capacity-$1$ start; only the before-anything state differs.

For an operation that takes the structure from state $h_{i-1}$ to state $h_i$ at actual cost $c_i$, the **amortized cost** of that operation is

$$
\hat{c}_i = c_i + \Phi(h_i) - \Phi(h_{i-1}).
$$

Summing telescopes:

$$
\sum_{i=1}^{n} c_i = \sum_{i=1}^{n} \hat{c}_i + \Phi(h_0) - \Phi(h_n).
$$

If $\Phi(h_0) = 0$ and $\Phi(h_n) \ge 0$, the last two terms contribute a nonpositive quantity, and the total actual cost is at most the total amortized cost. Nonnegativity is what lets you discard $\Phi(h_n)$. A potential that finishes below its start would make the telescope point the wrong way for an upper bound.

### 8.2 The append theorem

**Theorem.** With $\Phi(h) = 2\, s(h) - C(h)$ and the capacity-$0$ start, $\Phi$ is nonnegative after every append. Every append has amortized cost at most $3$. The total element-write cost of $n$ appends is at most $3n$, so the amortized cost is $\Theta(1)$.

**Proof.** Write $s$ and $C$ for the size and capacity before an append, and $s'$ and $C'$ for the values after it. Actual cost $c$ is the number of elements copied, plus $1$ for the new element.

First, nonnegativity, by induction on the number of appends, together with a side claim: every reachable state with $C \ge 1$ has $s \ge \lceil C / 2 \rceil$. The start has $\Phi = 0$, and the side claim is vacuously true because the capacity is $0$.

The first append goes from $(s, C) = (0, 0)$ to $(1, 1)$. Then $\Phi = 2 - 1 = 1 \ge 0$, and $1 \ge \lceil 1 / 2 \rceil$.

A resizing append finds $s = C \ge 1$ and finishes at $s' = C + 1$, $C' = 2C$. Then

$$
\Phi = 2(C + 1) - 2C = 2 \ge 0,
$$

and $C + 1 \ge C = C' / 2$, so $s' \ge \lceil C' / 2 \rceil$.

An append that does not resize has $C' = C$, $s' = s + 1$, and $s < C$. The side claim on the before-state gives $s \ge \lceil C / 2 \rceil$ once $s \ge 1$, so

$$
\Phi(h) = 2s - C \ge 2\lceil C / 2 \rceil - C \ge 0,
$$

and the after-state has a larger size and the same capacity, so both the potential and the side claim remain true. The only reachable state with $s = 0$ is the start. This closes the induction. In the append-only process the inequality is in fact stricter after each resize: the size is $C_{\mathrm{old}} + 1 = C' / 2 + 1$, so $\Phi = 2$ there, and further appends only increase $\Phi$ by $2$ until the next resize.

Now the amortized costs.

*First append.* $c = 1$, $\Phi$ goes from $0$ to $1$, and $\hat{c} = 1 + 1 - 0 = 2 \le 3$.

*No resize.* $c = 1$ and $\Phi$ increases by $2$, because the size increases by $1$ and the capacity does not change. $\hat{c} = 1 + 2 = 3$.

*Resize.* $s = C$, $c = C + 1$, $\Phi$ before the append is $2C - C = C$, and $\Phi$ after is $2$. Then

$$
\hat{c} = (C + 1) + (2 - C) = 3.
$$

Every append therefore has $\hat{c}_i \le 3$. The telescope and the two facts $\Phi(h_0) = 0$, $\Phi(h_n) \ge 0$ give

$$
\sum_{i=1}^{n} c_i = \sum_{i=1}^{n} \hat{c}_i + \Phi(h_0) - \Phi(h_n) \le 3n.
$$

Each $c_i \ge 1$, so the total is at least $n$. Dividing by $n$ yields $\Theta(1)$.

The same ten appends produce the potentials $1, 2, 2, 4, 2, 4, 6, 8, 2, 4$. Two of them are worth doing by hand because the program checks every entry.

Append $9$ resizes from size $8$, capacity $8$, where $\Phi = 8$, at actual cost $c = 8 + 1 = 9$, to size $9$, capacity $16$, where $\Phi = 18 - 16 = 2$. The amortized cost is $9 + 2 - 8 = 3$.

Append $10$ does not resize. Before it, $\Phi = 2$. Actual cost $c = 1$. After it, size $10$, capacity $16$, $\Phi = 20 - 16 = 4$. The amortized cost is $1 + 4 - 2 = 3$.

Append $1$ is the first-append case: amortized cost $2$, not $3$. The bound of $3$ is an upper bound that covers every case, including the resizes.

This potential does not survive arbitrary deletion. A deletion decreases the size and can make $2s - C$ negative, and a shrink changes the capacity downward. Part 7's credit invariant has the same limitation: it was proved for appends. The independent assignment uses a different potential for the mix of append and delete-at-end.

---

## PART 9 — GROWING BY ONE SLOT

Doubling is a policy. The contrasting policy is: when the table is full, allocate exactly one more slot and copy every live element.

Start at capacity $1$ and size $0$, which matches a first allocation of one slot. Append $1$ copies nothing. Append $k$, for $k \ge 2$, finds size $= k - 1 =$ capacity and copies $k - 1$ elements. After $n$ appends

$$
\sum_{k=2}^{n} (k - 1) = \sum_{j=1}^{n-1} j = \frac{n(n-1)}{2}.
$$

**Theorem.** Under the one-extra-slot policy, the total copy cost of $n$ appends is $n(n-1)/2$, which is $\Theta(n^2)$. The amortized copy cost is $(n - 1)/2$, which is $\Theta(n)$.

**Proof.** The sum above is the total. Dividing by $n$ produces $(n - 1)/2$. That quantity grows without a constant bound, so the amortized cost is not $O(1)$. It is $\Theta(n)$ because $(n - 1)/2$ is both $O(n)$ and $\Omega(n)$. Adding the $n$ placements of new elements does not change the $\Theta(n^2)$ total.

The geometric series in Part 6 stayed below $2n$ because each term was twice the previous term and the closed form of a geometric series is a constant times its last term. The series $1 + 2 + \cdots + (n - 1)$ is arithmetic. Its closed form is quadratic. The proofs of Parts 6 through 8 do not apply to this policy, because each of them used the doubling structure: the full-table stock of $C + 1$ units, the potential drop from $C$ to $2$ on a doubling, or the exact list of powers of two.

**Worked $n = 6$.** Copies on the six appends: $0, 1, 2, 3, 4, 5$. Total $15 = 6 \cdot 5 / 2$. The same formula at $n = 20$ gives $20 \cdot 19 / 2 = 190$, and $190 > 2 \cdot 20$, so this run already violates the doubling envelope. The laboratory program asserts both totals. At $n = 6$ the doubling policy of Part 6 has copied only $7$ elements.

---

## PART 10 — ROW-MAJOR MULTIDIMENSIONAL ARRAYS

A matrix with $r$ rows and $c$ columns can be stored in a one-dimensional array of length $r \cdot c$. **Row-major order** stores row $0$, then row $1$, then row $2$, each row left to right. The flat index of position $(i, j)$, with $0 \le j < c$, is

$$
\mathrm{index}(i, j) = i \cdot c + j.
$$

The address is $B + (i \cdot c + j) \cdot w$, the Part 1 formula applied to that index. This is the zero-based case of the layout in CLRS Section 10.1 and of lexicographic storage in Knuth Section 2.2.6.

**Worked matrix.** Three rows, four columns, width $w = 1$ for the index arithmetic:

```text
        j=0   j=1   j=2   j=3
i=0      1     2     3     4
i=1      5     6     7     8
i=2      9    10    11    12
```

The flat store is $[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]$. Position $(1, 2)$ has index $1 \cdot 4 + 2 = 6$ and value $7$. Row $1$ occupies indexes $4, 5, 6, 7$. Column $2$ occupies indexes $2, 6, 10$. The laboratory program asserts these indexes and the value $7$.

```javascript
function rowMajorIndex(row, column, columns) {
  if (!Number.isInteger(columns) || columns <= 0) {
    throw new Error("columns must be a positive integer");
  }
  if (!Number.isInteger(row) || row < 0 || !Number.isInteger(column) || column < 0 || column >= columns) {
    throw new Error("index out of range");
  }
  const index = row * columns + column;
  if (!Number.isSafeInteger(index)) {
    throw new Error("index exceeds the safe integer range");
  }
  return index;
}
```

**Cost of one row and one column, in the RAM model.** Reading row $i$ reads $c$ slots. Reading column $j$ reads $r$ slots. Both are $\Theta(1)$ per slot, so a row costs $\Theta(c)$ and a column costs $\Theta(r)$. For a square matrix of order $n$ those are the same bound, $\Theta(n)$. The RAM model does not make the row cheaper.

**Why a row walk is the walk that touches neighbors.** Successive elements of a row have flat indexes differing by $1$, so their addresses differ by $w$. That difference is the **stride** of the row, measured in address units as $w$, and measured in elements as $1$. Successive elements of a column have flat indexes differing by $c$, so their addresses differ by $c \cdot w$. The column stride is $c$ elements. In the worked matrix the column stride is $4$ elements: $6 - 2 = 4$ and $10 - 6 = 4$. Part 2 then applies unchanged. The row walk reads neighboring addresses. The column walk jumps. The number of RAM accesses is $\Theta(c)$ versus $\Theta(r)$; the locality is a statement about strides, not a different $\Theta$ in the RAM model, and it still has no cycle count attached.

An entire matrix read in row-major order is one sequential pass of length $r \cdot c$. The same elements read column by column perform the same number of accesses with stride $c$.

---

## PART 11 — STRINGS, IMMUTABILITY, AND A BUFFER

### 11.1 What the language guarantees

A JavaScript string is a sequence of UTF-16 code units. Indexing a string is constant-time for the same reason indexing an array is constant-time: a code unit has fixed width, $16$ bits. A Unicode scalar value may occupy two code units. This lecture stores and counts code units. It does not teach Unicode algorithms; Lecture 14 owns the string structures that go past this point.

ECMA-262 defines the String type and provides no operation that changes an existing string in place. Concatenation evaluates to a new string. That is a language rule. Some engines, on some patterns, build a rope or delay the copy. That is an engine optimization. The cost proved here is the cost of the copies the language semantics perform, implemented by an explicit counter, not the cost of one engine's optimizer.

### 11.2 Concatenation in a loop

Consider this loop, which builds a string of $n$ copies of a one-unit chunk:

```javascript
function concatenationCost(count, chunk) {
  let value = "";
  let copies = 0;
  for (let i = 0; i < count; i += 1) {
    copies += value.length + chunk.length;
    value = value + chunk;
  }
  return { value, copies };
}
```

At iteration $i$, counting from $0$, the left operand has length $i$ when the chunk has length $1$, and the new string writes $i + 1$ code units. The total is

$$
\sum_{t=1}^{n} t = \frac{n(n+1)}{2}.
$$

**Theorem.** $n$ concatenations of one code unit each perform $n(n+1)/2$ code-unit writes under this semantics, which is $\Theta(n^2)$.

**Proof.** The sum is the closed form from Lecture 01's summation facts, and $n(n+1)/2$ is $\Theta(n^2)$. Nothing is reused. Each new string is a full copy of the previous one plus the new unit, and the previous string is then abandoned. There is no geometric block and no credit to spend. The doubling argument does not apply to `+`.

**Worked $n = 4$.** The successive copy counts are $1, 2, 3, 4$, and the total is $10 = 4 \cdot 5 / 2$. The result is `"aaaa"`. The same formula at $n = 32$ gives $32 \cdot 33 / 2 = 528$. The laboratory program asserts both.

### 11.3 A buffer

The repair is a **buffer**: a dynamic array whose elements are code units. Appending a unit is the append of Part 6, amortized $\Theta(1)$ element writes, with total resize copies $C(n) < 2n$. The finished string is produced once, by walking the buffer a single time into a result of length $n$. That final walk is $\Theta(n)$ code units. It is not a loop of `+`.

```javascript
class StringBuilder {
  constructor() {
    this.buffer = new DynamicArray();
  }

  append(text) {
    for (let i = 0; i < text.length; i += 1) {
      this.buffer.append(text[i]);
    }
  }

  length() {
    return this.buffer.length();
  }

  toString() {
    const parts = new Array(this.buffer.length());
    for (let i = 0; i < parts.length; i += 1) {
      parts[i] = this.buffer.get(i);
    }
    return parts.join("");
  }
}
```

`toString` uses one `join` of a pre-sized array. The cost that the theorems measure is the buffer's own counters: $n$ placements plus $C(n)$ resize copies. For $n = 4$ the buffer's `copyCount` is $3$, and $3 = C(4)$, and $3 < 8$. For $n = 32$ the capacity is $32$ and the copy count is $31$, and $31 < 64$. The program checks those counters, and it checks that the joined string equals the concatenated string. `join` is the final assembly. Replacing it by a loop of `+` would reintroduce the quadratic sum, and the copy counter of the buffer would no longer be the cost of building the result.

---

## PART 12 — WHEN A DYNAMIC ARRAY IS THE WRONG STRUCTURE

Doubling pays for copies. It does not pay for shifts. `insertAt(0, x)` on a sequence of size $s$ moves $s$ elements. Under the potential of Part 8, a non-resizing call of this kind has actual cost $s + 1$ and changes $\Phi$ by $2$, so the amortized cost is $s + 3$, which is $\Theta(n)$ when $s$ is $\Theta(n)$. The potential does not cancel the shifts.

**Theorem.** $n$ insertions at index $0$, into an initially empty dynamic array, perform

$$
\sum_{k=0}^{n-1} k = \frac{n(n-1)}{2}
$$

shifts. The total shift cost is $\Theta(n^2)$. The resize copies on that same sequence remain $C(n) < 2n$, because each insertion adds one element and the growth rule depends on the size, not on the index.

**Proof.** The $k$-th insertion, counting from $0$, finds size $k$ and shifts $k$ elements. The sum is the arithmetic series. The copy claim is the theorem of Part 6 applied to any sequence of $n$ one-element insertions with no deletion: the table is full under the same condition $\mathrm{size} = \mathrm{capacity}$, so the copy sizes are the same powers of two.

**Worked $n = 5$.** Insert $10, 20, 30, 40, 50$ at index $0$.

| Insertion | Shifts on this call | Total shifts | Copies on this call | Total copies | Sequence |
| --- | --- | --- | --- | --- | --- |
| $10$ | $0$ | $0$ | $0$ | $0$ | $[10]$ |
| $20$ | $1$ | $1$ | $1$ | $1$ | $[20, 10]$ |
| $30$ | $2$ | $3$ | $2$ | $3$ | $[30, 20, 10]$ |
| $40$ | $3$ | $6$ | $0$ | $3$ | $[40, 30, 20, 10]$ |
| $50$ | $4$ | $10$ | $4$ | $7$ | $[50, 40, 30, 20, 10]$ |

Total shifts $10 = 5 \cdot 4 / 2$. Total copies $7 = 8 - 1$, and the final capacity is $8$, in agreement with $C(5) = 7 < 10$. The quadratic term is the shifts. The laboratory program asserts the final sequence, the shift total $10$, and the copy total $7$.

Frequent insertion at the front is the operation mix for which this structure is the wrong choice. A linked list supports insertion at the front in $\Theta(1)$ once the front cell is in hand. Lecture 03 owns that structure. This lecture does not build it.

---

## LABORATORY

### Guided traces

Do these on paper before you read the program. The numbers are the ones already derived in the body; produce each row yourself, then compare.

1. Append $10, 20, \ldots, 100$ to an empty doubling array. For each append record capacity, copies on that append, and total copies. The last row is size $10$, capacity $16$, total copies $15$.
2. Continue from the Part 5 gap trace only after you have hidden it: five appends to size $5$, capacity $8$, then three end-deletions to size $2$, capacity $4$, copy count $9$, then three appends ending at copy count $13$.
3. Concatenate `"a"` four times and total the code-unit writes. The total is $10$.

### Problems to do before the program

4. Using the exact formula, compute $C(47)$. Identify the greatest power of two that is at most $46$, and also identify the capacity after $47$ appends.
5. Repeat the static-array trace: start from $[10, 20, 30, 40, 50, 60]$, insert $99$ at index $2$, then delete index $3$. Record both move counts.
6. Compute $\mathrm{index}(1, 2)$ for $c = 4$, and the address of index $3$ with base $1000$ and width $8$.
7. Insert five values at index $0$ and total the shifts by the series, then check against a row-by-row simulation.
8. For the one-extra-slot policy, compute the copy total at $n = 6$ and at $n = 20$.

The program asserts every one of these results. Write your numbers before you read it. Save the program as `lecture02-lab.js` and run `node lecture02-lab.js`. It loads `node:assert/strict` with `require` and runs as an ordinary script.

## LABORATORY PROGRAM

```javascript
"use strict";

import assert from "node:assert/strict";

class DynamicArray {
  constructor() {
    this.slots = null;
    this.capacity = 0;
    this.size = 0;
    this.copyCount = 0;
    this.moveCount = 0;
  }

  length() {
    return this.size;
  }

  get(index) {
    this.#checkLiveIndex(index);
    return this.slots[index];
  }

  set(index, value) {
    this.#checkLiveIndex(index);
    this.slots[index] = value;
  }

  append(value) {
    this.insertAt(this.size, value);
  }

  insertAt(index, value) {
    this.#checkIndex(index, this.size);
    this.#growIfNeeded();
    for (let i = this.size; i > index; i -= 1) {
      this.slots[i] = this.slots[i - 1];
      this.moveCount += 1;
    }
    this.slots[index] = value;
    this.size += 1;
  }

  deleteAt(index) {
    this.#checkLiveIndex(index);
    const removed = this.slots[index];
    for (let i = index; i < this.size - 1; i += 1) {
      this.slots[i] = this.slots[i + 1];
      this.moveCount += 1;
    }
    this.slots[this.size - 1] = null;
    this.size -= 1;
    this.#shrinkIfNeeded();
    return removed;
  }

  toArray() {
    const out = new Array(this.size);
    for (let i = 0; i < this.size; i += 1) {
      out[i] = this.slots[i];
    }
    return out;
  }

  #checkLiveIndex(index) {
    this.#checkIndex(index, this.size - 1);
  }

  #checkIndex(index, lastLegal) {
    if (!Number.isInteger(index) || index < 0 || index > lastLegal) {
      throw new Error("index out of range");
    }
  }

  #growIfNeeded() {
    if (this.size < this.capacity) {
      return;
    }
    let next;
    if (this.capacity === 0) {
      next = 1;
    } else if (this.capacity > Math.floor(Number.MAX_SAFE_INTEGER / 2)) {
      throw new Error("capacity exceeds the safe integer range");
    } else {
      next = this.capacity * 2;
    }
    this.#reallocate(next);
  }

  #shrinkIfNeeded() {
    if (this.capacity >= 2 && this.size <= Math.floor(this.capacity / 4)) {
      this.#reallocate(this.capacity / 2);
    }
  }

  #reallocate(nextCapacity) {
    const fresh = new Array(nextCapacity);
    for (let i = 0; i < this.size; i += 1) {
      fresh[i] = this.slots[i];
      this.copyCount += 1;
    }
    this.slots = fresh;
    this.capacity = nextCapacity;
  }
}

class PlusOneArray {
  constructor() {
    this.slots = new Array(1);
    this.capacity = 1;
    this.size = 0;
    this.copyCount = 0;
  }

  append(value) {
    if (this.size === this.capacity) {
      const next = this.capacity + 1;
      if (next > Number.MAX_SAFE_INTEGER) {
        throw new Error("capacity exceeds the safe integer range");
      }
      const fresh = new Array(next);
      for (let i = 0; i < this.size; i += 1) {
        fresh[i] = this.slots[i];
        this.copyCount += 1;
      }
      this.slots = fresh;
      this.capacity = next;
    }
    this.slots[this.size] = value;
    this.size += 1;
  }
}

class StringBuilder {
  constructor() {
    this.buffer = new DynamicArray();
  }

  append(text) {
    for (let i = 0; i < text.length; i += 1) {
      this.buffer.append(text[i]);
    }
  }

  length() {
    return this.buffer.length();
  }

  toString() {
    const parts = new Array(this.buffer.length());
    for (let i = 0; i < parts.length; i += 1) {
      parts[i] = this.buffer.get(i);
    }
    return parts.join("");
  }
}

function insertStatic(slots, size, index, value) {
  if (size >= slots.length) {
    throw new Error("overflow");
  }
  if (!Number.isInteger(index) || index < 0 || index > size) {
    throw new Error("index out of range");
  }
  let moves = 0;
  for (let i = size; i > index; i -= 1) {
    slots[i] = slots[i - 1];
    moves += 1;
  }
  slots[index] = value;
  return { size: size + 1, moves };
}

function deleteStatic(slots, size, index) {
  if (!Number.isInteger(index) || index < 0 || index >= size) {
    throw new Error("index out of range");
  }
  let moves = 0;
  for (let i = index; i < size - 1; i += 1) {
    slots[i] = slots[i + 1];
    moves += 1;
  }
  slots[size - 1] = null;
  return { size: size - 1, moves };
}

function elementAddress(base, index, width) {
  if (!Number.isInteger(base) || !Number.isInteger(index) || index < 0 || !Number.isInteger(width) || width <= 0) {
    throw new Error("invalid address arguments");
  }
  const address = base + index * width;
  if (!Number.isSafeInteger(address)) {
    throw new Error("address exceeds the safe integer range");
  }
  return address;
}

function rowMajorIndex(row, column, columns) {
  if (!Number.isInteger(columns) || columns <= 0) {
    throw new Error("columns must be a positive integer");
  }
  if (!Number.isInteger(row) || row < 0 || !Number.isInteger(column) || column < 0 || column >= columns) {
    throw new Error("index out of range");
  }
  const index = row * columns + column;
  if (!Number.isSafeInteger(index)) {
    throw new Error("index exceeds the safe integer range");
  }
  return index;
}

function concatenationCost(count, chunk) {
  let value = "";
  let copies = 0;
  for (let i = 0; i < count; i += 1) {
    copies += value.length + chunk.length;
    value = value + chunk;
  }
  return { value, copies };
}

function provedCopyCount(n) {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("n must be a nonnegative integer");
  }
  if (n < 2) {
    return 0;
  }
  let power = 1;
  while (power <= Math.floor((n - 1) / 2)) {
    power *= 2;
  }
  return power * 2 - 1;
}

function assertDoublingInvariant(array) {
  assert.ok(array.size >= 0);
  assert.ok(array.size <= array.capacity);
  if (array.capacity === 0) {
    assert.equal(array.slots, null);
    assert.equal(array.size, 0);
    return;
  }
  assert.equal(array.slots.length, array.capacity);
  let power = 1;
  while (power < array.capacity) {
    power *= 2;
  }
  assert.equal(power, array.capacity);
  if (array.capacity >= 2) {
    assert.ok(array.size > Math.floor(array.capacity / 4));
  }
}

const indexed = new DynamicArray();
assert.equal(indexed.length(), 0);
assert.throws(() => indexed.get(0), /index out of range/);
indexed.append("a");
indexed.append("b");
indexed.append("c");
assert.equal(indexed.length(), 3);
indexed.set(1, "B");
assert.equal(indexed.get(0), "a");
assert.equal(indexed.get(1), "B");
assert.equal(indexed.get(2), "c");
assert.equal(indexed.length(), 3);
assert.equal(indexed.copyCount, 3);
assert.equal(indexed.moveCount, 0);
assert.throws(() => indexed.get(-1), /index out of range/);
assert.throws(() => indexed.get(3), /index out of range/);
assert.throws(() => indexed.set(3, "x"), /index out of range/);
assert.throws(() => indexed.deleteAt(3), /index out of range/);
assert.throws(() => indexed.insertAt(4, "z"), /index out of range/);
indexed.insertAt(3, "d");
assert.deepEqual(indexed.toArray(), ["a", "B", "c", "d"]);

const ten = new DynamicArray();
const capacities = [];
const stepCopies = [];
let credit = 0;
let previousCopies = 0;
for (let n = 1; n <= 10; n += 1) {
  ten.append(10 * n);
  capacities.push(ten.capacity);
  const bill = ten.copyCount - previousCopies;
  stepCopies.push(bill);
  assert.ok(credit >= bill);
  credit = credit - bill + 2;
  assert.ok(credit >= 1);
  assert.equal(credit, 2 * ten.size - ten.capacity + 1);
  assert.equal(2 * ten.size - ten.capacity, [1, 2, 2, 4, 2, 4, 6, 8, 2, 4][n - 1]);
  previousCopies = ten.copyCount;
  assert.equal(ten.copyCount, provedCopyCount(n));
  assert.equal(ten.copyCount, ten.capacity - 1);
  assert.ok(ten.copyCount < 2 * n);
  assertDoublingInvariant(ten);
}
assert.deepEqual(capacities, [1, 2, 4, 4, 8, 8, 8, 8, 16, 16]);
assert.deepEqual(stepCopies, [0, 1, 2, 0, 4, 0, 0, 0, 8, 0]);
assert.equal(ten.copyCount, 15);
assert.equal(ten.capacity, 16);
assert.equal(credit, 5);
assert.deepEqual(ten.toArray(), [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]);

const prefixes = new DynamicArray();
let prefixCredit = 0;
let prefixPrevious = 0;
for (let n = 1; n <= 64; n += 1) {
  prefixes.append(n);
  const bill = prefixes.copyCount - prefixPrevious;
  assert.ok(prefixCredit >= bill);
  prefixCredit = prefixCredit - bill + 2;
  assert.equal(prefixCredit, 2 * n - prefixes.capacity + 1);
  assert.ok(2 * n - prefixes.capacity >= 0);
  assert.equal(prefixes.copyCount, provedCopyCount(n));
  assert.equal(prefixes.copyCount, prefixes.capacity - 1);
  assert.ok(prefixes.copyCount < 2 * n);
  if (n === 47) {
    assert.equal(provedCopyCount(47), 63);
    assert.equal(prefixes.copyCount, 63);
    assert.equal(prefixes.capacity, 64);
  }
  prefixPrevious = prefixes.copyCount;
}

const staticSlots = [10, 20, 30, 40, 50, 60, null, null];
let staticSize = 6;
let staticStep = insertStatic(staticSlots, staticSize, 2, 99);
staticSize = staticStep.size;
assert.equal(staticStep.moves, 4);
assert.equal(staticSize, 7);
assert.deepEqual(staticSlots, [10, 20, 99, 30, 40, 50, 60, null]);
staticStep = deleteStatic(staticSlots, staticSize, 3);
staticSize = staticStep.size;
assert.equal(staticStep.moves, 3);
assert.equal(staticSize, 6);
assert.deepEqual(staticSlots, [10, 20, 99, 40, 50, 60, null, null]);

const shifted = new DynamicArray();
for (const value of [10, 20, 30, 40, 50, 60]) {
  shifted.append(value);
}
assert.equal(shifted.copyCount, 7);
assert.equal(shifted.capacity, 8);
assert.equal(shifted.moveCount, 0);
shifted.insertAt(2, 99);
assert.equal(shifted.moveCount, 4);
assert.equal(shifted.copyCount, 7);
assert.deepEqual(shifted.toArray(), [10, 20, 99, 30, 40, 50, 60]);
assert.equal(shifted.deleteAt(3), 30);
assert.equal(shifted.moveCount, 7);
assert.equal(shifted.capacity, 8);
assert.deepEqual(shifted.toArray(), [10, 20, 99, 40, 50, 60]);

const doubledInsert = new DynamicArray();
for (const value of [10, 20, 30, 40]) {
  doubledInsert.append(value);
}
assert.equal(doubledInsert.copyCount, 3);
assert.equal(doubledInsert.capacity, 4);
doubledInsert.insertAt(1, 99);
assert.equal(doubledInsert.copyCount, 7);
assert.equal(doubledInsert.capacity, 8);
assert.equal(doubledInsert.moveCount, 3);
assert.deepEqual(doubledInsert.toArray(), [10, 99, 20, 30, 40]);

const gap = new DynamicArray();
for (const value of [10, 20, 30, 40, 50]) {
  gap.append(value);
}
assert.equal(gap.size, 5);
assert.equal(gap.capacity, 8);
assert.equal(gap.copyCount, 7);
assert.equal(gap.deleteAt(gap.size - 1), 50);
assert.equal(gap.deleteAt(gap.size - 1), 40);
assert.equal(gap.capacity, 8);
assert.equal(gap.copyCount, 7);
assert.equal(gap.deleteAt(gap.size - 1), 30);
assert.equal(gap.size, 2);
assert.equal(gap.capacity, 4);
assert.equal(gap.copyCount, 9);
assert.deepEqual(gap.toArray(), [10, 20]);
gap.append(60);
gap.append(70);
assert.equal(gap.capacity, 4);
assert.equal(gap.copyCount, 9);
assert.deepEqual(gap.toArray(), [10, 20, 60, 70]);
gap.append(80);
assert.equal(gap.capacity, 8);
assert.equal(gap.size, 5);
assert.equal(gap.copyCount, 13);
assert.deepEqual(gap.toArray(), [10, 20, 60, 70, 80]);
assertDoublingInvariant(gap);

const front = new DynamicArray();
for (const value of [10, 20, 30, 40, 50]) {
  front.insertAt(0, value);
}
assert.equal(front.moveCount, 10);
assert.equal(front.copyCount, 7);
assert.equal(front.capacity, 8);
assert.deepEqual(front.toArray(), [50, 40, 30, 20, 10]);

const plusSix = new PlusOneArray();
for (let i = 0; i < 6; i += 1) {
  plusSix.append(i);
}
assert.equal(plusSix.copyCount, 15);
assert.equal(plusSix.copyCount, (6 * 5) / 2);
const plusTwenty = new PlusOneArray();
for (let i = 0; i < 20; i += 1) {
  plusTwenty.append(i);
}
assert.equal(plusTwenty.copyCount, 190);
assert.equal(plusTwenty.copyCount, (20 * 19) / 2);
assert.ok(plusTwenty.copyCount > 2 * 20);

assert.equal(elementAddress(1000, 3, 8), 1024);
const matrix = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
assert.equal(rowMajorIndex(1, 2, 4), 6);
assert.equal(matrix[rowMajorIndex(1, 2, 4)], 7);
const rowOne = [];
const columnTwo = [];
for (let column = 0; column < 4; column += 1) {
  rowOne[column] = rowMajorIndex(1, column, 4);
}
for (let row = 0; row < 3; row += 1) {
  columnTwo[row] = rowMajorIndex(row, 2, 4);
}
assert.deepEqual(rowOne, [4, 5, 6, 7]);
assert.deepEqual(columnTwo, [2, 6, 10]);
assert.equal(rowOne[1] - rowOne[0], 1);
assert.equal(columnTwo[1] - columnTwo[0], 4);
assert.equal(columnTwo[2] - columnTwo[1], 4);

const four = concatenationCost(4, "a");
assert.equal(four.copies, 10);
assert.equal(four.value, "aaaa");
assert.equal(concatenationCost(32, "a").copies, 528);
const builderFour = new StringBuilder();
builderFour.append("a");
builderFour.append("a");
builderFour.append("a");
builderFour.append("a");
assert.equal(builderFour.length(), 4);
assert.equal(builderFour.buffer.copyCount, 3);
assert.ok(builderFour.buffer.copyCount < 2 * 4);
assert.equal(builderFour.toString(), "aaaa");
const builderThirtyTwo = new StringBuilder();
for (let i = 0; i < 32; i += 1) {
  builderThirtyTwo.append("a");
}
assert.equal(builderThirtyTwo.buffer.copyCount, 31);
assert.equal(builderThirtyTwo.buffer.capacity, 32);
assert.ok(builderThirtyTwo.buffer.copyCount < 2 * 32);
assert.equal(builderThirtyTwo.length(), 32);
const built = builderThirtyTwo.toString();
assert.equal(built, concatenationCost(32, "a").value);
for (let i = 0; i < 32; i += 1) {
  assert.equal(built[i], "a");
}

console.log("ALL TESTS PASSED");
```

---

## COMMON MISTAKES

1. **Wrong idea:** amortized $\Theta(1)$ means every append is $\Theta(1)$. **Correction:** append $2^m + 1$ copies $2^m$ elements and is $\Theta(n)$ in the worst case. The $\Theta(1)$ is $T(n)/n$ for the whole sequence.

2. **Wrong idea:** amortized cost is average-case cost. **Correction:** average-case takes the mean over a distribution on inputs. Amortized cost takes a worst-case sequence and divides. No probability was assumed in Parts 6 through 8.

3. **Wrong idea:** shift the tail from the insertion index toward the right, low index first. **Correction:** that order overwrites an element that has not been copied. The loop in Part 3 starts at the old size and moves downward.

4. **Wrong idea:** the doubling bound applies to any growth policy. **Correction:** adding one slot produces the arithmetic sum $n(n-1)/2$. The geometric closed form is a fact about powers of two.

5. **Wrong idea:** shrink as soon as the load factor is $1/2$, to avoid wasted space. **Correction:** doubling leaves the load factor just over $1/2$, so the next deletion would shrink immediately and the next append would grow again. The quarter threshold is what creates the linear gap in the no-thrash theorem.

6. **Wrong idea:** $\Phi = 2s - C$ may be used with an empty array of capacity $1$, where it equals $-1$, and then discarded because "potentials are nonnegative." **Correction:** that start is negative. The telescope upper-bounds the actual cost when $\Phi$ finishes at least as high as it started. The proof uses a start at capacity $0$, where $\Phi = 0$, and proves $\Phi \ge 0$ afterward.

7. **Wrong idea:** `push` on a JavaScript array is the algorithm whose cost was proved. **Correction:** the proved costs are the copy counts of `DynamicArray`. Engine representations change, and this lecture does not prove a theorem about them.

8. **Wrong idea:** a string is a dynamic array, so a loop of `+` is amortized $\Theta(1)$ per iteration. **Correction:** each `+` copies the whole left operand into a new string. $n$ iterations write $n(n+1)/2$ code units. The buffer is the dynamic array; the string is not.

9. **Wrong idea:** the flat index of $(i, j)$ is $j \cdot \mathrm{rows} + i$ in a row-major store. **Correction:** that formula is the column-major index. Row-major order uses $i \cdot \mathrm{cols} + j$. Using the other formula reads a different element.

10. **Wrong idea:** because append is amortized $\Theta(1)$, `insertAt(0, x)` is amortized $\Theta(1)$ too. **Correction:** the $n$ front insertions in Part 12 shift $n(n-1)/2$ elements. The resize copies stay below $2n$. The shifts are the quadratic term, and Lecture 03 owns the structure that avoids them.

---

## EXAMINATION

Closed book, $90$ minutes. The only operations and policies in force are the ones defined in this lecture: doubling, shrink at size $\le \lfloor \mathrm{capacity}/4 \rfloor$, charge $3$ with $2$ stored, and $\Phi = 2s - C$ from a capacity-$0$ start. Show arithmetic.

**Question 1. (8 points)** (a) State the fixed-width assumption. (b) Write the address formula. (c) The base is $250$ and the width is $8$. Compute the address of index $6$.

**Question 2. (10 points)** Give the worst-case cost of `length`, `get`, `set`, `append`, `insertAt`, and `deleteAt`. Give the amortized cost of `append`. Name the unit in which the append bounds are counted.

**Question 3. (10 points)** (a) Define worst-case cost, average-case cost, and amortized cost, one sentence each. (b) Define the aggregate method, the accounting method, and the potential method, one sentence each. (c) An append inside a doubling sequence copies $n/2$ elements. Which of the three costs in (a) is $\Theta(n)$ for that call, and which is $\Theta(1)$ for appends in that sequence?

**Question 4. (12 points)** A doubling array starts at size $0$ and capacity $1$. Append the values $4, 8, 15, 16, 23, 42$, in that order. For each append give the size, the capacity, and the number of elements copied on that append. Give the total number of copies, and check it against the series formula.

**Question 5. (10 points)** Let $n = 100$ for doubling appends with no deletion. Compute $C(100)$ exactly. Name the greatest power of two that is at most $99$, and also name the capacity after $100$ appends. Show $C(100) < 200$. Give the amortized copy cost $C(100)/100$ as a fraction in lowest terms, and give the total element-write count $n + C(n)$.

**Question 6. (10 points)** Using the six appends of Question 4 and the charge of $3$ units, build the accounting table with columns: append number, copy bill $b$, stock before the bill, stock after the bill and before the deposit, stock after the append. Show that the stock never goes negative. Check the final stock against $2s - C + 1$.

**Question 7. (12 points)** Use $\Phi = 2s - C$ with the capacity-$0$, size-$0$ start, then the same six appends as Question 4. The copy column is identical because the first append copies nothing in both setups. (a) Give $\Phi$ after each append. (b) For the append that doubles the capacity from $4$ to $8$, compute the actual cost $c$, $\Phi$ before, $\Phi$ after, and the amortized cost $\hat{c} = c + \Phi_{\mathrm{after}} - \Phi_{\mathrm{before}}$. (c) From the telescope, state why $\Phi(h_0) = 0$ and $\Phi(h_n) \ge 0$ imply that the total actual cost is at most the total amortized cost.

**Question 8. (12 points)** A matrix with $6$ rows and $5$ columns is stored in row-major order. The base address is $400$ and the element width is $4$ bytes. (a) The flat index of element $(4, 3)$. (b) The byte address of that element. (c) The flat indexes of row $4$. (d) The flat indexes of column $3$. (e) The stride, in bytes, between consecutive elements of that column. (f) The RAM-model cost of reading the row and of reading the column, and which walk touches neighboring addresses.

**Question 9. (8 points)** A loop concatenates one code unit, $n = 12$ times. (a) The exact number of code-unit writes under the language semantics used in this lecture. (b) The exact resize-copy count of a doubling buffer that appends those $12$ units one at a time. (c) The asymptotic total for each method.

**Question 10. (10 points)** (a) A doubling array has just grown from capacity $8$ to capacity $16$, and the size is $9$. How many one-element end-deletions are required before the shrink rule halves the store? What are the size and the capacity after that shrink? How many further appends are required before the next growth? (b) $n$ insertions at index $0$ perform how many shifts? Evaluate the formula at $n = 5$.

---

## ANSWER KEY

**Question 1.** (a) Every element occupies the same width $w$, and $w$ does not depend on the index, the length, or the value. (b) $\mathrm{address}(i) = B + i \cdot w$. (c) $250 + 6 \cdot 8 = 250 + 48 = 298$.

**Question 2.** The unit for the append bounds is one write of a live element into a slot. Worst case: `length`, `get`, and `set` are $\Theta(1)$; `append`, `insertAt`, and `deleteAt` are $\Theta(n)$. The amortized cost of `append` is $\Theta(1)$. The worst-case append bound remains $\Theta(n)$ on the append that copies a linear number of elements. `insertAt` and `deleteAt` at an arbitrary index are $\Theta(n)$ because of shifts; doubling does not remove those shifts.

**Question 3.** (a) Worst-case cost is the maximum cost of one call on an input of size $n$. Average-case cost is the mean cost over a stated distribution on inputs. Amortized cost is the total cost of a worst-case sequence divided by the number of operations in it. (b) The aggregate method divides that total by $n$. The accounting method charges each operation a declared number of units, stores the surplus as credit, and shows the stock never goes negative while paying later work. The potential method sets the amortized cost equal to the actual cost plus the change in a function of the state. (c) That single append has worst-case cost $\Theta(n)$. The amortized cost of append in the doubling sequence is $\Theta(1)$. Average-case is not the name of either statement.

**Question 4.**

| Append | Value | Size | Capacity | Copies |
| --- | --- | --- | --- | --- |
| $1$ | $4$ | $1$ | $1$ | $0$ |
| $2$ | $8$ | $2$ | $2$ | $1$ |
| $3$ | $15$ | $3$ | $4$ | $2$ |
| $4$ | $16$ | $4$ | $4$ | $0$ |
| $5$ | $23$ | $5$ | $8$ | $4$ |
| $6$ | $42$ | $6$ | $8$ | $0$ |

Total copies $0 + 1 + 2 + 0 + 4 + 0 = 7$. Here $n - 1 = 5$, and the greatest power of two at most $5$ is $4$, so $C(6) = 2 \cdot 4 - 1 = 7$. The capacity after six appends is $8$, and $8 - 1 = 7$.

**Question 5.** $n - 1 = 99$. The greatest power of two at most $99$ is $64$, because $64 \le 99$ and $128 > 99$. Then $C(100) = 2 \cdot 64 - 1 = 127$. The least power of two that is at least $100$ is $128$, so the capacity is $128$ and $C(100) = 128 - 1 = 127$. And $127 < 200$. The amortized copy cost is $127/100$. The fraction is already in lowest terms: $127$ is prime and does not divide $100$. The total element writes are $100 + 127 = 227$, and $227 / 100 = 2.27 < 3$.

**Question 6.** The first append copies nothing, so a start at capacity $1$ with stock $0$ reaches the same stock as the capacity-$0$ start. Charge $3$ on every row: $1$ pays the write, and $2$ is deposited after the bill.

| Append | $b$ | Before | After the bill | After the append |
| --- | --- | --- | --- | --- |
| $1$ | $0$ | $0$ | $0$ | $2$ |
| $2$ | $1$ | $2$ | $1$ | $3$ |
| $3$ | $2$ | $3$ | $1$ | $3$ |
| $4$ | $0$ | $3$ | $3$ | $5$ |
| $5$ | $4$ | $5$ | $1$ | $3$ |
| $6$ | $0$ | $3$ | $3$ | $5$ |

The stock at payment is $0, 2, 3, 3, 5, 3$, each at least the bill $0, 1, 2, 0, 4, 0$. The remainder after each bill is $0, 1, 1, 3, 1, 3$, never negative. Final size $6$, capacity $8$, and $2 \cdot 6 - 8 + 1 = 5$, which matches the last cell.

**Question 7.** (a) After the six appends, $(s, C)$ is $(1, 1)$, $(2, 2)$, $(3, 4)$, $(4, 4)$, $(5, 8)$, $(6, 8)$. Then $\Phi$ is $2 - 1 = 1$, $4 - 2 = 2$, $6 - 4 = 2$, $8 - 4 = 4$, $10 - 8 = 2$, $12 - 8 = 4$. (b) The fifth append doubles from $4$ to $8$. Before it, size $4$, capacity $4$, $\Phi = 4$, and $c = 4 + 1 = 5$. After it, $\Phi = 2$. Then $\hat{c} = 5 + 2 - 4 = 3$. (c) $\sum c_i = \sum \hat{c}_i + \Phi(h_0) - \Phi(h_n)$. The hypothesis $\Phi(h_0) = 0$ removes the first potential, and $\Phi(h_n) \ge 0$ makes $-\Phi(h_n) \le 0$, so $\sum c_i \le \sum \hat{c}_i$.

**Question 8.** (a) $4 \cdot 5 + 3 = 23$. (b) $400 + 23 \cdot 4 = 400 + 92 = 492$. (c) Row $4$ starts at $4 \cdot 5 = 20$ and holds five entries: $20, 21, 22, 23, 24$. (d) Column $3$ is $i \cdot 5 + 3$ for $i = 0, \ldots, 5$: $3, 8, 13, 18, 23, 28$. (e) The element stride is $5$, so the byte stride is $5 \cdot 4 = 20$. (f) The row read is $\Theta(5)$ accesses and the column read is $\Theta(6)$ accesses. Successive row addresses differ by the width $4$. Successive column addresses differ by $20$. The row walk is the one whose addresses are neighbors.

**Question 9.** (a) $12 \cdot 13 / 2 = 78$. (b) $n - 1 = 11$, and the greatest power of two at most $11$ is $8$, so $C(12) = 16 - 1 = 15$. The capacity after $12$ appends is $16$, and $16 - 1 = 15$. (c) The concatenation total is $\Theta(n^2)$. The buffer's resize copies plus $n$ placements are $\Theta(n)$.

**Question 10.** (a) The shrink test at capacity $16$ is size $\le \lfloor 16 / 4 \rfloor = 4$. The size must fall from $9$ to $4$, which takes $9 - 4 = 5$ deletions. This matches $(C + 1) - \lfloor C / 2 \rfloor$ with $C = 8$: $9 - 4 = 5$. After the shrink the size is $4$ and the capacity is $8$. The next growth occurs on the append that finds size $8$. From size $4$, four appends reach size $8$ without growing, and the fifth append grows: $8/2 - \lfloor 8 / 4 \rfloor + 1 = 4 - 2 + 1 = 5$. (b) The insertion that finds size $k$ shifts $k$ elements, for $k = 0, \ldots, n - 1$. The total is $n(n - 1)/2$. At $n = 5$ the value is $10$.

---

## INDEPENDENT ASSIGNMENT

This assignment takes several hours and produces two artifacts: a written proof, and a JavaScript program you keep. Write both from a blank file. Later lectures assume you can still build this array without looking.

**The claim to prove.** Any sequence of $m$ operations, each an append or a delete-at-end, on the doubling array with the quarter-capacity shrink rule, has total element-write cost at most $3m$. Count $1$ unit for placing a new element or for the logical removal, plus $1$ unit per live element copied on a resize. The $\Theta(1)$ index arithmetic outside those writes may be named and then absorbed; the $3m$ bound is about the writes that can be linear.

**The potential to use.** Let $\Phi = 0$ when the capacity is $0$. When the capacity $C$ is positive and the size $s$ satisfies $s \ge C/2$, let $\Phi = 2s - C$. When $s < C/2$, let $\Phi = C/2 - s$.

Prove that $\Phi \ge 0$ on every state. Prove that every append and every delete-at-end has amortized cost at most $3$. The useful split is: append versus delete-at-end; resize versus no resize; load factor at least $1/2$, strictly below $1/2$, or crossing $1/2$ during the operation. Capacities are $0$ or powers of two, and a deletion decreases the size by exactly $1$, so the shrink threshold is crossed rather than jumped. Include the telescope: if $\Phi$ starts at $0$, stays nonnegative, and each amortized cost is at most $3$, the total actual cost is at most $3m$.

**The program.** Implement the array and this potential. Run a fixed sequence of at least $1000$ operations with no file and no network: a phase of appends, a phase that empties the array by delete-at-end, and a mixed phase such as two appends then one delete-at-end, repeated. After every operation assert $\Phi \ge 0$ and assert the representation invariant from Part 5. Assert that the summed actual write-cost is at most $3$ times the number of operations. Print a single line, `ASSIGNMENT CHECK PASSED`, on success.

The no-thrash theorem is already proved in the lecture. This assignment is the case analysis that turns the gap into the $3m$ bound. Do not replace the case analysis by a timing measurement.

---

## GLOSSARY

**Accounting method.** A way to bound the total cost of a sequence by charging each operation a declared number of units and storing the surplus as credit that later operations spend.

**Address.** The location of a slot, computed for an array element as base plus index times width.

**Aggregate method.** A way to bound amortized cost by dividing the total actual cost of a sequence by the number of operations.

**Amortized cost.** The cost per operation in a worst-case sequence: an upper bound on the total cost, divided by the length of the sequence. Not a distributional average, and not a promise about every single call.

**Append.** Insertion at index $n$, where $n$ is the current size.

**Array.** The ADT of a finite sequence with `length`, `get`, and `set`. In this lecture the implementation is contiguous.

**Average-case cost.** The mean cost over a stated probability distribution on inputs. This lecture does not prove one.

**Base address.** The address of index $0$.

**Buffer.** A dynamic array of code units used to build a string with a linear number of writes, plus one final assembly.

**Capacity.** The number of slots in the current store. The size never exceeds it.

**Code unit.** One UTF-16 unit of a JavaScript string. Indexing is by code unit. A scalar value may occupy two units.

**Contiguous storage.** A layout in which successive elements occupy successive addresses, separated by the element width, with no per-element link.

**Copy.** A write of a live element into a newly allocated store during a resize. `copyCount` records these writes.

**Credit.** Units of charge that have been stored and not yet spent. In the append accounting scheme the stock after $n \ge 1$ appends equals $2s - C + 1$.

**Dynamic array.** An array implementation that allocates a new contiguous store when an insertion finds the current store full, and that can shrink under a stated rule.

**Element width.** The number of addressable units occupied by one slot. Constant under the fixed-width assumption.

**Fixed-width assumption.** The element width does not depend on the index, the size, or the value. It is what makes $B + i \cdot w$ a constant-time address.

**Geometric growth.** Growth of capacity by a constant factor. In this lecture the factor is $2$.

**Index.** The zero-based position of an element. The flat index of a row-major pair $(i, j)$ is $i \cdot \mathrm{cols} + j$.

**Load factor.** Size divided by capacity, defined when the capacity is positive. Doubling occurs at load factor $1$. Shrinking is allowed at load factor $1/4$ and below.

**Move.** A write of a live element from one slot to a neighboring slot during `insertAt` or `deleteAt`. `moveCount` records these writes. Append performs none.

**Potential function.** A real-valued function of the state. This lecture's append potential is $\Phi = 2s - C$, with value $0$ at size $0$, capacity $0$.

**Potential method.** The analysis that defines the amortized cost of a step as the actual cost plus the change in potential, then uses a telescope.

**Row-major order.** The matrix layout that stores each row in consecutive slots, row $0$ first. Column-major order stores each column in consecutive slots; this lecture's formula is the row-major one.

**Safe integer.** An integer JavaScript represents exactly. The nonnegative ones run through $2^{53} - 1$. Address arithmetic outside that range is rejected.

**Shrink policy.** The rule that halves capacity when a deletion leaves size $\le \lfloor \mathrm{capacity} / 4 \rfloor$ and the capacity is at least $2$.

**Size.** The number of live elements. `length` returns it.

**Slot.** One fixed-width cell in the store. The live slots are the indexes $0$ through $\mathrm{size} - 1$.

**Spatial locality.** The reuse of a fetched memory block by later accesses to neighboring addresses. Part 2 describes it and does not quantify it in cycles.

**Static array.** A contiguous array whose capacity is fixed. Insertion that would pass the capacity overflows.

**Stride.** The difference in index, or in address, between successive elements of a walk. A row-major row has element stride $1$. A row-major column has element stride equal to the number of columns.

**String immutability.** The language rule that no operation changes an existing JavaScript string in place. Concatenation produces a new string.

**Thrashing.** A pattern in which consecutive operations each copy $\Theta(n)$ elements, which happens if the grow threshold and the shrink threshold sit on top of each other.

**Worst-case cost.** The maximum cost of one operation on an input of size $n$.

**Stack, as a forward pointer.** Not defined here. Lecture 04 defines the ADT. The only fact used in this lecture is that append and delete-at-end are a possible representation of its updates.

---

## LECTURE SUMMARY

An array element at index $i$ lives at address $B + i \cdot w$ when every slot has the same width $w$. In the RAM model that formula is a constant amount of arithmetic plus one memory access, so `get`, `set`, and a stored `length` are $\Theta(1)$. The same formula is why a scan touches neighboring addresses, and why inserting or deleting at an arbitrary index is $\Theta(n)$: the neighbors have to move. A static array stops when it is full. A dynamic array allocates a new block.

If the new block is only one slot larger, $n$ appends copy $n(n-1)/2$ elements and the amortized cost is $\Theta(n)$. If the new block is twice as large, the copy sizes are the powers of two up through the greatest power at most $n - 1$. That sum equals the current capacity minus $1$ and is strictly less than $2n$, including on lengths that are not one past a power of two, where several appends in a row copy nothing. Three arguments give the same $O(1)$ amortized append bound: divide the total by $n$; charge $3$ units and keep a stock of $2s - C + 1$; or use the potential $2s - C$, which stays nonnegative from a capacity-$0$ start and gives amortized cost at most $3$ on every append. A single append can still be $\Theta(n)$. Shrinking at one quarter, rather than at one half, leaves a linear number of operations between a growth and a shrinkage. The full $O(1)$ bound for a mix of append and delete-at-end is stated in the lecture and proved in the assignment.

Row-major order places $(i, j)$ at flat index $i \cdot \mathrm{cols} + j$. A row walk has stride $1$. A column walk has stride $\mathrm{cols}$. In the RAM model both cost a constant per element; the locality differs. A JavaScript string is immutable, so a loop of concatenations copies a triangular number of code units. A dynamic array of those units, joined once, is the linear construction. Insertion at the front still shifts a triangular number of elements, and that is the point at which Lecture 03 takes over.

## FIVE PRINCIPLES

1. The address of index $i$ is base plus $i$ times the width, and the arithmetic is $\Theta(1)$ because the width is a constant.
2. Doubling turns resize copies into a geometric series whose sum is strictly less than $2n$; adding one slot turns them into an arithmetic series of $\Theta(n^2)$.
3. Amortized $\Theta(1)$ is a theorem about every sequence under a stated cost model. It is compatible with a single operation that copies every live element.
4. The shrink threshold has to sit a constant factor below the growth threshold. Quarter-full versus completely full is the gap that prevents thrashing.
5. A $\Theta(n)$ shift is paid by the operation that performs it. Credits stored for doubling do not pay for insertion at the front, and string concatenation does not become a dynamic array by being written in a loop.

---

## REFERENCES

1. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapter 16 (amortized analysis: aggregate, accounting, potential, and dynamic tables) and Section 10.1 (arrays and row-major matrices). In the 3rd edition the amortized-analysis chapter is Chapter 17.
2. Robert Sedgewick and Kevin Wayne. *Algorithms*. 4th edition. Addison-Wesley, 2011. Section 1.3, resizing arrays. [https://algs4.cs.princeton.edu/13stacks/](https://algs4.cs.princeton.edu/13stacks/)
3. Michael T. Goodrich, Roberto Tamassia, and Michael H. Goldwasser. *Data Structures and Algorithms in Java*. 6th edition. Wiley, 2014. Section 7.2, array lists, dynamic arrays, their amortized analysis, and the role of a string builder.
4. Mark Allen Weiss. *Data Structures and Algorithm Analysis in C++*. 4th edition. Pearson, 2014. Chapter 3, the vector and its geometric expansion.
5. Donald E. Knuth. *The Art of Computer Programming, Volume 1: Fundamental Algorithms*. 3rd edition. Addison-Wesley, 1997. Section 2.2.6, sequential storage of arrays in lexicographic (row-major) order. The orthogonal-list material in that section is outside this lecture.
6. Robert E. Tarjan. "Amortized Computational Complexity." *SIAM Journal on Algebraic and Discrete Methods*, 6(2), 1985.
7. Daniel D. Sleator and Robert E. Tarjan. "Amortized Efficiency of List Update and Paging Rules." *Communications of the ACM*, 28(2), 1985. The source of the potential method as a general technique. The list-update rule itself is outside this lecture.
8. Ecma International. *ECMA-262, ECMAScript Language Specification*. 13th edition, 2022. The String type is a sequence of code units, and string operations produce strings rather than modifying an existing one.
9. Ulrich Drepper. "What Every Programmer Should Know About Memory." 2007. Further reading on caches and spatial locality. Part 2 of this lecture does not depend on a measurement from that paper.
