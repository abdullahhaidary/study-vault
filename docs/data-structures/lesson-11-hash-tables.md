# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 11 — HASH TABLES

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 11 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 8 hours
**Prerequisites:** Lecture 01 — Models, ADTs, and Asymptotic Analysis; Lecture 02 — Arrays, Dynamic Arrays, and Amortized Analysis
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapter 11; Sedgewick and Wayne, *Algorithms*, 4th edition, Section 3.4; Knuth, *The Art of Computer Programming*, Volume 3, 2nd edition, Section 6.4

**This lecture owns:** hash functions, separate chaining, the load factor, open addressing, and the assumption behind expected constant time.
**This lecture does not teach:** balanced trees, cryptographic hashing, or perfect hashing beyond a definition.

---

## Learning objectives

After this lecture you can:

1. State the map operations `put`, `get`, `delete`, and `contains`, and state that a key is identified by equality.
2. Draw the chains and the load factor after a given sequence of insertions and one deletion.
3. Compute the division hash and the polynomial string hash, including every intermediate product, for base $31$ and modulus $101$.
4. State simple uniform hashing in symbols and compute the expected number of elements examined by an unsuccessful search and by a successful search.
5. Count the key-moves in a doubling rehash and give the amortized number of moves per insertion.
6. Trace linear probing through insertions, a tombstone deletion, and a later insertion that reuses the tombstone.
7. Compute a double-hashing probe sequence and state the coprime condition under which that sequence visits every slot.
8. Show a quadratic probe sequence that misses slots, and explain primary clustering from a drawn run of occupied slots.
9. Use the cost table to place chaining, linear probing, and double hashing, and name order, the linear worst case, and a known fixed hash as reasons a hash table is the wrong map.
10. Run the laboratory program and read the line `ALL TESTS PASSED`.

---

## Purpose

A map stores values under keys and answers a direct question: given this key, what value is paired with it? Lecture 08 answers that question by walking a binary search tree. The cost follows the height of the tree. This lecture answers it by computing a slot from the key. When the keys spread across the slots, and the table grows so that the number of keys stays proportional to the number of slots, the expected cost of one search is constant. That sentence is the whole promise of the lecture, and every clause in it is a hypothesis you will be able to point at.

The mechanism is a hash function, a rule for collisions, and a resize that rehashes every live key. Collisions are part of the design. A table that forbade them would need one slot for every conceivable key, which is the direct-address table of Part 2, and that table is unusable when the universe of keys is huge and the set you actually store is small.

## What this lecture deliberately does not teach

Balanced search trees stay in Lecture 09. This lecture compares a hash table with the binary search tree of Lecture 08 in one table, and it stops there. It does not rotate, recolor, or split a node.

A cryptographic hash is built so that finding a preimage, or finding two inputs with the same output, is hard for an attacker. A hash for a table only has to spread the keys you store. Those specifications are different. This lecture does not construct SHA-256, or any other cryptographic hash, and it does not treat a cryptographic hash as a substitute for the analysis below.

A perfect hash for a fixed set is defined in Part 4. No construction is given.

Randomized hashing is named in Part 8, because an adversary who knows a fixed hash can force the worst case. The construction of a universal family is not given.

---

## Part 1 — The map abstract data type

### Definition

A **map** is an abstract data type that stores a finite set of pairs. Each pair joins a **key** to a **value**. The value is sometimes called satellite data: the structure locates it, and the structure does not interpret it. Keys in one map are unique. A second `put` with a key that is already present replaces the value and leaves the number of keys unchanged.

The operations are:

| Operation | Behavior |
| --- | --- |
| `put(key, value)` | If `key` is absent, store the pair. If `key` is present, replace its value. |
| `get(key)` | Return the value paired with `key`. If `key` is absent, report absence. |
| `delete(key)` | If `key` is present, remove its pair. If `key` is absent, leave the map unchanged. |
| `contains(key)` | Return whether `key` is present. |

In the JavaScript of this lecture, absence is `null`, and every stored value is a number or a string, never `null`. Then `get` returns `null` only for an absent key, and `contains` is the test `get(key) !== null`. A stored value of `0` is present. A production map that must store `null` uses a separate presence flag. That flag does not change the costs proved here.

### Equality, and the order a map does not have

`get` decides which pair to return by **equality** of keys. Two keys are equal or they are not. The map does not ask which key is smaller.

A **total order** is a different requirement. It decides, for every pair of unequal keys, which one comes first. Lecture 08's binary search tree needs a total order. The search property of that lecture is what makes an in-order walk list keys from smallest to largest, and what makes a successor and a range query possible. This lecture does not use that property and does not re-teach the tree.

A hash table can be walked, but the walk visits slots in index order. That order is an artifact of the hash and of the collision rule. It is not the order of the keys. If the keys are numbers and you need them sorted, sorting is a separate algorithm from Lecture 06. The table will not hand you the sorted order.

### Comparison with the binary search tree of Lecture 08

The costs in the tree column are the costs Lecture 08 attaches to the height and to a random insertion order. This table does not derive them again.

| Question | Binary search tree, Lecture 08 | Hash table, this lecture |
| --- | --- | --- |
| What a key must provide | A total order | Equality, and a hash into the slots |
| Where a successful search looks | One root-to-node path | One computed slot, then a chain or a probe sequence |
| Cost of search, insert, and delete | Determined by the height. The height depends on insertion order, as Lecture 08 proves | Expected $\Theta(1+\alpha)$ under simple uniform hashing when the load factor $\alpha$ is the quantity defined in Part 4 and the operation does not resize. Worst case $\Theta(n)$ |
| Iteration | An in-order walk lists keys from smallest to largest | Slot order, which is not key order |
| Successor and range queries | Provided by the search property | Absent. The next larger key is found only by inspecting stored keys and comparing them |
| Extra space beyond the $n$ pairs | The links in the nodes | The empty slots. Chaining uses $\Theta(n+m)$ words. Open addressing uses $\Theta(m)$ words and requires $n \le m$ |

Choose the tree when the client of the map needs order. Choose the hash table when the client needs equality lookup and accepts the hashing assumption and the linear worst case. Part 8 states that choice with numbers.

---

## Part 2 — Direct-address tables

### Definition

Let the **universe** of keys be
$$
U = \{0, 1, \ldots, u-1\}.
$$
A **direct-address table** is an array $T[0..u-1]$. The key is the index. An empty slot holds `null`. An occupied slot holds the value paired with that key.

```text
index:   0     1     2     3     4     5
T:     [null] [v1] [null] [v3] [null] [v5]
```

The operations are indexing, which the RAM model of Lecture 01 charges as $\Theta(1)$:

```text
put(k, v):      T[k] = v
get(k):         return T[k]
delete(k):      T[k] = null
contains(k):    return T[k] !== null
```

Each operation is $\Theta(1)$ in the worst case. There is no collision, because two different keys are two different indexes. The space is $\Theta(u)$ whether you store $n = u$ keys or $n = 1$ key. The empty slots are allocated.

### When the universe is the right size

If every integer from $0$ to $u-1$ is a plausible key and $u$ is a few thousand, the direct-address table is the structure to use. The bound is worst-case constant time, and it does not depend on a hashing assumption. Hashing would add a collision rule you do not need.

### When the universe is too large

Suppose employee identifiers are 9-digit numbers, so $u = 10^9$, and the company stores $n = 1000$ employees. A direct-address table asks for an array of length $10^9$. Almost every slot would be empty. The machine may be unable to allocate it, and if it can, the space is proportional to the universe rather than to the set you store.

The set you store is $K \subseteq U$ with $|K| = n \ll u$. A hash table allocates $m$ slots with $m$ chosen near $n$, not near $u$. A **hash function**
$$
h : U \to \{0, 1, \ldots, m-1\}
$$
sends each key to a slot. Because $m < u$ whenever the universe is larger than the table, the pigeonhole principle says that at least two keys of $U$ share a slot. Those two keys **collide**. The rest of the lecture is the design of $h$ and the design of what the table does when a collision happens.

---

## Part 3 — Hash functions

### Definition

A hash function for a table of $m$ slots is a function
$$
h : U \to \{0, 1, \ldots, m-1\}.
$$
It has two jobs, and they are different jobs.

**Deterministic.** If $k = k'$, then $h(k) = h(k')$. The same key must return to the same slot on every call. Otherwise `get` cannot find the pair that `put` stored. Determinism is a requirement of correctness, not a hope about distribution.

**Close to uniform on the keys you store.** Each slot should receive about the same number of keys from the set that is actually inserted. "Close to uniform" is the design goal. **Simple uniform hashing**, defined in Part 4, is the probabilistic model that turns the goal into an equation. A particular formula, such as $k \bmod m$, is one function. It may meet the goal on one set of keys and miss it on another.

A hash is not required to be one-to-one. If it were one-to-one on all of $U$, then $m$ would be at least $|U|$, and the table would be a direct-address table.

The implementation below hashes nonnegative integers with the division method. JavaScript's `%` operator agrees with mathematical modulo for a nonnegative left operand and a positive right operand. It does not agree for a negative left operand: the remainder can be negative, and a negative number is not a slot index. This lecture rejects negative keys at the boundary of the map. It does not silently repair them.

### The division method

The **division method** is
$$
h(k) = k \bmod m.
$$
One division produces the slot. The quality of the slot depends on $m$.

**Theorem.** Let $d$ and $m$ be positive integers and let $g = \gcd(d, m)$. As $t$ runs through the integers, the residues of $t \cdot d$ modulo $m$ take exactly $m/g$ distinct values.

**Proof.** Write $d = g d_1$ and $m = g m_1$, so $\gcd(d_1, m_1) = 1$. Then
$$
t d = t g d_1 \equiv g \cdot (t d_1) \pmod{g m_1}.
$$
The residue is $g$ times a residue modulo $m_1$. Because $\gcd(d_1, m_1) = 1$, $d_1$ has a multiplicative inverse modulo $m_1$, and as $t$ runs, $t d_1 \bmod m_1$ runs through every residue modulo $m_1$ exactly once per period. There are $m_1 = m/g$ such residues, and therefore $m/g$ distinct residues of $t d$ modulo $m$.

**Corollary.** Keys in an arithmetic progression with difference $d$ occupy $m / \gcd(d, m)$ slots of a division table. If $m$ is prime and $m$ does not divide $d$, then $\gcd(d, m) = 1$ and the progression eventually occupies every slot. If $m$ is composite and $\gcd(d, m) > 1$, the progression is confined to a proper subset of the slots, no matter how long it is.

The corollary is why a prime table length helps some key patterns. It is not a promise that every set of keys spreads out. A prime modulus does not stop an adversary who picks many keys already known to share one residue.

Work the corollary on the keys $0, 4, 8, 12, 16, 20$, which are the progression with difference $4$.

With $m = 12$:
$$
0, 4, 8, 0, 4, 8.
$$
Three distinct slots. And $\gcd(4, 12) = 4$, so $12/4 = 3$. The infinite progression never leaves those three slots.

With $m = 11$:
$$
0, 4, 8, 1, 5, 9.
$$
Six distinct slots in this finite list. And $\gcd(4, 11) = 1$, so $11/1 = 11$. The infinite progression occupies every residue. These six keys are six of the eleven, and they have not repeated.

A second failure of the division method is specific to powers of two. If $m = 2^p$, then $k \bmod m$ is the integer formed by the least significant $p$ bits of $k$. Two keys that agree on those bits collide, whatever their other bits are. A prime modulus is not subject to that bit truncation. The division may be slower than a bit mask. The residue set is the quantity this lecture optimizes, and a faster instruction does not repair a residue set that has collapsed.

CLRS, Chapter 11, records the practical rule that a prime $m$, not close to a power of two, is a reasonable static choice for the division method, and that the method still has no guarantee for every key set. That is the status of the rule here: a consequence of the theorem above for arithmetic progressions and for low bits, not a theorem that every input is uniform.

### The multiplication method

The **multiplication method** separates the choice of the constant from the choice of $m$. Let $A$ satisfy $0 < A < 1$. The slot is
$$
h(k) = \left\lfloor m \cdot (k A \bmod 1) \right\rfloor,
$$
where $k A \bmod 1$ means the fractional part $k A - \lfloor k A \rfloor$.

**Knuth's recommendation, stated and not derived.** Knuth, *The Art of Computer Programming*, Volume 3, Section 6.4, recommends
$$
A = \frac{\sqrt{5} - 1}{2} \approx 0.618033988749895.
$$
The continued-fraction argument that selects this constant is not proved in this lecture. The constant is a recommendation you may use. It is not a theorem of this course that this $A$ makes every key set uniform.

The same section of Knuth is the source of the integer used in the multiply-shift form. CLRS, Chapter 11, works an example with the 32-bit constant $2654435769$, which is Knuth's integer suggestion for a word of that width. This lecture does not implement bit shifts. It evaluates the fractional formula for two small keys, where the floor is unambiguous, and it leaves the formula out of the structures you will run for the rest of the laboratory. Those structures use integer arithmetic.

JavaScript evaluates $A$ as `(Math.sqrt(5) - 1) / 2`, which prints `0.6180339887498949`. That is a floating-point approximation of an irrational number. For the two keys below, the value that is then scaled by $m$ sits well away from an integer, so the floor is stable. This is not a claim that $k \cdot A$ is exact in IEEE-754 for every key. For a large key the product can round. Do not build a hash table on this floating-point expression and then cite the proofs in Part 4 as if they applied to the rounded function.

Take $m = 8$.

For $k = 10$:
$$
10 A = 6.180339887498949, \qquad \{10 A\} = 0.180339887498949,
$$
$$
8 \cdot \{10 A\} = 1.442719099991592, \qquad h(10) = 1.
$$

For $k = 11$:
$$
11 A = 6.798373876248844, \qquad \{11 A\} = 0.798373876248844,
$$
$$
8 \cdot \{11 A\} = 6.386991009990751, \qquad h(11) = 6.
$$

The braces denote the fractional part. The two keys are consecutive integers and they land in different slots. That is one example, not a distribution.

### Polynomial hashing of a string

A string is a sequence of character codes $c_0, c_1, \ldots, c_{r-1}$. The **polynomial hash** with base $a$ and modulus $m$ is the Horner recurrence
$$
h_0 = 0, \qquad h_{i+1} = (h_i \cdot a + c_i) \bmod m,
$$
and the hash of the string is $h_r$. The empty string has hash $0$.

The base $a$ is a fixed integer you choose, at least $2$. The recurrence is the evaluation of the polynomial
$$
c_0 a^{r-1} + c_1 a^{r-2} + \cdots + c_{r-1}
$$
modulo $m$, reduced at every step so the intermediate value stays smaller than $m \cdot a$ plus one character code.

**The safe-integer constraint.** A JavaScript number is an exact integer for every integer in the closed interval from $-(2^{53}-1)$ to $2^{53}-1$. The positive end is `Number.MAX_SAFE_INTEGER`, equal to $9007199254740991$. Outside that interval, consecutive integers are not all representable, and a product that has been rounded is no longer the mathematical product. The `%` operator then returns the remainder of the rounded value, which is a different hash.

`charCodeAt` returns a UTF-16 code unit in $\{0, 1, \ldots, 65535\}$. Inside the recurrence, $h_i$ is in $\{0, 1, \ldots, m-1\}$, so the largest value that must be exact is
$$
(m-1) \cdot a + 65535.
$$
That quantity must be at most $2^{53}-1$. Reducing modulo $m$ after a product that has already overflowed the safe range does not restore the mathematical residue.

**The pair this lecture uses.** Take $a = 31$ and $m = 101$. Then
$$
(101-1) \cdot 31 + 65535 = 3100 + 65535 = 68635,
$$
and $68635 \le 2^{53}-1$. Every product and every sum in the recurrence is an exact integer, and the remainder is the mathematical remainder. The laboratory asserts both the bound $68635$ and the hashes computed from it. If you change the modulus, you recompute $(m-1) \cdot a + 65535$ before you trust the hash. A modulus near $2^{40}$ with a base near $2^{20}$ fails the test, even though the source code still contains a `%` sign.

The function is:

```javascript
function polynomialHash(text, base, modulus) {
  let hash = 0;
  for (let index = 0; index < text.length; index += 1) {
    const code = text.charCodeAt(index);
    hash = (hash * base + code) % modulus;
  }
  return hash;
}
```

**Trace of `"cat"`.** The codes are `c = 99`, `a = 97`, `t = 116`. Base $31$, modulus $101$.

$$
\begin{align*}
h &= (0 \cdot 31 + 99) \bmod 101 = 99, \\
99 \cdot 31 + 97 &= 3069 + 97 = 3166, \\
3166 - 31 \cdot 101 &= 3166 - 3131 = 35, \\
35 \cdot 31 + 116 &= 1085 + 116 = 1201, \\
1201 - 11 \cdot 101 &= 1201 - 1111 = 90.
\end{align*}
$$

So $h(\texttt{"cat"}) = 90$.

**Trace of `"dog"`.** The codes are `d = 100`, `o = 111`, `g = 103`.

$$
\begin{align*}
h &= 100, \\
100 \cdot 31 + 111 &= 3100 + 111 = 3211, \\
3211 - 31 \cdot 101 &= 3211 - 3131 = 80, \\
80 \cdot 31 + 103 &= 2480 + 103 = 2583, \\
2583 - 25 \cdot 101 &= 2583 - 2525 = 58.
\end{align*}
$$

So $h(\texttt{"dog"}) = 58$.

The one-character string `"a"` has code $97$, and $97 < 101$, so its hash is $97$. The empty string has hash $0$.

A string key enters a table in two steps when the table length is not $101$. First the polynomial hash produces an integer in $\{0, 1, \ldots, 100\}$. Then the division method reduces that integer modulo the table length. When the table length is $101$, the polynomial hash is already the slot. The chained and open-addressed maps in the laboratory take nonnegative integer keys directly, so each slot in the traces is a remainder you can check by hand. The polynomial hash is tested on the strings above, and on the string in the laboratory problems.

---

## Part 4 — Collisions and separate chaining

### A collision is an ordinary event

If $|U| > m$, collisions exist in $h$ whether or not your particular set hits one. A collision is two keys with the same slot. It is the situation the collision rule was built for. It is not a signal that the table has failed, and it is not a signal to replace the hash function in the middle of a search.

**Separate chaining** gives each slot a list. Every key that hashes to slot $j$ is stored in the list at slot $j$, and in no other list. Lecture 03 owns the linked-list representation of a sequence. The list at a slot is that sequence. This lecture stores it in a JavaScript array used only as a list: index $0$ is the front, `push` appends at the tail, and a search scans from index $0$ toward the tail. The array is the chain. It is not a second hash table. There is no second hash function inside a slot.

Appending one pair is the dynamic-array append of Lecture 02. With the load factor held constant, the chain is short and that append is amortized constant time on the chain array. If a chain grows to length $n$, the scan is $\Theta(n)$, which is already the worst case of the hash table. Deletion shifts the tail of that one array with `splice`. The shift costs time proportional to the length of the chain, the same order as the scan that found the key.

The **load factor** is
$$
\alpha = \frac{n}{m},
$$
where $n$ is the number of keys stored and $m$ is the number of slots. It is the average chain length in the following exact sense. Let $L_j$ be the length of the chain at slot $j$. Then $\sum_{j=0}^{m-1} L_j = n$, so
$$
\frac{1}{m} \sum_{j=0}^{m-1} L_j = \frac{n}{m} = \alpha.
$$
This identity needs no probabilistic assumption. It is true for a terrible hash and for a good one. What it does not say is that every chain has length near $\alpha$. One chain of length $n$ and $m-1$ empty chains still average to $\alpha$.

### The hashing assumption, in symbols

**Simple uniform hashing.** For every key $k$ and every slot $j$,
$$
\Pr(h(k) = j) = \frac{1}{m},
$$
and the hash values of distinct keys are independent of each other.

CLRS, 4th edition, Chapter 11, states this same assumption under the name **independent uniform hashing**. This lecture uses the name simple uniform hashing. Both names mean the display above. The assumption is a model of an ideal hash. The division function $k \bmod m$ is a fixed function, and there exist sets of keys on which it is constant. On those sets the assumption is false, and the expectation theorems do not apply. Part 8 returns to that gap.

Under the assumption, linearity of expectation gives the expected length of one particular chain. The sample space is finite: each of the $n$ keys has $m$ possible slots, and every assignment has probability $m^{-n}$. For a sum of random variables on a finite space,
$$
\mathrm{E}\left[\sum_i X_i\right] = \sum_{\omega} \Pr(\omega) \sum_i X_i(\omega) = \sum_i \mathrm{E}[X_i],
$$
because a finite sum may be interchanged. If $X_i$ is $0$ or $1$, then $\mathrm{E}[X_i] = \Pr(X_i = 1)$.

Let $I_{ij} = 1$ when key $i$ hashes to slot $j$. Then $\mathrm{E}[I_{ij}] = 1/m$, and
$$
\mathrm{E}[L_j] = \mathrm{E}\left[\sum_{i=1}^{n} I_{ij}\right] = \frac{n}{m} = \alpha.
$$
So each slot, not only the average slot, has expected length $\alpha$. The identity for the average and the expectation for one slot are different statements. The second one uses the assumption.

### Expected search cost

A search computes $h(k)$ in $\Theta(1)$ time and then scans a chain. The theorems bound the number of elements examined. Adding the hash computation replaces an expectation of $\alpha$, or of $1 + \alpha/2$, by a running time of $\Theta(1+\alpha)$.

**Theorem.** Under simple uniform hashing, an unsuccessful search in a chained table examines $\alpha$ elements in expectation, and therefore runs in expected time $\Theta(1+\alpha)$.

**Proof.** The search key is not in the table, and its hash is independent of the stored keys. It selects a slot $J$. Let $I_i = 1$ when stored key $i$ hashes to $J$. Independence and uniformity give $\Pr(I_i = 1) = 1/m$. The number of elements examined is $\sum_i I_i$, because an unsuccessful search reads the whole chain. The expectation is $n/m = \alpha$. The hash computation is $\Theta(1)$. The total is $\Theta(1+\alpha)$.

This is the indicator form of CLRS Theorem 11.1. The "average chain" form is the same arithmetic: the search slot is uniform, and every slot has expected length $\alpha$.

**Theorem.** Under simple uniform hashing, if the searched key is equally likely to be any of the $n$ stored keys, a successful search examines
$$
1 + \frac{n-1}{2m} = 1 + \frac{\alpha}{2} - \frac{\alpha}{2n}
$$
elements in expectation, and therefore runs in expected time $\Theta(1+\alpha)$.

**Proof.** This lecture appends at the tail, so the pairs on a chain sit in insertion order. Let the keys in insertion order be $k_1, \ldots, k_n$. A search for $k_i$ examines $k_i$ itself and every $k_j$ with $j < i$ that shares its slot. Let $X_{ij} = 1$ when $j < i$ and $h(k_j) = h(k_i)$. The probability that two distinct keys collide is
$$
\sum_{q=0}^{m-1} \Pr(h(k_i) = q) \Pr(h(k_j) = q) = \sum_{q=0}^{m-1} \frac{1}{m} \cdot \frac{1}{m} = \frac{1}{m}.
$$
The number of elements examined for $k_i$ has expectation
$$
1 + \sum_{j < i} \frac{1}{m} = 1 + \frac{i-1}{m}.
$$
The searched key is uniform among the $n$ keys, so the overall expectation is
$$
\frac{1}{n} \sum_{i=1}^{n} \left(1 + \frac{i-1}{m}\right) = 1 + \frac{1}{nm} \sum_{t=0}^{n-1} t = 1 + \frac{1}{nm} \cdot \frac{(n-1)n}{2} = 1 + \frac{n-1}{2m}.
$$
The right-hand side is at least $1$ and at most $1 + \alpha/2$. Both of those are $\Theta(1+\alpha)$ when they are read as functions of $\alpha$, and the hash computation adds $\Theta(1)$.

CLRS Theorem 11.2 states the same $\Theta(1+\alpha)$ bound. CLRS inserts at the head of the chain, so the keys that precede the target are the keys inserted later. The algebra produces the same fraction $(n-1)/(2m)$. The factor $1/2$ is the statement that, among the other keys that collide with the target, about half precede it in insertion order.

**Worst case.** If every key hashes to one slot, that chain has length $n$. An unsuccessful search, and a successful search for the last key, examine $\Theta(n)$ elements. Simple uniform hashing is false for that hash on that set. The expectation theorems are silent, and the worst-case cost of chaining is $\Theta(n)$.

### What "expected constant time" means

If a resize policy holds $\alpha$ at a constant, then $\Theta(1+\alpha) = \Theta(1)$. The constant hidden by $\Theta$ grows with the constant hidden by $\alpha$. The bound is an expectation over hash values under simple uniform hashing. It is not a worst-case bound on one operation. Part 5 adds a second qualifier: the operation that resizes the table costs linear time at the moment it runs, and the aggregate method of Lecture 02 spreads that cost across the sequence. A careful sentence uses both words. An insertion that sometimes resizes is **amortized expected** $\Theta(1)$ when $\alpha$ is held $O(1)$ and simple uniform hashing holds in every table size the policy creates. Dropping either adjective claims more than the proof gives.

### A perfect hash, defined and not constructed

A hash function is **perfect** for a fixed set $S$ if no two keys of $S$ collide. It is **minimal perfect** if it is perfect and $m = |S|$. Perfection removes collisions only because $S$ is known and does not change. Inserting a key from outside $S$ can destroy it. This lecture does not construct a perfect hash.

### Invariant of a chained table

After every `put` and every `delete`:

1. `size` equals the number of pairs in all chains.
2. Each key appears in at most one pair.
3. The pair for key $k$, if it exists, is in the chain at index $k \bmod m$.
4. A chain contains no duplicate key.

### Trace

Table length $m = 7$, division hash, append at the tail, resize threshold held out of the way so this trace shows collisions only. Insert $(10, 100)$, $(3, 30)$, $(17, 170)$, $(8, 80)$, $(14, 140)$.

$$
\begin{align*}
10 \bmod 7 &= 3, \\
3 \bmod 7 &= 3, \\
17 \bmod 7 &= 3, \\
8 \bmod 7 &= 1, \\
14 \bmod 7 &= 0.
\end{align*}
$$

```text
slot 0: (14, 140)
slot 1: (8, 80)
slot 2: empty
slot 3: (10, 100) -> (3, 30) -> (17, 170)
slot 4: empty
slot 5: empty
slot 6: empty
```

Here $n = 5$ and $\alpha = 5/7$. The keys $10$, $3$, and $17$ are a forced collision on slot $3$.

`get(3)` scans $(10, 100)$ and then $(3, 30)$, and returns $30$.

`put(10, 101)` finds key $10$ already on slot $3$, replaces the value, and leaves $n = 5$. The chain is still $10, 3, 17$.

`delete(3)` removes the middle pair. Slot $3$ is $10, 17$. `get(3)` scans both pairs and returns `null`.

`get(17)` returns $170$. `contains(10)` is true. `delete(10)` leaves slot $3$ holding only $17$. `contains(10)` is false. The map still holds $14$, $8$, and $17$, so $n = 3$ and $\alpha = 3/7$.

On the table as it stood at $n = 5$, before those deletions, the successful-search formula gives
$$
1 + \frac{5-1}{2 \cdot 7} = 1 + \frac{4}{14} = 1 + \frac{2}{7} = \frac{9}{7}.
$$
That is the expectation under simple uniform hashing, not a count of one unlucky chain. The chain of length $3$ in this particular table is allowed. The formula describes an average over hash assignments, and this one assignment put three keys together.

### Operations

```text
put(key, value):
    if key is already on the chain at h(key):
        replace its value and return
    if (n + 1) / m would exceed the load threshold:
        rehash into a larger table
    append the pair to the chain at h(key)
    n = n + 1

get(key):
    scan the chain at h(key)
    if key is found, return its value
    return null

delete(key):
    scan the chain at h(key)
    if key is found, unlink that pair and decrease n
```

The runnable form is `ChainedHashMap` in the laboratory program. The threshold test in that class is the integer comparison `size + 1 > maxLoad * capacity`. For the thresholds used here, `1` and `100`, and for the small capacities in the traces, the product is an exact safe integer, so the comparison matches the mathematical test $\alpha > \textit{maxLoad}$ on the table that would result from the insertion.

---

## Part 5 — Resizing and the cost of a rehash

### Why the table grows

The expectation $\Theta(1+\alpha)$ becomes large when $\alpha$ becomes large. If $m$ is fixed and $n$ grows, a chained search degrades toward a scan of a long list. The repair is to allocate a new table whose length restores a small load factor, then insert every live key into the new table under the new modulus. That second insertion is a **rehash**. The new slot of a key is generally not the old slot, because $k \bmod m$ and $k \bmod m'$ differ. Copying a chain into the same indexes would be wrong.

Rehashing is not free. One rehash from a table of $n$ keys examines each key and appends it to a new chain. The work is $\Theta(n)$ on that operation, plus the $\Theta(m')$ work of allocating the new array of chains. A sentence that calls hashing "constant time" and leaves the rehash uncounted is describing a different algorithm.

The policy in this lecture: the threshold is $\alpha \le 1$. Immediately before inserting a new key, if $n + 1 > m$, allocate a table of length $2m$ and rehash the $n$ keys that are already stored. Then insert the new key into the new table. Replacing the value of a key that is already present does not change $n$ and does not resize. The growth factor is $2$, the same geometric growth Lecture 02 uses for a dynamic array. The thing being copied is a set of keys under a new hash, which is the part Lecture 02 does not do for you.

### Trace

Start with $m = 3$ and threshold $1$. Insert $(3, \texttt{"p"})$, $(4, \texttt{"q"})$, $(5, \texttt{"r"})$.

$$
3 \bmod 3 = 0, \qquad 4 \bmod 3 = 1, \qquad 5 \bmod 3 = 2.
$$

After these three insertions, $n = 3$, $m = 3$, and $\alpha = 1$. The threshold allows $\alpha = 1$. No rehash has run.

```text
slot 0: (3, "p")
slot 1: (4, "q")
slot 2: (5, "r")
```

The next insertion is $(6, \texttt{"s"})$. Here $n + 1 = 4 > 3$, so the table rehashes into length $6$ before $6$ is inserted.

$$
3 \bmod 6 = 3, \qquad 4 \bmod 6 = 4, \qquad 5 \bmod 6 = 5, \qquad 6 \bmod 6 = 0.
$$

```text
slot 0: (6, "s")
slot 1: empty
slot 2: empty
slot 3: (3, "p")
slot 4: (4, "q")
slot 5: (5, "r")
```

Now $n = 4$, $m = 6$, and $\alpha = 2/3$. The rehash moved three keys. Inserting $(7, \texttt{"t"})$ does not resize, because $4 + 1 = 5$ is not greater than $6$, and $7 \bmod 6 = 1$.

```text
slot 1: (7, "t")
```

`get(3)`, `get(6)`, and `get(7)` return `"p"`, `"s"`, and `"t"`.

### Aggregate cost

Lecture 02's aggregate method charges a sequence and then divides by the length of the sequence. Apply it to hashing. The rehash work is deterministic: every live key is moved, regardless of where it hashes. The placement of a key into its new chain is the expected $\Theta(1+\alpha)$ cost from Part 4, and during the whole sequence the policy keeps $\alpha \le 1$ after each insertion, so that expected placement cost is $\Theta(1)$ per insertion under simple uniform hashing. The calculation below bounds only the moves.

**Theorem.** Start with capacity $m_0 \ge 1$ and threshold $\alpha \le 1$, and double at each rehash. Any sequence of $N$ insertions of new keys performs fewer than $2N$ key-moves in total. The amortized number of key-moves per insertion is therefore $O(1)$. Together with simple uniform hashing, the amortized expected cost of one insertion in the sequence is $\Theta(1)$.

**Proof.** A rehash runs when an insertion finds $n = m$. It moves those $n$ keys and sets the capacity to $2n$. The capacities at which this happens are $m_0, 2m_0, 4m_0, \ldots$, and the numbers of keys moved are those same quantities. Suppose the resizes that actually run move
$$
m_0,\ 2m_0,\ \ldots,\ m_0 2^{r-1}
$$
keys. Each of those sizes was a value of $n$ strictly before the last insertion of the sequence, so $m_0 2^{r-1} < N$, and the next capacity $m_0 2^{r}$ is large enough that a further resize has not yet been required to reach $N$ keys. The total number of moves is the geometric sum
$$
m_0(1 + 2 + \cdots + 2^{r-1}).
$$
Let $S = 1 + 2 + \cdots + 2^{r-1}$. Then $2S = 2 + \cdots + 2^{r}$, and $2S - S = 2^{r} - 1$. Hence the total is
$$
m_0(2^{r} - 1) < m_0 \cdot 2^{r} = 2 \cdot (m_0 2^{r-1}) < 2N.
$$
Dividing by $N$ gives fewer than $2$ moves per insertion. That is the aggregate bound. It does not say that the insertion which triggers a rehash is cheap. That one call moves every key currently stored. The calls that do not resize move no keys for the rehash. The average over the sequence is $O(1)$.

Under simple uniform hashing, each of the $N$ placements into a chain, including the placements done during a rehash, examines an expected $\Theta(1)$ chain because $\alpha \le 1$. Adding fewer than $2N$ moves does not change the $\Theta(N)$ total, and the amortized expected cost per insertion is $\Theta(1)$.

If the hash is pathological, the chain scans during the rehash are $\Theta(n)$ per key and the aggregate argument about moves still holds, while the expected-time half of the theorem does not. The moves and the hash assumption answer different questions.

**Worked sequence.** Capacity starts at $m_0 = 2$, and $N = 8$ new keys are inserted.

| Insertion | $n$ before the test | Action | Moves so far |
| --- | --- | --- | --- |
| 1 | 0 | store, capacity stays 2 | 0 |
| 2 | 1 | store, capacity stays 2 | 0 |
| 3 | 2 | move 2 keys, capacity becomes 4, then store | 2 |
| 4 | 3 | store, capacity stays 4 | 2 |
| 5 | 4 | move 4 keys, capacity becomes 8, then store | 6 |
| 6, 7, 8 | 5, 6, 7 | store, capacity stays 8 | 6 |

Eight insertions move $6$ keys. The amortized count is $6/8 = 3/4$. The fifth insertion is the expensive one: it moves $4$ keys by itself. After eight insertions the capacity equals $8$, so the next resize would be the ninth insertion, which is outside this sequence.

The laboratory checks this count and checks the separate $m = 3$ trace, whose new capacity is $6 = 2 \cdot 3$.

---

## Part 6 — Open addressing

### Probe sequences

Chaining stores colliding keys in a list that lives beside the slot array. **Open addressing** stores every key in the slot array itself. There is no list. A slot holds one live key, or a marker that a key used to live there, or `null` for empty. Because each live key occupies a distinct slot, $n \le m$ and $\alpha \le 1$. A full table cannot accept a new key until it grows.

When the home slot $h(k)$ is already taken, the algorithm examines a **probe sequence**
$$
h(k, 0),\ h(k, 1),\ \ldots,\ h(k, m-1).
$$
The first probe is the home slot. Later probes are alternate slots for the same key. A correct probe sequence for open addressing is a permutation of the $m$ slots: every slot appears once. Search examines the same sequence the insertion examined. Search stops at an empty slot. The empty slot is the proof that the key is absent, because insertion would have placed the key in the first empty slot it saw and would not have walked past it.

CLRS calls the ideal model **independent uniform permutation hashing**: the probe sequence of each key is uniformly random among the $m!$ permutations, and distinct keys are independent. Older texts call a closely related ideal **uniform hashing**. This lecture uses the CLRS name when it cites the probe bounds, so that the hypothesis is visible. Linear probing and double hashing do not generate all $m!$ permutations. Their bounds are either proved from their own structure or stated from Knuth, and they are not silent substitutions for the ideal model.

The runnable maps share one insertion and search procedure. The collision strategy is the function `probe(key, i)`.

```text
put(key, value):
    remember the first tombstone seen, if any
    for i from 0 while the probe has not repeated a slot:
        q = probe(key, i)
        if slot q is empty:
            write the pair at the remembered tombstone, or at q if none
            return
        if slot q is a tombstone:
            remember q if it is the first
            continue
        if slot q holds key:
            replace the value and return
    if a tombstone was remembered:
        write the pair there and return
    report that the probe sequence is exhausted

get(key):
    for i from 0 while the probe has not repeated a slot:
        q = probe(key, i)
        if slot q is empty:
            return null
        if slot q holds key:
            return its value
        continue past a tombstone
    return null
```

Tombstones are defined in Part 7. Until the first deletion, every slot is either empty or live, and the tombstone branch does not run.

### Linear probing

**Linear probing** walks consecutive slots:
$$
h(k, i) = (h(k) + i) \bmod m, \qquad h(k) = k \bmod m.
$$
The step is $1$. Because $\gcd(1, m) = 1$, the sequence visits every slot exactly once before it repeats. Linear probing does not need a prime table length in order to cover the table. It still needs a home hash that spreads keys. A prime length is about the home hash, which is the division method of Part 3. Coverage and spread are different properties.

**Trace.** $m = 7$. Insert $7$, $14$, $8$, $21$, $15$, with the value equal to the key.

$$
\begin{align*}
7 \bmod 7 &= 0 && \text{slot 0 is empty, store 7}, \\
14 \bmod 7 &= 0 && \text{slot 0 holds 7, store 14 at slot 1}, \\
8 \bmod 7 &= 1 && \text{slot 1 holds 14, store 8 at slot 2}, \\
21 \bmod 7 &= 0 && \text{slots 0, 1, 2 are full, store 21 at slot 3}, \\
15 \bmod 7 &= 1 && \text{slots 1, 2, 3 are full, store 15 at slot 4}.
\end{align*}
$$

```text
slot:  0   1   2   3   4   5   6
      [7] [14] [8] [21] [15] [ ] [ ]
```

### Primary clustering

Look at the run of five occupied slots. A new key whose home slot is $0$, $1$, $2$, $3$, or $4$ walks into that same run and stops at slot $5$.

```text
slot:  0   1   2   3   4   5   6
      [7] [14] [8] [21] [15] [k] [ ]

Homes that all end at the same empty slot: 0, 1, 2, 3, 4
```

A run of length $L$ is the destination of $L$ different home slots, and each of those homes extends the run to length $L+1$. The longer run is then the destination of still more homes. That feedback is **primary clustering**. An isolated occupied slot is entered only by keys that hash directly to it. A long run absorbs every key that hashes anywhere inside it, plus the key that hashes to the empty slot just after it once the run has grown.

Two runs that are separated by one empty slot become one run when a key fills the gap. The new run has the sum of the lengths, and it absorbs the homes of both old runs. Linear probing creates these runs because the next probe is always the neighboring slot. The probe has no way to jump over a crowd.

### Quadratic probing

**Quadratic probing** jumps by growing squares:
$$
h(k, i) = (h(k) + i^2) \bmod m.
$$
The jump avoids the immediate neighbor, which is how it reduces primary clustering. The cost is that the sequence can repeat a slot before it has seen every slot. Insertion then fails while empty slots still exist.

**Theorem.** Let $m$ be an odd prime. The offsets $0^2, 1^2, \ldots, (m-1)^2$ modulo $m$ take exactly $(m+1)/2$ distinct values. Quadratic probing of the form above therefore visits $(m+1)/2$ slots, not $m$.

**Proof.** For $1 \le i \le m-1$,
$$
(m-i)^2 = m^2 - 2mi + i^2 \equiv i^2 \pmod{m}.
$$
The offsets $i$ and $m-i$ are the same square. At most $(m+1)/2$ squares exist, counting $0$. It remains to show that the squares $0^2, 1^2, \ldots, ((m-1)/2)^2$ are pairwise distinct modulo $m$. Suppose $0 \le j < i \le (m-1)/2$ and $i^2 \equiv j^2 \pmod{m}$. Then $m$ divides $(i-j)(i+j)$. Here $0 < i-j < m$, so $m$ does not divide $i-j$. And $0 < i+j \le m-1$, so $m$ does not divide $i+j$. A prime that divides a product divides one of the factors. Both factors escape $m$, so the squares are distinct. The count is exactly $(m+1)/2$.

**Trace.** Home slot $0$, modulus $7$. Note that $(7+1)/2 = 4$.

$$
\begin{align*}
i = 0 &\colon 0, \\
i = 1 &\colon 1, \\
i = 2 &\colon 4, \\
i = 3 &\colon 9 \bmod 7 = 2, \\
i = 4 &\colon 16 \bmod 7 = 2, \\
i = 5 &\colon 25 \bmod 7 = 4, \\
i = 6 &\colon 36 \bmod 7 = 1.
\end{align*}
$$

The sequence is $0, 1, 4, 2, 2, 4, 1$. The distinct slots are $0, 1, 2, 4$. Slots $3$, $5$, and $6$ are never probed.

Fill $0$, $1$, $2$, and $4$ by inserting the keys $0$, $1$, $2$, and $4$, each of which finds its home slot empty. Then insert key $7$. Its home slot is $7 \bmod 7 = 0$, and its probe visits only $0, 1, 4, 2$, all occupied. The insertion reports that the probe sequence is exhausted. Slots $3$, $5$, and $6$ are still empty. The failure is the probe, not a full table.

Other quadratic formulas, with extra coefficients on $i$ and on $i^2$, can be arranged to cover a prime table. This lecture does not adopt one. The formula above is enough to see the risk, and the laboratory implements this formula so the missed slots are checked.

### Double hashing

**Double hashing** uses two hash functions. The first chooses the home slot. The second chooses the step:
$$
h(k, i) = (h_1(k) + i \cdot h_2(k)) \bmod m.
$$
In this lecture
$$
h_1(k) = k \bmod m, \qquad h_2(k) = 1 + (k \bmod (m-1)).
$$
The step $h_2(k)$ lies in $\{1, 2, \ldots, m-1\}$. It is never $0$, so the probe does not stand still.

**Theorem.** The sequence $h_1, h_1 + h_2, h_1 + 2h_2, \ldots$ modulo $m$ visits every slot if and only if $\gcd(h_2, m) = 1$.

**Proof.** The number of distinct values of $i \cdot h_2 \bmod m$, as $i$ runs, is $m / \gcd(h_2, m)$. This is the theorem of Part 3 applied to the progression with difference $h_2$. Adding the constant $h_1$ shifts the set and does not change its size. The size equals $m$ exactly when the gcd equals $1$.

If $m$ is prime, every step in $\{1, 2, \ldots, m-1\}$ is coprime to $m$, and every key's probe is a permutation of the slots. The laboratory constructor for double hashing requires a prime capacity for that reason. If $m$ is a power of two, an odd step is coprime to $m$, and an even step is not. The formula $1 + (k \bmod (m-1))$ can be even, so a power-of-two table with this formula is not safe.

**Counterexample.** $m = 8$, home $1$, step $2$. Here $\gcd(2, 8) = 2$, and $8/2 = 4$ distinct slots:
$$
1,\ 3,\ 5,\ 7,\ 1,\ 3,\ 5,\ 7.
$$
The even slots are invisible to this key. The constructor rejects capacity $8$.

**Trace.** $m = 7$, which is prime. Key $19$:
$$
h_1(19) = 19 \bmod 7 = 5, \qquad h_2(19) = 1 + (19 \bmod 6) = 1 + 1 = 2.
$$

$$
\begin{align*}
i = 0 &\colon 5, \\
i = 1 &\colon (5 + 2) \bmod 7 = 0, \\
i = 2 &\colon (5 + 4) \bmod 7 = 2, \\
i = 3 &\colon (5 + 6) \bmod 7 = 4, \\
i = 4 &\colon (5 + 8) \bmod 7 = 6, \\
i = 5 &\colon (5 + 10) \bmod 7 = 1, \\
i = 6 &\colon (5 + 12) \bmod 7 = 3.
\end{align*}
$$

The probe sequence is $5, 0, 2, 4, 6, 1, 3$. All seven slots appear once.

Insert $19$, then $5$, then $12$.

Key $19$ is stored at slot $5$.

Key $5$: $h_1 = 5$, $h_2 = 1 + (5 \bmod 6) = 6$. Slot $5$ holds $19$. The next probe is $(5+6) \bmod 7 = 4$, which is empty. Store $5$ at slot $4$.

Key $12$: $h_1 = 12 \bmod 7 = 5$, $h_2 = 1 + (12 \bmod 6) = 1$. Slot $5$ holds $19$. The next probe is $6$, which is empty. Store $12$ at slot $6$.

```text
slot:  0   1   2   3   4   5   6
      [ ] [ ] [ ] [ ] [5] [19] [12]
```

### Open-addressing costs under the ideal probe model

The following two bounds assume independent uniform permutation hashing, $\alpha < 1$, and no deletions. Deletions change the picture, because a tombstone is not an empty slot and does not stop a search. CLRS Theorem 11.6 and Theorem 11.8 are the citations. The proofs below are sketches at the level of the indicator argument: the inequalities are written out, and the integral comparison that turns a harmonic sum into a logarithm is named as the estimate it is.

For a positive integer-valued random variable $X$,
$$
\mathrm{E}[X] = \sum_{t \ge 1} t \Pr(X = t) = \sum_{t \ge 1} \sum_{i = 1}^{t} \Pr(X = t) = \sum_{i \ge 1} \Pr(X \ge i).
$$
The rearrangement is finite because a probe sequence examines at most $m$ slots.

**Theorem (CLRS 11.6).** Under independent uniform permutation hashing, with no deletions and with $\alpha < 1$, the expected number of probes in an unsuccessful search is at most $1/(1-\alpha)$.

**Proof sketch.** Let $X$ be the number of probes. The $i$-th probe occurs and hits an occupied slot only if the first $i-1$ probes were occupied. The probability that the first probe is occupied is $n/m = \alpha$. Given that $j-1$ distinct slots were occupied, the next probe of a random permutation hits one of the remaining occupied slots with probability $(n-j+1)/(m-j+1)$. For $0 \le j < m$ and $n < m$,
$$
\frac{n-j}{m-j} \le \frac{n}{m} = \alpha,
$$
because $n(m-j) \le m(n-j)$ rearranges to $0 \le j(m-n)$. Therefore $\Pr(X \ge i) \le \alpha^{i-1}$ for each $i \ge 1$, and $\Pr(X \ge i) = 0$ once $i > n+1$. Hence
$$
\mathrm{E}[X] = \sum_{i \ge 1} \Pr(X \ge i) \le \sum_{i = 0}^{\infty} \alpha^{i} = \frac{1}{1-\alpha}.
$$
The closed form of the geometric series is the same sum used in Part 5: $\sum_{i=0}^{\infty} \alpha^i = 1/(1-\alpha)$ for $0 \le \alpha < 1$.

An insertion of a new key performs an unsuccessful search and then writes into the empty slot it found. Its expected probe count has the same upper bound.

**Theorem (CLRS 11.8, stated with the averaging argument).** Under the same hypotheses, if each stored key is equally likely to be the search target, the expected number of probes in a successful search is at most
$$
\frac{1}{\alpha} \ln \frac{1}{1-\alpha}.
$$

**Proof sketch.** A search for a key repeats the probes that inserted it. If the key was inserted when the table already held $i$ keys, the load factor at that moment was $i/m$, and the expected probes used to insert it were at most $1/(1 - i/m) = m/(m-i)$, by the previous theorem. Average over the $n$ keys, which were inserted at $i = 0, 1, \ldots, n-1$:
$$
\frac{1}{n} \sum_{i=0}^{n-1} \frac{m}{m-i} = \frac{1}{\alpha} \sum_{j = m-n+1}^{m} \frac{1}{j},
$$
where the substitution is $j = m-i$. The sum is a difference of harmonic numbers. Comparing the sum with an integral,
$$
\sum_{j = m-n+1}^{m} \frac{1}{j} < \int_{m-n}^{m} \frac{1}{x}\, dx = \ln \frac{m}{m-n} = \ln \frac{1}{1-\alpha}.
$$
The integral comparison is the estimate in this sketch. It yields the bound $(1/\alpha) \ln (1/(1-\alpha))$. CLRS records the numerical checks: at $\alpha = 1/2$ the bound is less than $1.387$, and at $\alpha = 9/10$ it is less than $2.559$.

Linear probing does not satisfy independent uniform permutation hashing. It generates only $m$ probe sequences, one for each home slot. Knuth's analysis of the clusters produces different formulas. They are stated here and not re-derived. The clustering argument is the content of Knuth, Volume 3, Section 6.4, and it is longer than the geometric-series argument above.

**Theorem (stated).** Under Knuth's model for linear probing, with load factor $\alpha < 1$ and no deletions, the expected number of probes is
$$
\frac{1}{2}\left(1 + \frac{1}{(1-\alpha)^2}\right)
$$
for an unsuccessful search, and
$$
\frac{1}{2}\left(1 + \frac{1}{1-\alpha}\right)
$$
for a successful search.

Primary clustering is why the unsuccessful formula has a squared term in the denominator. As $\alpha$ approaches $1$, linear probing becomes expensive faster than the ideal probe model. The table in Part 8 puts the two predictions side by side.

### Invariant of an open-addressed table

After every `put` and every `delete`:

1. Live keys are unique, and `size` counts them.
2. `tombstones` counts slots that hold a tombstone.
3. A live key $k$ occupies some slot on its probe sequence.
4. Every slot strictly before that key on its probe sequence holds a live key or a tombstone. It does not hold `null`.

Invariant 4 is the reason search may stop at `null`. If a `null` appeared before the key, the invariant would be false and the search would miss the key.

---

## Part 7 — Deletion, holes, and tombstones

### A hole ends the search too early

Return to the linear-probing table
```text
slot:  0   1   2   3   4   5   6
      [7] [14] [8] [21] [15] [ ] [ ]
```
and delete $14$ by writing `null` into slot $1$. Call that a **hole**: an empty slot sitting where a live key used to be, with other live keys later on probe sequences that walked through it.

```text
slot:  0   1    2   3   4   5   6
      [7] [ ]  [8] [21] [15] [ ] [ ]
```

Search for $8$. The home slot is $8 \bmod 7 = 1$. Slot $1$ is empty, so the search stops and reports that $8$ is absent. The key $8$ is sitting in slot $2$. The search examined only slot $1$. Invariant 4 has been broken for key $8$, whose probe $1, 2, 3, \ldots$ now sees `null` before the key.

The same hole hides $21$ and $15$ from any search that would have walked through slot $1$. Key $21$ has home $0$. Its probe reads slot $0$ (holds $7$), then slot $1$ (empty), and stops. It never reaches slot $3$.

Writing `null` on deletion is incorrect in open addressing.

### A tombstone continues the probe and can be reused

A **tombstone** is a third state of a slot. It means: a key was deleted here; keep probing; an insertion may store a new key here.

Search treats a tombstone as "not the key, and not the end." Insertion remembers the first tombstone on the probe and keeps walking, because the key might still live further along the sequence. If the key is found, insertion replaces the value and leaves the tombstone untouched. If the key is absent and a tombstone was seen, insertion writes the new pair into that tombstone. If the key is absent and no tombstone was seen, insertion writes into the empty slot that ended the walk.

**Trace, continued from the same table.** Delete $14$ by placing a tombstone, drawn as `T`.

```text
slot:  0   1   2   3   4   5   6
      [7] [T] [8] [21] [15] [ ] [ ]
```

Search for $8$: slot $1$ is a tombstone, so continue; slot $2$ holds $8$. The search returns $8$. It examined slots $1$ and $2$.

Search for $14$: slot $0$ holds $7$, slot $1$ is a tombstone, slot $2$ holds $8$, slot $3$ holds $21$, slot $4$ holds $15$, slot $5$ is empty. The key is not found. The empty slot ends the search.

Insert $28$. Its home is $28 \bmod 7 = 0$. Slot $0$ holds $7$. Slot $1$ is a tombstone; remember it. Slot $2$ holds $8$, slot $3$ holds $21$, slot $4$ holds $15$, slot $5$ is empty. The key $28$ was not found, so write it into the remembered tombstone at slot $1$.

```text
slot:  0   1   2   3   4   5   6
      [7] [28] [8] [21] [15] [ ] [ ]
```

`get(28)` returns $28$. `get(8)` still returns $8$. `get(14)` returns `null`. One live key was removed and one live key was added, so $n = 5$ again, and the tombstone count is $0$.

A later key $4$ has home $4 \bmod 7 = 4$. Slot $4$ holds $15$, and slot $5$ is empty, so $4$ is stored at slot $5$. That placement is a laboratory problem. The guided picture above stops before it.

### Tombstones occupy slots

Let $t$ be the number of tombstones. The **occupied load** is
$$
\alpha_{\mathrm{occ}} = \frac{n + t}{m}.
$$
The live load $\alpha = n/m$ counts keys. A search does not get to skip tombstones in the cost sense: it reads them and continues. The probe formulas of Part 6 were proved for tables with no deletions, where $t = 0$ and an empty slot appears as soon as the live keys on that probe are passed. With tombstones present, those formulas describe $\alpha_{\mathrm{occ}}$ only as a warning, not as a theorem this lecture has proved. The proved statement is narrower and exact: a tombstone is not free space during a search, and a long run of tombstones makes a search long even after the keys are gone.

After the deletion of $14$ and before the insertion of $28$, $n = 4$, $t = 1$, $m = 7$. The live load is $4/7$. The occupied load is $5/7$. Any account that keeps using $4/7$ in a probe formula is pretending the tombstone is not there.

A rehash clears tombstones. Allocate a new table and insert only the live keys, using the ordinary insertion path. Tombstones are not inserted. The new table has $t = 0$. The same aggregate accounting as Part 5 applies to a policy that rehashes when $\alpha_{\mathrm{occ}}$ exceeds a threshold: each such rehash costs linear time in the number of live keys, and a geometric growth of capacity makes the amortized number of moves constant across a sequence. The laboratory implements resize for chaining. The open-addressed laboratory uses a fixed capacity so that the tombstone trace stays on one array you can draw. The cost of leaving tombstones in place is the occupied load, and it is not zero.

---

## Part 8 — Choosing the load factor and the table length

### A practical table of costs

The chaining column is the number of elements examined. The open-addressing columns are numbers of probes. Chaining's successful column is the large-$n$ form $1 + \alpha/2$. The finite-$n$ value is smaller by $\alpha/(2n)$. The ideal open-addressing column uses independent uniform permutation hashing and no deletions. The linear-probing column uses Knuth's stated formulas. Working values $\ln 2 = 0.693$ and $\ln 10 = 2.303$ produce the three-decimal entries. They are working values for this table, not exact irrationals.

| $\alpha$ | Chaining, unsuccessful | Chaining, successful | Ideal probes, unsuccessful | Ideal probes, successful | Linear probing, unsuccessful | Linear probing, successful |
| --- | --- | --- | --- | --- | --- | --- |
| $0.50$ | $0.500$ | $1.250$ | $2$ | $1.386$ | $2.5$ | $1.5$ |
| $0.75$ | $0.750$ | $1.375$ | $4$ | $1.848$ | $8.5$ | $2.5$ |
| $0.90$ | $0.900$ | $1.450$ | $10$ | $2.559$ | $50.5$ | $5.5$ |

The ideal successful entry at $\alpha = 1/2$ is $2 \ln 2 = 1.386$. At $\alpha = 3/4$ it is $(4/3) \ln 4 = (8/3)(0.693) = 1.848$. At $\alpha = 9/10$ it is $(1/0.9)(2.303) = 2.559$.

The linear unsuccessful entry at $\alpha = 9/10$ is
$$
\frac{1}{2}\left(1 + \frac{1}{(0.1)^2}\right) = \frac{1}{2}(1 + 100) = 50.5.
$$
Chaining at the same load factor still examines fewer than one element on an average unsuccessful search, because an unsuccessful search examines a chain of expected length $\alpha$, and $\alpha = 0.9$. Open addressing at that load factor is a different regime. Chaining also continues to function for $\alpha > 1$. At $\alpha = 2$ the expected unsuccessful chain length is $2$. Open addressing cannot represent $\alpha > 1$, because two live keys would have to share a slot and there is no list to hold them.

### A policy that matches the table

For a map that inserts and deletes and does not need key order, use separate chaining and rehash when an insertion would push $\alpha$ above $1$. Expected chains stay near length $1$, deletion unlinks a pair in the chain and leaves no tombstone, and the aggregate bound of Part 5 applies.

For a map that does not delete, or that rehashes in order to drop tombstones, open addressing stores no chain pointers. Keep $\alpha \le 1/2$ if you use linear probing and you want the unsuccessful probe count near $2.5$ rather than near $8.5$. Double hashing is the open-addressing strategy whose probe sequences are numerous: a prime $m$ and a step coprime to $m$ give $m(m-1)$ sequences of the form used here, against the $m$ sequences of linear probing. Neither family is the full set of $m!$ permutations. Double hashing is the closer practical approximation, and linear probing is the one whose clusters you can see on a drawing.

Choose $m$ prime when the home hash is the division method and keys may contain arithmetic progressions or may share low bits. Choose $m$ prime for double hashing with the step $1 + (k \bmod (m-1))$. Linear probing covers every slot for any $m \ge 1$; primality is still the right constraint on its home hash when that home hash is division.

The constant inside $\Theta(1+\alpha)$ is the constant you buy with the load factor. Expected constant time with $\alpha = 1$ and expected constant time with $\alpha = 1/10$ are both $\Theta(1)$, and they are not the same number of memory reads. The table is the way to see the number.

### What this course does not claim

This course does not claim that a hash table resists an attacker.

The division function, the multiplication function, and the polynomial hash are fixed functions. An adversary who knows which function you use can choose $n$ keys that all land in one slot. For the division method the set $\{0, m, 2m, \ldots, (n-1)m\}$ is such a set. Every key collides. Search is $\Theta(n)$ on every operation that touches that chain. The expectation theorems do not apply, because simple uniform hashing is false for this set. The worst-case theorem does apply, and it says $\Theta(n)$.

**Randomized hashing** is the reply to that adversary. The program draws the hash function from a family, so the adversary does not know which function will be used. Carter and Wegman defined a **universal family**: a finite set $H$ of functions from $U$ to the $m$ slots such that, for every pair of distinct keys, at most $|H|/m$ members of $H$ send that pair to the same slot. A uniform draw from $H$ then collides any fixed pair with probability at most $1/m$. CLRS Corollary 11.3 records that chaining, with the hash drawn from a universal family, keeps the expected cost of a sequence of map operations linear in the length of the sequence, for any keys the adversary names. This lecture does not construct the family. Naming it is the whole of the treatment.

A cryptographic hash is not that construction, and this lecture does not teach one. Resistance to an attacker who tries to invert the hash or to find any collision in a gigantic output space is a different specification from "spread these $n$ keys across $m$ slots."

---

## Part 9 — The language Map, and the boundary of the lecture

JavaScript provides `Map`. It is a language map. Its specification identifies keys by the SameValueZero equality, which treats `NaN` as equal to `NaN` and distinguishes `-0` from `+0` in a defined way, and it iterates keys in insertion order. Insertion order is a real order. It is still not key order. A `Map` from integers does not iterate from the smallest integer to the largest unless you inserted them that way.

An engine may represent `Map` with a hash table. That representation is an implementation detail. It can change, it is not required by the language specification to be chaining or open addressing, and it is not a proof of simple uniform hashing. You cannot cite the existence of `Map` as the proof of Theorem 11.1. You also cannot time one engine on one input and treat the timing as the expectation.

The rule for the rest of this course is narrow. In later lectures, application code may use `Map` after you can implement separate chaining yourself, including a forced collision, a deletion, and a load-factor resize. The laboratory program is that demonstration. Until it prints `ALL TESTS PASSED` from code you understand, use the classes in this lecture when you need a map. This lecture's own program does not call `Map`.

---

## LABORATORY

The traces in Parts 3 through 7 use the numbers the program checks. Do those traces with a pencil before you read the program. Then do the four problems below without reading the program. The program checks the traces and the problems. It prints `ALL TESTS PASSED` when every assertion holds.

### Guided traces

1. Polynomial hash, base $31$, modulus $101$: `"cat"` ends at $90$, `"dog"` ends at $58$, `"a"` ends at $97$, and the empty string ends at $0$. The largest intermediate value the recurrence can form for any JavaScript string is $68635$.
2. Division residues of $0, 4, 8, 12, 16, 20$: modulo $12$ the list is $0, 4, 8, 0, 4, 8$; modulo $11$ the list is $0, 4, 8, 1, 5, 9$.
3. Multiplication hash with JavaScript's approximation of $(\sqrt{5}-1)/2$ and $m = 8$: $h(10) = 1$ and $h(11) = 6$.
4. Chained table, $m = 7$, threshold $100$: after inserting $10, 3, 17, 8, 14$, slot $3$ holds the keys $10, 3, 17$ in that order. Replacing the value of $10$ does not grow the chain. Deleting $3$ and then $10$ leaves slot $3$ holding $17$.
5. At $n = 5$ and $m = 7$, the successful-search expectation is $9/7$.
6. Chained resize from $m = 3$: the insertion of key $6$ rehashes into capacity $6$, with keys $6, 3, 4, 5$ in slots $0, 3, 4, 5$. Key $7$ then occupies slot $1$, and the capacity stays $6$.
7. Doubling from capacity $2$ across $8$ insertions of new keys moves $6$ keys in total and finishes at capacity $8$.
8. Linear probing, $m = 7$: the keys $7, 14, 8, 21, 15$ occupy slots $0$ through $4$. Deleting $14$ leaves a tombstone at slot $1$. `get(8)` still finds $8$. Inserting $28$ reuses slot $1$.
9. A hole at slot $1$, with $8$ still stored at slot $2$, makes a search for $8$ examine only slot $1$ and report absence.
10. Double hashing, $m = 7$: the probe sequence of $19$ is $5, 0, 2, 4, 6, 1, 3$. After inserting $19$, $5$, and $12$, the occupied slots are $4 \mapsto 5$, $5 \mapsto 19$, $6 \mapsto 12$. The step-$2$ probe on a table of length $8$, starting at slot $1$, is $1, 3, 5, 7, 1, 3, 5, 7$. Capacity $8$ is rejected for double hashing.
11. Quadratic probing from home $0$ with modulus $7$ produces $0, 1, 4, 2, 2, 4, 1$. Inserting $0, 1, 2, 4$ and then $7$ exhausts the probe while slots $3$, $5$, and $6$ are empty.

### Problems

Work these before you read the program.

1. Compute the polynomial hash of `"bit"` with base $31$ and modulus $101$. The codes are `b = 98`, `i = 105`, `t = 116`. Show each product before the remainder.
2. Compute the double-hashing probe sequence of key $8$ with $m = 7$, using $h_1(k) = k \bmod 7$ and $h_2(k) = 1 + (k \bmod 6)$.
3. On a chained table of length $5$, with append and with no resize, insert keys $5$, $9$, and $14$. Write the five chains.
4. On the linear-probing table after $28$ has reused the tombstone, insert key $4$. Name the slot that receives it.

## LABORATORY PROGRAM

```javascript
import assert from "node:assert/strict";

const STRING_HASH_BASE = 31;
const STRING_HASH_MODULUS = 101;
const MAX_CODE_UNIT = 65535;
const SAFE_INTEGER_LIMIT = 2 ** 53 - 1;
const TOMBSTONE = Object.freeze({ kind: "tombstone" });

function polynomialHash(text, base, modulus) {
  let hash = 0;
  for (let index = 0; index < text.length; index += 1) {
    const code = text.charCodeAt(index);
    hash = (hash * base + code) % modulus;
  }
  return hash;
}

function isPrime(value) {
  if (value < 2) {
    return false;
  }
  for (let divisor = 2; divisor * divisor <= value; divisor += 1) {
    if (value % divisor === 0) {
      return false;
    }
  }
  return true;
}

function requireNonnegativeInteger(key) {
  if (!Number.isInteger(key) || key < 0) {
    throw new Error("key must be a nonnegative integer");
  }
}

function residues(keys, modulus) {
  const out = [];
  for (let index = 0; index < keys.length; index += 1) {
    out.push(keys[index] % modulus);
  }
  return out;
}

function doubleProbe(home, step, modulus) {
  const sequence = [];
  for (let i = 0; i < modulus; i += 1) {
    sequence.push((home + i * step) % modulus);
  }
  return sequence;
}

function multiplicationHash(key, modulus) {
  const constantA = (Math.sqrt(5) - 1) / 2;
  const fractional = key * constantA - Math.floor(key * constantA);
  return Math.floor(modulus * fractional);
}

function searchStoppingAtHole(table, key) {
  const modulus = table.length;
  const examined = [];
  for (let i = 0; i < modulus; i += 1) {
    const index = (key % modulus + i) % modulus;
    examined.push(index);
    if (table[index] === null) {
      return { found: false, examined };
    }
    if (table[index] === key) {
      return { found: true, examined };
    }
  }
  return { found: false, examined };
}

function rehashMoves(insertions, initialCapacity) {
  let capacity = initialCapacity;
  let size = 0;
  let moves = 0;
  for (let count = 0; count < insertions; count += 1) {
    if (size + 1 > capacity) {
      moves += size;
      capacity *= 2;
    }
    size += 1;
  }
  return { moves, capacity, size };
}

class ChainedHashMap {
  constructor(capacity, maxLoad) {
    this.capacity = capacity;
    this.maxLoad = maxLoad;
    this.size = 0;
    this.buckets = [];
    for (let slot = 0; slot < capacity; slot += 1) {
      this.buckets.push([]);
    }
  }

  hash(key) {
    requireNonnegativeInteger(key);
    return key % this.capacity;
  }

  put(key, value) {
    requireNonnegativeInteger(key);
    let chain = this.buckets[this.hash(key)];
    for (let index = 0; index < chain.length; index += 1) {
      if (chain[index].key === key) {
        chain[index].value = value;
        return;
      }
    }
    if (this.size + 1 > this.maxLoad * this.capacity) {
      this.rehash(this.capacity * 2);
    }
    chain = this.buckets[this.hash(key)];
    chain.push({ key, value });
    this.size += 1;
  }

  rehash(newCapacity) {
    const previous = this.buckets;
    this.capacity = newCapacity;
    this.buckets = [];
    for (let slot = 0; slot < newCapacity; slot += 1) {
      this.buckets.push([]);
    }
    for (let slot = 0; slot < previous.length; slot += 1) {
      const chain = previous[slot];
      for (let index = 0; index < chain.length; index += 1) {
        const pair = chain[index];
        this.buckets[this.hash(pair.key)].push(pair);
      }
    }
  }

  get(key) {
    requireNonnegativeInteger(key);
    const chain = this.buckets[this.hash(key)];
    for (let index = 0; index < chain.length; index += 1) {
      if (chain[index].key === key) {
        return chain[index].value;
      }
    }
    return null;
  }

  contains(key) {
    return this.get(key) !== null;
  }

  delete(key) {
    requireNonnegativeInteger(key);
    const chain = this.buckets[this.hash(key)];
    for (let index = 0; index < chain.length; index += 1) {
      if (chain[index].key === key) {
        chain.splice(index, 1);
        this.size -= 1;
        return true;
      }
    }
    return false;
  }

  chainKeys(slot) {
    const keys = [];
    const chain = this.buckets[slot];
    for (let index = 0; index < chain.length; index += 1) {
      keys.push(chain[index].key);
    }
    return keys;
  }
}

class OpenAddressedMap {
  constructor(capacity) {
    this.capacity = capacity;
    this.size = 0;
    this.tombstones = 0;
    this.slots = [];
    for (let index = 0; index < capacity; index += 1) {
      this.slots.push(null);
    }
  }

  probe(key, i) {
    throw new Error("probe is defined by the collision strategy");
  }

  put(key, value) {
    requireNonnegativeInteger(key);
    const seen = new Set();
    let tombstoneAt = -1;
    for (let i = 0; i < this.capacity; i += 1) {
      const index = this.probe(key, i);
      if (seen.has(index)) {
        break;
      }
      seen.add(index);
      const slot = this.slots[index];
      if (slot === null) {
        const destination = tombstoneAt >= 0 ? tombstoneAt : index;
        if (tombstoneAt >= 0) {
          this.tombstones -= 1;
        }
        this.slots[destination] = { key, value };
        this.size += 1;
        return destination;
      }
      if (slot === TOMBSTONE) {
        if (tombstoneAt < 0) {
          tombstoneAt = index;
        }
        continue;
      }
      if (slot.key === key) {
        slot.value = value;
        return index;
      }
    }
    if (tombstoneAt >= 0) {
      this.slots[tombstoneAt] = { key, value };
      this.tombstones -= 1;
      this.size += 1;
      return tombstoneAt;
    }
    throw new Error("probe sequence exhausted");
  }

  get(key) {
    requireNonnegativeInteger(key);
    const seen = new Set();
    for (let i = 0; i < this.capacity; i += 1) {
      const index = this.probe(key, i);
      if (seen.has(index)) {
        return null;
      }
      seen.add(index);
      const slot = this.slots[index];
      if (slot === null) {
        return null;
      }
      if (slot !== TOMBSTONE && slot.key === key) {
        return slot.value;
      }
    }
    return null;
  }

  contains(key) {
    return this.get(key) !== null;
  }

  delete(key) {
    requireNonnegativeInteger(key);
    const seen = new Set();
    for (let i = 0; i < this.capacity; i += 1) {
      const index = this.probe(key, i);
      if (seen.has(index)) {
        return false;
      }
      seen.add(index);
      const slot = this.slots[index];
      if (slot === null) {
        return false;
      }
      if (slot !== TOMBSTONE && slot.key === key) {
        this.slots[index] = TOMBSTONE;
        this.size -= 1;
        this.tombstones += 1;
        return true;
      }
    }
    return false;
  }

  probeSequence(key) {
    requireNonnegativeInteger(key);
    const sequence = [];
    for (let i = 0; i < this.capacity; i += 1) {
      sequence.push(this.probe(key, i));
    }
    return sequence;
  }

  occupancy() {
    const row = [];
    for (let index = 0; index < this.slots.length; index += 1) {
      const slot = this.slots[index];
      if (slot === null) {
        row.push(null);
      } else if (slot === TOMBSTONE) {
        row.push("T");
      } else {
        row.push(slot.key);
      }
    }
    return row;
  }
}

class LinearProbingMap extends OpenAddressedMap {
  probe(key, i) {
    return (key % this.capacity + i) % this.capacity;
  }
}

class QuadraticProbingMap extends OpenAddressedMap {
  probe(key, i) {
    const home = key % this.capacity;
    return (home + i * i) % this.capacity;
  }
}

class DoubleHashingMap extends OpenAddressedMap {
  constructor(capacity) {
    super(capacity);
    if (!isPrime(capacity)) {
      throw new Error("double hashing requires a prime capacity");
    }
  }

  step(key) {
    return 1 + (key % (this.capacity - 1));
  }

  probe(key, i) {
    return (key % this.capacity + i * this.step(key)) % this.capacity;
  }
}

const maxIntermediate =
  (STRING_HASH_MODULUS - 1) * STRING_HASH_BASE + MAX_CODE_UNIT;
assert.equal(maxIntermediate, 68635);
assert.equal(maxIntermediate <= SAFE_INTEGER_LIMIT, true);

assert.equal(polynomialHash("cat", STRING_HASH_BASE, STRING_HASH_MODULUS), 90);
assert.equal(polynomialHash("dog", STRING_HASH_BASE, STRING_HASH_MODULUS), 58);
assert.equal(polynomialHash("a", STRING_HASH_BASE, STRING_HASH_MODULUS), 97);
assert.equal(polynomialHash("", STRING_HASH_BASE, STRING_HASH_MODULUS), 0);
assert.equal(polynomialHash("bit", STRING_HASH_BASE, STRING_HASH_MODULUS), 84);

assert.equal(multiplicationHash(10, 8), 1);
assert.equal(multiplicationHash(11, 8), 6);

assert.deepEqual(residues([0, 4, 8, 12, 16, 20], 12), [0, 4, 8, 0, 4, 8]);
assert.deepEqual(residues([0, 4, 8, 12, 16, 20], 11), [0, 4, 8, 1, 5, 9]);

const collision = new ChainedHashMap(7, 100);
collision.put(10, 100);
collision.put(3, 30);
collision.put(17, 170);
collision.put(8, 80);
collision.put(14, 140);
assert.equal(collision.capacity, 7);
assert.equal(collision.size, 5);
assert.equal(10 % 7, 3);
assert.equal(3 % 7, 3);
assert.equal(17 % 7, 3);
assert.deepEqual(collision.chainKeys(0), [14]);
assert.deepEqual(collision.chainKeys(1), [8]);
assert.deepEqual(collision.chainKeys(2), []);
assert.deepEqual(collision.chainKeys(3), [10, 3, 17]);
assert.deepEqual(collision.chainKeys(4), []);
assert.equal(collision.get(3), 30);
collision.put(10, 101);
assert.equal(collision.get(10), 101);
assert.equal(collision.size, 5);
assert.deepEqual(collision.chainKeys(3), [10, 3, 17]);
assert.equal(2 * 7 + (5 - 1), 18);
assert.equal(2 * 7, 14);
assert.equal(collision.delete(3), true);
assert.deepEqual(collision.chainKeys(3), [10, 17]);
assert.equal(collision.get(3), null);
assert.equal(collision.get(17), 170);
assert.equal(collision.contains(10), true);
assert.equal(collision.delete(10), true);
assert.deepEqual(collision.chainKeys(3), [17]);
assert.equal(collision.contains(10), false);
assert.equal(collision.contains(3), false);
assert.equal(collision.size, 3);
assert.equal(collision.get(14), 140);
assert.equal(collision.get(8), 80);
assert.equal(collision.delete(99), false);

const practice = new ChainedHashMap(5, 100);
practice.put(5, 5);
practice.put(9, 9);
practice.put(14, 14);
assert.deepEqual(practice.chainKeys(0), [5]);
assert.deepEqual(practice.chainKeys(1), []);
assert.deepEqual(practice.chainKeys(2), []);
assert.deepEqual(practice.chainKeys(3), []);
assert.deepEqual(practice.chainKeys(4), [9, 14]);

const growing = new ChainedHashMap(3, 1);
growing.put(3, "p");
growing.put(4, "q");
growing.put(5, "r");
assert.equal(growing.capacity, 3);
assert.equal(growing.size, 3);
assert.deepEqual(growing.chainKeys(0), [3]);
assert.deepEqual(growing.chainKeys(1), [4]);
assert.deepEqual(growing.chainKeys(2), [5]);
growing.put(6, "s");
assert.equal(growing.capacity, 6);
assert.equal(growing.size, 4);
assert.deepEqual(growing.chainKeys(0), [6]);
assert.deepEqual(growing.chainKeys(1), []);
assert.deepEqual(growing.chainKeys(2), []);
assert.deepEqual(growing.chainKeys(3), [3]);
assert.deepEqual(growing.chainKeys(4), [4]);
assert.deepEqual(growing.chainKeys(5), [5]);
growing.put(7, "t");
assert.equal(growing.capacity, 6);
assert.equal(growing.size, 5);
assert.deepEqual(growing.chainKeys(1), [7]);
assert.equal(growing.get(3), "p");
assert.equal(growing.get(4), "q");
assert.equal(growing.get(5), "r");
assert.equal(growing.get(6), "s");
assert.equal(growing.get(7), "t");

assert.deepEqual(rehashMoves(8, 2), { moves: 6, capacity: 8, size: 8 });

const linear = new LinearProbingMap(7);
assert.equal(linear.put(7, 7), 0);
assert.equal(linear.put(14, 14), 1);
assert.equal(linear.put(8, 8), 2);
assert.equal(linear.put(21, 21), 3);
assert.equal(linear.put(15, 15), 4);
assert.deepEqual(linear.occupancy(), [7, 14, 8, 21, 15, null, null]);
assert.equal(linear.delete(14), true);
assert.deepEqual(linear.occupancy(), [7, "T", 8, 21, 15, null, null]);
assert.equal(linear.get(8), 8);
assert.equal(linear.get(14), null);
assert.equal(linear.get(21), 21);
assert.equal(linear.tombstones, 1);
assert.equal(linear.size, 4);
assert.equal(linear.size + linear.tombstones, 5);
assert.equal(linear.put(28, 28), 1);
assert.deepEqual(linear.occupancy(), [7, 28, 8, 21, 15, null, null]);
assert.equal(linear.tombstones, 0);
assert.equal(linear.get(28), 28);
assert.equal(linear.get(8), 8);
assert.equal(linear.put(4, 4), 5);
assert.deepEqual(linear.occupancy(), [7, 28, 8, 21, 15, 4, null]);

assert.deepEqual(searchStoppingAtHole([7, null, 8, 21, 15, null, null], 8), {
  found: false,
  examined: [1],
});
assert.deepEqual(searchStoppingAtHole([7, null, 8, 21, 15, null, null], 7), {
  found: true,
  examined: [0],
});

const quadratic = new QuadraticProbingMap(7);
assert.deepEqual(quadratic.probeSequence(0), [0, 1, 4, 2, 2, 4, 1]);
quadratic.put(0, 0);
quadratic.put(1, 1);
quadratic.put(2, 2);
quadratic.put(4, 4);
assert.deepEqual(quadratic.occupancy(), [0, 1, 2, null, 4, null, null]);
let exhausted = false;
try {
  quadratic.put(7, 7);
} catch (error) {
  exhausted = error instanceof Error && error.message === "probe sequence exhausted";
}
assert.equal(exhausted, true);
assert.deepEqual(quadratic.occupancy(), [0, 1, 2, null, 4, null, null]);

const doubled = new DoubleHashingMap(7);
assert.deepEqual(doubled.probeSequence(19), [5, 0, 2, 4, 6, 1, 3]);
assert.deepEqual(doubled.probeSequence(8), [1, 4, 0, 3, 6, 2, 5]);
assert.equal(doubled.step(19), 2);
assert.equal(doubled.put(19, 19), 5);
assert.equal(doubled.put(5, 5), 4);
assert.equal(doubled.put(12, 12), 6);
assert.deepEqual(doubled.occupancy(), [null, null, null, null, 5, 19, 12]);
assert.equal(doubled.get(5), 5);
assert.equal(doubled.get(12), 12);
assert.equal(doubled.get(19), 19);
assert.deepEqual(doubleProbe(1, 2, 8), [1, 3, 5, 7, 1, 3, 5, 7]);

let rejected = false;
try {
  new DoubleHashingMap(8);
} catch (error) {
  rejected =
    error instanceof Error &&
    error.message === "double hashing requires a prime capacity";
}
assert.equal(rejected, true);

console.log("ALL TESTS PASSED");
```

---

## Common mistakes

1. **Wrong idea:** a collision means the hash function failed and the insertion should be rejected. **Correction:** when the universe is larger than the table, collisions exist in the function. Separate chaining, linear probing, quadratic probing, and double hashing are the rules that store the colliding key. Rejection is the behavior of a probe sequence that has repeated itself, which is a property of that probe, and it is the quadratic example where slots $3$, $5$, and $6$ were still empty.

2. **Wrong idea:** "expected constant time" means every call returns in a few instructions. **Correction:** $\Theta(1+\alpha)$ is an expectation under simple uniform hashing. The worst case is $\Theta(n)$. The insertion that rehashes also does $\Theta(n)$ work on that call. Amortized expected $\Theta(1)$ is a statement about a sequence, with both adjectives present.

3. **Wrong idea:** open addressing deletes a key by writing `null`. **Correction:** `null` ends a later search. The deletion of $14$ by a hole hid key $8$. A tombstone continues the search. The insertion of $28$ reused it.

4. **Wrong idea:** tombstones do not affect the load, because the deleted key is gone. **Correction:** search reads a tombstone and continues. After deleting $14$, the live load was $4/7$ and the occupied load was $5/7$. A rehash that inserts only live keys is what sets the tombstone count back to $0$.

5. **Wrong idea:** walking the slots lists the keys in sorted order. **Correction:** slot order follows the hash and the collision rule. Key order is the in-order walk of the binary search tree in Lecture 08. A hash table does not provide it.

6. **Wrong idea:** JavaScript's `%` is mathematical modulo for every integer. **Correction:** a negative left operand can produce a negative remainder, and a negative remainder is not a slot. The maps in this lecture accept only nonnegative integer keys, where `%` and mathematical modulo agree.

7. **Wrong idea:** writing `% modulus` makes a string hash exact for any modulus. **Correction:** the product $h \cdot a + c$ must be an exact safe integer before the remainder is taken. Base $31$ and modulus $101$ keep that product at most $68635$. A larger pair must be checked against $2^{53}-1$ again.

8. **Wrong idea:** quadratic probing finds an empty slot whenever the table has one. **Correction:** $(h + i^2) \bmod m$ for an odd prime $m$ visits $(m+1)/2$ slots. The modulus-$7$ sequence from home $0$ never visits $3$, $5$, or $6$.

9. **Wrong idea:** a rehash is negligible because it is rare. **Correction:** the call that rehashes moves every live key. In the capacity-$2$ sequence, the fifth insertion moves $4$ keys. The aggregate bound says the sequence of eight insertions moves $6$ keys in total. It does not shorten the fifth call.

10. **Wrong idea:** $m = 2^p$ is the right division modulus because a bit mask is fast. **Correction:** $k \bmod 2^p$ keeps the lowest $p$ bits, so keys that share those bits collide. A prime modulus spreads an arithmetic progression whose difference is not a multiple of that prime. The speed of the division is a separate question from the residue set.

11. **Wrong idea:** a cryptographic hash should be the default table hash because it is "more random," and `Map` already proves the expected-time theorem. **Correction:** this lecture does not claim attack resistance and does not teach a cryptographic construction. An adversary who knows a fixed hash can force one chain. Randomized hashing from a universal family is the named reply, and its construction is outside this lecture. `Map` is a language map with insertion-order iteration. It is not a proof of simple uniform hashing.

---

## Examination

Answer from the lecture. Do not use the answer key while you write. Show the arithmetic.

1. Define load factor, collision, tombstone, primary clustering, a perfect hash for a fixed set $S$, and a minimal perfect hash.

2. State simple uniform hashing in symbols.

3. The universe has $10^9$ keys and the map will store $1000$ of them. Why does a direct-address table fail? What does a hash table allocate instead?

4. For the keys $0, 4, 8, 12, 16, 20$, list the residues modulo $12$ and modulo $11$. How many distinct residues appear in each list? The theorem on arithmetic progressions says how many distinct residues the infinite progression with difference $4$ occupies, modulo $12$ and modulo $11$. Give both counts, with the gcd in each case.

5. Compute the polynomial hash of `"id"` with base $31$ and modulus $101$. The codes are `i = 105` and `d = 100`. Show each product before the remainder and each remainder.

6. A chained table has $m = 5$, appends at the tail, and does not resize. Insert the keys $5$, $12$, $7$, and $17$, each with value equal to the key. Draw the five chains. Delete $12$. Draw the five chains again. Give $n$ and $\alpha$ before the deletion and after the deletion.

7. A chained table has $m = 1000$ and $n = 500$. Assume simple uniform hashing, and assume the chain is stored in insertion order. Give the expected number of elements examined by an unsuccessful search, and by a successful search. Write the assumption in symbols. Give the worst-case number of elements examined by a search in this table.

8. Linear probing uses $m = 11$ and $h(k, i) = (k + i) \bmod 11$. Insert $11$, then $22$, then $4$. Draw the table. Delete $11$ with a tombstone. Draw the table. Insert $33$. Draw the table and name the slot that holds $33$. If the deletion had written an empty slot instead of a tombstone, which slots would a search for $22$ examine, and what would it return?

9. A chained table starts at capacity $4$ and doubles when an insertion of a new key finds $n + 1 > m$, moving every live key. Sixteen insertions of new keys are performed. How many key-moves do the rehashes perform? What is the amortized number of moves per insertion? Which insertion number moves the most keys, and how many does it move?

10. Take $\alpha = 3/4$, with no deletions. Use $\ln 2 = 0.693$.
    - Under independent uniform permutation hashing, give the upper bound on the expected number of probes in an unsuccessful search, and the upper bound in a successful search from $(1/\alpha) \ln (1/(1-\alpha))$, to three decimal places.
    - Under Knuth's stated linear-probing formulas, give the unsuccessful and successful probe counts.

11. List $(0 + i^2) \bmod 7$ for $i = 0, 1, \ldots, 6$. Which slots are never visited? Why can an insertion fail while empty slots remain?

12. Why is a hash table not the map for every job? Answer in one paragraph that covers key order, the worst case, and an adversary who knows the hash. You may name the binary search tree of Lecture 08 as the structure that provides key order. Do not describe a rotation or a balance factor.

13. The multiplication method uses $A = 0.618034$ and $m = 8$. Compute $h(20)$. Show the product, the fractional part, the value scaled by $8$, and the floor.

14. An attacker can choose the keys after reading the source of a fixed hash function. What does this course refuse to claim about that attacker? Name the randomized reply, and state what this lecture does not construct.

---

## Answer key

1. The load factor is $\alpha = n/m$, the number of stored keys divided by the number of slots. A collision is two keys with the same hash slot. A tombstone is a slot state meaning that a key was deleted there: search must continue, and insertion may reuse the slot. Primary clustering is the growth of a contiguous run under linear probing: a run of length $L$ absorbs every key whose home lies in those $L$ slots and therefore tends to become longer. A hash is perfect for a fixed set $S$ when no two keys of $S$ collide. It is minimal perfect when it is perfect and $m = |S|$.

2. For every key $k$ and every slot $j$, $\Pr(h(k) = j) = 1/m$, and the hash values of distinct keys are independent.

3. A direct-address table allocates one slot per universe element, so it asks for an array of length $10^9$ in order to store $1000$ pairs. The space follows the universe. A hash table allocates $m$ slots with $m$ chosen near the number of keys that are stored, and it resolves the collisions that the smaller table creates.

4. Modulo $12$ the residues are $0, 4, 8, 0, 4, 8$. Three distinct values appear. Modulo $11$ the residues are $0, 4, 8, 1, 5, 9$. Six distinct values appear. For the infinite progression, $\gcd(4, 12) = 4$ and $12/4 = 3$, so the progression occupies $3$ residues modulo $12$. And $\gcd(4, 11) = 1$ and $11/1 = 11$, so the progression occupies all $11$ residues modulo $11$. The six keys in the finite list are six of those eleven; they have not repeated yet.

5. The code $105$ is larger than the modulus, so the first step reduces it.
$$
105 = 1 \cdot 101 + 4, \qquad h = 4.
$$
The next product is $4 \cdot 31 + 100 = 124 + 100 = 224$. And $2 \cdot 101 = 202$, so
$$
224 - 202 = 22.
$$
The hash of `"id"` is $22$.

6. The homes are $5 \bmod 5 = 0$, $12 \bmod 5 = 2$, $7 \bmod 5 = 2$, and $17 \bmod 5 = 2$. Before the deletion:
```text
slot 0: 5
slot 1: empty
slot 2: 12, 7, 17
slot 3: empty
slot 4: empty
```
Here $n = 4$ and $\alpha = 4/5$. After deleting $12$:
```text
slot 0: 5
slot 1: empty
slot 2: 7, 17
slot 3: empty
slot 4: empty
```
Here $n = 3$ and $\alpha = 3/5$.

7. The assumption is: for every key $k$ and every slot $j$, $\Pr(h(k) = j) = 1/m$, and distinct keys hash independently. An unsuccessful search examines $\alpha = 500/1000 = 1/2$ elements in expectation. A successful search examines
$$
1 + \frac{500 - 1}{2 \cdot 1000} = 1 + \frac{499}{2000} = \frac{2499}{2000} = 1.2495
$$
elements in expectation. The worst case examines $500$ elements, which is $n$, when every key lies on the one chain that the search reads and the target is at the end of that chain, or when the search is unsuccessful on that chain.

8. Homes: $11 \bmod 11 = 0$, $22 \bmod 11 = 0$, $4 \bmod 11 = 4$. After the three insertions, slot $0$ holds $11$, slot $1$ holds $22$, and slot $4$ holds $4$. The other slots are empty. After the tombstone deletion, slot $0$ holds `T`, slot $1$ holds $22$, and slot $4$ holds $4$. Key $33$ has home $33 \bmod 11 = 0$. Slot $0$ is a tombstone, so it is remembered. Slot $1$ holds $22$. Slot $2$ is empty, so $33$ is not already present. Insertion writes $33$ into the remembered tombstone at slot $0$. The table holds $33$ at slot $0$, $22$ at slot $1$, and $4$ at slot $4$.

If slot $0$ had been a hole, a search for $22$ would examine slot $0$, see an empty slot, and return absent. It would not examine slot $1$, where $22$ is stored.

9. The resizes run when $n = 4$ and when $n = 8$. They move $4$ keys and then $8$ keys. The total is $12$. The amortized count is $12/16 = 3/4$. The ninth insertion is the one that finds $n = 8$ and capacity $8$, so it moves $8$ keys, which is the maximum among the sixteen insertions. After sixteen insertions, $n = 16$ and the capacity is $16$. The insertion that would move $16$ keys is the seventeenth, which is outside the sequence.

10. The unsuccessful ideal bound is $1/(1 - 3/4) = 1/(1/4) = 4$. The successful ideal bound is
$$
\frac{1}{3/4} \ln \frac{1}{1/4} = \frac{4}{3} \ln 4 = \frac{4}{3} \cdot 2 \cdot 0.693 = \frac{8}{3} \cdot 0.693 = \frac{5.544}{3} = 1.848.
$$
Knuth's unsuccessful count is
$$
\frac{1}{2}\left(1 + \frac{1}{(1/4)^2}\right) = \frac{1}{2}(1 + 16) = 8.5.
$$
Knuth's successful count is
$$
\frac{1}{2}\left(1 + \frac{1}{1/4}\right) = \frac{1}{2}(1 + 4) = 2.5.
$$

11. The seven values are $0, 1, 4, 2, 2, 4, 1$, because $9 \bmod 7 = 2$, $16 \bmod 7 = 2$, $25 \bmod 7 = 4$, and $36 \bmod 7 = 1$. Slots $3$, $5$, and $6$ never appear. An insertion whose probe stays inside $\{0, 1, 2, 4\}$ cannot use the empty slots outside that set, so it fails while those slots are empty. For an odd prime the number of distinct squares modulo $m$ is $(m+1)/2$, which is $4$ when $m = 7$.

12. A hash table locates a key by equality and by a slot computation. It does not list keys from smallest to largest, and it does not answer a successor query; the binary search tree of Lecture 08 does both, because its search property follows a total order. The search cost of the hash table is $\Theta(n)$ in the worst case, when every key collides, so a client that needs a bound on every operation does not get that bound from this lecture. An adversary who knows the fixed hash can choose the colliding set on purpose, for example the multiples of $m$ under the division method. Expected constant time holds when simple uniform hashing holds and the load factor stays constant. It is not a guarantee against that adversary, and this lecture does not construct the universal family that is the randomized reply.

13. $20 \cdot 0.618034 = 12.36068$. The fractional part is $0.36068$. Scaled by the table length, $8 \cdot 0.36068 = 2.88544$. The floor is $2$. So $h(20) = 2$.

14. The course refuses to claim that the table resists the attacker. A fixed hash, once known, can be aimed at a single slot, and the cost becomes $\Theta(n)$. The randomized reply is to draw the hash from a universal family, so that any fixed pair of keys collides with probability at most $1/m$. This lecture names that family and does not construct it, and it does not teach a cryptographic hash.

---

## Independent assignment

Produce two artifacts and keep both. Budget several hours. The point of the assignment is to watch the load-factor formulas succeed on one set of keys and fail on another, with numbers you computed.

**Artifact 1.** A Node.js program that imports nothing except `node:assert/strict` if you want assertions, and that does not use `Map`.

Generate keys with the Park–Miller recurrence
$$
x_{i+1} = (48271 \cdot x_i) \bmod (2^{31} - 1), \qquad x_0 = 1.
$$
The product $48271 \cdot x_i$ stays inside the safe-integer range for every residue modulo $2^{31}-1$. Take the first $2000$ outputs as keys. They are nonzero. Check that they are pairwise distinct and abort if they are not.

Implement separate chaining for nonnegative integer keys with the division hash, append at the tail, and a fixed capacity for each measurement. Do not resize during a measurement.

For $m \in \{500, 1000, 2000, 4000\}$, insert the $2000$ keys into a fresh table. Record $n$, $m$, $\alpha$, the average chain length, and the maximum chain length. The average chain length equals $\alpha$ by the identity in Part 4, for every hash, so this line is a sanity check on your lengths. Also record the average, over the $2000$ stored keys, of the number of elements a successful search examines, and compare it with $1 + (n-1)/(2m)$.

Then build the adversarial set $\{0, m, 2m, \ldots, (n-1)m\}$ with $n = 2000$ and $m = 1000$. Every key must land in slot $0$. The successful search for the last key must examine $2000$ elements. The average over the $n$ keys of the successful-search cost must be $(n+1)/2$. Assert these three facts.

Implement linear probing with no deletions. For $\alpha = 1/2$, use $n = 1000$ and $m = 2000$ on the first $1000$ Park–Miller keys. For $\alpha = 3/4$, use $n = 1500$ and $m = 2000$. Count the average number of probes in a successful search over the stored keys, and the average number of probes in an unsuccessful search over $500$ keys that are not in the table (add $2^{31}-1$ to a stored key, or another shift you prove is absent). Place those four measurements next to Knuth's two formulas and next to the ideal bounds $1/(1-\alpha)$ and $(1/\alpha)\ln(1/(1-\alpha))$. Use $\ln 2 = 0.693$ and $\ln 10 = 2.303$ only where you need them, and show the arithmetic.

Print a text table of predicted and measured values. The program must throw if the adversarial assertions fail. It does not need to throw because a random trial differs from a formula in the second decimal place. The discussion in Artifact 2 is where that gap is interpreted.

**Artifact 2.** A note of about one page. State whether the Park–Miller chains tracked $1 + (n-1)/(2m)$, and by how much the maximum chain exceeded $\alpha$. State the gap between your linear-probing measurements and Knuth's formulas. State, with the operation named, one map for which you would use the binary search tree of Lecture 08 instead of either hash table, and give the cost you are buying. Include the adversarial row so the worst case is a measured $\Theta(n)$, not a slogan.

---

## Glossary

**Amortized expected cost.** The aggregate cost of a sequence, divided by the length of the sequence, when the hash-dependent part of the cost is an expectation. In this lecture an insertion under doubling and simple uniform hashing is amortized expected $\Theta(1)$.

**Chain.** The list of pairs whose keys share one slot. In the implementation it is a JavaScript array used as a list, not a second hash table.

**Collision.** Two keys with the same hash slot.

**Deterministic hash.** A hash that returns the same slot for the same key on every call.

**Direct-address table.** An array indexed by the key itself, of length equal to the universe.

**Division method.** The hash $h(k) = k \bmod m$.

**Double hashing.** Open addressing with $h(k, i) = (h_1(k) + i \cdot h_2(k)) \bmod m$, where $h_2(k)$ is coprime to $m$.

**Equality.** The relation `get` uses to decide that two keys are the same key. It is not a total order.

**Expected constant time.** The bound $\Theta(1)$ obtained when $\alpha$ is held at a constant and simple uniform hashing holds, so that $\Theta(1+\alpha)$ collapses to $\Theta(1)$. It is an expectation, not a worst-case bound.

**Hole.** An empty slot written by a deletion on a probe sequence that other keys walked through. Search stops there and can miss a later key.

**Home slot.** The first probe, $h(k, 0)$, or $h(k)$ when the hash returns a single slot.

**Independent uniform permutation hashing.** The open-addressing model in which each key's probe sequence is uniform among the $m!$ permutations. CLRS, Chapter 11, uses this name. Linear probing does not satisfy it.

**Load factor.** $\alpha = n/m$.

**Map.** The ADT with `put`, `get`, `delete`, and `contains`, storing one value per key.

**Minimal perfect hash.** A perfect hash for $S$ that uses $m = |S|$ slots.

**Multiplication method.** The hash $\lfloor m \cdot (kA \bmod 1) \rfloor$ for a constant $A$ in $(0, 1)$.

**Occupied load.** $(n + t)/m$, where $t$ is the number of tombstones.

**Open addressing.** Collision resolution that stores every key inside the slot array and walks a probe sequence.

**Perfect hash.** A hash that is one-to-one on a fixed set $S$.

**Polynomial hash.** The string hash $h_{i+1} = (h_i \cdot a + c_i) \bmod m$, with $h_0 = 0$.

**Primary clustering.** The tendency of a linear-probing run to grow, because every home inside the run extends it.

**Probe sequence.** The ordered slots examined for one key under open addressing.

**Quadratic probing.** Open addressing with $h(k, i) = (h(k) + i^2) \bmod m$. For an odd prime $m$ this visits $(m+1)/2$ slots.

**Rehash.** Insertion of every live key into a new table under the new modulus. Tombstones are not reinserted.

**Safe integer.** An integer in the closed interval from $-(2^{53}-1)$ to $2^{53}-1$, which JavaScript stores exactly.

**Separate chaining.** Collision resolution that keeps a list at each slot.

**Simple uniform hashing.** The assumption that each key is independently equally likely to land in any slot: $\Pr(h(k) = j) = 1/m$, and distinct keys are independent. CLRS, 4th edition, calls this independent uniform hashing.

**Tombstone.** A slot marker that continues a search and may be reused by a later insertion.

**Total order.** A comparison that places every pair of unequal keys in order. A hash table does not require one.

**Universal family.** A set of hash functions in which every fixed pair of distinct keys collides under at most a $1/m$ fraction of the functions. This lecture names the family and does not construct it.

**Universe.** The set of all keys the hash is defined on, as opposed to the set stored in the table.

**Value.** The satellite data paired with a key.

---

## Lecture summary

A map answers `get` by equality. A direct-address table does that in worst-case constant time when the universe is small enough to allocate. When the universe is huge and the stored set is small, a hash function compresses keys into $m$ slots, and collisions are unavoidable. The division method, the multiplication method with Knuth's recommended constant $(\sqrt{5}-1)/2$, and the polynomial string hash with base $31$ and modulus $101$ are three deterministic compressions. The modulus $101$ is small enough that every intermediate product in the string hash is an exact safe integer.

Separate chaining stores each collision list at its slot. The average chain length is exactly the load factor $\alpha = n/m$. Under simple uniform hashing the expected unsuccessful search examines $\alpha$ elements, and the expected successful search examines $1 + (n-1)/(2m)$ elements. Both running times are $\Theta(1+\alpha)$. The worst case is $\Theta(n)$. Doubling the table when $\alpha$ would exceed $1$, and rehashing every key, keeps $\alpha$ constant. The rehash costs linear time when it runs. Across a sequence the aggregate method charges fewer than two key-moves per insertion.

Open addressing stores keys in the slot array and walks a probe sequence. Linear probing covers every slot and forms primary clusters. Quadratic probing of the form $h + i^2$ misses slots on a prime table. Double hashing covers every slot when the step is coprime to the table length. Deletion must leave a tombstone, because a hole stops a later probe. Tombstones count in the occupied load. The ideal probe model bounds unsuccessful search by $1/(1-\alpha)$ and successful search by $(1/\alpha)\ln(1/(1-\alpha))$. Knuth's linear-probing formulas are larger, and at $\alpha = 0.9$ an unsuccessful linear probe is already tens of probes while a chained search still examines a chain of expected length $0.9$.

Expected constant time is the sentence "$\alpha$ is constant and simple uniform hashing holds." It is not a worst-case promise, not a statement that rehashing is free, and not a statement about an adversary who knows $h$. JavaScript's `Map` is a language map. It becomes appropriate in later application code after the laboratory program is yours.

### Five principles

1. A hash sends a key to a slot. It does not put keys in order.
2. A collision is an ordinary event whenever the universe is larger than the table, and the collision rule is part of the structure.
3. Expected constant time requires simple uniform hashing, written as $\Pr(h(k) = j) = 1/m$ with independence, and a load factor held at a constant. The worst case stays linear.
4. Open addressing stops at an empty slot, so a deletion on a probe path leaves a tombstone. The tombstone still occupies the slot.
5. A rehash moves every live key. The aggregate method makes a sequence of doublings cheap per insertion, and the insertion that performs the rehash remains linear.

---

## References

1. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapter 11.
2. Robert Sedgewick and Kevin Wayne. *Algorithms*. 4th edition. Addison-Wesley, 2011. Section 3.4.
3. Donald E. Knuth. *The Art of Computer Programming, Volume 3: Sorting and Searching*. 2nd edition. Addison-Wesley, 1998. Section 6.4.
4. Michael T. Goodrich, Roberto Tamassia, and Michael H. Goldwasser. *Data Structures and Algorithms in Java*. 6th edition. Wiley, 2014. Chapter 10.
5. Mark Allen Weiss. *Data Structures and Algorithm Analysis in C++*. 4th edition. Pearson, 2014. Chapter 5.
6. J. Lawrence Carter and Mark N. Wegman. "Universal Classes of Hash Functions." *Journal of Computer and System Sciences* 18 (1979): 143–154.
