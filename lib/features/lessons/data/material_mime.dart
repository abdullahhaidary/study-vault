import 'package:path/path.dart' as p;

const kMarkdownMimeType = 'text/markdown';
const kPlainTextMimeType = 'text/plain';

/// One self-contained interactive HTML page.
const kHtmlMimeType = 'text/html';

/// A `.zip` of an interactive page with its own scripts, styles, and images.
const kHtmlBundleMimeType = 'application/vnd.study-vault.html-bundle+zip';

bool isHtmlPageMimeType(String mimeType) {
  return mimeType.toLowerCase() == kHtmlMimeType;
}

bool isHtmlBundleMimeType(String mimeType) {
  return mimeType.toLowerCase() == kHtmlBundleMimeType;
}

/// Interactive HTML runs in a web view. It is not a study document, so AI
/// Study Materials, Course Review, and chat context never read it.
bool isInteractiveHtmlMimeType(String mimeType) {
  return isHtmlPageMimeType(mimeType) || isHtmlBundleMimeType(mimeType);
}

bool isImageMimeType(String mimeType) {
  return mimeType.startsWith('image/');
}

bool isPdfMimeType(String mimeType) {
  return mimeType == 'application/pdf';
}

bool isMarkdownMimeType(String mimeType) {
  final mime = mimeType.toLowerCase();
  return mime == kMarkdownMimeType || mime == 'text/x-markdown';
}

bool isPlainTextMimeType(String mimeType) {
  return mimeType.toLowerCase() == kPlainTextMimeType;
}

/// Markdown or plain-text lesson attachments (PDF-like study sources).
bool isTextDocumentMimeType(String mimeType) {
  return isMarkdownMimeType(mimeType) || isPlainTextMimeType(mimeType);
}

/// PDF or text document — usable for AI Study Materials / Course Review.
bool isDocumentMimeType(String mimeType) {
  return isPdfMimeType(mimeType) || isTextDocumentMimeType(mimeType);
}

bool isTextDocumentPath(String filePath) {
  final ext = p.extension(filePath).toLowerCase();
  return ext == '.md' || ext == '.markdown' || ext == '.txt';
}

String materialKindLabel(String mimeType) {
  if (isPdfMimeType(mimeType)) return 'PDF';
  if (isMarkdownMimeType(mimeType)) return 'Markdown';
  if (isPlainTextMimeType(mimeType)) return 'Text';
  if (isImageMimeType(mimeType)) return 'Image';
  if (isHtmlPageMimeType(mimeType)) return 'Interactive HTML';
  if (isHtmlBundleMimeType(mimeType)) return 'Interactive HTML bundle';
  return 'File';
}

String guessMimeType(String fileName) {
  final ext = p.extension(fileName).toLowerCase();
  return switch (ext) {
    '.pdf' => 'application/pdf',
    '.md' || '.markdown' => kMarkdownMimeType,
    '.txt' => kPlainTextMimeType,
    '.html' || '.htm' => kHtmlMimeType,
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.bmp' => 'image/bmp',
    _ => 'application/octet-stream',
  };
}
