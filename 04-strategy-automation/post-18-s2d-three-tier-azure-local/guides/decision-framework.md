# Decision Framework

## Three-Tier SAN Usually Wins When

- you already own the SAN
- the storage team already knows the platform
- you want to scale compute and storage separately
- the VMware bill is the thing you are trying to replace, not your entire storage strategy

## S2D Usually Wins When

- you are intentionally building a new hyperconverged design
- you accept the hardware standardization and operational model
- low-latency local storage behavior is a primary requirement

## Azure Local Usually Wins When

- Azure management and service integration are strategic requirements, not just nice-to-haves
- the recurring platform fee is acceptable
- the hardware and operational model line up with your environment

## Final Rule

Do not compare architectures in the abstract. Compare them against the workloads you actually run, the hardware you already own, and the operational skills your team already has.
