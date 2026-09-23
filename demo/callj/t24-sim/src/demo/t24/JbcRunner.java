package demo.t24;

import java.io.IOException;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.function.Predicate;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Mini TAFJ/jBASE emulator: executes a subset of jBC (Infobasic) routines from a BP directory
 * and implements CALLJ with the same contract as TAFJ/jBASE:
 *
 * <pre>
 *   CALLJ packageAndClassName, [$]methodName, param SETTING ret [ON ERROR statements]
 * </pre>
 *
 * - "$" prefix on the method name means a public static method, otherwise an instance method
 *   invoked on an object created with the public no-arg constructor.
 * - The Java method must take one String and return a String.
 * - On failure the ON ERROR clause runs and SYSTEM(0) holds the error code:
 *   1 fatal error creating thread, 2 cannot create JVM, 3 cannot find class,
 *   4 unicode conversion error, 5 cannot find method, 6 cannot find object constructor,
 *   7 cannot instantiate object, 8 (simulator only) Java method threw an exception.
 *
 * Supported jBC subset: PROGRAM/SUBROUTINE, $INSERT/$USING (ignored), labels, GOSUB/RETURN,
 * STOP, CALL (by-reference args), assignment, CRT/PRINT, IF/THEN/ELSE (inline and block),
 * BEGIN CASE/CASE/END CASE, CALLJ (also accepts "RETURNING" instead of "SETTING"),
 * operators : + - * / = # <> < > <= >= EQ NE LT GT LE GE AND OR, substring X[s,l],
 * functions FIELD DCOUNT INDEX LEN TRIM UPCASE DOWNCASE CHANGE FMT STR NOT NUM SYSTEM
 * SQUOTE DQUOTE TIMEDATE, variables @FM @VM @SM @SENTENCE.
 *
 * Usage: java demo.t24.JbcRunner [--bp dir] PROGRAM.NAME [args...]
 */
public class JbcRunner {

    static final String FM = "\u00FE", VM = "\u00FD", SM = "\u00FC";
    static final boolean TRACE = Boolean.parseBoolean(System.getProperty("callj.trace", "true"));

    private final Path bpDir;
    private final Map<String, Routine> cache = new HashMap<>();
    private final String sentence;
    private String system0 = "0";

    public JbcRunner(Path bpDir, String sentence) {
        this.bpDir = bpDir;
        this.sentence = sentence;
    }

    public static void main(String[] args) {
        Path bp = Paths.get("BP");
        List<String> rest = new ArrayList<>();
        for (int i = 0; i < args.length; i++) {
            if ("--bp".equals(args[i]) && i + 1 < args.length) bp = Paths.get(args[++i]);
            else rest.add(args[i]);
        }
        if (rest.isEmpty()) {
            System.err.println("Usage: JbcRunner [--bp dir] PROGRAM.NAME [args...]");
            System.exit(2);
        }
        JbcRunner runner = new JbcRunner(bp, String.join(" ", rest));
        try {
            runner.run(rest.get(0));
        } catch (JbcError e) {
            System.err.println("** jBC RUNTIME ERROR: " + e.getMessage());
            System.exit(1);
        }
    }

    public void run(String programName) {
        Routine r = load(programName);
        Frame f = new Frame(r);
        try {
            exec(r.body, 0, f);
        } catch (StopSignal ignored) {
            // STOP ends the program
        }
    }

    // =====================================================================================
    // Loading / parsing
    // =====================================================================================

    private Routine load(String name) {
        return cache.computeIfAbsent(name, n -> {
            Path p = bpDir.resolve(n + ".b");
            if (!Files.exists(p)) p = bpDir.resolve(n);
            if (!Files.exists(p)) throw new JbcError("Routine " + n + " not found in " + bpDir.toAbsolutePath());
            try {
                return new Parser(n, Files.readAllLines(p, StandardCharsets.UTF_8)).parseRoutine();
            } catch (IOException e) {
                throw new JbcError("Cannot read " + p + ": " + e.getMessage());
            }
        });
    }

    static final class Routine {
        String name;
        boolean subroutine;
        List<String> params = new ArrayList<>();
        List<Stmt> body = new ArrayList<>();
        Map<String, Integer> labels = new HashMap<>();
    }

    record Tok(char type, String text) { // type: S=string N=number I=ident O=operator
        boolean is(String s) { return (type == 'I' || type == 'O') && text.equalsIgnoreCase(s); }
        public String toString() { return type == 'S' ? '"' + text + '"' : text; }
    }

    record Line(int no, List<Tok> toks) {
        boolean is(String... words) {
            if (toks.size() != words.length) return false;
            for (int i = 0; i < words.length; i++) if (!toks.get(i).is(words[i])) return false;
            return true;
        }
        boolean startsWith(String w) { return !toks.isEmpty() && toks.get(0).is(w); }
    }

    static final class Parser {
        private static final Pattern LABEL = Pattern.compile("^([A-Za-z0-9][A-Za-z0-9._$]*):(\\s.*)?$");
        final String name;
        final List<Line> lines = new ArrayList<>();
        int pos = 0;

        Parser(String name, List<String> src) {
            this.name = name;
            for (int i = 0; i < src.size(); i++) {
                for (String stmt : splitStatements(src.get(i))) {
                    Matcher m = LABEL.matcher(stmt);
                    if (m.matches() && !isKeyword(m.group(1))) {
                        lines.add(new Line(i + 1, List.of(new Tok('L', m.group(1)))));
                        stmt = m.group(2) == null ? "" : m.group(2).trim();
                        if (stmt.isEmpty()) continue;
                    }
                    lines.add(new Line(i + 1, tokenize(stmt, i + 1)));
                }
            }
        }

        private static boolean isKeyword(String w) {
            return Set.of("CRT", "PRINT", "IF", "CASE", "CALL", "CALLJ", "GOSUB").contains(w.toUpperCase());
        }

        /** Splits a physical line into statements on ';' and strips comments. */
        static List<String> splitStatements(String raw) {
            List<String> out = new ArrayList<>();
            String t = raw.trim();
            if (t.isEmpty() || t.startsWith("*") || t.startsWith("!") || t.toUpperCase().startsWith("REM ")) return out;
            StringBuilder cur = new StringBuilder();
            char q = 0;
            for (int i = 0; i < t.length(); i++) {
                char c = t.charAt(i);
                if (q != 0) {
                    if (c == q) q = 0;
                    cur.append(c);
                } else if (c == '"' || c == '\'') {
                    q = c;
                    cur.append(c);
                } else if (c == ';') {
                    if (!cur.toString().isBlank()) out.add(cur.toString().trim());
                    cur.setLength(0);
                    String after = t.substring(i + 1).trim();
                    if (after.startsWith("*") || after.startsWith("!")) return out; // ;* comment
                } else {
                    cur.append(c);
                }
            }
            if (!cur.toString().isBlank()) out.add(cur.toString().trim());
            return out;
        }

        static List<Tok> tokenize(String s, int lineNo) {
            List<Tok> toks = new ArrayList<>();
            int i = 0;
            while (i < s.length()) {
                char c = s.charAt(i);
                if (Character.isWhitespace(c)) { i++; continue; }
                if (c == '"' || c == '\'') {
                    int j = s.indexOf(c, i + 1);
                    if (j < 0) throw new JbcError("line " + lineNo + ": unterminated string");
                    toks.add(new Tok('S', s.substring(i + 1, j)));
                    i = j + 1;
                } else if (Character.isDigit(c)) {
                    int j = i;
                    while (j < s.length() && (Character.isDigit(s.charAt(j)) || s.charAt(j) == '.')) j++;
                    toks.add(new Tok('N', s.substring(i, j)));
                    i = j;
                } else if (Character.isLetter(c) || c == '$' || c == '@' || c == '_') {
                    int j = i + 1;
                    while (j < s.length() && (Character.isLetterOrDigit(s.charAt(j)) || ".$_@".indexOf(s.charAt(j)) >= 0)) j++;
                    toks.add(new Tok('I', s.substring(i, j)));
                    i = j;
                } else {
                    String two = i + 1 < s.length() ? s.substring(i, i + 2) : "";
                    if (two.equals("<=") || two.equals(">=") || two.equals("<>")) {
                        toks.add(new Tok('O', two));
                        i += 2;
                    } else if ("=#<>:+-*/(),[]".indexOf(c) >= 0) {
                        toks.add(new Tok('O', String.valueOf(c)));
                        i++;
                    } else {
                        throw new JbcError("line " + lineNo + ": unexpected character '" + c + "'");
                    }
                }
            }
            return toks;
        }

        Routine parseRoutine() {
            Routine r = new Routine();
            r.name = name;
            // header
            while (pos < lines.size()) {
                Line l = lines.get(pos);
                if (l.startsWith("PROGRAM")) { pos++; break; }
                if (l.startsWith("SUBROUTINE")) {
                    r.subroutine = true;
                    for (int i = 2; i < l.toks.size(); i++) {
                        Tok t = l.toks.get(i);
                        if (t.type == 'I') r.params.add(t.text.toUpperCase());
                    }
                    pos++;
                    break;
                }
                if (l.startsWith("$INSERT") || l.startsWith("$USING")) { pos++; continue; }
                break; // no header: treat as program
            }
            r.body = parseBlock(l -> l.is("END"));
            pos++; // final END (or EOF)
            for (int i = 0; i < r.body.size(); i++) {
                if (r.body.get(i) instanceof Label lb) r.labels.put(lb.name.toUpperCase(), i);
            }
            return r;
        }

        List<Stmt> parseBlock(Predicate<Line> stop) {
            List<Stmt> out = new ArrayList<>();
            while (pos < lines.size()) {
                Line l = lines.get(pos);
                if (stop.test(l)) return out;
                pos++;
                Stmt s = parseLine(l);
                if (s != null) out.add(s);
            }
            return out;
        }

        private Line expect(Predicate<Line> p, String what, int fromLine) {
            if (pos >= lines.size() || !p.test(lines.get(pos)))
                throw new JbcError(name + " line " + fromLine + ": missing " + what);
            return lines.get(pos++);
        }

        Stmt parseLine(Line l) {
            if (l.toks.isEmpty()) return null;
            Tok first = l.toks.get(0);
            if (first.type == 'L') return new Label(first.text, l.no);
            if (first.is("$INSERT") || first.is("$USING")) return null;
            if (first.is("IF")) return parseIf(new TS(l.toks, 1, l.no), l.no);
            if (first.is("BEGIN") && l.toks.size() == 2 && l.toks.get(1).is("CASE")) return parseCase(l.no);
            if (first.is("CALLJ")) return parseCallJ(new TS(l.toks, 1, l.no), l.no);
            return parseSimple(new TS(l.toks, 0, l.no));
        }

        Stmt parseIf(TS ts, int lineNo) {
            Expr cond = ts.expr();
            if (!ts.accept("THEN")) throw new JbcError(name + " line " + lineNo + ": IF without THEN");
            List<Stmt> thenB, elseB = List.of();
            if (ts.atEnd()) {
                thenB = parseBlock(x -> x.is("END") || x.is("END", "ELSE"));
                Line end = expect(x -> x.is("END") || x.is("END", "ELSE"), "END for IF", lineNo);
                if (end.is("END", "ELSE")) {
                    elseB = parseBlock(x -> x.is("END"));
                    expect(x -> x.is("END"), "END for ELSE", lineNo);
                }
            } else {
                int elseAt = ts.findTopLevel("ELSE");
                TS thenTs = ts.slice(ts.pos, elseAt < 0 ? ts.toks.size() : elseAt);
                thenB = List.of(parseInline(thenTs));
                if (elseAt >= 0) {
                    TS elseTs = ts.slice(elseAt + 1, ts.toks.size());
                    if (elseTs.atEnd()) {
                        elseB = parseBlock(x -> x.is("END"));
                        expect(x -> x.is("END"), "END for ELSE", lineNo);
                    } else {
                        elseB = List.of(parseInline(elseTs));
                    }
                }
            }
            return new If(cond, thenB, elseB);
        }

        Stmt parseCase(int lineNo) {
            List<Expr> conds = new ArrayList<>();
            List<List<Stmt>> bodies = new ArrayList<>();
            Predicate<Line> caseOrEnd = x -> x.is("END", "CASE") || (x.startsWith("CASE") && x.toks.size() > 1);
            parseBlock(caseOrEnd); // anything before first CASE is ignored
            while (pos < lines.size() && !lines.get(pos).is("END", "CASE")) {
                Line c = lines.get(pos++);
                TS ts = new TS(c.toks, 1, c.no);
                conds.add(ts.expr());
                bodies.add(parseBlock(caseOrEnd));
            }
            expect(x -> x.is("END", "CASE"), "END CASE", lineNo);
            return new Case(conds, bodies);
        }

        Stmt parseCallJ(TS ts, int lineNo) {
            Expr cls = ts.expr();
            ts.need(",");
            Expr meth = ts.expr();
            ts.need(",");
            Expr param = ts.expr();
            if (!ts.accept("SETTING") && !ts.accept("RETURNING"))
                throw new JbcError(name + " line " + lineNo + ": CALLJ needs SETTING <var>");
            String var = ts.ident();
            List<Stmt> onErr = List.of();
            if (ts.accept("ON")) {
                if (!ts.accept("ERROR")) throw new JbcError(name + " line " + lineNo + ": expected ON ERROR");
                if (ts.atEnd()) {
                    onErr = parseBlock(x -> x.is("END"));
                    expect(x -> x.is("END"), "END for ON ERROR", lineNo);
                } else {
                    onErr = List.of(parseInline(ts.slice(ts.pos, ts.toks.size())));
                }
            }
            return new CallJ(cls, meth, param, var, onErr, lineNo);
        }

        Stmt parseInline(TS ts) {
            if (ts.peekIs("CALLJ")) { ts.pos++; return parseCallJ(ts, ts.lineNo); }
            return parseSimple(ts);
        }

        Stmt parseSimple(TS ts) {
            Tok t = ts.peek();
            if (t == null) return null;
            if (t.is("CRT") || t.is("PRINT") || t.is("DISPLAY")) {
                ts.pos++;
                List<Expr> parts = new ArrayList<>();
                if (!ts.atEnd()) {
                    parts.add(ts.expr());
                    while (ts.accept(",")) parts.add(ts.expr());
                }
                ts.end();
                return new Crt(parts);
            }
            if (t.is("GOSUB")) { ts.pos++; String lb = ts.label(); ts.end(); return new Gosub(lb, ts.lineNo); }
            if (t.is("RETURN")) { ts.pos++; ts.end(); return new Return(); }
            if (t.is("STOP")) { ts.pos++; ts.end(); return new Stop(); }
            if (t.is("CALL")) {
                ts.pos++;
                String sub = ts.ident();
                List<Expr> args = new ArrayList<>();
                if (ts.accept("(")) {
                    if (!ts.accept(")")) {
                        args.add(ts.expr());
                        while (ts.accept(",")) args.add(ts.expr());
                        ts.need(")");
                    }
                }
                ts.end();
                return new Call(sub, args, ts.lineNo);
            }
            if (t.type == 'I' && ts.toks.size() > ts.pos + 1 && ts.toks.get(ts.pos + 1).is("=")) {
                String var = t.text.toUpperCase();
                ts.pos += 2;
                Expr e = ts.expr();
                ts.end();
                return new Assign(var, e);
            }
            throw new JbcError(name + " line " + ts.lineNo + ": unsupported statement: " + ts.toks);
        }
    }

    /** Token stream + recursive-descent expression parser. */
    static final class TS {
        final List<Tok> toks;
        int pos;
        final int lineNo;
        static final Set<String> FUNCS = Set.of("FIELD", "DCOUNT", "INDEX", "LEN", "TRIM", "UPCASE", "DOWNCASE",
                "CHANGE", "FMT", "STR", "NOT", "NUM", "SYSTEM", "SQUOTE", "DQUOTE", "TIMEDATE");
        static final Set<String> RESERVED = Set.of("THEN", "ELSE", "SETTING", "RETURNING", "ON", "ERROR", "AND", "OR",
                "EQ", "NE", "LT", "GT", "LE", "GE");

        TS(List<Tok> toks, int pos, int lineNo) { this.toks = toks; this.pos = pos; this.lineNo = lineNo; }

        TS slice(int from, int to) { return new TS(toks.subList(from, to), 0, lineNo); }
        boolean atEnd() { return pos >= toks.size(); }
        Tok peek() { return atEnd() ? null : toks.get(pos); }
        boolean peekIs(String s) { return !atEnd() && toks.get(pos).is(s); }
        boolean accept(String s) { if (peekIs(s)) { pos++; return true; } return false; }
        void need(String s) { if (!accept(s)) throw err("expected '" + s + "'"); }
        void end() { if (!atEnd()) throw err("unexpected '" + peek() + "'"); }
        JbcError err(String m) { return new JbcError("line " + lineNo + ": " + m + " in " + toks); }

        String ident() {
            Tok t = peek();
            if (t == null || t.type != 'I') throw err("expected identifier");
            pos++;
            return t.text.toUpperCase();
        }

        String label() {
            Tok t = peek();
            if (t == null || (t.type != 'I' && t.type != 'N')) throw err("expected label");
            pos++;
            return t.text.toUpperCase();
        }

        int findTopLevel(String word) {
            int depth = 0;
            for (int i = pos; i < toks.size(); i++) {
                Tok t = toks.get(i);
                if (t.is("(") || t.is("[")) depth++;
                else if (t.is(")") || t.is("]")) depth--;
                else if (depth == 0 && t.type == 'I' && t.is(word)) return i;
            }
            return -1;
        }

        Expr expr() { return or(); }

        Expr or() {
            Expr l = and();
            while (accept("OR")) { Expr r = and(); Expr a = l; l = f -> truth(a.eval(f)) || truth(r.eval(f)) ? "1" : "0"; }
            return l;
        }

        Expr and() {
            Expr l = rel();
            while (accept("AND")) { Expr r = rel(); Expr a = l; l = f -> truth(a.eval(f)) && truth(r.eval(f)) ? "1" : "0"; }
            return l;
        }

        Expr rel() {
            Expr l = concat();
            Tok t = peek();
            if (t == null) return l;
            String op = switch (t.text.toUpperCase()) {
                case "=", "EQ" -> "=";
                case "#", "<>", "NE" -> "#";
                case "<", "LT" -> "<";
                case ">", "GT" -> ">";
                case "<=", "LE" -> "<=";
                case ">=", "GE" -> ">=";
                default -> null;
            };
            if (op == null || t.type == 'S') return l;
            pos++;
            Expr r = concat();
            Expr a = l;
            return f -> {
                int c = compare(a.eval(f), r.eval(f));
                boolean res = switch (op) {
                    case "=" -> c == 0;
                    case "#" -> c != 0;
                    case "<" -> c < 0;
                    case ">" -> c > 0;
                    case "<=" -> c <= 0;
                    default -> c >= 0;
                };
                return res ? "1" : "0";
            };
        }

        Expr concat() {
            Expr l = add();
            while (accept(":")) { Expr r = add(); Expr a = l; l = f -> a.eval(f) + r.eval(f); }
            return l;
        }

        Expr add() {
            Expr l = mul();
            while (peekIs("+") || peekIs("-")) {
                boolean plus = toks.get(pos++).is("+");
                Expr r = mul();
                Expr a = l;
                l = f -> fmtNum(plus ? num(a.eval(f)).add(num(r.eval(f))) : num(a.eval(f)).subtract(num(r.eval(f))));
            }
            return l;
        }

        Expr mul() {
            Expr l = unary();
            while (peekIs("*") || peekIs("/")) {
                boolean times = toks.get(pos++).is("*");
                Expr r = unary();
                Expr a = l;
                l = f -> fmtNum(times ? num(a.eval(f)).multiply(num(r.eval(f)))
                        : num(a.eval(f)).divide(num(r.eval(f)), 10, java.math.RoundingMode.HALF_UP));
            }
            return l;
        }

        Expr unary() {
            if (accept("-")) { Expr e = unary(); return f -> fmtNum(num(e.eval(f)).negate()); }
            Expr p = primary();
            while (accept("[")) { // substring X[start,len]
                Expr s = expr();
                need(",");
                Expr n = expr();
                need("]");
                Expr base = p;
                p = f -> {
                    String v = base.eval(f);
                    int st = Math.max(1, num(s.eval(f)).intValue()), ln = num(n.eval(f)).intValue();
                    if (st > v.length() || ln <= 0) return "";
                    return v.substring(st - 1, Math.min(v.length(), st - 1 + ln));
                };
            }
            return p;
        }

        Expr primary() {
            Tok t = peek();
            if (t == null) throw err("unexpected end of expression");
            pos++;
            switch (t.type) {
                case 'S', 'N': { String v = t.text; return f -> v; }
                case 'O':
                    if (t.is("(")) { Expr e = expr(); need(")"); return e; }
                    throw err("unexpected '" + t.text + "'");
                default:
            }
            String id = t.text.toUpperCase();
            if (RESERVED.contains(id)) throw err("unexpected keyword " + id);
            if (peekIs("(") && FUNCS.contains(id)) {
                pos++;
                List<Expr> args = new ArrayList<>();
                if (!accept(")")) {
                    args.add(expr());
                    while (accept(",")) args.add(expr());
                    need(")");
                }
                return f -> f.runner().callFunction(id, args, f);
            }
            switch (id) {
                case "@FM": return f -> FM;
                case "@VM": return f -> VM;
                case "@SM": return f -> SM;
                case "@SENTENCE": return f -> f.runner().sentence;
                default: return new Var(id);
            }
        }
    }

    // =====================================================================================
    // AST
    // =====================================================================================

    interface Expr { String eval(Frame f); }
    record Var(String name) implements Expr { public String eval(Frame f) { return f.vars.getOrDefault(name, ""); } }

    interface Stmt {}
    record Label(String name, int line) implements Stmt {}
    record Assign(String var, Expr e) implements Stmt {}
    record Crt(List<Expr> parts) implements Stmt {}
    record If(Expr cond, List<Stmt> thenB, List<Stmt> elseB) implements Stmt {}
    record Case(List<Expr> conds, List<List<Stmt>> bodies) implements Stmt {}
    record Gosub(String label, int line) implements Stmt {}
    record Return() implements Stmt {}
    record Stop() implements Stmt {}
    record Call(String name, List<Expr> args, int line) implements Stmt {}
    record CallJ(Expr cls, Expr method, Expr param, String var, List<Stmt> onError, int line) implements Stmt {}

    // =====================================================================================
    // Execution
    // =====================================================================================

    final class Frame {
        final Routine routine;
        final Map<String, String> vars = new HashMap<>();
        Frame(Routine r) { routine = r; }
        JbcRunner runner() { return JbcRunner.this; }
    }

    enum Sig { NORMAL, RETURN }
    static final class StopSignal extends RuntimeException { StopSignal() { super(null, null, false, false); } }
    static final class JbcError extends RuntimeException { JbcError(String m) { super(m); } }

    private Sig exec(List<Stmt> block, int start, Frame f) {
        for (int i = start; i < block.size(); i++) {
            if (execOne(block.get(i), f) == Sig.RETURN) return Sig.RETURN;
        }
        return Sig.NORMAL;
    }

    private Sig execOne(Stmt s, Frame f) {
        if (s instanceof Label) return Sig.NORMAL;
        if (s instanceof Assign a) { f.vars.put(a.var(), a.e().eval(f)); return Sig.NORMAL; }
        if (s instanceof Crt c) {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < c.parts().size(); i++) sb.append(i > 0 ? " " : "").append(c.parts().get(i).eval(f));
            System.out.println(sb.toString().replace(FM, "^").replace(VM, "]").replace(SM, "\\"));
            return Sig.NORMAL;
        }
        if (s instanceof If i) return exec(truth(i.cond().eval(f)) ? i.thenB() : i.elseB(), 0, f);
        if (s instanceof Case c) {
            for (int i = 0; i < c.conds().size(); i++) {
                if (truth(c.conds().get(i).eval(f))) return exec(c.bodies().get(i), 0, f);
            }
            return Sig.NORMAL;
        }
        if (s instanceof Gosub g) {
            Integer idx = f.routine.labels.get(g.label());
            if (idx == null) throw new JbcError(f.routine.name + " line " + g.line() + ": label " + g.label() + " not found");
            exec(f.routine.body, idx + 1, f);
            return Sig.NORMAL;
        }
        if (s instanceof Return) return Sig.RETURN;
        if (s instanceof Stop) throw new StopSignal();
        if (s instanceof Call c) { doCall(c, f); return Sig.NORMAL; }
        if (s instanceof CallJ cj) return doCallJ(cj, f);
        throw new JbcError("unknown statement " + s);
    }

    private void doCall(Call c, Frame caller) {
        Routine r = load(c.name());
        if (!r.subroutine) throw new JbcError(c.name() + " is not a SUBROUTINE");
        Frame f = new Frame(r);
        for (int i = 0; i < r.params.size(); i++) {
            f.vars.put(r.params.get(i), i < c.args().size() ? c.args().get(i).eval(caller) : "");
        }
        exec(r.body, 0, f);
        for (int i = 0; i < Math.min(r.params.size(), c.args().size()); i++) {
            if (c.args().get(i) instanceof Var v) caller.vars.put(v.name(), f.vars.getOrDefault(r.params.get(i), ""));
        }
    }

    /** CALLJ implementation, mirrors the TAFJ/jBASE behaviour described in the class Javadoc. */
    private Sig doCallJ(CallJ cj, Frame f) {
        String className = cj.cls().eval(f);
        String methodSpec = cj.method().eval(f);
        String param = cj.param().eval(f);
        boolean isStatic = methodSpec.startsWith("$");
        String methodName = isStatic ? methodSpec.substring(1) : methodSpec;

        trace(">> CALLJ " + className + " " + methodSpec + " \"" + param + "\"");
        long t0 = System.nanoTime();
        int code;
        String result = "";
        String detail;
        try {
            Class<?> cls;
            try {
                cls = Class.forName(className, true, Thread.currentThread().getContextClassLoader());
            } catch (ClassNotFoundException e) {
                throw new CallJFailure(3, "Cannot find class " + className);
            } catch (LinkageError e) {
                Throwable root = e;
                while (root.getCause() != null) root = root.getCause();
                throw new CallJFailure(3, "Cannot load class " + className + " (" + root + ") - check classpath");
            }
            Method m;
            try {
                m = cls.getMethod(methodName, String.class);
            } catch (NoSuchMethodException e) {
                throw new CallJFailure(5, "Cannot find method " + methodName + "(String)");
            }
            if (isStatic != Modifier.isStatic(m.getModifiers())) {
                throw new CallJFailure(5, "Method " + methodName + (isStatic ? " is not static" : " is static (prefix with $)"));
            }
            Object target = null;
            if (!isStatic) {
                Constructor<?> ctor;
                try {
                    ctor = cls.getConstructor();
                } catch (NoSuchMethodException e) {
                    throw new CallJFailure(6, "Cannot find public no-arg constructor");
                }
                try {
                    target = ctor.newInstance();
                } catch (ReflectiveOperationException e) {
                    throw new CallJFailure(7, "Cannot instantiate " + className + ": " + e);
                }
            }
            try {
                Object r = m.invoke(target, param);
                result = r == null ? "" : r.toString();
            } catch (InvocationTargetException e) {
                throw new CallJFailure(8, "Java exception: " + e.getCause());
            } catch (IllegalAccessException e) {
                throw new CallJFailure(5, "Method not accessible: " + e.getMessage());
            }
            code = 0;
            detail = "OK";
        } catch (CallJFailure e) {
            code = e.code;
            detail = e.getMessage();
        }
        long ms = (System.nanoTime() - t0) / 1_000_000;
        system0 = String.valueOf(code);
        if (code == 0) {
            f.vars.put(cj.var(), result);
            trace("<< CALLJ returned (" + ms + " ms): \"" + result + "\"");
            return Sig.NORMAL;
        }
        trace("<< CALLJ FAILED, SYSTEM(0)=" + code + " : " + detail);
        return exec(cj.onError(), 0, f);
    }

    static final class CallJFailure extends Exception {
        final int code;
        CallJFailure(int code, String msg) { super(msg); this.code = code; }
    }

    private static void trace(String msg) {
        if (TRACE) System.out.println("   [TAFJ-SIM] " + msg);
    }

    // =====================================================================================
    // Built-in functions & value helpers
    // =====================================================================================

    String callFunction(String name, List<Expr> a, Frame f) {
        List<String> v = new ArrayList<>();
        for (Expr e : a) v.add(e.eval(f));
        switch (name) {
            case "FIELD": {
                String[] parts = v.get(0).split(Pattern.quote(v.get(1)), -1);
                int start = num(v.get(2)).intValue(), cnt = v.size() > 3 ? num(v.get(3)).intValue() : 1;
                if (start < 1 || start > parts.length) return "";
                return String.join(v.get(1), Arrays.copyOfRange(parts, start - 1, Math.min(parts.length, start - 1 + cnt)));
            }
            case "DCOUNT": return v.get(0).isEmpty() ? "0" : String.valueOf(v.get(0).split(Pattern.quote(v.get(1)), -1).length);
            case "INDEX": {
                int occ = v.size() > 2 ? num(v.get(2)).intValue() : 1, idx = -1;
                for (int i = 0; i < occ; i++) { idx = v.get(0).indexOf(v.get(1), idx + 1); if (idx < 0) return "0"; }
                return String.valueOf(idx + 1);
            }
            case "LEN": return String.valueOf(v.get(0).length());
            case "TRIM": return v.get(0).trim().replaceAll(" +", " ");
            case "UPCASE": return v.get(0).toUpperCase();
            case "DOWNCASE": return v.get(0).toLowerCase();
            case "CHANGE": return v.get(0).replace(v.get(1), v.get(2));
            case "STR": return v.get(0).repeat(Math.max(0, num(v.get(1)).intValue()));
            case "NOT": return truth(v.get(0)) ? "0" : "1";
            case "NUM": return isNum(v.get(0)) || v.get(0).isEmpty() ? "1" : "0";
            case "SQUOTE": return "'" + v.get(0) + "'";
            case "DQUOTE": return "\"" + v.get(0) + "\"";
            case "SYSTEM": return num(v.get(0)).intValue() == 0 ? system0 : "";
            case "TIMEDATE": return LocalDateTime.now().format(DateTimeFormatter.ofPattern("HH:mm:ss dd MMM yyyy", Locale.ENGLISH)).toUpperCase();
            case "FMT": {
                Matcher m = Pattern.compile("([LR])#(\\d+)").matcher(v.get(1));
                if (!m.matches()) return v.get(0);
                int w = Integer.parseInt(m.group(2));
                String s = v.get(0).length() > w ? v.get(0).substring(0, w) : v.get(0);
                return m.group(1).equals("L") ? String.format("%-" + w + "s", s) : String.format("%" + w + "s", s);
            }
            default: throw new JbcError("function " + name + " not supported");
        }
    }

    static boolean isNum(String s) {
        return s.matches("-?\\d+(\\.\\d+)?");
    }

    static BigDecimal num(String s) {
        return isNum(s.trim()) ? new BigDecimal(s.trim()) : BigDecimal.ZERO;
    }

    static String fmtNum(BigDecimal d) {
        d = d.stripTrailingZeros();
        return d.scale() <= 0 ? d.toBigInteger().toString() : d.toPlainString();
    }

    static boolean truth(String s) {
        if (s.isEmpty()) return false;
        return !isNum(s) || num(s).signum() != 0;
    }

    static int compare(String a, String b) {
        if (isNum(a) && isNum(b)) return num(a).compareTo(num(b));
        return a.compareTo(b);
    }
}
