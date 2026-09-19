namespace Sample
{
    /// <summary>Tiny class so the sample project has something to test.</summary>
    public static class Calculator
    {
        public static int Add(int a, int b) => a + b;

        public static int Clamp(int value, int min, int max) =>
            value < min ? min : value > max ? max : value;
    }
}
