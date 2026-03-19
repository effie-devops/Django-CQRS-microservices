#!/bin/bash
# Live scaling monitor — run in a separate terminal during the stress test
# Usage: bash tests/monitor.sh

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       🔍 LIVE SCALING MONITOR — Django CQRS            ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

PREV_NODES=0
PREV_READER=0
PREV_WRITER=0

while true; do
    TIMESTAMP=$(date +"%H:%M:%S")
    NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    READER_PODS=$(kubectl get pods -l app=reader-service --no-headers 2>/dev/null | grep Running | wc -l | tr -d ' ')
    WRITER_PODS=$(kubectl get pods -l app=writer-service --no-headers 2>/dev/null | grep Running | wc -l | tr -d ' ')
    PENDING=$(kubectl get pods --no-headers 2>/dev/null | grep Pending | wc -l | tr -d ' ')

    READER_CPU=$(kubectl get hpa reader-service-hpa --no-headers 2>/dev/null | awk '{print $3}')
    WRITER_CPU=$(kubectl get hpa writer-service-hpa --no-headers 2>/dev/null | awk '{print $3}')

    KARPENTER_NODES=$(kubectl get nodeclaims --no-headers 2>/dev/null | wc -l | tr -d ' ')

    echo -e "${CYAN}[$TIMESTAMP]${NC} ─────────────────────────────────────────"
    echo -e "  ${BOLD}Nodes:${NC}    $NODES total ($KARPENTER_NODES from Karpenter)"
    echo -e "  ${BOLD}Reader:${NC}   $READER_PODS pods  │  CPU: $READER_CPU"
    echo -e "  ${BOLD}Writer:${NC}   $WRITER_PODS pods  │  CPU: $WRITER_CPU"

    if [ "$PENDING" -gt 0 ]; then
        echo -e "  ${YELLOW}⏳ Pending: $PENDING pods waiting for nodes${NC}"
    fi

    if [ "$NODES" -gt "$PREV_NODES" ] && [ "$PREV_NODES" -gt 0 ]; then
        echo -e "  ${GREEN}🚀 KARPENTER SCALED: $PREV_NODES → $NODES nodes${NC}"
    fi
    if [ "$READER_PODS" -gt "$PREV_READER" ] && [ "$PREV_READER" -gt 0 ]; then
        echo -e "  ${GREEN}📈 HPA SCALED READER: $PREV_READER → $READER_PODS pods${NC}"
    fi
    if [ "$WRITER_PODS" -gt "$PREV_WRITER" ] && [ "$PREV_WRITER" -gt 0 ]; then
        echo -e "  ${GREEN}📈 HPA SCALED WRITER: $PREV_WRITER → $WRITER_PODS pods${NC}"
    fi

    if [ "$NODES" -lt "$PREV_NODES" ] && [ "$PREV_NODES" -gt 0 ]; then
        echo -e "  ${RED}📉 KARPENTER CONSOLIDATED: $PREV_NODES → $NODES nodes${NC}"
    fi
    if [ "$READER_PODS" -lt "$PREV_READER" ] && [ "$PREV_READER" -gt 0 ]; then
        echo -e "  ${RED}📉 HPA SCALED DOWN READER: $PREV_READER → $READER_PODS pods${NC}"
    fi

    PREV_NODES=$NODES
    PREV_READER=$READER_PODS
    PREV_WRITER=$WRITER_PODS

    sleep 10
done
