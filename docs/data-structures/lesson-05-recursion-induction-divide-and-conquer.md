# DATA STRUCTURES AND ALGORITHM ANALYSIS

## LECTURE 05 — RECURSION, INDUCTION, AND DIVIDE-AND-CONQUER

**Course:** Data Structures and Algorithm Analysis
**Section:** JOB Core · Data Structures
**Lecture:** 05 of 14
**Academic level:** Undergraduate computer science, self-study, equivalent to a CS2 / algorithms-core semester
**Recommended study time:** 8 hours
**Prerequisites:** Lecture 01 — Models, ADTs, and Asymptotic Analysis; Lecture 04 — Stacks, Queues, and Deques (the call stack)
**Primary references:** Cormen, Leiserson, Rivest, and Stein, *Introduction to Algorithms*, 4th edition, Chapters 2 and 4; Goodrich, Tamassia, and Goldwasser, *Data Structures and Algorithms in Java*, 6th edition, Chapter 5; Sedgewick and Wayne, *Algorithms*, 4th edition, Section 1.1; Weiss, *Data Structures and Algorithm Analysis in C++*, 4th edition, Chapter 1; Graham, Knuth, and Patashnik, *Concrete Mathematics*, 2nd edition, Chapter 1; Bentley, *Programming Pearls*, 2nd edition, Column 4

**This lecture owns:** how to write and prove recursive algorithms, mathematical induction as used in this course, binary search, and the divide-and-conquer pattern.
**This lecture does not teach:** mergesort or quicksort code, dynamic programming, linked-list reversal, or tail-call elimination as something a program may depend on. A divide-and-conquer recurrence for sorting is set up and left to Lecture 06.

---

## 1. Learning objectives

After this lecture you should be able to do each of the following on paper and in a short JavaScript program.

1. Write a recursive function and an iterative function for factorial and for the sum of an array, and name a nonnegative integer measure that decreases on every recursive call.
2. Draw every stack frame of a recursive factorial, including the pending multiplication, and state the maximum depth and the stack-space cost.
3. Decide whether a call is in tail position, rewrite factorial with an accumulator so that the call is in tail position, and state the stack cost of that function in Node.js.
4. Write a weak induction and a strong induction, and choose the form that matches a recursion whose calls are only on $n-1$ or whose calls are on subproblems of several smaller sizes.
5. Prove $\sum_{k=1}^{n} k = n(n+1)/2$ by induction, and prove that the recursive array sum returns the sum of the subarray it is given.
6. Implement iterative and recursive binary search, including the first occurrence of a duplicate key, and prove correctness from the closed-interval invariant, the sortedness precondition, and termination.
7. Solve the worst-case recurrence $W(n) = 1 + W(\lfloor n/2 \rfloor)$ with the floor kept visible, and conclude that the worst-case running time of binary search is $\Theta(\log n)$.
8. State divide-and-conquer as divide, solve, combine; implement integer power by squaring; prove the value and the exact multiplication count.
9. Derive the Tower of Hanoi recurrence $T(n) = 2T(n-1) + 1$, prove $T(n) = 2^n - 1$ by induction, and prove that $2^n - 1$ moves are necessary.
10. Generate every subset of an $n$-element set by include-or-exclude, draw the recursion tree, and prove that it has $2^n$ leaves and $2^{n+1}-1$ calls.
11. Classify a broken recursion as a wrong base value, a measure that does not decrease, or a combine step that uses a postcondition the recursive calls did not establish.

---

## 2. Purpose of this lecture

A recursive algorithm names its answer in terms of answers to smaller instances of the same problem. That sentence is a definition, not yet a method. The method has three obligations: a base case that does not call itself, a recursive case that calls only smaller instances, and a measure that makes "smaller" a finite descent. Induction is the proof technique that matches this shape. Divide-and-conquer is the design pattern in which the smaller instances are a fixed number of substantial pieces of the input, solved independently and then combined.

Lecture 01 gave the RAM model, $\Theta$/$O$/$\Omega$ notation, summation, loop analysis, substitution, and the Master Theorem. This lecture uses those tools and does not rebuild them. Lecture 04 gave the stack abstract data type and the call stack as the stack of activation records the language uses when one function calls another. This lecture uses that stack as the concrete machine on which a recursive call is stored. It does not rebuild stacks, queues, or the shunting-yard algorithm.

The eight hours break cleanly.

| Sitting | Work |
| --- | --- |
| 1 | Sections 3 through 5, with the factorial frames drawn by hand |
| 2 | Sections 6 and 7, writing both induction proofs without looking |
| 3 | Sections 8 and 9, including the binary-search trace and the power trace |
| 4 | Sections 10 through 13, then the laboratory program |
| 5 | The examination closed, then the answer key, then the independent assignment |

Binary search is taught here in full, code and proof, because its correctness is an invariant argument and its cost is a one-sided recurrence. Sorting by merging is the same pattern with a real combine step. This lecture writes the recurrence $T(n) = 2T(\lfloor n/2 \rfloor) + \Theta(n)$ and stops. Lecture 06 owns mergesort, quicksort, and the solution of that recurrence.

One numeric convention from Lecture 01 is used on every page: $\log$ means $\log_2$, $\ln$ means the natural logarithm, and a bound written $\Theta(f(n))$ is tight. Arrays are 0-indexed. The implementation language is JavaScript, with ordinary numbers. A safe integer is an integer $z$ with $|z| \le 2^{53}-1 = 9007199254740991$. Every integer in that range is represented exactly, and adding or subtracting $1$ yields the next integer. Outside that range, a JavaScript number may still be an exact integer (powers of two remain exact much further), but it is no longer safe. The text states which results are safe.

---

## 3. Recursive definitions

### 3.1 Base case, recursive case, and a measure

**Definition.** A *recursive definition* of a function $f$ gives $f(x)$ in one of two ways.

- A *base case* gives the value directly, with no reference to $f$.
- A *recursive case* gives the value by using $f$ at one or more arguments other than $x$.

A definition written in that shape can still be circular. If the recursive case refers to $f(x)$ itself, or to a value that eventually refers back to $f(x)$, the sentence has not named a unique value. The missing piece is a measure.

**Definition.** A *measure* for a recursive definition is a function $m$ from the legal arguments to the nonnegative integers such that every recursive call uses an argument $y$ with $m(y) < m(x)$, where $x$ is the argument of the caller.

The nonnegative integers under the usual order are *well-founded*: every strictly decreasing sequence is finite, because a sequence of nonnegative integers cannot descend forever. Therefore a call that decreases $m$ reaches a base case after finitely many steps, and the definition assigns exactly one value.

The measure is part of the definition, not an optional comment. When you write a recursive function, name $m$ before you trust the function. Typical measures in this lecture are the integer $n$ itself, the number of array cells still to be read, the length of a closed index interval, and the exponent still to be consumed.

A recursion is *linear* when each invocation makes at most one recursive call. It is *binary* when an invocation makes two. Those words count calls. They do not say whether the call is the last act of the function. Tail position is defined in Section 5 and is a different property.

### 3.2 Factorial

For a nonnegative integer $n$, the factorial $n!$ is defined by $0! = 1$ and $n! = n \cdot (n-1)!$ for $n \ge 1$.

The base value $0! = 1$ is the empty product: the product of no factors is the multiplicative identity. It is also the unique choice that makes $1! = 1 \cdot 0!$ true. This lecture uses that definition for every finite number raised to the power $0$ as well, in Section 9: the empty product is $1$, including the programming convention $0^0 = 1$ as an empty product. The symbol $0^0$ is left undefined in some analysis texts; the recurrence in this lecture needs a base, and the base is $1$.

The measure is $m(n) = n$. The recursive call uses $n-1$, and $n-1 < n$ whenever the recursive case runs, which is when $n \ge 1$. The descent hits $0$.

```javascript
function factorial(n) {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("factorial is defined here for nonnegative integers");
  }
  if (n === 0) {
    return 1;
  }
  const value = n * factorial(n - 1);
  if (!Number.isSafeInteger(value)) {
    throw new Error("factorial left the safe integer range");
  }
  return value;
}
```

The multiplication stands after the recursive call in the source. The function cannot return until that multiplication has been done. Section 4 draws the consequence for the stack. The safe-integer test is also work that happens after the call returns; it is there so that a result which has left integer exactness-as-safety is refused instead of being returned as a rounded number.

The value $n!$ is a safe integer for $0 \le n \le 18$, and $18! = 6402373705728000$. For $n = 19$, $19! = 121645100408832000$ is still an exact JavaScript number, because $19!$ is divisible by a high enough power of two, but it is larger than $2^{53}-1$, so `Number.isSafeInteger` rejects it. The function above throws at $n = 19$. Exactness fails later: $23!$ is no longer an exact JavaScript number. The laboratory checks the safe boundary, not the later exactness boundary. All traced calls in this lecture use $n \le 10$, where the value is a small safe integer: $4! = 24$ and $10! = 3628800$.

### 3.3 The same function, written as a loop

Recursion is not a second arithmetic. The sequence $1, 1, 2, 6, 24, \ldots$ is one sequence. A loop can build it by storing in variables the information that the recursive version stores in pending frames.

```javascript
function factorialIterative(n) {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("factorial is defined here for nonnegative integers");
  }
  let result = 1;
  for (let k = 1; k <= n; k += 1) {
    result *= k;
    if (!Number.isSafeInteger(result)) {
      throw new Error("factorial left the safe integer range");
    }
  }
  return result;
}
```

**Proposition.** For every integer $n$ with $0 \le n \le 18$, `factorialIterative(n)` returns $n!$.

**Proof.** Fix such an $n$. If $n = 0$, the loop body does not run and the function returns $1 = 0!$.

Now let $n \ge 1$. The loop invariant is: at the start of the iteration that is about to use a particular $k$, with $1 \le k \le n+1$, the variable `result` equals $(k-1)!$.

Initialization: the first iteration has $k = 1$ and `result` $= 1 = 0!$.

Maintenance: assume the invariant for some $k$ with $1 \le k \le n$. The body multiplies `result` by $k$, producing $(k-1)! \cdot k = k!$. Then $k$ increases by $1$. At the next test, `result` equals $(k'-1)!$ for the new index $k'$. For $k \le 18$ the product $k!$ is a safe integer, so the multiplication agrees with integer arithmetic and the function does not throw.

Termination: $k$ increases by $1$ each iteration and starts at $1$, so $k$ reaches $n+1$ after exactly $n$ iterations. The loop stops. The invariant at $k = n+1$ says `result` $= n!$.

The running time is $\Theta(n)$ arithmetic operations in the RAM model. The extra space is $\Theta(1)$ words: `result` and $k$. One stack frame exists, the frame of `factorialIterative` itself, and that frame does not grow with $n$.

Hand trace for $n = 4$:

| At the start of the iteration | $k$ | `result` | Invariant claim |
| --- | --- | --- | --- |
| 1 | $1$ | $1$ | $0!$ |
| 2 | $2$ | $2$ | $1!$ |
| 3 | $3$ | $6$ | $2!$ |
| 4 | $4$ | $24$ | $3!$ |
| after the loop | $5$ | $24$ | $4!$ |

### 3.4 Sum of an array

Let $a[0], \ldots, a[n-1]$ be numbers, $n \ge 0$. The sum of the whole array is the sum of a suffix. Write $S(i)$ for the sum of $a[i] + a[i+1] + \cdots + a[n-1]$, and write $S(n) = 0$ because that sum has no terms.

Then $S(n) = 0$, and $S(i) = a[i] + S(i+1)$ for $0 \le i < n$. The measure of a call at index $i$ is $m(i) = n - i$, the number of cells still to be added. The recursive call uses index $i+1$, and $m(i+1) = m(i) - 1$. The base case is $m(i) = 0$.

```javascript
function sumFrom(a, i) {
  if (!Number.isInteger(i) || i < 0 || i > a.length) {
    throw new Error("sumFrom index is outside 0..a.length");
  }
  if (i === a.length) {
    return 0;
  }
  return a[i] + sumFrom(a, i + 1);
}

function sumArray(a) {
  return sumFrom(a, 0);
}
```

The call `sumArray([3, 1, 4])` unfolds as follows. The measure starts at $3$.

$$
\begin{align*}
S(0) &= 3 + S(1) \\
S(1) &= 1 + S(2) \\
S(2) &= 4 + S(3) \\
S(3) &= 0
\end{align*}
$$

On the way back, $S(2) = 4$, $S(1) = 5$, and $S(0) = 8$. Section 7 proves that this is always the suffix sum, not only on this array. The empty array has $n = 0$, the single call is the base case, and the sum is $0$.

### 3.5 The same sum, written as a loop

```javascript
function sumIterative(a) {
  let acc = 0;
  for (let i = 0; i < a.length; i += 1) {
    acc += a[i];
  }
  return acc;
}
```

**Proposition.** `sumIterative(a)` returns $\sum_{k=0}^{n-1} a[k]$, with the empty sum equal to $0$.

**Proof.** The invariant is: at the start of the iteration with index $i$, `acc` equals $\sum_{k=0}^{i-1} a[k]$.

Initialization: $i = 0$ and `acc` $= 0$, the empty sum.

Maintenance: the body adds $a[i]$, so `acc` becomes the sum through index $i$. Then $i$ increases by $1$, which restores the invariant for the new index.

Termination: $i$ starts at $0$ and increases by $1$, so after exactly $n$ iterations $i = n$ and the loop stops. The invariant says `acc` is the sum of the whole array.

On $[3, 1, 4]$ the accumulator is $0$, then $3$, then $4$, then $8$. The recursive evaluation in Section 3.4 produces the same $8$. The loop keeps the partial sum in one variable. The recursion keeps one pending addition per frame. The mathematics of "add the next cell to the sum of the rest" is the same sentence in both programs. The cost is not the same: both use $\Theta(n)$ time, the loop uses $\Theta(1)$ extra words, and the recursion uses $\Theta(n)$ stack frames. That cost is the subject of the next section.

---

## 4. The call stack

### 4.1 What a frame holds

Lecture 04 defined a stack as a last-in, first-out store of values, and identified the call stack as the stack the language implementation uses for function calls. This section does not rebuild that abstract data type. It records the fields a frame must contain so that a recursive return can resume the caller.

An *activation record*, or *stack frame*, for a call holds:

- the parameters of that call
- the local variables of that call
- the return address, meaning the place in the caller that receives the returned value and continues
- the space in which the returned value itself sits once the callee is done

A call pushes a frame. A return pops the frame and delivers the value to the return address in the frame underneath. The frame underneath is the caller. Its pending work is whatever source text follows the call expression.

In the recursive factorial, the source text after the call is a multiplication by $n$, then the safe-integer test, then the return of that product. Until the callee returns, that multiplication is pending. It is stored by the existence of the caller's frame, not by an explicit stack in the program text.

### 4.2 A full trace of factorial(4)

The call `factorial(4)` is legal: $4$ is a nonnegative integer, and $24$ is a safe integer. Each frame's guard succeeds. The diagram omits the guard and shows the parameter, the pending operation, and the value that eventually occupies the frame.

The stack grows until the base case is the top frame. The bottom of each diagram is the original caller, which is waiting for $24$ and has no factorial parameter of its own.

```text
Call factorial(4). One frame. The multiplication is waiting on factorial(3).

| n = 4 | pending: 4 * factorial(3) | value: not yet |
| caller of factorial(4)                                 |
```

```text
Call factorial(3).

| n = 3 | pending: 3 * factorial(2) | value: not yet |
| n = 4 | pending: 4 * _                | value: not yet |
| caller                                                   |
```

```text
Call factorial(2).

| n = 2 | pending: 2 * factorial(1) | value: not yet |
| n = 3 | pending: 3 * _                | value: not yet |
| n = 4 | pending: 4 * _                | value: not yet |
| caller                                                   |
```

```text
Call factorial(1).

| n = 1 | pending: 1 * factorial(0) | value: not yet |
| n = 2 | pending: 2 * _                | value: not yet |
| n = 3 | pending: 3 * _                | value: not yet |
| n = 4 | pending: 4 * _                | value: not yet |
| caller                                                   |
```

```text
Call factorial(0). This is the base case. Maximum depth.
Five factorial frames are live: n = 4, 3, 2, 1, 0.

| n = 0 | base case, returns 1          |
| n = 1 | pending: 1 * _                |
| n = 2 | pending: 2 * _                |
| n = 3 | pending: 3 * _                |
| n = 4 | pending: 4 * _                |
| caller                                 |
```

The returns then pop frames. The blank in each pending multiplication is filled by the value just returned.

| Return from | Computation in that frame | Value delivered | Frames still live after the pop |
| --- | --- | --- | --- |
| $n = 0$ | base case | $1$ | $4$ |
| $n = 1$ | $1 \cdot 1$ | $1$ | $3$ |
| $n = 2$ | $2 \cdot 1$ | $2$ | $2$ |
| $n = 3$ | $3 \cdot 2$ | $6$ | $1$ |
| $n = 4$ | $4 \cdot 6$ | $24$ | $0$ factorial frames |

The order of entry is $4, 3, 2, 1, 0$. The order of completion is the reverse. That reversal is the stack. It is also why an induction proof of correctness reads naturally from the base case outward: the first value that exists is $0!$, and each larger value is built when a frame resumes. Section 7 makes that remark precise for the array sum.

The same trace for $n = 10$ enters $10, 9, \ldots, 0$, eleven frames at the maximum, and returns $3628800$. The laboratory checks both traces.

### 4.3 Maximum depth and the cost of stack space

**Definition.** The *depth* of a call is the number of frames of that recursion that are live at once, counting the frame just pushed. The *maximum depth* of a run is the largest depth that run attains.

For `factorial(n)` the maximum depth is $n+1$: one frame for each of $n, n-1, \ldots, 0$. The proof is the measure. Each call decreases $n$ by $1$, the base case is $0$, and no call returns before the base case has been entered, so the frames $n$ down through $0$ are all live together.

Each of those frames stores a constant amount of information: one integer parameter and a return address. In the RAM model the extra space is therefore $\Theta(n)$ words. This cost is easy to miss if you only count arithmetic. The iterative factorial of Section 3.3 performs the same $n$ multiplications and uses $\Theta(1)$ extra words.

Time and stack space for the functions of Section 3:

| Function | Time | Extra stack space |
| --- | --- | --- |
| `factorial(n)` | $\Theta(n)$ | $\Theta(n)$ |
| `factorialIterative(n)` | $\Theta(n)$ | $\Theta(1)$ |
| `sumFrom` on a suffix of length $r$ | $\Theta(r)$ | $\Theta(r)$ |
| `sumIterative` | $\Theta(n)$ | $\Theta(1)$ |

The numeric limit and the stack limit are different failures. The factorial value leaves the safe integers at $n = 19$, which is only $20$ frames. A stack overflow is a failure of depth, and the engine's maximum depth is finite and implementation-defined. It is large compared with $20$. You will see the safe-integer throw from factorial long before you see a stack overflow from factorial. Stack overflow is still real for a recursion whose depth reaches the engine limit and whose frames do little arithmetic. The countdown

```javascript
function countdown(n) {
  if (n === 0) {
    return 0;
  }
  return countdown(n - 1);
}
```

performs no large multiplication. In Node.js it still allocates $n+1$ frames. A large enough $n$ throws `RangeError: Maximum call stack size exceeded`. This lecture does not put a particular threshold into a theorem, and the laboratory does not call `countdown` on a crashing input. The theorem is the $\Theta(n)$ frame count, not the brand of the engine.

---

## 5. Tail recursion

**Definition.** A call is in *tail position* when the rest of the caller's work, after that call returns, is only to return that same value to the caller's own caller. No arithmetic remains, no second call remains, and no assignment must still happen.

**Definition.** A function is *tail recursive* when every recursive call it makes is in tail position.

`factorial` is not tail recursive. After `factorial(n - 1)` returns, the frame still multiplies by $n$ and still tests the safe-integer range. `countdown` is tail recursive: the recursive call is the entire return value. The array sum is not tail recursive: an addition follows the call. The recursive binary search in Section 8 is tail recursive: each recursive call is a `return` of that call's result. Tail recursion is a syntactic position. It is not a promise about memory.

The pending multiplication in factorial can be moved out of the frame and into a parameter. The parameter is an *accumulator*: a value that already holds the work the pending frames would have done.

```javascript
function factorialTail(n, acc) {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("factorial is defined here for nonnegative integers");
  }
  if (n === 0) {
    if (!Number.isSafeInteger(acc)) {
      throw new Error("factorial left the safe integer range");
    }
    return acc;
  }
  return factorialTail(n - 1, n * acc);
}
```

The public call is `factorialTail(n, 1)`. The intended meaning of a call is $n! \cdot \mathrm{acc}$, provided the product is a safe integer.

**Proposition.** For integers $n \ge 0$ and $acc$ such that $n! \cdot acc$ is a safe integer, `factorialTail(n, acc)` returns $n! \cdot acc$.

**Proof.** Let $P(n)$ be the statement: for every integer `acc` such that $n! \cdot acc$ is a safe integer, `factorialTail(n, acc)` returns $n! \cdot acc$. The argument is weak induction on $n$.

Base $n = 0$. The product $0! \cdot acc$ is `acc`, which is a safe integer by the hypothesis of $P(0)$. The function takes the base branch, the safe-integer test passes, and it returns `acc`.

Inductive hypothesis: assume $P(n)$ for some $n \ge 0$.

Inductive step: take an integer `acc` such that $(n+1)! \cdot acc$ is a safe integer. The call `factorialTail(n+1, acc)` does not take the base branch. It evaluates the argument $(n+1) \cdot acc$ and returns the result of `factorialTail(n, (n+1) * acc)`. The product attached to that recursive call is

$$
n! \cdot ((n+1) \cdot acc) = (n+1)! \cdot acc,
$$

which is a safe integer by the choice of `acc`. The inductive hypothesis therefore says the recursive call returns $(n+1)! \cdot acc$. The caller returns that value with no further arithmetic, which is $P(n+1)$.

By weak induction, $P(n)$ holds for every integer $n \ge 0$.

The call `factorialTail(4, 1)` therefore returns $24$. The frames enter as $(4, 1)$, $(3, 4)$, $(2, 12)$, $(1, 24)$, $(0, 24)$. The base frame returns $24$, and each caller returns that same $24$ with no further arithmetic. Maximum depth is still $5$, which is $n+1$.

Moving the multiplication into the argument removes pending work from the frame. It does not remove the frame. An implementation is allowed to notice that a tail call does not need its caller's frame and to reuse that frame. That transformation is *tail-call elimination*. ECMA-262, the ECMAScript specification, describes proper tail calls. JavaScript engines are not required to eliminate tail calls for any program in this course, and you must not write a function that is correct only if they do. Node.js runs V8, which does not eliminate tail calls. Firefox's SpiderMonkey does not either. A tail-recursive function run here still allocates one frame per call and can overflow the stack. Safari's JavaScriptCore has implemented proper tail calls in strict mode; that is an engine-specific behavior, and no cost claimed in this lecture depends on it.

Concretely: `factorialTail(n, 1)` uses $\Theta(n)$ stack frames in Node.js, the same order as `factorial(n)`. `countdown` is already a tail call and still uses $\Theta(n)$ frames. The iterative factorial is the program that actually uses $\Theta(1)$ extra space. If you need a constant amount of stack, write the loop. Do not leave a comment that says the engine will optimize the recursion.

---

## 6. Mathematical induction

Induction is the way a statement about every nonnegative integer is proved from a base value and a step. Recursive programs are such statements. The step should follow the calls the program actually makes.

Throughout this section, $P(n)$ is a statement about an integer $n$. The starting index $n_0$ is usually $0$ or $1$.

### 6.1 Weak induction

**Definition.** A proof of $\forall n \ge n_0,\; P(n)$ by *weak induction* has three labeled parts.

1. *Base.* Prove $P(n_0)$.
2. *Inductive hypothesis.* Fix an arbitrary integer $n \ge n_0$ and assume $P(n)$.
3. *Inductive step.* Prove $P(n+1)$, and use the hypothesis $P(n)$ where you need it.

The conclusion is $P(n)$ for every integer $n \ge n_0$.

The word "weak" means the hypothesis offers only the immediate predecessor. It does not mean the conclusion is partial. The principle is: if the statement is true at the start, and truth at any integer forces truth at the next integer, then there is no first integer where it fails.

Factorial's recurrence $n! = n \cdot (n-1)!$ calls only the immediate predecessor. Weak induction matches it. The Hanoi recurrence in Section 10 calls only $n-1$, twice. Weak induction matches that proof as well. Calling the predecessor twice does not require a stronger hypothesis; the same fact $P(n)$ is used twice.

### 6.2 Strong induction

**Definition.** A proof of $\forall n \ge n_0,\; P(n)$ by *strong induction* has three labeled parts.

1. *Base.* Prove $P(n_0)$. If the step for small $n$ would refer to arguments below $n_0$, prove those extra base cases too, up through the last integer the step does not cover.
2. *Inductive hypothesis.* Fix an arbitrary integer $n \ge n_0$ and assume $P(k)$ for every integer $k$ with $n_0 \le k \le n$. Equivalently, assume $P(k)$ for every legal $k < n+1$.
3. *Inductive step.* Prove $P(n+1)$ from that collection of earlier facts.

The hypothesis is a block of earlier values, not one earlier value. A recursive call on $\lfloor n/2 \rfloor$, or on $(n-1)/2$, lands somewhere in that block. It does not land on $n$ itself, so a hypothesis that only says $P(n)$ does not mention the call the program makes.

### 6.3 Which form matches the recursion

Use the calls as a checklist.

| Recursive call pattern | Induction that matches the calls |
| --- | --- |
| Only on $n-1$ | Weak induction on $n$ |
| On $i+1$ while walking an array toward a fixed end | Weak induction on the number of cells already finished, or on the number still left |
| On $\lfloor n/2 \rfloor$, or on $(n-1)/2$ | Strong induction on $n$ |
| On two halves $\lfloor n/2 \rfloor$ and $\lceil n/2 \rceil$ | Strong induction on $n$ |
| On a strictly shorter closed interval, whose new length is not a fixed $n-1$ | Strong induction on the interval length |

Binary search and integer power need the strong form. The subset generator of Section 11 calls only on a suffix that is shorter by one element, twice, so the count of subsets is a weak induction on the number of elements that remain. The form follows the call, not the reputation of the problem.

### 6.4 They prove the same statements

Strong induction is not a larger set of theorems about the integers. It is a more convenient packaging of the same principle. The next theorem records that, so that "use strong induction" is never heard as "weak induction cannot reach this claim."

**Theorem 1.** Let $P(n)$ be a statement about integers $n \ge n_0$. There is a weak-induction proof of $P(n)$ for all such $n$ if and only if there is a strong-induction proof of the same claim.

**Proof.** First direction: a weak proof is already a strong proof. The strong step is allowed to assume $P(n_0), \ldots, P(n)$. If the step can be written using only $P(n)$, it can be written in a context that happens to supply the earlier facts as well and simply does not cite them.

Second direction: suppose the base $P(n_0)$ is known, and suppose that whenever $P(k)$ holds for all $k$ with $n_0 \le k \le n$, the statement $P(n+1)$ follows. Define a new statement $Q(n)$ by

$$
Q(n) :\quad P(k) \text{ holds for every integer } k \text{ with } n_0 \le k \le n.
$$

Base of a weak induction on $Q$: $Q(n_0)$ is exactly $P(n_0)$, which holds.

Weak inductive hypothesis: assume $Q(n)$ for some $n \ge n_0$. That assumption is precisely "$P(k)$ holds for all $k$ from $n_0$ through $n$." The supposed strong step yields $P(n+1)$. Combined with $Q(n)$, this is $Q(n+1)$.

By weak induction, $Q(n)$ holds for every $n \ge n_0$. The statement $Q(n)$ includes $P(n)$. Therefore $P(n)$ holds for every $n \ge n_0$.

The practical rule survives the theorem. Write the strong proof when the recursive calls are on many smaller sizes, because $Q$ is then what you meant. Write the weak proof when the only call is on $n-1$, because the extra packaging adds nothing.

One arithmetic identity used later is proved here so that floor and ceiling are not treated as decoration.

**Lemma 1.** For every integer $n \ge 0$,

$$
\lfloor n/2 \rfloor + \lceil n/2 \rceil = n.
$$

**Proof.** If $n = 2m$, then both terms are $m$, and the sum is $2m$. If $n = 2m+1$, then $\lfloor n/2 \rfloor = m$ and $\lceil n/2 \rceil = m+1$, and the sum is $2m+1$.

---

## 7. Two proofs in full

Lecture 01 may already have produced the formula for $1 + \cdots + n$ from the algebra of series. The proof in this section is the induction form. It is the pattern every later induction in the course is allowed to imitate: a named statement, a base, a hypothesis, a step that contains the arithmetic, and an explicit appeal to the principle.

### 7.1 The sum of the first $n$ positive integers

**Theorem 2.** For every integer $n \ge 0$,

$$
\sum_{k=1}^{n} k = \frac{n(n+1)}{2}.
$$

When $n = 0$ the left side is the empty sum, defined to be $0$, and the right side is $0$.

**Proof.** Let $P(n)$ be the displayed equation. The proof is weak induction starting at $n_0 = 0$.

Base $n = 0$. The empty sum is $0$, and $0 \cdot 1 / 2 = 0$. So $P(0)$ holds. The case $n = 1$ is then available as a check rather than as the base: the left side is $1$, and the right side is $1 \cdot 2 / 2 = 1$.

Inductive hypothesis: fix $n \ge 0$ and assume $P(n)$, that is

$$
\sum_{k=1}^{n} k = \frac{n(n+1)}{2}.
$$

Inductive step: the sum through $n+1$ adds one term to the sum through $n$.

$$
\sum_{k=1}^{n+1} k
  = \left(\sum_{k=1}^{n} k\right) + (n+1)
  = \frac{n(n+1)}{2} + (n+1)
  = (n+1)\left(\frac{n}{2} + 1\right)
  = (n+1)\left(\frac{n+2}{2}\right)
  = \frac{(n+1)(n+2)}{2}.
$$

The second equality is the inductive hypothesis. The result is $P(n+1)$.

By weak induction, $P(n)$ holds for every integer $n \ge 0$.

Check at $n = 5$: the left side is $15$, and the right side is $5 \cdot 6 / 2 = 15$. Check at $n = 4$: $10 = 4 \cdot 5 / 2$. These checks do not replace the proof. They catch an algebraic slip in the step.

### 7.2 Correctness of the recursive array sum

The code is `sumFrom` from Section 3.4. The theorem is stated for every suffix, not only for the public call at index $0$, because the recursive call is a suffix call and the hypothesis must talk about the call that actually happens.

**Theorem 3.** Let $a$ be an array of $n \ge 0$ numbers. For every integer $i$ with $0 \le i \le n$, `sumFrom(a, i)` returns

$$
\sum_{k=i}^{n-1} a[k],
$$

where the sum is $0$ when $i = n$.

**Proof.** The measure of the call at $i$ is $t = n - i$. The proof is weak induction on $t$. For $t = 0, 1, \ldots, n$, let $i = n - t$ and let $P(t)$ be the claim that `sumFrom(a, i)` returns the sum of $a[i], \ldots, a[n-1]$.

Base $t = 0$. Then $i = n$. The function returns $0$, which is the empty sum. $P(0)$ holds.

Inductive hypothesis: fix $t$ with $0 \le t < n$, and assume $P(t)$. Explicitly, `sumFrom(a, n-t)` returns the sum from index $n-t$ through $n-1$.

Inductive step: consider $t+1$. The corresponding index is

$$
i = n - (t+1) = (n-t) - 1.
$$

Since $t < n$, this $i$ satisfies $0 \le i < n$, so the function does not take the base branch. It returns

$$
a[i] + \mathtt{sumFrom}(a, i+1).
$$

The index $i+1$ equals $n-t$, so the inductive hypothesis says that the recursive call returns the sum from $i+1$ through $n-1$. Adding $a[i]$ produces the sum from $i$ through $n-1$. That is $P(t+1)$.

By weak induction, $P(t)$ holds for every $t$ from $0$ through $n$. The public call `sumArray(a)` is `sumFrom(a, 0)`, which is the case $t = n$.

The induction proceeds from the base outward, in the same order as the returns in Section 4. The calls themselves happen from the full array inward. Both orders are correct; they describe different moments. The call stack is why the inward trip can pause until the outward trip has produced a number.

On $a = [3, 1, 4]$, Theorem 3 says `sumFrom(a, 2)` returns $4$, `sumFrom(a, 1)` returns $5$, and `sumFrom(a, 0)` returns $8$. That is the trace already computed in Section 3.4, now as an instance of the theorem rather than as an example that happens to work.

A linked-list reversal has the same shape: a base case on the empty list, a measure equal to the length, and an inductive step that uses the reversal of the tail. Lecture 03 owns list structure. This lecture does not borrow that code. Theorem 3 is the array form of the same idea, and it is the one later proofs imitate.

---

## 8. Binary search

### 8.1 The problem and the precondition

**Input.** An array $a$ of $n \ge 0$ numbers, and a key.

**Precondition.** The array is sorted *ascending*, which in this lecture means non-decreasing:

$$
a[0] \le a[1] \le \cdots \le a[n-1]
$$

when $n \ge 1$. Duplicates are allowed. The empty array is sorted. Strict increase is the special case in which every inequality is strict; the algorithms do not need that stronger hypothesis.

**Output of the any-occurrence search.** Any index $i$ with $a[i] = \mathrm{key}$, or $-1$ if no such index exists.

**Output of the first-occurrence search.** The smallest index $i$ with $a[i] = \mathrm{key}$, or $-1$ if no such index exists.

Sortedness is a hypothesis about the whole array, and every subarray $a[\ell], \ldots, a[r]$ of a sorted array is sorted. The algorithms use that fact on whatever closed interval is still live. They do not re-check the hypothesis, because a linear scan would hide the logarithmic cost. If the hypothesis is false, the theorems are silent and the returned index can be wrong. A one-line counterexample is in the proof of Theorem 6.

The reason to search by halving, rather than by scanning, is the sorted order: a comparison with the middle element discards every cell on one side. Without that order, a comparison discards one cell. The mechanism below is that observation written as an invariant.

### 8.2 The iterative algorithm

The live region is a *closed interval* of indices, written $\mathrm{lo}..\,\mathrm{hi}$, meaning every index $j$ with $\mathrm{lo} \le j \le \mathrm{hi}$. The interval is *empty* when $\mathrm{lo} > \mathrm{hi}$. Its length is $\mathrm{hi} - \mathrm{lo} + 1$ when it is nonempty, and $0$ when it is empty.

```javascript
function binarySearch(a, key) {
  let lo = 0;
  let hi = a.length - 1;
  while (lo <= hi) {
    const mid = lo + Math.floor((hi - lo) / 2);
    if (a[mid] === key) {
      return mid;
    }
    if (a[mid] < key) {
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return -1;
}
```

The loop condition is $\mathrm{lo} \le \mathrm{hi}$, not $\mathrm{lo} < \mathrm{hi}$. A one-element interval has $\mathrm{lo} = \mathrm{hi}$ and is still a candidate. The midpoint formula is the one proved exact for safe indices in Section 8.7. On an empty array, $\mathrm{hi} = -1$ and $\mathrm{lo} = 0$, so the loop body never runs and the result is $-1$. No read of $a[0]$ occurs.

### 8.3 The invariant

**Invariant of `binarySearch`, at the start of every test of `lo <= hi`, including the test that fails and ends the loop.**

1. $0 \le \mathrm{lo} \le n$ and $-1 \le \mathrm{hi} \le n-1$.
2. Every index $j < \mathrm{lo}$ has $a[j] < \mathrm{key}$.
3. Every index $j > \mathrm{hi}$ has $a[j] > \mathrm{key}$.

Clause 2 and clause 3 together say: if the key occurs anywhere in $a$, then it occurs in the closed interval $\mathrm{lo}..\,\mathrm{hi}$. When the interval is empty, they say the key occurs nowhere.

The invariant is a statement about discarded cells, not only about the live interval. That extra precision is what the update rules preserve. "The key, if present, is somewhere in $\mathrm{lo}..\,\mathrm{hi}$" is the corollary you should be able to say out loud; the proof maintains the two discarded-side statements.

### 8.4 A numeric trace

Let

$$
a = [1, 3, 4, 7, 7, 9, 12]
$$

with indices $0$ through $6$, and search for the key $4$.

| Step | $\mathrm{lo}$ | $\mathrm{hi}$ | $\mathrm{mid}$ | $a[\mathrm{mid}]$ | Decision |
| --- | --- | --- | --- | --- | --- |
| 1 | $0$ | $6$ | $3$ | $7$ | $7 > 4$, so $\mathrm{hi} \leftarrow 2$ |
| 2 | $0$ | $2$ | $1$ | $3$ | $3 < 4$, so $\mathrm{lo} \leftarrow 2$ |
| 3 | $2$ | $2$ | $2$ | $4$ | equal, return $2$ |

After step 1, before step 2, the invariant says every index greater than $2$ holds a value greater than $4$. The cells $a[3], a[4], a[5], a[6]$ are $7, 7, 9, 12$, all greater than $4$. After step 2, every index less than $2$ holds a value less than $4$: $a[0] = 1$ and $a[1] = 3$. The live interval is the single index $2$.

The same array, key $5$, which is absent:

| Step | $\mathrm{lo}$ | $\mathrm{hi}$ | $\mathrm{mid}$ | $a[\mathrm{mid}]$ | Decision |
| --- | --- | --- | --- | --- | --- |
| 1 | $0$ | $6$ | $3$ | $7$ | $7 > 5$, so $\mathrm{hi} \leftarrow 2$ |
| 2 | $0$ | $2$ | $1$ | $3$ | $3 < 5$, so $\mathrm{lo} \leftarrow 2$ |
| 3 | $2$ | $2$ | $2$ | $4$ | $4 < 5$, so $\mathrm{lo} \leftarrow 3$ |
| end | $3$ | $2$ |  |  | $\mathrm{lo} > \mathrm{hi}$, return $-1$ |

At the end, every index is either less than $3$ or greater than $2$. There is no index that escapes both descriptions, because $3 > 2$. The left discarded region is $a[0], a[1], a[2] = 1, 3, 4$, all less than $5$. The right discarded region is $a[3], \ldots, a[6]$, all greater than $5$.

Further runs on this array, used again by the laboratory:

| Key | Returned index | Steps $(\mathrm{lo}, \mathrm{hi}, \mathrm{mid}, a[\mathrm{mid}])$ |
| --- | --- | --- |
| $9$ | $5$ | $(0,6,3,7)$, $(4,6,5,9)$ equal |
| $1$ | $0$ | $(0,6,3,7)$, $(0,2,1,3)$, $(0,0,0,1)$ equal |
| $12$ | $6$ | $(0,6,3,7)$, $(4,6,5,9)$, $(6,6,6,12)$ equal |
| $0$ | $-1$ | $(0,6,3,7)$, $(0,2,1,3)$, $(0,0,0,1)$ then $\mathrm{hi} \leftarrow -1$ |
| $13$ | $-1$ | $(0,6,3,7)$, $(4,6,5,9)$, $(6,6,6,12)$ then $\mathrm{lo} \leftarrow 7$ |
| $7$ | $3$ | $(0,6,3,7)$ equal on the first midpoint |

The key $7$ occurs at indices $3$ and $4$. This run returns $3$ because the first midpoint landed on the earlier copy. That is an accident of the length. Section 8.8 shows a run that returns a later copy, and the algorithm that is required to return the earliest.

### 8.5 Termination and the recurrence, with the floor

**Lemma 2.** Inside the loop, $\mathrm{lo} \le \mathrm{hi}$, and $\mathrm{mid} = \mathrm{lo} + \lfloor (\mathrm{hi}-\mathrm{lo})/2 \rfloor$ satisfies $\mathrm{lo} \le \mathrm{mid} \le \mathrm{hi}$.

**Proof.** The loop body runs only when $\mathrm{lo} \le \mathrm{hi}$, so $\mathrm{hi}-\mathrm{lo} \ge 0$ and the floor term is at least $0$. Thus $\mathrm{mid} \ge \mathrm{lo}$. Also $\lfloor (\mathrm{hi}-\mathrm{lo})/2 \rfloor \le \mathrm{hi}-\mathrm{lo}$, so $\mathrm{mid} \le \mathrm{hi}$.

**Lemma 3.** Let $L = \mathrm{hi} - \mathrm{lo} + 1 \ge 1$ be the length at the start of an iteration that does not return. If the branch sets $\mathrm{lo} \leftarrow \mathrm{mid}+1$, the new length is $\lfloor L/2 \rfloor$. If the branch sets $\mathrm{hi} \leftarrow \mathrm{mid}-1$, the new length is $\lfloor (L-1)/2 \rfloor$, which is at most $\lfloor L/2 \rfloor$.

**Proof.** By Lemma 2, $\mathrm{mid} = \mathrm{lo} + \lfloor (L-1)/2 \rfloor$.

Right branch, $\mathrm{lo}' = \mathrm{mid}+1$, $\mathrm{hi}$ unchanged. The new length is

$$
\mathrm{hi} - (\mathrm{mid}+1) + 1 = \mathrm{hi} - \mathrm{mid} = (L-1) - \lfloor (L-1)/2 \rfloor = \lceil (L-1)/2 \rceil.
$$

This equals $\lfloor L/2 \rfloor$. If $L = 2m$, then $\lceil (2m-1)/2 \rceil = m = \lfloor L/2 \rfloor$. If $L = 2m+1$, then $\lceil 2m/2 \rceil = m = \lfloor L/2 \rfloor$.

Left branch, $\mathrm{hi}' = \mathrm{mid}-1$, $\mathrm{lo}$ unchanged. The new length is

$$
(\mathrm{mid}-1) - \mathrm{lo} + 1 = \mathrm{mid} - \mathrm{lo} = \lfloor (L-1)/2 \rfloor.
$$

For any integer $L \ge 1$, $\lfloor (L-1)/2 \rfloor \le \lfloor L/2 \rfloor$. When $L$ is odd the two lengths are equal. When $L$ is even the left branch is one cell shorter than the right branch.

Every iteration that does not find the key therefore replaces a positive length $L$ by a length at most $\lfloor L/2 \rfloor$, which is a strictly smaller nonnegative integer. The empty interval is the only interval with $L = 0$, and the loop stops when $\mathrm{lo} > \mathrm{hi}$. Hence the loop terminates after a finite number of iterations. It cannot run forever on a finite array.

Let $W(n)$ be the worst-case number of iterations of `binarySearch` on an array of length $n$. Then $W(0) = 0$. For $n \ge 1$ the first iteration always happens. If it finds the key, the count is $1$, which will sit under the bound proved below. If it does not, the adversary who wants a long run chooses the child interval whose worst-case cost is larger. By Lemma 3 the two child lengths are $\lfloor (n-1)/2 \rfloor$ and $\lfloor n/2 \rfloor$, so

$$
W(n) = 1 + \max\big(W(\lfloor (n-1)/2 \rfloor),\; W(\lfloor n/2 \rfloor)\big).
$$

**Lemma 4.** For every integer $n \ge 2$,

$$
\lfloor \log \lfloor n/2 \rfloor \rfloor = \lfloor \log n \rfloor - 1.
$$

**Proof.** Let $q = \lfloor \log n \rfloor$. Then $q \ge 1$ and $2^q \le n \le 2^{q+1}-1$. Dividing through by $2$ and taking the floor,

$$
2^{q-1} \le \lfloor n/2 \rfloor \le \lfloor (2^{q+1}-1)/2 \rfloor = 2^q - 1.
$$

The lower bound holds because $\lfloor n/2 \rfloor \ge \lfloor 2^q / 2 \rfloor = 2^{q-1}$. An integer in the range $2^{q-1}, \ldots, 2^q - 1$ has floor-logarithm $q-1$.

**Theorem 4.** For every integer $n \ge 1$,

$$
W(n) = \lfloor \log n \rfloor + 1,
$$

and $W(0) = 0$. Each iteration does $\Theta(1)$ work in the RAM model, so the worst-case running time of `binarySearch` on an array of length $n \ge 1$ is $\Theta(\log n)$.

**Proof.** The closed form $f(0) = 0$ and $f(n) = \lfloor \log n \rfloor + 1$ for $n \ge 1$ is nondecreasing: $f(0) \le f(1)$, and $\lfloor \log (k+1) \rfloor \ge \lfloor \log k \rfloor$ for $k \ge 1$.

The claim $W(n) = f(n)$ is proved by strong induction on $n$.

Base. $W(0) = 0$. For $n = 1$ both child lengths are $\lfloor 0/2 \rfloor = 0$, so $W(1) = 1 + W(0) = 1$, and $\lfloor \log 1 \rfloor + 1 = 1$.

Inductive hypothesis: fix $n \ge 2$ and assume $W(k) = f(k)$ for every $k < n$. Both child lengths are at most $\lfloor n/2 \rfloor \le n/2 \le n-1$, so the hypothesis applies to them. Because $f$ is nondecreasing and $W$ agrees with $f$ below $n$, $W$ is nondecreasing on $0, \ldots, n-1$. Therefore the larger child cost is $W(\lfloor n/2 \rfloor)$, and

$$
W(n) = 1 + W(\lfloor n/2 \rfloor) = 1 + \lfloor \log \lfloor n/2 \rfloor \rfloor + 1 = 2 + \lfloor \log \lfloor n/2 \rfloor \rfloor.
$$

Lemma 4 rewrites the floor-logarithm, and $W(n) = \lfloor \log n \rfloor + 1$.

By strong induction the formula holds for every $n \ge 0$.

The bound is attained. If the key is strictly larger than every element, no midpoint compares equal, and Lemma 3 says the algorithm always takes the right branch, whose length is exactly $\lfloor L/2 \rfloor$. The number of iterations on that input is exactly the recurrence $1 + W(\lfloor n/2 \rfloor)$, which the proof just solved. On $[1, 3, 4, 7, 7, 9, 12]$ the key $13$ takes three iterations, and $\lfloor \log 7 \rfloor + 1 = 2 + 1 = 3$.

A particular run can be shorter. The best case is $\Theta(1)$: the first midpoint equals the key, as the key $7$ did on this array. An unsuccessful search can also be shorter than $W(n)$ when $n$ is even and the search takes the left branch. On $[1, 3]$ with key $0$, the single midpoint is index $0$, the value $1$ is greater than $0$, and $\mathrm{hi}$ becomes $-1$. That is one iteration, while $W(2) = 2$. The $\Theta(\log n)$ claim is a worst-case claim. This lecture does not analyze the average number of iterations; that average depends on a distribution of keys, and no such distribution has been assumed.

The Master Theorem of Lecture 01, applied to the floor-free shape $T(n) = T(n/2) + \Theta(1)$ on exact powers of two, also yields $\Theta(\log n)$. Theorem 4 is the version this lecture owns, because the algorithm really does compute $\lfloor n/2 \rfloor$ and the exact iteration count is $\lfloor \log n \rfloor + 1$, not only a $\Theta$ class.

### 8.6 The recursive algorithm

The same invariant lives on the parameters.

```javascript
function binarySearchRecursive(a, key) {
  return searchRange(a, key, 0, a.length - 1);
}

function searchRange(a, key, lo, hi) {
  if (lo > hi) {
    return -1;
  }
  const mid = lo + Math.floor((hi - lo) / 2);
  if (a[mid] === key) {
    return mid;
  }
  if (a[mid] < key) {
    return searchRange(a, key, mid + 1, hi);
  }
  return searchRange(a, key, lo, mid - 1);
}
```

Both recursive calls are in tail position. Section 5 still applies: Node.js does not reuse the frame. The worst-case chain on a miss follows lengths $n, \lfloor n/2 \rfloor, \lfloor n/4 \rfloor, \ldots, 1, 0$. That is $W(n)$ nonempty calls plus the empty base call, hence at most $\lfloor \log n \rfloor + 2$ frames for $n \ge 1$. For $n = 7$ the lengths are $7, 3, 1, 0$, four frames, and $\lfloor \log 7 \rfloor + 2 = 4$. The extra space is $\Theta(\log n)$ words in the worst case, against $\Theta(1)$ extra words for the iterative loop. Time is the same $\Theta(\log n)$ worst case, because the work along the chain is proportional to its length.

The measure is the interval length $\mathrm{hi}-\mathrm{lo}+1$, taken to be $0$ when $\mathrm{lo} > \mathrm{hi}$. Every recursive call receives a strictly smaller measure, by Lemma 3. Termination of the recursion is the well-founded descent, not a separate hope.

### 8.7 Off-by-one: midpoint, empty interval, one-element interval

Three boundaries produce almost all of the defective binary searches.

**The empty interval.** The search ends when $\mathrm{lo} > \mathrm{hi}$. The return value is then $-1$, and the body must not read an index. Starting $\mathrm{hi}$ at `a.length` instead of `a.length - 1`, while keeping the test $\mathrm{lo} \le \mathrm{hi}$, makes the first midpoint legal only by accident and eventually reads `a[a.length]`, which is `undefined` in JavaScript. The comparison `undefined < key` is false, and `undefined > key` is also false, so the equality test fails and the branch that treats the value as greater than the key is not a faithful model of the mathematics. The closed interval of candidate indices for an array of length $n$ starts at $0..\,n-1$.

**The one-element interval.** If the any-occurrence loop is written `while (lo < hi)` and the only inspection of a cell is inside that loop, the last live index is never read. On $a = [4]$ and key $4$, one has $\mathrm{lo} = \mathrm{hi} = 0$, the loop body does not run, and the function returns $-1$ for a key that is present. The test $\mathrm{lo} \le \mathrm{hi}$ exists so that this interval is inspected. With that test, the same input reads $a[0]$, finds $4$, and returns $0$. The key $5$ reads $a[0]$, sets $\mathrm{hi} = -1$, and returns $-1$. Section 8.8 mentions a spelling that uses $\mathrm{lo} < \mathrm{hi}$, and that spelling is tied to a different update and a read after the loop. The two conventions are not interchangeable.

**The midpoint.** The mathematical index is $\mathrm{lo} + \lfloor (\mathrm{hi}-\mathrm{lo})/2 \rfloor$.

**Lemma 5.** If $\mathrm{lo}$ and $\mathrm{hi}$ are integers and $0 \le \mathrm{lo} \le \mathrm{hi} \le 2^{53}-1$, then the JavaScript expression `lo + Math.floor((hi - lo) / 2)` equals that integer, and the result lies between $\mathrm{lo}$ and $\mathrm{hi}$ inclusive.

**Proof.** The difference $k = \mathrm{hi}-\mathrm{lo}$ is an integer in $0, \ldots, 2^{53}-1$, so it is a safe integer and is represented exactly. The claim reduces to showing that `Math.floor(k / 2)` equals $\lfloor k/2 \rfloor$, and that adding $\mathrm{lo}$ to that integer is exact.

If $k$ is even, then $k/2$ is an integer at most $(2^{53}-2)/2 = 2^{52}-1$. That integer is safe, so the division is exact and `Math.floor` leaves it unchanged.

If $k$ is odd, write $k = 2m+1$ with $m = \lfloor k/2 \rfloor$. Then $m \le \lfloor (2^{53}-1)/2 \rfloor = 2^{52}-1$, and the mathematical quotient is $m + 1/2 \le 2^{52} - 1/2$. Every multiple of $1/2$ in that range is exactly representable: on the binade $[2^{51}, 2^{52})$ the unit in the last place is $1/2$, and below $2^{51}$ the unit is at most $1/4$. So `k / 2` evaluates to $m + 1/2$, and `Math.floor` returns $m$. The odd endpoint $k = 2^{53}-1$ is the case `Math.floor((2^{53}-1) / 2) = 4503599627370495`.

The sum of $\mathrm{lo}$ and this floor is an integer between $\mathrm{lo}$ and $\mathrm{hi}$ inclusive, hence at most $2^{53}-1$. The addition of two nonnegative safe integers whose mathematical sum is safe is exact.

The expression `Math.floor((lo + hi) / 2)` is not the same contract. The sum of two safe integers can leave the safe range and can fail to be the mathematical sum. Take

$$
\mathrm{lo} = 9007199254740988, \qquad \mathrm{hi} = 9007199254740991.
$$

Both are safe integers. Their mathematical sum is $18014398509481979$, which is not a safe integer and is not represented exactly: in JavaScript, `lo + hi` evaluates to $18014398509481980$. Then `Math.floor((lo + hi) / 2)` evaluates to $9007199254740990$. The mathematical midpoint $\lfloor (\mathrm{lo}+\mathrm{hi})/2 \rfloor$ is $9007199254740989$, which is what `lo + Math.floor((hi - lo) / 2)` returns.

No array you can allocate in this course has an index near $2^{53}$. On real index pairs the two expressions usually agree. The subtraction form is still the one in the code, for two reasons: it is the expression Lemma 3 analyzes, and it remains exact for every pair of safe integers $\mathrm{lo} \le \mathrm{hi}$, including pairs that are not plausible array indices. Fixed-width integer languages have a further reason, overflow of $\mathrm{lo}+\mathrm{hi}$, which JavaScript numbers do not share. This course still writes the form whose proof we have.

### 8.8 Duplicate keys: any occurrence, and the first occurrence

`binarySearch` returns when it sees equality. The index it returns is some match, not necessarily the leftmost. On

$$
b = [2, 5, 5, 5, 8]
$$

the any-occurrence search for $5$ does this:

| Step | $\mathrm{lo}$ | $\mathrm{hi}$ | $\mathrm{mid}$ | $b[\mathrm{mid}]$ | Decision |
| --- | --- | --- | --- | --- | --- |
| 1 | $0$ | $4$ | $2$ | $5$ | equal, return $2$ |

Index $2$ is a legal answer for "find any." The first occurrence is index $1$. A caller that deletes "the" matching record, or that counts how many copies exist by walking outward from the returned index, needs the first index, or the first and the last. This lecture owns the first. The independent assignment asks for the last, by the same invariant method.

The first-occurrence algorithm keeps the closed interval and the test $\mathrm{lo} \le \mathrm{hi}$. It does not return on equality. It records the match and continues on the left, where an earlier match would have to sit.

```javascript
function binarySearchFirst(a, key) {
  let lo = 0;
  let hi = a.length - 1;
  let answer = -1;
  while (lo <= hi) {
    const mid = lo + Math.floor((hi - lo) / 2);
    if (a[mid] < key) {
      lo = mid + 1;
    } else if (a[mid] > key) {
      hi = mid - 1;
    } else {
      answer = mid;
      hi = mid - 1;
    }
  }
  return answer;
}
```

Trace on $b$ for the key $5$:

| Step | $\mathrm{lo}$ | $\mathrm{hi}$ | $\mathrm{answer}$ before the body | $\mathrm{mid}$ | $b[\mathrm{mid}]$ | Update |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | $0$ | $4$ | $-1$ | $2$ | $5$ | $\mathrm{answer} \leftarrow 2$, $\mathrm{hi} \leftarrow 1$ |
| 2 | $0$ | $1$ | $2$ | $0$ | $2$ | $\mathrm{lo} \leftarrow 1$ |
| 3 | $1$ | $1$ | $2$ | $1$ | $5$ | $\mathrm{answer} \leftarrow 1$, $\mathrm{hi} \leftarrow 0$ |
| end | $1$ | $0$ | $1$ |  |  | return $1$ |

Further runs on $b$, all checked by the laboratory:

| Key | Any-occurrence index | First-occurrence index |
| --- | --- | --- |
| $5$ | $2$ | $1$ |
| $8$ | $4$ | $4$ |
| $2$ | $0$ | $0$ |
| $6$ | $-1$ | $-1$ |
| $1$ | $-1$ | $-1$ |
| $9$ | $-1$ | $-1$ |

On the earlier array $[1, 3, 4, 7, 7, 9, 12]$, the first occurrence of $7$ is also $3$. The any-occurrence search happened to land there immediately, so that array does not exhibit the difference. The array $b$ does.

A second, equally common, spelling uses a half-open live range and the test $\mathrm{lo} < \mathrm{hi}$, with $\mathrm{hi} \leftarrow \mathrm{mid}$ on the side $a[\mathrm{mid}] \ge \mathrm{key}$, and with one inspection of $a[\mathrm{lo}]$ after the loop. That spelling is correct when the updates and the final read travel together. It is a different invariant. Mixing it with the any-occurrence updates — in particular using $\mathrm{lo} < \mathrm{hi}$ while still returning only from inside the loop — drops the one-element interval, as Section 8.7 showed. This lecture commits to the closed interval and the recorded answer.

Each iteration of `binarySearchFirst` shrinks the length to at most $\lfloor L/2 \rfloor$, by the same arithmetic as Lemma 3: the branch $a[\mathrm{mid}] < \mathrm{key}$ is the right branch, and both other branches set $\mathrm{hi} \leftarrow \mathrm{mid}-1$. The worst-case number of iterations is therefore at most $W(n)$. A key larger than every element always takes the right branch and attains $W(n) = \lfloor \log n \rfloor + 1$. The running time is $\Theta(\log n)$ in the worst case, and the extra space of this iterative form is $\Theta(1)$.

### 8.9 Correctness

**Theorem 5.** Assume $a$ is sorted ascending. `binarySearch(a, key)` returns an index $i$ with $a[i] = \mathrm{key}$ if any such index exists, and returns $-1$ if none exists.

**Proof.** The argument is an induction on the number of completed iterations, maintaining the invariant of Section 8.3, plus the termination already proved.

Initialization, zero iterations completed. $\mathrm{lo} = 0$ and $\mathrm{hi} = n-1$. If $n = 0$, then $\mathrm{hi} = -1$, the numeric bounds in clause 1 hold, and clauses 2 and 3 quantify over no indices. If $n \ge 1$, no index is less than $0$ and no index is greater than $n-1$. The invariant holds before any comparison. Sortedness is not yet used.

Maintenance. Assume the invariant at the start of an iteration with $\mathrm{lo} \le \mathrm{hi}$, and let $\mathrm{mid}$ be as in Lemma 2, so the read $a[\mathrm{mid}]$ is inside the array.

If $a[\mathrm{mid}] = \mathrm{key}$, the function returns $\mathrm{mid}$. The returned index satisfies the specification. The loop invariant is not required after a return.

If $a[\mathrm{mid}] < \mathrm{key}$, sortedness gives $a[j] \le a[\mathrm{mid}] < \mathrm{key}$ for every $j \le \mathrm{mid}$, so $a[j] < \mathrm{key}$. The assignment $\mathrm{lo} \leftarrow \mathrm{mid}+1$ makes clause 2 true for the new $\mathrm{lo}$. Clause 3 is unchanged because $\mathrm{hi}$ is unchanged. Clause 1 holds because $\mathrm{mid}+1 \le \mathrm{hi}+1 \le n$.

If $a[\mathrm{mid}] > \mathrm{key}$, sortedness gives $a[j] \ge a[\mathrm{mid}] > \mathrm{key}$ for every $j \ge \mathrm{mid}$. The assignment $\mathrm{hi} \leftarrow \mathrm{mid}-1$ makes clause 3 true for the new $\mathrm{hi}$. Clause 2 is unchanged. Clause 1 holds because $\mathrm{mid}-1 \ge \mathrm{lo}-1 \ge -1$.

Termination. Section 8.5 showed that every non-returning iteration strictly decreases a nonnegative length, so the loop reaches $\mathrm{lo} > \mathrm{hi}$. At that moment the invariant's clauses 2 and 3 cover every index: an index $j$ cannot satisfy both $j \ge \mathrm{lo}$ and $j \le \mathrm{hi}$. No cell equals the key. The function returns $-1$.

If a match exists, the invariant forbids the loop from emptying the interval before the match has been seen: a match cannot sit in a discarded side. The loop returns only from the equality branch, and it does terminate, so it returns a real match. The match it returns is whichever one the midpoint hits first. The theorem claims existence of a correct index, not uniqueness.

**Theorem 6.** Assume $a$ is sorted ascending. `binarySearchFirst(a, key)` returns the smallest index $i$ with $a[i] = \mathrm{key}$, or $-1$ if the key is absent.

**Proof.** Maintain three statements at the start of every test of $\mathrm{lo} \le \mathrm{hi}$.

- **(L)** Every index $j < \mathrm{lo}$ has $a[j] < \mathrm{key}$.
- **(R)** Every index $j > \mathrm{hi}$ has $a[j] \ge \mathrm{key}$.
- **(F)** Either $\mathrm{answer} = -1$ and no index $j > \mathrm{hi}$ has $a[j] = \mathrm{key}$, or $\mathrm{answer}$ is the smallest index $j > \mathrm{hi}$ with $a[j] = \mathrm{key}$.

Initialization. $\mathrm{lo} = 0$, $\mathrm{hi} = n-1$, $\mathrm{answer} = -1$. All three statements quantify over empty index sets, or over no successful equality. They hold for any array, sorted or not.

Maintenance, in an iteration with $\mathrm{lo} \le \mathrm{hi}$. The midpoint lies inside the interval by Lemma 2.

Case $a[\mathrm{mid}] < \mathrm{key}$. Sortedness yields $a[j] < \mathrm{key}$ for every $j \le \mathrm{mid}$. Setting $\mathrm{lo} \leftarrow \mathrm{mid}+1$ restores (L). The values $\mathrm{hi}$ and $\mathrm{answer}$ stay put, so (R) and (F) stay put.

Case $a[\mathrm{mid}] > \mathrm{key}$. Sortedness yields $a[j] > \mathrm{key}$ for every $j \ge \mathrm{mid}$, hence $a[j] \ge \mathrm{key}$ and $a[j] \ne \mathrm{key}$. Setting $\mathrm{hi} \leftarrow \mathrm{mid}-1$ restores (R): every newly included index on the right is $\ge \mathrm{mid}$. For (F), the indices strictly between the new $\mathrm{hi}$ and the old $\mathrm{hi}$, namely $\mathrm{mid}, \ldots, \mathrm{hi}$, contain no match. The matches sitting strictly right of the new $\mathrm{hi}$ are exactly the matches that sat strictly right of the old $\mathrm{hi}$. The recorded answer is unchanged and remains correct.

Case $a[\mathrm{mid}] = \mathrm{key}$. Sortedness yields $a[j] \ge \mathrm{key}$ for every $j \ge \mathrm{mid}$. Setting $\mathrm{hi} \leftarrow \mathrm{mid}-1$ restores (R). Set $\mathrm{answer} \leftarrow \mathrm{mid}$. Then $\mathrm{answer} = \mathrm{hi}'+1$, so $\mathrm{answer}$ itself lies strictly right of the new $\mathrm{hi}$, and no index strictly between them exists. Every other match strictly right of the new $\mathrm{hi}$ is at least $\mathrm{mid}$. So $\mathrm{answer}$ is the smallest such match, which is (F).

Termination. Each case strictly decreases $\mathrm{hi}-\mathrm{lo}+1$, exactly as in the any-occurrence loop, so the loop ends with $\mathrm{lo} > \mathrm{hi}$. Every index is then either $< \mathrm{lo}$ or $> \mathrm{hi}$. By (L), no index $< \mathrm{lo}$ holds the key. By (F), the matches among indices $> \mathrm{hi}$ are summarized by $\mathrm{answer}$. Therefore $\mathrm{answer}$ is the leftmost match in the whole array, or $-1$ when there is none.

Sortedness is necessary. On the unsorted array $[3, 1]$ with key $1$, the first iteration has $\mathrm{mid} = 0$, sees $3 > 1$, sets $\mathrm{hi} = -1$, and returns $-1$, leaving the real match at index $1$ unread. The maintenance case "$a[\mathrm{mid}] > \mathrm{key}$ implies the right side is also greater" is the step that fails.

---

## 9. Divide-and-conquer

### 9.1 The pattern and the recurrence shape

**Definition.** A *divide-and-conquer* algorithm solves a problem in three steps.

1. *Divide.* Split the input into one or more smaller instances of the same problem.
2. *Solve.* Solve each smaller instance by the same algorithm. When an instance is small enough, solve it by a base case that does not split further.
3. *Combine.* Build the answer of the original instance from the answers of the smaller instances.

The reason for the pattern is reuse of one algorithm at several scales, with a cost that a recurrence can name. The mechanism is the split and the combine. A pattern that cannot name a measure for the smaller instances is not yet an algorithm; Section 3.1 still applies.

Suppose the input size is $n$, the divide produces $a$ subproblems each of size $n/b$, and the divide together with the combine costs $f(n)$ in the RAM model, outside the recursive solves. The running time satisfies the shape

$$
T(n) = a\, T(n/b) + f(n)
$$

for $n$ large enough that the split makes sense, with a constant base $T(n) = \Theta(1)$ for $n$ below a fixed bound. Lecture 01's Master Theorem and substitution method solve the floor-free form of this shape on exact powers of $b$. When the algorithm uses $\lfloor n/b \rfloor$ or $\lceil n/b \rceil$, a careful solution either restricts the induction to powers of $b$ and then fills the gaps, or writes the floors into the inductive step the way Theorem 4 did. This lecture does the second for binary search and for the power function's multiplication count. It does not pretend that $n/2$ and $\lfloor n/2 \rfloor$ are the same symbol.

### 9.2 Binary search is the pattern with an empty combine

Binary search divides the closed interval into one smaller closed interval. It solves that one subproblem. The answer of the subproblem is already the answer of the original problem: an index into the same array, or $-1$. There is no combine step. In the shape above, $a = 1$, $b = 2$, and $f(n) = \Theta(1)$. The floor-accurate form is

$$
T(n) = T(\lfloor n/2 \rfloor) + \Theta(1),
$$

which Theorem 4 solved. An empty combine is still the pattern. It is the pattern in its cheapest form: one subproblem, constant work beside it.

### 9.3 A recurrence Lecture 06 will solve

Sorting by splitting an array into two halves, sorting each half, and merging the two sorted halves is divide-and-conquer with a real combine. If the split is into $\lfloor n/2 \rfloor$ and $\lceil n/2 \rceil$ and the merge reads each cell a constant number of times, the cost has the shape

$$
T(n) = T(\lfloor n/2 \rfloor) + T(\lceil n/2 \rceil) + \Theta(n),
$$

which is written $T(n) = 2T(n/2) + \Theta(n)$ when $n$ is a power of two. Lecture 01's Master Theorem gives $\Theta(n \log n)$ for that power-of-two shape. Lecture 06 owns the merge, the code, the floor-accurate solution, and quicksort. This lecture does not write either sorting algorithm.

The identity that makes two halves a full split is Lemma 1: the two sizes sum to $n$. The examination asks you to solve a cousin of this recurrence, with $\Theta(1)$ combine cost rather than $\Theta(n)$, by the strong induction practiced here.

### 9.4 Integer power by squaring

The direct computation of $x^n$ multiplies $n$ copies of $x$ and uses $n-1$ multiplications for $n \ge 1$. The exponent's binary representation gives a shorter product. Halving an even exponent is squaring; an odd exponent peels off one factor of $x$ and leaves an even exponent. That is divide-and-conquer with one subproblem. The combine is one squaring, plus one extra multiplication by $x$ when the exponent is odd and at least $3$.

Let $x$ be a number and let $n$ be a nonnegative integer. Define $\mathrm{Pow}(x, n)$ by

- $\mathrm{Pow}(x, 0) = 1$
- $\mathrm{Pow}(x, 1) = x$
- if $n \ge 2$ is even, $\mathrm{Pow}(x, n) = y \cdot y$ where $y = \mathrm{Pow}(x, n/2)$
- if $n \ge 3$ is odd, $\mathrm{Pow}(x, n) = (y \cdot y) \cdot x$ where $y = \mathrm{Pow}(x, (n-1)/2)$

The measure is $n$. An even $n \ge 2$ calls $n/2 < n$. An odd $n \ge 3$ calls $(n-1)/2 \le (n-1)/2 < n$. The case $n = 1$ is a base, so the odd branch never calls the exponent $0$ through the formula $(1-1)/2$; the code returns before that. Both $0$ and $1$ are bases so that $x^1$ costs no multiplication.

```javascript
function power(x, n) {
  if (!Number.isFinite(x)) {
    throw new Error("power base must be a finite number");
  }
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("power exponent must be a nonnegative integer");
  }
  return powerFrom(x, n);
}

function powerFrom(x, n) {
  if (n === 0) {
    return { value: 1, multiplications: 0 };
  }
  if (n === 1) {
    return { value: x, multiplications: 0 };
  }
  if (n % 2 === 0) {
    const half = powerFrom(x, n / 2);
    const value = half.value * half.value;
    return finish(x, value, half.multiplications + 1);
  }
  const half = powerFrom(x, (n - 1) / 2);
  const value = half.value * half.value * x;
  return finish(x, value, half.multiplications + 2);
}

function finish(x, value, multiplications) {
  if (Number.isInteger(x) && !Number.isSafeInteger(value)) {
    throw new Error("power left the safe integer range");
  }
  return { value, multiplications };
}
```

When $x$ is an integer, the laboratory function refuses a result that is not a safe integer, because beyond that range JavaScript `*` is not a faithful model of integer multiplication. The theorem below is about the mathematical function. The traced calls stay inside the safe integers: $2^{13} = 8192$, and the other powers in the table are smaller.

**Theorem 7.** For every number $x$ and every integer $n \ge 0$, $\mathrm{Pow}(x, n) = x^n$, where $x^0 = 1$ by the empty-product convention, including $x = 0$.

**Proof.** Strong induction on $n$.

Base $n = 0$: the definition returns $1$. Base $n = 1$: the definition returns $x$. Both match.

Inductive hypothesis: fix $n \ge 2$ and assume $\mathrm{Pow}(x, k) = x^k$ for every $k$ with $0 \le k < n$.

If $n$ is even, the call uses $n/2$, and $0 < n/2 < n$. The hypothesis gives $y = x^{n/2}$. The returned value is $y \cdot y = x^{n/2} \cdot x^{n/2} = x^n$.

If $n$ is odd, then $n \ge 3$ and the call uses $(n-1)/2$, which is an integer strictly between $0$ and $n$. The hypothesis gives $y = x^{(n-1)/2}$. The returned value is

$$
(y \cdot y) \cdot x = x^{n-1} \cdot x = x^n.
$$

By strong induction the claim holds for every $n \ge 0$.

Let $M(n)$ be the number of multiplications $\mathrm{Pow}$ performs on exponent $n$, not counting multiplications inside the arithmetic of the caller. Then $M(0) = 0$, $M(1) = 0$, $M(n) = M(n/2) + 1$ for even $n \ge 2$, and $M(n) = M((n-1)/2) + 2$ for odd $n \ge 3$.

Let $\nu(n)$ be the number of $1$-bits in the binary expansion of $n$, for $n \ge 1$. So $\nu(1) = 1$, $\nu(2) = 1$, $\nu(13) = 3$ because $13 = 1101_2$.

**Theorem 8.** For every integer $n \ge 1$,

$$
M(n) = \lfloor \log n \rfloor + \nu(n) - 1.
$$

In particular $M(n) \le 2 \lfloor \log n \rfloor$, so the number of multiplications is $\Theta(\log n)$, and the recursion depth is also $\Theta(\log n)$ because each call halves the exponent, roughly, and the stack holds one frame per call.

**Proof.** Strong induction on $n$.

Base $n = 1$. The left side is $0$. The right side is $\lfloor \log 1 \rfloor + \nu(1) - 1 = 0 + 1 - 1 = 0$.

Inductive hypothesis: the formula holds for every exponent from $1$ through $n-1$, for some $n \ge 2$.

Case even, $n = 2m$ with $m \ge 1$. Then $M(n) = M(m) + 1$. The hypothesis applies to $m$ because $m < n$. So

$$
M(n) = \lfloor \log m \rfloor + \nu(m) - 1 + 1 = \lfloor \log m \rfloor + \nu(m).
$$

The binary expansion of $n$ is the expansion of $m$ followed by a zero, so $\nu(n) = \nu(m)$. Also $\lfloor \log n \rfloor = \lfloor \log (2m) \rfloor = \lfloor \log m \rfloor + 1$. Therefore

$$
\lfloor \log n \rfloor + \nu(n) - 1 = \lfloor \log m \rfloor + 1 + \nu(m) - 1 = \lfloor \log m \rfloor + \nu(m),
$$

which equals $M(n)$.

Case odd, $n = 2m+1$ with $m \ge 1$, so $n \ge 3$. Then $M(n) = M(m) + 2$, and

$$
M(n) = \lfloor \log m \rfloor + \nu(m) - 1 + 2 = \lfloor \log m \rfloor + \nu(m) + 1.
$$

The binary expansion of $n$ is the expansion of $m$ followed by a one, so $\nu(n) = \nu(m) + 1$. It remains to check the logarithm. Let $L = \lfloor \log m \rfloor$, so $2^L \le m \le 2^{L+1}-1$. Then

$$
2^{L+1} \le 2m < 2m+1 \le 2(2^{L+1}-1)+1 = 2^{L+2} - 1.
$$

Hence $2^{L+1} \le n \le 2^{L+2}-1$, and $\lfloor \log n \rfloor = L+1 = \lfloor \log m \rfloor + 1$. The claimed formula becomes

$$
\lfloor \log n \rfloor + \nu(n) - 1 = \lfloor \log m \rfloor + 1 + \nu(m) + 1 - 1 = \lfloor \log m \rfloor + \nu(m) + 1,
$$

which equals $M(n)$.

By strong induction the formula holds for every $n \ge 1$.

The inequality $M(n) \le 2\lfloor \log n \rfloor$ for $n \ge 2$ follows because $\nu(n) \le \lfloor \log n \rfloor + 1$, so $\lfloor \log n \rfloor + \nu(n) - 1 \le 2\lfloor \log n \rfloor$. For $n = 1$ both sides of the $\Theta$ statement are handled by the exact formula: zero multiplications is $\Theta(1)$ at a fixed input, and the asymptotic statement is for growing $n$.

Trace of $\mathrm{Pow}(2, 13)$. Since $13 = 1101_2$, one has $\lfloor \log 13 \rfloor = 3$ because $2^3 = 8 \le 13 < 16$, and $\nu(13) = 3$, so Theorem 8 predicts $3+3-1 = 5$ multiplications. The value must be $2^{13} = 8192$.

| Call | Branch | Returns | Multiplications charged at this call | Running total |
| --- | --- | --- | --- | --- |
| $\mathrm{Pow}(2, 1)$ | base | $2$ | $0$ | $0$ |
| $\mathrm{Pow}(2, 3)$ | odd, half is $2^1$ | $(2 \cdot 2) \cdot 2 = 8$ | $2$ | $2$ |
| $\mathrm{Pow}(2, 6)$ | even, half is $2^3$ | $8 \cdot 8 = 64$ | $1$ | $3$ |
| $\mathrm{Pow}(2, 13)$ | odd, half is $2^6$ | $(64 \cdot 64) \cdot 2 = 8192$ | $2$ | $5$ |

The five multiplications are $2\cdot 2$, that product times $2$, $8\cdot 8$, $64\cdot 64$, and that product times $2$.

A few more values, all predicted by Theorem 8 and checked by the laboratory. The base is $2$.

| $n$ | Binary | $\lfloor \log n \rfloor$ | $\nu(n)$ | $M(n)$ | $2^n$ |
| --- | --- | --- | --- | --- | --- |
| $1$ | $1$ | $0$ | $1$ | $0$ | $2$ |
| $2$ | $10$ | $1$ | $1$ | $1$ | $4$ |
| $3$ | $11$ | $1$ | $2$ | $2$ | $8$ |
| $8$ | $1000$ | $3$ | $1$ | $3$ | $256$ |
| $13$ | $1101$ | $3$ | $3$ | $5$ | $8192$ |

Also $\mathrm{Pow}(2, 0) = 1$ with $0$ multiplications, the empty product. Depth of the call $\mathrm{Pow}(2, 13)$ is $4$ frames, one per row of the trace. The pending work in each frame is the squaring, so these calls are not tail calls. The stack space is $\Theta(\log n)$ in Node.js, which is the same order as the number of multiplications. Eliminating the tail would not change the $\Theta$ class of this particular recursion by more than a constant, because the depth is already logarithmic; the reason to refuse the optimization is portability and honesty, not the difference between $\Theta(\log n)$ and $\Theta(\log n)$. For factorial, the same refusal is the difference between $\Theta(n)$ stack and $\Theta(1)$ stack.

---

## 10. The Tower of Hanoi

### 10.1 The rules and the recurrence

Three pegs are called $A$, $B$, and $C$. On peg $A$ there sit $n$ disks, ordered by size: disk $1$ is the smallest, disk $n$ is the largest, and no larger disk sits on a smaller disk. Pegs $B$ and $C$ are empty. A *move* transfers the top disk of one peg onto the top of another peg. The move is legal only when the destination peg is empty or its current top disk is larger than the disk being moved. The goal is to move the tower from $A$ to $C$, using $B$ as spare, with every intermediate placement legal.

The smallest interesting cases are direct. For $n = 0$ there is nothing to do: $0$ moves. For $n = 1$ the single move $A \to C$ is legal: $1$ move.

For $n \ge 1$, a legal solution that actually works is:

1. Move the top $n-1$ disks from $A$ to $B$, using $C$ as spare.
2. Move disk $n$ from $A$ to $C$. This is legal because the $n-1$ smaller disks are on $B$, so $A$'s top is disk $n$ and $C$ is empty.
3. Move the $n-1$ disks from $B$ to $C$, using $A$ as spare. Each of them is smaller than disk $n$, so disk $n$ may sit under them on $C$.

Let $T(n)$ be the number of moves this procedure makes. Then $T(0) = 0$ and

$$
T(n) = 2T(n-1) + 1 \qquad (n \ge 1).
$$

The measure is $n$. Both recursive calls use $n-1$. The procedure terminates. It is binary recursion, and it is not tail recursive. In `hanoiMoves` the first call is followed by a push and by the second call. The second call is an expression statement, not a `return` of that call, so the function still has to finish after it. Neither call is in tail position.

The natural implementation records moves by pushing into one array, so that each move costs $\Theta(1)$ work outside the recursive calls. The recurrence $T(n) = 2T(n-1)+1$ then counts both the moves and, up to the $\Theta$, the running time.

```javascript
function hanoiMoves(n, from, to, aux) {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("hanoi disk count must be a nonnegative integer");
  }
  const moves = [];
  function go(k, source, target, spare) {
    if (k === 0) {
      return;
    }
    go(k - 1, source, spare, target);
    moves.push([source, target]);
    go(k - 1, spare, target, source);
  }
  go(n, from, to, aux);
  return moves;
}

function hanoiCount(n) {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("hanoi disk count must be a nonnegative integer");
  }
  if (n === 0) {
    return 0;
  }
  return 2 * hanoiCount(n - 1) + 1;
}
```

`hanoiCount` implements the same recurrence with one recursive call, then a multiplication by $2$ and an addition of $1$. Its running time is $\Theta(n)$, not $\Theta(2^n)$. It computes the number. It does not exhibit the moves. The exponential cost belongs to any procedure that writes every move, because there are exponentially many moves, as Theorem 9 shows. `hanoiMoves` does $\Theta(1)$ work per call beside the two recursive calls, and the number of calls is $2^{n+1}-1$ by the same counting argument as Theorem 12 in Section 11, of which $2^n - 1$ calls actually push a move. The running time of `hanoiMoves` is therefore $\Theta(2^n)$, and the output length is $2^n - 1$.

The maximum stack depth of `go` is $n+1$: the first thing `go(n)` does is call `go(n-1)`, which calls `go(n-2)`, and so on down to `go(0)`, before any move is pushed. Depth is linear. Time, for the move list, is exponential. Those are different functions of $n$.

### 10.2 A trace for two disks and for three

`hanoiMoves(2, "A", "C", "B")` produces

$$
A \to B,\quad A \to C,\quad B \to C.
$$

Three moves, and $2^2 - 1 = 3$.

`hanoiMoves(3, "A", "C", "B")` produces seven moves. The call tree below shows the move recorded by each positive call. Each call on $k \ge 1$ also makes two calls on $k-1$; the drawing collapses a call on $1$ to the single move it records, and omits the two calls on $0$ that surround that move.

```text
go(3, A, C, B)
├─ go(2, A, B, C)
│  ├─ go(1, A, C, B)    records A → C
│  ├─ record A → B
│  └─ go(1, C, B, A)    records C → B
├─ record A → C
└─ go(2, B, C, A)
   ├─ go(1, B, A, C)    records B → A
   ├─ record B → C
   └─ go(1, A, C, B)    records A → C
```

The move list, in order, is

$$
A \to C,\;
A \to B,\;
C \to B,\;
A \to C,\;
B \to A,\;
B \to C,\;
A \to C.
$$

There are $7 = 2^3 - 1$ moves. The laboratory compares this list, and the two-disk list, exactly.

### 10.3 The closed form, by induction

Unrolling the recurrence suggests the form, and the induction proves it. For $n \ge 1$,

$$
\begin{align*}
T(n)
  &= 1 + 2T(n-1) \\
  &= 1 + 2 + 4T(n-2) \\
  &= 1 + 2 + 4 + \cdots + 2^{n-1} T(0).
\end{align*}
$$

Since $T(0) = 0$, the last term vanishes, and $T(n)$ is a geometric series. The next lemma evaluates that series. Theorem 9 then proves the closed form directly from the recurrence, so the result does not depend on how many times you are willing to unroll.

**Lemma 6.** For every integer $n \ge 0$,

$$
\sum_{k=0}^{n-1} 2^k = 2^n - 1.
$$

When $n = 0$ the sum is empty and equals $0$, and $2^0 - 1 = 0$.

**Proof.** Weak induction on $n$.

Base $n = 0$: both sides are $0$.

Inductive hypothesis: assume the equation at some $n \ge 0$.

Step:

$$
\sum_{k=0}^{n} 2^k
  = \left(\sum_{k=0}^{n-1} 2^k\right) + 2^n
  = (2^n - 1) + 2^n
  = 2^{n+1} - 1.
$$

The step is the lemma at $n+1$. By weak induction the lemma holds for every integer $n \ge 0$.

**Theorem 9.** The move count of the procedure satisfies $T(n) = 2^n - 1$ for every integer $n \ge 0$.

**Proof.** Weak induction on $n$.

Base $n = 0$: $T(0) = 0 = 2^0 - 1$.

Inductive hypothesis: assume $T(n) = 2^n - 1$ for some $n \ge 0$.

Step: the recurrence gives

$$
T(n+1) = 2T(n) + 1 = 2(2^n - 1) + 1 = 2^{n+1} - 2 + 1 = 2^{n+1} - 1.
$$

By weak induction the closed form holds for every $n \ge 0$.

Instances: $T(1) = 1$, $T(2) = 3$, $T(3) = 7$, $T(4) = 15$, $T(10) = 1023$. In JavaScript, $2^n$ is an exact number for every integer $n$ with $0 \le n \le 53$, and $2^n - 1$ is a safe integer throughout that range, including $n = 53$, where the value is $2^{53}-1$ itself. The recursive `hanoiCount` uses $n+1$ frames and is the wrong way to evaluate the formula at large $n$; the closed form is a constant amount of arithmetic inside the safe range.

### 10.4 Why $2^n - 1$ moves are necessary

Theorem 9 is an upper bound on the length of the shortest legal solution, because the procedure is one legal solution. The matching lower bound says the procedure is optimal.

Let $L(n)$ be the minimum, over all legal sequences, of the number of moves that transfer $n$ disks from a designated source peg to a designated target peg, using the third peg as spare, starting from a legal tower on the source. Set $L(0) = 0$.

**Theorem 10.** For every integer $n \ge 0$, $L(n) = 2^n - 1$.

**Proof.** The procedure of Section 10.1 is a legal solution of length $T(n)$, so $L(n) \le T(n) = 2^n - 1$ by Theorem 9. The rest of the proof shows $L(n) \ge 2^n - 1$.

First, $L(n) \ge 2L(n-1) + 1$ for $n \ge 1$, with $L(0) = 0$. Consider any legal solution that moves an $n$-disk tower from source $S$ to target $G$, and consider the largest disk, disk $n$. It starts on $S$ and must end on $G$, so it moves at least once. Consider its first move, and let $D$ be the peg it moves to on that move. Immediately before that move, disk $n$ is free to leave $S$, so none of the $n-1$ smaller disks is on $S$. The destination $D$ must be able to receive disk $n$, so none of the smaller disks is on $D$: a smaller disk there would make the move illegal. The only remaining peg therefore holds all $n-1$ smaller disks. A legal configuration of those $n-1$ disks on a single peg is unique: they must appear in size order, smallest on top, because a larger disk is never placed on a smaller one at any earlier time. Reaching that unique tower, from the initial tower of $n-1$ disks on $S$ (they started there, above disk $n$), is itself an $(n-1)$-disk transfer. It costs at least $L(n-1)$ moves, all of them occurring before the first move of disk $n$.

After the last move of disk $n$, that disk sits on $G$ and never moves again. Immediately after that move, $G$ holds disk $n$ and no smaller disk, by the same legality argument. All $n-1$ smaller disks therefore form the unique legal tower on the other peg. The remainder of the solution transfers that tower onto $G$. Disk $n$ does not obstruct the transfer: every smaller disk is allowed to sit on it. The remainder costs at least $L(n-1)$ moves. Between the prefix and the suffix there is at least the one move of disk $n$ just discussed. If disk $n$ moves more than once, the sequence is longer, not shorter. Hence every legal solution has length at least $2L(n-1) + 1$, and the minimum $L(n)$ satisfies the same inequality.

Now prove $L(n) \ge 2^n - 1$ by weak induction.

Base $n = 0$: $L(0) = 0 = 2^0 - 1$.

Inductive hypothesis: assume $L(n) \ge 2^n - 1$.

Step:

$$
L(n+1) \ge 2L(n) + 1 \ge 2(2^n - 1) + 1 = 2^{n+1} - 1.
$$

Thus $L(n) \ge 2^n - 1$ for every $n \ge 0$. Combined with the matching upper bound, $L(n) = 2^n - 1$.

The largest disk moves exactly once in every optimal solution. If it moved twice or more, the inequality would be strict and the length would exceed $2^n - 1$. The procedure moves it exactly once, in step 2, from $A$ directly to $C$.

---

## 11. Backtracking: every subset

Backtracking, in the narrow sense used here, is a recursion that tries each legal choice at the current position, recurses, and then undoes the choice. This lecture uses it for one task: generate the power set. It does not become a catalogue of puzzles.

### 11.1 Include or exclude

Let the input be an array of $n$ distinct elements, indexed $0$ through $n-1$. A subset is determined by a choice, for each index, of whether that element is in the subset. The algorithm walks the indices in order. At index $i$ it tries the exclude choice first, then the include choice. Undoing the include is a `pop` on an array that represents the subset under construction.

```javascript
function subsets(elements) {
  const result = [];
  const current = [];
  function choose(i) {
    if (i === elements.length) {
      result.push(current.slice());
      return;
    }
    choose(i + 1);
    current.push(elements[i]);
    choose(i + 1);
    current.pop();
  }
  choose(0);
  return result;
}
```

The measure of `choose(i)` is $n - i$. Each recursive call uses $i+1$. The base case records a copy of `current` and does not call further. The copy is required: `current` is mutated on the way back down the other branch, and the recorded subset must be a snapshot.

Neither call is in tail position. After the exclude call, the function still pushes and explores the include branch. After the include call, the function still pops. The maximum depth is $n+1$ frames: indices $0, 1, \ldots, n$ are live together along the path to the first leaf, which is the all-exclude path.

### 11.2 The recursion tree for two elements

Let the input be $[1, 2]$. The tree of calls, with the subset recorded at each leaf, is

```text
choose(0)  current = []
├─ exclude 1
│  └─ choose(1)  current = []
│     ├─ exclude 2
│     │  └─ choose(2)  record []
│     └─ include 2
│        └─ choose(2)  record [2]
└─ include 1
   └─ choose(1)  current = [1]
      ├─ exclude 2
      │  └─ choose(2)  record [1]
      └─ include 2
         └─ choose(2)  record [1, 2]
```

The emission order is

$$
[],\quad [2],\quad [1],\quad [1, 2].
$$

The order is part of the specification of this procedure. A different convention, include first, would emit a different sequence and would still be a correct generator of the power set. The laboratory checks this order, not a sorted order.

The same procedure on $[1, 2, 3]$ emits

$$
\begin{align*}
&[],\; [3],\; [2],\; [2, 3],\\
&[1],\; [1, 3],\; [1, 2],\; [1, 2, 3].
\end{align*}
$$

Eight subsets. On the empty input, `choose(0)` is already the base case and the result is `[[]]`, one subset, the empty subset. On `[1]` the result is `[[], [1]]`.

### 11.3 How many subsets, how many calls

**Theorem 11.** On an input of $n$ elements, `subsets` returns each subset exactly once. In particular it returns $2^n$ subsets.

**Proof.** A run of choices from index $0$ through index $n-1$ is a vector $c \in \{0,1\}^n$, where $c_i = 1$ means element $i$ was included. The tree explores every such vector: at each index both calls happen, independently of the choices above. Different vectors differ at some first index $i$, and the recorded arrays differ on whether `elements[i]` is present, so different vectors produce different subsets. Every subset $S$ arises from the vector with $c_i = 1$ exactly when `elements[i]` is in $S$. The map is therefore a bijection between $\{0,1\}^n$ and the power set of the input. The domain has $2^n$ vectors.

**Theorem 12.** Let $C(n)$ be the number of calls to `choose` made while generating the subsets of an $n$-element set, including the original call. Then $C(n) = 2^{n+1} - 1$.

**Proof.** A call on a suffix of $r$ remaining elements makes two calls on a suffix of $r-1$ elements, unless $r = 0$, in which case it makes none. So $C(0) = 1$ and $C(r) = 1 + 2C(r-1)$ for $r \ge 1$. Weak induction shows $C(r) = 2^{r+1} - 1$.

Base $r = 0$: $2^1 - 1 = 1$.

Hypothesis: $C(r) = 2^{r+1} - 1$.

Step: $C(r+1) = 1 + 2(2^{r+1} - 1) = 1 + 2^{r+2} - 2 = 2^{r+2} - 1$.

By weak induction, $C(r) = 2^{r+1} - 1$ for every integer $r \ge 0$.

The leaves are the calls with nothing remaining. There are $2^n$ of them by Theorem 11, one per subset. In particular $C(0) = 1$, $C(2) = 2^3 - 1 = 7$, and $C(3) = 2^4 - 1 = 15$. The laboratory counts these three values.

**Corollary.** For any fixed element, exactly $2^{n-1}$ subsets contain it, and exactly $2^{n-1}$ omit it.

**Proof.** At that element's index the tree splits into an include subtree and an exclude subtree. Each is the full choice tree on the remaining $n-1$ elements, so each has $2^{n-1}$ leaves.

The same split counts subsets by size. Let $B(n, k)$ be the number of $k$-element subsets of an $n$-element set. The exclude branch contributes the $k$-element subsets of an $(n-1)$-element set. The include branch contributes the $(k-1)$-element subsets of an $(n-1)$-element set, each extended by the included element. Therefore

$$
B(n, k) = B(n-1, k) + B(n-1, k-1)
$$

for $n \ge 1$ and $k \ge 1$, with $B(n, 0) = 1$ for every $n \ge 0$ (one way to exclude everyone), $B(0, 0) = 1$, and $B(0, k) = 0$ for $k > 0$. Also $B(n, k) = 0$ when $k > n$.

The table through $n = 4$, computed only from that recurrence, is the one the examination extends. It is Pascal's triangle, obtained here as a corollary of include-or-exclude rather than as a separate combinatorial theory.

| $n \backslash k$ | $0$ | $1$ | $2$ | $3$ | $4$ |
| --- | --- | --- | --- | --- | --- |
| $0$ | $1$ | $0$ | $0$ | $0$ | $0$ |
| $1$ | $1$ | $1$ | $0$ | $0$ | $0$ |
| $2$ | $1$ | $2$ | $1$ | $0$ | $0$ |
| $3$ | $1$ | $3$ | $3$ | $1$ | $0$ |
| $4$ | $1$ | $4$ | $6$ | $4$ | $1$ |

For example, $B(4, 2) = B(3, 2) + B(3, 1) = 3 + 3 = 6$.

Time and space. The procedure makes $\Theta(2^n)$ calls and does $\Theta(1)$ work in each call aside from copying. Each leaf copies its current subset. Element $i$ appears in $2^{n-1}$ subsets, so the sum of the lengths of all subsets is $n \cdot 2^{n-1}$. The total running time is $\Theta(n \cdot 2^n)$. The output occupies that much space. Besides the output, the algorithm stores the current path, of length at most $n$, and $n+1$ stack frames. Auxiliary space is $\Theta(n)$.

---

## 12. When a recursion is wrong

A recursive function that returns the wrong answer, or that does not return, has failed one of three obligations: the base value, the measure, or the postcondition the caller uses. The repair is to name which obligation failed, on a concrete input, before rewriting the function at random.

### 12.1 The base value is wrong

```javascript
function sumFromWrongBase(a, i) {
  if (i === a.length) {
    return 1;
  }
  return a[i] + sumFromWrongBase(a, i + 1);
}
```

On $[3, 1, 4]$ the calls still decrease the measure $n - i$, and they still terminate. The arithmetic on the way back is $4 + 1 = 5$, then $1 + 5 = 6$, then $3 + 6 = 9$. Theorem 3 says the true sum is $8$. The only broken clause in the proof is the base $t = 0$: the empty sum was defined to be $0$, and this function returns $1$. Every nonempty suffix is then too large by $1$.

The same class of bug in factorial is a base `if (n === 1) return 1` with no case for $0$. The call `factorial(0)` never hits that base. It calls `factorial(-1)`, the measure $n$ is no longer bounded below by the base, and the descent does not land. Two failures travel together: the base does not cover the arguments the recursive case can reach, and once $n$ is negative the measure is not a nonnegative integer decreasing toward a base. The repair for the mathematical factorial is the base $n = 0$ returning $1$, which covers the call made by $n = 1$.

A binary-search version of the same mistake is the any-occurrence loop written `while (lo < hi)` with the cell inspected only inside the loop. On the one-element array $[4]$ and key $4$, the interval that still contains the key is never read. The "base" of the iteration, the one-cell interval, returns "absent" without looking.

### 12.2 The measure does not decrease

```javascript
function locateStuck(a, key, lo, hi) {
  if (lo > hi) {
    return -1;
  }
  const mid = lo + Math.floor((hi - lo) / 2);
  if (a[mid] === key) {
    return mid;
  }
  if (a[mid] < key) {
    return locateStuck(a, key, mid, hi);
  }
  return locateStuck(a, key, lo, mid - 1);
}
```

The right-hand call passes `mid` rather than `mid + 1`. Consider $a = [1, 3]$, key $3$, started at $\mathrm{lo} = 0$, $\mathrm{hi} = 1$.

| Call | $\mathrm{lo}$ | $\mathrm{hi}$ | length | $\mathrm{mid}$ | $a[\mathrm{mid}]$ | Next call |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | $0$ | $1$ | $2$ | $0$ | $1$ | $(\mathrm{lo}, \mathrm{hi}) = (0, 1)$ |
| 2 | $0$ | $1$ | $2$ | $0$ | $1$ | $(0, 1)$ again |

The length stays $2$. The measure that Lemma 3 depended on does not decrease, because that lemma's right branch was $\mathrm{lo} \leftarrow \mathrm{mid}+1$, which excludes the cell already known to be too small. Here the cell $a[0] = 1 < 3$ remains inside the interval forever. The function does not terminate.

The left branch of this particular function still decreases the length, so some inputs do return. Termination has to hold for every legal input, not for the inputs that were tried first. The repair is $\mathrm{lo} \leftarrow \mathrm{mid}+1$ on the side $a[\mathrm{mid}] < \mathrm{key}$. After that repair the function is `searchRange`, and Theorem 5 applies if the array is sorted.

A measure can also fail by increasing: `sumTo(n)` calling `sumTo(n)` , or calling `sumTo(n+1)`, with a base at $0$. The call's argument is not smaller in the chosen measure. Naming the measure in a comment, and checking it against the actual arguments of each call, is the diagnosis.

### 12.3 The combine step assumes a result the subcalls did not return

Divide-and-conquer is allowed to use a fact about a subproblem only when that fact is the postcondition of the call that solved it. Sortedness of the original input is not automatically a postcondition of a call that was asked for something else.

The minimum of a nonempty subarray $a[\mathrm{lo}], \ldots, a[\mathrm{hi}]$ obeys a correct divide-and-conquer recurrence: the minimum on a one-cell range is that cell, and the minimum on a longer range is the smaller of the minimum of the left part and the minimum of the right part. Both subcalls return a number. Their postcondition is "this number equals the minimum of my range."

```javascript
function minimumWrong(a, lo, hi) {
  if (lo === hi) {
    return a[lo];
  }
  const mid = lo + Math.floor((hi - lo) / 2);
  const left = minimumWrong(a, lo, mid);
  const right = minimumWrong(a, mid + 1, hi);
  return left;
}
```

The combine returns `left`. That would be correct if every left-half value were at most every right-half value, because then the left minimum would be the global minimum. The subcalls did not return that sortedness. They were not asked to sort. They returned two minima. On $a = [4, 1]$, the call on $0..\,1$ sets $\mathrm{mid} = 0$, receives `left` $= 4$ and `right` $= 1$, and returns $4$. The minimum is $1$.

The repair uses only the postcondition: return the smaller of `left` and `right`. The subcalls are already correct; the combine was the entire bug. This is the same discipline as the binary-search proof, read in the other direction. Theorem 5 is allowed to discard a side only because sortedness of the live interval, plus one comparison, implies the postcondition about the discarded indices. A combine that needs sorted halves must call a procedure whose postcondition is "I returned a sorted half." Lecture 06's merge has that obligation. A sum, a minimum, or an unsorted partition does not discharge it.

---

## 13. Laboratory

Work these by hand before you read the program. The program asserts the same numbers. If your hand trace and the assertion disagree, the hand trace is the thing to repair first; the assertion is the trace from the chapter.

**Guided trace.** Cover the return column in Section 4.2 and fill it from the stack diagram alone. Then uncover it. The depth at the base case is $5$, the entry order is $4, 3, 2, 1, 0$, and the final value is $24$.

**Problems.**

1. Repeat the frame count for `factorial(10)`. State the value, the maximum depth, and the first and last parameters entered.
2. On $a = [1, 3, 4, 7, 7, 9, 12]$, trace `binarySearch` for key $12$ and for key $5$, writing every $(\mathrm{lo}, \mathrm{hi}, \mathrm{mid})$.
3. On $b = [2, 5, 5, 5, 8]$, state the index returned by any-occurrence search for $5$ and the index returned by first-occurrence search for $5$.
4. Using Theorem 8, compute $M(13)$ and $2^{13}$ before you run `power`.
5. Write the seven moves of `hanoiMoves(3, "A", "C", "B")` from the call tree, and compute $T(4)$ from Theorem 9.
6. List the subsets of $[1, 2]$ in the order Section 11 emits them. State $C(3)$, the number of `choose` calls on a $3$-element input, from Theorem 12.
7. On $[3, 1, 4]$, compute both `sumFrom` and `sumIterative`. Identify which single return in `sumFromWrongBase` turns the sum into $9$.

Then save the following program as `lecture05-lab.mjs` and run `node lecture05-lab.mjs`. Change one assertion so that it must fail, confirm that the run throws, and restore it. The program reads no files, no network, and no command-line arguments.

## LABORATORY PROGRAM

```javascript
import assert from "node:assert/strict";

function factorial(n) {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("factorial is defined here for nonnegative integers");
  }
  if (n === 0) {
    return 1;
  }
  const value = n * factorial(n - 1);
  if (!Number.isSafeInteger(value)) {
    throw new Error("factorial left the safe integer range");
  }
  return value;
}

function factorialIterative(n) {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("factorial is defined here for nonnegative integers");
  }
  let result = 1;
  for (let k = 1; k <= n; k += 1) {
    result *= k;
    if (!Number.isSafeInteger(result)) {
      throw new Error("factorial left the safe integer range");
    }
  }
  return result;
}

function factorialFrames(n) {
  const entered = [];
  let maxDepth = 0;
  function go(k, depth) {
    entered.push(k);
    if (depth > maxDepth) {
      maxDepth = depth;
    }
    if (k === 0) {
      return 1;
    }
    return k * go(k - 1, depth + 1);
  }
  const value = go(n, 1);
  return { value, maxDepth, entered };
}

function factorialTail(n, acc) {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("factorial is defined here for nonnegative integers");
  }
  if (n === 0) {
    if (!Number.isSafeInteger(acc)) {
      throw new Error("factorial left the safe integer range");
    }
    return acc;
  }
  return factorialTail(n - 1, n * acc);
}

function sumFrom(a, i) {
  if (!Number.isInteger(i) || i < 0 || i > a.length) {
    throw new Error("sumFrom index is outside 0..a.length");
  }
  if (i === a.length) {
    return 0;
  }
  return a[i] + sumFrom(a, i + 1);
}

function sumIterative(a) {
  let acc = 0;
  for (let i = 0; i < a.length; i += 1) {
    acc += a[i];
  }
  return acc;
}

function binarySearch(a, key) {
  let lo = 0;
  let hi = a.length - 1;
  while (lo <= hi) {
    const mid = lo + Math.floor((hi - lo) / 2);
    if (a[mid] === key) {
      return mid;
    }
    if (a[mid] < key) {
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return -1;
}

function binarySearchRecursive(a, key) {
  return searchRange(a, key, 0, a.length - 1);
}

function searchRange(a, key, lo, hi) {
  if (lo > hi) {
    return -1;
  }
  const mid = lo + Math.floor((hi - lo) / 2);
  if (a[mid] === key) {
    return mid;
  }
  if (a[mid] < key) {
    return searchRange(a, key, mid + 1, hi);
  }
  return searchRange(a, key, lo, mid - 1);
}

function binarySearchFirst(a, key) {
  let lo = 0;
  let hi = a.length - 1;
  let answer = -1;
  while (lo <= hi) {
    const mid = lo + Math.floor((hi - lo) / 2);
    if (a[mid] < key) {
      lo = mid + 1;
    } else if (a[mid] > key) {
      hi = mid - 1;
    } else {
      answer = mid;
      hi = mid - 1;
    }
  }
  return answer;
}

function power(x, n) {
  if (!Number.isFinite(x)) {
    throw new Error("power base must be a finite number");
  }
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("power exponent must be a nonnegative integer");
  }
  return powerFrom(x, n);
}

function powerFrom(x, n) {
  if (n === 0) {
    return { value: 1, multiplications: 0 };
  }
  if (n === 1) {
    return { value: x, multiplications: 0 };
  }
  if (n % 2 === 0) {
    const half = powerFrom(x, n / 2);
    const value = half.value * half.value;
    return finish(x, value, half.multiplications + 1);
  }
  const half = powerFrom(x, (n - 1) / 2);
  const value = half.value * half.value * x;
  return finish(x, value, half.multiplications + 2);
}

function finish(x, value, multiplications) {
  if (Number.isInteger(x) && !Number.isSafeInteger(value)) {
    throw new Error("power left the safe integer range");
  }
  return { value, multiplications };
}

function hanoiMoves(n, from, to, aux) {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("hanoi disk count must be a nonnegative integer");
  }
  const moves = [];
  function go(k, source, target, spare) {
    if (k === 0) {
      return;
    }
    go(k - 1, source, spare, target);
    moves.push([source, target]);
    go(k - 1, spare, target, source);
  }
  go(n, from, to, aux);
  return moves;
}

function hanoiCount(n) {
  if (!Number.isInteger(n) || n < 0) {
    throw new Error("hanoi disk count must be a nonnegative integer");
  }
  if (n === 0) {
    return 0;
  }
  return 2 * hanoiCount(n - 1) + 1;
}

function subsets(elements) {
  const result = [];
  const current = [];
  function choose(i) {
    if (i === elements.length) {
      result.push(current.slice());
      return;
    }
    choose(i + 1);
    current.push(elements[i]);
    choose(i + 1);
    current.pop();
  }
  choose(0);
  return result;
}

function chooseCalls(n) {
  function choose(i) {
    if (i === n) {
      return 1;
    }
    return 1 + choose(i + 1) + choose(i + 1);
  }
  return choose(0);
}

const frames4 = factorialFrames(4);
assert.deepEqual(frames4, {
  value: 24,
  maxDepth: 5,
  entered: [4, 3, 2, 1, 0],
});
assert.equal(factorial(4), 24);
assert.equal(factorialIterative(4), 24);
assert.equal(factorialTail(4, 1), 24);
assert.equal(factorial(0), 1);
assert.equal(factorialIterative(0), 1);

const frames10 = factorialFrames(10);
assert.equal(frames10.value, 3628800);
assert.equal(frames10.maxDepth, 11);
assert.equal(frames10.entered[0], 10);
assert.equal(frames10.entered[10], 0);
assert.equal(factorial(10), 3628800);
assert.equal(factorialIterative(10), 3628800);
assert.equal(factorialIterative(18), 6402373705728000);
assert.equal(factorial(18), 6402373705728000);
assert.throws(() => factorial(19), /safe integer range/);
assert.throws(() => factorial(-1), /nonnegative integers/);

const sample = [3, 1, 4];
assert.equal(sumFrom(sample, 0), 8);
assert.equal(sumFrom(sample, 1), 5);
assert.equal(sumFrom(sample, 2), 4);
assert.equal(sumFrom(sample, 3), 0);
assert.equal(sumIterative(sample), 8);
assert.equal(sumIterative([]), 0);
assert.equal(sumFrom([], 0), 0);

const sorted = [1, 3, 4, 7, 7, 9, 12];
const anyCases = [
  [4, 2],
  [9, 5],
  [1, 0],
  [12, 6],
  [5, -1],
  [0, -1],
  [13, -1],
  [7, 3],
];
for (const [key, index] of anyCases) {
  assert.equal(binarySearch(sorted, key), index);
  assert.equal(binarySearchRecursive(sorted, key), index);
}
assert.equal(binarySearch([], 1), -1);
assert.equal(binarySearchRecursive([], 1), -1);
assert.equal(binarySearch([4], 4), 0);
assert.equal(binarySearch([4], 5), -1);
assert.equal(binarySearchFirst(sorted, 7), 3);
assert.equal(binarySearchFirst(sorted, 5), -1);

const duplicates = [2, 5, 5, 5, 8];
assert.equal(binarySearch(duplicates, 5), 2);
assert.equal(binarySearchRecursive(duplicates, 5), 2);
assert.equal(binarySearchFirst(duplicates, 5), 1);
assert.equal(binarySearch(duplicates, 8), 4);
assert.equal(binarySearchFirst(duplicates, 8), 4);
assert.equal(binarySearch(duplicates, 2), 0);
assert.equal(binarySearchFirst(duplicates, 2), 0);
assert.equal(binarySearch(duplicates, 6), -1);
assert.equal(binarySearchFirst(duplicates, 6), -1);
assert.equal(binarySearchFirst(duplicates, 1), -1);
assert.equal(binarySearchFirst(duplicates, 9), -1);

assert.deepEqual(power(2, 0), { value: 1, multiplications: 0 });
assert.deepEqual(power(2, 1), { value: 2, multiplications: 0 });
assert.deepEqual(power(2, 2), { value: 4, multiplications: 1 });
assert.deepEqual(power(2, 3), { value: 8, multiplications: 2 });
assert.deepEqual(power(2, 8), { value: 256, multiplications: 3 });
assert.deepEqual(power(2, 13), { value: 8192, multiplications: 5 });
assert.throws(() => power(2, -1), /nonnegative integer/);

assert.deepEqual(hanoiMoves(2, "A", "C", "B"), [
  ["A", "B"],
  ["A", "C"],
  ["B", "C"],
]);
assert.deepEqual(hanoiMoves(3, "A", "C", "B"), [
  ["A", "C"],
  ["A", "B"],
  ["C", "B"],
  ["A", "C"],
  ["B", "A"],
  ["B", "C"],
  ["A", "C"],
]);
assert.equal(hanoiMoves(3, "A", "C", "B").length, 7);
assert.equal(hanoiCount(0), 0);
assert.equal(hanoiCount(1), 1);
assert.equal(hanoiCount(2), 3);
assert.equal(hanoiCount(3), 7);
assert.equal(hanoiCount(4), 15);
assert.equal(hanoiCount(10), 1023);

assert.deepEqual(subsets([]), [[]]);
assert.deepEqual(subsets([1]), [[], [1]]);
assert.deepEqual(subsets([1, 2]), [[], [2], [1], [1, 2]]);
assert.deepEqual(subsets([1, 2, 3]), [
  [],
  [3],
  [2],
  [2, 3],
  [1],
  [1, 3],
  [1, 2],
  [1, 2, 3],
]);
assert.equal(subsets([1, 2, 3]).length, 8);
assert.equal(chooseCalls(0), 1);
assert.equal(chooseCalls(2), 7);
assert.equal(chooseCalls(3), 15);

console.log("ALL TESTS PASSED");
```

---

## 14. Common mistakes

**Mistake 1.** Recursion is a different mathematical operation from a loop.

**Wrong idea.** A recursive factorial and an iterative factorial compute different kinds of products, and only the recursive one needs a proof.

**Correction.** Both compute $n!$. The invariant of the loop and the inductive step of the recursion are the same identity, $k! = k \cdot (k-1)!$. What changes is where the pending factor is stored: in a frame, or in the variable `result`.

**Mistake 2.** A base case is optional when the input is large.

**Wrong idea.** Factorial of a positive integer never needs $0!$, so the base can be omitted, or can sit at $n = 1$ with no thought about $n = 0$.

**Correction.** The call at $n = 1$ invokes the function at $n = 0$. The base has to answer every call the recursive case can make. The empty sum returning $1$ instead of $0$ is the same mistake with a function that still terminates: `sumFromWrongBase([3, 1, 4], 0)` returns $9$, not $8$.

**Mistake 3.** Tail recursion means the stack stays constant.

**Wrong idea.** Once the multiplication has been moved into an accumulator, Node.js reuses one frame, so `factorialTail` is safe at arbitrary depth.

**Correction.** The call is in tail position. JavaScript engines are not required to eliminate it. Node.js, running V8, does not eliminate it. The maximum depth remains $n+1$. Constant extra space belongs to the loop in Section 3.3. No proof in this lecture assumes elimination.

**Mistake 4.** Strong induction can prove statements that weak induction cannot.

**Wrong idea.** The binary-search recurrence needs strong induction, therefore it lies outside ordinary induction, and the hypothesis is allowed to assume the claim for larger inputs as well as smaller ones.

**Correction.** Theorem 1 shows that the two forms prove the same family of statements about the integers. Strong induction is the packaging that mentions every smaller size the recursion actually calls. The hypothesis still looks only backward, at arguments smaller than the one in the step. Assuming the claim for a larger input would be circular.

**Mistake 5.** $\mathrm{lo} < \mathrm{hi}$ and $(\mathrm{lo}+\mathrm{hi})/2$ are harmless spelling variants.

**Wrong idea.** Any loop that keeps two indices and picks a midpoint is binary search.

**Correction.** For the any-occurrence algorithm, $\mathrm{lo} = \mathrm{hi}$ is a live cell and must be inspected, so the test is $\mathrm{lo} \le \mathrm{hi}$. The midpoint in the code is $\mathrm{lo} + \lfloor (\mathrm{hi}-\mathrm{lo})/2 \rfloor$. The sum form is a different expression: at $\mathrm{lo} = 9007199254740988$ and $\mathrm{hi} = 9007199254740991$ it yields $9007199254740990$ instead of the mathematical midpoint $9007199254740989$. A first-occurrence loop may use $\mathrm{lo} < \mathrm{hi}$ only with matching updates and a final read. Mixing the test from one algorithm with the updates of the other drops either the last cell or the progress argument.

**Mistake 6.** The index returned for a duplicate key is the first occurrence.

**Wrong idea.** Binary search finds "the" position of the key, so on $[2, 5, 5, 5, 8]$ the result $2$ for key $5$ is the start of the run of fives.

**Correction.** Equality returns whichever match the midpoint hits. On that array the any-occurrence result is $2$ and the first occurrence is $1$. Theorem 5 and Theorem 6 are different statements. A caller who needs the start of the run must use the first-occurrence invariant, which keeps searching left after a hit.

**Mistake 7.** The Hanoi procedure is exponential in stack depth.

**Wrong idea.** Because the running time is $\Theta(2^n)$, the call stack also holds $\Theta(2^n)$ frames.

**Correction.** The first chain of calls goes from $n$ down to $0$ before any move is recorded. The maximum depth is $n+1$, which is $\Theta(n)$. The exponential quantity is the number of moves, $2^n - 1$, and the time to write them down. `hanoiCount` is a further distinction: computing the number from the one-call recurrence is $\Theta(n)$ time, and computing it from the closed form is $\Theta(1)$ arithmetic inside the safe range.

**Mistake 8.** The combine step may use any true fact about the original input.

**Wrong idea.** If the original array happens to be sorted, a recursive minimum may return the left half's minimum and ignore the right half.

**Correction.** A subcall establishes only its postcondition. `minimumWrong` asks each half for a minimum and then treats the left answer as the global minimum, which would require every left value to be at most every right value. The halves did not return that fact. On $[4, 1]$ the function returns $4$. The legal combine is the minimum of the two returned minima.

---

## 15. Examination

Ninety minutes, closed lecture. Write full solutions. Numeric answers should show the arithmetic. The answer key is Section 16; do not read it first.

**E1. Definitions and short answers.**

1. Define a measure of a recursive function. State the measure of `sumFrom` and the measure of `searchRange`.
2. Define tail position. Say why `factorial` is not tail recursive, and why `factorialTail` is. State the maximum depth of `factorialTail(n, 1)` in Node.js, and say why the answer is not $O(1)$ stack words.
3. State the three labeled parts of a weak induction and of a strong induction. Which form matches `powerFrom`, and which form matches the proof that $T(n) = 2^n - 1$ for Hanoi?
4. Name the three steps of divide-and-conquer. Which step is empty in binary search? Write the mergesort recurrence that Lecture 06 owns, and stop. Do not write sorting code.

**E2. Induction.**

Prove by weak induction that for every integer $n \ge 1$,

$$
\sum_{k=1}^{n} (2k - 1) = n^2.
$$

That is, the first $n$ odd positives sum to $n^2$. Show the base and the arithmetic of the step.

**E3. Binary search.**

The array

$$
a = [2, 4, 6, 8, 10, 12, 14]
$$

is sorted ascending. Indices start at $0$.

1. Trace `binarySearch(a, 10)`. Give a table with columns $\mathrm{lo}$, $\mathrm{hi}$, $\mathrm{mid}$, $a[\mathrm{mid}]$, and the decision. State the index returned.
2. After the first iteration, before the second, write the invariant of Section 8.3 as a concrete statement about this array and this key: which indices are already known to be $< 10$, and which are already known to be $> 10$.
3. What does `binarySearch` return for key $7$, and for key $14$? A returned index must be justified by the same style of trace; an absent key needs the final empty interval.
4. On $c = [1, 4, 4, 4, 4, 9]$, trace `binarySearch` and `binarySearchFirst` for key $4$. Give the index each returns. One sentence: why are those indices allowed to differ?

**E4. Recurrence.**

Define $S(1) = 0$ and, for every integer $n \ge 2$,

$$
S(n) = S(\lfloor n/2 \rfloor) + S(\lceil n/2 \rceil) + 1.
$$

1. Compute $S(2), S(3), S(4), S(5), S(6)$ from the recurrence.
2. Prove by strong induction that $S(n) = n - 1$ for every integer $n \ge 1$. You may use Lemma 1.

**E5. Does the measure decrease?**

```javascript
function locate(a, key, lo, hi) {
  if (lo > hi) {
    return -1;
  }
  const mid = lo + Math.floor((hi - lo) / 2);
  if (a[mid] === key) {
    return mid;
  }
  if (a[mid] < key) {
    return locate(a, key, mid, hi);
  }
  return locate(a, key, lo, mid - 1);
}
```

1. Name the measure the correct `searchRange` uses.
2. Start `locate([1, 3, 5], 5, 0, 2)`. List $(\mathrm{lo}, \mathrm{hi}, \mathrm{mid})$ for the first three calls, and the length $\mathrm{hi}-\mathrm{lo}+1$ of each. Does the call terminate?
3. Replace the single wrong argument. After the repair, what index does the search return on this input?
4. Separately, `sumFromWrongBase([3, 1, 4], 0)` returns $9$. Does its measure decrease? Which of the three failure classes in Section 12 is this, and what is the repaired base value?

**E6. Subsets.**

An input has $6$ distinct elements. `subsets` and `choose` are the procedures of Section 11.

1. How many subsets are returned?
2. How many calls to `choose` are made?
3. How many of the subsets contain one fixed element?
4. Using the recurrence for $B(n, k)$ and the table through $n = 4$ in Section 11, compute $B(6, 3)$. Show each value you compute along the way, including the $n = 5$ row entries you need.

---

## 16. Answer key

**E1.**

1. A measure is a function from the legal arguments to the nonnegative integers that is strictly smaller on every recursive call than on the caller. For `sumFrom(a, i)` the measure is `a.length - i`. For `searchRange(a, key, lo, hi)` the measure is the interval length $\mathrm{hi}-\mathrm{lo}+1$ when $\mathrm{lo} \le \mathrm{hi}$, and $0$ when $\mathrm{lo} > \mathrm{hi}$.

2. A call is in tail position when, after it returns, the caller only returns that value. `factorial(n)` multiplies the returned value by $n$ and then tests the safe-integer range, so the call is not in tail position. `factorialTail(n, acc)` returns the recursive call's value unchanged, so that call is in tail position. In Node.js the maximum depth is $n+1$ frames, because V8 does not eliminate tail calls. That is $\Theta(n)$ stack words, not $\Theta(1)$. The iterative factorial is the $\Theta(1)$ extra-space program.

3. Weak induction: prove $P(n_0)$; assume $P(n)$ for an arbitrary $n \ge n_0$; prove $P(n+1)$. Strong induction: prove $P(n_0)$, and any extra bases the step needs; assume $P(k)$ for all $k$ with $n_0 \le k \le n$; prove $P(n+1)$. `powerFrom` calls $n/2$ or $(n-1)/2$, so the matching proof is strong induction (Theorem 7). The Hanoi closed form calls the recurrence at $n$ only, which uses $T(n-1)$, so the matching proof is weak induction (Theorem 9).

4. Divide, solve, combine. Binary search's combine is empty: the answer of the single smaller interval is the answer of the original interval. The mergesort recurrence Lecture 06 owns is $T(n) = T(\lfloor n/2 \rfloor) + T(\lceil n/2 \rceil) + \Theta(n)$, or $T(n) = 2T(n/2) + \Theta(n)$ when $n$ is a power of two.

**E2.**

Let $P(n)$ be $\sum_{k=1}^{n} (2k-1) = n^2$, for $n \ge 1$.

Base $n = 1$. The left side is the single term $2\cdot 1 - 1 = 1$. The right side is $1^2 = 1$.

Inductive hypothesis: assume $P(n)$ for some $n \ge 1$.

Step. The sum of the first $n+1$ odd positives adds the next odd number, which is $2(n+1)-1 = 2n+1$.

$$
\sum_{k=1}^{n+1} (2k-1)
  = n^2 + (2n+1)
  = n^2 + 2n + 1
  = (n+1)^2.
$$

The first equality uses the inductive hypothesis. This is $P(n+1)$.

By weak induction, $P(n)$ holds for every integer $n \ge 1$.

Check: the first three odds are $1+3+5 = 9 = 3^2$.

**E3.**

1. Trace of key $10$.

| $\mathrm{lo}$ | $\mathrm{hi}$ | $\mathrm{mid}$ | $a[\mathrm{mid}]$ | Decision |
| --- | --- | --- | --- | --- |
| $0$ | $6$ | $3$ | $8$ | $8 < 10$, so $\mathrm{lo} \leftarrow 4$ |
| $4$ | $6$ | $5$ | $12$ | $12 > 10$, so $\mathrm{hi} \leftarrow 4$ |
| $4$ | $4$ | $4$ | $10$ | equal, return $4$ |

The returned index is $4$.

2. After the first iteration, $\mathrm{lo} = 4$ and $\mathrm{hi} = 6$. Every index $j < 4$ has $a[j] < 10$. Those cells are $2, 4, 6, 8$. No index is greater than $6$, so the right discarded side is empty. If $10$ occurs, it occurs in indices $4..\,6$.

3. Key $7$:

| $\mathrm{lo}$ | $\mathrm{hi}$ | $\mathrm{mid}$ | $a[\mathrm{mid}]$ | Decision |
| --- | --- | --- | --- | --- |
| $0$ | $6$ | $3$ | $8$ | $8 > 7$, so $\mathrm{hi} \leftarrow 2$ |
| $0$ | $2$ | $1$ | $4$ | $4 < 7$, so $\mathrm{lo} \leftarrow 2$ |
| $2$ | $2$ | $2$ | $6$ | $6 < 7$, so $\mathrm{lo} \leftarrow 3$ |

Now $\mathrm{lo} = 3 > 2 = \mathrm{hi}$. The function returns $-1$.

Key $14$:

| $\mathrm{lo}$ | $\mathrm{hi}$ | $\mathrm{mid}$ | $a[\mathrm{mid}]$ | Decision |
| --- | --- | --- | --- | --- |
| $0$ | $6$ | $3$ | $8$ | $8 < 14$, so $\mathrm{lo} \leftarrow 4$ |
| $4$ | $6$ | $5$ | $12$ | $12 < 14$, so $\mathrm{lo} \leftarrow 6$ |
| $6$ | $6$ | $6$ | $14$ | equal, return $6$ |

4. Any-occurrence on $c = [1, 4, 4, 4, 4, 9]$, key $4$:

$\mathrm{lo} = 0$, $\mathrm{hi} = 5$, $\mathrm{mid} = 2$, $c[2] = 4$. Return $2$.

First-occurrence:

| $\mathrm{lo}$ | $\mathrm{hi}$ | $\mathrm{answer}$ | $\mathrm{mid}$ | $c[\mathrm{mid}]$ | Update |
| --- | --- | --- | --- | --- | --- |
| $0$ | $5$ | $-1$ | $2$ | $4$ | $\mathrm{answer} \leftarrow 2$, $\mathrm{hi} \leftarrow 1$ |
| $0$ | $1$ | $2$ | $0$ | $1$ | $\mathrm{lo} \leftarrow 1$ |
| $1$ | $1$ | $2$ | $1$ | $4$ | $\mathrm{answer} \leftarrow 1$, $\mathrm{hi} \leftarrow 0$ |

Then $\mathrm{lo} = 1 > 0 = \mathrm{hi}$, so the function returns $1$.

The indices differ because any-occurrence returns the match the midpoint hits, here index $2$, while first-occurrence continues left and finds the earlier match at index $1$. Both answers are correct for their own specifications. Theorem 5 allows any match; Theorem 6 requires the smallest.

**E4.**

1. From the recurrence:

$$
\begin{align*}
S(2) &= S(1) + S(1) + 1 = 0 + 0 + 1 = 1 \\
S(3) &= S(1) + S(2) + 1 = 0 + 1 + 1 = 2 \\
S(4) &= S(2) + S(2) + 1 = 1 + 1 + 1 = 3 \\
S(5) &= S(2) + S(3) + 1 = 1 + 2 + 1 = 4 \\
S(6) &= S(3) + S(3) + 1 = 2 + 2 + 1 = 5
\end{align*}
$$

These agree with $n-1$.

2. Strong induction on $n$.

Base $n = 1$: $S(1) = 0 = 1-1$.

Inductive hypothesis: fix $n \ge 2$ and assume $S(k) = k-1$ for every $k$ with $1 \le k < n$. Both $\lfloor n/2 \rfloor$ and $\lceil n/2 \rceil$ are at least $1$ and at most $n-1$ for $n \ge 2$, so the hypothesis applies to both.

$$
S(n)
  = \big(\lfloor n/2 \rfloor - 1\big) + \big(\lceil n/2 \rceil - 1\big) + 1
  = \lfloor n/2 \rfloor + \lceil n/2 \rceil - 1.
$$

Lemma 1 says the two halves sum to $n$, so $S(n) = n - 1$.

By strong induction, $S(n) = n-1$ for every integer $n \ge 1$.

**E5.**

1. The measure is the closed-interval length $\mathrm{hi}-\mathrm{lo}+1$, or $0$ when the interval is empty.

2. First call: $\mathrm{lo} = 0$, $\mathrm{hi} = 2$, $\mathrm{mid} = 1$, length $3$. The cell $a[1] = 3 < 5$, so the next call uses $(\mathrm{mid}, \mathrm{hi}) = (1, 2)$.

Second call: $\mathrm{lo} = 1$, $\mathrm{hi} = 2$, $\mathrm{mid} = 1$, length $2$. Again $a[1] = 3 < 5$, so the next call uses $(1, 2)$.

Third call: $\mathrm{lo} = 1$, $\mathrm{hi} = 2$, $\mathrm{mid} = 1$, length $2$.

The length went $3, 2, 2$ and then stays $2$. The call does not terminate.

3. The wrong argument is the lower bound of the right branch. Pass `mid + 1` rather than `mid`. The repaired call on this input is `searchRange`. Trace: $\mathrm{mid} = 1$, $a[1] = 3 < 5$, so the next interval is $\mathrm{lo} = 2$, $\mathrm{hi} = 2$. Then $\mathrm{mid} = 2$, $a[2] = 5$, and the function returns $2$.

4. The measure $3-i$ of `sumFromWrongBase` decreases at every call: indices $0, 1, 2, 3$. The function terminates. The failure is the base value, Section 12.1. The empty suffix must return $0$, not $1$. With that repair the sum is $3+1+4 = 8$.

**E6.**

1. Theorem 11: $2^6 = 64$ subsets.

2. Theorem 12: $C(6) = 2^{7} - 1 = 128 - 1 = 127$ calls.

3. The corollary of Theorem 11: $2^{5} = 32$ subsets contain a fixed element.

4. From the table, $B(4, 1) = 4$, $B(4, 2) = 6$, $B(4, 3) = 4$, and $B(n, 0) = 1$.

$$
\begin{align*}
B(5, 1) &= B(4, 1) + B(4, 0) = 4 + 1 = 5 \\
B(5, 2) &= B(4, 2) + B(4, 1) = 6 + 4 = 10 \\
B(5, 3) &= B(4, 3) + B(4, 2) = 4 + 6 = 10 \\
B(6, 3) &= B(5, 3) + B(5, 2) = 10 + 10 = 20
\end{align*}
$$

So $B(6, 3) = 20$. As a check, $1+6+15+20+15+6+1 = 64 = 2^6$ once the rest of the row is computed the same way; the problem asked only for $B(6, 3)$, and $20$ is that entry.

---

## 17. Independent assignment

Produce two artifacts and keep them. Later lectures assume you can still write a binary search and an induction without this file open. Budget about three to five hours.

**Artifact 1. A program, `search-power-hanoi.mjs`.** It uses only JavaScript and `node:assert/strict`. It must print `ALL TESTS PASSED`.

1. *Last occurrence.* Implement `binarySearchLast(a, key)`, returning the greatest index $i$ with $a[i] = \mathrm{key}$, or $-1$. Model it on `binarySearchFirst`: the closed interval, the test $\mathrm{lo} \le \mathrm{hi}$, and a recorded answer. When the midpoint compares equal, record it and move $\mathrm{lo}$ to $\mathrm{mid}+1$, so the remaining search looks to the right. In a comment block above the function, write the invariant and a maintenance proof at the same level of detail as Theorem 6. The three cases are $a[\mathrm{mid}] < \mathrm{key}$, $a[\mathrm{mid}] > \mathrm{key}$, and equality. Include a one-line note on why the any-occurrence index and the last-occurrence index differ on $[2, 5, 5, 5, 8]$ for key $5$: any-occurrence returns $2$, and last-occurrence must return $3$.
2. *Tests for the search.* Assert last-occurrence on $[2, 5, 5, 5, 8]$ for keys $5, 2, 8, 6$. Assert it on the empty array and on a one-element array. Assert that a strictly increasing array gives the same index for any-occurrence, first-occurrence, and last-occurrence.
3. *Multiplication counts, without relying on floating `Math.log2`.* Implement $M(n)$ by the recurrence in Section 9.4, and implement $\lfloor \log n \rfloor$ and $\nu(n)$ by loops on the integer $n$. For every $n$ from $1$ through $1024$, assert $M(n) = \lfloor \log n \rfloor + \nu(n) - 1$. This checks the count, not a large power. Do not compute $3^{1024}$ in a JavaScript number.
4. *Hanoi rules.* Generate `hanoiMoves` for every $n$ from $0$ through $6$. Assert that the length equals $2^n - 1$. Simulate three pegs, each a stack of disk numbers with disk $1$ smallest. Start from the legal tower on $A$. After every move, assert that the moved disk was the top of its source and that it is not placed on a smaller disk. Assert that the final configuration is the legal tower on $C$ and that the other two pegs are empty. Assert that disk $n$, when $n \ge 1$, moves exactly once.

**Artifact 2. A short written note, kept with the program.** One page is enough.

1. The invariant proof of `binarySearchLast`, if you did not put the full text in the comment block. One of the two places must contain the full proof.
2. Three broken functions you write yourself, one for each class in Section 12, each in ten lines or fewer, each with a concrete input, the observed failure, and the repaired line. Do not reuse the three broken functions already printed in Section 12; write new ones in the same classes. At least one must be a binary search or a power function.
3. A paragraph on stack space: depth of `factorial`, of `factorialTail` in Node.js, of recursive binary search, of `hanoiMoves`, and of `subsets`, each as a $\Theta$ expression in $n$. State which of these would change if an engine eliminated tail calls, and state that this course does not use that change.

You are finished when both artifacts exist, the program prints `ALL TESTS PASSED`, and you can reproduce the last-occurrence invariant without looking at the comment block.

---

## 18. Glossary

**Accumulator.** A parameter that carries work already completed, used so that a recursive call can sit in tail position. In `factorialTail(n, acc)` the intended value is $n! \cdot acc$.

**Activation record.** A stack frame: parameters, local variables, and the return address of one live call.

**Any-occurrence search.** Binary search that returns some index where the key sits, or $-1$. Specified by Theorem 5.

**Ascending.** Non-decreasing order: $a[0] \le a[1] \le \cdots \le a[n-1]$. Duplicates are allowed.

**Backtracking.** Recursion that tries a choice, calls itself, and undoes the choice. In this lecture, the choices are include and exclude.

**Base case.** A clause of a recursive definition that gives the value with no recursive call.

**Binary recursion.** A recursive function that makes two recursive calls in a single invocation. Hanoi and subset generation are binary recursions. Binary recursion is not the same thing as tail recursion.

**Call stack.** The stack of activation records maintained by the language implementation. Lecture 04 owns the stack abstract data type; this lecture uses the call stack.

**Closed interval.** The indices $j$ with $\mathrm{lo} \le j \le \mathrm{hi}$. Empty when $\mathrm{lo} > \mathrm{hi}$.

**Combine.** The divide-and-conquer step that builds the original answer from the answers of the subproblems. Empty for binary search.

**Depth.** The number of frames of a recursion that are live at one moment. Maximum depth of `factorial(n)` is $n+1$.

**Divide.** The step that splits an instance into smaller instances of the same problem.

**Divide-and-conquer.** The pattern divide, solve, combine, with cost shaped by $T(n) = a\,T(n/b) + f(n)$ when the subproblems are equal.

**Empty product.** The product of no factors, defined to be $1$. This is why $0! = 1$ and why $x^0 = 1$ in `power`.

**Empty sum.** The sum of no terms, defined to be $0$.

**First occurrence.** The smallest index at which the key sits. Specified by Theorem 6.

**Inductive hypothesis.** The assumption $P(n)$ in a weak proof, or the assumption that $P(k)$ holds for all $k$ from the base through $n$ in a strong proof.

**Inductive step.** The argument from the inductive hypothesis to $P(n+1)$.

**Invariant.** A statement that is true at a chosen recurring moment, such as the start of every loop test or the entry of every recursive call, and that is strong enough to imply the specification when the procedure ends.

**Linear recursion.** A recursive function that makes at most one recursive call per invocation.

**Measure.** A function from legal arguments to the nonnegative integers that strictly decreases on every recursive call. It is what makes the recursion terminate.

**Midpoint.** The index $\mathrm{lo} + \lfloor (\mathrm{hi}-\mathrm{lo})/2 \rfloor$ inside a nonempty closed interval.

**Population count $\nu(n)$.** The number of $1$-bits in the binary expansion of a positive integer $n$.

**Postcondition.** The fact a call guarantees about its returned value. A combine step may use a postcondition of a subcall, and may not use a property the subcall was not obliged to establish.

**Power set.** The set of all subsets of a finite set. It has $2^n$ elements when the set has $n$ elements.

**Recurrence.** An equation that defines a sequence by earlier terms, such as $T(n) = 2T(n-1)+1$ or $W(n) = 1 + W(\lfloor n/2 \rfloor)$.

**Recursive case.** A clause that defines $f(x)$ by using $f$ at arguments the measure declares smaller.

**Recursive definition.** A definition by base cases and recursive cases, together with a measure.

**Safe integer.** An integer $z$ with $|z| \le 2^{53}-1$. JavaScript represents each of them exactly. $18!$ is a safe integer; $19!$ is not, even though $19!$ happens to be an exact JavaScript number.

**Solve.** The divide-and-conquer step that runs the same algorithm on each smaller instance, hitting a base case when the instance is small enough.

**Strong induction.** A proof that assumes $P(k)$ for all $k$ with $n_0 \le k \le n$ in order to prove $P(n+1)$. It matches recursions whose calls are on subproblems of many smaller sizes.

**Tail-call elimination.** An implementation technique that reuses the caller's frame for a call in tail position. Not part of the cost model of this course, and not performed by Node.js.

**Tail position.** The position of a call whose returned value is immediately returned by the caller, with no further work.

**Tail recursion.** A recursion in which every recursive call is in tail position.

**Well-founded.** An order in which every strictly decreasing sequence is finite. The nonnegative integers with the usual order are well-founded, which is why a decreasing measure reaches a base case.

**Weak induction.** A proof that assumes only $P(n)$ in order to prove $P(n+1)$. It matches a recursion whose calls are only on the immediate predecessor.

---

## 19. Lecture summary

A recursive algorithm is a base case, a recursive case, and a measure on the nonnegative integers that decreases at every call. Factorial and the array sum are the same functions written either as that descent or as a loop with an invariant; the loop stores the pending operation in a variable, and the recursion stores it in a stack frame. For `factorial(n)` the maximum depth is $n+1$ and the extra space is $\Theta(n)$, against $\Theta(1)$ extra space for the loop. Moving the pending multiplication into an accumulator puts the call in tail position and does not remove the frames in Node.js.

Weak induction matches calls on $n-1$. Strong induction matches calls on $\lfloor n/2 \rfloor$ and on other smaller sizes, and Theorem 1 records that the two forms prove the same statements. The proofs written in full are the sum $n(n+1)/2$, the suffix sum, both binary searches, the exact iteration count $\lfloor \log n \rfloor + 1$, power by squaring and its multiplication count, the Hanoi closed form, and the matching lower bound. Subset generation is the include-or-exclude tree: $2^n$ leaves, $2^{n+1}-1$ calls, depth $n+1$.

Binary search is divide-and-conquer with one subproblem and an empty combine, under the precondition that the array is sorted ascending, with the live candidates kept as a closed interval. The Tower of Hanoi is the recurrence $T(n) = 2T(n-1)+1$, whose solution $2^n-1$ is both the length of the procedure and the length of every shortest solution. The mergesort recurrence is stated and left to Lecture 06.

**Five principles.**

1. Name the measure before you trust the recursion. A base case that the calls never hit, or a call that does not decrease the measure, is not yet a definition.
2. Recursion and iteration are two layouts of one argument. Pending work sits either in frames or in variables, and the layout is what determines stack space.
3. Choose weak or strong induction by reading the calls. Use strong induction when a call lands on a size other than $n-1$; the two principles are equal in strength and different in shape.
4. Discard, return, or combine only what the invariant or the subcall's postcondition has established. Sortedness that the subcalls did not return is not an input to the combine step.
5. A tail call in this course allocates a frame. Write a loop when the stack must be constant. Do not plan on an engine to erase the recursion.

---

## 20. References

1. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022. Chapter 2 (loop invariants as a correctness pattern) and Chapter 4 (divide-and-conquer recurrences and substitution). The Master Theorem used as a pointer for the power-of-two mergesort shape is the one Lecture 01 takes from this chapter.
2. Michael T. Goodrich, Roberto Tamassia, and Michael H. Goldwasser. *Data Structures and Algorithms in Java*. 6th edition. Wiley, 2014. Chapter 5, Recursion: linear recursion, binary recursion, and the Tower of Hanoi. The code in this lecture is JavaScript; the recurrence structure is the same.
3. Robert Sedgewick and Kevin Wayne. *Algorithms*. 4th edition. Addison-Wesley, 2011. Section 1.1, the binary-search case study. Course site: [https://algs4.cs.princeton.edu/home/](https://algs4.cs.princeton.edu/home/).
4. Mark Allen Weiss. *Data Structures and Algorithm Analysis in C++*. 4th edition. Pearson, 2014. Chapter 1, the mathematics review, for induction as it is used before data structures begin.
5. Ronald L. Graham, Donald E. Knuth, and Oren Patashnik. *Concrete Mathematics*. 2nd edition. Addison-Wesley, 1994. Chapter 1, Recurrent Problems, for the Tower of Hanoi recurrence and the discipline of proving a guessed closed form by induction.
6. Jon Bentley. *Programming Pearls*. 2nd edition. Addison-Wesley, 2000. Column 4, Writing Correct Programs, for the insistence that a binary search carry an invariant strong enough to make the off-by-one cases fail in the proof rather than in a later test.
7. Donald E. Knuth. *The Art of Computer Programming, Volume 1: Fundamental Algorithms*. 3rd edition. Addison-Wesley, 1997. Section 1.2.1, Mathematical Induction.
8. ECMA-262, the ECMAScript Language Specification, the clauses that describe tail calls. The specification text is not a promise that Node.js eliminates them. V8, the engine used by Node.js, does not eliminate tail calls; the cost claims in this lecture are written for that behavior.
