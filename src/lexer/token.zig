const std = @import("std");

pub const TokenType = enum {
    Identifier,
    Integer,
    Float,
    String,
    FString,
    Plus, Minus, Star, StarStar, Slash, SlashSlash, Percent,
    Eq, EqEq, BangEq, PlusEq, MinusEq, StarEq, SlashEq, PercentEq, Lt, Gt, LtEq, GtEq, LtLt, GtGt,
    Pipe, Caret, Ampersand, Tilde,
    Colon, Comma, Dot, At,
    Ellipsis,
    ColonEq,
    LParen, RParen,
    LBracket, RBracket,
    LBrace, RBrace,
    Indent, Dedent, Newline,
    KeywordIf, KeywordWith, KeywordElif, KeywordElse, KeywordWhile, KeywordFor, KeywordDef, KeywordClass, KeywordLambda,
    KeywordDel,
    KeywordNonlocal,
    KeywordReturn, KeywordImport, KeywordFrom, KeywordContinue, KeywordBreak, KeywordPass,
    KeywordTrue, KeywordFalse, KeywordNone, KeywordYield, KeywordIn,
    KeywordIs,
    KeywordAnd, KeywordOr, KeywordNot, KeywordGlobal, KeywordConst,
    KeywordAssert,
    KeywordTry, KeywordExcept, KeywordFinally, KeywordRaise,
    KeywordMatch, KeywordCase, KeywordAs, KeywordAsync, KeywordAwait,
    Semicolon,
    DirectiveStrict,
    EOF,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
};
