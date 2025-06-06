const { expect } = require('chai');
const Calculator = require('../src/calculator');

describe('Calculator', () => {
  let calc;

  beforeEach(() => {
    calc = new Calculator();
  });

  describe('add', () => {
    it('should add two positive numbers', () => {
      expect(calc.add(2, 3)).to.equal(5);
    });

    it('should add negative numbers', () => {
      expect(calc.add(-2, -3)).to.equal(-5);
    });
  });

  describe('subtract', () => {
    it('should subtract two numbers', () => {
      expect(calc.subtract(5, 3)).to.equal(2);
    });
  });

  describe('multiply', () => {
    it('should multiply two numbers', () => {
      expect(calc.multiply(4, 5)).to.equal(20);
    });
  });

  describe('divide', () => {
    it('should divide two numbers', () => {
      expect(calc.divide(10, 2)).to.equal(5);
    });

    it('should throw error for division by zero', () => {
      expect(() => calc.divide(10, 0)).to.throw('Division by zero');
    });
  });

  describe('power', () => {
    it('should calculate power correctly', () => {
      expect(calc.power(2, 3)).to.equal(8);
      expect(calc.power(5, 0)).to.equal(1);
      expect(calc.power(3, 1)).to.equal(3);
    });

    // This test will fail due to the bug - negative exponents not handled
    it('should handle negative exponents', () => {
      expect(calc.power(2, -2)).to.equal(0.25);
    });
  });
});
