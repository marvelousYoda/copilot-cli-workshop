# Demo WorkIQ context — dummy IcM handoff email

> **Why this file exists:** WorkIQ surfaces context from your real work — emails, Teams chats,
> meetings, IcMs. For the workshop we seed that context by having you **email this dummy IcM to a
> buddy** during setup. ~2 minutes later WorkIQ has ingested it, so when you build **F6 (Import
> suggested notes from WorkIQ)** there's genuine context to extract — not just the mock fallback.
> This isn't about the incident itself; it's about getting a feel for how WorkIQ picks up your
> live work context.

## How to use it (do this during setup — see README "Phase 0")

1. Pair up with the person next to you and swap email addresses.
2. In Outlook, paste the **Subject** and **Body** below into a new email **to your buddy**.
3. Send it. (You'll receive theirs too — now both of you have inbound context.)
4. Wait ~2 minutes for WorkIQ to pick it up, then carry on with ADO setup and Phases 1–3.

---

**To:** `<your workshop buddy>`

**Subject:** `[IcM 0123456] SEV-2 — AuthService elevated 5xx / token-validation latency (mitigated, watch overnight)`

**Body:**

```text
Heads up before your on-call shift —

We hit a SEV-2 on AuthService around 14:20 UTC. Token-validation p95 spiked to ~3s and we saw
elevated 5xx on the Billing API downstream because auth calls were timing out.

What we know:
- Root cause looks like connection-pool exhaustion after the 14:00 deploy (build 8821).
- Mitigation: rolled back to build 8819 and bumped the pool size 50 -> 100. p95 back under 400ms as of 15:05 UTC.
- Still simmering: one replica in West US 2 shows intermittent timeouts — restarted once, keep an eye on it.

Workaround applied (not a permanent fix):
- Manually scaled AuthService to 6 replicas. Needs to be reverted or made permanent in config.

Follow-ups for the next on-call:
- Confirm the West US 2 replica is stable by 09:00.
- Customer escalation from Contoso (ticket #44781) still open — they saw failed logins during the
  window and are owed an update.
- File a repair item to make the pool-size change permanent.

IcM: https://portal.microsofticm.com/imp/v5/incidents/details/0123456
Severity: 2 · Service: AuthService
```
