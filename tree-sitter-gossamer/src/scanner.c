// External scanner for the Gossamer tokens a regular expression cannot lex:
// nesting block comments, triple-quoted strings, and raw strings, plus the
// newline that stands in for a list comma. The literals mirror the
// corresponding loops in the compiler's gossamer-lex crate, and each accepts
// an unterminated literal to EOF, matching the compiler's recovery.

#include "tree_sitter/alloc.h"
#include "tree_sitter/parser.h"

#include <string.h>

enum TokenType {
  BLOCK_COMMENT,
  MULTILINE_STRING_LITERAL,
  LINE_SEPARATOR,
  RAW_STRING_LITERAL,
  RAW_BYTE_STRING_LITERAL,
};

// A block comment that opens a line hides that line's break from the scan
// after it, so the comment records the break and the column it ended at. The
// scan that starts at exactly that column is the one directly after the
// comment; any later scan on the same row starts at a different column, and
// one on a later row has seen a break of its own.
typedef struct {
  bool break_before_comment;
  uint32_t comment_end_column;
} Scanner;

void *tree_sitter_gossamer_external_scanner_create(void) {
  return ts_calloc(1, sizeof(Scanner));
}

void tree_sitter_gossamer_external_scanner_destroy(void *payload) { ts_free(payload); }

unsigned tree_sitter_gossamer_external_scanner_serialize(void *payload, char *buffer) {
  Scanner *scanner = payload;
  buffer[0] = (char)scanner->break_before_comment;
  memcpy(buffer + 1, &scanner->comment_end_column, sizeof(uint32_t));
  return 1 + sizeof(uint32_t);
}

void tree_sitter_gossamer_external_scanner_deserialize(void *payload, const char *buffer,
                                                       unsigned length) {
  Scanner *scanner = payload;
  scanner->break_before_comment = false;
  scanner->comment_end_column = 0;
  if (length == 1 + sizeof(uint32_t)) {
    scanner->break_before_comment = buffer[0] != 0;
    memcpy(&scanner->comment_end_column, buffer + 1, sizeof(uint32_t));
  }
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

  lexer->mark_end(lexer);
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

  lexer->mark_end(lexer);
  lexer->result_symbol = MULTILINE_STRING_LITERAL;
  return true;
}

// `r#"a "quoted" word"#` ends at the first `"` followed by as many `#` as
// opened it; the body has no escapes. `b` has already been read for the byte
// form.
static bool scan_raw_string(TSLexer *lexer, enum TokenType symbol) {
  if (lexer->lookahead != 'r') {
    return false;
  }
  lexer->advance(lexer, false);
  unsigned hashes = 0;
  while (lexer->lookahead == '#') {
    lexer->advance(lexer, false);
    hashes += 1;
  }
  if (lexer->lookahead != '"') {
    return false;
  }
  lexer->advance(lexer, false);

  while (!lexer->eof(lexer)) {
    int32_t current = lexer->lookahead;
    lexer->advance(lexer, false);
    if (current != '"') {
      continue;
    }
    unsigned closing = 0;
    while (closing < hashes && lexer->lookahead == '#') {
      lexer->advance(lexer, false);
      closing += 1;
    }
    if (closing == hashes) {
      break;
    }
  }

  lexer->mark_end(lexer);
  lexer->result_symbol = symbol;
  return true;
}

// A line break separates two elements only when another element follows it;
// before a closing delimiter, or a line that continues the expression above,
// the list has not moved on. The decision reads at most two characters, and
// leaves a `/` unread so a comment can still be lexed from it.
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
    // it. The language reads a leading `*`, `-`, or `!` as the start of a new
    // element, but `*%`, `-%`, and `!=` are binary operators.
    case '*':
    case '-':
      lexer->advance(lexer, true);
      return lexer->lookahead != '%';
    case '!':
      lexer->advance(lexer, true);
      return lexer->lookahead != '=';
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
  Scanner *scanner = payload;
  bool line_break = scanner->break_before_comment &&
                    lexer->get_column(lexer) == scanner->comment_end_column;
  scanner->break_before_comment = false;
  // The scanner runs before the whitespace extra is consumed, so this is
  // where a line break between two list elements is still visible.
  while (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
         lexer->lookahead == '\n' || lexer->lookahead == '\r') {
    line_break = line_break || lexer->lookahead == '\n';
    lexer->advance(lexer, true);
  }

  // Zero-width: the break stands in for the comma, it does not consume text.
  // Fixing the end here keeps the characters the peek below reads out of the
  // token.
  bool separator_valid = valid_symbols[LINE_SEPARATOR] && line_break;
  if (separator_valid) {
    lexer->mark_end(lexer);
    int32_t first = lexer->lookahead;
    if (element_follows(lexer)) {
      lexer->result_symbol = LINE_SEPARATOR;
      return true;
    }
    // Every other character has been read past, so the only token still
    // lexable from here is a comment, which `element_follows` leaves unread.
    if (first != '/') {
      return false;
    }
  }
  if (valid_symbols[MULTILINE_STRING_LITERAL] && lexer->lookahead == '"') {
    return scan_multiline_string(lexer);
  }
  if (valid_symbols[RAW_STRING_LITERAL] && lexer->lookahead == 'r') {
    return scan_raw_string(lexer, RAW_STRING_LITERAL);
  }
  if (valid_symbols[RAW_BYTE_STRING_LITERAL] && lexer->lookahead == 'b') {
    lexer->advance(lexer, false);
    return scan_raw_string(lexer, RAW_BYTE_STRING_LITERAL);
  }
  if (valid_symbols[BLOCK_COMMENT] && lexer->lookahead == '/') {
    if (!scan_block_comment(lexer)) {
      return false;
    }
    scanner->break_before_comment = separator_valid;
    scanner->comment_end_column = lexer->get_column(lexer);
    return true;
  }
  return false;
}
