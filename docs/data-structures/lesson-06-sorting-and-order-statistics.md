# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 06 — SORTING AND ORDER STATISTICS

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 06 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 10 hours
**Prerequisites:** Lecture 01 — Models, ADTs, and Asymptotic Analysis; Lecture 05 — Recursion, Induction, and Divide-and-Conquer
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapters 2, 4, 5, 7, 8, and 9; Sedgewick and Wayne, *Algorithms*, 4th edition, Chapter 2

**This lecture owns:** comparison sorting, mergesort, quicksort with Lomuto partition, the comparison lower bound, counting sort, radix sort, and quickselect.
**This lecture does not teach:** the binary heap or heapsort's sift procedures. Heapsort is $\Theta(n \log n)$ and is built in Lecture 10. Bucket sort, external sorting, and most-significant-digit radix sort are also outside this lecture.

---

## 1. Learning objectives

After this lecture you should be able to do the following.

1. Define a stable sort, state the in-place convention used here, and state what a comparison is allowed to reveal in the comparison model.
2. Give the exact worst-case key-comparison counts of selection sort and insertion sort, maintain each algorithm's invariant, and execute insertion sort on a numeric array.
3. Merge two sorted runs by hand, solve $T(n) = 2T(n/2) + \Theta(n)$ by the Master Theorem and by a recursion tree, and prove that a left-preferring merge is stable.
4. Execute Lomuto partition by hand, derive the $\Theta(n^2)$ worst case of quicksort, and carry out the indicator-variable argument for the expected comparison count of randomized quicksort.
5. Derive the $\Omega(n \log n)$ comparison lower bound from the height of a decision tree, using either the elementary bound on $n!$ proved here or the stated form of Stirling's approximation.
6. Execute stable counting sort and least-significant-digit radix sort by hand, and prove radix-sort correctness by induction on the digit index.
7. Find the minimum and the maximum together with at most $3\lfloor n/2 \rfloor$ comparisons, and state the expected-time recurrence of randomized quickselect.
8. Choose an algorithm by naming $n$, the key domain, the stability requirement, and the auxiliary memory.

---

## 2. Purpose of the lecture

Sorting is the problem of arranging a finite sequence into nondecreasing order. Order statistics is the problem of finding the element that would sit at a stated index after that arrangement, without necessarily producing the rest of the arrangement.

Binary search and proofs by induction are Lecture 05. The Master Theorem, $\Theta$ notation, and the unfolding of a recurrence are Lecture 01. This lecture uses those tools on the first family of algorithms whose bounds meet, and then escape, a theorem about every comparison.

The lecture develops six procedures far enough that you can run them by hand and in JavaScript: insertion sort, top-down mergesort, quicksort with Lomuto partition, counting sort, least-significant-digit radix sort, and randomized quickselect. Selection sort is included because its comparison count is exact on every input. Median-of-medians selection is included because it is the worst-case linear algorithm for one order statistic; the laboratory implements it and tests it. Heapsort's bound is quoted so the decision table is complete. The binary heap, and the sift that heapsort uses, belong to Lecture 10.

JavaScript arrays are the dynamic arrays of Lecture 02, used here as random-access storage with constant-time indexing. The language's own `Array.prototype.sort` is never called. Engine-specific representations of arrays are irrelevant to the bounds. Numeric code uses ordinary numbers. Counting sort and radix sort require integer keys whose digit arithmetic stays inside the safe-integer range, at most $2^{53}-1$. That limit is a property of JavaScript numbers. The mathematical algorithms are stated for integers in general, and the laboratory stays inside the range where every integer result is exact.

---

## 3. The sorting problem

### 3.1 Input and output

Let $A[0..n-1]$ be an array of $n$ elements drawn from a totally ordered set. The **sorting problem** asks for a permutation of those elements such that

$$
A[0] \le A[1] \le \cdots \le A[n-1].
$$

Equal keys are allowed. The order is nondecreasing, which permits ties. A procedure that demanded a strict increase would be unable to sort an array that contains two equal keys.

The elements are often records. A **key** is the field the order reads. The rest of the record is payload that must travel with the key. In the laboratory a record is an object `{key, id}` where `id` remembers the original position. Sorting an array of bare numbers is the special case in which the key is the whole element.

### 3.2 Stability

A sort is **stable** when equal keys leave the array in their original relative order. If $i < j$ and the key of $A[i]$ equals the key of $A[j]$ before the sort, then the record that began at $i$ appears before the record that began at $j$ in the output.

Stability is a property of records, not of bare numbers. Two copies of the number $3$ are indistinguishable, so a numeric array cannot witness a failure. Attach identities and the failure becomes visible. Section 4 shows that selection sort reverses the two records of key $2$ in $[(2,a),(2,b),(1,c)]$. Section 5 proves that mergesort, with the tie rule stated there, keeps $a$ before $b$.

Stability is the reason a person can sort a table by city and then by name, and still have the cities in order inside each name group, provided the second sort is stable and is the sort by name. Least-significant-digit radix sort, Section 10, is that idea applied to digits. An unstable second sort can undo the order the first sort established.

### 3.3 Auxiliary memory and the word "in-place"

**Auxiliary memory** is memory beyond the input array. This lecture uses the following convention, and uses it the same way in every later claim.

- A procedure is **in-place** when every stack frame stores $\Theta(1)$ words and the procedure allocates no second array of elements.
- The **stack depth** is reported separately. A recursion of depth $d$ stores $\Theta(d)$ words of indices and return addresses even when each frame is in-place in the sense above.

Under that convention insertion sort and selection sort are in-place, and the stack depth is $\Theta(1)$ because the loops are iterative. Lomuto partition is in-place. Plain quicksort is in-place per frame, with stack depth $\Theta(n)$ in the worst case and expected depth $O(\log n)$ under random pivots. Mergesort allocates an auxiliary buffer of $n$ elements, so its auxiliary element memory is $\Theta(n)$, and its stack depth is $\Theta(\log n)$. Counting sort allocates a count array of length $k+1$ and an output array of length $n$.

Words that are indices are not elements. The convention above is the one used by the comparison of mergesort with quicksort: mergesort moves $\Theta(n)$ elements into a second buffer; quicksort rearranges elements inside the input and stores indices on the stack.

### 3.4 The comparison model

A **comparison sort** may examine the order of keys only by comparing two of them. Each comparison has two outcomes. The model used for the lower bound takes the outcomes to be "$x \le y$" and "$x > y$". A three-way comparison that returns less, equal, or greater can be simulated by a constant number of two-outcome comparisons, so it changes constant factors and does not change an $\Omega(n \log n)$ result.

The comparison reveals nothing else. It does not return the rank of a key, the number of inversions, or a hash of the key. An algorithm in this model may use the Boolean outcome to decide which pair to compare next, and it may rearrange records. The **decision tree** of Section 8 is the record of those Boolean choices.

Insertion sort, selection sort, mergesort, quicksort, and heapsort are comparison sorts. Counting sort and radix sort index memory by the key. They are correct sorting algorithms, and the decision-tree theorem does not apply to them, because its hypothesis is absent. Section 9 says this again next to the counting-sort bound, where the point is easy to lose.

Throughout the comparison algorithms, the cost we count first is the number of key comparisons. In the RAM model each comparison, index, and assignment is $\Theta(1)$ time, and for these procedures the running time has the same $\Theta$ bound as the comparison count, or as the length of the counting loops when the algorithm is not a comparison sort. Swaps are $\Theta(1)$ per swap. Where an exact comparison count is available it is stated as an integer, not only as a $\Theta$ bound.

### 3.5 Inversions

An **inversion** in an array is a pair of indices $i < j$ with $A[i] > A[j]$. A sorted array has zero inversions. A reverse-sorted array of $n$ distinct keys has $n(n-1)/2$ inversions, one for every pair. Insertion sort's data movement is exactly the inversion count. That identity is proved in the next section, after the procedure is specified.

---

## 4. Selection sort and insertion sort

Both algorithms below are iterative, in-place, and $\Theta(n^2)$ in the worst case. They earn their place because the comparison counts are exact, the invariants are short, and insertion sort is the stable algorithm a mergesort or quicksort may call on a tiny subarray. The cutoff itself is an exercise in the independent assignment. The bounds below are for the plain algorithms on the whole array.

### 4.1 Selection sort

**Reason.** The prefix $A[0..i-1]$ should already be the $i$ smallest elements, in order. The next action is to find the minimum of the unsorted suffix and swap it into position $i$.

**Procedure.** For $i$ from $0$ to $n-2$, scan $j$ from $i+1$ to $n-1$, remember the index of the minimum key in $A[i..n-1]$, and swap that index with $i$. The comparison that updates the remembered index is strict: replace the remembered index when $A[j] < A[\mathrm{min}]$. A non-strict test would prefer a later equal key and would move equal records even more freely. The strict test does not make the algorithm stable. The swap can still carry an early record across another record of equal key.

**Invariant.** At the start of iteration $i$, the prefix $A[0..i-1]$ is sorted, and every element of the prefix is less than or equal to every element of the suffix $A[i..n-1]$.

The invariant holds at $i = 0$ because the prefix is empty. The scan selects a minimum of the suffix. After the swap, position $i$ holds a minimum of what had been the suffix, so it is at least as large as everything already in the prefix and at most as large as everything that remains. The prefix $A[0..i]$ then satisfies the invariant for the next iteration. At $i = n-1$ the suffix has one element and the loop stops. The whole array is sorted.

**Comparisons.** Iteration $i$ always performs $n-1-i$ key comparisons. The scan does not stop early, because a minimum is known only after every suffix element has been seen. The total is

$$
\sum_{i=0}^{n-2} (n-1-i) = \sum_{t=1}^{n-1} t = \frac{n(n-1)}{2}.
$$

The identity $\sum_{t=1}^{m} t = m(m+1)/2$ is the one from Lecture 01, with $m = n-1$. The count does not depend on the data. Best case, worst case, and every other case use exactly $n(n-1)/2$ key comparisons. The number of swaps is at most $n-1$.

**A short trace.** Selection sort on $[5, 2, 4, 6, 1]$.

| $i$ | scan | swap | array afterwards |
| --- | --- | --- | --- |
| 0 | minimum $1$ at index $4$ | indices $0$ and $4$ | $[1, 2, 4, 6, 5]$ |
| 1 | minimum $2$ already at index $1$ | none that changes values | $[1, 2, 4, 6, 5]$ |
| 2 | minimum $4$ already at index $2$ | none | $[1, 2, 4, 6, 5]$ |
| 3 | minimum $5$ at index $4$ | indices $3$ and $4$ | $[1, 2, 4, 5, 6]$ |

Comparisons: $4+3+2+1 = 10 = 5\cdot 4/2$.

**Unstable.** On records $[(2,a),(2,b),(1,c)]$ the minimum of the whole array is $(1,c)$. Swapping it with $(2,a)$ yields $[(1,c),(2,b),(2,a)]$. The two keys equal to $2$ have reversed their original order. The laboratory asserts those ids.

### 4.2 Insertion sort

**Reason.** A sorted prefix can absorb the next element by sliding larger keys one position to the right until the hole is the correct rank of the new key. Adjacent data movement matches inversions one by one, which is why a nearly sorted array is cheap.

**Procedure.** For $i$ from $1$ to $n-1$, let $\mathrm{key} = A[i]$ and let $j = i-1$. While $j \ge 0$ and $A[j] > \mathrm{key}$, copy $A[j]$ into $A[j+1]$ and decrease $j$. Then write $\mathrm{key}$ into $A[j+1]$. The test is strict greater-than. An equal key stops the slide, so the new record is inserted to the right of records already in the prefix that share its key.

**Invariant.** At the start of iteration $i$, the prefix $A[0..i-1]$ is a sorted permutation of the elements that originally occupied $A[0..i-1]$.

The invariant holds at $i = 1$. The slide removes the hole at $i$ and shifts it leftward across keys that are strictly larger than $\mathrm{key}$. It stops when $j < 0$ or when $A[j] \le \mathrm{key}$. Every key to the right of the hole and inside the old prefix is then strictly larger than $\mathrm{key}$, and every key to the left is at most $\mathrm{key}$. Writing $\mathrm{key}$ into the hole restores a sorted prefix of length $i+1$ containing the original first $i+1$ elements. At termination $i = n$ and the array is sorted.

**Stability.** Suppose two equal keys occur at original indices $p < q$. Consider the moment $q$ is inserted. The record from $p$ is already in the sorted prefix, because $p < q$. The slide stops on $A[j] > \mathrm{key}$ failing, and an equal key fails that test. The record from $p$ is therefore not moved past the hole. The new record is placed to its right. Later insertions may shift both records rightward together when a still smaller key arrives; a shift moves a contiguous block and preserves relative order inside the block. So the record from $p$ stays before the record from $q$.

**Worst-case comparisons.** If the array is strictly decreasing, the new key is smaller than every element of the prefix. Iteration $i$ compares the key with all $i$ prefix elements, each comparison succeeds, and $j$ falls off the left end. There is no failing key comparison on that iteration. The total is

$$
\sum_{i=1}^{n-1} i = \frac{n(n-1)}{2}.
$$

**Best-case comparisons.** If the array is already nondecreasing, iteration $i$ performs one comparison, $A[i-1] > \mathrm{key}$ is false, and the key stays where it is. The total is $n-1$.

**Inversions and the count in between.** Let $I$ be the number of inversions in the original array. Each shift copies a key that forms an inversion with the key being inserted, and each inversion causes exactly one shift, on the iteration that inserts the right-hand element of that pair. The number of shifts is exactly $I$.

Each iteration $i$ performs one key comparison per shift during that iteration, plus one extra key comparison when the slide stops because $A[j] \le \mathrm{key}$. When the key is smaller than the entire prefix there is no extra comparison. If $F$ is the number of iterations that insert at the extreme left, then the number $C$ of key comparisons is

$$
C = I + (n-1-F),
$$

and therefore

$$
I \le C \le I + (n-1).
$$

The worst case $I = n(n-1)/2$ forces $F = n-1$ and $C = n(n-1)/2$, which matches the count above. The best case $I = 0$ forces $F = 0$ and $C = n-1$.

**Trace of $[5, 2, 4, 6, 1, 3]$.** The laboratory asserts the final array and the comparison total $12$.

| $i$ | key | comparisons on this iteration | array after the insertion |
| --- | --- | --- | --- |
| 1 | $2$ | $5 > 2$ succeeds, then $j = -1$ | $[2, 5, 4, 6, 1, 3]$ |
| 2 | $4$ | $5 > 4$ succeeds, $2 > 4$ fails | $[2, 4, 5, 6, 1, 3]$ |
| 3 | $6$ | $5 > 6$ fails | $[2, 4, 5, 6, 1, 3]$ |
| 4 | $1$ | $6,5,4,2$ all succeed, then $j = -1$ | $[1, 2, 4, 5, 6, 3]$ |
| 5 | $3$ | $6,5,4$ succeed, $2 > 3$ fails | $[1, 2, 3, 4, 5, 6]$ |

Comparison total: $1+2+1+4+4 = 12$.

The inversions of the original array are $(5,2)$, $(5,4)$, $(5,1)$, $(5,3)$, $(2,1)$, $(4,1)$, $(4,3)$, $(6,1)$, $(6,3)$, so $I = 9$. Iterations $1$ and $4$ run off the left end, so $F = 2$ and $C = 9 + (5-2) = 12$. The identity agrees with the trace.

**Cost.** Worst-case time is $\Theta(n^2)$. Best-case time is $\Theta(n)$. The algorithm is stable and in-place, with $\Theta(1)$ stack depth.

### 4.3 Bubble sort, as a negative example

Bubble sort walks adjacent pairs and swaps a pair that is out of order. After the pass that places the next maximum into its final suffix cell, that suffix cell is finished. On a reverse-sorted input every compared pair swaps, and a complete run of passes performs

$$
(n-1) + (n-2) + \cdots + 1 = \frac{n(n-1)}{2}
$$

key comparisons. The worst-case cost is $\Theta(n^2)$. A flag that returns early when a pass performs no swap brings the best case down to $\Theta(n)$ and leaves the worst case unchanged.

The worst-case comparison count matches insertion sort. The algorithm moves more data, and the invariant after a partial pass is weaker than insertion sort's sorted prefix: only a finished suffix of maxima is known, while the prefix is still unordered. The procedure is not implemented in the laboratory. The count above is the fact worth keeping, and the algorithm stops here.

---

## 5. Mergesort

### 5.1 Why divide and conquer

Insertion sort pays for every inversion. A reverse-sorted array has $\Theta(n^2)$ inversions, so any algorithm whose work is proportional to inversions is quadratic on that input. Mergesort spends its work on merging already sorted runs. A run of length $m$ can be merged in $\Theta(m)$ time, and a balanced split produces $\Theta(\log n)$ layers of merging. The comparison lower bound of Section 8 says no comparison sort improves on $\Theta(n \log n)$ in the worst case, so this shape is optimal in that model.

The algorithm is top-down. The same merge can be driven from the bottom by doubling the run length. That organization has the same $\Theta(n \log n)$ bound. This lecture specifies and implements the top-down form.

### 5.2 The merge of two sorted runs

Let the current subarray be $A[\ell..r]$, and let $q$ satisfy $\ell \le q < r$. Assume $A[\ell..q]$ and $A[q+1..r]$ are each sorted. **Merge** copies the subarray into an auxiliary buffer $B[\ell..r]$ and writes a sorted result back into $A[\ell..r]$.

Indices $i$ and $j$ start at $\ell$ and $q+1$. For each output position $k$ from $\ell$ to $r$:

- If $i$ has passed $q$, copy $B[j]$ and advance $j$.
- If $j$ has passed $r$, copy $B[i]$ and advance $i$.
- If $B[j] < B[i]$, copy $B[j]$ and advance $j$.
- Otherwise copy $B[i]$ and advance $i$.

The last branch is the tie rule. It fires when $B[i] \le B[j]$. The left run is preferred on equal keys.

**Merge invariant.** At the start of an output step, the cells already written form a nondecreasing sequence, and if both runs still have elements then every written key is less than or equal to both $B[i]$ and $B[j]$. Each step appends the smaller exposed head, or the left head when the heads are equal, so the written sequence stays nondecreasing and the new key is still at most both new heads. When one run empties, the other run is sorted and all of its keys are at least as large as what has been written, because every one of them lost a comparison to a key that was written, or sits behind a head that lost such a comparison. The output is sorted.

**Comparisons.** Each comparison writes one element into the output. The last remaining element, if one run empties first, is copied with no comparison. A merge of $m$ elements therefore performs at most $m-1$ key comparisons. It may perform fewer. Merging $[1,2]$ with $[3,4]$ compares $1$ with $3$ and $2$ with $3$, then copies $[3,4]$ with no further comparison: two comparisons, and $m-1 = 3$.

**Trace.** Merge $[(2,b),(5,L),(7,c),(9,d)]$ with $[(1,e),(5,R),(6,g),(8,h)]$. The two keys equal to $5$ carry different ids so the tie rule is visible. The laboratory asserts the id sequence and the comparison count $7$.

| step | comparison | written |
| --- | --- | --- |
| 1 | $2$ against $1$ | $(1,e)$ |
| 2 | $2$ against $5R$ | $(2,b)$ |
| 3 | $5L$ against $5R$, equal, take the left run | $(5,L)$ |
| 4 | $7$ against $5R$ | $(5,R)$ |
| 5 | $7$ against $6$ | $(6,g)$ |
| 6 | $7$ against $8$ | $(7,c)$ |
| 7 | $9$ against $8$ | $(8,h)$ |
| 8 | right run empty, copy | $(9,d)$ |

Output: $[(1,e),(2,b),(5,L),(5,R),(6,g),(7,c),(8,h),(9,d)]$. Seven comparisons, which is $m-1$ for $m = 8$. The left-hand $5$ stands before the right-hand $5$.

### 5.3 Stability of merge, then of mergesort

**Lemma.** Suppose $L$ and $R$ are sorted, every original index represented in $L$ is smaller than every original index represented in $R$, and each of $L$ and $R$ is already stable with respect to the original indices inside it. The merge that prefers $L$ on equal keys returns a sorted array that is stable with respect to the original indices.

**Proof.** Section 5.2 already shows that the output is sorted. For stability, take two records $x$ and $y$ of equal key whose original indices satisfy $\mathrm{index}(x) < \mathrm{index}(y)$.

If both records lie in $L$, their order in $L$ is the original order, by the hypothesis on $L$. Merge consumes $L$ from left to right, so it writes them in that same order. The case where both lie in $R$ is the same.

They cannot satisfy $\mathrm{index}(x) < \mathrm{index}(y)$ with $x$ in $R$ and $y$ in $L$, because every index in $L$ is smaller than every index in $R$. The remaining case is $x$ in $L$ and $y$ in $R$. Inside a sorted run, equal keys occupy a contiguous segment. Whenever the two exposed heads are equal, the tie rule writes the head of $L$. So the entire remaining equal segment of $L$ is written before any record of that key is written from $R$. In particular $x$ is written before $y$.

**Theorem.** Top-down mergesort is stable.

**Proof.** Induction on the length $n$ of the subarray. If $n \le 1$, there is no pair to reorder. If $n \ge 2$, the subarray is split at an index so that the left piece occupies the smaller indices and the right piece occupies the larger indices. Each piece is shorter than $n$. By the inductive hypothesis each piece is stably sorted. The lemma applies to the merge. The whole subarray is stably sorted.

The split used in the program is $\mathrm{mid} = \ell + \lfloor (r-\ell)/2 \rfloor$, the left piece is $\ell..\mathrm{mid}$, and the right piece is $\mathrm{mid}+1..r$. Every left index is smaller than every right index. The hypothesis of the lemma holds at every merge.

**Worked stability trace.** Mergesort of $[(3,a),(1,b),(3,c),(2,d)]$.

```text
[(3,a), (1,b), (3,c), (2,d)]
        /                          \
[(3,a), (1,b)]                [(3,c), (2,d)]
   /        \                    /        \
(3,a)     (1,b)              (3,c)      (2,d)
   \        /                    \        /
[(1,b), (3,a)]                [(2,d), (3,c)]
        \                          /
        [(1,b), (2,d), (3,a), (3,c)]
```

The final merge compares $(3,a)$ with $(3,c)$ and takes the left record. The ids are $b, d, a, c$. The two keys equal to $3$ kept the original order $a$ then $c$. The laboratory asserts that id sequence. Reversing the tie rule, and taking the right run on equals, would emit $c$ before $a$ at that one comparison. The whole algorithm would then be unstable, and the inductive proof would fail at the cross-run case.

### 5.4 The recurrence, the Master Theorem, and the tree

Let $T(n)$ be the worst-case comparison count, or equivalently the worst-case running time, of top-down mergesort. Splitting is $\Theta(1)$. The two recursive calls receive $\lfloor n/2 \rfloor$ and $\lceil n/2 \rceil$ elements. The merge is $\Theta(n)$. For powers of two the recurrence is exactly the form Lecture 01 solves:

$$
T(n) = 2T(n/2) + \Theta(n), \qquad T(1) = \Theta(1).
$$

Here $a = 2$, $b = 2$, and $\log_b a = 1$. The merge cost $f(n) = \Theta(n)$ equals $\Theta(n^{\log_b a})$. Case 2 of the Master Theorem from Lecture 01 yields

$$
T(n) = \Theta(n \log n).
$$

The same conclusion is visible in the recursion tree when $n = 2^m$. Write the non-recursive cost at a node of size $m$ as $cm$ for the upper bound and as $c'm$ for the lower bound, with $c \ge c' > 0$, which is what $\Theta(n)$ at the root means after it is scaled down the tree.

```text
level 0:                 size 8          cost at most 8c
level 1:            size 4     size 4    cost at most 8c
level 2:         size 2  size 2  size 2  size 2
                         cost at most 8c
leaves:          eight calls on one element, cost at most 8d
```

There are $\log_2 n$ levels of merging (level $0$ through level $\log_2 n - 1$), and each of those levels costs at most $cn$ and at least $c'n$. The leaves contribute $\Theta(n)$. Therefore

$$
c' n \log_2 n + \Theta(n) \le T(n) \le c n \log_2 n + \Theta(n).
$$

For $n \ge 2$ the linear term is at most a constant times $n \log_2 n$, so $T(n) = \Theta(n \log n)$.

The recurrence with floors, $T(n) = T(\lfloor n/2 \rfloor) + T(\lceil n/2 \rceil) + \Theta(n)$, is the one the program actually runs. The extension from exact powers of two to every positive integer is part of the Master Theorem in Lecture 01. The tree above is the direct check on the infinite family $n = 2^m$, which is enough to see both the upper bound and the matching lower bound.

**Substitution, as a second look at the upper bound.** Guess $T(n) \le kn \log_2 n$ for $n \ge 2$, and set $T(1) = d$. For $n = 2^m \ge 2$,

$$
T(n) \le 2 \cdot k \cdot \frac{n}{2} \cdot \log_2(n/2) + cn = kn(\log_2 n - 1) + cn = kn\log_2 n - kn + cn.
$$

The guess closes when $k \ge c$. The base $n = 2$ is $T(2) \le 2d + 2c$, while $k \cdot 2 \cdot \log_2 2 = 2k$. Choosing $k \ge c + d$ covers the base and the inductive step. This is an upper bound. The tree already supplied the matching $\Omega(n \log n)$ side.

### 5.5 Memory

The auxiliary buffer has length $n$ and is allocated once. Every merge of a subarray uses the slice of that buffer with the same indices. Element memory beyond the input is $\Theta(n)$. The recursion depth is $\lfloor \log_2 n \rfloor$ splits until a subarray of length $1$, so the stack is $\Theta(\log n)$ frames. Total extra memory is $\Theta(n)$.

Mergesort is stable, its worst-case time is $\Theta(n \log n)$, and it pays a linear buffer for that guarantee. That trade is the one the decision table in Section 12 records.

### 5.6 Top-down procedure

```text
mergeSort(A):
    if A.length = 0: return
    let B be an array of length n
    sortRange(A, 0, n - 1, B)

sortRange(A, lo, hi, B):
    if lo >= hi: return
    mid = lo + floor((hi - lo) / 2)
    sortRange(A, lo, mid, B)
    sortRange(A, mid + 1, hi, B)
    merge(A, lo, mid, hi, B)

merge(A, lo, mid, hi, B):
    copy A[lo..hi] into B[lo..hi]
    i = lo
    j = mid + 1
    for k from lo to hi:
        if i > mid:        A[k] = B[j]; j = j + 1
        else if j > hi:    A[k] = B[i]; i = i + 1
        else if B[j] < B[i]: A[k] = B[j]; j = j + 1
        else:              A[k] = B[i]; i = i + 1
```

The last branch implements the left-preferring tie rule. The JavaScript in the laboratory is this procedure, plus a comparison counter on the branch that reads two keys.

---

## 6. Quicksort

### 6.1 The idea

Quicksort chooses a **pivot**, rearranges the subarray so that the pivot stands at some index $q$, every element to the left of $q$ is less than or equal to the pivot, and every element to the right of $q$ is strictly greater than the pivot. It then sorts the two sides. No merge step follows, because the rearrangement has already put every left element on the correct side of every right element.

The cost follows the balance of $q$. A pivot near the middle produces the mergesort shape, $\Theta(n \log n)$. A pivot at an end produces the recurrence $T(n) = T(n-1) + \Theta(n)$, which is $\Theta(n^2)$. The rest of this section specifies one partition, proves it, traces it, then separates the worst case from the expected case under a random pivot.

### 6.2 Lomuto partition, specified

On the subarray $A[p..r]$ the pivot is the element originally at index $r$, or the element that a caller has just swapped into index $r$. Let $x$ be that element's key. The index $i$ marks the end of the region of keys less than or equal to $x$. It starts at $p-1$, so that the region is empty.

```text
lomutoPartition(A, p, r):
    x = key of A[r]
    i = p - 1
    for j from p to r - 1:
        if key of A[j] <= x:
            i = i + 1
            swap A[i] with A[j]
    swap A[i + 1] with A[r]
    return i + 1
```

**Invariant.** At the start of the loop body for a given $j$:

- if $p \le k \le i$, then the key of $A[k]$ is $\le x$
- if $i+1 \le k \le j-1$, then the key of $A[k]$ is $> x$
- the key of $A[r]$ is $x$

```text
p            i       j           r
[ <= x      | > x   | unseen    | x ]
```

Initialization: $i = p-1$ and $j = p$, so both closed regions are empty, and $A[r]$ holds the pivot. The invariant holds.

Maintenance: if the key of $A[j]$ is $> x$, then $j$ advances and the strict region grows by one cell. If the key of $A[j]$ is $\le x$, then $i$ advances, and the swap places that key at the new end of the $\le$ region. The element moved from $i$ to $j$ was either $A[j]$ itself or an element of the strict region, which remains inside the strict region after $j$ advances. In both branches the invariant holds for $j+1$.

Termination: $j = r$. Then $A[p..i]$ is $\le x$ and $A[i+1..r-1]$ is $> x$, with the pivot still at $r$. The final swap exchanges $A[i+1]$ with $A[r]$. The returned index $q = i+1$ satisfies:

- every key in $A[p..q-1]$ is $\le$ the key of $A[q]$
- $A[q]$ is the original pivot element
- every key in $A[q+1..r]$ is $>$ the key of $A[q]$

```text
p          q            r
[ <= pivot | pivot | > pivot ]
```

Equal keys travel into the left region, because the test is $\le$. The right region contains no key equal to the pivot. One consequence is proved in Section 6.5: an array whose keys are all equal always returns $q = r$.

The loop performs exactly $r-p$ key comparisons. On a subarray of $m$ elements that number is $m-1$.

**Full trace.** Partition $[2, 8, 7, 1, 3, 5, 6, 4]$. The pivot key is $4$, $p = 0$, $r = 7$, $i$ starts at $-1$. The laboratory asserts the returned index and the final array.

| $j$ | key | action | array | $i$ |
| --- | --- | --- | --- | --- |
| 0 | $2$ | $2 \le 4$, swap index $0$ with itself | $[2, 8, 7, 1, 3, 5, 6, 4]$ | $0$ |
| 1 | $8$ | $8 > 4$, skip | $[2, 8, 7, 1, 3, 5, 6, 4]$ | $0$ |
| 2 | $7$ | $7 > 4$, skip | $[2, 8, 7, 1, 3, 5, 6, 4]$ | $0$ |
| 3 | $1$ | $1 \le 4$, swap indices $1$ and $3$ | $[2, 1, 7, 8, 3, 5, 6, 4]$ | $1$ |
| 4 | $3$ | $3 \le 4$, swap indices $2$ and $4$ | $[2, 1, 3, 8, 7, 5, 6, 4]$ | $2$ |
| 5 | $5$ | $5 > 4$, skip | $[2, 1, 3, 8, 7, 5, 6, 4]$ | $2$ |
| 6 | $6$ | $6 > 4$, skip | $[2, 1, 3, 8, 7, 5, 6, 4]$ | $2$ |
| final | | swap indices $3$ and $7$ | $[2, 1, 3, 4, 7, 5, 6, 8]$ | return $3$ |

To the left of index $3$: $2, 1, 3$, all $\le 4$. To the right: $7, 5, 6, 8$, all $> 4$.

### 6.3 Correctness and the procedure

**Theorem.** Quicksort with Lomuto partition sorts its input.

**Proof.** Induction on the subarray length $m = r-p+1$. If $m \le 1$ the procedure returns. If $m \ge 2$, partition returns an index $q$ with $p \le q \le r$, the two recursive calls receive strictly shorter subarrays, and the inductive hypothesis sorts each side. Every key on the left is $\le A[q]$ and every key on the right is $> A[q]$, so the concatenation of a sorted left side, the pivot, and a sorted right side is sorted.

```text
quickSort(A, p, r, choosePivot):
    if p >= r: return
    swap A[choosePivot(p, r)] with A[r]
    q = lomutoPartition(A, p, r)
    quickSort(A, p, q - 1, choosePivot)
    quickSort(A, q + 1, r, choosePivot)
```

When the pivot is always the last element, $\mathrm{choosePivot}(p, r) = r$ and the swap does nothing. Randomized quicksort uses a pivot index drawn uniformly from $p, p+1, \ldots, r$ and swaps that element into $A[r]$ before Lomuto runs. The partition specification is unchanged. Only the choice of which element occupies $A[r]$ changes.

### 6.4 Worst case

Suppose the pivot's final index is always an endpoint of the current subarray. Lomuto on an already sorted array does this: the last element is a maximum, every key is $\le x$, $i$ advances on every $j$, and $q = r$. The left call receives $n-1$ elements and the right call receives none. A reverse-sorted array sends the minimum to the front and leaves a right subarray of length $n-1$. An array of equal keys does the same as the sorted case, for every choice of pivot index, because every key compares $\le x$ and $q$ is always the right end.

Each partition of $m$ elements costs $m-1$ comparisons. Along the spine of sizes $n, n-1, \ldots, 2$ the total is

$$
(n-1) + (n-2) + \cdots + 1 = \frac{n(n-1)}{2}.
$$

The recurrence for the running time is

$$
T(n) = T(n-1) + \Theta(n), \qquad T(1) = \Theta(1).
$$

Unfolding, $T(n) = \Theta(n) + \Theta(n-1) + \cdots + \Theta(1) = \Theta(n^2)$. The Master Theorem in its $T(n) = aT(n/b) + f(n)$ form does not apply to a subtraction inside the argument. Unfolding, which Lecture 01 uses on linear recurrences, is the right tool.

The laboratory runs this case on $[1, 2, \ldots, 8]$ with the pivot fixed at the last index. It asserts that the number of partitions is $7 = n-1$ and that the deepest call sits $n$ frames down, counting the original call as frame $1$ and counting the final call on a single cell. The stack depth of the plain two-call recursion is $\Theta(n)$ on this input.

### 6.5 Equal keys, and instability

**All keys equal.** As noted above, Lomuto returns $q = r$ whatever index was swapped into the pivot slot. Randomizing the index does not change the split. The running time is $\Theta(n^2)$ on an equal array. The expectation proof in the next subsection assumes distinct keys so that a random element has a random rank. A three-way partition that isolates the whole equal run is the usual repair. This lecture does not implement that partition. The implemented partition is Lomuto's.

**Unstable.** Quicksort is not stable. On $[(3,a),(1,b),(3,c),(2,d)]$ with the pivot always at the end, the first partition swaps as follows. Keys $3, 1, 3$ against pivot $2$: only $1$ is $\le 2$, so it is swapped to the front, and the pivot then swaps into index $1$, producing $[(1,b),(2,d),(3,c),(3,a)]$. The right subarray is $[(3,c),(3,a)]$. Its pivot is $(3,a)$, and $(3,c) \le (3,a)$ stays on the left of that tiny partition. The final ids are $b, d, c, a$. The record $c$ stands before the record $a$, which is the reverse of their original order. The laboratory asserts those ids. Mergesort on the same four records produces $b, d, a, c$.

### 6.6 Probability used in the expectation proof

The next proof needs three facts about expectation. They are stated here so the sorting argument can use them by name.

An **indicator random variable** $X$ takes only the values $0$ and $1$. Its expectation is $E[X] = \Pr(X = 1)$, because $E[X] = 0\cdot\Pr(X=0) + 1\cdot\Pr(X=1)$.

**Linearity.** For random variables $X$ and $Y$ with finite expectations, $E[X+Y] = E[X]+E[Y]$. The identity does not require independence. By induction it extends to any finite sum. Dependent indicators may therefore be added: the expectation of the sum is the sum of the probabilities, even when the events overlap in complicated ways.

**Integral bounds on the harmonic number.** Let $H_n = \sum_{m=1}^{n} 1/m$. Comparing the decreasing function $1/x$ with the steps of the sum gives, for $n \ge 1$,

$$
\ln(n+1) \le H_n \le 1 + \ln n.
$$

The right-hand inequality: $1 \le 1$, and $1/2 \le \int_1^2 (1/x)\,dx$, $1/3 \le \int_2^3 (1/x)\,dx$, and so on through $1/n \le \int_{n-1}^{n} (1/x)\,dx$, so $H_n \le 1 + \int_1^n (1/x)\,dx = 1 + \ln n$. The left-hand inequality: $1/1 \ge \int_1^2 (1/x)\,dx$, $1/2 \ge \int_2^3 (1/x)\,dx$, through $1/n \ge \int_n^{n+1} (1/x)\,dx$, so $H_n \ge \int_1^{n+1} (1/x)\,dx = \ln(n+1)$.

In this course $\log$ is base $2$ and $\ln$ is natural. The change of base $\ln n = \ln 2 \cdot \log_2 n$ is used when a bound written with $\ln$ is reported as $O(n \log n)$.

### 6.7 Expected comparisons of randomized quicksort

Assume the $n$ keys are distinct. Let $z_0 < z_1 < \cdots < z_{n-1}$ be those keys in sorted order. The subscripts here are ranks, starting at $0$. They are not array indices. Array indices elsewhere in the lecture remain $0$-based in the input array.

**Random priorities.** Draw an independent uniform priority in the continuous interval $(0,1)$ for each element. Let the pivot of any subarray be the element of highest priority in that subarray. Inside any fixed subarray the highest-priority element is equally likely to be any member, because the priorities are independent and identically distributed and the probability of a tie is zero. This is the same distribution as swapping a uniformly chosen index into the Lomuto pivot slot at every call.

**Lemma.** Fix ranks $i < j$. Randomized quicksort compares $z_i$ with $z_j$ if and only if the first pivot chosen from the rank interval $Z = \{z_i, z_{i+1}, \ldots, z_j\}$ is either $z_i$ or $z_j$. The pair is compared at most once.

**Proof.** Lomuto compares elements only against the current pivot. Two elements that are never a pivot-and-other pair are never compared. The keys of $Z$ are contiguous in rank order, so a pivot whose rank lies outside $Z$ is either smaller than every key of $Z$ or larger than every key of $Z$. All of $Z$ then moves to the same side of that pivot and remains inside one subarray.

Consider the first moment at which the chosen pivot lies in $Z$. The whole of $Z$ is still in that subarray, so the pivot, being the maximum priority of the subarray, has higher priority than every other member of $Z$. It is the maximum-priority element of $Z$. A non-maximum of $Z$ cannot be chosen while the maximum of $Z$ is still present. So the first pivot taken from $Z$ is exactly the maximum-priority element of $Z$.

If that element is strictly between $z_i$ and $z_j$ in rank, the two endpoints move to opposite sides and are never again in one subarray, so they are never compared. If that element is $z_i$, then $z_i$ is compared with every other element of the subarray, including $z_j$. The symmetric statement holds for $z_j$. After that comparison one of the two endpoints is the pivot and is removed from later subarrays, so the pair is not compared a second time.

The maximum-priority element of $Z$ is uniform on $Z$, which has $j-i+1$ elements. Therefore

$$
\Pr(z_i \text{ is compared with } z_j) = \frac{2}{j-i+1}.
$$

**Theorem.** On $n$ distinct keys, the expected number of key comparisons performed by randomized quicksort is $\Theta(n \log n)$.

**Proof.** Let $X_{ij}$ be the indicator that is $1$ when $z_i$ and $z_j$ are compared, for $0 \le i < j \le n-1$. Let $X = \sum_{i<j} X_{ij}$. Every comparison the algorithm performs is between some such pair, so $X$ is the comparison count. Linearity gives

$$
E[X] = \sum_{i=0}^{n-2} \sum_{j=i+1}^{n-1} \frac{2}{j-i+1},
$$

even though the indicators are dependent.

Group the pairs by $m = j-i+1$, the number of ranks in the closed interval from $i$ to $j$. Then $m$ runs from $2$ to $n$. For a fixed $m$ the admissible starts $i$ run from $0$ through $n-m$, so there are $n-m+1$ pairs, and each contributes $2/m$. Hence

$$
E[X] = \sum_{m=2}^{n} (n-m+1)\cdot\frac{2}{m} = 2\sum_{m=2}^{n}\left(\frac{n+1}{m} - 1\right).
$$

The sum has $n-1$ values of $m$, and $\sum_{m=2}^{n} 1/m = H_n - 1$, so

$$
E[X] = 2(n+1)(H_n - 1) - 2(n-1).
$$

Apply $H_n \le 1 + \ln n$. Then $H_n - 1 \le \ln n$ and

$$
E[X] \le 2(n+1)\ln n.
$$

For $n \ge 1$, $n+1 \le 2n$, and $\ln n = \ln 2 \cdot \log_2 n \le \log_2 n$, so $E[X] \le 4n\log_2 n$. This is the $O(n \log n)$ side.

For the matching lower bound, use $H_n \ge \ln(n+1)$. Then

$$
E[X] \ge 2(n+1)\bigl(\ln(n+1) - 1\bigr) - 2(n-1).
$$

Restrict to $n \ge 64$. Then $\ln(n+1) \ge \ln 65 > 4$, so $\ln(n+1) - 1 > \tfrac{1}{2}\ln(n+1)$, and

$$
E[X] \ge (n+1)\ln(n+1) - 2(n-1) \ge n\ln n - 2n = n\ln n\left(1 - \frac{2}{\ln n}\right).
$$

Also $\ln n > 4$, so $2/\ln n < 1/2$ and $E[X] \ge \tfrac{1}{2} n \ln n$. Since $\ln n = \ln 2 \cdot \log_2 n$ and $\ln 2 > 1/2$,

$$
E[X] \ge \tfrac{1}{4}\, n \log_2 n.
$$

Combined with the upper bound, $\tfrac{1}{4} n \log_2 n \le E[X] \le 4n\log_2 n$ for every $n \ge 64$. Therefore $E[X] = \Theta(n \log n)$.

The algebra from the probability $2/(j-i+1)$ through this $\Theta$ bound is complete. Cormen's Chapter 7 records the same indicator decomposition and the same harmonic expression; the book also expands the leading term as $2n\ln n - \Theta(n)$. The bounds above already give $\Theta(n \log n)$ and do not need that sharper expansion. The distinct-key hypothesis is necessary for the statement as proved: Section 6.5 showed that equal keys make Lomuto quadratic for every pivot sequence.

The running time has the same expectation, because each partition of $m$ elements does $\Theta(m)$ work besides the $m-1$ comparisons, and that work is proportional to the comparisons along the same recursion tree.

### 6.8 Recursion depth

**Worst-case stack depth.** Section 6.4 showed that the plain procedure, the one that makes two recursive calls, reaches $n$ frames on a sorted array of length $n$ when the pivot is the last cell. The stack depth is $\Theta(n)$. On that input a language runtime can run out of call stack long before the $\Theta(n^2)$ time becomes the practical problem. The laboratory asserts the depth on $n = 8$.

**Smaller side first.** The following organization keeps Lomuto and changes only the control flow. Iterate on the larger side. Recurse on the smaller side.

```text
quickSortBounded(A, p, r, choosePivot):
    while p < r:
        swap A[choosePivot(p, r)] with A[r]
        q = lomutoPartition(A, p, r)
        if q - p < r - q:
            quickSortBounded(A, p, q - 1, choosePivot)
            p = q + 1
        else:
            quickSortBounded(A, q + 1, r, choosePivot)
            r = q - 1
```

**Theorem.** The recursion depth of this organization is $O(\log n)$ on every input.

**Proof.** A recursive call receives the smaller side of a partition of some length $m$. That side has at most $\lfloor (m-1)/2 \rfloor \le m/2$ elements. Each nested call therefore receives at most half as many elements as the call that invoked it. After at most $\log_2 n$ nested calls the length drops to $1$ and the recursion returns. The `while` loop continues on the larger side in the same frame and adds no stack frame. The depth is $O(\log n)$ even when every split is as unbalanced as Lomuto allows. The running time on a sorted array remains $\Theta(n^2)$, because the partitions along the iterated side still cost $n-1, n-2, \ldots$ comparisons. The laboratory implements the plain two-call procedure, so the $\Theta(n)$ depth is observable. The bounded procedure is specified here and is part of the independent assignment.

**Expected depth of one path.** Under random pivots and distinct keys, call a pivot **good** when its rank inside the current subarray of length $m$ lies between $m/4$ and $3m/4$ inclusive. At least half of the ranks do, for $m \ge 2$, up to an off-by-one that a more pedantic bound replaces by probability at least $1/2$ for all large $m$. A good pivot leaves both sides of size at most $3m/4$.

Along a single root-to-leaf path, group the partitions into phases that end at a good pivot. The number of partitions in a phase is a geometric random variable with success probability at least $1/2$, so the expected number of frames charged to one phase is at most $2$. Each successful phase multiplies the subproblem size by at most $3/4$, so $O(\log n)$ phases reduce the size to a constant. The expected length of the path is $O(\log n)$.

This bounds one path. The stack depth at any moment of the plain recursion is the length of the current path. The expected maximum, over all paths in the tree, is also $O(\log n)$. Extending the one-path bound to the maximum is a further induction or union bound; Cormen's analysis of quicksort's expectation is the citation for that extension. The smaller-side organization already gives $O(\log n)$ stack on every input, which is the bound an implementation should use when stack overflow is the concern.

### 6.9 What the laboratory randomizes

The expectation proof assumes an ideal uniform pivot. The laboratory does not call `Math.random`, because a test must be reproducible. Two mechanisms are used.

- An injected chooser returns the last index, or some other index the test specifies. The Lomuto trace and the sorted-array depth use the last index.
- A linear congruential generator with a fixed seed produces each index. The update is $s \leftarrow (1664525\, s + 1013904223) \bmod 2^{32}$, and the index is $p + (s \bmod (r-p+1))$. When the span $r-p+1$ does not divide $2^{32}$, the residues are not perfectly uniform. That bias is a property of this generator. It is acceptable in a test because the seed is fixed and the test asserts the resulting pivot-index list. It is not a premise of the $\Theta(n \log n)$ proof.

On the array $[4, 1, 3, 2, 6, 5, 8, 7]$ with seed $1$, the pivot indices the generator returns are $4, 2, 0, 4, 6$, and the deepest frame is at depth $4$. The laboratory asserts that list, asserts that a second run with the same seed repeats it, and asserts that the array comes out sorted.

---

## 7. A note on Hoare partition

Hoare partition uses two indices that move inward. One index starts at the left of the subarray and walks right. The other starts at the right and walks left. Each stops on an element that belongs on the opposite side of the pivot value. Those two elements are swapped, and the walk continues until the indices cross. The crossing index is the boundary between a left region whose keys are at most the pivot value and a right region whose keys are at least the pivot value.

The pivot element itself is not guaranteed to sit at that boundary. A later recursive call may receive the pivot in either piece. The invariant a programmer checks after the call is a separation of values across a cut, which is a different statement from Lomuto's "index $q$ holds the pivot, the left is $\le$, and the right is $>$".

Hoare's scheme is a real partition, published with quicksort, and on many inputs it performs fewer swaps than Lomuto. It is not the partition this course implements, traces, or examines. Every worked quicksort and quickselect step in this lecture is Lomuto's, with the pivot at the last index of the subarray before the scan, and with $i$ marking the end of the $\le$ region.

---

## 8. The comparison lower bound

### 8.1 Decision trees

Fix a comparison sort and an input length $n$, and assume the $n$ keys are distinct. The algorithm's behavior on those inputs is a binary tree. Each internal node is a comparison of two positions. The two edges are the two outcomes. Each leaf is a completed execution: the algorithm has decided upon a permutation of the input positions.

The tree must have at least $n!$ leaves. There are $n!$ possible orderings of $n$ distinct keys. If two different orderings reached the same leaf, they would have produced the same sequence of outcomes and the algorithm would apply the same permutation of positions to both. One permutation of positions cannot place both orderings into sorted order. So each ordering needs its own leaf.

A binary tree of height $h$ has at most $2^h$ leaves, because each level at most doubles the set of nodes, and a leaf is reached by one root-to-leaf path of length at most $h$. The comparison tree therefore satisfies

$$
2^h \ge n!, \qquad h \ge \log_2(n!).
$$

The height $h$ is an integer, so $h \ge \lceil \log_2(n!) \rceil$. The height is the worst-case number of comparisons: some input follows a longest path. Every comparison sort on $n$ distinct keys uses at least $\lceil \log_2(n!) \rceil$ comparisons in the worst case.

The bound is a statement about the comparison model of Section 3.4. An algorithm that inspects a key by using it as an array index is outside the hypothesis.

**A numerical check for $n = 3$.** Then $3! = 6$. Since $2^2 = 4 < 6$ and $2^3 = 8 \ge 6$, the height is at least $3$. Insertion sort's worst-case count on $3$ elements is $3\cdot 2/2 = 3$. The bound is tight for $n = 3$. The shape of one particular algorithm's tree is not required for the counting argument. Any binary tree with $6$ leaves has height at least $3$.

### 8.2 An elementary lower bound on $\log_2(n!)$

**Theorem.** For every integer $n \ge 4$,

$$
\log_2(n!) \ge \frac{1}{8}\, n \log_2 n.
$$

Consequently every comparison sort has worst-case cost $\Omega(n \log n)$.

**Proof.** Among the $n$ factors of $n!$, the largest $\lfloor n/2 \rfloor$ factors are each at least $n/2$. There are $\lfloor n/2 \rfloor$ of them, and $\lfloor n/2 \rfloor \ge (n-1)/2$, so

$$
n! \ge \left(\frac{n}{2}\right)^{(n-1)/2}.
$$

Take $\log_2$ of both sides:

$$
\log_2(n!) \ge \frac{n-1}{2}\,\log_2\frac{n}{2} = \frac{n-1}{2}\,(\log_2 n - 1).
$$

For $n \ge 2$, $(n-1)/2 \ge n/4$. For $n \ge 4$, $\log_2 n \ge 2$, so $\log_2 n - 1 \ge \tfrac{1}{2}\log_2 n$. Therefore

$$
\log_2(n!) \ge \frac{n}{4}\cdot\frac{1}{2}\log_2 n = \frac{1}{8}\, n \log_2 n.
$$

The decision-tree height is at least $\log_2(n!)$, hence at least $(1/8)\, n \log_2 n$ for every $n \ge 4$. The worst-case comparison count is $\Omega(n \log n)$.

Mergesort's $\Theta(n \log n)$ worst case matches this bound. The bound is asymptotically tight for comparison sorts: there is a comparison sort whose worst case is $O(n \log n)$, so the $\Omega$ result cannot be improved to a faster-growing function that would still lower-bound every comparison sort. Heapsort, built in Lecture 10, is another comparison sort with worst-case cost $\Theta(n \log n)$. Its sift procedures are not part of this lecture. The existence of the bound is what the decision table needs.

### 8.3 Stirling's approximation, stated, and the algebra to $\Omega(n \log n)$

The elementary bound hides a small constant, $1/8$. A sharper description of $n!$ gives the same $\Omega$ conclusion with a constant that can be taken arbitrarily close to $1$ in the leading term, and it also gives the matching $O$ bound from the factorial itself.

**Theorem (stated).** Stirling's approximation implies

$$
\log_2(n!) = n \log_2 n - n \log_2 e + O(\log n).
$$

This lecture does not prove Stirling's approximation. The form $n! = \sqrt{2\pi n}\,(n/e)^n\,(1 + \Theta(1/n))$ is the one from which the logarithmic statement follows by taking $\log_2$. Cormen's treatment of the comparison lower bound invokes this estimate. The algebra below starts from the logarithmic statement and does not replace the missing proof of Stirling.

**Algebra.** The $O(\log n)$ term means that there exists a constant $c > 0$ such that, for all sufficiently large $n$,

$$
\log_2(n!) \ge n\log_2 n - n\log_2 e - c\log_2 n.
$$

Factor $n\log_2 n$:

$$
\log_2(n!) \ge n\log_2 n\left(1 - \frac{\log_2 e}{\log_2 n} - \frac{c}{n}\right).
$$

Now $\log_2 e < 3/2$. Choose $n$ large enough that $\log_2 n \ge 4$ and $c/n \le 1/10$. Then $\log_2 e / \log_2 n < (3/2)/4 < 2/5$, and the factor in parentheses is greater than $1 - 2/5 - 1/10 = 1/2$. Hence, for all sufficiently large $n$,

$$
\log_2(n!) \ge \frac{1}{2}\, n \log_2 n.
$$

That is again $\log_2(n!) = \Omega(n \log n)$, and therefore $h = \Omega(n \log n)$.

The same stated formula supplies the upper direction. There is a constant $c'$ such that $\log_2(n!) \le n\log_2 n - n\log_2 e + c'\log_2 n$. For large $n$ the terms $-n\log_2 e + c'\log_2 n$ are negative, so $\log_2(n!) \le n\log_2 n$. A direct proof of this upper bound, with no appeal to Stirling, is $n! \le n^n$, hence $\log_2(n!) \le n\log_2 n$ for every $n \ge 1$. Together with Section 8.2, $\log_2(n!) = \Theta(n \log n)$.

The $\Theta$ statement does not say $\log_2(n!) \ge n\log_2 n$. The inequality $n! \le n^n$ says the opposite for $n > 1$. The $\Omega$ notation permits a constant factor. Section 8.2's constant $1/8$ already works for every $n \ge 4$. The examination asks you to check a constant $1/2$ on one particular $n$ by arithmetic, and to explain why a failure of the constant $1$ is compatible with the theorem.

### 8.4 Average leaf depth

The worst-case bound is a statement about the longest path. Randomized quicksort was bounded directly by indicators, so this lecture does not need an average-case lower bound to finish that theorem. The following fact is recorded because it is the reason a comparison sort cannot escape $\Omega(n \log n)$ by being lucky on most inputs and slow on a few.

**Theorem.** In any binary tree with $L \ge 1$ leaves, in which every internal node has two children, the average depth of the leaves is at least $\log_2 L$.

**Proof.** Let $S(L)$ be the minimum, over such trees, of the sum of the leaf depths. Then $S(1) = 0$. For $L \ge 2$ the root has two subtrees, with $L_1$ and $L_2$ leaves, $L_1 \ge 1$, $L_2 \ge 1$, $L_1 + L_2 = L$. Each leaf is one deeper than it was in its subtree, so

$$
S(L) = L + \min_{L_1+L_2=L} \bigl(S(L_1) + S(L_2)\bigr).
$$

The inductive claim is $S(L) \ge L\log_2 L$. It holds for $L = 1$. Assuming it for every smaller positive integer,

$$
S(L) \ge L + \min\bigl(L_1\log_2 L_1 + L_2\log_2 L_2\bigr).
$$

It is enough to show $L_1\log_2 L_1 + L_2\log_2 L_2 \ge L\log_2 L - L$, that is

$$
L_1\log_2 L_1 + L_2\log_2 L_2 + L \ge L\log_2 L.
$$

Let $p = L_1/L$ and write the difference between the left side and $L\log_2 L$ as

$$
L\bigl(p\log_2 p + (1-p)\log_2(1-p) + 1\bigr).
$$

The binary entropy $H(p) = -p\log_2 p - (1-p)\log_2(1-p)$ has derivative $\log_2((1-p)/p)$, which is zero at $p = 1/2$, positive on $(0,1/2)$, and negative on $(1/2, 1)$. The maximum value is $H(1/2) = 1$. Therefore $p\log_2 p + (1-p)\log_2(1-p) \ge -1$, the expression in parentheses is at least $0$, and $S(L) \ge L\log_2 L$.

A comparison sort's tree has at least $n!$ leaves. On a uniform random permutation the number of comparisons is the depth of a uniform random leaf, whose expectation is at least $\log_2(n!)$, which is $\Omega(n \log n)$. Randomizing the algorithm and then averaging over inputs cannot produce a smaller average, because each fixing of the random choices is some comparison tree, and every such tree has average depth at least $\log_2(n!)$.

---

## 9. Counting sort

### 9.1 Why indexing escapes the tree

If every key is an integer in $\{0, 1, \ldots, k\}$, the key can be used as an index into an array of length $k+1$. One index operation learns more than one bit. The decision tree, whose branches are comparisons, is the wrong model. The cost will be $\Theta(n+k)$ in the RAM model, which is $o(n \log n)$ when $k$ grows slowly enough, for example when $k$ is a constant or when $k = O(n)$. There is no contradiction with Section 8, because counting sort is not a comparison sort.

The procedure below is the stable one. Stability is required by radix sort in the next section, and it is also the reason to process the input from right to left. A left-to-right placement into the same cumulative array would reverse equal keys.

### 9.2 The stable procedure

Input: an array $A[0..n-1]$ of integers, each in $0..k$, together with the integer $k$.

```text
countingSort(A, k):
    let C[0..k] be zero
    for i from 0 to n - 1:
        C[A[i]] = C[A[i]] + 1
    for x from 1 to k:
        C[x] = C[x] + C[x - 1]
    let B[0..n - 1] be a new array
    for i from n - 1 down to 0:
        B[C[A[i]] - 1] = A[i]
        C[A[i]] = C[A[i]] - 1
    copy B back into A
```

After the first loop, $C[x]$ is the number of keys equal to $x$. After the second loop, $C[x]$ is the number of keys less than or equal to $x$. That number is also the position, in $1$-based counting of the output, of the last slot that should receive a key equal to $x$. The placement loop converts it to a $0$-based index by subtracting $1$, writes the record, and decrements $C[x]$ so that the next record of key $x$ receives the slot immediately to the left.

**Why the right-to-left scan is stable.** The cumulative value $C[x]$ begins as the last output index reserved for $x$, plus one in the $1$-based reading. The rightmost input record of key $x$ is placed into that last slot. Each earlier record of key $x$ is placed one slot further left. Records of key $x$ therefore appear in the output in the order they appeared in the input. Records of different keys are placed into disjoint ranges of slots, and those ranges are in key order because $C[x]$ counts every key up through $x$. The output is sorted and stable.

**Time and memory.** The histogram is $\Theta(n)$. The cumulative scan is $\Theta(k)$. The placement is $\Theta(n)$. The total is $\Theta(n+k)$. The count array has length $k+1$ and the output array has length $n$, so auxiliary memory is $\Theta(n+k)$. When $k$ is enormous the allocation is the practical limit, even though the arithmetic is linear in $k$. A key outside $0..k$ is outside the hypothesis; the procedure is not defined on it.

### 9.3 Trace

Sort the records

$$
[(2,a),\ (5,b),\ (3,c),\ (0,d),\ (2,e),\ (3,f),\ (0,g),\ (3,h)]
$$

with $k = 5$. The laboratory asserts the final keys and the final ids.

Histogram $C$, as counts of each key:

$$
\begin{array}{c|cccccc}
x & 0 & 1 & 2 & 3 & 4 & 5 \\
\hline
C[x] & 2 & 0 & 2 & 3 & 0 & 1
\end{array}
$$

Cumulative $C$, as the number of keys less than or equal to $x$:

$$
\begin{array}{c|cccccc}
x & 0 & 1 & 2 & 3 & 4 & 5 \\
\hline
C[x] & 2 & 2 & 4 & 7 & 7 & 8
\end{array}
$$

Placement from the right. The table shows the id written and the index it receives. Underscores are empty slots.

| $i$ | record | $C[\mathrm{key}]$ before the write | output index | output ids |
| --- | --- | --- | --- | --- |
| 7 | $(3,h)$ | $7$ | $6$ | `_ _ _ _ _ _ h _` |
| 6 | $(0,g)$ | $2$ | $1$ | `_ g _ _ _ _ h _` |
| 5 | $(3,f)$ | $6$ | $5$ | `_ g _ _ _ f h _` |
| 4 | $(2,e)$ | $4$ | $3$ | `_ g _ e _ f h _` |
| 3 | $(0,d)$ | $1$ | $0$ | `d g _ e _ f h _` |
| 2 | $(3,c)$ | $5$ | $4$ | `d g _ e c f h _` |
| 1 | $(5,b)$ | $8$ | $7$ | `d g _ e c f h b` |
| 0 | $(2,a)$ | $3$ | $2$ | `d g a e c f h b` |

Output records: $(0,d),\ (0,g),\ (2,a),\ (2,e),\ (3,c),\ (3,f),\ (3,h),\ (5,b)$. Equal keys kept their original order: $d$ before $g$, $a$ before $e$, and $c$ before $f$ before $h$.

### 9.4 Relation to the lower bound

Counting sort's $\Theta(n+k)$ bound and the theorem "every comparison sort is $\Omega(n \log n)$" talk about different hypotheses. When $k = O(n)$, counting sort is $\Theta(n)$, which grows more slowly than $n \log n$. The algorithm is allowed to do that because a key is an address, not merely an argument to a comparison.

When $k$ is large the linear dependence on $k$ becomes the expensive term. If every key lies in $0..n^2$, then $k = n^2$ and counting sort is $\Theta(n^2)$, while mergesort is $\Theta(n \log n)$. Counting sort is the wrong algorithm on that domain even though it is correct. Radix sort, next, sorts a large integer range by several passes over small digits.

---

## 10. Radix sort

### 10.1 Least significant digit

Write each key as $w$ digits in base $b$, the leftmost digit being the most significant. **Least-significant-digit radix sort** sorts the array $w$ times. Pass $0$ sorts by digit $0$, the least significant digit. Pass $d$ sorts by digit $d$. Each pass is a stable sort on a digit that lies in $0..b-1$. This lecture uses stable counting sort for every pass. The digit is an integer in a known range, which is exactly counting sort's hypothesis, with $k = b-1$.

The reason for starting at the least significant digit is the inductive claim in the next subsection: after pass $d$, the array is sorted by the integer formed by digits $0$ through $d$. A stable pass on digit $d+1$ then orders the higher digit and, where that digit ties, leaves the already correct lower-digit order alone. A most-significant-digit procedure exists. It recurses on buckets and is not the algorithm specified here.

### 10.2 Correctness by induction

**Theorem.** After pass $d$ of least-significant-digit radix sort, for $d = 0, 1, \ldots, w-1$, the array is sorted by the integer value of the lowest $d+1$ digits. After pass $w-1$ the array is sorted by the entire key.

**Proof.** Induction on $d$.

Base, $d = 0$. Counting sort on digit $0$ sorts the array by that digit. The lowest one digit determines the order. The claim holds.

Inductive step. Assume that before pass $d$, the array is sorted by digits $0$ through $d-1$. Pass $d$ is a stable sort on digit $d$. Take any two keys $x$ and $y$, and write $x_d$ and $y_d$ for digit $d$.

If $x_d < y_d$, the pass places $x$ before $y$, and the lowest $d+1$ digits of $x$ form a smaller integer than those of $y$, because the highest of those digits decides the comparison.

If $x_d > y_d$, the pass places $y$ before $x$, which is the correct order on the lowest $d+1$ digits.

If $x_d = y_d$, stability preserves the relative order that $x$ and $y$ had before the pass. By the inductive hypothesis that order is exactly the order of their lowest $d$ digits. Those lowest $d$ digits decide the comparison of the lowest $d+1$ digits once digit $d$ is known to be equal.

In every case the pair stands in the correct order after the pass. After pass $w-1$ every digit has been included.

An unstable pass breaks the equal-digit case. The examination asks for a two-key example. The repair is the stability of counting sort, which Section 9 proved from the right-to-left placement.

### 10.3 A decimal trace

Sort $329,\ 457,\ 657,\ 839,\ 436,\ 720,\ 355$ in base $10$. Three digits suffice, so $w = 3$ and $b = 10$. Each pass is stable counting sort on one digit. The laboratory asserts the final array.

| pass | digit | array after the pass |
| --- | --- | --- |
| units | $0$ | $720,\ 355,\ 436,\ 457,\ 657,\ 329,\ 839$ |
| tens | $1$ | $720,\ 329,\ 436,\ 839,\ 355,\ 457,\ 657$ |
| hundreds | $2$ | $329,\ 355,\ 436,\ 457,\ 657,\ 720,\ 839$ |

Check one stability step. After the units pass, $457$ stands before $657$; both have units digit $7$, and $457$ occurred earlier in the input. The tens digits are $5$ and $5$. The tens pass must keep $457$ before $657$, and it does: they appear in that order inside the final tens group $355,\ 457,\ 657$. Another pair: $720$ and $329$ both have tens digit $2$, and $720$ stands first after the units pass, so the tens pass emits $720$ then $329$.

### 10.4 Cost, base $256$, and the comparison with mergesort

A digit in base $b$ is an integer in $0..b-1$. One stable counting pass costs $\Theta(n+b)$ time and uses $\Theta(n+b)$ auxiliary memory. The buffers are reused, so the memory does not grow with the number of passes. With $w$ passes the time is

$$
\Theta\bigl(w(n+b)\bigr).
$$

If every key is an integer in $0..U-1$, then $w = \lceil \log_b U \rceil$. Choosing the base is part of the algorithm. Two regimes matter.

**Fixed word size.** A $32$-bit key satisfies $0 \le \mathrm{key} < 2^{32}$. In base $256 = 2^8$ the width is $w = 4$, because $256^4 = 2^{32}$. Four counting passes cost $\Theta(n + 256) = \Theta(n)$. Mergesort costs $\Theta(n \log n)$. For large $n$ the radix sort performs fewer RAM operations. The keys $0..2^{32}-1$ are exact JavaScript integers, since $2^{32}-1 < 2^{53}$. The laboratory's base-$256$ test uses keys below $256$, so a single pass suffices; the four-pass bound is the bound for a full word.

**A base that grows with $n$.** If $U \le n^{c}$ for a fixed constant $c$ and the base is chosen to be $n$, then $w \le c$ and the time is $\Theta(c(n+n)) = \Theta(cn)$. For each fixed $c$ this is linear. It is asymptotically faster than mergesort. The hypothesis is that a digit in base $n$ still fits in a constant-time word. When that hypothesis is false, the model has changed and the $\Theta$ statement has to be rebuilt.

**When mergesort is the better bound.** Radix sort requires a digit decomposition. Arbitrary comparable records, with no digits, are outside its hypothesis; mergesort applies. Separately, a long digit string can lose on the arithmetic. If $w = n$ and $b$ is a constant, the radix bound is $\Theta(n(n+b)) = \Theta(n^2)$, while mergesort remains $\Theta(n \log n)$ in the comparison model. A comparison of two long keys is itself not $\Theta(1)$ if the comparison must read the whole key, so a careful comparison has to charge both algorithms for the length of the key. The safe summary is: radix sort wins when $w(n+b)$ is smaller than the real cost of the comparison sort you would otherwise run, which for machine-word integers and large $n$ is the radix side, and for a linear number of digits is not.

The same inductive proof shows why the per-digit sort has to be stable. Replacing counting sort by an unstable partition would leave the inductive step without the equal-digit case.

---

## 11. Order statistics

### 11.1 The selection problem

The element of **order** $k$ in an array of $n$ elements, for $0 \le k < n$, is the element that stands at index $k$ after the array is sorted into nondecreasing order. The value is well defined when keys repeat: it is the value stored at index $k$ of the sorted array. A selection algorithm must return a record whose key equals that value. It is not required to sort the rest of the array.

The **lower median** is the element of order $\lfloor (n-1)/2 \rfloor$. The **upper median** is the element of order $\lfloor n/2 \rfloor$. When $n$ is odd the two orders are the same index. The laboratory's median checks use the lower median.

The minimum is order $0$. The maximum is order $n-1$. Finding one order statistic by sorting costs $\Theta(n \log n)$ in the comparison model if the sort is mergesort. The procedures below do less work when only one order is required.

### 11.2 Minimum and maximum together

The minimum of $n$ elements can be found with $n-1$ comparisons: scan once and remember the smaller key. The bound is tight in the comparison model, because each comparison has one loser, and every element other than the minimum must lose at least once. Otherwise an element that never lost could still be smaller than the reported minimum. The maximum, by the symmetric argument, also requires $n-1$ comparisons.

Running the two scans independently costs $2n-2$ comparisons. Pairing cuts the leading term.

**Procedure.** If $n$ is odd, set both the minimum and the maximum to $A[0]$ and start at index $1$. If $n$ is even, compare $A[0]$ with $A[1]$, assign the smaller to the minimum and the larger to the maximum, and start at index $2$. Then, for each remaining pair $(A[j], A[j+1])$, compare the two elements with each other, compare the smaller with the current minimum, and compare the larger with the current maximum.

**Theorem.** The procedure uses at most $3\lfloor n/2 \rfloor$ key comparisons for every $n \ge 1$, and it returns the minimum and the maximum.

**Proof.** Correctness is the loop invariant that the remembered minimum is the minimum of the elements already read, and likewise for the maximum. Each new pair extends the set of elements already read by two, after the three comparisons.

The comparison count:

- When $n$ is odd there are $\lfloor n/2 \rfloor$ pairs and no initial comparison, so the total is $3\lfloor n/2 \rfloor$.
- When $n$ is even there is $1$ initial comparison and $n/2 - 1$ later pairs, so the total is $1 + 3(n/2 - 1) = 3n/2 - 2$.

For even $n$, $3\lfloor n/2 \rfloor = 3n/2$, which is $2$ more than $3n/2 - 2$. In both parities the procedure uses at most $3\lfloor n/2 \rfloor$ comparisons. The even case uses $3n/2 - 2$, which is equal to $\lceil 3n/2 \rceil - 2$. The odd case uses $3(n-1)/2$, which is also equal to $\lceil 3n/2 \rceil - 2$. So the exact count of this procedure, for $n \ge 2$, is $\lceil 3n/2 \rceil - 2$, and the bound asked for in the statement is the convenient closed form $3\lfloor n/2 \rfloor$ that sits weakly above it.

A matching lower bound of $\lceil 3n/2 \rceil - 2$ is true and is not proved in this lecture. It is an exercise in Cormen's Chapter 9. The algorithm above meets that number; the lecture treats the matching lower bound as stated, not as a proof we have written.

**Check on five elements.** $n = 5$ is odd, so the count is $3\lfloor 5/2 \rfloor = 6$. On $[3, 1, 4, 2, 5]$ the procedure sets the minimum and the maximum to $3$. The pair $(1,4)$ costs three comparisons and updates both remembered values to $1$ and $4$. The pair $(2,5)$ costs three comparisons and updates the maximum to $5$. Total $6$. The laboratory asserts this count, and asserts that four elements $[3, 1, 4, 2]$ take $3\cdot 4/2 - 2 = 4$ comparisons.

### 11.3 Randomized quickselect

**Reason.** After Lomuto partition the pivot stands at its final sorted index $q$. If $q$ is the order we want, return it. If the desired order is smaller, every element that could have that order lies in the left subarray, because the right subarray is strictly greater than $A[q]$. If the desired order is larger, it lies in the right subarray. One recursive call remains, not two.

```text
quickSelect(A, p, r, k, choosePivot):
    if p = r: return A[p]
    swap A[choosePivot(p, r)] with A[r]
    q = lomutoPartition(A, p, r)
    if k = q: return A[q]
    if k < q: return quickSelect(A, p, q - 1, k, choosePivot)
    return quickSelect(A, q + 1, r, k, choosePivot)
```

The index $k$ is absolute in the original array, and the invariant of a call is $p \le k \le r$. The precondition of the whole procedure is $0 \le k < n$.

**Correctness.** Induction on the subarray length. Length $1$ returns the only element, and $k = p$. On a longer subarray, Section 6.2 shows that $A[q]$ is the element of order $q$ in the current subarray, hence in the original array: at least the elements now on its left belong at or before $q$, and every element now on its right belongs after $q$. If $k = q$ the value is correct. If $k < q$ the desired element is inside $A[p..q-1]$, which is a strictly smaller instance containing index $k$. The right branch is symmetric.

**Worst case.** The same inputs that make quicksort quadratic make quickselect quadratic. With the pivot fixed at the end of a sorted array, each partition discards one element and the recurrence is $T(n) = T(n-1) + \Theta(n) = \Theta(n^2)$ when the search is driven toward the far end. Equal keys do the same, by Section 6.5.

**Trace, injected pivots.** Select order $2$ in $[4, 1, 3, 2, 6, 5]$, always using the last index as the pivot. The lower median of six elements is order $\lfloor 5/2 \rfloor = 2$, whose value in the sorted array $[1, 2, 3, 4, 5, 6]$ is $3$.

First partition, pivot $5$. The keys $4, 1, 3, 2$ are $\le 5$ and $6$ is not. Lomuto returns $q = 4$ and the array $[4, 1, 3, 2, 5, 6]$. Order $2 < 4$, so the call continues on indices $0..3$.

Second partition, pivot $2$, subarray $[4, 1, 3, 2]$. The key $4$ stays out of the $\le$ region, the key $1$ is swapped to the front, and the key $3$ stays out. The final swap places $2$ at index $1$: array $[1, 2, 3, 4, 5, 6]$, returned index $1$. Order $2 > 1$, so the call continues on indices $2..3$, the subarray $[3, 4]$.

Third partition, pivot $4$. The key $3$ is $\le 4$, so it occupies the $\le$ region and the pivot stays at index $3$. Order $2 < 3$, so the call continues on the single index $2$ and returns $3$.

The laboratory asserts that return value and the final array $[1, 2, 3, 4, 5, 6]$. Selection was not asked to sort the array. On this pivot sequence the array happens to end sorted. A different pivot sequence can return the correct order statistic from an array that is not fully sorted. The median-of-medians trace in Section 11.5 is an example.

**Expected time.** Assume distinct keys, and assume each pivot is uniform in the current subarray. Let $T(n)$ be the expected running time on a subarray of length $n$. The rank $q$ of the pivot is then uniform in $\{0, 1, \ldots, n-1\}$. Whatever order is being sought, the recursive call is on a subarray of length at most $\max(q,\ n-1-q)$, and the partition costs $\Theta(n)$. Therefore

$$
T(n) \le \frac{1}{n}\sum_{q=0}^{n-1} T\bigl(\max(q,\ n-1-q)\bigr) + \Theta(n),
$$

with $T(n) = \Theta(1)$ for $n$ below a fixed constant. Cormen's Chapter 9 solves this recurrence by substitution and obtains $T(n) = \Theta(n)$. That solution is cited, not reproduced.

**Proof sketch of the constant-fraction bound.** A pivot whose rank lies between $n/4$ and $3n/4$ leaves a recursive subproblem of size at most $3n/4$. At least half the ranks are in that middle range once $n$ is large enough for the range to be nonempty; call such a pivot good, and take the success probability to be at least $1/2$.

Charge a phase for the work done until a good pivot appears. Each attempt costs $O(n)$ even if earlier bad pivots have already shrunk the subarray, because the current length is at most $n$. The number of attempts is geometric with success probability at least $1/2$. For a positive integer-valued random variable $Y$, $E[Y] = \sum_{t \ge 0}\Pr(Y > t)$. If $\Pr(Y > t) \le (1/2)^t$, then $E[Y] \le \sum_{t \ge 0}(1/2)^t = 2$. The expected cost of a phase is $O(n)$. After the phase the remaining length is at most $3n/4$. Hence

$$
T(n) \le T(3n/4) + O(n).
$$

Unfolding, $T(n) = O(n)$. The sketch uses a uniform upper bound of $n$ on every attempt inside the phase, it uses distinct keys so that ranks are uniform, and it treats the probability $1/2$ as a large-$n$ statement. Those are the steps the Chapter 9 substitution avoids by working directly with the averaged recurrence. The $\Theta(n)$ conclusion of the sketch is the one to remember: a constant fraction of the subarray is discarded in expectation, so the costs form a geometric series.

The laboratory checks randomized quickselect with seed $2026$ on $[7, 2, 9, 4, 1, 8, 5, 3, 6]$. The lower median is order $4$, and the value is $5$. Every other order is checked against insertion sort on the same array.

### 11.4 Median of medians

Randomized quickselect is linear in expectation and quadratic in the worst case. The **median of medians** algorithm forces a pivot that discards a constant fraction on every input of distinct keys, and the worst-case time becomes $\Theta(n)$.

**Procedure.** Select the element of order $k$ in the subarray $A[\ell..r]$, with $\ell \le k \le r$.

If the subarray has length at most $5$, insertion-sort it and return $A[k]$.

Otherwise let $g = \lceil m/5 \rceil$ where $m = r-\ell+1$. Insertion-sort each group of five consecutive elements. The last group holds $m \bmod 5$ elements when $5$ does not divide $m$, provided that remainder is nonzero; otherwise every group has five elements. The median of a group that occupies indices $[s, e]$ is the element now at index $s + \lfloor (e-s)/2 \rfloor$. For a full group of five, that index is $s+2$, the third element of the sorted group.

Swap those $g$ medians into $A[\ell..\ell+g-1]$. Recursively select the lower median of that region: the element of order $\ell + \lfloor (g-1)/2 \rfloor$ inside it. Let $x$ be the value returned. That recursive call may rearrange the median region. The value $x$ is still present somewhere in $A[\ell..r]$.

Swap one occurrence of $x$ to index $r$ and run Lomuto partition on $A[\ell..r]$. Let $q$ be the index Lomuto returns. If $k = q$, return $A[q]$. If $k < q$, recurse on $A[\ell..q-1]$. If $k > q$, recurse on $A[q+1..r]$.

**Correctness.** Induction on the subarray length, with the same invariant as quickselect: $\ell \le k \le r$, and the returned key equals the element of order $k$ in the whole array. The base case is insertion sort. Lomuto places $x$ at an index $q$ that is a correct sorted position for the value $x$, by the argument in Section 6.2, which does not require the keys to be distinct. Both recursive calls, when they happen, receive a strictly shorter subarray that still contains $k$. The recursive computation of $x$ itself is a selection on $g \le \lceil m/5 \rceil < m$ elements when $m > 5$, so it is a smaller instance. The algorithm terminates and returns the required order statistic on every input, including inputs with repeated keys. The laboratory tests repeated keys for that reason.

The linear-time theorem is narrower than the correctness theorem. It needs distinct keys, because the counting argument below talks about elements strictly larger than $x$.

**Trace.** Select order $4$ in $[4, 9, 1, 8, 3, 6, 2, 7, 5, 0]$. The sorted array is $[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]$, so the answer is $4$. The lower median of ten elements is order $\lfloor 9/2 \rfloor = 4$.

Group $[4, 9, 1, 8, 3]$ sorts to $[1, 3, 4, 8, 9]$. Its median is $4$, swapped to the front. The array is $[4, 3, 1, 8, 9, 6, 2, 7, 5, 0]$.

Group $[6, 2, 7, 5, 0]$ sorts to $[0, 2, 5, 6, 7]$. Its median is $5$ at index $7$, swapped into index $1$. The array is $[4, 5, 1, 8, 9, 0, 2, 3, 6, 7]$.

The median region is $[4, 5]$, whose lower median is order $0$ inside that region, the value $4$. Partition the whole array around $4$. One occurrence sits at index $0$; swapping it with the end produces $[7, 5, 1, 8, 9, 0, 2, 3, 6, 4]$. Lomuto then produces

$$
[1,\ 0,\ 2,\ 3,\ 4,\ 5,\ 7,\ 8,\ 6,\ 9]
$$

and returns $q = 4$. That equals the requested order, so the algorithm returns $4$. The cells to the left of index $4$ are not sorted. Selection stopped at the requested order. The laboratory asserts the return value on this array.

### 11.5 The $7n/10$ recurrence

**Proof sketch.** Assume the keys are distinct and $n$ is large. Let $g = \lceil n/5 \rceil$. At least half of the group medians are greater than or equal to the median-of-medians $x$. Each full group whose median is greater than $x$ contributes three elements greater than $x$: the median and the two elements above it. Two groups are set aside in the count: the group that contains $x$, and at most one incomplete final group. Cormen's Chapter 9 turns that counting into the inequality

$$
\bigl|\{\text{elements} > x\}\bigr| \ge 3\left(\left\lceil\frac{1}{2}\left\lceil\frac{n}{5}\right\rceil\right\rceil - 2\right) \ge \frac{3n}{10} - 6
$$

for $n$ large enough that the right-hand side is positive. The same count applies to elements less than $x$. The recursive selection on one side of $x$ therefore receives at most

$$
n - \left(\frac{3n}{10} - 6\right) = \frac{7n}{10} + 6
$$

elements. Finding $x$ is a recursive call on at most $\lceil n/5 \rceil$ elements. Sorting the groups is $\Theta(n)$, because each group has bounded length and there are $\Theta(n)$ of them. Partition is $\Theta(n)$. The worst-case time satisfies

$$
T(n) \le T\!\left(\left\lceil\frac{n}{5}\right\rceil\right) + T\!\left(\frac{7n}{10} + 6\right) + \Theta(n)
$$

for large $n$, and $T(n) = \Theta(1)$ when $n$ is below a fixed base. The base in the program is length $5$, which is legal for the algorithm. A substitution proof may take a larger constant base and fold every $n$ below that base into the choice of the leading constant.

Substitute the guess $T(m) \le cm$ for every $m < n$. For all $n$ large enough that $\lceil n/5 \rceil \le n/5 + 1$ and $7n/10 + 6 < n$,

$$
T(n) \le c\left(\frac{n}{5} + 1\right) + c\left(\frac{7n}{10} + 6\right) + dn = cn - c\left(\frac{n}{10} - 7\right) + dn.
$$

Choose $n_0 \ge 140$ and $c \ge 20d$. Then for $n \ge n_0$ one has $n/10 - 7 \ge n/20$ and $c(n/20) \ge dn$, so $T(n) \le cn$. For $n < n_0$ there are finitely many sizes. Increase $c$ until $T(n) \le cn$ holds for those sizes as well, which is possible because each of them has some finite cost. The guess holds for every $n$, and $T(n) = \Theta(n)$.

The algebra above is a sketch because the inequality $\ge 3n/10 - 6$ is cited from the group count in Cormen rather than expanded for every residue class of $n$ modulo $10$, and because the finite check for $n < n_0$ is an existence argument about $c$ rather than a table of values. The algorithm in the laboratory is the procedure of Section 11.4, and the tests check values, including duplicate keys. The $\Theta(n)$ worst-case claim is the distinct-key theorem. On an array of identical keys, Lomuto still discards only the single pivot at each step, and this implementation does not promise linear time on that input. It does return the correct value, which the tests check.

---

## 12. Choosing an algorithm

Name four facts before choosing: the length $n$, the domain of the keys, whether equal keys must keep their original order, and how much auxiliary memory is acceptable. The bounds below are the ones proved or stated in this lecture.

| Situation | Algorithm | Time | Stable | Auxiliary elements | Stack |
| --- | --- | --- | --- | --- | --- |
| General keys, $n$ large, stability required, a linear buffer allowed | mergesort | $\Theta(n \log n)$ worst case | yes | $\Theta(n)$ | $\Theta(\log n)$ |
| General keys, $n$ small or already nearly sorted, stability required | insertion sort | $\Theta(n^2)$ worst case, $\Theta(n)$ when $I = O(n)$ | yes | $\Theta(1)$ | $\Theta(1)$ |
| General distinct keys, stability not required, expected time acceptable | randomized quicksort | expected $\Theta(n \log n)$, worst $\Theta(n^2)$ | no | $\Theta(1)$ per frame | expected $O(\log n)$; $\Theta(n)$ worst case for the plain recursion |
| General keys, a worst-case $\Theta(n \log n)$ bound, only a constant amount of element memory | heapsort, Lecture 10 | $\Theta(n \log n)$ worst case | no | $\Theta(1)$ | the sift is iterative in the usual form |
| Integers in $0..k$ with $k = O(n)$, stability required | counting sort | $\Theta(n+k)$ | yes | $\Theta(n+k)$ | $\Theta(1)$ |
| Fixed-width integers, or $w$ digits in base $b$, stability required | LSD radix sort | $\Theta(w(n+b))$ | yes | $\Theta(n+b)$ | $\Theta(1)$ per counting pass |
| One order statistic, distinct general keys, expected time acceptable | randomized quickselect | expected $\Theta(n)$, worst $\Theta(n^2)$ | the output is one element | $\Theta(1)$ per frame | expected $O(\log n)$ along a path |
| One order statistic, distinct keys, worst-case linear time required | median of medians | $\Theta(n)$ worst case | the output is one element | $\Theta(1)$ per frame | $O(\log n)$ because each selection call shrinks by a constant fraction |

Two worked choices, of the kind the examination asks for.

**A million records with arbitrary comparable keys, stability required.** Counting sort and radix sort have no digit hypothesis to use. Quicksort does not keep equal keys in their original order. Insertion sort is stable and would perform on the order of $10^{12}$ comparisons in the worst case. Mergesort is $\Theta(n \log n)$, stable, and allocates a buffer of a million records. That is the match.

**Ten million integers in $0..100$, stability required.** Here $k = 100$ and $n = 10^7$. Counting sort is $\Theta(n+k)$, stable, and the count array is negligible beside the output array of length $n$. Radix sort would also be correct and stable, and it would perform several passes where one histogram already suffices. Mergesort would spend an extra $\log_2 n$ factor. Counting sort is the match.

Heapsort is the row to cite when the problem demands a worst-case $\Theta(n \log n)$ comparison sort and refuses a linear buffer. Say that the bound is $\Theta(n \log n)$, that the algorithm is built in Lecture 10, and stop. Inventing a sift procedure is not part of answering a question in this lecture.

---

## Laboratory

Work the traces in Sections 4, 5, 6, 9, 10, and 11 with the later rows covered, then uncover them. The numbers below are the ones the program checks.

1. Insertion sort on $[5, 2, 4, 6, 1, 3]$ ends at $[1, 2, 3, 4, 5, 6]$ after $12$ key comparisons.
2. Selection sort on $[5, 2, 4, 6, 1]$ performs $10$ comparisons.
3. The merge in Section 5.2 emits ids $e, b, L, R, g, c, h, d$ and performs $7$ comparisons. Mergesort of $[(3,a),(1,b),(3,c),(2,d)]$ emits ids $b, d, a, c$.
4. Lomuto partition of $[2, 8, 7, 1, 3, 5, 6, 4]$ returns index $3$ and the array $[2, 1, 3, 4, 7, 5, 6, 8]$.
5. Quicksort of those eight keys with the pivot fixed at the end finishes sorted. The same pivot rule on $[(3,a),(1,b),(3,c),(2,d)]$ finishes with ids $b, d, c, a$.
6. On the sorted array $[1, 2, \ldots, 8]$, plain quicksort with the last-index pivot performs $7$ partitions and reaches stack depth $8$.
7. Counting sort of the eight records in Section 9.3 ends with ids $d, g, a, e, c, f, h, b$.
8. Radix sort of $[329, 457, 657, 839, 436, 720, 355]$ in base $10$ ends at $[329, 355, 436, 457, 657, 720, 839]$.
9. Quickselect of order $2$ in $[4, 1, 3, 2, 6, 5]$, pivot fixed at the end, returns $3$. Quickselect of order $4$ in $[7, 2, 9, 4, 1, 8, 5, 3, 6]$ with seed $2026$ returns $5$.
10. Median-of-medians selection of order $4$ in $[4, 9, 1, 8, 3, 6, 2, 7, 5, 0]$ returns $4$.

### Problems to finish before you read the program

1. How many key comparisons does insertion sort use on $[9, 7, 8]$? Write the array after each outer iteration.
2. Selection-sort and insertion-sort the records $[(2,a),(2,b),(1,c)]$. Predict both id sequences.
3. Lomuto-partition $[5, 3, 5, 1]$. Give the returned index and the array.
4. How many key comparisons does selection sort use on $n = 10$ elements?
5. State which Master Theorem case applies to $T(n) = 2T(n/2) + \Theta(n)$, and the resulting bound.

Copy the program into a file and run it with `node`. Success prints `ALL TESTS PASSED` and nothing else. Then change one asserted array, confirm that the process throws, and restore the assertion. That is the check that the test is alive.

## LABORATORY PROGRAM

```javascript
"use strict";

import assert from "node:assert/strict";

// Integer keys used by counting sort and radix sort stay inside
// Number.MAX_SAFE_INTEGER. Digit powers base^place must stay exact.
// The seeded generator makes tests deterministic. Its modulo bias is
// not an assumption of the expected-time proofs.

class Record {
  constructor(key, id) {
    this.key = key;
    this.id = id;
  }
}

class SeededRng {
  constructor(seed) {
    this.state = seed >>> 0;
  }

  nextInt(lo, hi) {
    this.state = (Math.imul(1664525, this.state) + 1013904223) >>> 0;
    const span = hi - lo + 1;
    return lo + (this.state % span);
  }
}

function keyOf(value) {
  if (typeof value === "number") {
    return value;
  }
  return value.key;
}

function swap(a, i, j) {
  const tmp = a[i];
  a[i] = a[j];
  a[j] = tmp;
}

function copyOf(a) {
  return a.slice();
}

function selectionSort(a) {
  const n = a.length;
  let comparisons = 0;
  for (let i = 0; i < n - 1; i += 1) {
    let min = i;
    for (let j = i + 1; j < n; j += 1) {
      comparisons += 1;
      if (keyOf(a[j]) < keyOf(a[min])) {
        min = j;
      }
    }
    swap(a, i, min);
  }
  return comparisons;
}

function insertionSort(a) {
  const n = a.length;
  let comparisons = 0;
  for (let i = 1; i < n; i += 1) {
    const key = a[i];
    let j = i - 1;
    while (j >= 0) {
      comparisons += 1;
      if (keyOf(a[j]) > keyOf(key)) {
        a[j + 1] = a[j];
        j -= 1;
      } else {
        break;
      }
    }
    a[j + 1] = key;
  }
  return comparisons;
}

function insertionSortRange(a, lo, hi) {
  for (let i = lo + 1; i <= hi; i += 1) {
    const key = a[i];
    let j = i - 1;
    while (j >= lo && keyOf(a[j]) > keyOf(key)) {
      a[j + 1] = a[j];
      j -= 1;
    }
    a[j + 1] = key;
  }
}

function merge(a, lo, mid, hi, aux, counter) {
  for (let t = lo; t <= hi; t += 1) {
    aux[t] = a[t];
  }
  let i = lo;
  let j = mid + 1;
  for (let k = lo; k <= hi; k += 1) {
    if (i > mid) {
      a[k] = aux[j];
      j += 1;
    } else if (j > hi) {
      a[k] = aux[i];
      i += 1;
    } else {
      counter.comparisons += 1;
      if (keyOf(aux[j]) < keyOf(aux[i])) {
        a[k] = aux[j];
        j += 1;
      } else {
        a[k] = aux[i];
        i += 1;
      }
    }
  }
}

function mergeSort(a) {
  const aux = new Array(a.length);
  const counter = { comparisons: 0 };
  function rec(lo, hi) {
    if (lo >= hi) {
      return;
    }
    const mid = lo + Math.floor((hi - lo) / 2);
    rec(lo, mid);
    rec(mid + 1, hi);
    merge(a, lo, mid, hi, aux, counter);
  }
  if (a.length > 0) {
    rec(0, a.length - 1);
  }
  return counter.comparisons;
}

function mergeRuns(left, right) {
  const a = left.concat(right);
  const aux = new Array(a.length);
  const counter = { comparisons: 0 };
  const mid = left.length - 1;
  merge(a, 0, mid, a.length - 1, aux, counter);
  return { array: a, comparisons: counter.comparisons };
}

function lomutoPartition(a, p, r) {
  const pivot = keyOf(a[r]);
  let i = p - 1;
  for (let j = p; j < r; j += 1) {
    if (keyOf(a[j]) <= pivot) {
      i += 1;
      swap(a, i, j);
    }
  }
  swap(a, i + 1, r);
  return i + 1;
}

function quickSort(a, choosePivot, stats) {
  function rec(p, r, depth) {
    if (depth > stats.maxDepth) {
      stats.maxDepth = depth;
    }
    if (p >= r) {
      return;
    }
    const chosen = choosePivot(p, r);
    if (stats.pivots !== undefined) {
      stats.pivots.push(chosen);
    }
    swap(a, chosen, r);
    stats.partitions += 1;
    const q = lomutoPartition(a, p, r);
    rec(p, q - 1, depth + 1);
    rec(q + 1, r, depth + 1);
  }
  if (a.length > 0) {
    rec(0, a.length - 1, 1);
  }
}

function lastPivot(p, r) {
  return r;
}

function pivotChooser(rng) {
  return function choose(p, r) {
    return rng.nextInt(p, r);
  };
}

function countingSort(a, k) {
  const n = a.length;
  const count = new Array(k + 1);
  for (let x = 0; x <= k; x += 1) {
    count[x] = 0;
  }
  for (let i = 0; i < n; i += 1) {
    count[keyOf(a[i])] += 1;
  }
  for (let x = 1; x <= k; x += 1) {
    count[x] += count[x - 1];
  }
  const out = new Array(n);
  for (let i = n - 1; i >= 0; i -= 1) {
    const key = keyOf(a[i]);
    const pos = count[key] - 1;
    out[pos] = a[i];
    count[key] = pos;
  }
  for (let i = 0; i < n; i += 1) {
    a[i] = out[i];
  }
}

function countingSortByDigit(a, base, place) {
  const n = a.length;
  const count = new Array(base);
  for (let d = 0; d < base; d += 1) {
    count[d] = 0;
  }
  const digits = new Array(n);
  for (let i = 0; i < n; i += 1) {
    const digit = Math.floor(keyOf(a[i]) / place) % base;
    digits[i] = digit;
    count[digit] += 1;
  }
  for (let d = 1; d < base; d += 1) {
    count[d] += count[d - 1];
  }
  const out = new Array(n);
  for (let i = n - 1; i >= 0; i -= 1) {
    const digit = digits[i];
    const pos = count[digit] - 1;
    out[pos] = a[i];
    count[digit] = pos;
  }
  for (let i = 0; i < n; i += 1) {
    a[i] = out[i];
  }
}

function radixSort(a, base) {
  let maxKey = 0;
  for (let i = 0; i < a.length; i += 1) {
    const key = keyOf(a[i]);
    if (key > maxKey) {
      maxKey = key;
    }
  }
  for (let place = 1; Math.floor(maxKey / place) > 0; place *= base) {
    countingSortByDigit(a, base, place);
  }
}

function quickSelect(a, order, choosePivot) {
  function rec(p, r) {
    if (p === r) {
      return a[p];
    }
    swap(a, choosePivot(p, r), r);
    const q = lomutoPartition(a, p, r);
    if (order === q) {
      return a[q];
    }
    if (order < q) {
      return rec(p, q - 1);
    }
    return rec(q + 1, r);
  }
  return rec(0, a.length - 1);
}

function partitionAroundValue(a, lo, hi, pivotValue) {
  let found = lo;
  while (keyOf(a[found]) !== pivotValue) {
    found += 1;
  }
  swap(a, found, hi);
  return lomutoPartition(a, lo, hi);
}

function medianOfMedians(a, order) {
  function rec(lo, hi, k) {
    if (lo === hi) {
      return a[lo];
    }
    const n = hi - lo + 1;
    if (n <= 5) {
      insertionSortRange(a, lo, hi);
      return a[k];
    }
    const groups = Math.ceil(n / 5);
    for (let g = 0; g < groups; g += 1) {
      const start = lo + g * 5;
      const end = Math.min(start + 4, hi);
      insertionSortRange(a, start, end);
      const medianPos = start + Math.floor((end - start) / 2);
      swap(a, medianPos, lo + g);
    }
    const medianRank = lo + Math.floor((groups - 1) / 2);
    const pivotValue = rec(lo, lo + groups - 1, medianRank);
    const q = partitionAroundValue(a, lo, hi, pivotValue);
    if (k === q) {
      return a[q];
    }
    if (k < q) {
      return rec(lo, q - 1, k);
    }
    return rec(q + 1, hi, k);
  }
  return rec(0, a.length - 1, order);
}

function minAndMax(a) {
  const n = a.length;
  let comparisons = 0;
  let min;
  let max;
  let start;
  if (n % 2 === 1) {
    min = a[0];
    max = a[0];
    start = 1;
  } else {
    comparisons += 1;
    if (keyOf(a[0]) <= keyOf(a[1])) {
      min = a[0];
      max = a[1];
    } else {
      min = a[1];
      max = a[0];
    }
    start = 2;
  }
  for (let j = start; j < n; j += 2) {
    comparisons += 1;
    let lo;
    let hi;
    if (keyOf(a[j]) <= keyOf(a[j + 1])) {
      lo = a[j];
      hi = a[j + 1];
    } else {
      lo = a[j + 1];
      hi = a[j];
    }
    comparisons += 1;
    if (keyOf(lo) < keyOf(min)) {
      min = lo;
    }
    comparisons += 1;
    if (keyOf(hi) > keyOf(max)) {
      max = hi;
    }
  }
  return { min, max, comparisons };
}

function ids(a) {
  return a.map((item) => item.id);
}

function keysOf(a) {
  return a.map((item) => keyOf(item));
}

function freshStats(withPivots) {
  const stats = { maxDepth: 0, partitions: 0 };
  if (withPivots) {
    stats.pivots = [];
  }
  return stats;
}

{
  const a = [5, 2, 4, 6, 1, 3];
  assert.equal(insertionSort(a), 12);
  assert.deepEqual(a, [1, 2, 3, 4, 5, 6]);
}

{
  const a = [6, 5, 4, 3, 2, 1];
  assert.equal(insertionSort(a), 15);
  assert.deepEqual(a, [1, 2, 3, 4, 5, 6]);
}

{
  const a = [1, 2, 3, 4, 5, 6];
  assert.equal(insertionSort(a), 5);
}

{
  const empty = [];
  assert.equal(insertionSort(empty), 0);
  const one = [4];
  assert.equal(insertionSort(one), 0);
  const small = [3, 1, 2];
  assert.equal(insertionSort(small), 3);
  assert.deepEqual(small, [1, 2, 3]);
  const lab = [9, 7, 8];
  assert.equal(insertionSort(lab), 3);
  assert.deepEqual(lab, [7, 8, 9]);
}

{
  const a = [new Record(3, "a"), new Record(1, "b"), new Record(3, "c"), new Record(2, "d")];
  insertionSort(a);
  assert.deepEqual(ids(a), ["b", "d", "a", "c"]);
}

{
  const a = [new Record(2, "a"), new Record(2, "b"), new Record(1, "c")];
  insertionSort(a);
  assert.deepEqual(ids(a), ["c", "a", "b"]);
}

{
  const a = [5, 2, 4, 6, 1];
  assert.equal(selectionSort(a), 10);
  assert.deepEqual(a, [1, 2, 4, 5, 6]);
  const ten = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1];
  assert.equal(selectionSort(ten), 45);
  const pair = [new Record(2, "a"), new Record(2, "b"), new Record(1, "c")];
  selectionSort(pair);
  assert.deepEqual(ids(pair), ["c", "b", "a"]);
}

{
  const left = [new Record(2, "b"), new Record(5, "L"), new Record(7, "c"), new Record(9, "d")];
  const right = [new Record(1, "e"), new Record(5, "R"), new Record(6, "g"), new Record(8, "h")];
  const merged = mergeRuns(left, right);
  assert.deepEqual(keysOf(merged.array), [1, 2, 5, 5, 6, 7, 8, 9]);
  assert.deepEqual(ids(merged.array), ["e", "b", "L", "R", "g", "c", "h", "d"]);
  assert.equal(merged.comparisons, 7);
}

{
  const a = [new Record(3, "a"), new Record(1, "b"), new Record(3, "c"), new Record(2, "d")];
  mergeSort(a);
  assert.deepEqual(ids(a), ["b", "d", "a", "c"]);
  assert.deepEqual(keysOf(a), [1, 2, 3, 3]);
}

{
  const a = [2, 8, 7, 1, 3, 5, 6, 4];
  assert.equal(lomutoPartition(a, 0, 7), 3);
  assert.deepEqual(a, [2, 1, 3, 4, 7, 5, 6, 8]);
  const full = [2, 8, 7, 1, 3, 5, 6, 4];
  quickSort(full, lastPivot, freshStats(false));
  assert.deepEqual(full, [1, 2, 3, 4, 5, 6, 7, 8]);
}

{
  const tiny = [2, 2, 1];
  assert.equal(lomutoPartition(tiny, 0, 2), 0);
  assert.deepEqual(tiny, [1, 2, 2]);
  const ties = [5, 3, 5, 1];
  assert.equal(lomutoPartition(ties, 0, 3), 0);
  assert.deepEqual(ties, [1, 3, 5, 5]);
}

{
  const a = [new Record(3, "a"), new Record(1, "b"), new Record(3, "c"), new Record(2, "d")];
  quickSort(a, lastPivot, freshStats(false));
  assert.deepEqual(keysOf(a), [1, 2, 3, 3]);
  assert.deepEqual(ids(a), ["b", "d", "c", "a"]);
}

{
  const n = 8;
  const a = [];
  for (let i = 1; i <= n; i += 1) {
    a.push(i);
  }
  const stats = freshStats(false);
  quickSort(a, lastPivot, stats);
  assert.equal(stats.partitions, n - 1);
  assert.equal(stats.maxDepth, n);
  assert.deepEqual(a, [1, 2, 3, 4, 5, 6, 7, 8]);
  const equals = [2, 2, 2, 2];
  quickSort(equals, lastPivot, freshStats(false));
  assert.deepEqual(equals, [2, 2, 2, 2]);
}

{
  const source = [4, 1, 3, 2, 6, 5, 8, 7];
  const first = freshStats(true);
  const second = freshStats(true);
  const a1 = copyOf(source);
  const a2 = copyOf(source);
  quickSort(a1, pivotChooser(new SeededRng(1)), first);
  quickSort(a2, pivotChooser(new SeededRng(1)), second);
  assert.deepEqual(a1, [1, 2, 3, 4, 5, 6, 7, 8]);
  assert.deepEqual(first.pivots, [4, 2, 0, 4, 6]);
  assert.deepEqual(first.pivots, second.pivots);
  assert.equal(first.maxDepth, 4);
}

{
  const a = [
    new Record(2, "a"),
    new Record(5, "b"),
    new Record(3, "c"),
    new Record(0, "d"),
    new Record(2, "e"),
    new Record(3, "f"),
    new Record(0, "g"),
    new Record(3, "h"),
  ];
  countingSort(a, 5);
  assert.deepEqual(keysOf(a), [0, 0, 2, 2, 3, 3, 3, 5]);
  assert.deepEqual(ids(a), ["d", "g", "a", "e", "c", "f", "h", "b"]);
}

{
  const a = [329, 457, 657, 839, 436, 720, 355];
  radixSort(a, 10);
  assert.deepEqual(a, [329, 355, 436, 457, 657, 720, 839]);
  const stable = [new Record(12, "a"), new Record(11, "b"), new Record(21, "c"), new Record(12, "d")];
  radixSort(stable, 10);
  assert.deepEqual(keysOf(stable), [11, 12, 12, 21]);
  assert.deepEqual(ids(stable), ["b", "a", "d", "c"]);
  const zeros = [0, 0, 0];
  radixSort(zeros, 10);
  assert.deepEqual(zeros, [0, 0, 0]);
  const bytes = [];
  for (let i = 0; i < 50; i += 1) {
    bytes.push((i * 17) % 256);
  }
  const expect = copyOf(bytes);
  insertionSort(expect);
  radixSort(bytes, 256);
  assert.deepEqual(bytes, expect);
}

{
  const a = [4, 1, 3, 2, 6, 5];
  assert.equal(quickSelect(a, 2, lastPivot), 3);
  assert.deepEqual(a, [1, 2, 3, 4, 5, 6]);
}

{
  const source = [7, 2, 9, 4, 1, 8, 5, 3, 6];
  const sorted = copyOf(source);
  insertionSort(sorted);
  for (let rank = 0; rank < source.length; rank += 1) {
    const got = quickSelect(copyOf(source), rank, pivotChooser(new SeededRng(2026)));
    assert.equal(got, sorted[rank]);
  }
  assert.equal(quickSelect(copyOf(source), 4, pivotChooser(new SeededRng(2026))), 5);
}

{
  assert.equal(medianOfMedians([4, 9, 1, 8, 3, 6, 2, 7, 5, 0], 4), 4);
  const samples = [
    [1],
    [2, 1],
    [1, 1, 1],
    [5, 4, 3, 2, 1],
    [3, 1, 4, 1, 5, 9, 2, 6],
    [8, 3, 5, 1, 7, 2, 6, 4, 9, 0, 11, 10, 12, 13, 14],
    [4, 4, 4, 1, 4, 2, 4, 3, 4, 4],
  ];
  for (const sample of samples) {
    const sorted = copyOf(sample);
    insertionSort(sorted);
    for (let rank = 0; rank < sample.length; rank += 1) {
      assert.equal(medianOfMedians(copyOf(sample), rank), sorted[rank]);
    }
  }
  const big = [];
  for (let i = 0; i < 200; i += 1) {
    big.push((i * 37) % 200);
  }
  const bigSorted = copyOf(big);
  insertionSort(bigSorted);
  for (let rank = 0; rank < big.length; rank += 1) {
    assert.equal(medianOfMedians(copyOf(big), rank), bigSorted[rank]);
  }
  for (const rank of [0, 50, 99]) {
    const dups = new Array(100);
    for (let i = 0; i < 100; i += 1) {
      dups[i] = 5;
    }
    assert.equal(medianOfMedians(dups, rank), 5);
  }
}

{
  const odd = minAndMax([3, 1, 4, 2, 5]);
  assert.equal(keyOf(odd.min), 1);
  assert.equal(keyOf(odd.max), 5);
  assert.equal(odd.comparisons, 6);
  const even = minAndMax([3, 1, 4, 2]);
  assert.equal(keyOf(even.min), 1);
  assert.equal(keyOf(even.max), 4);
  assert.equal(even.comparisons, 4);
  const one = minAndMax([7]);
  assert.equal(one.comparisons, 0);
  assert.equal(one.min, 7);
}

console.log("ALL TESTS PASSED");
```

---

## Common mistakes

**Wrong idea.** Insertion sort stays stable if the inner test is $\ge$ rather than $>$.
**Correction.** The slide must stop when the exposed prefix key is equal to the new key. The test that continues the slide is strict greater-than. A non-strict test moves the new equal key to the left of the older one.

**Wrong idea.** Selection sort is stable because the scan uses a strict $<$ when it remembers the minimum index.
**Correction.** The strict scan keeps the leftmost minimum of the suffix. The swap that installs it at $i$ can still jump the record originally at $i$ over an equal record that sits between $i$ and the minimum. The pair $[(2,a),(2,b),(1,c)]$ ends as $[(1,c),(2,b),(2,a)]$.

**Wrong idea.** Mergesort is in-place because the recursive calls reuse the input array.
**Correction.** The merge writes into an auxiliary buffer of length $n$. Auxiliary element memory is $\Theta(n)$. The $\Theta(\log n)$ stack is additional.

**Wrong idea.** A merge is stable as long as both runs are sorted, regardless of which run is preferred on a tie.
**Correction.** The cross-run case of the stability proof requires the left run, which holds the earlier original indices, to be taken on an equal comparison. Preferring the right run emits the later record first.

**Wrong idea.** Lomuto's index $i$ starts at $p$, and the final swap exchanges $A[i]$ with the pivot.
**Correction.** The index $i$ starts at $p-1$ so that the $\le$ region is empty. The final swap exchanges $A[i+1]$ with $A[r]$, and the returned index is $i+1$.

**Wrong idea.** Randomized quicksort is $\Theta(n \log n)$ in the worst case.
**Correction.** The $\Theta(n \log n)$ bound is an expectation over the pivot choices, proved for distinct keys. A sorted array with the pivot fixed at the end is $\Theta(n^2)$. An array of equal keys is $\Theta(n^2)$ for every pivot sequence under Lomuto partition.

**Wrong idea.** The $\Omega(n \log n)$ theorem forbids every sorting algorithm from running in linear time.
**Correction.** The theorem's hypothesis is the comparison model. Counting sort uses a key as an index. Its $\Theta(n+k)$ bound lives in the RAM model. When $k = n^2$ that bound is worse than mergesort, which is a separate fact about the size of $k$.

**Wrong idea.** Any sort on the individual digits may be used inside radix sort.
**Correction.** The inductive step, when digit $d$ ties, preserves the order established by the lower digits only because the pass is stable. An unstable tens pass can reverse two keys that the units pass had already ordered, as in the examination.

**Wrong idea.** Quickselect's worst case is linear because one side of the partition is discarded.
**Correction.** Discarding a side helps only when the discarded side is a constant fraction of the array. A pivot at an endpoint discards one element. The expectation is linear for distinct keys and random pivots. The worst case of Lomuto quickselect is $\Theta(n^2)$. Median of medians is the algorithm whose worst case is linear on distinct keys.

**Wrong idea.** Writing $O(n \log n)$ for mergesort is the same statement as $\Theta(n \log n)$.
**Correction.** $O$ is an upper bound. Mergesort's comparison count is both $O(n \log n)$ and $\Omega(n \log n)$, which is the tight bound $\Theta(n \log n)$. The lower bound matters because Section 8 shows that every comparison sort is $\Omega(n \log n)$ in the worst case, so the tight bound says mergesort is optimal in that model.

---

## Examination

Closed notes. Ninety minutes. Definitions may be stated in your own sentences; the mathematical content must match the lecture. Show arithmetic.

### Question 1

Define a stable sort, the in-place convention of this lecture, and the comparison model. Three short definitions.

### Question 2

Give the exact worst-case number of key comparisons used by selection sort on $n$ elements, and the exact worst-case and best-case numbers used by insertion sort. Closed forms, not $\Theta$ notation.

### Question 3

Insertion-sort the records $[(4,a),\ (2,b),\ (5,c),\ (2,d),\ (1,e)]$, using the lecture's strict greater-than test. Show the array of ids after each outer iteration, give the total number of key comparisons, and state why the two records of key $2$ finished in that order.

### Question 4

Merge

$$
L = [(4,a),\ (4,b),\ (7,c),\ (9,d)]
$$

with

$$
R = [(3,e),\ (4,f),\ (8,g),\ (10,h)],
$$

preferring the left run when keys are equal. Show the output id after each record is written, and give the number of key comparisons.

### Question 5

Lomuto-partition $[6,\ 1,\ 7,\ 3,\ 8,\ 2,\ 5,\ 4]$, with the pivot at the last index. Show the array after every swap that changes it, and give the returned index. Then state, for the final array, which keys are $\le$ the pivot and which keys are $>$ the pivot.

### Question 6

Run stable counting sort on $[(2,a),\ (0,b),\ (2,c),\ (1,d),\ (0,e),\ (1,f)]$ with keys in $0..2$. Show the histogram, the cumulative array, and the output ids in order.

### Question 7

Let $n = 10$.

(a) Compute $10!$ by successive multiplication.

(b) Compute $2^{10}$, $2^{20}$, $2^{21}$, and $2^{22}$. Find integers that bound $\log_2(10!)$ by comparing $10!$ with those powers of two.

(c) Using $8 < 10 < 16$, bound $n\log_2 n = 10\log_2 10$ between two multiples of $10$.

(d) Show from your bounds that $\log_2(10!) > \tfrac{1}{2}\, n\log_2 n$ and that $\log_2(10!) < n\log_2 n$.

(e) Explain why $\log_2(10!) < n\log_2 n$ is compatible with the theorem $\log_2(n!) = \Omega(n\log n)$.

### Question 8

Choose an algorithm for each situation. Name the time bound, whether the algorithm is stable, and the auxiliary element memory. Use only procedures whose steps are in this lecture, except that you may name heapsort by its $\Theta(n \log n)$ bound and by Lecture 10 when a situation asks for it.

(a) $2\cdot 10^6$ records with arbitrary comparable keys, stability required, a linear buffer allowed.

(b) $5\cdot 10^7$ integers, each in $0..200$, stability required.

(c) $10^6$ distinct arbitrary comparable keys, stability not required, no auxiliary array of $\Theta(n)$ elements, expected time acceptable. Use an algorithm implemented in this lecture.

(d) The element of order $\lfloor (n-1)/2 \rfloor$ among $n = 10^7$ distinct arbitrary keys. Expected linear time is acceptable. The other elements need not be ordered.

(e) $10^7$ integers in a $32$-bit word, stability required, a linear buffer allowed, and a bound better than $\Theta(n \log n)$ for large $n$.

### Question 9

The pairing procedure of Section 11.2 is run on $n = 9$ elements.

(a) How many key comparisons does it perform? Derive the number from the odd case of the procedure.

(b) Evaluate $3\lfloor n/2 \rfloor$ and $\lceil 3n/2 \rceil - 2$ at $n = 9$, and say how the procedure's count sits relative to each expression.

### Question 10

(a) Lomuto-partition $[8,\ 3,\ 6,\ 1,\ 5,\ 9,\ 2,\ 7]$ with the last element as pivot. Give the returned index $q$ and the final array. Quickselect wants order $2$. Which subarray does the recursive call receive?

(b) When every Lomuto pivot on an $n$-element array finishes at an endpoint, the comparison count $C(n)$ satisfies $C(n) = C(n-1) + (n-1)$ and $C(1) = 0$. Solve the recurrence.

### Question 11

Least-significant-digit radix sort, base $10$, is applied to $[41,\ 23,\ 14,\ 32,\ 21]$.

(a) Show the array after the units pass and after the tens pass.

(b) Give two two-digit numbers that are in correct order after a stable units pass, and show an unstable rearrangement on the tens pass that destroys that order. State which sentence of the inductive proof has failed.

### Question 12

(a) Why does counting sort's $\Theta(n+k)$ bound not contradict the $\Omega(n \log n)$ comparison lower bound?

(b) Every key lies in $0..n^2$. State the counting-sort cost and compare it with mergesort.

---

## Answer key

### Question 1

A sort is stable when, for every pair of records with equal keys, the record that occurred earlier in the input occurs earlier in the output.

A procedure is in-place, in this lecture's convention, when every stack frame stores $\Theta(1)$ words and the procedure allocates no second array of elements. Stack depth is stated separately.

The comparison model allows the algorithm to learn the order of keys only by comparing two of them. Each comparison has two outcomes.

### Question 2

Selection sort always performs $n(n-1)/2$ key comparisons, so that is the worst-case count.

Insertion sort performs $n(n-1)/2$ key comparisons in the worst case, and $n-1$ key comparisons in the best case.

### Question 3

Start: ids $a\, b\, c\, d\, e$, keys $4, 2, 5, 2, 1$.

Iteration $i = 1$, key $(2,b)$. Compare with $(4,a)$: the slide succeeds, and $j$ falls off the left end. One comparison. Ids: $b\, a\, c\, d\, e$.

Iteration $i = 2$, key $(5,c)$. Compare with $(4,a)$: $4 > 5$ fails. One comparison. Ids unchanged: $b\, a\, c\, d\, e$.

Iteration $i = 3$, key $(2,d)$. Compare with $(5,c)$: slide. Compare with $(4,a)$: slide. Compare with $(2,b)$: $2 > 2$ fails, so the new record is written immediately to the right of $b$. Three comparisons. Ids: $b\, d\, a\, c\, e$.

Iteration $i = 4$, key $(1,e)$. The slide succeeds against $5$, $4$, $2$, and $2$, then $j$ falls off the left end. Four comparisons. Ids: $e\, b\, d\, a\, c$.

Total comparisons: $1+1+3+4 = 9$.

The record $b$ was already in the sorted prefix when $d$ was inserted. The inner test does not slide across an equal key, so $d$ is placed to the right of $b$. Later, inserting $e$ shifts both of them rightward as a block. The original order $b$ then $d$ remains.

### Question 4

| step | comparison | ids written so far |
| --- | --- | --- |
| 1 | $4a$ against $3e$, take $e$ | $e$ |
| 2 | $4a$ against $4f$, equal, take the left record $a$ | $e\, a$ |
| 3 | $4b$ against $4f$, equal, take $b$ | $e\, a\, b$ |
| 4 | $7c$ against $4f$, take $f$ | $e\, a\, b\, f$ |
| 5 | $7c$ against $8g$, take $c$ | $e\, a\, b\, f\, c$ |
| 6 | $9d$ against $8g$, take $g$ | $e\, a\, b\, f\, c\, g$ |
| 7 | $9d$ against $10h$, take $d$ | $e\, a\, b\, f\, c\, g\, d$ |
| 8 | left run empty, copy $h$ | $e\, a\, b\, f\, c\, g\, d\, h$ |

Seven key comparisons. The last record is copied after the right run's head has already been compared and the left run is empty, so it adds no eighth comparison. Final keys: $3, 4, 4, 4, 7, 8, 9, 10$, with the three fours in the order $a$, then $b$, then $f$.

### Question 5

Start: $[6, 1, 7, 3, 8, 2, 5, 4]$, pivot key $4$, $i = -1$.

- $j = 1$, key $1 \le 4$, $i = 0$, swap indices $0$ and $1$: $[1, 6, 7, 3, 8, 2, 5, 4]$.
- $j = 3$, key $3 \le 4$, $i = 1$, swap indices $1$ and $3$: $[1, 3, 7, 6, 8, 2, 5, 4]$.
- $j = 5$, key $2 \le 4$, $i = 2$, swap indices $2$ and $5$: $[1, 3, 2, 6, 8, 7, 5, 4]$.
- Final swap of indices $3$ and $7$: $[1, 3, 2, 4, 8, 7, 5, 6]$, return $q = 3$.

The skipped indices $j = 0, 2, 4, 6$ hold $6, 7, 8, 5$, all $> 4$, and do not change the array.

Keys $1, 3, 2$ are $\le 4$. Keys $8, 7, 5, 6$ are $> 4$.

### Question 6

Histogram of keys $0, 1, 2$: $C = [2, 2, 2]$.

Cumulative, the number of keys less than or equal to $x$: $C = [2, 4, 6]$.

Placement from the right:

- $(1,f)$ goes to index $4-1 = 3$, then $C[1] = 3$.
- $(0,e)$ goes to index $2-1 = 1$, then $C[0] = 1$.
- $(1,d)$ goes to index $3-1 = 2$, then $C[1] = 2$.
- $(2,c)$ goes to index $6-1 = 5$, then $C[2] = 5$.
- $(0,b)$ goes to index $1-1 = 0$, then $C[0] = 0$.
- $(2,a)$ goes to index $5-1 = 4$, then $C[2] = 4$.

Output ids: $b,\ e,\ d,\ f,\ a,\ c$. Keys: $0, 0, 1, 1, 2, 2$. The original order inside each key is preserved.

### Question 7

(a) $1\cdot 2 = 2$, $\cdot 3 = 6$, $\cdot 4 = 24$, $\cdot 5 = 120$, $\cdot 6 = 720$, $\cdot 7 = 5040$, $\cdot 8 = 40320$, $\cdot 9 = 362880$, $\cdot 10 = 3628800$. So $10! = 3{,}628{,}800$.

(b) $2^{10} = 1024$. Then $2^{20} = 1024^2$. Compute $(1000+24)^2 = 1000^2 + 2\cdot 1000\cdot 24 + 24^2 = 1{,}000{,}000 + 48{,}000 + 576 = 1{,}048{,}576$. Hence $2^{21} = 2{,}097{,}152$ and $2^{22} = 4{,}194{,}304$.

Now $3{,}628{,}800 - 2{,}097{,}152 = 1{,}531{,}648 > 0$, so $10! > 2^{21}$. And $4{,}194{,}304 - 3{,}628{,}800 = 565{,}504 > 0$, so $10! < 2^{22}$. Therefore

$$
21 < \log_2(10!) < 22.
$$

(c) Since $2^3 = 8 < 10 < 16 = 2^4$, one has $3 < \log_2 10 < 4$, and

$$
30 < 10\log_2 10 < 40.
$$

(d) Half of $n\log_2 n$ is $5\log_2 10$, so $15 < 5\log_2 10 < 20$. From (b), $\log_2(10!) > 21$. From the upper half of the bound on $5\log_2 10$, $21 > 20 > 5\log_2 10$. Therefore $\log_2(10!) > \tfrac{1}{2}\, n\log_2 n$.

From (b) and (c), $\log_2(10!) < 22$ and $22 < 30 < 10\log_2 10$, so $\log_2(10!) < n\log_2 n$.

(e) The statement $\log_2(n!) = \Omega(n\log n)$ says that some positive constant $c$ satisfies $\log_2(n!) \ge c\, n\log_2 n$ for every sufficiently large $n$. It does not require $c = 1$. Part (d) shows that $c = 1$ already fails at $n = 10$, which is the elementary comparison $n! < n^n$, and that $c = 1/2$ holds at $n = 10$. Both facts fit the definition.

### Question 8

(a) Mergesort. Time $\Theta(n \log n)$ in the worst case, stable, auxiliary element memory $\Theta(n)$. Arbitrary keys give counting sort and radix sort nothing to index. Quicksort is unstable. Insertion sort is stable and quadratic.

(b) Counting sort with $k = 200$. Time $\Theta(n+k)$, stable, auxiliary memory $\Theta(n+k)$. One histogram covers the stated range.

(c) Randomized quicksort. Expected time $\Theta(n \log n)$ on distinct keys, worst case $\Theta(n^2)$, not stable, no linear element buffer. Plain recursion has expected path depth $O(\log n)$ and worst-case depth $\Theta(n)$. The smaller-side organization from the lecture brings the worst-case stack to $O(\log n)$ and is still Lomuto quicksort.

(d) Randomized quickselect. Expected time $\Theta(n)$, worst case $\Theta(n^2)$, one returned element. The order requested is the lower median.

(e) Least-significant-digit radix sort in base $256$. A $32$-bit key has $w = 4$ digits, each pass is stable counting sort, the time is $\Theta(n)$, and the auxiliary memory is $\Theta(n+256)$. The sort is stable. Mergesort remains $\Theta(n \log n)$.

### Question 9

(a) For odd $n$ the procedure performs $3\lfloor n/2 \rfloor$ comparisons: there is no opening pair, and there are $\lfloor n/2 \rfloor$ pairs of three comparisons each. At $n = 9$, $\lfloor 9/2 \rfloor = 4$ and $3\cdot 4 = 12$.

(b) $3\lfloor 9/2 \rfloor = 12$. And $3\cdot 9/2 = 13.5$, so $\lceil 3n/2 \rceil - 2 = 14 - 2 = 12$. The procedure's count equals both expressions. The gap of $2$ between $3\lfloor n/2 \rfloor$ and $\lceil 3n/2 \rceil - 2$ appears only for even $n$.

### Question 10

(a) Pivot key $7$.

- Skip $8$.
- $3 \le 7$, swap into index $0$: $[3, 8, 6, 1, 5, 9, 2, 7]$.
- $6 \le 7$, swap into index $1$: $[3, 6, 8, 1, 5, 9, 2, 7]$.
- $1 \le 7$, swap into index $2$: $[3, 6, 1, 8, 5, 9, 2, 7]$.
- $5 \le 7$, swap into index $3$: $[3, 6, 1, 5, 8, 9, 2, 7]$.
- Skip $9$.
- $2 \le 7$, swap into index $4$: $[3, 6, 1, 5, 2, 9, 8, 7]$.
- Final swap of indices $5$ and $7$: $[3, 6, 1, 5, 2, 7, 8, 9]$, return $q = 5$.

Order $2 < 5$, so quickselect continues on indices $0..4$, the subarray $[3, 6, 1, 5, 2]$.

(b) Unfold:

$$
C(n) = (n-1) + (n-2) + \cdots + 1 + C(1) = \frac{n(n-1)}{2}.
$$

The comparison count is $n(n-1)/2$, which is $\Theta(n^2)$.

### Question 11

(a) Units digits are $1, 3, 4, 2, 1$. Stable counting sort emits the two keys with digit $1$ in their original order, $41$ then $21$, then digit $2$, then digit $3$, then digit $4$:

$$
[41,\ 21,\ 32,\ 23,\ 14].
$$

Tens digits of that array are $4, 2, 3, 2, 1$. Stable sort by that digit:

$$
[14,\ 21,\ 23,\ 32,\ 41].
$$

The pair $21, 23$ shares a tens digit. Their order after the units pass was $21$ then $23$, and the tens pass keeps it. The array is fully sorted.

(b) Take $31$ and $32$. A stable units pass on input $[32, 31]$ emits $[31, 32]$, because the units digits $2$ and $1$ differ and $1 < 2$. Both tens digits are $3$. An unstable tens pass may emit $[32, 31]$. The sorted order is $[31, 32]$, so the result is wrong.

The failed sentence is the equal-digit case of the inductive step: when digit $d$ ties, stability was supposed to preserve the order already established on the lower digits. An unstable pass does not preserve it.

### Question 12

(a) The $\Omega(n \log n)$ theorem applies to comparison sorts: algorithms whose only access to the order is a two-outcome comparison. Counting sort addresses an array by the key. That operation is outside the hypothesis, so a $\Theta(n+k)$ bound is compatible with the theorem.

(b) Here $k = n^2$, so counting sort costs $\Theta(n + n^2) = \Theta(n^2)$. Mergesort costs $\Theta(n \log n)$, which is asymptotically smaller. Counting sort remains correct and is the worse choice on this domain.

---

## Independent assignment

Produce two artifacts and keep both. Budget four to six hours.

**Artifact 1, a program.** Implement the smaller-side-first Lomuto quicksort from Section 6.8, and instrument four counters: key comparisons, Lomuto partitions, maximum stack depth of the plain two-call quicksort, and maximum stack depth of the smaller-side procedure. Use the seeded generator from the laboratory, or an injected pivot, so every run is reproducible. Do not call `Array.prototype.sort`.

Run three families of inputs at $n = 128,\ 256,\ 512,\ 1024,\ 2048$:

- distinct keys in an order produced by the seeded generator
- the sorted array $0, 1, \ldots, n-1$, with the pivot fixed as the last index
- the reverse-sorted array, with the same pivot rule

Also run stable counting sort and base-$256$ radix sort on the integer family whose keys lie in $0..n-1$, and record $\Theta$ quantities you can actually count: for counting sort, the number of loop iterations is enough if you count them; for radix sort, count the number of digit passes and the number of element moves.

**Artifact 2, a memo of about two pages.** Include a table of the measurements. Beside each comparison count, write the value of $n(n-1)/2$ and the value of $n\log_2 n$, computed for that $n$. Say which family tracks which expression, and why the sorted family tracks the quadratic expression under a last-index pivot. Report the two stack depths on the sorted family at $n = 2048$, and prove in your own words that the smaller side of a partition has length at most $\lfloor (m-1)/2 \rfloor$. End with one paragraph that states, for machine-word integers at these lengths, whether your radix counts or your mergesort-shaped quicksort counts are the smaller number, and which hypothesis of Section 10 that comparison uses.

The memo is the piece a later lecture can ask you to defend. The program is the piece you will rewrite from a blank file at the Lecture 07 checkpoint, together with mergesort.

---

## Glossary

**Auxiliary memory.** Memory beyond the input array. Element memory and stack depth are reported separately.

**Base.** The radix in which a key is decomposed into digits. A digit in base $b$ is an integer in $0..b-1$.

**Bubble sort.** The adjacent-swap procedure whose worst-case comparison count is $n(n-1)/2$. It is not implemented here.

**Comparison model.** The model in which the only information about order is a comparison of two keys, with two outcomes.

**Comparison sort.** A sorting algorithm whose decisions about order come only from the comparison model.

**Counting sort.** The stable sort of integers in $0..k$ that uses a histogram and a cumulative count, in $\Theta(n+k)$ time.

**Cumulative count.** After the prefix summation in counting sort, $C[x]$ is the number of keys less than or equal to $x$.

**Decision tree.** The binary tree of comparisons a comparison sort performs. Leaves correspond to distinct permutations when the keys are distinct.

**Digit.** One coefficient of a key written in a fixed base. Digit $0$ is the least significant digit.

**Expected running time.** The expectation of the running time over the algorithm's random choices, on a stated class of inputs. For randomized quicksort the class used in the theorem is the distinct-key inputs, and the expectation is over the pivots.

**Good pivot.** A pivot whose rank lies in the middle half of the current subarray, so both sides have length at most three quarters of that subarray.

**Harmonic number.** $H_n = \sum_{m=1}^{n} 1/m$.

**Heapsort.** A comparison sort of worst-case cost $\Theta(n \log n)$, built in Lecture 10. Its sift procedures are not defined in this lecture.

**Hoare partition.** A partition that walks one index inward from each end. It is not the implemented partition.

**Indicator random variable.** A random variable that takes only the values $0$ and $1$. Its expectation equals the probability that it equals $1$.

**Insertion sort.** The in-place stable sort that slides the next key into a sorted prefix. Worst-case comparisons $n(n-1)/2$, best-case comparisons $n-1$.

**In-place.** In this lecture: $\Theta(1)$ words per stack frame and no auxiliary array of elements.

**Inversion.** A pair of indices $i < j$ with $A[i] > A[j]$.

**Least-significant-digit radix sort.** Radix sort that stable-sorts digit $0$, then digit $1$, and so on through the most significant digit.

**Lomuto partition.** The partition in which the pivot occupies the last index, $i$ starts at $p-1$ and marks the end of the $\le$ region, and the returned index holds the pivot.

**Loop invariant.** A statement that holds at the start of every iteration and that, with the exit test, implies the procedure's postcondition.

**Lower median.** The element of order $\lfloor (n-1)/2 \rfloor$.

**Median of medians.** The selection algorithm that pivots on the median of the medians of groups of five. Worst-case time $\Theta(n)$ on distinct keys.

**Merge.** The procedure that combines two adjacent sorted runs into one sorted run, preferring the left run on equal keys.

**Mergesort.** Top-down divide-and-conquer sort that splits, sorts recursively, and merges. Worst-case time $\Theta(n \log n)$, stable, auxiliary element memory $\Theta(n)$.

**Order statistic.** The element of a stated order $k$, that is, the value that a nondecreasing sort would place at index $k$.

**Pivot.** The element Lomuto places at its final sorted index, used to separate the two sides of quicksort or quickselect.

**Quickselect.** Selection by Lomuto partition and a single recursive call on the side that contains the desired order.

**Quicksort.** Sort by Lomuto partition and two recursive calls. The plain version in the laboratory uses two calls. The smaller-side version bounds stack depth by $O(\log n)$.

**Radix sort.** A sort that decomposes keys into digits and sorts one digit at a time. In this lecture the order of digits is least significant first, and each pass is stable counting sort.

**Randomized quicksort.** Quicksort that swaps a uniform random index into the pivot slot before Lomuto partition.

**Rank.** In the indicator proof, the position of a key in the sorted order of the distinct keys, starting at $0$. Elsewhere, the order $k$ of an order statistic.

**Recursion depth.** The number of nested calls on the current path. The laboratory counts the original call as depth $1$.

**Run.** A contiguous sorted segment of an array. Merge consumes two runs.

**Selection sort.** The in-place sort that repeatedly swaps the minimum of the suffix into the next prefix cell. Every input uses $n(n-1)/2$ key comparisons. Unstable.

**Sorting problem.** Given an array, produce a permutation of it in nondecreasing key order.

**Stack depth.** The maximum number of frames simultaneously active. Distinct from auxiliary element memory.

**Stable sort.** A sort that preserves the original relative order of records with equal keys.

**Stirling's approximation.** The stated estimate $\log_2(n!) = n\log_2 n - n\log_2 e + O(\log n)$. Not proved in this lecture.

**Unstable sort.** A sort for which some pair of equal-key records reverses its original order. Selection sort and Lomuto quicksort are unstable.

**Upper median.** The element of order $\lfloor n/2 \rfloor$.

---

## Lecture summary

A comparison sort learns order two outcomes at a time. The decision tree then has at least $n!$ leaves, so its height is at least $\log_2(n!)$, and both the elementary bound and the stated form of Stirling's approximation turn that height into $\Omega(n \log n)$. Mergesort meets the bound with the recurrence $T(n) = 2T(n/2) + \Theta(n)$, a left-preferring merge that is stable, and a linear buffer. Insertion sort is the stable quadratic algorithm whose exact worst-case count is $n(n-1)/2$ and whose best case is $n-1$. Selection sort uses that same count on every input and is unstable.

Lomuto partition places the last element at a final index $q$, with the left region $\le$ the pivot and the right region strictly greater. Quicksort's worst case is the recurrence $T(n) = T(n-1) + \Theta(n) = \Theta(n^2)$, reached when the pivot is always extreme and also when every key is equal. On distinct keys a random pivot has expected comparison count $\Theta(n \log n)$ by the indicator argument: a pair of ranks is compared exactly when the first pivot in the interval they span is one of the two endpoints, an event of probability $2/(j-i+1)$, and the resulting harmonic sum is $\Theta(n \log n)$. The plain recursion has worst-case stack depth $\Theta(n)$. Recursing on the smaller side and iterating on the larger side brings every input's stack depth down to $O(\log n)$.

Counting sort and least-significant-digit radix sort leave the comparison model. Counting sort is $\Theta(n+k)$ and stable when the placement walks the input from right to left. Radix sort calls it once per digit, from least significant to most significant, and the inductive claim is that pass $d$ leaves the lowest $d+1$ digits sorted. The same idea, one order at a time, is quickselect: Lomuto's index $q$ answers a selection when it matches the desired order, and a random pivot discards a constant fraction in expectation, giving expected linear time. Median of medians forces a constant-fraction discard on distinct keys by pivoting on the median of five-element medians, at the price of the recurrence $T(n) \le T(\lceil n/5 \rceil) + T(7n/10 + 6) + \Theta(n)$.

### Five principles

1. Count comparisons exactly when the scan is data-independent, and use $\Theta$ when only the growth matters. Selection sort is $n(n-1)/2$ on every input; mergesort is $\Theta(n \log n)$.
2. Stability is settled by the tie rule. Prefer the left run in a merge, stop insertion sort on a non-strict predecessor, and place counting-sort records from right to left.
3. A lower bound applies only inside its model. The decision tree bounds comparison sorts. An algorithm that uses a key as an index is answering a different question about what a step may observe.
4. Randomness changes the expectation. It does not rewrite the worst-case partition. State the distinct-key hypothesis beside every expected $\Theta(n \log n)$ or expected $\Theta(n)$ claim for Lomuto's partition.
5. Choose from the key domain, the stability requirement, and the memory budget. A linear buffer buys mergesort's worst-case guarantee. A bounded integer range buys counting sort or radix sort. One order statistic does not require a full sort.

---

## References

Cormen, Thomas H., Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapters 2, 4, 5, 7, 8, and 9. Insertion sort and mergesort are in Chapter 2. The Master Theorem is in Chapter 4. Indicator variables and expectation are in Chapter 5. Quicksort, including the indicator analysis of the expected comparison count and Lomuto partition, is in Chapter 7. The decision-tree lower bound, Stirling's approximation as used for that bound, counting sort, and radix sort are in Chapter 8. Minimum and maximum, quickselect, and median of medians are in Chapter 9.

Sedgewick, Robert, and Kevin Wayne. *Algorithms*. 4th edition. Addison-Wesley, 2011. Chapter 2. Elementary sorts, mergesort, and quicksort. The partition implemented and traced in this lecture is Lomuto's, as in Cormen, Chapter 7.

Hoare, C. A. R. "Quicksort." *The Computer Journal*, volume 5, number 1, 1962. The original quicksort paper. Section 7 of this lecture describes the two-index partition associated with that paper and does not implement it.

Blum, Manuel, Robert W. Floyd, Vaughan Pratt, Ronald L. Rivest, and Robert E. Tarjan. "Time bounds for selection." *Journal of Computer and System Sciences*, 1973. The median-of-medians selection algorithm. The procedure and the $7n/10$ recurrence in this lecture follow the account in Cormen, Chapter 9.
