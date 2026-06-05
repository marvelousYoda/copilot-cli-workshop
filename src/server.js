const express = require("express");
const path = require("path");

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get("/", (_req, res) => {
  res.send(`
    <h1>On-Call Handoff Notes</h1>
    <p>Starter app is running. Time to build!</p>
    <p>Pick a story from ADO and ask Copilot CLI to implement it.</p>
  `);
});

app.get("/healthz", (_req, res) => res.json({ ok: true }));

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => console.log(`Listening on http://localhost:${PORT}`));
}

module.exports = app;
