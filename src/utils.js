function formatNumber(num, decimals = 2) {
  return Number(num.toFixed(decimals));
}

function isEven(num) {
  return num % 2 === 0;
}

function factorial(n) {
  if (n < 0) throw new Error('Factorial of negative number');
  if (n <= 1) return 1;
  return n * factorial(n - 1);
}

module.exports = {
  formatNumber,
  isEven,
  factorial
};
