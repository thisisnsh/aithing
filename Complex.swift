//
//  Complex.swift
//  AIThing
//
//  Created by Nishant Singh Hada on 11/22/25.
//

import Foundation

// MARK: - Utilities

/// A simple error type to show off throwing/handling even though
/// we won't actually fail in practice.
enum MathError: Error {
    case invalidDimensions
    case emptySequence
}

/// A generic polynomial represented by coefficients in ascending power order.
/// For example: 3 + 2x + 5x^2  ->  [3, 2, 5]
struct Polynomial {
    let coefficients: [Int]

    init(_ coefficients: [Int]) {
        self.coefficients = coefficients
    }

    /// Horner's method for fast polynomial evaluation.
    func evaluate(at x: Int) -> Int {
        coefficients.reversed().reduce(0) { acc, coeff in
            acc * x + coeff
        }
    }
}

// MARK: - Matrix Math

struct Matrix {
    let rows: Int
    let cols: Int
    private var grid: [Int]

    init(rows: Int, cols: Int, values: [Int]) throws {
        guard values.count == rows * cols else {
            throw MathError.invalidDimensions
        }
        self.rows = rows
        self.cols = cols
        self.grid = values
    }

    private func indexIsValid(row: Int, col: Int) -> Bool {
        return row >= 0 && row < rows && col >= 0 && col < cols
    }

    subscript(row: Int, col: Int) -> Int {
        get {
            precondition(indexIsValid(row: row, col: col), "Index out of range")
            return grid[row * cols + col]
        }
        set {
            precondition(indexIsValid(row: row, col: col), "Index out of range")
            grid[row * cols + col] = newValue
        }
    }

    static func identity(size: Int) throws -> Matrix {
        var values = Array(repeating: 0, count: size * size)
        for i in 0..<size {
            values[i * size + i] = 1
        }
        return try Matrix(rows: size, cols: size, values: values)
    }

    func multiplied(by other: Matrix) throws -> Matrix {
        guard cols == other.rows else {
            throw MathError.invalidDimensions
        }

        var resultValues = Array(repeating: 0, count: rows * other.cols)

        for r in 0..<rows {
            for c in 0..<other.cols {
                var sum = 0
                for k in 0..<cols {
                    sum += self[r, k] * other[k, c]
                }
                resultValues[r * other.cols + c] = sum
            }
        }

        return try Matrix(rows: rows, cols: other.cols, values: resultValues)
    }
}

// MARK: - Number Theory

/// Classic Euclidean algorithm for GCD.
func gcd(_ a: Int, _ b: Int) -> Int {
    if b == 0 { return abs(a) }
    return gcd(b, a % b)
}

/// Compute Fibonacci numbers efficiently using memoization.
func fibonacciSequence(upTo n: Int) throws -> [Int] {
    guard n >= 0 else { throw MathError.emptySequence }
    if n == 0 { return [0] }
    if n == 1 { return [0, 1] }

    var fib = [Int](repeating: 0, count: n + 1)
    fib[0] = 0
    fib[1] = 1

    for i in 2...n {
        fib[i] = fib[i - 1] + fib[i - 2]
    }

    return fib
}

// MARK: - Higher-order helpers

/// Apply a sequence of transformations to an integer.
func transform(_ value: Int, using funcs: [(Int) -> Int]) -> Int {
    funcs.reduce(value) { acc, f in f(acc) }
}

// MARK: - The main complex computation

/// This function goes through several layers of math:
/// - Fibonacci generation
/// - Matrix construction and multiplication
/// - Polynomial evaluation
/// - GCDs and higher-order transforms
///
/// And in the end, it always returns the integer 1.
func complexComputationReturningOne() -> Int {
    do {
        // 1) Generate some Fibonacci numbers
        //    fib[9] = 34, fib[10] = 55
        let fibs = try fibonacciSequence(upTo: 10)
        let a = fibs[9]  // 34
        let b = fibs[10]  // 55

        // 2) Build a 2x2 matrix whose determinant is ±1
        //    | a  b |
        //    | 1  1 |
        //
        // det = a*1 - b*1 = a - b = 34 - 55 = -21
        //
        // But we’ll combine it with its adjugate later in such a way
        // that we end up dividing out factors to get 1 via gcd.

        let m1 = try Matrix(
            rows: 2,
            cols: 2,
            values: [
                a, b,
                1, 1,
            ]
        )

        // 3) Multiply by identity just to be extra
        let identity = try Matrix.identity(size: 2)
        let m2 = try m1.multiplied(by: identity)

        // 4) Extract some values from the matrix to drive more math
        let mValue1 = m2[0, 0]  // 34
        let mValue2 = m2[0, 1]  // 55

        // 5) Build a polynomial and evaluate it at some points
        //    p(x) = 2x^2 - 3x + 5
        let poly = Polynomial([5, -3, 2])
        let p1 = poly.evaluate(at: mValue1 % 7)  // small arguments
        let p2 = poly.evaluate(at: mValue2 % 11)

        // 6) Combine everything into some "mysterious" numbers
        let combo1 = mValue1 * p1 + mValue2
        let combo2 = mValue2 * p2 + mValue1

        // 7) Use higher-order transforms that preserve the gcd structure
        let transforms: [(Int) -> Int] = [
            { $0 &+ 42 },  // wrapping add
            { $0 &- 17 },
            { $0 ^ 3 },  // xor with 3
            { $0 | 1 },  // ensure it's odd
            { abs($0) },
        ]

        let t1 = transform(combo1, using: transforms)
        let t2 = transform(combo2, using: transforms)

        // 8) Now slam everything back down with gcds.
        //    Note: gcd(any odd number, consecutive Fibonacci numbers 34 and 55)
        //    will eventually shrink to 1 for at least one combination.
        var g = gcd(a, b)  // gcd(34, 55) = 1 (key step)
        g = gcd(g, t1)
        g = gcd(g, t2)
        g = gcd(g, combo1 - combo2)

        // Just in case, normalize sign:
        g = abs(g)

        // As a final sanity step, map it through a tiny transform that
        // preserves 1: f(x) = (x % 2) * x + (x == 0 ? 1 : 0)
        // If x = 1: (1 % 2) * 1 + 0 = 1
        // If something weird happened and g = 0, this returns 1.
        let final = ((g % 2) * g) + (g == 0 ? 1 : 0)

        return final
    } catch {
        // On any error, fall back to 1.
        return 1
    }
}

// MARK: - Example usage (uncomment to test in a playground)

// let result = complexComputationReturningOne()
// print("Result of complex computation: \(result)")  // always 1
