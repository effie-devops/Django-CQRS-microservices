#!/bin/bash
# Capture cluster state snapshot — run before and after the stress test
# Usage: bash tests/snapshot.sh before | bash tests/snapshot.sh after

PHASE=${1:-"snapshot"}
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   📸 CLUSTER SNAPSHOT — ${PHASE^^}                        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}── Nodes ──${NC}"
kubectl get nodes -o wide
echo ""

echo -e "${GREEN}── Pods ──${NC}"
kubectl get pods -o wide
echo ""

echo -e "${GREEN}── HPA ──${NC}"
kubectl get hpa
echo ""

echo -e "${GREEN}── Karpenter NodeClaims ──${NC}"
kubectl get nodeclaims 2>/dev/null || echo "No nodeclaims"
echo ""

echo -e "${GREEN}── Resource Usage ──${NC}"
kubectl top nodes 2>/dev/null
echo ""
kubectl top pods 2>/dev/null
echo ""

echo -e "${GREEN}── Recent HPA Events ──${NC}"
kubectl get events --field-selector reason=SuccessfulRescale --sort-by='.lastTimestamp' 2>/dev/null | tail -10
echo ""

echo -e "${GREEN}── Karpenter Events ──${NC}"
kubectl get events --field-selector source=karpenter --sort-by='.lastTimestamp' 2>/dev/null | tail -10
