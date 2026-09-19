using System.Collections;
using NUnit.Framework;
using UnityEngine.TestTools;

namespace Sample.Tests
{
    public class CalculatorPlayModeTests
    {
        [UnityTest]
        public IEnumerator AddWorksAfterAFrame()
        {
            yield return null;

            Assert.AreEqual(7, Calculator.Add(3, 4));
        }
    }
}
