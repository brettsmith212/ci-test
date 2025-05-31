class Calculator {
  add(a, b) {
    return a + b;
  }

  subtract(a, b) {
    return a - b;
  }

  multiply(a, b) {
    return a * b;
  }

  divide(a, b) {
    if (b === 0) {
      throw new Error('Division by zero');
    }
    return a / b;
  }

  // Intentionally buggy function for demo
  power(base, exponent) {
    if (exponent === 0) return 1;
    if (exponent === 1) return base;
    return base * this.power(base, exponent - 1);
  }
}

module.exports = Calculator;
