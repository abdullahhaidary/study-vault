import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/material_storage.dart';
import '../../lessons/data/material_mime.dart';

typedef MarkdownWriter =
    Future<void> Function({
      required String lessonId,
      required String storedFileName,
      required String contents,
    });

typedef LessonFilesCleanup = Future<void> Function(String lessonId);

/// Installs a complete, editable mathematics path for machine learning.
///
/// Each lesson includes a markdown study guide that can be read directly or
/// used as a grounded source for AI questions and answers.
class MlMathFoundationsService {
  MlMathFoundationsService(
    this._db, {
    MarkdownWriter? writeMarkdown,
    LessonFilesCleanup? cleanupLessonFiles,
    Uuid? uuid,
  }) : _writeMarkdown = writeMarkdown ?? MaterialStorage.writeText,
       _cleanupLessonFiles =
           cleanupLessonFiles ?? MaterialStorage.deleteLessonDir,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final MarkdownWriter _writeMarkdown;
  final LessonFilesCleanup _cleanupLessonFiles;
  final Uuid _uuid;

  Future<String> create() async {
    final now = DateTime.now();
    final classId = _uuid.v4();
    final subjects = <_PreparedSubject>[];
    final lessonIds = <String>[];

    for (
      var subjectIndex = 0;
      subjectIndex < _curriculum.length;
      subjectIndex++
    ) {
      final template = _curriculum[subjectIndex];
      final preparedLessons = <_PreparedLesson>[];
      for (
        var lessonIndex = 0;
        lessonIndex < template.lessons.length;
        lessonIndex++
      ) {
        final lesson = template.lessons[lessonIndex];
        final lessonId = _uuid.v4();
        lessonIds.add(lessonId);
        preparedLessons.add(
          _PreparedLesson(
            id: lessonId,
            materialId: _uuid.v4(),
            roadmapId: _uuid.v4(),
            sortOrder: lessonIndex,
            template: lesson,
            markdown: lesson.toMarkdown(subjectName: template.name),
          ),
        );
      }
      subjects.add(
        _PreparedSubject(
          id: _uuid.v4(),
          sortOrder: subjectIndex,
          template: template,
          lessons: preparedLessons,
        ),
      );
    }

    try {
      for (final subject in subjects) {
        for (final lesson in subject.lessons) {
          await _writeMarkdown(
            lessonId: lesson.id,
            storedFileName: '${lesson.materialId}.md',
            contents: '${lesson.markdown.trimRight()}\n',
          );
        }
      }

      await _db.transaction(() async {
        await _db.insertClass(
          ClassesCompanion.insert(
            id: classId,
            name: 'Mathematics for Machine Learning',
            description: const Value(
              'A foundations-to-optimization specialization with worked '
              'equations, ML connections, and practice prompts.',
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );

        var roadmapOrder = 0;
        for (final subject in subjects) {
          await _db.insertSubject(
            SubjectsCompanion.insert(
              id: subject.id,
              classId: classId,
              name: subject.template.name,
              description: Value(subject.template.description),
              sortOrder: Value(subject.sortOrder),
              createdAt: now,
              updatedAt: now,
            ),
          );

          for (final lesson in subject.lessons) {
            await _db.insertLesson(
              LessonsCompanion.insert(
                id: lesson.id,
                subjectId: subject.id,
                name: lesson.template.name,
                description: Value(lesson.template.summary),
                sortOrder: Value(lesson.sortOrder),
                createdAt: now,
                updatedAt: now,
              ),
            );
            await _db.insertLessonMaterial(
              LessonMaterialsCompanion.insert(
                id: lesson.materialId,
                lessonId: lesson.id,
                title: '${lesson.template.name} — Study Guide',
                originalFileName: 'study-guide.md',
                storedFileName: '${lesson.materialId}.md',
                mimeType: const Value(kMarkdownMimeType),
                createdAt: now,
                updatedAt: now,
              ),
            );
            await _db.insertRoadmapEntry(
              ClassRoadmapEntriesCompanion.insert(
                id: lesson.roadmapId,
                classId: classId,
                lessonId: lesson.id,
                sortOrder: Value(roadmapOrder++),
                note: const Value(
                  'Read the guide, solve the checks, then generate a mixed quiz.',
                ),
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        }
      });
      return classId;
    } catch (_) {
      for (final lessonId in lessonIds) {
        try {
          await _cleanupLessonFiles(lessonId);
        } catch (_) {
          // Keep cleaning the remaining lesson folders and preserve the
          // original creation failure.
        }
      }
      rethrow;
    }
  }
}

class _PreparedSubject {
  const _PreparedSubject({
    required this.id,
    required this.sortOrder,
    required this.template,
    required this.lessons,
  });

  final String id;
  final int sortOrder;
  final _SubjectTemplate template;
  final List<_PreparedLesson> lessons;
}

class _PreparedLesson {
  const _PreparedLesson({
    required this.id,
    required this.materialId,
    required this.roadmapId,
    required this.sortOrder,
    required this.template,
    required this.markdown,
  });

  final String id;
  final String materialId;
  final String roadmapId;
  final int sortOrder;
  final _LessonTemplate template;
  final String markdown;
}

class _SubjectTemplate {
  const _SubjectTemplate({
    required this.name,
    required this.description,
    required this.lessons,
  });

  final String name;
  final String description;
  final List<_LessonTemplate> lessons;
}

class _LessonTemplate {
  const _LessonTemplate({
    required this.name,
    required this.summary,
    required this.coreIdeas,
    required this.equations,
    required this.mlConnection,
    required this.practice,
  });

  final String name;
  final String summary;
  final List<String> coreIdeas;
  final List<String> equations;
  final String mlConnection;
  final List<String> practice;

  String toMarkdown({required String subjectName}) {
    final buffer = StringBuffer()
      ..writeln('# $name')
      ..writeln()
      ..writeln('**Track:** $subjectName')
      ..writeln()
      ..writeln(summary)
      ..writeln()
      ..writeln('## Core ideas');
    for (final idea in coreIdeas) {
      buffer.writeln('- $idea');
    }
    buffer
      ..writeln()
      ..writeln('## Core equations');
    for (final equation in equations) {
      buffer
        ..writeln(r'$$')
        ..writeln(equation)
        ..writeln(r'$$')
        ..writeln();
    }
    buffer
      ..writeln('## Machine-learning connection')
      ..writeln()
      ..writeln(mlConnection)
      ..writeln()
      ..writeln('## Check your understanding');
    for (final question in practice) {
      buffer.writeln('- $question');
    }
    buffer
      ..writeln()
      ..writeln(
        '> After solving these checks, generate a mixed quiz from this '
        'document. Review every explanation, not only the score.',
      );
    return buffer.toString();
  }
}

const _curriculum = <_SubjectTemplate>[
  _SubjectTemplate(
    name: 'Foundations and Mathematical Language',
    description:
        'The notation, functions, algebra, and numerical habits used throughout machine learning.',
    lessons: [
      _LessonTemplate(
        name: 'Functions, graphs, and transformations',
        summary:
            'A function maps inputs to outputs. Learn to read domain, range, composition, inverse behavior, and how parameters transform a graph.',
        coreIdeas: [
          'Treat a model as a parameterized function from features to predictions.',
          'Composition applies one function after another; order generally matters.',
          'A graph makes growth, saturation, symmetry, and discontinuities visible.',
        ],
        equations: [
          r'y=f(x), \qquad (f\circ g)(x)=f(g(x))',
          r'g(x)=a\,f(b(x-h))+k',
        ],
        mlConnection:
            'Neural networks are compositions of affine transformations and nonlinear activation functions. Understanding composition prepares you for the chain rule and backpropagation.',
        practice: [
          r'If $f(x)=x^2$ and $g(x)=2x-1$, compute $(f\circ g)(3)$ and $(g\circ f)(3)$.',
          'Explain what the parameters in a shifted and scaled graph change.',
        ],
      ),
      _LessonTemplate(
        name: 'Exponents, logarithms, and growth',
        summary:
            'Exponents describe repeated multiplication and logarithms invert exponentials. Their identities are essential for probabilities and stable computation.',
        coreIdeas: [
          'Logarithms turn products into sums and powers into multipliers.',
          'Natural logarithms are especially convenient because their derivative is simple.',
          'Log-space computation prevents underflow when probabilities are tiny.',
        ],
        equations: [
          r'a^{x+y}=a^x a^y, \qquad \log(ab)=\log a+\log b',
          r'\log(a^k)=k\log a, \qquad e^{\log x}=x',
        ],
        mlConnection:
            'Cross-entropy and maximum likelihood use log probabilities. Summing log-likelihoods is both mathematically convenient and numerically safer than multiplying probabilities.',
        practice: [
          r'Simplify $\log(x^3y)-\log(y)$ for positive $x,y$.',
          'Why is a sum of log probabilities more stable than a product of probabilities?',
        ],
      ),
      _LessonTemplate(
        name: 'Summations, products, and indexing',
        summary:
            'Compact notation lets us describe datasets, losses, vectors, and repeated operations without writing every term.',
        coreIdeas: [
          'An index identifies one observation, feature, class, or parameter.',
          'Linearity lets constants and sums move through many operations.',
          'Always state index ranges and distinguish sample count from feature count.',
        ],
        equations: [
          r'\sum_{i=1}^{n} x_i=x_1+\cdots+x_n',
          r'\bar{x}=\frac{1}{n}\sum_{i=1}^{n}x_i, \qquad \prod_{i=1}^{n}p_i',
        ],
        mlConnection:
            'Empirical risk is an average over training examples. Matrix notation later compresses nested sums over examples and features.',
        practice: [
          r'Compute $\sum_{i=1}^{4}(2i-1)$.',
          r'Rewrite the mean squared error for $n$ predictions using sigma notation.',
        ],
      ),
      _LessonTemplate(
        name: 'Sets, logic, and proof habits',
        summary:
            'Sets describe data spaces and events; logic helps you test assumptions and distinguish examples from proofs.',
        coreIdeas: [
          'Union means OR, intersection means AND, and complement means NOT.',
          'A counterexample disproves a universal claim.',
          'Necessary and sufficient conditions are different directions of implication.',
        ],
        equations: [
          r'x\in A\cap B \iff (x\in A)\land(x\in B)',
          r'A\subseteq B \iff \forall x,\;x\in A\Rightarrow x\in B',
        ],
        mlConnection:
            'Model guarantees depend on assumptions. Clear logic prevents you from treating an empirical observation as a universal theorem.',
        practice: [
          'Give a counterexample to the claim that every differentiable function is convex.',
          r'Express “a sample belongs to class 1 or class 2” using sets.',
        ],
      ),
    ],
  ),
  _SubjectTemplate(
    name: 'Linear Algebra',
    description:
        'Vectors, matrices, geometry, decompositions, and dimensionality reduction.',
    lessons: [
      _LessonTemplate(
        name: 'Vectors, norms, and similarity',
        summary:
            'Vectors represent feature collections and directions. Norms measure size; dot products connect algebra to angles and projections.',
        coreIdeas: [
          'Vector addition combines displacements or feature contributions.',
          'The dot product is large when vectors point in similar directions.',
          'Different norms encode different notions of distance and regularization.',
        ],
        equations: [
          r'\mathbf{x}^{\mathsf T}\mathbf{y}=\sum_{j=1}^{d}x_jy_j',
          r'\|\mathbf{x}\|_2=\sqrt{\sum_j x_j^2}, \qquad \cos\theta=\frac{\mathbf{x}^{\mathsf T}\mathbf{y}}{\|\mathbf{x}\|_2\|\mathbf{y}\|_2}',
        ],
        mlConnection:
            'Feature rows, embeddings, gradients, and model weights are vectors. Cosine similarity is widely used for retrieval and semantic search.',
        practice: [
          r'For $\mathbf{x}=(3,4)$, compute its $L_1$ and $L_2$ norms.',
          'When can cosine similarity be high even if Euclidean distance is large?',
        ],
      ),
      _LessonTemplate(
        name: 'Matrices as data and transformations',
        summary:
            'A matrix can store a dataset or represent a linear transformation. Shape tracking is the fastest way to catch algebra mistakes.',
        coreIdeas: [
          'Rows commonly represent samples and columns represent features.',
          'Matrix multiplication composes linear transformations.',
          'The inner dimensions must match; multiplication order matters.',
        ],
        equations: [
          r'\mathbf{X}\in\mathbb{R}^{n\times d},\quad \mathbf{w}\in\mathbb{R}^{d},\quad \hat{\mathbf{y}}=\mathbf{X}\mathbf{w}\in\mathbb{R}^{n}',
          r'(\mathbf{A}\mathbf{B})_{ij}=\sum_k A_{ik}B_{kj}',
        ],
        mlConnection:
            'A batch of examples is a matrix. Dense neural-network layers apply one matrix multiplication to an entire batch.',
        practice: [
          r'If $\mathbf{X}$ is $100\times20$ and $\mathbf{W}$ is $20\times8$, what is the output shape?',
          'Explain geometrically why matrix multiplication order matters.',
        ],
      ),
      _LessonTemplate(
        name: 'Linear systems, span, rank, and inverse',
        summary:
            'Linear systems reveal whether information is sufficient, redundant, or contradictory. Rank measures the number of independent directions.',
        coreIdeas: [
          'A span contains every linear combination of a set of vectors.',
          'Linear dependence means one direction can be built from others.',
          'Solve systems with elimination; avoid explicitly computing inverses in numerical code.',
        ],
        equations: [
          r'\mathbf{A}\mathbf{x}=\mathbf{b}',
          r'\operatorname{rank}(\mathbf{A})=\dim(\operatorname{Col}(\mathbf{A}))',
        ],
        mlConnection:
            'Correlated features create rank deficiency and unstable coefficients. Least-squares solvers use robust factorizations rather than a literal matrix inverse.',
        practice: [
          'How does duplicating a feature column affect matrix rank?',
          r'What must be true for a square matrix $\mathbf{A}$ to have a unique inverse?',
        ],
      ),
      _LessonTemplate(
        name: 'Orthogonality and projections',
        summary:
            'Orthogonal directions separate independent geometric components. Projection finds the closest point in a subspace.',
        coreIdeas: [
          'Orthogonal vectors have zero dot product.',
          'An orthonormal basis preserves lengths and simplifies coordinates.',
          'Least squares projects a target onto the column space of the design matrix.',
        ],
        equations: [
          r'\operatorname{proj}_{\mathbf{u}}(\mathbf{x})=\frac{\mathbf{x}^{\mathsf T}\mathbf{u}}{\mathbf{u}^{\mathsf T}\mathbf{u}}\mathbf{u}',
          r'\hat{\mathbf{y}}=\mathbf{X}(\mathbf{X}^{\mathsf T}\mathbf{X})^{-1}\mathbf{X}^{\mathsf T}\mathbf{y}',
        ],
        mlConnection:
            'Linear regression is a projection problem. Orthogonal features reduce interference and improve numerical interpretation.',
        practice: [
          r'Project $(3,4)$ onto the direction $(1,0)$.',
          'Why is the least-squares residual orthogonal to every column of the design matrix?',
        ],
      ),
      _LessonTemplate(
        name: 'Eigenvalues and eigenvectors',
        summary:
            'Eigenvectors are directions a transformation does not rotate; eigenvalues state how those directions scale.',
        coreIdeas: [
          'Eigenpairs summarize invariant directions of a square matrix.',
          'Symmetric real matrices have real eigenvalues and orthogonal eigenvectors.',
          'Repeated multiplication emphasizes directions with large eigenvalue magnitude.',
        ],
        equations: [
          r'\mathbf{A}\mathbf{v}=\lambda\mathbf{v}',
          r'\mathbf{A}=\mathbf{Q}\mathbf{\Lambda}\mathbf{Q}^{\mathsf T}\quad\text{for symmetric }\mathbf{A}',
        ],
        mlConnection:
            'Covariance eigenvectors identify principal directions of variation. Spectral methods also appear in clustering, graphs, and stability analysis.',
        practice: [
          r'Find the eigenvalues of $\begin{bmatrix}2&0\\0&5\end{bmatrix}$.',
          'What does a zero eigenvalue imply about a transformation?',
        ],
      ),
      _LessonTemplate(
        name: 'SVD and principal component analysis',
        summary:
            'The singular value decomposition works for any matrix and exposes its most important input-output directions.',
        coreIdeas: [
          'Singular values rank directions by captured scale or information.',
          'Low-rank approximation keeps dominant structure while discarding weaker directions.',
          'PCA applies an eigendecomposition or SVD after centering the data.',
        ],
        equations: [
          r'\mathbf{X}=\mathbf{U}\mathbf{\Sigma}\mathbf{V}^{\mathsf T}',
          r'\mathbf{X}_k=\mathbf{U}_k\mathbf{\Sigma}_k\mathbf{V}_k^{\mathsf T}',
        ],
        mlConnection:
            'PCA compresses correlated features and supports visualization. Truncated SVD also powers latent representations in text and recommendation systems.',
        practice: [
          'Why must data usually be centered before PCA?',
          'Describe the trade-off when choosing a smaller rank for an approximation.',
        ],
      ),
    ],
  ),
  _SubjectTemplate(
    name: 'Calculus and Backpropagation',
    description:
        'Rates of change, multivariable derivatives, and the chain rule behind learning.',
    lessons: [
      _LessonTemplate(
        name: 'Limits, derivatives, and local approximation',
        summary:
            'A derivative is an instantaneous rate of change and the slope of the best local linear approximation.',
        coreIdeas: [
          'Limits describe behavior near a point.',
          'Derivative sign tells whether a function locally rises or falls.',
          'A first-order approximation is accurate for sufficiently small changes.',
        ],
        equations: [
          r'f^\prime(x)=\lim_{h\to0}\frac{f(x+h)-f(x)}{h}',
          r'f(x+\Delta x)\approx f(x)+f^\prime(x)\Delta x',
        ],
        mlConnection:
            'Training algorithms use local slope information to choose parameter updates. Learning rate controls the size of the local step.',
        practice: [
          r'Differentiate $f(x)=3x^2-2x+1$.',
          'When can a local linear approximation become misleading?',
        ],
      ),
      _LessonTemplate(
        name: 'Derivative rules and computational graphs',
        summary:
            'Product, quotient, and chain rules differentiate complex expressions by decomposing them into simpler operations.',
        coreIdeas: [
          'The chain rule multiplies local rates along a composition.',
          'A computational graph records intermediate values and dependencies.',
          'Reuse intermediate derivatives instead of expanding a large expression.',
        ],
        equations: [
          r'\frac{d}{dx}f(g(x))=f^\prime(g(x))g^\prime(x)',
          r'(uv)^\prime=u^\prime v+uv^\prime',
        ],
        mlConnection:
            'Automatic differentiation applies the chain rule across a computational graph. Reverse mode efficiently computes gradients of one scalar loss with many parameters.',
        practice: [
          r'Differentiate $\log(1+e^{2x})$ using the chain rule.',
          'Draw a computational graph for squared error and label each local derivative.',
        ],
      ),
      _LessonTemplate(
        name: 'Partial derivatives and gradients',
        summary:
            'A partial derivative changes one input while holding others fixed. The gradient collects all partial derivatives and points uphill.',
        coreIdeas: [
          'The gradient has the same shape as the parameter vector.',
          'Directional derivatives are dot products with the gradient.',
          'The negative gradient is the steepest local descent direction.',
        ],
        equations: [
          r'\nabla f(\mathbf{x})=\begin{bmatrix}\partial f/\partial x_1\\ \vdots\\ \partial f/\partial x_d\end{bmatrix}',
          r'D_{\mathbf{u}}f=\nabla f(\mathbf{x})^{\mathsf T}\mathbf{u}',
        ],
        mlConnection:
            'Every training step depends on the gradient of loss with respect to parameters. Gradient shape and scale are key debugging signals.',
        practice: [
          r'Find $\nabla f(x,y)$ for $f=x^2+3xy+y^2$.',
          'Why does moving against the gradient reduce a smooth function for a small enough step?',
        ],
      ),
      _LessonTemplate(
        name: 'Jacobians, Hessians, and curvature',
        summary:
            'Jacobians generalize first derivatives to vector outputs; Hessians collect second derivatives and describe local curvature.',
        coreIdeas: [
          'A Jacobian maps a small input change to an output change.',
          'A positive-definite Hessian indicates locally upward curvature.',
          'Curvature explains why one learning rate can be too small in one direction and too large in another.',
        ],
        equations: [
          r'J_{ij}=\frac{\partial f_i}{\partial x_j}',
          r'H_{ij}=\frac{\partial^2 f}{\partial x_i\partial x_j}',
        ],
        mlConnection:
            'Backpropagation computes vector-Jacobian products without materializing huge Jacobians. Second-order information motivates Newton and quasi-Newton methods.',
        practice: [
          r'Write the Jacobian shape for $f:\mathbb{R}^3\to\mathbb{R}^2$.',
          'What does a negative Hessian eigenvalue say about a stationary point?',
        ],
      ),
      _LessonTemplate(
        name: 'Backpropagation by hand',
        summary:
            'Backpropagation sends loss sensitivity backward through each operation while reusing intermediate results.',
        coreIdeas: [
          'The forward pass stores values needed by local derivatives.',
          'The backward pass accumulates every path by which a variable affects the loss.',
          'Check gradients numerically when implementing a new operation.',
        ],
        equations: [
          r'z=\mathbf{w}^{\mathsf T}\mathbf{x}+b,\quad a=\sigma(z),\quad L=(a-y)^2',
          r'\frac{\partial L}{\partial \mathbf{w}}=\frac{\partial L}{\partial a}\frac{\partial a}{\partial z}\frac{\partial z}{\partial \mathbf{w}}',
        ],
        mlConnection:
            'This is the core learning mechanism of neural networks. Frameworks automate it, but manual shape and chain-rule reasoning remains essential for debugging.',
        practice: [
          'For one sigmoid neuron, list the derivatives needed from loss back to each weight.',
          'Why do shared parameters receive a sum of gradient contributions?',
        ],
      ),
    ],
  ),
  _SubjectTemplate(
    name: 'Probability, Statistics, and Information',
    description:
        'Uncertainty, distributions, estimation, Bayesian reasoning, and information-based losses.',
    lessons: [
      _LessonTemplate(
        name: 'Probability rules and conditional probability',
        summary:
            'Probability quantifies uncertainty. Conditional probability updates the sample space after information is observed.',
        coreIdeas: [
          'Probabilities are nonnegative and sum to one over exhaustive outcomes.',
          'Independence is stronger than being different or uncorrelated.',
          'The product rule links joint and conditional probability.',
        ],
        equations: [
          r'P(A\mid B)=\frac{P(A\cap B)}{P(B)}',
          r'P(A\cap B)=P(A\mid B)P(B)',
        ],
        mlConnection:
            'Classification outputs are often interpreted as conditional probabilities of labels given features.',
        practice: [
          'Give an example where two events are mutually exclusive but not independent.',
          r'Compute $P(A\cap B)$ from a conditional probability and a marginal probability.',
        ],
      ),
      _LessonTemplate(
        name: 'Random variables and common distributions',
        summary:
            'A random variable assigns numbers to outcomes. A distribution specifies which values are likely.',
        coreIdeas: [
          'Discrete distributions use probability mass; continuous distributions use density.',
          'Parameters control location, spread, or shape.',
          'Choose a distribution whose support matches the data.',
        ],
        equations: [
          r'X\sim\operatorname{Bernoulli}(p),\quad P(X=x)=p^x(1-p)^{1-x}',
          r'X\sim\mathcal{N}(\mu,\sigma^2)',
        ],
        mlConnection:
            'Bernoulli models binary labels, categorical distributions model classes, and Gaussians model continuous noise and latent variables.',
        practice: [
          'Which distribution would you use for a binary label, a class label, and a real-valued measurement?',
          r'For $X\sim\operatorname{Bernoulli}(0.7)$, compute $P(X=0)$.',
        ],
      ),
      _LessonTemplate(
        name: 'Expectation, variance, and covariance',
        summary:
            'Expectation is a probability-weighted average; variance measures spread; covariance measures joint linear variation.',
        coreIdeas: [
          'Expectation is linear even when variables are dependent.',
          'Variance is measured in squared units.',
          'Correlation normalizes covariance but does not imply causation.',
        ],
        equations: [
          r'\mathbb{E}[X]=\sum_x xP(X=x)',
          r'\operatorname{Var}(X)=\mathbb{E}[(X-\mu)^2],\quad \operatorname{Cov}(X,Y)=\mathbb{E}[(X-\mu_X)(Y-\mu_Y)]',
        ],
        mlConnection:
            'Feature standardization uses means and variances. Covariance structure underlies PCA and multivariate Gaussian models.',
        practice: [
          'Why does adding a constant change the mean but not the variance?',
          'What can zero covariance tell you, and what can it not tell you?',
        ],
      ),
      _LessonTemplate(
        name: 'Bayes rule and probabilistic inference',
        summary:
            'Bayes rule reverses a conditional probability by combining evidence with prior belief.',
        coreIdeas: [
          'The likelihood scores how compatible data are with a hypothesis.',
          'The evidence normalizes posterior probabilities.',
          'A strong prior matters most when data are limited.',
        ],
        equations: [
          r'P(\theta\mid D)=\frac{P(D\mid\theta)P(\theta)}{P(D)}',
          r'\text{posterior}\propto\text{likelihood}\times\text{prior}',
        ],
        mlConnection:
            'Bayesian models represent uncertainty over parameters or predictions. Naive Bayes applies Bayes rule with a strong conditional-independence assumption.',
        practice: [
          'Explain prior, likelihood, evidence, and posterior in a medical-test example.',
          'Why can a highly accurate test still produce many false positives for a rare condition?',
        ],
      ),
      _LessonTemplate(
        name: 'Likelihood, MLE, and MAP estimation',
        summary:
            'Estimation chooses parameter values that make observed data plausible. Logs convert products into manageable sums.',
        coreIdeas: [
          'Likelihood treats data as fixed and parameters as variable.',
          'Maximum likelihood uses data fit; MAP adds a prior preference.',
          'Negative log-likelihood often becomes the training loss.',
        ],
        equations: [
          r'\hat{\theta}_{\mathrm{MLE}}=\arg\max_\theta\prod_{i=1}^{n}p(x_i\mid\theta)',
          r'\hat{\theta}_{\mathrm{MAP}}=\arg\max_\theta\left[\sum_i\log p(x_i\mid\theta)+\log p(\theta)\right]',
        ],
        mlConnection:
            'Mean squared error follows from Gaussian observation noise; binary cross-entropy follows from a Bernoulli likelihood.',
        practice: [
          'Derive the MLE of a Bernoulli parameter from observed zeros and ones.',
          'How does MAP connect a probabilistic prior to regularization?',
        ],
      ),
      _LessonTemplate(
        name: 'Sampling, estimation, and the central limit theorem',
        summary:
            'Samples vary. Estimators summarize samples, and sampling distributions describe their uncertainty.',
        coreIdeas: [
          'Bias and variance are different estimator properties.',
          'Standard error shrinks as sample size grows.',
          'The central limit theorem concerns sample averages, not necessarily raw data.',
        ],
        equations: [
          r'\bar{X}=\frac{1}{n}\sum_{i=1}^{n}X_i',
          r'\frac{\bar{X}-\mu}{\sigma/\sqrt{n}}\xrightarrow{d}\mathcal{N}(0,1)',
        ],
        mlConnection:
            'Train/validation scores are estimates with uncertainty. Resampling and confidence intervals help distinguish real improvements from noise.',
        practice: [
          'What happens to standard error when sample size is multiplied by four?',
          'Why does a representative sample matter more than a merely large biased sample?',
        ],
      ),
      _LessonTemplate(
        name: 'Entropy, cross-entropy, and KL divergence',
        summary:
            'Information theory measures uncertainty and the cost of encoding outcomes under an imperfect probability model.',
        coreIdeas: [
          'Entropy is high when outcomes are uncertain.',
          'Cross-entropy penalizes confident probability assigned to the wrong outcome.',
          'KL divergence is asymmetric and nonnegative.',
        ],
        equations: [
          r'H(p)=-\sum_x p(x)\log p(x)',
          r'H(p,q)=-\sum_x p(x)\log q(x)=H(p)+D_{\mathrm{KL}}(p\|q)',
        ],
        mlConnection:
            'Cross-entropy is the standard classification loss. KL divergence appears in variational inference, distillation, and distribution matching.',
        practice: [
          'Why is predicting probability zero for the true class severely penalized?',
          r'If $p=q$, what is $D_{\mathrm{KL}}(p\|q)$ and why?',
        ],
      ),
    ],
  ),
  _SubjectTemplate(
    name: 'Optimization and Generalization',
    description:
        'Loss landscapes, gradient methods, regularization, and constrained optimization.',
    lessons: [
      _LessonTemplate(
        name: 'Objectives, empirical risk, and regularization',
        summary:
            'Training turns learning into optimization: choose parameters that minimize average loss plus any desired complexity penalty.',
        coreIdeas: [
          'The loss measures one prediction; empirical risk averages over data.',
          'Regularization expresses a preference beyond fitting the training set.',
          'Training loss and generalization performance are not the same objective.',
        ],
        equations: [
          r'J(\theta)=\frac{1}{n}\sum_{i=1}^{n}\ell(f_\theta(x_i),y_i)+\lambda R(\theta)',
          r'R_{L_2}(\theta)=\|\theta\|_2^2,\qquad R_{L_1}(\theta)=\|\theta\|_1',
        ],
        mlConnection:
            'This equation describes much of supervised learning. Validation data and regularization help control overfitting.',
        practice: [
          'What behavior does increasing the regularization strength encourage?',
          'Compare the typical effects of L1 and L2 penalties.',
        ],
      ),
      _LessonTemplate(
        name: 'Gradient descent and learning rates',
        summary:
            'Gradient descent repeatedly takes a step opposite the local slope. Step size determines stability and speed.',
        coreIdeas: [
          'A tiny learning rate is stable but slow; a large one can overshoot.',
          'Feature scaling improves the geometry seen by gradient descent.',
          'Convergence of a nonconvex model does not guarantee a global minimum.',
        ],
        equations: [
          r'\theta_{t+1}=\theta_t-\eta\nabla J(\theta_t)',
          r'J(\theta+\Delta)\approx J(\theta)+\nabla J(\theta)^{\mathsf T}\Delta',
        ],
        mlConnection:
            'Nearly every neural network is trained by a gradient-based optimizer. Loss curves reveal divergence, plateaus, and poor step sizes.',
        practice: [
          'Predict the loss-curve behavior for learning rates that are too small and too large.',
          r'Perform one gradient-descent step for $J(w)=(w-3)^2$ from $w=0$ with $\eta=0.1$.',
        ],
      ),
      _LessonTemplate(
        name: 'SGD, momentum, and Adam',
        summary:
            'Mini-batch methods trade exact gradients for fast noisy estimates. Momentum and adaptive scaling reshape updates over time.',
        coreIdeas: [
          'An unbiased mini-batch gradient can still have high variance.',
          'Momentum accumulates a velocity that smooths oscillations.',
          'Adam combines momentum-like first moments with adaptive second moments.',
        ],
        equations: [
          r'\mathbf{v}_t=\beta\mathbf{v}_{t-1}+(1-\beta)\mathbf{g}_t,\qquad \theta_{t+1}=\theta_t-\eta\mathbf{v}_t',
          r'\theta_{t+1}=\theta_t-\eta\frac{\hat{\mathbf{m}}_t}{\sqrt{\hat{\mathbf{v}}_t}+\epsilon}',
        ],
        mlConnection:
            'Optimizer choice changes training dynamics, memory use, and tuning needs. Adam is convenient, while SGD with momentum can generalize strongly in some settings.',
        practice: [
          'How does batch size affect gradient noise and computation per update?',
          'Why is the small epsilon term needed in Adam?',
        ],
      ),
      _LessonTemplate(
        name: 'Convexity and constrained optimization',
        summary:
            'Convex problems have no bad local minima. Constraints can be incorporated with Lagrange multipliers.',
        coreIdeas: [
          'For a convex objective, every local minimum is global.',
          'A convex feasible set contains the line segment between any two feasible points.',
          'A Lagrange multiplier measures sensitivity to a constraint.',
        ],
        equations: [
          r'f(tx+(1-t)y)\leq tf(x)+(1-t)f(y),\quad 0\leq t\leq1',
          r'\mathcal{L}(x,\lambda)=f(x)+\lambda g(x)',
        ],
        mlConnection:
            'Linear and logistic regression have convex objectives under standard settings; deep networks do not. Constraints appear in normalization, fairness, budgets, and margins.',
        practice: [
          'Explain why convexity makes optimization guarantees stronger.',
          r'Use a Lagrange multiplier to set up minimizing $x^2+y^2$ subject to $x+y=1$.',
        ],
      ),
    ],
  ),
];
