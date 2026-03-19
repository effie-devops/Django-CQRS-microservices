import http from "k6/http";
import { check, sleep } from "k6";
import { Rate, Trend } from "k6/metrics";

const ALB_URL = "https://k8s-djangoapi-6ccce36b95-1435753881.us-east-1.elb.amazonaws.com";
const HOST_HEADER = { Host: "apis.effiecancode.buzz" };

const errorRate = new Rate("errors");
const readerLatency = new Trend("reader_latency", true);
const writerLatency = new Trend("writer_latency", true);

export const options = {
  insecureSkipTLSVerify: true,
  stages: [
    { duration: "20s", target: 20 },     // warm up
    { duration: "40s", target: 100 },    // moderate load
    { duration: "1m", target: 300 },     // push hard — trigger HPA
    { duration: "1m30s", target: 500 },  // spike — sustained peak
    { duration: "1m", target: 500 },     // hold peak
    { duration: "30s", target: 0 },      // cool down
  ],
  thresholds: {
    http_req_duration: ["p(95)<3000"],
    errors: ["rate<0.15"],
  },
};

export default function () {
  const rand = Math.random();

  if (rand < 0.6) {
    const res = http.get(`${ALB_URL}/reader/books/`, { headers: HOST_HEADER });
    readerLatency.add(res.timings.duration);
    check(res, { "reader list 200": (r) => r.status === 200 });
    errorRate.add(res.status !== 200);
  } else if (rand < 0.85) {
    const payload = JSON.stringify({
      title: `K6 Book ${Date.now()}`,
      author: `Load Tester ${__VU}`,
      description: `Stress test entry from VU ${__VU}`,
    });
    const params = { headers: Object.assign({ "Content-Type": "application/json" }, HOST_HEADER) };

    const createRes = http.post(`${ALB_URL}/writer/books/create/`, payload, params);
    writerLatency.add(createRes.timings.duration);
    check(createRes, { "writer create 201": (r) => r.status === 201 });
    errorRate.add(createRes.status !== 201);

    if (createRes.status === 201) {
      try {
        const body = JSON.parse(createRes.body);
        if (body.id) {
          http.del(`${ALB_URL}/writer/books/${body.id}/delete/`, null, { headers: HOST_HEADER });
        }
      } catch (_) {}
    }
  } else {
    const res = http.get(`${ALB_URL}/reader/health/`, { headers: HOST_HEADER });
    check(res, { "health 200": (r) => r.status === 200 });
    errorRate.add(res.status !== 200);
  }

  sleep(0.3);
}
