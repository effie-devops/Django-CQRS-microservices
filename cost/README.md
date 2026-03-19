# Split Cost Allocation Data (SCAD) — Per-Pod Cost Report

Queries AWS Cost Explorer for EKS split cost allocation data and the live cluster for pod counts, then computes cost-per-pod for `reader-service` and `writer-service`.

## Prerequisites

1. **Enable SCAD in AWS Billing Console:**
   - **Billing → Cost Allocation Tags** → activate `eks:cluster-name`, `eks:k8s-namespace`, `eks:k8s-app`
   - **Billing → Cost Management Preferences → Split Cost Allocation Data** → enable for Amazon EKS

2. **IAM permissions:** caller needs `ce:GetCostAndUsage`

3. **kubectl** configured for `django-api-uat-cluster` (for live pod counts)

4. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

```bash
# Last 30 days, per-pod breakdown to stdout
python scad_report.py

# Last 7 days, export to CSV
python scad_report.py --days 7 --csv pod_costs.csv
```

## Sample Output

```
SCAD Report — django-api-uat-cluster
Period: 2025-06-01 → 2025-07-01 (30 days)

── Total EKS Cost: $42.37 ──

── Cost by Usage Type ──
  USE1-AmazonEKS-Hours:perCluster            $7.2000
  USE1-NodeUsage:t3.medium                    $35.1700

── Cost by Service (eks:k8s-app) ──
  reader-service                              $18.5200
  writer-service                              $16.6500
  (untagged)                                  $7.2000

── Live Pod Counts ──
  reader-service                              3 running
  writer-service                              2 running

── Per-Pod Cost Breakdown ──
  Service              Pods   Total          Per Pod        Daily/Pod      Hourly/Pod     CPU Req    Mem Req
  ──────────────────── ───── ───────────── ───────────── ───────────── ───────────── ───────── ─────────
  reader-service       3      $18.5200      $6.1733       $0.2058       $0.008574     100m       256Mi
  writer-service       2      $16.6500      $8.3250       $0.2775       $0.011563     100m       256Mi
```
