# 🎤 Stress Test Demo — Presentation Runbook

## Setup: Open 3 Terminal Windows

| Terminal | Purpose | Command |
|----------|---------|---------|
| **Terminal 1** | Live Scaling Monitor | `bash tests/monitor.sh` |
| **Terminal 2** | Stress Test Runner | _(commands below)_ |
| **Terminal 3** | Ad-hoc kubectl | _(for live queries)_ |

---

## Step 1 — Show the Baseline (Terminal 2)

> _"Let me show you our current cluster state before any load."_

```bash
bash tests/snapshot.sh before
```

**Talk through:**
- 2 nodes (managed node group)
- 2 reader pods, 2 writer pods, 2 frontend pods
- HPA configured: min 2, max 6, target 70% CPU
- Karpenter installed: will provision new nodes if pods can't be scheduled
- Current CPU usage is low (~13%)

---

## Step 2 — Start the Live Monitor (Terminal 1)

> _"I'll start a live monitor so we can watch the scaling in real time."_

```bash
bash tests/monitor.sh
```

**Talk through:**
- This refreshes every 10 seconds
- Shows node count, pod count, CPU utilization
- Will highlight scaling events as they happen

---

## Step 3 — Launch the Stress Test (Terminal 2)

> _"Now let's simulate real-world traffic. We'll ramp from 0 to 400 concurrent users over 8.5 minutes."_

```bash
~/.local/bin/k6 run tests/stress-test.js
```

**Talk through the stages as they happen:**

| Time | VUs | What to Say |
|------|-----|-------------|
| 0:00–0:20 | 0→20 | _"Warm-up phase. 60% reads, 25% writes, 15% health checks."_ |
| 0:20–1:00 | 20→100 | _"Moderate load. Watch the CPU start climbing in the monitor."_ |
| 1:00–2:00 | 100→300 | _"This is where it gets interesting. CPU should cross 70% — watch for HPA scaling."_ |
| 2:00–3:30 | 300→400 | _"Heavy spike. HPA should be scaling pods to max now."_ |
| 3:30–4:30 | 400 | _"Sustained peak. The system is fully scaled out."_ |
| 4:30–5:00 | 400→0 | _"Cool-down. After traffic drops, watch HPA scale back down."_ |

---

## Step 4 — Show the Scaled State (Terminal 3)

> _"Let's capture the state at peak load."_

While the test is still running (around the 5–6 minute mark):

```bash
bash tests/snapshot.sh after
```

**Point out:**
- More pods running (HPA scaled reader/writer from 2 → up to 6)
- Possibly more nodes (Karpenter provisioned)
- Higher CPU/memory usage across the board

---

## Step 5 — Review k6 Results (Terminal 2)

> _"Here are the final results."_

After the test completes, walk through the k6 summary:

| Metric | What to Highlight |
|--------|-------------------|
| `checks` | Success rate — how many requests passed |
| `http_req_duration p(95)` | 95th percentile latency |
| `http_reqs` | Total requests per second |
| `reader_latency` | Read path performance |
| `writer_latency` | Write path performance |
| `errors` | Error rate under load |

---

## Step 6 — Show Scale-Down (Terminal 1)

> _"Now watch the system scale back down automatically."_

Wait 2–5 minutes after the test ends. The monitor will show:
- HPA scaling pods back to 2
- Karpenter consolidating/removing empty nodes

You can also run:
```bash
kubectl get events --sort-by='.lastTimestamp' | grep -E "ScalingReplicaSet|Scaled|Provisioned|Deprovisioned" | tail -20
```

---

## Step 7 — Architecture Recap

> _"Here's what just happened automatically:"_

```
Traffic spike detected
  → HPA sees CPU > 70%
    → Scales pods from 2 → 6
      → Pods go Pending (no room on existing nodes)
        → Karpenter provisions a new EC2 instance in ~60s
          → Pending pods get scheduled
            → Traffic served successfully

Traffic drops
  → HPA scales pods back to 2
    → Nodes become underutilized
      → Karpenter consolidates and terminates empty nodes
        → Cost savings
```

---

## Quick Recovery Commands

If anything goes wrong during the demo:

```bash
# Check pod status
kubectl get pods -o wide

# Check for errors
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Restart a stuck deployment
kubectl rollout restart deployment/reader-service

# Check Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=20
```

---

## Cleanup After Demo

Delete the test books created during the stress test:

```bash
# From Terminal 3
kubectl exec -it $(kubectl get pod -l app=reader-service -o jsonpath='{.items[0].metadata.name}') -- python manage.py shell -c "
from shared.models import Book
deleted = Book.objects.filter(title__startswith='K6 Book').delete()
print(f'Cleaned up {deleted[0]} test books')
"
```
