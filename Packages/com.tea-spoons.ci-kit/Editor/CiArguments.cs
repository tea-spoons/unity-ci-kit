using System;
using System.Collections.Generic;

namespace TeaSpoons.CiKit
{
    /// <summary>
    /// Reads kit-specific command line arguments of the form <c>-ciName value</c>.
    /// Anything that does not start with <c>-ci</c> is ignored, so Unity's own flags pass through untouched.
    /// A <c>-ciName</c> without a value counts as the flag being set to "true".
    /// </summary>
    public sealed class CiArguments
    {
        const string Prefix = "-ci";

        readonly Dictionary<string, string> _values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        public CiArguments(IReadOnlyList<string> args)
        {
            for (var i = 0; i < args.Count; i++)
            {
                var arg = args[i];
                if (!arg.StartsWith(Prefix, StringComparison.OrdinalIgnoreCase) || arg.Length == Prefix.Length)
                    continue;

                var name = arg.Substring(Prefix.Length);
                var value = "true";
                if (i + 1 < args.Count && !args[i + 1].StartsWith("-", StringComparison.Ordinal))
                {
                    value = args[i + 1];
                    i++;
                }

                _values[name] = value;
            }
        }

        public bool Has(string name) => _values.ContainsKey(name);

        public string Get(string name, string fallback = null) =>
            _values.TryGetValue(name, out var value) ? value : fallback;

        public bool GetBool(string name) =>
            _values.TryGetValue(name, out var value) && bool.TryParse(value, out var parsed) && parsed;

        /// <summary>Splits a value on ';' and ',' and drops empty entries.</summary>
        public string[] GetList(string name)
        {
            if (!_values.TryGetValue(name, out var value))
                return Array.Empty<string>();

            return value.Split(new[] { ';', ',' }, StringSplitOptions.RemoveEmptyEntries);
        }
    }
}
