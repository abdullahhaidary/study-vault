# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 01 — MODELS, ADTs, AND ASYMPTOTIC ANALYSIS

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 01 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 8 hours
**Prerequisites:** None. JavaScript functions, loops, and algebra. No earlier lecture.
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapters 1–4; the same authors' 3rd edition, Chapter 4, for the narrower Master Theorem case; Graham, Knuth, and Patashnik, *Concrete Mathematics*, 2nd edition, Chapter 2; Liskov and Zilles, "Programming with Abstract Data Types" (1974)

**This lecture owns:** the RAM model, abstract data types versus implementations, formal asymptotic notation, summation, loop analysis, and solving recurrences by substitution and the Master Theorem.
**This lecture does not teach:** dynamic-array code, linked lists, sorting implementations, or a full amortized analysis. Amortization is named once and proved in Lecture 02. Binary search as an algorithm is Lecture 05. Mergesort as an algorithm is Lecture 06.

---

## Learning objectives

By the end of this lecture you can:

1. Distinguish a problem, an instance, and a correct finite algorithm, and reject a procedure that fails to halt on some instance.
2. Classify a step as a constant-time RAM primitive or as a non-primitive, including multiplication of huge integers and hashing of an arbitrary string.
3. Specify a counter abstract data type by operations and equations, and give two implementations whose costs differ.
4. Define best-case, worst-case, and average-case cost, and name the distribution an average-case claim uses.
5. Write the definitions of $O$, $\Omega$, $\Theta$, $o$, and $\omega$ with their quantifiers, and produce a numeric witness or a negative proof.
6. Order $1$, $\log n$, $n$, $n \log n$, $n^2$, $n^3$, $2^n$, and $n!$, and prove the comparisons that justify that order.
7. Prove the closed forms of the arithmetic series, the geometric series, and the sum of squares, and apply them to nested loops.
8. Derive the exact iteration count and a $\Theta$ bound for a single loop, a triangular nested loop, and a loop that doubles its index.
9. Prove a divide-and-conquer recurrence by induction, including the choice of constant; apply the Master Theorem; and solve one recurrence the theorem does not cover.
10. Prove a small loop correct by an invariant, in the form initialization, maintenance, termination.

---

## Purpose of this lecture

Every later lecture states a cost. The cost is meaningless until three things are fixed: the machine that is being charged, the object whose operations are being charged, and the meaning of the symbols $O$, $\Omega$, and $\Theta$. This lecture fixes those three things, and it builds the two calculation tools the rest of the course uses: sums for loops, and recurrences for recursive procedures.

The lecture is the chapter. Work the traces with a pencil before you read the next line. The laboratory program checks the closed forms; it does not replace the proofs. The examination is at the end, before the answer key. Take it closed-notes.

What this lecture deliberately leaves alone: a dynamic array and the aggregate, accounting, and potential methods (Lecture 02); linked representation (Lecture 03); stacks, queues, and deques (Lecture 04); the correctness proof and the code of binary search (Lecture 05); the code of mergesort, quicksort, and the sorting lower bound (Lecture 06). When a sorting cost appears below, it is only a function from the input length to a number of primitive steps. The procedure that realizes that function is not given here.

Notation used from this point on, and in every later lecture: arrays and strings are $0$-indexed; $n$ is the input size; $\log$ is base $2$; $\ln$ is the natural logarithm; $\log_b$ names another base; $\Theta$ is a tight bound, $O$ is only an upper bound, and $\Omega$ is only a lower bound.

---

# Part 1. Algorithms as technology

## 1.1 Problem, instance, algorithm

A **problem** is a general question together with a rule that says which inputs are legal and which outputs count as solutions. A **instance** is one legal input.

The sorting problem, stated only as a specification: the input is a finite sequence of integers, and the output is a permutation of that sequence in nondecreasing order. The sequence $(3, 1, 2)$ is an instance. The sequence $(1, 2, 3)$ is a solution of that instance. The sequence $(3, 2, 1)$ is not. This lecture does not give a sorting procedure. Lecture 06 does.

An **algorithm** for a problem is a procedure that, on every instance, performs finitely many primitive steps and returns a solution. Both demands are part of the definition.

- **Correctness.** For every instance, the value returned meets the problem's output rule.
- **Finiteness.** For every instance, the procedure reaches that return after finitely many steps.

A procedure that returns the right answer on some instances and runs forever on others is not an algorithm for the problem. Consider a scan that walks an array looking for the value $7$ and increments an index, but has no test for the end of the array. On an array that contains $7$ it may return. On an array that does not, it never returns. It is not an algorithm for the problem "find $7$ or report that it is absent." It can be an algorithm for the different problem "find $7$ in an array that is promised to contain $7$," because every legal instance of that narrower problem makes it halt. The promise is part of the problem.

## 1.2 Why the procedure is not enough

Correctness does not decide which of two algorithms to run. Hardware speed does not decide it either, once the input is long. The comparison below uses two cost functions and two machine speeds. It does not describe the internal steps of either algorithm. Call a quadratic sorting method **insertion sort** and a linearithmic sorting method **mergesort**. Their procedures belong to Lecture 06. Here each name denotes only a function from the length $n$ to a number of primitive steps.

Model, not a measurement of any JavaScript engine:

- Machine A performs $10^{10}$ primitive steps per second and runs a procedure whose cost is $2n^2$ steps.
- Machine B performs $10^{7}$ primitive steps per second and runs a procedure whose cost is $50\, n \log n$ steps.

Machine A is one thousand times faster, step for step. Take $n = 2^{10} = 1024$, so $\log n = 10$.

$$
\begin{aligned}
\text{time on A}
  &= \frac{2 \cdot (2^{10})^2}{10^{10}}
   = \frac{2^{21}}{10^{10}}
   = \frac{2097152}{10000000000}
   = 0.0002097152 \text{ seconds.} \\[0.5em]
\text{time on B}
  &= \frac{50 \cdot 2^{10} \cdot 10}{10^{7}}
   = \frac{512000}{10000000}
   = 0.0512 \text{ seconds.}
\end{aligned}
$$

At this length the faster machine wins. Now take $n = 2^{20} = 1048576$, so $\log n = 20$. Use $2^{10} = 1024$ and $2^{20} = 1048576$, hence $2^{40} = 1099511627776$ and $2^{41} = 2199023255552$.

$$
\begin{aligned}
\text{time on A}
  &= \frac{2 \cdot (2^{20})^2}{10^{10}}
   = \frac{2^{41}}{10^{10}}
   = 219.9023255552 \text{ seconds.} \\[0.5em]
\text{time on B}
  &= \frac{50 \cdot 2^{20} \cdot 20}{10^{7}}
   = \frac{1048576000}{10000000}
   = 104.8576 \text{ seconds.}
\end{aligned}
$$

At one million elements the slower machine finishes first, because it is running the slower-growing cost. For still larger $n$ the gap widens, since $n^2$ grows faster than $n \log n$. The proof of that comparison is in Part 6. The numerical point is already visible: a change of algorithm can beat a large change of hardware. That is the sense in which an algorithm is a technology. The constants $2$ and $50$ are part of this model. They are not universal constants of the two procedures, and they are not timings of an engine.

---

# Part 2. The RAM model

## 2.1 What is being charged

A running time measured on one laptop mixes the algorithm with the processor, the language runtime, the cache, and the other programs on the machine. The course needs a cost that depends on the procedure and on the length of the input. The **RAM model** (random-access machine) is that idealization.

The machine stores integers in cells called **words**. It can read or write the word at a given address in one step. That is the "random access": the cost of touching a cell does not depend on the address. A **primitive step** is one of the operations the model charges as one unit. On words, the primitive steps are:

- addition, subtraction, multiplication, integer division, and remainder of two words;
- comparison of two words;
- bitwise operations on a word;
- reading a word from an address, or writing a word to an address;
- following a stored address (one pointer hop) and reading or writing the word found there;
- the bookkeeping of one assignment, one conditional branch, or one procedure call, apart from the work inside the procedure.

A sequence of $k$ primitive steps costs $k$, for a constant $k$ independent of $n$. That sequence is $\Theta(1)$ time. The symbol $\Theta$ is defined in Part 5. Until then, read $\Theta(1)$ as "bounded by two positive constants for every sufficiently large input."

The word must be wide enough to hold an address into the input. If the input occupies $n$ words, a word of $\Theta(\log n)$ bits can name any of those words. Arithmetic on such words is one primitive step. This is a modeling decision. It matches the way CLRS analyzes the algorithms in Chapters 1–4, and it matches ordinary programming as long as every integer you touch fits in a machine word.

JavaScript's number type is an IEEE-754 double, not a mathematical integer. Every integer whose absolute value is at most $2^{53} - 1 = 9007199254740991$ is represented exactly. Call that bound the **safe-integer limit**. All exact integer claims in this lecture, and every number in the laboratory program, stay inside it. Past that limit, a JavaScript number is the wrong model of a word, and the right model is the multi-word arithmetic of the next subsection.

## 2.2 What is not a primitive step

Two operations that programs often write as one expression are not constant-time primitives.

**Multiplying integers that do not fit in a word.** Let each integer have $m$ bits, with $m$ growing. The schoolbook method multiplies each bit of one by each bit of the other and adds, using $\Theta(m^2)$ bit operations. Faster methods exist; none of them is $\Theta(1)$ as $m$ grows. In the word RAM, a single `*` is a primitive only when both factors are words. A loop that multiplies the integer $N$ by itself $\Theta(N)$ times, with $N$ given in binary, is not a linear-time algorithm in the length of the input: the input length is $\Theta(\log N)$ bits, while the loop performs $\Theta(N)$ iterations.

**Hashing an arbitrary string.** A string of length $m$ is $m$ characters. Any procedure that claims to depend on every character must read those characters, which costs $\Omega(m)$ in the worst case. Treating "compute the hash of this string" as one RAM step hides a loop over the characters. Lecture 11 builds hash tables and states the hashing assumption those bounds need. This lecture only records the prohibition: an arbitrary string hash is not a primitive.

The same reading lower bound applies to any claim that a structure "looks at the whole key for free."

## 2.3 How a cost is built from primitives

If a procedure performs at most $c \cdot f(n)$ primitive steps on every input of size $n$, for some constant $c > 0$ and all sufficiently large $n$, its worst-case cost is $O(f(n))$. If it also performs at least $c' \cdot f(n)$ primitive steps on every such input, the cost is $\Theta(f(n))$. The quantifiers that make these sentences precise are in Part 5. The discipline is already usable: count primitive steps, keep the exact count when the algebra is clean, and only then wrap the count in $O$, $\Omega$, or $\Theta$.

Engine-specific optimizations are not part of the count. A particular JavaScript engine may represent an array in a clever way, or cache a string hash. A proof in this course does not depend on that. The laboratory implements the copies it claims to perform.

---

# Part 3. Abstract data type, data structure, and algorithm

## 3.1 Three different objects

An **abstract data type** (ADT) is a collection of operations and a set of equations that say how those operations behave. The equations mention values that a client can observe. They do not mention indexes, pointers, or the number of words stored.

A **data structure** is a representation that provides those operations: the fields that are stored, and the procedures that update them. One ADT can have many data structures. They are interchangeable for a client who only relies on the equations, and they are not interchangeable for a client who relies on the cost.

An **algorithm** is a finite procedure solving a stated problem. It may use a data structure. The algorithm is not the structure. Linear search, below, is an algorithm. The counter, next, is an ADT with two structures. Neither is a list. The list ADT is Lecture 03.

The separation is the one Liskov and Zilles insisted on: the specification is closed under the operations the client can call, and the representation is a private choice that must preserve that specification.

## 3.2 The counter ADT

A counter stands for a nonnegative integer. The client can create it, add a nonnegative integer to it, and read it. The client cannot see how the integer is stored.

**Operations.**

| Operation | Meaning |
| --- | --- |
| $\mathrm{make}()$ | a new counter |
| $\mathrm{add}(c, k)$ | the counter obtained by adding integer $k \ge 0$ to $c$ |
| $\mathrm{increment}(c)$ | abbreviation of $\mathrm{add}(c, 1)$ |
| $\mathrm{reset}(c)$ | the counter obtained by returning $c$ to zero |
| $\mathrm{value}(c)$ | the nonnegative integer that $c$ stands for |

**Equations.** For every counter $c$ and every integer $k \ge 0$,

$$
\begin{aligned}
\mathrm{value}(\mathrm{make}()) &= 0, \\
\mathrm{value}(\mathrm{add}(c, k)) &= \mathrm{value}(c) + k, \\
\mathrm{value}(\mathrm{increment}(c)) &= \mathrm{value}(c) + 1, \\
\mathrm{value}(\mathrm{reset}(c)) &= 0.
\end{aligned}
$$

The third equation is a consequence of the second together with the abbreviation $\mathrm{increment}(c) = \mathrm{add}(c, 1)$. It is written out because both implementations below must be checked against it. These equations are the whole specification. A client who only uses them cannot tell which implementation is underneath.

## 3.3 First implementation: one word

**NumberCounter** stores a single nonnegative integer `count`, at most the safe-integer limit.

```text
make():
    count ← 0

value(c):
    return count

add(c, k):          (k ≥ 0, and count + k stays inside the safe-integer limit)
    count ← count + k

reset(c):
    count ← 0
```

Each operation performs a constant number of word primitives, so each is $\Theta(1)$ time in the RAM model, inside the safe-integer limit. The space is one word, $\Theta(1)$.

**Representation invariant.** `count` equals $\mathrm{value}(c)$, and `count` is an integer with $0 \le \mathrm{count} \le 2^{53} - 1$. The constructor makes it true. `add` preserves it when the limit is respected. `reset` restores `count` to $0$.

## 3.4 Second implementation: unary marks

**UnaryCounter** stores the value $v$ as an array of $v$ marks, each mark the integer $1$. The length of the array is the value. This is a teaching representation. It exists so the cost of the specification can be seen to depend on the representation. It is not the dynamic array of Lecture 02: the array is not grown by doubling, and no amortized bound is claimed.

```text
make():
    marks ← an array of length 0

value(c):
    return the length of marks

increment(c):
    allocate an array t of length v + 1, where v is the length of marks
    copy the v marks into the first v slots of t
    store 1 in the last slot of t
    marks ← t

add(c, k):
    allocate an array t of length v + k
    copy the v marks into t
    store 1 in each of the k new slots
    marks ← t

reset(c):
    marks ← an array of length 0
```

Reading the length is one primitive, so $\mathrm{value}$ is $\Theta(1)$. Reset replaces the array by an empty one and is $\Theta(1)$ in this model; the old array is simply no longer used. Increment of a counter whose value is $v$ copies $v$ words and writes one new word, which is $\Theta(v)$ primitive steps. Add of $k$ copies $v$ words and writes $k$ new words, which is $\Theta(v + k)$.

**Representation invariant.** The length of `marks` equals $\mathrm{value}(c)$, and every slot holds $1$. Increment copies the old marks and appends a single $1$, so the length grows by exactly $1$ and the invariant is preserved. The equation $\mathrm{value}(\mathrm{increment}(c)) = \mathrm{value}(c) + 1$ holds because the new length is the old length plus one.

After $\mathrm{make}$ followed by $n$ increments, the $i$-th increment (counting from $i = 1$) copies $i - 1$ marks. The total number of copied words is

$$
\sum_{i = 0}^{n - 1} i = \frac{(n - 1) n}{2}
$$

once the arithmetic-series theorem of Part 7 is available. The total cost of the $n$ increments is therefore $\Theta(n^2)$. The same $n$ increments on NumberCounter cost $\Theta(n)$. Both structures satisfy the same equations. The equations do not mention cost. The choice between them is a cost decision: NumberCounter is the one to use, and UnaryCounter is the witness that "a counter" does not by itself have a running time.

A geometric resizing policy, in which some increments are expensive and the average over a sequence is cheap, is amortization. Lecture 02 proves it. This lecture stops at the definition in Part 4.

```text
NumberCounter after 4 increments:    count = 4

UnaryCounter after 4 increments:     marks = [1, 1, 1, 1]
                                     length = 4
                                     words copied along the way = 0 + 1 + 2 + 3 = 6
```

## 3.5 Where the algorithm sits

Linear search is an algorithm, not an ADT. The input is an array $A[0..n-1]$ of words and a word $x$. The output is the smallest index $i$ with $A[i] = x$, or an absent result if no such index exists. In JavaScript the absent result is `null`.

```text
linearSearch(A, x):
    for i ← 0 to n - 1:
        if A[i] = x:
            return i
    return null
```

The procedure always halts: the loop runs at most $n$ times. It is correct because it returns the first match, and it returns `null` only after every slot has failed the test. Its cost depends on the instance. That distinction is the next part. The procedure is not binary search. Binary search requires a sorted array and a different argument; Lecture 05 owns it.

---

# Part 4. Input size, and best, worst, and average case

## 4.1 Input size

The variable $n$ is the **input size** in the unit the RAM model charges: almost always the number of words in the input. For an array of $n$ word-sized numbers, the size is $n$. For a string, the size is the number of characters. For a procedure whose only input is a single integer $N$ written in binary, the size is $\Theta(\log N)$, the number of bits, and not the numeric value $N$. A loop that runs $N$ times is then exponential in the input size.

Floors and ceilings appear as soon as a length is split in half. For a real number $x$, the **floor** $\lfloor x \rfloor$ is the greatest integer less than or equal to $x$, and the **ceiling** $\lceil x \rceil$ is the least integer greater than or equal to $x$. So $\lfloor n/2 \rfloor + \lceil n/2 \rceil = n$ for every integer $n \ge 0$.

When several parameters describe the input, the cost is a function of all of them. A graph procedure, when graphs arrive in Lecture 12, is charged in the number of vertices and the number of edges. Saying "it is $O(n)$" without saying what $n$ counts is not yet a bound. Part 11 returns to that abuse.

## 4.2 Best case and worst case

Let $T(x)$ be the number of primitive steps the procedure uses on instance $x$, and let $I_n$ be the set of instances of size $n$.

$$
\begin{aligned}
T_{\mathrm{worst}}(n) &= \max_{x \in I_n} T(x), \\
T_{\mathrm{best}}(n) &= \min_{x \in I_n} T(x).
\end{aligned}
$$

Both are functions of $n$ alone. The worst case is the cost you can guarantee. The best case is the cost on the easiest legal instance. It is not a typical cost, and it is not a reason to choose an algorithm.

On `linearSearch`, each iteration performs a constant number of primitives; call that constant $c \ge 1$, accounting for the comparison, the index arithmetic, and the branch. If $A[0] = x$, the loop body runs once and the cost is $\Theta(1)$. That is the best case. If $x$ does not occur, the body runs $n$ times and the cost is $\Theta(n)$. That is the worst case. If $x$ occurs only at index $n - 1$, the cost is also $\Theta(n)$.

## 4.3 Average case needs a distribution

The **average-case** cost is an expectation. It is defined only after a probability distribution on $I_n$ is named.

$$
T_{\mathrm{avg}}(n) = \sum_{x \in I_n} \Pr(x) \, T(x).
$$

A sentence of the form "the average case is $\Theta(n)$" that does not name $\Pr$ has not stated a theorem.

Take `linearSearch` under this distribution: $x$ occurs exactly once, and its index is uniformly random in $\{0, 1, \ldots, n - 1\}$. Finding the value at index $i$ uses $i + 1$ comparisons. The expectation is

$$
\frac{1}{n} \sum_{i = 0}^{n - 1} (i + 1)
  = \frac{1}{n} \sum_{k = 1}^{n} k.
$$

Part 7 proves that the sum equals $n(n + 1)/2$, so the expectation equals $(n + 1)/2$, which is $\Theta(n)$. The distribution did the work. A different distribution gives a different number. If $x$ is absent with probability $1$, the average case is the worst case.

For a numeric check with the same array the laboratory uses: $A = [4, 7, 9]$, so $n = 3$. The three equally likely positions cost $1$, $2$, and $3$ comparisons. The mean is $6/3 = 2$, and $(3 + 1)/2 = 2$.

## 4.4 One paragraph on amortized cost

Amortized cost is the average cost of one operation over a worst-case sequence of operations on a structure, not the expectation of one operation under a distribution on inputs. If every sequence of $m$ operations costs at most $T(m)$ primitive steps in total, the amortized cost per operation is $T(m)/m$. Some operation inside that sequence may be much more expensive; the bound says only that those expensive operations are rare enough in every sequence, including the worst one. Average-case analysis answers a different question: it takes the expectation of the cost of a single run under a stated probability distribution. The two averages are not interchangeable. Lecture 02 proves amortized bounds for a dynamic array. This lecture does not.

---

# Part 5. Formal asymptotic notation

## 5.1 Asymptotically nonnegative functions

The definitions below follow CLRS: they are stated for functions that are eventually nonnegative, because a running time is a number of steps. A function $g$ is **asymptotically nonnegative** when there exists $n_1$ such that $g(n) \ge 0$ for every $n \ge n_1$. Throughout this part, $f$ and $g$ are functions from the positive integers to the reals, and the bounding function named on the right-hand side is asymptotically nonnegative. The phrase "for all $n \ge n_0$" always quantifies over integers.

Writing $f(n) = O(g(n))$ means $f$ is a member of the set $O(g)$. The equals sign is a membership claim, read from left to right. It is the notation of CLRS and of this course. It does not mean that the two sides may be swapped.

## 5.2 The five definitions

**Big-O (upper bound).**

$$
O(g(n))
  = \{\, f(n) : \text{there exist constants } c > 0 \text{ and } n_0 > 0
     \text{ such that } 0 \le f(n) \le c \, g(n) \text{ for all } n \ge n_0 \,\}.
$$

**Big-Omega (lower bound).**

$$
\Omega(g(n))
  = \{\, f(n) : \text{there exist constants } c > 0 \text{ and } n_0 > 0
     \text{ such that } 0 \le c \, g(n) \le f(n) \text{ for all } n \ge n_0 \,\}.
$$

**Theta (tight bound).**

$$
\Theta(g(n))
  = \{\, f(n) : \text{there exist constants } c_1 > 0,\; c_2 > 0, \text{ and } n_0 > 0
     \text{ such that } 0 \le c_1 \, g(n) \le f(n) \le c_2 \, g(n)
     \text{ for all } n \ge n_0 \,\}.
$$

**Little-o (upper bound that is not tight).**

$$
o(g(n))
  = \{\, f(n) : \text{for every constant } c > 0 \text{ there exists } n_0 > 0
     \text{ such that } 0 \le f(n) < c \, g(n) \text{ for all } n \ge n_0 \,\}.
$$

**Little-omega (lower bound that is not tight).**

$$
\omega(g(n))
  = \{\, f(n) : \text{for every constant } c > 0 \text{ there exists } n_0 > 0
     \text{ such that } 0 \le c \, g(n) < f(n) \text{ for all } n \ge n_0 \,\}.
$$

The quantifier order is the whole difference between the big and little forms. For $O$ and $\Omega$, one constant $c$ is chosen and then works for every large $n$. For $o$ and $\omega$, the constant is given by an adversary and must be answered by some $n_0$. A single pair $(c, n_0)$ is a **witness** for a big-O, big-Omega, or Theta claim. A little-o or little-omega claim needs a rule that produces $n_0$ from $c$.

## 5.3 Theta is the intersection of O and Omega

**Lemma (Theta characterization).** $f(n) = \Theta(g(n))$ if and only if $f(n) = O(g(n))$ and $f(n) = \Omega(g(n))$.

**Proof.** Suppose $f(n) = \Theta(g(n))$, witnessed by $c_1$, $c_2$, and $n_0$. The inequality $f(n) \le c_2 \, g(n)$ is the witness $c = c_2$ for $O$. The inequality $c_1 \, g(n) \le f(n)$ is the witness $c = c_1$ for $\Omega$. The same $n_0$ serves both.

Suppose instead $f(n) = O(g(n))$ with witness $(c_2, n_2)$ and $f(n) = \Omega(g(n))$ with witness $(c_1, n_1)$. For every $n \ge \max(n_1, n_2)$,

$$
0 \le c_1 \, g(n) \le f(n) \le c_2 \, g(n).
$$

So $c_1$, $c_2$, and $n_0 = \max(n_1, n_2)$ witness $f(n) = \Theta(g(n))$. $\square$

**Lemma (Transitivity of big-O).** If $f(n) = O(g(n))$ and $g(n) = O(h(n))$, then $f(n) = O(h(n))$.

**Proof.** Take witnesses $f(n) \le c_1 g(n)$ for $n \ge n_1$, and $g(n) \le c_2 h(n)$ for $n \ge n_2$. Then $f(n) \le c_1 c_2 \, h(n)$ for every $n \ge \max(n_1, n_2)$. $\square$

## 5.4 Numeric witnesses

**Example 1.** $3n + 2 = O(n)$, with witness $c = 5$ and $n_0 = 1$.

For every integer $n \ge 1$, the inequality $3n + 2 \le 5n$ rearranges to $2 \le 2n$, which holds. Also $3n + 2 \ge 0$. The witness $c = 3$ fails: $3n + 2 \le 3n$ rearranges to $2 \le 0$.

**Example 2.** $3n + 2 = \Omega(n)$, with witness $c = 3$ and $n_0 = 1$, because $3n \le 3n + 2$ for every $n \ge 1$.

By the Theta characterization, $3n + 2 = \Theta(n)$ with $c_1 = 3$, $c_2 = 5$, and $n_0 = 1$.

**Example 3 (negative).** $n^2$ is not $O(n)$.

Suppose toward a contradiction that witnesses $c > 0$ and $n_0 > 0$ exist, so that $n^2 \le c \, n$ for every integer $n \ge n_0$. For $n \ge 1$ this divides to $n \le c$. Choose the integer

$$
n = \max(n_0, \lfloor c \rfloor + 1).
$$

Then $n \ge n_0$ and $n \ge \lfloor c \rfloor + 1 > c$, so $n > c$. That contradicts $n \le c$. Therefore no such witnesses exist. This is the required kind of negative example: a faster-growing function is not big-O of a slower one. The laboratory can show a finite piece of the same fact, for instance $101^2 > 100 \cdot 101$, but a finite piece is not the proof. The proof is the contradiction.

**Example 4.** $n = o(n^2)$. Let $c > 0$ be arbitrary. Choose $n_0 = \lfloor 1/c \rfloor + 1$. For every integer $n \ge n_0$, one has $n > 1/c$, so $1 < c \, n$, and multiplying by the positive quantity $n$ gives $n < c \, n^2$.

**Example 5.** $n^2 = \omega(n)$. Let $c > 0$ be arbitrary. Choose $n_0 = \lfloor c \rfloor + 1$. For every integer $n \ge n_0$, one has $n > c$, so $n^2 > c \, n$.

**Example 6.** $n$ is not $o(n)$. The little-o definition, applied to the particular constant $c = 1$, demands an $n_0$ such that $n < n$ for every $n \ge n_0$. No integer satisfies $n < n$.

A finite check, such as "the inequality holds for every $n$ from $1$ through $1000$," supports a witness you have already proved. It does not prove a "for all $n \ge n_0$" claim, and the laboratory program is written so that it cannot be mistaken for such a proof.

---

# Part 6. Standard growth

## 6.1 Change of base

**Lemma (Change of base).** Let $b > 1$ and $n > 0$. Then

$$
\log_b n = \frac{\log n}{\log b},
$$

and for every $n \ge 2$,

$$
\log_b n = \Theta(\log n).
$$

**Proof.** Let $x = \log_b n$, so $b^x = n$ by definition of $\log_b$. Apply $\log$ to both sides. The identity $\log(b^x) = x \log b$ holds because $\log$ is the inverse of the exponential base $2$: if $b = 2^{\log b}$, then $b^x = 2^{x \log b}$, and taking $\log$ yields $x \log b$. Therefore $\log n = x \log b$. Since $b > 1$, one has $\log b > 0$, and dividing is legal. So $x = \log n / \log b$.

For $n \ge 2$ both $\log n$ and $\log_b n$ are positive. The constant $1/\log b$ is positive and independent of $n$, so the same constant serves as both $c_1$ and $c_2$ in the definition of $\Theta$, with $n_0 = 2$. $\square$

In particular $\log_b a = \log a / \log b$ whenever $a > 0$ and $b > 1$. The Master Theorem uses $\log_b a$. Changing the base of the logarithm inside a $\Theta$ bound never changes the bound, because the bases differ by a positive constant factor. Writing $\log_{10}$ in one place and $\log_2$ in another is not, by itself, a different growth class.

CLRS writes $\lg$ for the base-$2$ logarithm. This course writes $\log$ for that function.

## 6.2 Logarithms against polynomials

**Lemma (Logarithm versus a positive power).** For every constant $\varepsilon > 0$,

$$
\log n = o(n^{\varepsilon}).
$$

**Proof.** The binomial theorem supplies the polynomial lower bound on the exponential. For an integer $t \ge 2$,

$$
2^t = \sum_{i = 0}^{t} \binom{t}{i} \ge \binom{t}{2} = \frac{t(t - 1)}{2}.
$$

Let $c > 0$ be given. The little-o claim needs an $n_0$ such that $\log n < c \, n^{\varepsilon}$ for every integer $n \ge n_0$. Consider integers $n \ge 4$, and write $m = \lfloor \log n \rfloor$, so $m \ge 2$, $2^m \le n < 2^{m + 1}$, and $m > \log n - 1$. In particular $\log n < m + 1$. The rest of the argument bounds $m$ and converts back to $\log n$ only at the last step.

Restrict further to $m \ge 4/\varepsilon$, so that the integer $t = \lfloor \varepsilon m \rfloor$ satisfies $t \ge 2$ and, because $\varepsilon m \ge 4 \ge 2$,

$$
t = \lfloor \varepsilon m \rfloor \ge \varepsilon m - 1 \ge \frac{\varepsilon m}{2}.
$$

(The last step is $\varepsilon m - 1 \ge \varepsilon m / 2$, that is $\varepsilon m \ge 2$, which holds.) Then $t - 1 \ge \varepsilon m / 2 - 1$, and the further restriction $m \ge 4/\varepsilon$ gives $\varepsilon m / 2 \ge 2$, so $\varepsilon m / 2 - 1 \ge \varepsilon m / 4$. Therefore

$$
2^t \ge \frac{t(t - 1)}{2}
  \ge \frac{1}{2} \cdot \frac{\varepsilon m}{2} \cdot \frac{\varepsilon m}{4}
  = \frac{\varepsilon^2 m^2}{16}.
$$

Since $n^{\varepsilon} \ge (2^m)^{\varepsilon} = 2^{\varepsilon m} \ge 2^t$,

$$
n^{\varepsilon} \ge \frac{\varepsilon^2 m^2}{16}.
$$

Also $\log n < m + 1$, so

$$
\frac{\log n}{n^{\varepsilon}}
  < \frac{16(m + 1)}{\varepsilon^2 m^2}.
$$

For $m \ge 1$, $(m + 1)/m^2 \le 2/m$, and the right-hand side is at most $32/(\varepsilon^2 m)$. Choose an integer $m$ large enough that

$$
m \ge \frac{4}{\varepsilon}, \qquad m \ge 2, \qquad \frac{32}{\varepsilon^2 m} < c,
$$

and set $n_0 = 2^{m}$. For every integer $n \ge n_0$ the corresponding $\lfloor \log n \rfloor$ is at least this $m$, and $\log n < c \, n^{\varepsilon}$. $\square$

The special case $\varepsilon = 1$ is $\log n = o(n)$.

## 6.3 Polynomials against exponentials, and exponentials against factorials

**Lemma (Polynomial versus exponential).** For every integer $k \ge 0$,

$$
n^k = o(2^n).
$$

**Proof.** Let $c > 0$. For integers $n \ge \max(2k, k + 1)$, the binomial coefficient $\binom{n}{k + 1}$ is one term of the expansion of $2^n = (1 + 1)^n$, so

$$
2^n \ge \binom{n}{k + 1} = \frac{n(n - 1) \cdots (n - k)}{(k + 1)!}.
$$

The numerator has $k + 1$ factors, and the smallest of them is $n - k$. The hypothesis $n \ge 2k$ gives $n - k \ge n/2$, so each factor is at least $n/2$ and

$$
2^n \ge \frac{(n/2)^{k + 1}}{(k + 1)!}.
$$

Therefore

$$
\frac{n^k}{2^n}
  \le n^k \cdot \frac{(k + 1)!}{(n/2)^{k + 1}}
  = \frac{(k + 1)! \, 2^{k + 1}}{n}.
$$

Choose

$$
n_0 = \max\left(2k,\; k + 1,\; \left\lfloor \frac{(k + 1)! \, 2^{k + 1}}{c} \right\rfloor + 1\right).
$$

For every integer $n \ge n_0$ the displayed ratio is strictly less than $c$, so $n^k < c \, 2^n$. $\square$

**Lemma (Exponential versus factorial).**

$$
2^n = o(n!).
$$

**Proof.** For every integer $n \ge 1$ the product of the integers from $\lfloor n/2 \rfloor + 1$ through $n$ contains $\lceil n/2 \rceil \ge n/2$ factors, each at least $n/2$. Those integers also divide $n!$, and the remaining factors of $n!$ are at least $1$, so

$$
n! \ge \left(\frac{n}{2}\right)^{n/2}.
$$

Hence

$$
\frac{2^n}{n!}
  \le \frac{2^n}{(n/2)^{n/2}}
  = \frac{2^n \cdot 2^{n/2}}{n^{n/2}}
  = \left(\frac{8}{n}\right)^{n/2}.
$$

For every integer $n \ge 16$, one has $8/n \le 1/2$, so

$$
\frac{2^n}{n!} \le \left(\frac{1}{2}\right)^{n/2} = 2^{-n/2}.
$$

Let $c > 0$. If $c \ge 1$, the choice $n_0 = 16$ works, because $2^{-n/2} \le 2^{-8} = 1/256 < 1 \le c$ is stronger than needed, and already $2^{-8} < c$. If $0 < c < 1$, impose as well $2^{-n/2} < c$, that is $n > 2 \log(1/c)$. The choice

$$
n_0 = \max\left(16,\; \left\lfloor 2 \log \frac{1}{c} \right\rfloor + 1\right)
$$

then gives $2^n < c \, n!$ for every integer $n \ge n_0$. $\square$

## 6.4 The hierarchy

**Lemma (Little-o transitivity).** Suppose $f$, $g$, and $h$ are eventually positive. If $f(n) = o(g(n))$ and $g(n) = o(h(n))$, then $f(n) = o(h(n))$.

**Proof.** Let $c > 0$. Eventually $f(n) < g(n)$, because little-o lets us choose the constant $1$ in front of $g$. Eventually $g(n) < c \, h(n)$. Past both of those thresholds, $f(n) < c \, h(n)$. $\square$

**Theorem (Growth hierarchy).** The following little-o relations hold. They are statements about sufficiently large $n$, not claims about a single $n$.

$$
1 = o(\log n), \quad
\log n = o(n), \quad
n = o(n \log n), \quad
n \log n = o(n^2), \quad
n^2 = o(n^3), \quad
n^3 = o(2^n), \quad
2^n = o(n!).
$$

By little-o transitivity, each function in this list is little-o of every function strictly to its right.

**Proof.** Take the links in order.

1. Let $c > 0$ and set $n_0 = 2^{\lfloor 1/c \rfloor + 1}$. For $n \ge n_0$, $\log n \ge \lfloor 1/c \rfloor + 1 > 1/c$, so $1 < c \log n$.

2. $\log n = o(n)$ is the logarithm-versus-power lemma with $\varepsilon = 1$.

3. For $n \ge 2$, $\log n > 0$. Let $c > 0$ and choose $n_0$ so that $n \ge n_0$ implies $\log n > 1/c$, as in link 1. Then $n < c \, n \log n$.

4. $n \log n < c \, n^2$ rearranges, for $n > 0$, to $\log n < c \, n$, which holds for all large $n$ by link 2.

5. $n^2 < c \, n^3$ rearranges to $1 < c \, n$, so $n_0 = \lfloor 1/c \rfloor + 1$ works.

6. $n^3 = o(2^n)$ is the polynomial-versus-exponential lemma with $k = 3$.

7. $2^n = o(n!)$ is the preceding lemma.

Each function is eventually positive, so transitivity applies along the chain. $\square$

Little-o is a stronger statement than big-O. Each link also yields a big-O bound, and the big-O bound in the reverse direction is false by the same style of argument as Example 3 in Part 5. In particular $n \log n$ is not $O(n)$, and $2^n$ is not $O(n^3)$.

## 6.5 A table, and the shape of the plot

The next table gives exact values. $\log$ is base $2$. The row $n = 1$ is omitted because $\log 1 = 0$, so the product $n \log n$ is $0$ there and the interesting separations have not started. Factorials are exact.

| $n$ | $1$ | $\log n$ | $n$ | $n \log n$ | $n^2$ | $n^3$ | $2^n$ | $n!$ |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| $2$ | $1$ | $1$ | $2$ | $2$ | $4$ | $8$ | $4$ | $2$ |
| $4$ | $1$ | $2$ | $4$ | $8$ | $16$ | $64$ | $16$ | $24$ |
| $8$ | $1$ | $3$ | $8$ | $24$ | $64$ | $512$ | $256$ | $40320$ |
| $16$ | $1$ | $4$ | $16$ | $64$ | $256$ | $4096$ | $65536$ | $20922789888000$ |
| $32$ | $1$ | $5$ | $32$ | $160$ | $1024$ | $32768$ | $4294967296$ | (far beyond the table) |

Two crossovers are easy to miss if one only remembers the eventual order. At $n = 2$, $2^n = 4$ is already larger than $n! = 2$, and it stays larger at $n = 3$ ($8$ against $6$). At $n = 4$, $n! = 24$ passes $2^n = 16$ and, by the last link of the hierarchy, never gives the lead back. Separately, $n^3$ is still ahead of $2^n$ at $n = 8$ ($512$ against $256$) and at $n = 9$ ($729$ against $512$). At $n = 10$, $n^3 = 1000$ and $2^{10} = 1024$, so the exponential passes the cubic, in agreement with $n^3 = o(2^n)$.

On a linear vertical scale the plot is a picture of the rightmost column. By $n = 16$ the value $2^n = 65536$ has left $n^3 = 4096$ and $n \log n = 64$, and $n!$ has left the frame entirely. The slow functions $1$, $\log n$, and $n$ sit on top of each other against that scale. A logarithmic vertical scale separates them: $\log n$ becomes a straight line of small slope, $n^k$ becomes a straight line whose slope grows with $k$ when the horizontal axis is also logarithmic, and $2^n$ becomes a straight line on a semi-log plot (linear in $n$, logarithmic in the value) that is already steeper than every $n^k$. The sketch below is only the left-to-right order of the curves. It is not drawn to scale. The table carries the numbers.

```text
value
  ^
  |                                              n!
  |                                         2^n
  |                                    n^3
  |                              n^2
  |                        n log n
  |                  n
  |            log n
  |     1
  +-------------------------------------------------> n
        2          8           16          32
```

The practical reading of the hierarchy is the one Part 1 used. Replacing an $n^2$ cost by an $n \log n$ cost changes the largest $n$ one can afford. Replacing an $n \log n$ cost by a $2^n$ cost removes that possibility. A bound of $n!$ is a bound that applies only for very small $n$, which the table makes quantitative: $8!$ is already $40320$, and $16!$ has fourteen digits.

---

# Part 7. Summation

The loops in Part 8 are sums. A closed form turns the sum into an expression that the definitions of Part 5 can be applied to. Empty sums are $0$.

## 7.1 Arithmetic series

**Theorem (Arithmetic series).** For every integer $n \ge 0$,

$$
\sum_{k = 1}^{n} k = \frac{n(n + 1)}{2}.
$$

The $n = 0$ case is the empty sum, and the right-hand side is $0$.

**Proof.** The reason the formula is true is a pairing. Let $S = \sum_{k = 1}^{n} k$ for $n \ge 1$. The same sum written backwards is $S = \sum_{k = 1}^{n} (n + 1 - k)$. Add the two expressions term by term. The $k$-th pair is

$$
k + (n + 1 - k) = n + 1,
$$

and there are $n$ pairs, so $2S = n(n + 1)$, hence $S = n(n + 1)/2$. The pairing uses every integer $n \ge 1$, odd or even. For $n = 3$, the pairs are $(1, 3)$, $(2, 2)$, $(3, 1)$, each summing to $4$, and $2S = 12$.

The formal proof is by induction on $n$, so the inductive habit needed for recurrences is practiced on an identity whose answer is already visible.

**Base case.** For $n = 0$, both sides are $0$.

**Inductive hypothesis.** Fix $m \ge 0$ and assume $\sum_{k = 1}^{m} k = m(m + 1)/2$.

**Inductive step.** 

$$
\begin{aligned}
\sum_{k = 1}^{m + 1} k
  &= \frac{m(m + 1)}{2} + (m + 1)
   = (m + 1) \left( \frac{m}{2} + 1 \right)
   = (m + 1) \cdot \frac{m + 2}{2}
   = \frac{(m + 1)(m + 2)}{2}.
\end{aligned}
$$

By induction the identity holds for every integer $n \ge 0$. $\square$

For $n = 10$ the formula yields $10 \cdot 11 / 2 = 55$. That is one of the numbers the laboratory checks by adding the integers directly.

## 7.2 Sum of squares

**Theorem (Sum of squares).** For every integer $n \ge 0$,

$$
\sum_{k = 1}^{n} k^2 = \frac{n(n + 1)(2n + 1)}{6}.
$$

**Proof.** Induction on $n$.

**Base case.** For $n = 0$, both sides are $0$. For a second check, $n = 1$ gives $1 = 1 \cdot 2 \cdot 3 / 6$.

**Inductive hypothesis.** Assume the formula holds for some $m \ge 0$.

**Inductive step.**

$$
\begin{aligned}
\sum_{k = 1}^{m + 1} k^2
  &= \frac{m(m + 1)(2m + 1)}{6} + (m + 1)^2
   = (m + 1) \left( \frac{m(2m + 1)}{6} + (m + 1) \right) \\
  &= (m + 1) \cdot \frac{m(2m + 1) + 6(m + 1)}{6}
   = (m + 1) \cdot \frac{2m^2 + m + 6m + 6}{6}
   = (m + 1) \cdot \frac{2m^2 + 7m + 6}{6}.
\end{aligned}
$$

The quadratic factors as $(2m + 3)(m + 2) = 2m^2 + 4m + 3m + 6 = 2m^2 + 7m + 6$. Therefore the sum equals

$$
\frac{(m + 1)(m + 2)(2m + 3)}{6}
  = \frac{(m + 1)(m + 2)\bigl(2(m + 1) + 1\bigr)}{6},
$$

which is the claimed formula at $m + 1$. $\square$

For $n = 10$ the right-hand side is $10 \cdot 11 \cdot 21 / 6 = 385$. The laboratory adds the ten squares and requires the same value.

## 7.3 Geometric series

**Theorem (Geometric series).** Let $r$ be a real number with $r \ne 1$, and let $n \ge 0$ be an integer. Then

$$
\sum_{k = 0}^{n} r^k = \frac{r^{n + 1} - 1}{r - 1}.
$$

When $r = 1$, every term is $1$ and the sum is $n + 1$. That case is excluded from the closed form because the denominator would be $0$.

**Proof.** Let $S = \sum_{k = 0}^{n} r^k = 1 + r + r^2 + \cdots + r^n$. Multiply by $r$:

$$
rS = r + r^2 + \cdots + r^n + r^{n + 1}.
$$

Subtract:

$$
rS - S = r^{n + 1} - 1,
$$

because every intermediate power cancels. Factor $(r - 1)S = r^{n + 1} - 1$. The hypothesis $r \ne 1$ lets us divide:

$$
S = \frac{r^{n + 1} - 1}{r - 1}.
$$

The same algebra with the terms written in the opposite order yields the often-useful form $(1 - r^{n + 1})/(1 - r)$. $\square$

For $r = 2$ and $n = 4$,

$$
1 + 2 + 4 + 8 + 16 = 31, \qquad \frac{2^{5} - 1}{2 - 1} = 31.
$$

The laboratory checks this pair and a second pair, $r = 3$, $n = 5$:

$$
\frac{3^{6} - 1}{3 - 1} = \frac{729 - 1}{2} = 364.
$$

**Corollary (A geometric sum is at most a constant times its largest term).** Let $r > 1$ and let $n \ge 0$. Then

$$
\sum_{k = 0}^{n} r^k = \frac{r^{n + 1} - 1}{r - 1} < \frac{r^{n + 1}}{r - 1} = r^n \cdot \frac{r}{r - 1}.
$$

The sum of a growing geometric series is $\Theta(r^n)$: the last term alone is a lower bound, and the corollary is an upper bound with constant $r/(r - 1)$. For $r = 2$ the constant is $2$, and the sum equals $2^{n + 1} - 1$, which sits between $2^n$ and $2 \cdot 2^n$.

## 7.4 What these formulas are for

An independent pair of nested loops, each running $n$ times, performs $n^2$ inner iterations. A triangular pair performs $\sum_{i = 1}^{n} i = n(n + 1)/2$ inner iterations. A loop whose body costs $i^2$ on the $i$-th pass performs the sum of squares. A loop whose trip count or whose body halves or doubles produces a geometric series. Part 8 makes each of those sentences a counted procedure. The harmonic numbers $H_m = \sum_{k = 1}^{m} 1/k$ do not have a closed form of this elementary kind. Their bounds are proved in Part 9, at the moment a recurrence produces them.

---

# Part 8. Loop analysis

## 8.1 The iteration lemma

**Lemma (Iteration count).** Suppose the body of a loop executes exactly $s(n)$ times on an input of size $n$, and each execution performs at least $1$ and at most $c_0$ primitive steps, for a constant $c_0$ independent of $n$. Suppose the loop control itself performs at most $c_1$ primitive steps per execution and at most $c_1$ extra steps for the failing test. If $s(n) \ge 1$, the whole loop costs $\Theta(s(n))$ primitive steps.

**Proof.** The body contributes a total $B$ with $s(n) \le B \le c_0 \, s(n)$. Control contributes $C$ with $1 \le C \le c_1(s(n) + 1)$. The sum $B + C$ therefore satisfies

$$
s(n) \le B + C \le (c_0 + c_1) s(n) + c_1 \le (c_0 + 2c_1) s(n)
$$

for every $n$ with $s(n) \ge 1$, because $c_1 \le c_1 s(n)$. The constants $c_{\mathrm{low}} = 1$ and $c_{\mathrm{high}} = c_0 + 2c_1$ witness $\Theta(s(n))$. $\square$

The exact value of $s(n)$ is the useful object. The $\Theta$ bound is what later lectures quote. Both are required here.

## 8.2 A single loop

```text
s ← 0
for i ← 1 to n:
    s ← s + 1
```

The body executes once for each $i \in \{1, 2, \ldots, n\}$, so $s(n) = n$ and the final value of `s` is $n$. For $n = 10$ the body runs ten times and `s` is $10$. Each execution is a constant number of primitives. By the iteration lemma the cost is $\Theta(n)$.

The same count holds if the body is `s ← s + i` instead of `s ← s + 1`. The final value of `s` is then the arithmetic series $n(n + 1)/2$, which is a value computed by the algorithm, not a cost. The cost is still $\Theta(n)$, because each addition is one word operation under the safe-integer limit. Confusing the value stored in `s` with the number of steps is a standing risk when the body adds $i$.

## 8.3 The triangular loop

```text
s ← 0
for i ← 1 to n:
    for j ← 1 to i:
        s ← s + 1
```

The inner body runs $i$ times for each $i$, so the exact number of inner executions is

$$
\sum_{i = 1}^{n} i = \frac{n(n + 1)}{2}
$$

by the arithmetic-series theorem. For $n = 4$ the inner counts are $1 + 2 + 3 + 4 = 10$, and $4 \cdot 5 / 2 = 10$. For $n = 10$ the count is $55$.

For the tight bound, let $s(n) = n(n + 1)/2$. For every integer $n \ge 1$,

$$
\frac{1}{2} n^2 \le \frac{n(n + 1)}{2} \le n^2,
$$

because $n(n + 1)/2 \le n^2$ rearranges to $n + 1 \le 2n$, and $n(n + 1)/2 \ge n^2 / 2$ rearranges to $n + 1 \ge n$. Thus $s(n) = \Theta(n^2)$ with $c_1 = 1/2$, $c_2 = 1$, and $n_0 = 1$. The iteration lemma lifts the bound from the iteration count to the primitive-step count. The cost of the triangular loop is $\Theta(n^2)$.

A second triangular shape, with the inner loop running from $i$ through $n$ rather than from $1$ through $i$, has the same sum: the number of pairs $(i, j)$ with $1 \le i \le j \le n$ is again $n(n + 1)/2$. The examination asks for that variant.

## 8.4 A loop that doubles its index

```text
t ← 0
i ← 1
while i ≤ n:
    t ← t + 1
    i ← 2 · i
```

Assume $n \ge 1$. The variable `i` begins at $2^0 = 1$. After exactly $t$ successful iterations it holds $2^{t}$. The test at the start of the next iteration therefore succeeds if and only if $2^{t} \le n$, that is, if and only if $t \le \log n$. The successful values of $t$ are $0, 1, \ldots, \lfloor \log n \rfloor$. The number of them is the least integer strictly greater than $\log n$, which is

$$
t = \lfloor \log n \rfloor + 1.
$$

Check $n = 1$: the body runs once (`i` goes from $1$ to $2$), and $\lfloor \log 1 \rfloor + 1 = 1$. Check $n = 10$: the successive values of `i` at the test are $1, 2, 4, 8$, all $\le 10$, and the next value $16$ fails. That is four iterations, and $\lfloor \log 10 \rfloor + 1 = 3 + 1 = 4$. Check $n = 8$: the values $1, 2, 4, 8$ pass and $16$ fails, four iterations, and $\lfloor \log 8 \rfloor + 1 = 4$.

For $n \ge 2$, $\log n \ge 1$ and

$$
\log n \le \lfloor \log n \rfloor + 1 \le \log n + 1 \le 2 \log n.
$$

The last step uses $1 \le \log n$. Therefore the iteration count is $\Theta(\log n)$ with $c_1 = 1$, $c_2 = 2$, and $n_0 = 2$. The cost is $\Theta(\log n)$ by the iteration lemma. This is the logarithmic loop. It does not examine $n$ entries. It examines $\lfloor \log n \rfloor + 1$ entries.

## 8.5 A doubling loop whose body adds the index

The geometric series enters when the body does work proportional to the current index, not work proportional to $1$.

```text
s ← 0
i ← 1
while i ≤ n:
    s ← s + i
    i ← 2 · i
```

The values added are $1, 2, 4, \ldots, 2^{m}$ where $m = \lfloor \log n \rfloor$, because $2^{m} \le n < 2^{m + 1}$. By the geometric-series theorem,

$$
s = \sum_{k = 0}^{m} 2^k = 2^{m + 1} - 1.
$$

Since $n$ is an integer and $2^{m} \le n \le 2^{m + 1} - 1$,

$$
n \le 2^{m + 1} - 1 \le 2 \cdot 2^{m} - 1 \le 2n - 1.
$$

The second comparison is equality, because $2 \cdot 2^{m} - 1 = 2^{m + 1} - 1$. The third comparison rearranges to $2^{m} \le n$, which is the definition of $m$. The first comparison holds because $n$ is an integer strictly less than $2^{m + 1}$. So

$$
n \le s \le 2n - 1
$$

for every integer $n \ge 1$, and $s = \Theta(n)$ with $c_1 = 1$, $c_2 = 2$, and $n_0 = 1$. For $n = 10$, $m = 3$ and $s = 1 + 2 + 4 + 8 = 15 = 2^{4} - 1$.

The iteration count is $\Theta(\log n)$. The cost is $\Theta(n)$, because the iterations are not the same size. Reporting "it doubles, so it is logarithmic" answers the wrong question whenever the body grows.

## 8.6 Nested independent loops, and a sum of squares

Two nested loops that each run $n$ times,

```text
for i ← 1 to n:
    for j ← 1 to n:
        constant-time body
```

perform $n^2$ inner executions, which is $\Theta(n^2)$ with $c_1 = c_2 = 1$.

A loop whose $i$-th pass does $\Theta(i^2)$ work, for instance an inner double loop running $i$ by $i$, costs

$$
\sum_{i = 1}^{n} \Theta(i^2) = \Theta\left(\sum_{i = 1}^{n} i^2\right) = \Theta(n^3),
$$

because the sum-of-squares theorem gives a polynomial of degree $3$, and a polynomial of degree $3$ with positive leading coefficient is $\Theta(n^3)$ by the polynomial lemma in Part 9 (the short argument is repeated there so that the Master Theorem can use it). Expanding the exact formula is enough on its own: $n(n + 1)(2n + 1)/6 = (2n^3 + 3n^2 + n)/6$, and for $n \ge 1$ this lies between $(2/6) n^3 = n^3/3$ and $(2n^3 + 3n^3 + n^3)/6 = n^3$. So $c_1 = 1/3$, $c_2 = 1$, and $n_0 = 1$.

---

# Part 9. Recurrences

A **recurrence** defines a function by its value on smaller arguments. The running time of a recursive procedure is a recurrence whose non-recursive term is the cost of the work done outside the recursive calls. Solving the recurrence means producing a closed form, or a $\Theta$ bound, and proving it.

Throughout this part, a cost written $\Theta(1)$ means a positive constant: there is a fixed $c > 0$ such that the non-recursive work is at most $c$ and, when a matching lower bound is claimed, at least some positive constant. When an exact identity is proved, the constant is written as a specific number so the induction has a number to check.

Floors and ceilings are part of an honest recurrence, because a subproblem size has to be an integer. Several proofs below are stated for exact powers, where $\lfloor n/2 \rfloor = n/2$, so the floor never appears. Extending those $\Theta$ bounds from powers of $2$ to every integer $n$, for recurrences of Master-Theorem shape, is a theorem of CLRS (4th edition, the discussion of floors and ceilings in Chapter 4). That extension is **not proved in this lecture**. Every place this lecture claims a bound for all $n$, the proof given here really does cover all $n$. Every place the domain is "powers of $2$," the claim stops there.

## 9.1 Polynomials

The Master Theorem compares a driving function with a power of $n$. The driving functions in the laboratory are polynomials, so the comparison has to be justified for polynomials, not only for monomials.

**Lemma (Polynomials).** Let $d \ge 0$ be an integer and let

$$
p(n) = a_d n^d + a_{d - 1} n^{d - 1} + \cdots + a_0
$$

with $a_d > 0$. Then $p(n) = \Theta(n^d)$.

**Proof.** If $d = 0$, then $p(n) = a_0 > 0$, so $c_1 = c_2 = a_0$ and $n_0 = 1$ witness $\Theta(1)$.

Now let $d \ge 1$. For every integer $n \ge 1$ and every $i \le d$, $n^i \le n^d$, so

$$
p(n) \le \left(\sum_{i = 0}^{d} |a_i|\right) n^d.
$$

That is the big-O half, with $c_2 = \sum_{i = 0}^{d} |a_i|$ and $n_0$ still to be raised if the lower bound needs it. For the lower bound, separate the leading term:

$$
p(n) \ge a_d n^d - \sum_{i = 0}^{d - 1} |a_i| \, n^i
  \ge a_d n^d - \left(\sum_{i = 0}^{d - 1} |a_i|\right) n^{d - 1}
  = n^d \left( a_d - \frac{1}{n} \sum_{i = 0}^{d - 1} |a_i| \right).
$$

Let $A = \sum_{i < d} |a_i|$. If $A = 0$, then $p(n) = a_d n^d$ and $c_1 = a_d$ works for every $n \ge 1$. If $A > 0$, choose an integer

$$
n_0 = \max\left(1,\; \left\lceil \frac{2A}{a_d} \right\rceil\right).
$$

For $n \ge n_0$, $A/n \le a_d / 2$, so $p(n) \ge (a_d / 2) \, n^d$. Thus $c_1 = a_d / 2$ and $c_2 = \sum_{i = 0}^{d} |a_i|$ witness $\Theta(n^d)$. $\square$

## 9.2 Substitution, and how the constant is chosen

The **substitution method** has three moves. Guess a bound. Prove the guess by induction on the argument. While doing that, choose the constants so the inductive step closes and the base case is true. A guess can fail in two different ways, and they ask for different repairs.

- The inductive step produces an extra positive term that no choice of the leading constant can absorb. The shape of the guess is wrong.
- The inductive step closes for every constant, or for every sufficiently large constant, but the base case is false for the constant you picked. Keep the shape and change the constant, or strengthen the inductive claim by subtracting a lower-order term.

**Lemma (Choosing the constant).** Let $T(1) = 1$ and, for every power of $2$ with $n \ge 2$,

$$
T(n) = 2T(n/2) + 1.
$$

Then $T(n) = 2n - 1$ for every power of $2$, $n \ge 1$. In particular $T(n) \le 2n$. A direct induction of the claim $T(n) \le 2n$ does not go through, even though the claim is true. The subtracted term is what makes the induction close.

**Proof of the exact formula.** Induction on the exponent of $n = 2^m$.

Base $n = 1$: $2 \cdot 1 - 1 = 1 = T(1)$.

Assume $T(n/2) = 2 \cdot (n/2) - 1 = n - 1$, where $n \ge 2$ is a power of $2$. Then

$$
T(n) = 2(n - 1) + 1 = 2n - 2 + 1 = 2n - 1.
$$

**The naive upper bound.** The inequality $2n - 1 \le 2n$ shows $T(n) \le 2n$ is true. Try to prove $T(n) \le 2n$ by induction directly. The base $n = 1$ holds: $1 \le 2$. The inductive step assumes $T(n/2) \le 2 \cdot (n/2) = n$ and concludes

$$
T(n) = 2T(n/2) + 1 \le 2n + 1,
$$

which is not $\le 2n$. The extra $+1$ is never absorbed. The induction is stuck, not the truth.

**The repaired claim.** Prove the stronger statement $T(n) \le 2n - 1$, which is the exact formula already proved. Seen as a repair rather than as an identity: guess $T(n) \le cn - 1$ and choose $c$. The inductive step gives

$$
T(n) \le 2\left(c \cdot \frac{n}{2} - 1\right) + 1 = cn - 2 + 1 = cn - 1,
$$

for every $c$. The step imposes no restriction on $c$. The base $T(1) = 1 \le c - 1$ forces $c \ge 2$. The choice $c = 2$ is the smallest constant that survives the base, and it is the constant in the exact formula. This is the pattern: write a claim strong enough that the extra term produced by the recurrence is cancelled by the term you subtracted, then use the base case to pick the leading constant. $\square$

## 9.3 The mergesort-shaped recurrence

Mergesort, whose procedure is Lecture 06, splits an array of $n$ elements into two halves, sorts each half, and combines the two sorted halves in $\Theta(n)$ word operations. This lecture does not write that procedure. It solves the recurrence that those three sentences produce. On powers of $2$ the halves are exact, and the combine cost may be taken as exactly $n$ once the hidden constant inside $\Theta(n)$ is scaled into the unit of cost. The normalized recurrence is

$$
T(1) = 1, \qquad T(n) = 2T(n/2) + n \quad \text{for } n = 2^m,\; m \ge 1.
$$

**Recursion tree.** The tree is a counting argument on powers of $2$, not a picture used in place of a count. For $n = 2^m$ the root has non-recursive cost $n$. It has two children of size $n/2$, four grandchildren of size $n/4$, and so on. Level $i$, for $0 \le i \le m - 1$, contains $2^i$ nodes, each of size $n/2^i$, and each contributes non-recursive cost $n/2^i$. The level costs

$$
2^i \cdot \frac{n}{2^i} = n.
$$

There are $m$ such levels, numbered $0$ through $m - 1$, for a total of $mn$. Level $m$ is $n$ leaves, and each leaf is a base case $T(1) = 1$, contributing $n \cdot 1 = n$. No non-recursive "$+ \, n$" is added on top of a leaf, because the recurrence equation is only the case $n > 1$. Therefore

$$
T(n) = mn + n = n \log n + n,
$$

since $m = \log n$. For $n = 8$, so $m = 3$, the level costs are $8 + 8 + 8$ and the leaves contribute $8$:

```text
level 0:                 [8]                     cost 8
level 1:           [4]         [4]               cost 8
level 2:       [2]   [2]   [2]   [2]             cost 8
leaves:     1  1  1  1  1  1  1  1               cost 8
                                            total 32
```

The same number falls out of the formula: $8 \cdot 3 + 8 = 32$. The laboratory evaluates the recurrence and requires $32$.

**Theorem (Halving recurrence with linear work).** With $T$ defined above, $T(n) = n \log n + n$ for every power of $2$, $n \ge 1$. Consequently, on those powers with $n \ge 2$,

$$
n \log n \le T(n) \le 2n \log n,
$$

so $T(n) = \Theta(n \log n)$ with $c_1 = 1$, $c_2 = 2$, and $n_0 = 2$.

**Proof.** Induction on $m$, where $n = 2^m$.

Base $m = 0$, $n = 1$: $1 \cdot \log 1 + 1 = 1 = T(1)$.

Assume the formula holds at $n/2$, with $n \ge 2$ a power of $2$. Then $\log(n/2) = \log n - 1$ and

$$
\begin{aligned}
T(n/2)
  &= \frac{n}{2} \log \frac{n}{2} + \frac{n}{2}
   = \frac{n}{2}(\log n - 1) + \frac{n}{2}
   = \frac{n}{2}\log n - \frac{n}{2} + \frac{n}{2}
   = \frac{n}{2}\log n.
\end{aligned}
$$

Hence

$$
T(n) = 2 \cdot \frac{n}{2}\log n + n = n \log n + n.
$$

For the $\Theta$ bounds, take $n \ge 2$, so $\log n \ge 1$. The exact formula gives $T(n) = n \log n + n \ge n \log n$, and

$$
T(n) = n \log n + n \le n \log n + n \log n = 2n \log n,
$$

because $n \le n \log n$. $\square$

**A guess that cannot be repaired by a constant.** Suppose one guesses $T(n) \le cn$. The inductive step produces

$$
T(n) \le 2 \cdot c \cdot \frac{n}{2} + n = cn + n,
$$

and $cn + n \le cn$ is false for every $c$ and every $n > 0$. No larger $c$ helps. The guess is the wrong shape. The exact formula shows why: $n \log n + n$ is not $O(n)$, because $n \log n + n \le cn$ rearranges to $\log n + 1 \le c$ for every large power of $2$.

**Proving only the upper bound, and where the base case stops.** The claim $T(n) \le 2n \log n$ is false at $n = 1$: the right-hand side is $0$ and the left-hand side is $1$. Start the induction at $n = 2$, and apply the inductive hypothesis only when the half is still at least $2$.

Base $n = 2$: $T(2) = 2 \cdot T(1) + 2 = 4$, and $2 \cdot 2 \cdot \log 2 = 4$.

Inductive step, $n \ge 4$ a power of $2$, so $n/2 \ge 2$. Assume $T(n/2) \le 2 \cdot (n/2) \cdot \log(n/2) = n(\log n - 1) = n \log n - n$. Then

$$
T(n) \le 2(n \log n - n) + n = 2n \log n - 2n + n = 2n \log n - n \le 2n \log n.
$$

The constant $2$ is forced by the base $n = 2$ together with the spare $-n$ in the step, which is more than enough. The same constant fails at $n = 1$, so $n_0 = 2$ is part of the statement, not an ornament.

The Master Theorem, stated below, gives $T(n) = \Theta(n \log n)$ for the floor-and-ceiling form on all $n$. That citation is not a second proof of the identity just proved. The identity is the proof on powers of $2$.

## 9.4 A recurrence the divide-and-conquer shape does not cover

**Corollary (Subtractive recurrence).** Let $T(0) = 0$ and $T(n) = T(n - 1) + n$ for every integer $n \ge 1$. Then

$$
T(n) = \frac{n(n + 1)}{2}.
$$

**Proof.** Unfold the recurrence:

$$
T(n) = n + (n - 1) + \cdots + 1 + T(0) = \sum_{k = 1}^{n} k.
$$

The arithmetic-series theorem supplies the closed form. The same identity by induction, for use as a pattern: the base $n = 0$ is $0 = 0$. If $T(m) = m(m + 1)/2$, then

$$
T(m + 1) = \frac{m(m + 1)}{2} + (m + 1) = \frac{(m + 1)(m + 2)}{2}
$$

by the same algebra as the inductive step of the arithmetic series. $\square$

This recurrence is not $T(n) = aT(n/b) + f(n)$. The subproblem is smaller by $1$, not by a constant factor. The Master Theorem says nothing about it. Unfolding into a sum is the method that does.

The total copy count of $n$ unary increments, $\sum_{i = 0}^{n - 1} i = (n - 1)n/2$, is this corollary shifted by one index, or the arithmetic series stopped at $n - 1$.

## 9.5 The constant-work halving recurrence

Binary search, whose correctness proof and code are Lecture 05, compares a key with the middle element of a sorted array and then continues on one of the two halves. One comparison and one recursive call on $\lfloor n/2 \rfloor$ elements produce

$$
T(1) = c, \qquad T(n) = T(\lfloor n/2 \rfloor) + c \quad \text{for } n \ge 2,
$$

where $c > 0$ is the constant cost of the work outside the recursive call. This lecture does not implement the search. It solves the recurrence.

**Lemma (Constant-work halving).** For every integer $n \ge 1$,

$$
T(n) = c\bigl(\lfloor \log n \rfloor + 1\bigr).
$$

For every $n \ge 2$, $\log n \le T(n)/c \le 2\log n$, so $T(n) = \Theta(\log n)$.

**Proof.** First a fact about floors. Let $n \ge 2$ and let $m = \lfloor \log n \rfloor$, so $m \ge 1$ and $2^m \le n \le 2^{m + 1} - 1$. Then

$$
2^{m - 1} \le \lfloor n/2 \rfloor \le 2^m - 1,
$$

because $n \ge 2^m$ implies $\lfloor n/2 \rfloor \ge \lfloor 2^m / 2 \rfloor = 2^{m - 1}$, and $n \le 2^{m + 1} - 1$ implies $\lfloor n/2 \rfloor \le \lfloor (2^{m + 1} - 1)/2 \rfloor = 2^m - 1$. Therefore $\lfloor \log \lfloor n/2 \rfloor \rfloor = m - 1 = \lfloor \log n \rfloor - 1$.

Now induct on $n$. The base $n = 1$ is $c(\lfloor \log 1 \rfloor + 1) = c$. Assume the formula holds for every positive integer smaller than $n$, where $n \ge 2$. Then

$$
\begin{aligned}
T(n)
  &= T(\lfloor n/2 \rfloor) + c
   = c\bigl(\lfloor \log \lfloor n/2 \rfloor \rfloor + 1\bigr) + c
   = c\bigl((\lfloor \log n \rfloor - 1) + 1\bigr) + c
   = c\bigl(\lfloor \log n \rfloor + 1\bigr).
\end{aligned}
$$

For $n \ge 2$, $\log n \ge 1$, and the doubling-loop comparison of Part 8 gives $\log n \le \lfloor \log n \rfloor + 1 \le 2\log n$. Multiply by the positive constant $c$. $\square$

## 9.6 The Master Theorem

The theorem in this section is stated, not proved. CLRS, 4th edition, Theorem 4.1, is the statement used here. Its proof for a continuous variant is the starred Section 4.6 of that edition; this lecture does not reproduce it. What this lecture does prove is the arithmetic that checks the hypotheses on each application.

CLRS writes $\lg$ where this course writes $\log$. The two symbols are the same function. The 3rd edition's Theorem 4.1 has the same cases 1 and 3, but its case 2 is only the subcase $k = 0$ below. Under that narrower statement, a factor of $\log n$ in the driving function falls into a gap. Under the 4th-edition statement, that factor is case 2. The gap example solved in Section 9.8 is outside both statements.

**Theorem (stated) (Master theorem, CLRS 4th edition).** Let $a > 0$ and $b > 1$ be constants, and let $f(n)$ be a driving function, defined and nonnegative for all sufficiently large reals. Suppose $T(n)$ is defined on the nonnegative integers by

$$
T(n) = aT(n/b) + f(n),
$$

where $aT(n/b)$ means $a' T(\lfloor n/b \rfloor) + a'' T(\lceil n/b \rceil)$ for some constants $a' \ge 0$ and $a'' \ge 0$ with $a = a' + a''$, and where $T$ is constant on a finite set of base sizes. Write the **watershed** function as $n^{\log_b a}$. Then:

1. If $f(n) = O(n^{\log_b a - \varepsilon})$ for some constant $\varepsilon > 0$, then $T(n) = \Theta(n^{\log_b a})$.
2. If $f(n) = \Theta(n^{\log_b a} \log^k n)$ for some constant $k \ge 0$, then $T(n) = \Theta(n^{\log_b a} \log^{k + 1} n)$.
3. If $f(n) = \Omega(n^{\log_b a + \varepsilon})$ for some constant $\varepsilon > 0$, and if $f$ satisfies the **regularity condition** that $a f(n/b) \le c f(n)$ for some constant $c < 1$ and all sufficiently large $n$, then $T(n) = \Theta(f(n))$.

In every application below, $a$ is a positive integer and the $a$ subproblems have the same size, so $a' + a'' = a$ is just "$a$ recursive calls." The phrase $\log^k n$ means $(\log n)^k$, not $\log(\log(\cdots n))$.

The watershed is the leaf contribution of the recursion tree: there are $\Theta(n^{\log_b a})$ leaves if each leaf costs $\Theta(1)$. Case 1 says the leaves dominate, and the driving function is smaller by a polynomial factor $n^{\varepsilon}$. Case 2 says the levels are equal up to a polylogarithmic factor, so the $\Theta(\log n)$ levels contribute one extra logarithm. Case 3 says the root dominates, provided the level costs actually shrink by a constant factor. That proviso is regularity. Polynomial separation alone does not replace it in the statement of the theorem.

The three cases leave two gaps. Between cases 1 and 2, $f$ may be $o$ of the watershed without being polynomially smaller. Between cases 2 and 3, $f$ may be larger than every polylogarithmic multiple of the watershed without being polynomially larger. Section 9.8 solves a recurrence in the first of those gaps. A driving function that oscillates, larger than the watershed on some infinite set and smaller on another, is also outside the theorem; the functions in this lecture do not oscillate.

**Lemma (A polynomial never lands in the gap).** Let $a \ge 1$ and $b \ge 2$ be integers, and let $f$ be a polynomial of degree $k \ge 0$ with positive leading coefficient. Compare $b^k$ with $a$.

- If $b^k < a$, then case 1 applies, and $T(n) = \Theta(n^{\log_b a})$.
- If $b^k = a$, then case 2 applies with the exponent $k$ of the logarithm equal to $0$, and $T(n) = \Theta(n^k \log n)$.
- If $b^k > a$, then the polynomial-separation hypothesis of case 3 holds. For a monomial $f(n) = n^k$, regularity holds with room to spare. For a general polynomial of degree $k$ with positive leading coefficient, regularity holds for all sufficiently large $n$. In both situations $T(n) = \Theta(n^k)$.

No such polynomial falls in either gap.

**Proof.** The map $x \mapsto b^x$ is strictly increasing for $b > 1$, and $b^{\log_b a} = a$. Therefore $b^k < a$ if and only if $k < \log_b a$, and likewise for equality and for $>$. By the polynomial lemma, $f(n) = \Theta(n^k)$.

If $k < \log_b a$, set $\varepsilon = \log_b a - k > 0$. Then $f(n) = \Theta(n^k) = O(n^{\log_b a - \varepsilon})$, which is case 1.

If $k = \log_b a$, then $f(n) = \Theta(n^{\log_b a} \log^0 n)$, which is case 2 with the polylogarithmic exponent $0$. The conclusion is $\Theta(n^k \log^{1} n)$.

If $k > \log_b a$, set $\varepsilon = k - \log_b a > 0$. Then $f(n) = \Omega(n^{\log_b a + \varepsilon})$. It remains to check regularity, and then case 3 says $T(n) = \Theta(f(n)) = \Theta(n^k)$.

For the monomial $f(n) = n^k$ with $n > 0$,

$$
a f(n/b) = a \left(\frac{n}{b}\right)^k = \frac{a}{b^k} n^k.
$$

The hypothesis $b^k > a$ says that $\rho = a/b^k$ satisfies $0 < \rho < 1$. Regularity holds for every $n > 0$ with this constant $\rho$.

For a general polynomial, write $f(n) = n^k q(n)$ where

$$
q(n) = a_k + \frac{a_{k - 1}}{n} + \cdots + \frac{a_0}{n^k}, \qquad a_k > 0.
$$

Let $\rho = a/b^k < 1$ and let $\delta = (1 - \rho)/(2(1 + 3\rho))$, so $0 < \delta < 1$. Choose $n_1$ large enough that for every real $x \ge n_1 / b$ one has $|q(x) - a_k| \le \delta a_k$, which is possible because each lower term has a positive power of $x$ in the denominator. Then for $n \ge n_1$,

$$
a_k(1 - \delta) \le q(n) \le a_k(1 + \delta), \qquad a_k(1 - \delta) \le q(n/b) \le a_k(1 + \delta),
$$

and

$$
\frac{a f(n/b)}{f(n)}
  = \rho \cdot \frac{q(n/b)}{q(n)}
  \le \rho \cdot \frac{1 + \delta}{1 - \delta}.
$$

Let $L = (1 + \rho)/(2\rho) > 1$. The inequality $(1 + \delta)/(1 - \delta) \le L$ rearranges, for $0 < \delta < 1$, to $\delta \le (L - 1)/(L + 1)$. Now

$$
L - 1 = \frac{1 + \rho}{2\rho} - 1 = \frac{1 - \rho}{2\rho}, \qquad
L + 1 = \frac{1 + \rho}{2\rho} + 1 = \frac{1 + 3\rho}{2\rho},
$$

so

$$
\frac{L - 1}{L + 1} = \frac{1 - \rho}{1 + 3\rho}.
$$

The $\delta$ chosen above is half of that quantity, so $(1 + \delta)/(1 - \delta) \le L$. Therefore

$$
\frac{a f(n/b)}{f(n)} \le \rho \cdot \frac{1 + \rho}{2\rho} = \frac{1 + \rho}{2} < 1.
$$

Regularity holds with constant $c = (1 + \rho)/2$. The three comparisons of $b^k$ with $a$ exhaust the integers $k$, so a polynomial has no remaining case to fall into a gap. $\square$

The laboratory function `masterCasePolynomial` implements exactly the comparison of $b^k$ with $a$. It returns a case number. It does not prove the theorem, and it does not accept a driving function such as $n/\log n$, which is not a polynomial.

## 9.7 Three applications

**Binary search, case 2.** The recurrence of Section 9.5 has $a = 1$, $b = 2$, and $f(n) = \Theta(1)$. The watershed exponent is $\log_2 1 = 0$, because $2^0 = 1$. So $n^{\log_b a} = n^0 = 1$, and $f(n) = \Theta(n^0 \log^0 n)$. Case 2 with $k = 0$ gives $T(n) = \Theta(\log n)$. This agrees with the lemma already proved. The lemma is the proof. The case check is the pattern you will reuse when a later lecture cites the theorem.

A common slip is to treat $\log_b 1$ as undefined. It is $0$.

**Mergesort, case 2.** The recurrence $T(n) = 2T(n/2) + \Theta(n)$ has $a = 2$, $b = 2$, and watershed $n^{\log_2 2} = n$. The driving function is $\Theta(n) = \Theta(n \log^0 n)$. Case 2 gives $\Theta(n \log n)$, in agreement with the theorem of Section 9.3 on powers of $2$.

**A polynomial-larger driving function, case 3.** Consider $T(n) = 2T(n/2) + n^2$. Here $a = 2$, $b = 2$, and the watershed is $n$. The driving function $n^2$ is larger by the polynomial factor $n^{1}$, so the case-3 separation holds with $\varepsilon = 1$: $n^2 = \Omega(n^{1 + 1})$. Regularity:

$$
a f(n/b) = 2 \left(\frac{n}{2}\right)^2 = 2 \cdot \frac{n^2}{4} = \frac{1}{2} n^2.
$$

The constant $c = 1/2 < 1$ works for every $n > 0$. Case 3 gives $T(n) = \Theta(n^2)$. The same conclusion is the monomial row of the polynomial lemma's case division, since $b^k = 2^2 = 4 > 2 = a$.

**A case-1 example whose watershed exponent is not an integer.** The numbers $a = 7$, $b = 2$, and $f(n) = n^2$ are the shape of the recurrence for Strassen's matrix-multiplication algorithm. This course does not derive that algorithm. The classification is only an exercise in the hypotheses. Since $2^2 = 4 < 7$, one has $2 < \log_2 7$, so $\varepsilon = \log_2 7 - 2 > 0$ and $n^2 = O(n^{\log_2 7 - \varepsilon})$. Case 1 gives $T(n) = \Theta(n^{\log_2 7})$. The laboratory reports the case number for these parameters and does not approximate $\log_2 7$ by a floating-point division.

**What the 4th-edition case 2 adds.** For $T(n) = 2T(n/2) + n \log n$, the watershed is $n$ and $f(n) = \Theta(n \log^1 n)$. Case 2 with $k = 1$ gives $\Theta(n \log^{2} n)$. The 3rd-edition statement does not include $k = 1$, so under that statement this driving function is in the gap and the theorem must not be quoted. Under the statement used in this lecture, it is case 2. The solution is the theorem's conclusion, not an independent proof.

## 9.8 A gap recurrence, solved by induction

The recurrence

$$
T(2) = 2, \qquad T(n) = 2T(n/2) + \frac{n}{\log n}
$$

for $n = 2^m$ and $m \ge 2$, is a Master-Theorem recurrence with $a = 2$, $b = 2$, watershed $n$, and driving function $f(n) = n/\log n$. It meets none of the three cases.

- Not case 1. If $n/\log n = O(n^{1 - \varepsilon})$ for some $\varepsilon > 0$, then $n^{\varepsilon} = O(\log n)$, so $\log n = \Omega(n^{\varepsilon})$, contradicting $\log n = o(n^{\varepsilon})$ from Part 6.
- Not case 2. For every $k \ge 0$, $f(n) / (n \log^k n) = 1/\log^{k + 1} n$, which tends to $0$ and is therefore not $\Theta(1)$. The driving function is not a polylogarithmic multiple of the watershed with a nonnegative power.
- Not case 3. If $n/\log n = \Omega(n^{1 + \varepsilon})$, then $1/\log n = \Omega(n^{\varepsilon})$, which is false because the left side tends to $0$ and the right side tends to infinity.

The 3rd-edition statement rejects it for the same case-1 and case-2 reasons. This is the gap between case 1 and case 2.

**Lemma (Harmonic bounds).** Let $H_m = \sum_{k = 1}^{m} 1/k$ for an integer $m \ge 1$, and let $t = \lfloor \log m \rfloor$. Then

$$
\frac{t}{2} \le H_m \le t + 1.
$$

**Proof.** Partition $\{1, 2, \ldots, m\}$ into blocks $B_0, B_1, \ldots, B_t$ where $B_j$ is the set of integers $k$ with $2^j \le k \le \min(m, 2^{j + 1} - 1)$. These blocks are disjoint, they begin at $1$, and they end at $m$ because $m < 2^{t + 1}$, so $m \le 2^{t + 1} - 1$.

For the upper bound, every $k \in B_j$ satisfies $k \ge 2^j$, so $1/k \le 2^{-j}$. A complete block would contain $2^j$ integers, and the last block contains at most that many, so the block sums to at most $1$. There are $t + 1$ blocks, and $H_m \le t + 1$.

For the lower bound, each block $B_j$ with $0 \le j \le t - 1$ is complete: it ends at $2^{j + 1} - 1 \le 2^t - 1$, and $m \ge 2^t$, so the endpoint is at most $m$. That block has $2^j$ terms, and each term $k$ satisfies $k \le 2^{j + 1} - 1 < 2^{j + 1}$, so $1/k > 2^{-(j + 1)}$. The block sums to more than $2^j / 2^{j + 1} = 1/2$. If $t = 0$, there is no such block and the bound $H_m \ge 0$ is immediate. If $t \ge 1$, then $H_m > t/2$, hence $H_m \ge t/2$. $\square$

**Theorem (Gap recurrence).** For every integer $m \ge 1$, with $n = 2^m$,

$$
T(n) = n \, H_m = n \, H_{\log n}.
$$

For every integer $m \ge 4$,

$$
\frac{1}{4} \, n \log \log n \le T(n) \le 2 \, n \log \log n.
$$

Thus on the powers $n = 2^m$ with $m \ge 4$, one has $T(n) = \Theta(n \log \log n)$, with $c_1 = 1/4$, $c_2 = 2$, and the domain restriction just stated.

**Proof.** The exact identity is an induction on $m$. For $m = 1$, $n = 2$ and $2 \cdot H_1 = 2 \cdot 1 = 2 = T(2)$. Assume $T(2^{m - 1}) = 2^{m - 1} H_{m - 1}$. Then

$$
\begin{aligned}
T(2^m)
  &= 2 \cdot 2^{m - 1} H_{m - 1} + \frac{2^m}{m}
   = 2^m \left(H_{m - 1} + \frac{1}{m}\right)
   = 2^m H_m.
\end{aligned}
$$

The trace the laboratory checks is short enough to add by hand. $T(2) = 2$. Then

$$
\begin{aligned}
T(4) &= 2 \cdot 2 + \frac{4}{2} = 6, \\
T(8) &= 2 \cdot 6 + \frac{8}{3} = \frac{44}{3}, \\
T(16) &= 2 \cdot \frac{44}{3} + \frac{16}{4} = \frac{88}{3} + 4 = \frac{100}{3}.
\end{aligned}
$$

And $H_4 = 1 + 1/2 + 1/3 + 1/4 = 25/12$, so $16 \cdot H_4 = 400/12 = 100/3$.

For the $\Theta$ bounds, let $m \ge 2$, so $\log m \ge 1$. The harmonic lemma gives $H_m \le \lfloor \log m \rfloor + 1 \le \log m + 1 \le 2\log m$, where the last step is $1 \le \log m$. Thus $T(n) \le 2n \log m = 2n \log \log n$ for every $m \ge 2$.

For the lower bound, let $m \ge 4$, so $\log m \ge 2$. For every real $x$, $\lfloor x \rfloor > x - 1$, and therefore $\lfloor x \rfloor \ge x - 1$. Applied to $x = \log m$, this is $\lfloor \log m \rfloor \ge \log m - 1$. Combined with the harmonic lemma,

$$
H_m \ge \frac{\lfloor \log m \rfloor}{2} \ge \frac{\log m - 1}{2}.
$$

The hypothesis $\log m \ge 2$ rearranges to $(\log m - 1)/2 \ge (\log m)/4$. Therefore $H_m \ge (\log m)/4$, and $T(n) \ge (1/4) n \log \log n$. $\square$

The base constant does not change the $\Theta$ class. If $T(2) = c$ instead of $2$, the same induction produces $T(n) = n(H_{\log n} + c/2 - 1)$, and $H_m$ still tends to infinity, squeezed between two constant multiples of $\log m$. The exact formula changes. The $\Theta$ bound does not.

Akra–Bazzi recurrences, which allow subproblems of several different sizes, are CLRS 4th edition, Section 4.7. This lecture does not teach them.

---

# Part 10. Loop invariants

A **loop invariant** is a predicate that is true every time the loop test is about to be evaluated. It is the induction hypothesis of an iterative procedure. Lecture 05 extends induction to recursive procedures and to the correctness of binary search. The shape, already complete for a single loop, has three parts.

- **Initialization.** The predicate is true before the first test.
- **Maintenance.** If the predicate is true before an iteration and the body runs, it is true before the next test.
- **Termination.** The loop stops, and the predicate together with the failed test is the specification you wanted.

The termination part is where finiteness from Part 1 is used. An invariant that is true of an infinite loop does not prove that a result was returned.

## 10.1 Summing an array

Let $A[0..n-1]$ be an array of words, $n \ge 0$. The empty sum, $n = 0$, is $0$.

```text
s ← 0
i ← 0
while i < n:
    s ← s + A[i]
    i ← i + 1
```

**Invariant.** At the test, $s = \sum_{k = 0}^{i - 1} A[k]$, where the sum over an empty range is $0$, and $0 \le i \le n$.

**Initialization.** Before the loop, $s = 0$ and $i = 0$. The sum of no terms is $0$.

**Maintenance.** Suppose the invariant holds and $i < n$, so the body runs. The assignment to $s$ replaces $s$ by $s + A[i]$, which is the sum through index $i$. The assignment to $i$ then increases $i$ by $1$. The invariant's right-hand side grows by exactly the element just added. Both sides match at the next test. The upper bound $i \le n$ is preserved because the body runs only when $i \le n - 1$.

**Termination.** The variable $i$ starts at $0$ and increases by $1$ on every iteration, so after at most $n$ iterations the test $i < n$ fails, and it fails at $i = n$ rather than at some larger index. The invariant at $i = n$ says

$$
s = \sum_{k = 0}^{n - 1} A[k].
$$

That is the specification of the sum of the array. The procedure is correct, and it performs $\Theta(n)$ word additions when each $A[k]$ is a word inside the safe-integer limit and the partial sums stay inside that limit.

The trace used by the laboratory is $A = [3, 1, 4]$.

| At the test, $i$ | $s$ | Invariant, written out |
| --- | --- | --- |
| $0$ | $0$ | sum of no elements |
| $1$ | $3$ | $A[0] = 3$ |
| $2$ | $4$ | $3 + 1 = 4$ |
| $3$ | $8$ | $3 + 1 + 4 = 8$ |

The failed test is $i = 3 = n$. The returned sum is $8$.

The representation invariant of a counter, in Part 3, is a different predicate. It talks about the stored fields and must hold after every public operation. A loop invariant talks about the variables of one loop and must hold at every test. Both are invariants. They are not the same sentence.

---

# Part 11. Abuses of big-O

The notation is a quantified statement about functions. Most of the damage done with it comes from dropping a quantifier or a parameter and then comparing what remains.

**Writing $O$ for a tight bound.** From $T(n) = n \log n + n$ one may correctly write $T(n) = O(n \log n)$. One may also write $T(n) = O(n^3)$. The second sentence is true and useless as a description of the tight growth. This course writes $\Theta(n \log n)$ when both sides have been proved, and $O$ only when the claim really is one-sided. A later lecture that says "the operation is $O(n)$" is claiming an upper bound. It is not claiming that the operation takes about $n$ steps, and it is not forbidding a $\Theta(1)$ implementation.

**Dropping the input-size parameter.** "The algorithm is $O(n)$" does not say what $n$ counts. For an array, $n$ is the length. For an integer written in binary, the length is the number of bits. For a graph, a single $n$ is not enough once both the vertex count and the edge count matter. The repair is to name the parameters in the same sentence as the bound.

**Comparing $O(n)$ of different operations as if the constants were equal.** Suppose operation A costs at most $2n$ word additions and operation B costs at most $1000n$ string-hash steps, each of which reads a key of length $n$. Both can be written $O(n^2)$ or, in the first case, $O(n)$, and the symbols do not say that the operations are equally fast. Even inside the word RAM, $3n + 2 = \Theta(n)$ and $1000n = \Theta(n)$ are the same $\Theta$ class and not the same cost. The definitions exist in order to delete constant factors when the question is growth. They do not license putting the constants back as $1$ when the question is which procedure is faster at a stated $n$. Part 1 kept the constants $2$ and $50$ precisely because that comparison was about a stated $n$.

**Reading a little-o as a big-O, or the reverse.** $n = O(n)$ is true. $n = o(n)$ is false, by Example 6 of Part 5. An algorithm whose cost is $\Theta(n)$ is not $o(n)$.

**A finite plot as a proof.** The table in Part 6 is evidence one can see. The proof of the hierarchy is the chain of little-o arguments. A laboratory loop that checks $3n + 2 \le 5n$ for $n$ from $1$ through $1000$ confirms a witness on a finite set. The witness proof is the algebra that covers every $n \ge 1$.

---

# Laboratory

The traces below use the same numbers as the program. Do them before you read the program. A finite loop inside the program is a check, not a proof of a "for all $n$" statement. The proofs are the theorems above.

## Guided traces

**Arithmetic series.** $\sum_{k = 1}^{10} k = 10 \cdot 11 / 2 = 55$.

**Sum of squares.** $\sum_{k = 1}^{10} k^2 = 10 \cdot 11 \cdot 21 / 6 = 385$. Adding the squares: $1 + 4 + 9 + 16 + 25 + 36 + 49 + 64 + 81 + 100$. Group as $55 + 36 = 91$, $91 + 49 = 140$, $140 + 64 = 204$, $204 + 81 = 285$, $285 + 100 = 385$.

**Geometric series.** For $r = 2$ and $n = 4$, the terms are $1 + 2 + 4 + 8 + 16 = 31$, and $(2^5 - 1)/(2 - 1) = 31$. For $r = 3$ and $n = 5$, the terms are $1 + 3 + 9 + 27 + 81 + 243 = 364$, and $(3^6 - 1)/(3 - 1) = 728/2 = 364$.

**Triangular loop.** For $n = 4$ the inner counts are $1 + 2 + 3 + 4 = 10$. For $n = 10$ the closed form gives $55$.

**Doubling loop.** For $n = 10$ the tested indices are $1, 2, 4, 8$, four iterations, and $\lfloor \log 10 \rfloor + 1 = 4$. For $n = 8$ the tested indices are $1, 2, 4, 8$, four iterations. For $n = 1$ there is one iteration. The loop that adds the index, on $n = 10$, stores $1 + 2 + 4 + 8 = 15 = 2^4 - 1$.

**Halving recurrence.** $T(1) = 1$, $T(2) = 4$, $T(4) = 12$, $T(8) = 2 \cdot 12 + 8 = 32$, and $8 \log 8 + 8 = 32$. The tree in Section 9.3 is this computation drawn by levels.

**Gap recurrence.** $T(16) = 100/3$, as added in Section 9.8.

**Unary counter.** Four increments from zero copy $0$, then $1$, then $2$, then $3$ marks. The total is $6$, and the value is $4$. A fresh counter after $\mathrm{add}(3)$ has value $3$ and has copied $0$ marks.

**Array sum.** On $[3, 1, 4]$ the partial sums at the tests are $0, 3, 4, 8$.

**Linear search.** On $[4, 7, 9]$ searching for $7$ compares index $0$, fails, compares index $1$, and returns $1$. Searching for $4$ returns $0$. Searching for $1$ returns `null`. Under the uniform distribution on the three positions that do occur, the comparison counts are $1 + 2 + 3 = 6$, and the mean is $2$, matching $(3 + 1)/2$.

**Master-Theorem cases for polynomials.** Compare $b^k$ with $a$.

| $a$ | $b$ | polynomial | $b^k$ against $a$ | case |
| --- | --- | --- | --- | --- |
| $2$ | $2$ | $n$ | $2 = 2$ | $2$ |
| $2$ | $2$ | $n^2$ | $4 > 2$ | $3$, regularity constant $2/4$ |
| $1$ | $2$ | $1$ | $1 = 1$ | $2$ |
| $8$ | $2$ | $1$ | $1 < 8$ | $1$ |
| $9$ | $3$ | $n^2$ | $9 = 9$ | $2$ |
| $7$ | $2$ | $n^2$ | $4 < 7$ | $1$ |

**A big-O witness on a finite range.** $3n + 2 \le 5n$ holds at $n = 1$ ($5 \le 5$) and is the algebra of Example 1. The program repeats it through $n = 1000$. That repetition is not the proof. Separately, $101^2 = 10201$ and $100 \cdot 101 = 10100$, so $101^2 > 100 \cdot 101$. This one integer is the shape of the negative example, not the contradiction that covers every candidate $c$.

## Problems

Work these before you read the program. The program does not print their answers.

1. Give $c > 0$ and $n_0 > 0$ such that $n^3 + 4n \le c \, n^3$ for every integer $n \ge n_0$. Show the algebra.
2. By hand, without the program, classify $T(n) = 4T(n/2) + n$ under the 4th-edition Master Theorem. Identify $a$, $b$, the watershed, the case, and the solution. Check regularity if you claim case 3.
3. Explain why `masterCasePolynomial` has no return value meaning "gap." Which hypothesis of the polynomial lemma does that explanation use?
4. The claim $3n + 2 \le 3n$ for every $n \ge 1$ is false. Give the smallest integer $n$ that refutes it, and say which quantifier of the big-O definition has failed if someone offers $c = 3$ and $n_0 = 1$.

---

## LABORATORY PROGRAM

```javascript
"use strict";

import assert from "node:assert/strict";

function sumFirst(n) {
  let s = 0;
  for (let k = 1; k <= n; k += 1) {
    s += k;
  }
  return s;
}

function arithmeticClosed(n) {
  return (n * (n + 1)) / 2;
}

function sumSquares(n) {
  let s = 0;
  for (let k = 1; k <= n; k += 1) {
    s += k * k;
  }
  return s;
}

function squaresClosed(n) {
  return (n * (n + 1) * (2 * n + 1)) / 6;
}

function geometricSum(r, n) {
  let s = 0;
  let p = 1;
  for (let k = 0; k <= n; k += 1) {
    s += p;
    p *= r;
  }
  return s;
}

function geometricClosed(r, n) {
  return (r ** (n + 1) - 1) / (r - 1);
}

function triangularIterations(n) {
  let s = 0;
  for (let i = 1; i <= n; i += 1) {
    for (let j = 1; j <= i; j += 1) {
      s += 1;
    }
  }
  return s;
}

function countSingle(n) {
  let s = 0;
  for (let i = 1; i <= n; i += 1) {
    s += 1;
  }
  return s;
}

function floorLog2(n) {
  if (!Number.isInteger(n) || n < 1) {
    throw new Error("n must be an integer >= 1");
  }
  let m = 0;
  let p = 1;
  while (p * 2 <= n) {
    p *= 2;
    m += 1;
  }
  return m;
}

function doublingSteps(n) {
  let t = 0;
  let i = 1;
  while (i <= n) {
    t += 1;
    i *= 2;
  }
  return t;
}

function doublingValueSum(n) {
  let s = 0;
  let i = 1;
  while (i <= n) {
    s += i;
    i *= 2;
  }
  return s;
}

function holdsUpper(f, g, c, n0, n1) {
  for (let n = n0; n <= n1; n += 1) {
    if (f(n) > c * g(n)) {
      return false;
    }
  }
  return true;
}

function masterCasePolynomial(a, b, coeffs) {
  if (!Number.isInteger(a) || a < 1) {
    throw new Error("a must be an integer >= 1");
  }
  if (!Number.isInteger(b) || b < 2) {
    throw new Error("b must be an integer >= 2");
  }
  if (coeffs.length === 0) {
    throw new Error("polynomial needs at least one coefficient");
  }
  for (let i = 0; i < coeffs.length; i += 1) {
    if (!Number.isInteger(coeffs[i])) {
      throw new Error("coefficients must be integers");
    }
  }
  let degree = coeffs.length - 1;
  while (degree > 0 && coeffs[degree] === 0) {
    degree -= 1;
  }
  if (coeffs[degree] <= 0) {
    throw new Error("leading coefficient must be positive");
  }
  let bk = 1;
  for (let i = 0; i < degree; i += 1) {
    bk *= b;
  }
  if (!Number.isSafeInteger(bk)) {
    throw new Error("b^k is outside the safe-integer limit");
  }
  let caseNumber;
  if (bk < a) {
    caseNumber = 1;
  } else if (bk === a) {
    caseNumber = 2;
  } else {
    caseNumber = 3;
  }
  return {
    caseNumber,
    degree,
    regularityNumerator: caseNumber === 3 ? a : null,
    regularityDenominator: caseNumber === 3 ? bk : null,
  };
}

function caseLabel(result) {
  if (result.caseNumber === 1) {
    return "case 1: Theta(n^(log_b a))";
  }
  if (result.caseNumber === 2) {
    return "case 2: Theta(n^" + String(result.degree) + " log n)";
  }
  return "case 3: Theta(n^" + String(result.degree) + ")";
}

class NumberCounter {
  constructor() {
    this.count = 0;
  }

  increment() {
    this.add(1);
  }

  add(k) {
    if (!Number.isInteger(k) || k < 0) {
      throw new Error("k must be an integer >= 0");
    }
    if (this.count + k > Number.MAX_SAFE_INTEGER) {
      throw new Error("safe-integer limit");
    }
    this.count += k;
  }

  reset() {
    this.count = 0;
  }

  value() {
    return this.count;
  }
}

class UnaryCounter {
  constructor() {
    this.marks = [];
    this.copies = 0;
  }

  increment() {
    this.add(1);
  }

  add(k) {
    if (!Number.isInteger(k) || k < 0) {
      throw new Error("k must be an integer >= 0");
    }
    const next = new Array(this.marks.length + k);
    for (let i = 0; i < this.marks.length; i += 1) {
      next[i] = 1;
      this.copies += 1;
    }
    for (let j = 0; j < k; j += 1) {
      next[this.marks.length + j] = 1;
    }
    this.marks = next;
  }

  reset() {
    this.marks = [];
  }

  value() {
    return this.marks.length;
  }
}

function mergesortShape(n) {
  if (n === 1) {
    return 1;
  }
  return 2 * mergesortShape(n / 2) + n;
}

function closedMergesortShape(n) {
  return n * floorLog2(n) + n;
}

function sumArrayTrace(a) {
  const partials = [0];
  let s = 0;
  for (let i = 0; i < a.length; i += 1) {
    s += a[i];
    partials.push(s);
  }
  return partials;
}

function linearSearch(a, x) {
  for (let i = 0; i < a.length; i += 1) {
    if (a[i] === x) {
      return i;
    }
  }
  return null;
}

function totalComparisons(a) {
  let total = 0;
  for (let target = 0; target < a.length; target += 1) {
    let comps = 0;
    for (let i = 0; i < a.length; i += 1) {
      comps += 1;
      if (i === target) {
        break;
      }
    }
    total += comps;
  }
  return total;
}

function gcd(a, b) {
  let x = a;
  let y = b;
  while (y !== 0) {
    const t = x % y;
    x = y;
    y = t;
  }
  return x;
}

function frac(num, den) {
  if (den === 0) {
    throw new Error("zero denominator");
  }
  if (den < 0) {
    num = -num;
    den = -den;
  }
  if (num === 0) {
    return { num: 0, den: 1 };
  }
  const g = gcd(Math.abs(num), den);
  return { num: num / g, den: den / g };
}

function addFrac(p, q) {
  return frac(p.num * q.den + q.num * p.den, p.den * q.den);
}

function mulFrac(p, q) {
  return frac(p.num * q.num, p.den * q.den);
}

function fracEqual(p, q) {
  return p.num === q.num && p.den === q.den;
}

function fracLe(p, q) {
  return p.num * q.den <= q.num * p.den;
}

function harmonicFrac(m) {
  let s = frac(0, 1);
  for (let k = 1; k <= m; k += 1) {
    s = addFrac(s, frac(1, k));
  }
  return s;
}

function gapT(m) {
  let t = frac(2, 1);
  for (let j = 2; j <= m; j += 1) {
    const n = 2 ** j;
    t = addFrac(mulFrac(frac(2, 1), t), frac(n, j));
  }
  return t;
}

for (let n = 0; n <= 100; n += 1) {
  assert.equal(sumFirst(n), arithmeticClosed(n));
  assert.equal(sumSquares(n), squaresClosed(n));
  assert.equal(Number.isSafeInteger(sumFirst(n)), true);
  assert.equal(Number.isSafeInteger(sumSquares(n)), true);
}

assert.equal(sumFirst(10), 55);
assert.equal(sumSquares(10), 385);

for (let n = 0; n <= 12; n += 1) {
  assert.equal(geometricSum(2, n), geometricClosed(2, n));
}
for (let n = 0; n <= 8; n += 1) {
  assert.equal(geometricSum(3, n), geometricClosed(3, n));
}
assert.equal(geometricSum(2, 4), 31);
assert.equal(geometricSum(3, 5), 364);

assert.equal(triangularIterations(0), 0);
assert.equal(triangularIterations(4), 10);
assert.equal(triangularIterations(10), 55);
assert.equal(triangularIterations(10), arithmeticClosed(10));
assert.equal(countSingle(10), 10);

assert.equal(doublingSteps(1), 1);
assert.equal(doublingSteps(8), 4);
assert.equal(doublingSteps(10), 4);
assert.equal(doublingSteps(10), floorLog2(10) + 1);
assert.equal(doublingValueSum(10), 15);
assert.equal(doublingValueSum(10), 2 ** (floorLog2(10) + 1) - 1);

const linear = (n) => 3 * n + 2;
const identity = (n) => n;
assert.equal(holdsUpper(linear, identity, 5, 1, 1000), true);
assert.equal(holdsUpper(linear, identity, 3, 1, 10), false);
assert.equal(101 * 101 > 100 * 101, true);

const mergesortCase = masterCasePolynomial(2, 2, [0, 1]);
assert.equal(mergesortCase.caseNumber, 2);
assert.equal(caseLabel(mergesortCase), "case 2: Theta(n^1 log n)");

const squareCase = masterCasePolynomial(2, 2, [0, 0, 1]);
assert.equal(squareCase.caseNumber, 3);
assert.equal(squareCase.regularityNumerator, 2);
assert.equal(squareCase.regularityDenominator, 4);
assert.equal(squareCase.regularityNumerator < squareCase.regularityDenominator, true);
assert.equal(caseLabel(squareCase), "case 3: Theta(n^2)");

const binarySearchCase = masterCasePolynomial(1, 2, [1]);
assert.equal(binarySearchCase.caseNumber, 2);
assert.equal(caseLabel(binarySearchCase), "case 2: Theta(n^0 log n)");

const eightCase = masterCasePolynomial(8, 2, [1]);
assert.equal(eightCase.caseNumber, 1);
assert.equal(caseLabel(eightCase), "case 1: Theta(n^(log_b a))");

const nineCase = masterCasePolynomial(9, 3, [0, 0, 1]);
assert.equal(nineCase.caseNumber, 2);
assert.equal(caseLabel(nineCase), "case 2: Theta(n^2 log n)");

const sevenCase = masterCasePolynomial(7, 2, [0, 0, 1]);
assert.equal(sevenCase.caseNumber, 1);

const withLowerTerms = masterCasePolynomial(2, 2, [3, 0, 5]);
assert.equal(withLowerTerms.caseNumber, 3);
assert.equal(withLowerTerms.degree, 2);

const constantAfterStrip = masterCasePolynomial(1, 2, [5, 0]);
assert.equal(constantAfterStrip.caseNumber, 2);
assert.equal(constantAfterStrip.degree, 0);

assert.throws(() => masterCasePolynomial(2, 2, [1, -2]));
assert.throws(() => masterCasePolynomial(2, 2, []));

assert.equal(mergesortShape(1), 1);
assert.equal(mergesortShape(2), 4);
assert.equal(mergesortShape(4), 12);
assert.equal(mergesortShape(8), 32);
assert.equal(mergesortShape(16), 80);
assert.equal(mergesortShape(8), closedMergesortShape(8));
assert.equal(mergesortShape(16), closedMergesortShape(16));

const numeric = new NumberCounter();
const unary = new UnaryCounter();
for (let i = 0; i < 4; i += 1) {
  numeric.increment();
  unary.increment();
}
assert.equal(numeric.value(), 4);
assert.equal(unary.value(), 4);
assert.equal(unary.copies, 6);
numeric.reset();
unary.reset();
assert.equal(numeric.value(), 0);
assert.equal(unary.value(), 0);

const numericAdd = new NumberCounter();
const unaryAdd = new UnaryCounter();
numericAdd.add(3);
unaryAdd.add(3);
assert.equal(numericAdd.value(), 3);
assert.equal(unaryAdd.value(), 3);
assert.equal(unaryAdd.copies, 0);

assert.deepEqual(sumArrayTrace([3, 1, 4]), [0, 3, 4, 8]);
assert.equal(linearSearch([4, 7, 9], 7), 1);
assert.equal(linearSearch([4, 7, 9], 4), 0);
assert.equal(linearSearch([4, 7, 9], 1), null);
assert.equal(totalComparisons([4, 7, 9]), 6);
assert.equal(totalComparisons([4, 7, 9]) / 3, 2);

assert.equal(Number.MAX_SAFE_INTEGER, 2 ** 53 - 1);

for (let m = 1; m <= 8; m += 1) {
  const n = 2 ** m;
  const got = gapT(m);
  const expected = mulFrac(frac(n, 1), harmonicFrac(m));
  assert.equal(fracEqual(got, expected), true);
  assert.equal(Number.isSafeInteger(got.num), true);
  assert.equal(Number.isSafeInteger(got.den), true);
}
assert.equal(fracEqual(gapT(4), frac(100, 3)), true);

for (const m of [4, 8]) {
  const n = 2 ** m;
  const logLog = floorLog2(m);
  const lower = frac(n * logLog, 4);
  const upper = frac(2 * n * logLog, 1);
  const t = gapT(m);
  assert.equal(fracLe(lower, t), true);
  assert.equal(fracLe(t, upper), true);
}

console.log("ALL TESTS PASSED");
```

---

## Common mistakes

**Wrong idea:** A bound written $O(f(n))$ has been shown to be tight.

**Correction:** $O$ is an upper bound. Tightness is $\Theta$, and it requires both $O$ and $\Omega$, or a direct two-sided witness. $n \log n + n = O(n^3)$ is true and is not the growth of that function.

**Wrong idea:** The inequality was checked for $n$ up to one thousand, so the asymptotic claim is proved.

**Correction:** A finite check confirms a witness on a finite set. The definition quantifies every integer past $n_0$. The proof is the algebra or the induction. The laboratory is written as a check for that reason.

**Wrong idea:** The inductive step simplified to the desired bound, so the proof is finished.

**Correction:** The step is conditional on the inductive hypothesis. If the base is false, the hypothesis is never available. $T(n) \le 2n \log n$ for the mergesort-shaped recurrence has a step that closes for $n \ge 4$ and a base that fails at $n = 1$. The constant and the starting index are part of the claim.

**Wrong idea:** "Average case" can be stated without saying which inputs are likely.

**Correction:** The average case is an expectation. Name the distribution. Under a different distribution the number changes. Amortized cost is not a substitute name for that expectation.

**Wrong idea:** Hashing the input string, or multiplying two $m$-bit integers, counts as one primitive step.

**Correction:** A word operation is a primitive. A string of length $m$ costs $\Omega(m)$ to read in the worst case. Schoolbook multiplication of $m$-bit integers costs $\Theta(m^2)$ bit operations.

**Wrong idea:** $T(n) = T(n - 1) + n$ is case 2 of the Master Theorem because it adds $n$.

**Correction:** The theorem requires subproblems of size $n/b$, a constant factor smaller. This recurrence shrinks by $1$. Unfold it into the arithmetic series.

**Wrong idea:** Case 3 applies as soon as $f$ is larger than the watershed, so the regularity check can be skipped.

**Correction:** The statement of case 3 includes $a f(n/b) \le c f(n)$ for some $c < 1$ and all large $n$. For the monomials in this lecture the same comparison that gives polynomial separation also gives regularity. That is a theorem about those functions, not a reason to delete the hypothesis from the statement.

**Wrong idea:** The triangular loop runs $n(n - 1)/2$ times for the bounds $i = 1$ to $n$ and $j = 1$ to $i$.

**Correction:** That count is the number of pairs with $1 \le j < i \le n$. Including $j = i$ produces $\sum_{i = 1}^{n} i = n(n + 1)/2$. For $n = 4$ the two formulas give $6$ and $10$, and the loop's inner counts are $1 + 2 + 3 + 4 = 10$.

**Wrong idea:** A loop that doubles its index is logarithmic, whatever the body does.

**Correction:** The iteration count is $\lfloor \log n \rfloor + 1$. If the body adds the current index, the values form a geometric series and the cost is $\Theta(n)$.

**Wrong idea:** $\log_{10} n$ and $\log n$ are different $\Theta$ classes, and a floating-point value of $\log a / \log b$ such as $1.999999$ decides a Master-Theorem case.

**Correction:** Change of base multiplies by the positive constant $1/\log b$, so $\log_b n = \Theta(\log n)$. For a polynomial of integer degree $k$, compare the integer $b^k$ with the integer $a$. The laboratory does that comparison and does not divide floating-point logarithms.

---

## Examination

Allow 90 minutes. Closed notes. Write full solutions. The answer key begins after this examination.

**1.** Let $g$ be asymptotically nonnegative. Write the definition of each set, with the quantifiers in order. (a) $O(g(n))$. (b) $\Omega(g(n))$. (c) $\Theta(g(n))$. (d) $o(g(n))$. (e) $\omega(g(n))$.

**2.** Let $f(n) = 5n^2 + 3n + 8$.

(a) Find constants $c > 0$ and $n_0 > 0$ such that $0 \le f(n) \le c \, n^2$ for every integer $n \ge n_0$. Show the algebra.

(b) Find constants $c > 0$ and $n_0 > 0$ such that $0 \le c \, n^2 \le f(n)$ for every integer $n \ge n_0$.

(c) Conclude a $\Theta$ statement and name the three constants.

(d) Prove that $n^2$ is not $O(n)$.

(e) Prove that $n^2 = \omega(n)$ by giving, for every $c > 0$, an $n_0$ that works.

(f) Prove that $n = o(n^2)$ by giving, for every $c > 0$, an $n_0$ that works.

**3.** In one paragraph, distinguish average-case cost from amortized cost. Use the words distribution and sequence.

**4.** (a) Name one RAM primitive and one operation that is not a primitive. (b) Why is hashing an arbitrary string of length $m$ not $\Theta(1)$ in the worst case?

**5.** (a) Write the four equations of the counter ADT. (b) After $\mathrm{make}$ and then $n$ increments, give the total cost on NumberCounter and on UnaryCounter, as $\Theta$ expressions in $n$. (c) How many words does the unary implementation copy during those $n$ increments?

**6.** For every integer $n \ge 1$, the following procedure runs its innermost statement how many times? Give the exact count as a closed form, and a $\Theta$ bound with explicit constants $c_1$, $c_2$, and $n_0$.

```text
s ← 0
for i ← 1 to n:
    for j ← i to n:
        s ← s + 1
```

**7.** For every integer $n \ge 1$, how many times does the body of the following loop run? Give the exact count, and a $\Theta$ bound with explicit constants for $n \ge 2$.

```text
t ← 0
i ← 1
while i ≤ n:
    t ← t + 1
    i ← 2 · i
```

**8.** Solve $T(n) = 2T(n/2) + n^3$ by the Master Theorem as stated in this lecture (CLRS, 4th edition, Theorem 4.1). Identify $a$, $b$, the watershed, the case, the value of $\varepsilon$ you use, the regularity constant if the case needs one, and the solution. This is an application of the stated theorem: check every hypothesis the case requires.

**9.** Let $T(1) = 1$ and $T(n) = 2T(n/2) + 4n$ for every power of $2$ with $n \ge 2$.

(a) Compute $T(2)$ and show that $T(2) \le 4 \cdot 2 \cdot \log 2$ is false.

(b) Prove by induction that $T(n) = 4n \log n + n$ for every power of $2$, $n \ge 1$.

(c) Prove $T(n) \le 5n \log n$ for every power of $2$, $n \ge 2$, by induction. Use $n = 2$ as the base. In the step for $n \ge 4$, you may assume the claim at $n/2$. Do not quote the closed form from (b) inside this induction.

(d) Deduce $T(n) = \Theta(n \log n)$ on the powers of $2$ that are at least $2$, and give $c_1$, $c_2$, and $n_0$. You may use (b) here.

**10.** Each sentence abuses the notation. Name the abuse and rewrite the sentence so that it states a true claim of the kind this lecture permits.

(a) "Binary search is $O(\log n)$, so its running time is about $\log n$."

(b) "The procedure is $O(n)$." The procedure's input has not been described.

(c) "Insertion into structure A is $O(n)$ and insertion into structure B is $O(n)$, so the two insertions are equally fast."

**11.** For the array-sum procedure of Part 10 and the array $A = [3, 1, 4]$, state the invariant, then write initialization, maintenance, and termination. Include the value of $s$ at each test, and the value returned.

---

## Answer key

**1.** (a) $O(g(n))$ is the set of $f$ for which there exist constants $c > 0$ and $n_0 > 0$ such that $0 \le f(n) \le c \, g(n)$ for every integer $n \ge n_0$.

(b) $\Omega(g(n))$ is the set of $f$ for which there exist constants $c > 0$ and $n_0 > 0$ such that $0 \le c \, g(n) \le f(n)$ for every integer $n \ge n_0$.

(c) $\Theta(g(n))$ is the set of $f$ for which there exist constants $c_1 > 0$, $c_2 > 0$, and $n_0 > 0$ such that $0 \le c_1 \, g(n) \le f(n) \le c_2 \, g(n)$ for every integer $n \ge n_0$.

(d) $o(g(n))$ is the set of $f$ for which, for every constant $c > 0$, there exists $n_0 > 0$ such that $0 \le f(n) < c \, g(n)$ for every integer $n \ge n_0$.

(e) $\omega(g(n))$ is the set of $f$ for which, for every constant $c > 0$, there exists $n_0 > 0$ such that $0 \le c \, g(n) < f(n)$ for every integer $n \ge n_0$.

**2.** (a) For every integer $n \ge 1$, $n \le n^2$ and $1 \le n^2$, so $3n \le 3n^2$ and $8 \le 8n^2$. Therefore

$$
f(n) = 5n^2 + 3n + 8 \le 5n^2 + 3n^2 + 8n^2 = 16n^2.
$$

Also $f(n) \ge 0$. The witness is $c = 16$ and $n_0 = 1$. At $n = 1$, $f(1) = 16 \le 16$.

(b) For every integer $n \ge 1$, $3n + 8 \ge 0$, so $f(n) \ge 5n^2$. The witness is $c = 5$ and $n_0 = 1$.

(c) By the Theta characterization, $f(n) = \Theta(n^2)$ with $c_1 = 5$, $c_2 = 16$, and $n_0 = 1$.

(d) Suppose $c > 0$ and $n_0 > 0$ satisfy $n^2 \le c \, n$ for every integer $n \ge n_0$. For $n \ge 1$ this is $n \le c$. The integer $n = \max(n_0, \lfloor c \rfloor + 1)$ satisfies $n \ge n_0$ and $n > c$, a contradiction. So $n^2$ is not $O(n)$.

(e) Let $c > 0$ and set $n_0 = \lfloor c \rfloor + 1$. For every integer $n \ge n_0$, $n > c$, so $n^2 > c \, n$.

(f) Let $c > 0$ and set $n_0 = \lfloor 1/c \rfloor + 1$. For every integer $n \ge n_0$, $n > 1/c$, so $n < c \, n^2$.

**3.** Average-case cost is the expectation of the cost of one run under a named probability distribution on the instances of size $n$. Amortized cost divides the total cost of a sequence of operations by the length of that sequence, and the sequence is an arbitrary one, including a worst-case sequence. A distribution on inputs is not a sequence of operations, and a worst-case sequence is not a random input. Lecture 02 proves amortized bounds. This lecture only separates the two definitions.

**4.** (a) Addition of two words is a primitive. Multiplication of two integers of $m$ bits, with $m$ growing, is not: schoolbook multiplication uses $\Theta(m^2)$ bit operations. (b) A string of length $m$ has $m$ characters. Any hash that depends on every character must read them, which is $\Omega(m)$ in the worst case.

**5.** (a) The equations are $\mathrm{value}(\mathrm{make}()) = 0$, $\mathrm{value}(\mathrm{add}(c, k)) = \mathrm{value}(c) + k$ for $k \ge 0$, $\mathrm{value}(\mathrm{increment}(c)) = \mathrm{value}(c) + 1$, and $\mathrm{value}(\mathrm{reset}(c)) = 0$.

(b) NumberCounter performs $\Theta(1)$ work per increment, so $n$ increments cost $\Theta(n)$. The $i$-th unary increment copies $i - 1$ words, and the sum of those copies is $\Theta(n^2)$, which is also the total cost.

(c) The number of copied words is $\sum_{i = 0}^{n - 1} i = n(n - 1)/2$.

**6.** For each $i$ from $1$ to $n$, the index $j$ runs through $n - i + 1$ values. Let $k = n - i + 1$. As $i$ runs from $1$ to $n$, $k$ runs from $n$ down to $1$. The exact count is

$$
\sum_{k = 1}^{n} k = \frac{n(n + 1)}{2}
$$

by the arithmetic-series theorem. For a check at $n = 5$, the inner counts are $5 + 4 + 3 + 2 + 1 = 15$, and $5 \cdot 6 / 2 = 15$.

For every integer $n \ge 1$, $n(n + 1)/2 \le n^2$ because $n + 1 \le 2n$, and $n(n + 1)/2 \ge n^2 / 2$ because $n + 1 \ge n$. So the count is $\Theta(n^2)$ with $c_1 = 1/2$, $c_2 = 1$, and $n_0 = 1$.

**7.** After $t$ successful iterations the index holds $2^t$, and the body runs while the index at the test satisfies $2^{t_{\mathrm{before}}} \le n$. The number of successful iterations is the least integer $t$ with $2^t > n$, namely $t = \lfloor \log n \rfloor + 1$. For $n = 10$ the tested values are $1, 2, 4, 8$, so $t = 4$, and $\lfloor \log 10 \rfloor + 1 = 4$. For $n = 1$, $t = 1$.

For $n \ge 2$, $\log n \ge 1$ and $\log n \le \lfloor \log n \rfloor + 1 \le \log n + 1 \le 2\log n$. The count is $\Theta(\log n)$ with $c_1 = 1$, $c_2 = 2$, and $n_0 = 2$.

**8.** Here $a = 2$, $b = 2$, and $\log_b a = 1$, so the watershed is $n$. The driving function is $f(n) = n^3$. Take $\varepsilon = 2$. Then $\log_b a + \varepsilon = 3$ and $f(n) = \Omega(n^3)$. Regularity:

$$
a f(n/b) = 2 \left(\frac{n}{2}\right)^3 = 2 \cdot \frac{n^3}{8} = \frac{n^3}{4} \le \frac{1}{4} f(n).
$$

The constant $c = 1/4 < 1$ works for every $n > 0$. Case 3 applies, and $T(n) = \Theta(n^3)$.

**9.** (a) $T(2) = 2 \cdot T(1) + 4 \cdot 2 = 2 + 8 = 10$. And $4 \cdot 2 \cdot \log 2 = 8$. Since $10 \le 8$ is false, the proposed bound is false at $n = 2$.

(b) Induction on the exponent of $n = 2^m$. Base $n = 1$: $4 \cdot 1 \cdot \log 1 + 1 = 1 = T(1)$. Assume $n \ge 2$ is a power of $2$ and the formula holds at $n/2$:

$$
\begin{aligned}
T(n/2)
  &= 4 \cdot \frac{n}{2} \cdot \log \frac{n}{2} + \frac{n}{2}
   = 2n(\log n - 1) + \frac{n}{2}
   = 2n \log n - 2n + \frac{n}{2}
   = 2n \log n - \frac{3n}{2}.
\end{aligned}
$$

Then

$$
T(n) = 2\left(2n \log n - \frac{3n}{2}\right) + 4n = 4n \log n - 3n + 4n = 4n \log n + n.
$$

Numerical check, not a substitute for the induction: $T(4) = 2 \cdot 10 + 16 = 36$ and $4 \cdot 4 \cdot 2 + 4 = 36$. $T(8) = 2 \cdot 36 + 32 = 104$ and $4 \cdot 8 \cdot 3 + 8 = 104$.

(c) Base $n = 2$: $T(2) = 10$ and $5 \cdot 2 \cdot \log 2 = 10$, so $10 \le 10$. For the step, let $n \ge 4$ be a power of $2$, and assume $T(n/2) \le 5 \cdot (n/2) \cdot \log(n/2)$. Then

$$
\begin{aligned}
T(n)
  &= 2T(n/2) + 4n
   \le 2 \cdot \frac{5n}{2} \cdot (\log n - 1) + 4n
   = 5n(\log n - 1) + 4n
   = 5n \log n - 5n + 4n
   = 5n \log n - n
   \le 5n \log n.
\end{aligned}
$$

(d) From (b), for every power of $2$ with $n \ge 2$, $\log n \ge 1$ and

$$
4n \log n \le 4n \log n + n = T(n) \le 4n \log n + n \log n = 5n \log n,
$$

where the last step uses $n \le n \log n$. Thus $c_1 = 4$, $c_2 = 5$, and $n_0 = 2$. (The constants $c_1 = 1$ and $c_2 = 5$ also work, since $4n \log n \ge n \log n$. The pair $4$ and $5$ matches the exact leading term.)

**10.** (a) The abuse is writing an $O$ upper bound as if it were a tight approximate value. A repair that this lecture has proved: the binary-search recurrence costs $\Theta(\log n)$. That statement still hides a constant factor. It does not say the cost equals $\log n$.

(b) The abuse is dropping the input-size parameter. A repair: if the input is an array of $n$ words and the procedure examines each word a constant number of times in the worst case, the worst-case cost is $\Theta(n)$, where $n$ is the length of the array.

(c) The abuse is treating two $O(n)$ statements as equal constants. A repair: both insertions are $O(n)$. The two hidden constants need not agree, and an $O(n)$ upper bound does not by itself prevent one of the insertions from being $\Theta(1)$. Equal speed is a statement about those constants at a stated $n$, not a consequence of membership in $O(n)$.

**11.** The invariant: at the test, $s = \sum_{k = 0}^{i - 1} A[k]$, with the empty sum equal to $0$, and $0 \le i \le 3$.

Initialization: $i = 0$, $s = 0$, the sum of no elements.

Maintenance, instantiated on this array. From $(i, s) = (0, 0)$ the body adds $A[0] = 3$ and advances $i$ to $1$, leaving $s = 3$. From $(1, 3)$ it adds $1$, leaving $s = 4$ at $i = 2$. From $(2, 4)$ it adds $4$, leaving $s = 8$ at $i = 3$. Each step extends the prefix sum by the element just read.

Termination: $i$ increases by $1$ from $0$, so the test $i < 3$ fails at $i = 3$. The invariant then says $s = 3 + 1 + 4 = 8$, which is the sum of the array. The procedure returns $8$.

---

## Independent assignment

Produce two files of your own, kept with your notes. Do not add them to the lecture. Budget several hours. The point of the assignment is the induction and the exact counts, written out, plus a program that checks the formulas you proved.

**Written part.**

1. Prove by induction on $n$ that for every integer $n \ge 0$,

$$
\sum_{k = 1}^{n} k^3 = \left(\frac{n(n + 1)}{2}\right)^2.
$$

The $n = 0$ sum is empty. Show the base and the algebra of the inductive step in full.

2. Analyze the three procedures below. For each, give an exact closed form where one is asked, and a $\Theta$ bound with explicit positive constants and an explicit $n_0$.

```text
Loop A, exact value of s for n ≥ 0, then a Theta bound:
s ← 0
for i ← 1 to n:
    for j ← 1 to n:
        for k ← 1 to j:
            s ← s + 1

Loop B, exact value of t for n ≥ 1, then a Theta bound:
t ← 0
i ← 1
while i ≤ n:
    t ← t + 1
    i ← 3 · i

Loop C:
s ← 0
i ← n
while i ≥ 1:
    s ← s + i
    i ← floor(i / 2)
```

For Loop C, prove an exact formula when $n$ is a power of $2$, and prove $n \le s < 2n$ for every integer $n \ge 1$.

3. Let $T(1) = 1$ and $T(n) = 3T(n/3) + n$ for $n$ a power of $3$, $n \ge 3$. Show that the guess $T(n) \le cn$ fails in the inductive step for every constant $c$. Find a closed form and prove it by induction on the exponent of $3$. Then give a $\Theta$ bound, in the course's base-$2$ logarithm, with explicit constants, using the change-of-base lemma.

**Program.** One Node.js file. The only import is `node:assert/strict`. No network, no filesystem, no `process.argv`. Assert your cube formula against a direct loop for every $n$ from $0$ through $40$. Assert your exact formulas for Loops A and B, and the power-of-two formula for Loop C, on a range of $n$ you choose and state. Assert your closed form of $T$ against a recursive or iterative evaluation at $n = 3^k$ for $k = 0, 1, \ldots, 8$. On success print exactly `ALL TESTS PASSED`.

The artifact is finished when a reader can check every algebraic step without inventing a missing line, and the program passes.

---

## Glossary

**Abstract data type.** A set of operations and equations relating their observable results, with no memory layout.

**Algorithm.** A procedure that, on every instance of a stated problem, returns a correct solution after finitely many primitive steps.

**Amortized cost.** The total cost of a worst-case sequence of operations, divided by the length of the sequence. Proved for dynamic arrays in Lecture 02. Not an average over a distribution.

**Arithmetic series.** The sum of the first $n$ positive integers, equal to $n(n + 1)/2$.

**Asymptotically nonnegative.** A function that is nonnegative for every sufficiently large integer argument. The asymptotic definitions in this lecture assume that of the bounding function.

**Average case.** The expectation of cost under a named distribution on instances of size $n$.

**Best case.** The minimum cost over instances of size $n$.

**Big-O.** The set $O(g)$ of functions bounded above by a constant times $g$, for every sufficiently large $n$. An upper bound, not a claim of tightness.

**Big-Omega.** The set $\Omega(g)$ of functions bounded below by a constant times $g$, for every sufficiently large $n$.

**Ceiling.** $\lceil x \rceil$, the least integer greater than or equal to $x$.

**Change of base.** $\log_b n = \log n / \log b$ for $b > 1$. Inside $\Theta$, the base of a logarithm is a constant factor.

**Correctness.** The procedure's output meets the problem's output rule on every instance.

**Counter.** The ADT specified in Part 3 by $\mathrm{make}$, $\mathrm{add}$, $\mathrm{increment}$, $\mathrm{reset}$, and $\mathrm{value}$.

**Data structure.** A representation and the procedures that maintain it, providing some ADT.

**Distribution.** The probability assignment on instances that an average-case claim must name.

**Driving function.** The non-recursive term $f(n)$ in $T(n) = aT(n/b) + f(n)$.

**Finite procedure.** A procedure that reaches a return after finitely many steps on every legal instance.

**Floor.** $\lfloor x \rfloor$, the greatest integer less than or equal to $x$.

**Gap (of the Master Theorem).** A driving function that is neither covered by case 1, nor by case 2, nor by case 3. In this lecture, $n/\log n$ against the watershed $n$.

**Geometric series.** The sum $\sum_{k = 0}^{n} r^k = (r^{n + 1} - 1)/(r - 1)$ for $r \ne 1$.

**Growth hierarchy.** The chain of little-o relations from $1$ through $n!$ proved in Part 6.

**Harmonic number.** $H_m = \sum_{k = 1}^{m} 1/k$.

**Initialization.** The first part of a loop-invariant argument: the predicate holds before the first test.

**Input size.** The number of words, or other named parameters, in which cost is expressed. For a binary integer, the number of bits.

**Instance.** One legal input of a problem.

**Iteration count.** The number of times a loop body executes. The iteration lemma lifts a $\Theta$ bound on that count to a $\Theta$ bound on primitive steps when each execution costs $\Theta(1)$.

**Linear search.** The scan that returns the smallest index of a value, or `null` if the value is absent.

**Little-o.** An upper bound that remains strict after the constant is made arbitrarily small. The constant is universally quantified.

**Little-omega.** A lower bound that remains strict after the constant is made arbitrarily large. The constant is universally quantified.

**Loop invariant.** A predicate true at every evaluation of a loop test. Argued by initialization, maintenance, and termination.

**Maintenance.** If the invariant holds and the body runs, the invariant holds at the next test.

**Master Theorem.** CLRS 4th edition, Theorem 4.1, stated in Part 9 and not proved here. Three cases, with a polylogarithmic case 2 and a regularity condition in case 3.

**NumberCounter.** The one-word implementation of the counter. Each operation is $\Theta(1)$ inside the safe-integer limit.

**Primitive step.** An operation the RAM model charges as one unit: word arithmetic, comparison, bitwise operations, a load or a store, one pointer hop, or the bookkeeping of one assignment, branch, or call.

**Problem.** A general question, the set of legal inputs, and the rule for a correct output.

**RAM model.** The machine model in which each primitive step costs one unit and memory is addressed in constant time.

**Recurrence.** An equation defining a function by its values on smaller arguments.

**Recursion tree.** A tree whose nodes are the non-recursive costs of a recurrence. Used here as an exact count on powers of $2$, and as the source of a guess that substitution then proves.

**Regularity condition.** The case-3 hypothesis $a f(n/b) \le c f(n)$ for some constant $c < 1$ and all sufficiently large $n$.

**Representation invariant.** A predicate about stored fields that holds after every public operation. For the unary counter: the length is the value, and every mark is $1$.

**Safe-integer limit.** $2^{53} - 1$, the largest integer JavaScript's number type represents exactly. Word-RAM arithmetic in the laboratory stays inside it.

**Substitution method.** Guess a bound, prove it by induction, and choose the constants so the step closes and the base holds.

**Sum of squares.** $\sum_{k = 1}^{n} k^2 = n(n + 1)(2n + 1)/6$.

**Termination.** The loop stops, and the invariant together with the failed test implies the specification.

**Theta.** The set $\Theta(g)$ of functions sandwiched between two positive constant multiples of $g$ for every sufficiently large $n$. The tight bound. Equivalent to being both $O(g)$ and $\Omega(g)$.

**UnaryCounter.** The counter stored as an array of $v$ marks. Increment copies $v$ words.

**Watershed.** The function $n^{\log_b a}$ in the Master Theorem, against which $f(n)$ is compared.

**Witness.** Constants $c$ and $n_0$, or $c_1$, $c_2$, and $n_0$, that make a big-O, big-Omega, or Theta definition true. For little-o and little-omega, a rule producing $n_0$ from every $c > 0$.

**Word.** A memory cell holding an integer the RAM model can operate on in one primitive step. Wide enough to hold an address into an input of $n$ words.

**Worst case.** The maximum cost over instances of size $n$.

---

## Lecture summary

A problem states the legal inputs and the required outputs. An algorithm is a procedure that meets that specification and stops. The RAM model is the machine that makes "stops after how many steps" a property of the procedure rather than of one laptop: word arithmetic and a load or a store are one step each, and a long integer multiplication or a hash of an arbitrary string is a loop, not a step.

The counter equations do not choose a representation. One word makes $n$ increments cost $\Theta(n)$. Unary marks make the same $n$ increments copy $n(n - 1)/2$ words. Linear search shows why the case matters: best case $\Theta(1)$, worst case $\Theta(n)$, and average case $(n + 1)/2$ only under the uniform distribution that was named.

$O$, $\Omega$, and $\Theta$ each existentially quantify a constant and a threshold. Little-o and little-omega universally quantify the constant. The hierarchy $1$, $\log n$, $n$, $n \log n$, $n^2$, $n^3$, $2^n$, $n!$ is a chain of little-o proofs, not a reading of one plot. Loops become the arithmetic series, the sum of squares, or the geometric series, and those closed forms are theorems. Recursive costs become recurrences. Substitution proves them when the constant is chosen so the base exists and the step cancels. The Master Theorem, in the 4th-edition three-case form, dispatches $T(n) = aT(n/b) + f(n)$ when a case's hypotheses hold, and it is silent on $T(n) = T(n - 1) + n$ and on $T(n) = 2T(n/2) + n/\log n$. The second of those is $n H_{\log n}$ on powers of $2$, which is $\Theta(n \log \log n)$. A loop is correct when its invariant is initialized, maintained, and read off at termination.

### Five principles

1. Charge primitive steps of the RAM model. A word operation is one step. Reading a string, or multiplying integers that do not fit in a word, is as many steps as the data require.
2. Write the ADT as operations and equations first. A second implementation is allowed to have a different cost and must not have a different observable value.
3. Attach quantifiers to every bound. Use $\Theta$ when both sides are proved, and name what $n$ counts.
4. Convert a loop into a sum and a recursive procedure into a recurrence, then prove the closed form. A recursion tree is a count or a guess, and the induction is the proof.
5. Name the case. Worst case is a maximum. Average case is an expectation under a stated distribution. Amortized cost, which Lecture 02 proves, is an average over a worst-case sequence.

---

## References

Cormen, Thomas H., Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapters 1 through 4. The Master Theorem applied in this lecture is Theorem 4.1 of that edition. Section 4.6 proves a continuous variant. Section 4.7 states the Akra–Bazzi method, which this lecture does not teach.

Cormen, Thomas H., Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 3rd edition. MIT Press, 2009. Chapter 4. Cited for the narrower case 2 of Theorem 4.1, the form without a polylogarithmic factor. This lecture uses the 4th-edition statement.

Graham, Ronald L., Donald E. Knuth, and Oren Patashnik. *Concrete Mathematics*. 2nd edition. Addison-Wesley, 1994. Chapter 2, on sums. The arithmetic and geometric series are proved in this lecture; that chapter is the extended account.

Liskov, Barbara, and Stephen Zilles. "Programming with Abstract Data Types." *Proceedings of the ACM SIGPLAN Symposium on Very High Level Languages*, 1974. Cited for the separation of an abstract specification from a representation. The counter and its two implementations are the lecture's own example.


