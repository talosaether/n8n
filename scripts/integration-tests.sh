#!/usr/bin/env bash

#######################################
# n8n Post-Deployment Integration Tests
# Comprehensive health and functionality tests
#######################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENV_FILE="${PROJECT_ROOT}/.env"
TEST_RESULTS_FILE="${PROJECT_ROOT}/test-results.log"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${RED}[ERROR]${NC} .env file not found"
    exit 1
fi

# Get n8n URL
N8N_URL="http://${HOST_IP:-localhost}:${N8N_PORT:-5678}"
N8N_BASIC_AUTH="${N8N_BASIC_AUTH_USER:-admin}:${N8N_BASIC_AUTH_PASSWORD:-changeme123}"

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$TEST_RESULTS_FILE"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$TEST_RESULTS_FILE"
    ((PASSED_TESTS++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$TEST_RESULTS_FILE"
    ((FAILED_TESTS++))
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$TEST_RESULTS_FILE"
}

# Initialize test results file
init_test_results() {
    echo "n8n Integration Test Results" > "$TEST_RESULTS_FILE"
    echo "============================" >> "$TEST_RESULTS_FILE"
    echo "Timestamp: $(date)" >> "$TEST_RESULTS_FILE"
    echo "Target: $N8N_URL" >> "$TEST_RESULTS_FILE"
    echo "" >> "$TEST_RESULTS_FILE"
}

# Test: Docker Container Running
test_container_running() {
    ((TOTAL_TESTS++))
    log_test "Checking if n8n container is running..."

    if docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
        log_pass "n8n container is running"
        return 0
    else
        log_fail "n8n container is not running"
        return 1
    fi
}

# Test: Container Health Status
test_container_health() {
    ((TOTAL_TESTS++))
    log_test "Checking container health status..."

    local health_status=$(docker inspect --format='{{.State.Health.Status}}' n8n 2>/dev/null || echo "unknown")

    if [ "$health_status" = "healthy" ]; then
        log_pass "Container health status: healthy"
        return 0
    else
        log_fail "Container health status: $health_status"
        return 1
    fi
}

# Test: HTTP Endpoint Reachability
test_http_reachable() {
    ((TOTAL_TESTS++))
    log_test "Checking if n8n HTTP endpoint is reachable..."

    local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$N8N_URL" --max-time 10 || echo "000")

    if [ "$response_code" = "401" ] || [ "$response_code" = "200" ]; then
        log_pass "HTTP endpoint is reachable (HTTP $response_code)"
        return 0
    else
        log_fail "HTTP endpoint not reachable (HTTP $response_code)"
        return 1
    fi
}

# Test: Healthz Endpoint
test_healthz_endpoint() {
    ((TOTAL_TESTS++))
    log_test "Testing /healthz endpoint..."

    local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$N8N_URL/healthz" --max-time 10 || echo "000")

    if [ "$response_code" = "200" ]; then
        log_pass "/healthz endpoint is healthy (HTTP 200)"
        return 0
    else
        log_fail "/healthz endpoint failed (HTTP $response_code)"
        return 1
    fi
}

# Test: Basic Authentication
test_basic_auth() {
    ((TOTAL_TESTS++))
    log_test "Testing basic authentication..."

    # Test without auth (should fail)
    local no_auth_code=$(curl -s -o /dev/null -w "%{http_code}" "$N8N_URL" --max-time 10 || echo "000")

    if [ "$no_auth_code" = "401" ]; then
        log_pass "Authentication required (HTTP 401 without credentials)"
        ((TOTAL_TESTS++))
    else
        log_fail "Authentication not enforced (HTTP $no_auth_code)"
        return 1
    fi

    # Test with auth (should succeed)
    local auth_code=$(curl -s -o /dev/null -w "%{http_code}" -u "$N8N_BASIC_AUTH" "$N8N_URL" --max-time 10 || echo "000")

    if [ "$auth_code" = "200" ]; then
        log_pass "Authentication successful (HTTP 200)"
        return 0
    else
        log_fail "Authentication failed (HTTP $auth_code)"
        return 1
    fi
}

# Test: API Endpoint Accessibility
test_api_endpoints() {
    ((TOTAL_TESTS++))
    log_test "Testing API endpoints accessibility..."

    # Test /api/v1/workflows endpoint
    local api_response=$(curl -s -u "$N8N_BASIC_AUTH" "$N8N_URL/api/v1/workflows" --max-time 10 || echo "")

    if echo "$api_response" | grep -q "data" || echo "$api_response" | grep -q "\[\]"; then
        log_pass "API endpoints are accessible"
        return 0
    else
        log_fail "API endpoints not accessible or returned unexpected response"
        return 1
    fi
}

# Test: Volume Persistence
test_volume_persistence() {
    ((TOTAL_TESTS++))
    log_test "Checking volume persistence..."

    local volume_exists=$(docker volume ls --format '{{.Name}}' | grep -c "^n8n_data$" || echo "0")

    if [ "$volume_exists" = "1" ]; then
        log_pass "n8n_data volume exists"
        return 0
    else
        log_fail "n8n_data volume not found"
        return 1
    fi
}

# Test: Container Resource Usage
test_resource_usage() {
    ((TOTAL_TESTS++))
    log_test "Checking container resource usage..."

    local mem_usage=$(docker stats --no-stream --format "{{.MemPerc}}" n8n 2>/dev/null | sed 's/%//' || echo "0")
    local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" n8n 2>/dev/null | sed 's/%//' || echo "0")

    log_info "CPU Usage: ${cpu_usage}%"
    log_info "Memory Usage: ${mem_usage}%"

    # Check if memory usage is below 90%
    if (( $(echo "$mem_usage < 90" | bc -l) )); then
        log_pass "Resource usage is within acceptable limits"
        return 0
    else
        log_fail "Resource usage is high (Memory: ${mem_usage}%)"
        return 1
    fi
}

# Test: Container Logs for Errors
test_container_logs() {
    ((TOTAL_TESTS++))
    log_test "Checking container logs for critical errors..."

    local error_count=$(docker logs n8n --tail 100 2>&1 | grep -i "error\|fatal\|exception" | grep -v "0 errors" | wc -l || echo "0")

    if [ "$error_count" -eq 0 ]; then
        log_pass "No critical errors in recent logs"
        return 0
    else
        log_fail "Found $error_count error entries in logs"
        log_info "Recent errors:"
        docker logs n8n --tail 100 2>&1 | grep -i "error\|fatal\|exception" | grep -v "0 errors" | head -5 | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi
}

# Test: Network Connectivity
test_network_connectivity() {
    ((TOTAL_TESTS++))
    log_test "Checking network connectivity..."

    local network_exists=$(docker network ls --format '{{.Name}}' | grep -c "^n8n_network$" || echo "0")

    if [ "$network_exists" = "1" ]; then
        log_pass "n8n_network exists"
        return 0
    else
        log_fail "n8n_network not found"
        return 1
    fi
}

# Test: Webhook URL Configuration
test_webhook_config() {
    ((TOTAL_TESTS++))
    log_test "Verifying webhook URL configuration..."

    local webhook_url=$(docker exec n8n env | grep "WEBHOOK_URL" | cut -d'=' -f2 || echo "")

    if [ -n "$webhook_url" ]; then
        log_pass "Webhook URL configured: $webhook_url"
        return 0
    else
        log_fail "Webhook URL not configured"
        return 1
    fi
}

# Test: Port Binding
test_port_binding() {
    ((TOTAL_TESTS++))
    log_test "Checking port binding..."

    local port_status=$(docker port n8n 5678 2>/dev/null || echo "")

    if [ -n "$port_status" ]; then
        log_pass "Port 5678 is bound: $port_status"
        return 0
    else
        log_fail "Port 5678 is not bound"
        return 1
    fi
}

# Test: Environment Variables
test_environment_variables() {
    ((TOTAL_TESTS++))
    log_test "Verifying critical environment variables..."

    local vars_ok=true

    # Check N8N_HOST
    if ! docker exec n8n env | grep -q "N8N_HOST="; then
        log_fail "N8N_HOST not set"
        vars_ok=false
    fi

    # Check N8N_PORT
    if ! docker exec n8n env | grep -q "N8N_PORT="; then
        log_fail "N8N_PORT not set"
        vars_ok=false
    fi

    # Check basic auth
    if ! docker exec n8n env | grep -q "N8N_BASIC_AUTH_ACTIVE=true"; then
        log_fail "Basic auth not enabled"
        vars_ok=false
    fi

    if [ "$vars_ok" = true ]; then
        log_pass "Critical environment variables are set"
        return 0
    else
        return 1
    fi
}

# Test: Container Restart Policy
test_restart_policy() {
    ((TOTAL_TESTS++))
    log_test "Checking container restart policy..."

    local restart_policy=$(docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' n8n 2>/dev/null || echo "no")

    if [ "$restart_policy" = "unless-stopped" ] || [ "$restart_policy" = "always" ]; then
        log_pass "Restart policy is configured: $restart_policy"
        return 0
    else
        log_fail "Restart policy not configured properly: $restart_policy"
        return 1
    fi
}

# Test: Response Time
test_response_time() {
    ((TOTAL_TESTS++))
    log_test "Measuring response time..."

    local response_time=$(curl -s -o /dev/null -w "%{time_total}" -u "$N8N_BASIC_AUTH" "$N8N_URL" --max-time 10 || echo "10")

    log_info "Response time: ${response_time}s"

    if (( $(echo "$response_time < 5" | bc -l) )); then
        log_pass "Response time is acceptable (< 5s)"
        return 0
    else
        log_fail "Response time is slow (${response_time}s)"
        return 1
    fi
}

# Display test summary
display_summary() {
    echo ""
    echo "======================================" | tee -a "$TEST_RESULTS_FILE"
    echo "Test Summary" | tee -a "$TEST_RESULTS_FILE"
    echo "======================================" | tee -a "$TEST_RESULTS_FILE"
    echo "Total Tests: $TOTAL_TESTS" | tee -a "$TEST_RESULTS_FILE"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}" | tee -a "$TEST_RESULTS_FILE"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}" | tee -a "$TEST_RESULTS_FILE"

    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo "Success Rate: ${success_rate}%" | tee -a "$TEST_RESULTS_FILE"
    echo "" | tee -a "$TEST_RESULTS_FILE"

    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}" | tee -a "$TEST_RESULTS_FILE"
        return 0
    else
        echo -e "${RED}Some tests failed. Check $TEST_RESULTS_FILE for details.${NC}" | tee -a "$TEST_RESULTS_FILE"
        return 1
    fi
}

# Main function
main() {
    log_info "Starting n8n Integration Tests..."
    log_info "=================================="
    echo ""

    init_test_results

    # Run all tests
    test_container_running
    test_container_health
    test_http_reachable
    test_healthz_endpoint
    test_basic_auth
    test_api_endpoints
    test_volume_persistence
    test_resource_usage
    test_container_logs
    test_network_connectivity
    test_webhook_config
    test_port_binding
    test_environment_variables
    test_restart_policy
    test_response_time

    # Display summary
    echo ""
    display_summary

    # Exit with appropriate code
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
