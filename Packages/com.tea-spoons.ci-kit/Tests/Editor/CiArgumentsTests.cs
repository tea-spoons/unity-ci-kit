using NUnit.Framework;

namespace TeaSpoons.CiKit.Tests
{
    public class CiArgumentsTests
    {
        [Test]
        public void ReadsValuesAndIgnoresUnityFlags()
        {
            var args = new CiArguments(new[]
            {
                "Unity", "-batchmode", "-quit", "-ciBuildTarget", "Android", "-ciOutputPath", "/out",
            });

            Assert.AreEqual("Android", args.Get("BuildTarget"));
            Assert.AreEqual("/out", args.Get("OutputPath"));
            Assert.IsFalse(args.Has("batchmode"));
        }

        [Test]
        public void FlagWithoutValueCountsAsTrue()
        {
            var args = new CiArguments(new[] { "-ciDevelopment", "-ciVersion", "1.2.3" });

            Assert.IsTrue(args.GetBool("Development"));
            Assert.AreEqual("1.2.3", args.Get("Version"));
        }

        [Test]
        public void NamesAreCaseInsensitive()
        {
            var args = new CiArguments(new[] { "-cibuildtarget", "WebGL" });

            Assert.AreEqual("WebGL", args.Get("BuildTarget"));
        }

        [Test]
        public void ListsSplitOnSemicolonsAndCommas()
        {
            var args = new CiArguments(new[] { "-ciDefines", "FOO;BAR,,BAZ;" });

            CollectionAssert.AreEqual(new[] { "FOO", "BAR", "BAZ" }, args.GetList("Defines"));
        }

        [Test]
        public void MissingValuesFallBack()
        {
            var args = new CiArguments(new string[0]);

            Assert.AreEqual("fallback", args.Get("Nothing", "fallback"));
            Assert.IsFalse(args.GetBool("Nothing"));
            Assert.IsEmpty(args.GetList("Nothing"));
        }
    }
}
