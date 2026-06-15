// Minimal example plugin: echoes the input with a configurable prefix.
// Demonstrates the plugin contract: translate(query, completion) + $option.
function translate(query, completion) {
  var prefix = $option.prefix || "";
  completion({ result: { translated: prefix + query.text } });
}
