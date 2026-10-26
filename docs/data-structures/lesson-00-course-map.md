# DATA STRUCTURES AND ALGORITHM ANALYSIS

## COURSE MAP — HOW THIS COURSE IS STUDIED

**Course:** Data Structures and Algorithm Analysis  
**Section:** JOB Core · Data Structures  
**Academic level:** Undergraduate computer science, studied independently at the depth of a CS2 semester plus the data-structure core of an algorithms course  
**Recommended duration:** 14 study weeks, about 6–10 hours each  
**Implementation language:** JavaScript (ES2022), no libraries  
**Prerequisites:** You can write functions, loops, conditionals, and classes in JavaScript. You can manipulate algebraic expressions. You do not need prior data-structure coursework.

---

# 1. WHAT THIS COURSE IS

A data structure is a way of organizing information so that a stated set of operations can be performed within a stated cost.

An algorithm is a finite procedure that solves a stated problem. Its cost is measured against a model of computation, not against the speed of one laptop.

This course teaches both, together. Every structure is specified as an abstract data type, implemented in JavaScript, and bounded with asymptotic analysis. Every algorithm that depends on a structure is proved correct at the level a careful undergraduate course demands, or the missing step is named.

The course is self-study. Each lecture is the chapter, the laboratory, and the examination. The answer key is at the end of the lecture so you can attempt the examination before you read it.

---

# 2. WHERE THE CURRICULUM COMES FROM

The lecture list is the common core of current undergraduate data-structure courses, not a personal selection of interview puzzles.

| Source | What it contributes |
| --- | --- |
| Purdue CS 251, Data Structures | ADTs, hashing, collision resolution, Dijkstra, Bellman–Ford, Prim, Kruskal |
| UNSW COMP2521 (2025) | Recursion, analysis, BSTs, AVL and 2–3–4 trees, graph traversal, MST, Dijkstra, heaps, hashing, tries |
| IIIT Allahabad DSA (2024) | Analysis, sorting, lists, stacks, queues, AVL, heaps, hashing, DFS, BFS, MST, Dijkstra |
| Waterloo ECE 250 | Mathematical review, sequential and hierarchical storage, hashing, graphs, the boundary with complexity classes |
| Princeton COS 226 (Spring and Fall 2026), Sedgewick and Wayne | Union–find, resizable arrays, elementary sorts, mergesort, quicksort, priority queues, BSTs, red–black trees, hash tables, DFS/BFS, MST, shortest paths |
| Cormen, Leiserson, Rivest, Stein, *Introduction to Algorithms*, 4th edition | Growth of functions, recurrences, heaps, quicksort, linear-time sorting, hash tables, BSTs, red–black trees, B-trees, amortized analysis, disjoint sets, elementary graph algorithms, single-source shortest paths, minimum spanning trees |

Two topics appear in some of those courses and are **not** separate lectures here, because they belong to the next course, Algorithms:

- Dynamic programming as a design method.
- Maximum flow, NP-completeness, and intractability.

Lecture 14 says what those topics are and why they are outside this course. Greedy choice is taught where it is used: Huffman codes, Dijkstra, Prim, and Kruskal.

---

# 3. LEARNING OUTCOMES

By the end of the course you should be able to:

1. Specify an abstract data type separately from any implementation.
2. Place an algorithm in the RAM model and derive a $\Theta$, $O$, or $\Omega$ bound, including recurrences solved by substitution or the Master Theorem.
3. Prove an amortized bound for a dynamic table by the aggregate method, and explain the accounting and potential methods.
4. Implement and choose among dynamic arrays, singly and doubly linked lists, stacks, queues, deques, binary search trees, AVL trees, binary heaps, chained hash tables, and adjacency-list graphs.
5. Explain red–black trees, B-trees, and 2–3–4 trees precisely enough to carry out an insertion by hand.
6. Sort in the comparison model and state the $\Omega(n \log n)$ lower bound, then explain how counting sort and radix sort escape that bound.
7. Search with binary search, trees, tries, and hashing, and state the assumption behind each expected-time claim.
8. Traverse a graph, detect cycles, compute a topological order and strongly connected components, compute a minimum spanning tree, and compute single-source shortest paths under the correct weight restriction.
9. Maintain a disjoint-set forest with union by rank and path compression.
10. Given a new problem, choose a structure by naming the operation mix and the cost you are buying.

---

# 4. THE FOURTEEN LECTURES

Study them in order. A later lecture is allowed to use an earlier result without re-teaching it.

| Lecture | Title | It owns | It refuses to re-teach |
| --- | --- | --- | --- |
| 01 | Models, ADTs, and Asymptotic Analysis | RAM model, formal $O/\Omega/\Theta/o/\omega$, sums, loop analysis, substitution, Master Theorem | Array implementation, sorting code |
| 02 | Arrays, Dynamic Arrays, and Amortized Analysis | Contiguous storage, geometric growth, aggregate / accounting / potential methods | Linked lists |
| 03 | Linked Lists | Singly, doubly, and circular lists, sentinels, pointer surgery | Stacks as the main topic |
| 04 | Stacks, Queues, and Deques | The ADTs, circular buffers, shunting-yard | Graph search |
| 05 | Recursion, Induction, and Divide-and-Conquer | Induction, the call stack, binary search correctness, divide-and-conquer recurrences | Full mergesort |
| 06 | Sorting and Order Statistics | Insertion, selection, mergesort, quicksort (Lomuto), lower bound, counting sort, radix sort, quickselect | Heapsort's heap machinery |
| 07 | Trees, Binary Trees, and Traversals | Definitions, height convention, four traversals, expression trees | The BST search property |
| 08 | Binary Search Trees | Search property, insert, delete, successor, random-build cost, a bounded introduction to k-d trees | Rotations for balance |
| 09 | Balanced Search Trees | AVL rotations and height, red–black insertion, B-trees and 2–3–4 trees, order-statistic augmentation | Hashing |
| 10 | Heaps and Priority Queues | Binary heap, linear-time build, heapsort, decrease-key, Huffman codes | Dijkstra |
| 11 | Hash Tables | Chaining, load factor, open addressing, tombstones, the simple uniform hashing assumption | Balanced trees |
| 12 | Graphs: Representation, BFS, and DFS | Representations, BFS layers, DFS timestamps, edge classification, topological sort, Kosaraju | Weighted shortest paths |
| 13 | Shortest Paths, Spanning Trees, and Disjoint Sets | Relaxation, Dijkstra, Bellman–Ford, DAG shortest paths, cut and cycle properties, Prim, Kruskal, union-find | Tries |
| 14 | Tries, Strings, and Course Synthesis | Prefix trees, naive suffix arrays, a decision procedure for choosing a structure, the cumulative examination | A second copy of lectures 01–13 |

---

# 5. HOW THE IDEAS DEPEND ON EACH OTHER

```text
01 Analysis
    ├── 02 Dynamic arrays and amortization
    │       └── 04 Stacks and queues (array form)
    ├── 03 Linked lists
    │       └── 04 Stacks and queues (linked form)
    ├── 05 Recursion and induction
    │       └── 06 Sorting and selection
    │               └── 10 Heaps and heapsort
    └── 07 Tree vocabulary
            ├── 08 Binary search trees
            │       └── 09 AVL, red–black, B-trees
            ├── 10 Heaps (complete trees)
            └── 14 Tries

11 Hash tables  (needs 01 and 02)
12 Graphs       (needs 04 for the queue and the stack)
13 Shortest paths, MST, union-find
        needs 10 (priority queue), 12 (graphs), 06 (sorting edges)
14 Synthesis    needs all of the above
```

If lecture 09 is difficult, the failure is usually lecture 07's height convention or lecture 05's induction, not the rotation diagram. Go back to the lecture that owns the missing idea.

---

# 6. CONVENTIONS USED IN EVERY LECTURE

These choices are fixed so that a diagram in one lecture means the same thing in the next.

- Indexes start at $0$.
- $\log$ means $\log_2$. $\ln$ means the natural logarithm.
- A bound written $\Theta(f(n))$ is tight. A bound written $O(f(n))$ is only an upper bound.
- The empty tree has height $-1$. A leaf has height $0$. The root has depth $0$.
- AVL balance factor $= \mathrm{height}(\mathrm{left}) - \mathrm{height}(\mathrm{right}) \in \{-1,0,1\}$.
- A binary heap is stored in a 0-indexed array. The parent of $i$ is $\lfloor (i-1)/2 \rfloor$. The children of $i$ are $2i+1$ and $2i+2$.
- Quicksort's worked partition is Lomuto's partition.
- Graphs are stored as adjacency lists unless a section is about matrices.
- Dijkstra's algorithm in this course requires nonnegative edge weights and uses an indexed binary heap.
- Disjoint sets use union by rank and path compression.
- Absent child pointers and absent list links are `null`.

---

# 7. HOW TO STUDY ONE LECTURE

Use the same cycle every time.

1. Read the learning objectives and rewrite them as questions.
2. Read the body with a pencil. When a trace is given, cover the next row and produce it yourself.
3. Type the laboratory program yourself before you read it, or type it while you read it. Run it. Then change one assertion so that it must fail, confirm that it fails, and restore it.
4. Close the lecture and take the examination. Write full solutions.
5. Open the answer key. Mark what was wrong and return to that section. Do not read the key first.
6. Do the independent assignment. Keep the code. Later lectures assume you can still write the earlier structure.

A lecture is finished when you can state the invariant, give the cost, and implement the operations without the notes. The progress mark in Study Vault can move to **Reviewed** at that point. Move it to **Mastered** only after a later lecture has forced you to use the structure again and the scheduled review still feels solid.

Suggested week shape for a 6–10 hour lecture:

| Sitting | Work |
| --- | --- |
| 1 | Objectives, purpose, first half of the body |
| 2 | Second half of the body and the hand traces |
| 3 | Laboratory program |
| 4 | Examination under a time limit, then the key |
| 5 | Independent assignment |

---

# 8. ASSESSMENT YOU RUN YOURSELF

There is no instructor. The assessment is still real if you keep the artifacts.

| Item | When | What you produce |
| --- | --- | --- |
| Lecture examination | End of each lecture | Written solutions, then a marked key |
| Laboratory program | During each lecture | A JavaScript program that prints `ALL TESTS PASSED` |
| Independent assignment | End of each lecture | A small program or a written proof, kept |
| Mid-course checkpoint | After lecture 07 | Re-implement a dynamic array, a linked list, a queue, mergesort, and a binary tree from a blank file, with costs written beside each operation |
| Final examination | Lecture 14 | The cumulative paper inside that lecture |

The mid-course checkpoint is not a separate file. It is the assignment at the end of lecture 07, and it deliberately reaches back to lectures 02 through 06.

---

# 9. PRIMARY BOOKS

Read the lecture first. Use a book when a proof in the lecture is labeled as a sketch and you want the full argument.

1. Thomas H. Cormen, Charles E. Leiserson, Ronald L. Rivest, and Clifford Stein. *Introduction to Algorithms*. 4th edition. MIT Press, 2022.
2. Robert Sedgewick and Kevin Wayne. *Algorithms*. 4th edition. Addison-Wesley, 2011. The course site is [https://algs4.cs.princeton.edu/home/](https://algs4.cs.princeton.edu/home/).
3. Michael T. Goodrich, Roberto Tamassia, and Michael H. Goldwasser. *Data Structures and Algorithms in Java*. 6th edition. Wiley, 2014. The analysis and the ADT discipline transfer directly; the code in this course is JavaScript.
4. Mark Allen Weiss. *Data Structures and Algorithm Analysis in C++*. 4th edition. Pearson, 2014. Useful for AVL trees and the style of amortized arguments.

JavaScript is the language of the laboratories because this course sits in JOB Core beside the JavaScript and TypeScript subjects. The mathematics does not depend on that choice. When a Java or C++ book presents an array as a fixed block, translate it into the dynamic array of lecture 02 rather than into `Array.prototype.push` used as magic.

---

# 10. WHAT “UNIVERSITY LEVEL” MEANS HERE

It does not mean more adjectives. It means the following are present for each structure:

- a specification of the operations
- an implementation whose code you can run
- a cost for each operation, with the case (worst, average, amortized) named
- the assumption the average-case claim uses
- an invariant you can check after every update
- at least one place the structure is the wrong choice

Interview problems are practice after that, not a substitute for it. Lecture 14 includes a small set of choice problems of the kind an interview uses, and each one is answered by naming a structure from this course and its cost.

---

# 11. A FIRST READING OF THE VOCABULARY

You do not need to memorize this list now. It is a map of words so that lecture 01 does not feel like a new language.

| Word | The idea you will make precise |
| --- | --- |
| Abstract data type | A set of operations and their behavior, with no memory layout |
| Implementation | A concrete representation that provides those operations |
| Invariant | A property that is true before and after every public operation |
| RAM model | A machine that does one primitive step in constant time and addresses memory in constant time |
| Asymptotic bound | A description of cost as the input grows, ignoring constant factors and small inputs |
| Amortized cost | The average cost of one operation over a worst-case sequence, not over a random input |
| Node | A record that stores an element and one or more links |
| Tree | A connected acyclic set of nodes with one root |
| Heap order | A parent is ordered relative to its children; the tree is not fully sorted |
| Search property | Every key in the left subtree is smaller, and every key in the right subtree is larger |
| Hash | A function from keys to slots |
| Graph | A set of vertices and a set of edges |
| Relaxation | Replacing a recorded distance when a cheaper path is found |

---

# 12. START

Open **Lecture 01 — Models, ADTs, and Asymptotic Analysis**.

Do not begin with a tree. The tree lectures are short if lecture 01 is solid, and opaque if it is not.
