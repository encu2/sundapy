const std = @import("std");
const token_mod = @import("token.zig");
const TokenType = token_mod.TokenType;

pub fn matchKeyword(lexeme: []const u8) TokenType {
    if (std.mem.eql(u8, lexeme, "if")) return .KeywordIf;
    if (std.mem.eql(u8, lexeme, "elif")) return .KeywordElif;
    if (std.mem.eql(u8, lexeme, "else")) return .KeywordElse;
    if (std.mem.eql(u8, lexeme, "lambda")) return .KeywordLambda;
    if (std.mem.eql(u8, lexeme, "while")) return .KeywordWhile;
    if (std.mem.eql(u8, lexeme, "for")) return .KeywordFor;
    if (std.mem.eql(u8, lexeme, "def")) return .KeywordDef;
    if (std.mem.eql(u8, lexeme, "class")) return .KeywordClass;
    if (std.mem.eql(u8, lexeme, "return")) return .KeywordReturn;
    if (std.mem.eql(u8, lexeme, "import")) return .KeywordImport;
    if (std.mem.eql(u8, lexeme, "from")) return .KeywordFrom;
    if (std.mem.eql(u8, lexeme, "continue")) return .KeywordContinue;
    if (std.mem.eql(u8, lexeme, "break")) return .KeywordBreak;
    if (std.mem.eql(u8, lexeme, "pass")) return .KeywordPass;
    if (std.mem.eql(u8, lexeme, "True")) return .KeywordTrue;
    if (std.mem.eql(u8, lexeme, "False")) return .KeywordFalse;
    if (std.mem.eql(u8, lexeme, "None")) return .KeywordNone;
    if (std.mem.eql(u8, lexeme, "yield")) return .KeywordYield;
    if (std.mem.eql(u8, lexeme, "in")) return .KeywordIn;
    if (std.mem.eql(u8, lexeme, "and")) return .KeywordAnd;
    if (std.mem.eql(u8, lexeme, "or")) return .KeywordOr;
    if (std.mem.eql(u8, lexeme, "not")) return .KeywordNot;
    if (std.mem.eql(u8, lexeme, "global")) return .KeywordGlobal;
    if (std.mem.eql(u8, lexeme, "const")) return .KeywordConst;
    if (std.mem.eql(u8, lexeme, "try")) return .KeywordTry;
    if (std.mem.eql(u8, lexeme, "except")) return .KeywordExcept;
    if (std.mem.eql(u8, lexeme, "finally")) return .KeywordFinally;
    if (std.mem.eql(u8, lexeme, "raise")) return .KeywordRaise;
    if (std.mem.eql(u8, lexeme, "match")) return .KeywordMatch;
    if (std.mem.eql(u8, lexeme, "case")) return .KeywordCase;
    if (std.mem.eql(u8, lexeme, "as")) return .KeywordAs;
    return .Identifier;
}
