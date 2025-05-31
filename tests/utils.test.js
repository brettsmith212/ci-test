const { expect } = require('chai');
const { formatNumber, isEven, factorial } = require('../src/utils');

describe('Utils', () => {
  describe('formatNumber', () => {
    it('should format numbers to 2 decimal places by default', () => {
      expect(formatNumber(3.14159)).to.equal(3.14);
    });

    it('should format numbers to specified decimal places', () => {
      expect(formatNumber(3.14159, 3)).to.equal(3.142);
    });
  });

  describe('isEven', () => {
    it('should return true for even numbers', () => {
      expect(isEven(4)).to.be.true;
      expect(isEven(0)).to.be.true;
    });

    it('should return false for odd numbers', () => {
      expect(isEven(3)).to.be.false;
      expect(isEven(1)).to.be.false;
    });
  });

  describe('factorial', () => {
    it('should calculate factorial correctly', () => {
      expect(factorial(0)).to.equal(1);
      expect(factorial(1)).to.equal(1);
      expect(factorial(5)).to.equal(120);
    });

    it('should throw error for negative numbers', () => {
      expect(() => factorial(-1)).to.throw('Factorial of negative number');
    });
  });
});
