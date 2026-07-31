# Day 10 Video Proof

Recommended duration: 3–5 minutes.

1. Show the code contract and fallback policy:
   - Haiku micro-model;
   - Sonnet fallback;
   - threshold `0.80`;
   - exact JSON schema and `OK` / `UNSURE` status.
2. Show the frozen catalog: 24 cases split into 8 simple, 8 boundary and 8
   complex inputs.
3. Open WorkHarness Chat and send `/micro-model evaluate`.
4. Open the new `Inference Evaluation` Run and show live timeline events:
   - provider request with model and tier;
   - structured-output validation;
   - route accepted by Haiku or escalated to Sonnet.
5. At `Run Completed`, show the Final Summary:
   - total cases;
   - handled by micro-model;
   - fallbacks / calls to the large model;
   - average latency.
6. Open `day10-micro-model-report.md` and scroll through the per-case routing
   table. Briefly show the JSON artifact as proof of structured results.
7. Show the passing `MicroModelEvaluationTests` run. Mention that it forces
   `UNSURE` and invalid JSON to demonstrate the fallback even if every live
   Haiku response was accepted.

Closing statement:

> WorkHarness sends every request to Haiku first. It accepts only valid JSON
> with status OK and confidence at least 0.80; otherwise it calls Sonnet. The
> report shows how many of 24 requests avoided the large model and the measured
> average latency.
