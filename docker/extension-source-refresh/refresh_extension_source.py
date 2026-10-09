#!/usr/bin/env python3
"""Chạy nền: định kỳ tải nguyên JSON resource (giữ cả `extension[]`) từ FHIR
server và ghi ra file NDJSON (1 resource/dòng) trong OUTPUT_DIR, mounted vào
Spark ở /dwh. Encounter_fact.sql (và các view khác nếu cần) đọc thẳng file
này bằng cú pháp `json.`/dwh/extension-source/<resourcetype>_raw.ndjson``.

Đây KHÔNG phải một bảng: chỉ là file JSON trên đĩa mà Spark tự suy schema khi
đọc, không qua Bunsen nên giữ nguyên được `extension` (điều mà pipeline
Spark/Bunsen chính không làm được - xem comment trong Encounter_fact.sql).

Cấu hình qua biến môi trường:
  FHIR_SERVER_URL, OUTPUT_DIR, REFRESH_INTERVAL_SECONDS,
  EXTENSION_SOURCE_RESOURCE_TYPES (phân tách bởi dấu phẩy).
"""
import json
import os
import time

import requests

FHIR_SERVER_URL = os.environ.get("FHIR_SERVER_URL", "http://172.16.12.230:8013/fhir").rstrip("/")
OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "/dwh/extension-source")
REFRESH_INTERVAL_SECONDS = int(os.environ.get("REFRESH_INTERVAL_SECONDS", "300"))
RESOURCE_TYPES = [
    r.strip()
    for r in os.environ.get("EXTENSION_SOURCE_RESOURCE_TYPES", "Encounter").split(",")
    if r.strip()
]


def fetch_resources(resource_type):
    resources = []
    url = f"{FHIR_SERVER_URL}/{resource_type}?_count=200"
    while url:
        resp = requests.get(url, headers={"Accept": "application/fhir+json"}, timeout=60)
        resp.raise_for_status()
        bundle = resp.json()
        for entry in bundle.get("entry", []):
            res = entry.get("resource")
            if res and res.get("resourceType") == resource_type:
                resources.append(res)
        url = None
        for link in bundle.get("link", []):
            if link.get("relation") == "next":
                url = link.get("url")
    return resources


def refresh_once():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for rtype in RESOURCE_TYPES:
        resources = fetch_resources(rtype)
        out_path = os.path.join(OUTPUT_DIR, f"{rtype.lower()}_raw.ndjson")
        tmp_path = out_path + ".tmp"
        with open(tmp_path, "w", encoding="utf-8") as f:
            for res in resources:
                f.write(json.dumps(res, ensure_ascii=False) + "\n")
        os.replace(tmp_path, out_path)  # ghi nguyên tử, tránh Spark đọc file dở dang
        print(f"[extension-source-refresh] {rtype}: wrote {len(resources)} resources to {out_path}", flush=True)


def main():
    print(
        f"[extension-source-refresh] starting, resource_types={RESOURCE_TYPES}, "
        f"interval={REFRESH_INTERVAL_SECONDS}s, fhir={FHIR_SERVER_URL}, output_dir={OUTPUT_DIR}",
        flush=True,
    )
    while True:
        try:
            refresh_once()
        except Exception as e:
            print(f"[extension-source-refresh] ERROR: {e}", flush=True)
        time.sleep(REFRESH_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
