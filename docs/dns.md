# DNS Requirements

Create DNS records before running the installer.

```text
Type: A
Name: n8n
Value: SERVER_IPV4

Type: A
Name: uptime
Value: SERVER_IPV4
```

Optional IPv6:

```text
Type: AAAA
Name: n8n
Value: SERVER_IPV6

Type: AAAA
Name: uptime
Value: SERVER_IPV6
```

Verify:

```bash
nslookup n8n.example.com
nslookup uptime.example.com
```

Both must resolve to the target server before Let's Encrypt can issue certificates.

