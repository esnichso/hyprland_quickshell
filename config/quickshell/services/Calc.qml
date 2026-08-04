// The launcher's `=` mode: an arithmetic expression evaluator.
//
// Hand-written recursive descent, not eval(). eval() on a string the user is
// still typing is a script injection surface in a process that owns the
// notification daemon and the system tray; a parser that only knows about
// numbers cannot be talked into doing anything else.
//
// SCOPE: numbers, + - * / % ^, parentheses, unary +/-, a fixed set of
// functions, and pi/e/tau. FEATURES.md §4 says "units-aware" — unit conversion
// is NOT implemented and is listed in ROADMAP.md as a follow-up. Everything
// this does handle, it handles exactly.
//
// The tokenizer scans by hand rather than with a sticky regex: Qt's JS engine
// support for the /y flag is not something this repo can verify locally.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // { ok, value, text, error }. error is "" for an empty input, so a bare "="
    // renders as nothing rather than as a complaint.
    function evaluate(src) {
        const s = String(src === undefined || src === null ? "" : src);
        if (s.trim() === "")
            return { ok: false, value: 0, text: "", error: "" };

        let i = 0;

        function ws() {
            while (i < s.length && (s.charAt(i) === " " || s.charAt(i) === "\t"))
                i += 1;
        }

        function peek() {
            ws();
            return i < s.length ? s.charAt(i) : "";
        }

        function eat(ch) {
            if (peek() === ch) {
                i += 1;
                return true;
            }
            return false;
        }

        function isDigit(c) {
            return c >= "0" && c <= "9";
        }

        function isAlpha(c) {
            return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z");
        }

        function number() {
            const start = i;
            while (i < s.length && isDigit(s.charAt(i)))
                i += 1;
            if (s.charAt(i) === ".") {
                i += 1;
                while (i < s.length && isDigit(s.charAt(i)))
                    i += 1;
            }
            if (i === start)
                throw "expected a number";

            // Exponent, but only if it is actually followed by digits, so a
            // half-typed "1e" is rejected as an unfinished expression rather
            // than silently read as 1.
            if (s.charAt(i) === "e" || s.charAt(i) === "E") {
                const save = i;
                i += 1;
                if (s.charAt(i) === "+" || s.charAt(i) === "-")
                    i += 1;
                if (isDigit(s.charAt(i))) {
                    while (i < s.length && isDigit(s.charAt(i)))
                        i += 1;
                } else {
                    i = save;
                }
            }
            return parseFloat(s.slice(start, i));
        }

        function identifier() {
            const start = i;
            while (i < s.length && isAlpha(s.charAt(i)))
                i += 1;
            return s.slice(start, i).toLowerCase();
        }

        function primary() {
            if (eat("(")) {
                const v = additive();
                if (!eat(")"))
                    throw "missing )";
                return v;
            }

            const c = peek();
            if (isDigit(c) || c === ".")
                return number();

            if (isAlpha(c)) {
                ws();
                const name = identifier();
                if (peek() === "(") {
                    eat("(");
                    const arg = additive();
                    if (!eat(")"))
                        throw "missing )";
                    return root.call(name, arg);
                }
                return root.constant(name);
            }
            if (c === "")
                throw "unfinished expression";
            throw `unexpected "${c}"`;
        }

        // Right-associative, so 2^3^2 is 512 like every calculator. The right
        // operand is a unary, which is what makes 2^-3 parse.
        function power() {
            const base = primary();
            if (eat("^"))
                return Math.pow(base, unary());
            return base;
        }

        // Unary sits ABOVE power, not inside primary: -2^2 is -4, the way bc,
        // Python and every pocket calculator read it. Folding the sign into the
        // base instead would quietly answer 4.
        function unary() {
            if (eat("-"))
                return -unary();
            if (eat("+"))
                return unary();
            return power();
        }

        function multiplicative() {
            let v = unary();
            for (;;) {
                if (eat("*"))
                    v = v * unary();
                else if (eat("/"))
                    v = v / unary();
                else if (eat("%"))
                    v = v % unary();
                else
                    return v;
            }
        }

        function additive() {
            let v = multiplicative();
            for (;;) {
                if (eat("+"))
                    v = v + multiplicative();
                else if (eat("-"))
                    v = v - multiplicative();
                else
                    return v;
            }
        }

        try {
            const v = additive();
            ws();
            if (i < s.length)
                throw `unexpected "${s.charAt(i)}"`;
            return { ok: true, value: v, text: format(v), error: "" };
        } catch (e) {
            return { ok: false, value: 0, text: "", error: String(e) };
        }
    }

    function constant(name) {
        if (name === "pi")
            return Math.PI;
        if (name === "e")
            return Math.E;
        if (name === "tau")
            return Math.PI * 2;
        throw `unknown name "${name}"`;
    }

    // A switch rather than a table of function references: storing native
    // functions on a QML `var` property is one more thing that would only fail
    // in the VM.
    function call(name, x) {
        switch (name) {
        case "sqrt": return Math.sqrt(x);
        case "abs": return Math.abs(x);
        case "floor": return Math.floor(x);
        case "ceil": return Math.ceil(x);
        case "round": return Math.round(x);
        case "ln": return Math.log(x);
        case "log": return Math.log(x) / Math.LN10;
        case "exp": return Math.exp(x);
        case "sin": return Math.sin(x);
        case "cos": return Math.cos(x);
        case "tan": return Math.tan(x);
        case "asin": return Math.asin(x);
        case "acos": return Math.acos(x);
        case "atan": return Math.atan(x);
        }
        throw `unknown function "${name}"`;
    }

    function format(v) {
        if (isNaN(v))
            return "not a number";
        if (!isFinite(v))
            return v > 0 ? "∞" : "-∞";

        // Kill the floating-point tail: 45 * 1.19 must read 53.55, not
        // 53.550000000000004.
        const r = Math.round(v * 1e10) / 1e10;
        if (r === Math.floor(r) && Math.abs(r) < 1e15)
            return String(r);
        return String(parseFloat(r.toPrecision(12)));
    }
}
