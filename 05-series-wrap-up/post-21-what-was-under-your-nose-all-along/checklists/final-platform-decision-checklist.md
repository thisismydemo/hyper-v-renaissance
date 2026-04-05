# Final Platform Decision Checklist

Use this checklist before committing to a platform direction.

## Commercial Fit

- [ ] We understand the VMware renewal or replacement cost well enough to explain it internally.
- [ ] We understand the Azure Local host service fee and guest licensing model.
- [ ] We have confirmed whether Azure Hybrid Benefit materially changes the Azure Local economics.
- [ ] We have compared those costs against Windows Server Datacenter plus Hyper-V.

## Hardware Fit

- [ ] We know which existing hosts are still viable for another lifecycle.
- [ ] We know whether our current storage platform still meets performance and resiliency requirements.
- [ ] We know whether Azure Local would force a hardware refresh or change our storage posture.

## Operational Fit

- [ ] We know which management tools we actually need.
- [ ] We know which backup and DR model we will standardize on.
- [ ] We know whether Azure integration is a hard requirement or an optional benefit.
- [ ] We know whether the operations team prefers PowerShell-first automation or a broader IaC toolchain.

## Decision Quality

- [ ] We are choosing based on business fit and technical fit, not just product marketing.
- [ ] We are not paying for bundled capabilities we do not expect to use.
- [ ] We are not forcing a new operating model without a clear return.
- [ ] We can explain, in one paragraph, why the chosen platform is the right answer for our environment.
