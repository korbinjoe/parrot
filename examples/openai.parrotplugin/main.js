// Example LLM plugin: translates via the OpenAI Chat Completions API.
// Network is restricted to api.openai.com by the manifest whitelist.
function translate(query, completion) {
  var model = $option.model || "gpt-4o-mini";
  var system = "You are a professional translator. Translate the user's text into " +
               query.to + ". Output only the translation.";
  if (query.terminology && query.terminology.length) {
    system += "\n\nTerminology constraints:";
    for (var i = 0; i < query.terminology.length; i++) {
      var term = query.terminology[i];
      system += "\n- " + term.source + " => " + term.target;
    }
    system += "\nUse the exact target term whenever the source term appears.";
  }
  $http.post({
    url: "https://api.openai.com/v1/chat/completions",
    header: {
      "Content-Type": "application/json",
      "Authorization": "Bearer " + $option.apiKey
    },
    body: {
      model: model,
      temperature: 0.2,
      messages: [
        { role: "system", content: system },
        { role: "user", content: query.text }
      ]
    },
    handler: function (resp) {
      if (resp.error) { completion({ error: resp.error }); return; }
      if (resp.statusCode === 401 || resp.statusCode === 403) {
        completion({ error: "auth failed" }); return;
      }
      try {
        var content = resp.data.choices[0].message.content;
        completion({ result: { translated: content.trim() } });
      } catch (e) {
        completion({ error: "parse error: " + e });
      }
    }
  });
}
