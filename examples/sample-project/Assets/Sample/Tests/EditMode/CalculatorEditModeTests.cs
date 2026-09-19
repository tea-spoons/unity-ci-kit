using NUnit.Framework;

namespace Sample.Tests
{
    public class CalculatorEditModeTests
    {
        [Test]
        public void AddSumsTwoNumbers() => Assert.AreEqual(5, Calculator.Add(2, 3));

        [TestCase(-5, 0, 10, 0)]
        [TestCase(5, 0, 10, 5)]
        [TestCase(50, 0, 10, 10)]
        public void ClampKeepsValueInRange(int value, int min, int max, int expected) =>
            Assert.AreEqual(expected, Calculator.Clamp(value, min, max));
    }
}
