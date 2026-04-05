# CSV Troubleshooting Guide

## Symptom: CSV In Redirected I/O

Check:

- storage path health
- MPIO session state
- cluster network health
- active backup or snapshot operations

## Symptom: High VM Storage Latency

Check:

- host CPU saturation
- array latency and cache behavior
- network congestion on storage paths
- CSV ownership and coordinator placement during heavy metadata activity

## Symptom: Failover Causes Long I/O Pause

Check:

- coordinator node transitions
- cluster event logs
- storage path failover timing
- backup or redirected I/O activity during the failover window
