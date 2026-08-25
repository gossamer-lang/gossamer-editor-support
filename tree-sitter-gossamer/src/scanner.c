// External scanner for the two Gossamer tokens a regular expression cannot
// lex: nesting block comments and triple-quoted strings. Both mirror the
// corresponding loop in the compiler's gossamer-lex crate, and both accept
// an unterminated literal to EOF, matching the compiler's recovery.

#include "tree_sitter/parser.h"

enum TokenType {
  BLOCK_COMMENT,
  MULTILINE_STRING_LITERAL,
  LINE_SEPARATOR,
};

void *tree_sitter_gossamer_external_scanner_create(void) { return NULL; }

void tree_sitter_gossamer_external_scanner_destroy(void *payload) { (void)payload; }

unsigned tree_sitter_gossamer_external_scanner_serialize(void *payload, char *buffer) {
  (void)payload;
  (void)buffer;
  return 0;
}

void tree_sitter_gossamer_external_scanner_deserialize(void *payload, const char *buffer,
                                                       unsigned length) {
  (void)payload;
  (void)buffer;
  (void)length;
}

// `/* a /* b */ c */` is a single comment, so the terminator is the `*/`
// that brings the nesting depth back to zero.
static bool scan_block_comment(TSLexer *lexer) {
  if (lexer->lookahead != '/') {
    return false;
  }
  lexer->advance(lexer, false);
  if (lexer->lookahead != '*') {
    return false;
  }
  lexer->advance(lexer, false);

  unsigned depth = 1;
  while (depth > 0 && !lexer->eof(lexer)) {
    int32_t current = lexer->lookahead;
    lexer->advance(lexer, false);
    if (current == '/' && lexer->lookahead == '*') {
      lexer->advance(lexer, false);
      depth += 1;
    } else if (current == '*' && lexer->lookahead == '/') {
      lexer->advance(lexer, false);
      depth -= 1;
    }
  }

  lexer->result_symbol = BLOCK_COMMENT;
  return true;
}

// A triple-quoted body carries the same escapes an ordinary string does, so
// the literal ends at the first `"""` an escape has not already consumed.
static bool scan_multiline_string(TSLexer *lexer) {
  for (unsigned i = 0; i < 3; i++) {
    if (lexer->lookahead != '"') {
      return false;
    }
    lexer->advance(lexer, false);
  }

  unsigned quotes = 0;
  while (!lexer->eof(lexer)) {
    if (lexer->lookahead == '\\') {
      lexer->advance(lexer, false);
      if (!lexer->eof(lexer)) {
        lexer->advance(lexer, false);
      }
      quotes = 0;
      continue;
    }
    if (lexer->lookahead == '"') {
      lexer->advance(lexer, false);
      quotes += 1;
      if (quotes == 3) {
        break;
      }
      continue;
    }
    lexer->advance(lexer, false);
    quotes = 0;
  }

  lexer->result_symbol = MULTILINE_STRING_LITERAL;
  return true;
}

// A line break separates two elements only when another element follows it;
// before a closing delimiter, or a line that continues the expression above,
// the list has not moved on. The decision reads at most two characters so
// that a `false` answer leaves the position usable by the scans below.
static bool element_follows(TSLexer *lexer) {
  if (lexer->eof(lexer)) {
    return false;
  }
  switch (lexer->lookahead) {
    case '}':
    case ')':
    case ']':
    case ',':
      return false;
    // A line opening with a binary operator continues the expression above
    // it. `*` and `-` are absent: the language reads a leading one of those
    // as the start of a new element.
    case '+':
    case '?':
    case '|':
    case '=':
    case '<':
    case '>':
    case '%':
    case '^':
      return false;
    // Either division or a comment; a comment is consumed as an extra and
    // the break is still here to be read on the next scan.
    case '/':
      return false;
    case '&':
      // `&x` is a reference and starts an element; `&&` continues.
      lexer->advance(lexer, true);
      return lexer->lookahead != '&';
    case '.':
      // `.method()` continues a chain; `..base` and `..end` are elements.
      lexer->advance(lexer, true);
      return lexer->lookahead == '.';
    default:
      return true;
  }
}

bool tree_sitter_gossamer_external_scanner_scan(void *payload, TSLexer *lexer,
                                                const bool *valid_symbols) {
  (void)payload;
  // The scanner runs before the whitespace extra is consumed, so this is
  // where a line break between two list elements is still visible.
  bool line_break = false;
  while (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
         lexer->lookahead == '\n' || lexer->lookahead == '\r') {
    line_break = line_break || lexer->lookahead == '\n';
    lexer->advance(lexer, true);
  }

  // Zero-width: the break stands in for the comma, it does not consume text.
  // Fixing the end here lets the peek below range past comments without
  // pulling any of them into the token.
  if (valid_symbols[LINE_SEPARATOR] && line_break) {
    lexer->mark_end(lexer);
    if (element_follows(lexer)) {
      lexer->result_symbol = LINE_SEPARATOR;
      return true;
    }
  }
  if (valid_symbols[MULTILINE_STRING_LITERAL] && lexer->lookahead == '"') {
    return scan_multiline_string(lexer);
  }
  if (valid_symbols[BLOCK_COMMENT] && lexer->lookahead == '/') {
    return scan_block_comment(lexer);
  }
  return false;
}
