"""
Split Cost Allocation Data (SCAD) Report — Per-Pod Cost Breakdown.

Queries AWS Cost Explorer for EKS split costs and the live cluster
for pod counts, then computes cost-per-pod for each service.
"""

import argparse
import csv
import json
import subprocess
import sys
from datetime import datetime, timedelta

import boto3


CLUSTER_NAME = "django-api-uat-cluster"
REGION = "us-east-1"
NAMESPACE = "default"
DEPLOYMENTS = ["reader-service", "writer-service"]

# From deployment manifests
POD_RESOURCES = {
    "reader-service": {"cpu_request": "100m", "cpu_limit": "500m", "mem_request": "256Mi", "mem_limit": "512Mi"},
    "writer-service": {"cpu_request": "100m", "cpu_limit": "500m", "mem_request": "256Mi", "mem_limit": "512Mi"},
}


def get_date_range(days_back=30):
    end = datetime.utcnow().date()
    start = end - timedelta(days=days_back)
    return str(start), str(end)


def get_live_pod_counts():
    """Query the cluster for current running pod counts per deployment."""
    counts = {}
    for dep in DEPLOYMENTS:
        try:
            result = subprocess.run(
                ["kubectl", "get", "pods", "-n", NAMESPACE,
                 "-l", f"app={dep}", "--field-selector=status.phase=Running",
                 "-o", "json"],
                capture_output=True, text=True, timeout=15,
            )
            if result.returncode == 0:
                pods = json.loads(result.stdout)
                counts[dep] = len(pods.get("items", []))
            else:
                print(f"  [WARN] kubectl failed for {dep}: {result.stderr.strip()}", file=sys.stderr)
                counts[dep] = None
        except (FileNotFoundError, subprocess.TimeoutExpired):
            print(f"  [WARN] kubectl unavailable, skipping live pod count for {dep}", file=sys.stderr)
            counts[dep] = None
    return counts


def get_eks_total_cost(ce, start, end):
    """Total EKS cost for the cluster."""
    resp = ce.get_cost_and_usage(
        TimePeriod={"Start": start, "End": end},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        Filter={"Dimensions": {"Key": "SERVICE", "Values": ["Amazon Elastic Kubernetes Service"]}},
    )
    total = sum(float(p["Total"]["UnblendedCost"]["Amount"]) for p in resp["ResultsByTime"])
    return total


def get_cost_by_tag(ce, start, end, tag_key):
    """Get cost grouped by a specific SCAD tag."""
    try:
        resp = ce.get_cost_and_usage(
            TimePeriod={"Start": start, "End": end},
            Granularity="MONTHLY",
            Metrics=["UnblendedCost"],
            GroupBy=[{"Type": "TAG", "Key": tag_key}],
            Filter={"Tags": {"Key": "eks:cluster-name", "Values": [CLUSTER_NAME]}},
        )
    except Exception as e:
        print(f"  [WARN] Could not query tag '{tag_key}': {e}", file=sys.stderr)
        return {}

    costs = {}
    for period in resp["ResultsByTime"]:
        for group in period.get("Groups", []):
            tag_val = group["Keys"][0].replace(f"{tag_key}$", "")
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            costs[tag_val] = costs.get(tag_val, 0.0) + amount
    return costs


def get_cost_by_usage_type(ce, start, end):
    """EKS cost broken down by usage type."""
    resp = ce.get_cost_and_usage(
        TimePeriod={"Start": start, "End": end},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        Filter={
            "And": [
                {"Dimensions": {"Key": "SERVICE", "Values": ["Amazon Elastic Kubernetes Service"]}},
                {"Tags": {"Key": "eks:cluster-name", "Values": [CLUSTER_NAME]}},
            ]
        },
        GroupBy=[{"Type": "DIMENSION", "Key": "USAGE_TYPE"}],
    )
    costs = {}
    for period in resp["ResultsByTime"]:
        for group in period.get("Groups", []):
            key = group["Keys"][0]
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            if amount > 0.001:
                costs[key] = costs.get(key, 0.0) + amount
    return costs


def compute_per_pod_cost(service_costs, pod_counts, days):
    """Compute per-pod cost (total, daily, hourly) for each service."""
    rows = []
    for svc in DEPLOYMENTS:
        svc_cost = service_costs.get(svc, 0.0)
        pod_count = pod_counts.get(svc)
        resources = POD_RESOURCES[svc]

        row = {
            "service": svc,
            "total_cost": svc_cost,
            "pod_count": pod_count if pod_count else "N/A",
            "cpu_request": resources["cpu_request"],
            "mem_request": resources["mem_request"],
        }

        if pod_count and pod_count > 0:
            cost_per_pod = svc_cost / pod_count
            row["cost_per_pod_period"] = cost_per_pod
            row["cost_per_pod_daily"] = cost_per_pod / days if days > 0 else 0
            row["cost_per_pod_hourly"] = cost_per_pod / (days * 24) if days > 0 else 0
        else:
            row["cost_per_pod_period"] = None
            row["cost_per_pod_daily"] = None
            row["cost_per_pod_hourly"] = None

        rows.append(row)
    return rows


def write_csv(rows, path):
    if not rows:
        return
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(f"\n[OK] CSV written to {path}")


def fmt(val, decimals=4):
    return f"${val:.{decimals}f}" if val is not None else "N/A"


def build_report(days_back, output_csv):
    ce = boto3.client("ce", region_name=REGION)
    start, end = get_date_range(days_back)

    print(f"SCAD Report — {CLUSTER_NAME}")
    print(f"Period: {start} → {end} ({days_back} days)\n")

    # 1. Total EKS cost
    total = get_eks_total_cost(ce, start, end)
    print(f"── Total EKS Cost: {fmt(total, 2)} ──\n")

    # 2. Cost by usage type
    print("── Cost by Usage Type ──")
    usage_costs = get_cost_by_usage_type(ce, start, end)
    for utype, amount in sorted(usage_costs.items(), key=lambda x: -x[1]):
        print(f"  {utype:50s} {fmt(amount)}")

    # 3. Cost by service (SCAD tag)
    print("\n── Cost by Service (eks:k8s-app) ──")
    service_costs = get_cost_by_tag(ce, start, end, "eks:k8s-app")
    if not service_costs:
        # Fallback to namespace tag
        print("  (eks:k8s-app not available, falling back to eks:k8s-namespace)")
        service_costs = get_cost_by_tag(ce, start, end, "eks:k8s-namespace")

    for svc, amount in sorted(service_costs.items(), key=lambda x: -x[1]):
        label = svc if svc else "(untagged)"
        print(f"  {label:40s} {fmt(amount)}")

    # 4. Live pod counts
    print("\n── Live Pod Counts ──")
    pod_counts = get_live_pod_counts()
    for dep, count in pod_counts.items():
        status = f"{count} running" if count is not None else "unavailable"
        print(f"  {dep:40s} {status}")

    # 5. Per-pod cost
    print(f"\n── Per-Pod Cost Breakdown ──")
    pod_rows = compute_per_pod_cost(service_costs, pod_counts, days_back)
    print(f"  {'Service':<20s} {'Pods':<6s} {'Total':<14s} {'Per Pod':<14s} {'Daily/Pod':<14s} {'Hourly/Pod':<14s} {'CPU Req':<10s} {'Mem Req':<10s}")
    print(f"  {'─'*20} {'─'*5} {'─'*13} {'─'*13} {'─'*13} {'─'*13} {'─'*9} {'─'*9}")
    for r in pod_rows:
        pods = str(r["pod_count"]) if r["pod_count"] != "N/A" else "N/A"
        print(
            f"  {r['service']:<20s} {pods:<6s} "
            f"{fmt(r['total_cost'], 4):<14s} "
            f"{fmt(r['cost_per_pod_period'], 4):<14s} "
            f"{fmt(r['cost_per_pod_daily'], 4):<14s} "
            f"{fmt(r['cost_per_pod_hourly'], 6):<14s} "
            f"{r['cpu_request']:<10s} {r['mem_request']:<10s}"
        )

    # CSV export
    if output_csv:
        write_csv(pod_rows, output_csv)


def main():
    parser = argparse.ArgumentParser(description="SCAD per-pod cost report for Django CQRS EKS microservices")
    parser.add_argument("--days", type=int, default=30, help="Lookback period in days (default: 30)")
    parser.add_argument("--csv", type=str, default=None, help="Output CSV file path")
    args = parser.parse_args()
    build_report(args.days, args.csv)


if __name__ == "__main__":
    main()
