#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../"

python3 << 'PYEOF'
import json, subprocess, re, sys

def k8s(*args):
    r = subprocess.run(["kubectl"] + list(args), capture_output=True, text=True)
    if r.returncode != 0:
        return {"items": []}
    return json.loads(r.stdout)

def traefik_info(label):
    pods = k8s("get", "pods", "-n", "traefik",
               "-l", f"app.kubernetes.io/instance={label}",
               "--field-selector=status.phase=Running", "-o", "json")
    items = pods.get("items", [])
    if not items:
        return "N/A", "N/A"
    p = items[0]
    return p.get("spec", {}).get("nodeName", "N/A"), p.get("status", {}).get("hostIP", "N/A")

def rows_for(ingresses, ingressroutes, public):
    rows = []
    for i in ingresses:
        ns = i["metadata"]["namespace"]
        name = i["metadata"]["name"]
        icn = i.get("spec", {}).get("ingressClassName", "" if public else "traefik")
        if (public and icn == "traefik-public") or (not public and icn != "traefik-public"):
            for r in i.get("spec", {}).get("rules", []):
                host = r.get("host", "")
                if host:
                    rows.append((ns, name, "Ingress", host))
    if not public:
        for i in ingressroutes:
            ns = i["metadata"]["namespace"]
            name = i["metadata"]["name"]
            for route in i.get("spec", {}).get("routes", []):
                m = re.search(r"Host\(`([^)]+)`\)", route.get("match", ""))
                if m:
                    rows.append((ns, name, "IngressRoute", m.group(1)))
                    break
    return rows

def print_section(title, rows, node, ip):
    print(f"=== {title} ===")
    print(f"  node: {node}  IP: {ip}")
    print()
    if not rows:
        print("  (none)")
        print()
        return
    ns_w = max(len(r[0]) for r in rows)
    nm_w = max(len(r[1]) for r in rows)
    tp_w = max(len(r[2]) for r in rows)
    sep = "  ".join(["-" * w for w in [ns_w, nm_w, tp_w, 0]])
    fmt = "  ".join([f"{{:<{ns_w}}}", f"{{:<{nm_w}}}", f"{{:<{tp_w}}}", "{}"])
    print(fmt.format("NAMESPACE", "NAME", "TYPE", "HOST(S)"))
    print(sep)
    for ns, nm, tp, host in sorted(rows):
        print(fmt.format(ns, nm, tp, host))
    print()

ing = k8s("get", "ingress", "-A", "-o", "json")
irt = k8s("get", "ingressroute", "-A", "-o", "json")

int_node, int_ip = traefik_info("traefik-traefik")
int_rows = rows_for(ing["items"], irt["items"], public=False)
print_section("Internal Ingress (Netbird VPN *.sklein.internal)", int_rows, int_node, int_ip)

pub_node, pub_ip = traefik_info("traefik-public-traefik")
pub_rows = rows_for(ing["items"], irt["items"], public=True)
print_section("Public Ingress (IPv6 *.ipv6.ingress.homelab.public.stephane-klein.info)", pub_rows, pub_node, pub_ip)
PYEOF
